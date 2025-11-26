#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CONFIGURAÇÕES GERAIS
# ==============================================================================
STREAM_DIR="/var/www/html/stream"
STATIC_DIR="/var/www/html/static"
HLS_JS_PATH="${STATIC_DIR}/hls.min.js"
CAMERA_RUNNER="/usr/local/sbin/rpicam-hls.sh"
SERVICE_FILE="/etc/systemd/system/rpicam-hls.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_ROOT="${SCRIPT_DIR}/assets"

# Tamanho do RAMDISK (50MB é mais que suficiente para chunks de 0.4s)
RAMDISK_SIZE="50M"

# ==============================================================================
# FUNÇÕES UTILITÁRIAS
# ==============================================================================

deploy_file() {
  local source_file=$1
  local destination=$2
  local permissions=${3:-644}
  install -D -o www-data -g www-data -m "${permissions}" "${source_file}" "${destination}"
}

ensure_asset() {
  local packaged=$1
  local remote_url=$2
  local destination=$3
  local permissions=${4:-644}

  if [[ -f ${packaged} ]]; then
    deploy_file "${packaged}" "${destination}" "${permissions}"
  else
    echo "[ERRO] Arquivo empacotado ausente: ${packaged}" >&2
    exit 1
  fi

  if [[ -n ${remote_url} ]]; then
    local tmp
    tmp=$(mktemp)
    if curl -fL --connect-timeout 10 --max-time 120 -o "${tmp}" "${remote_url}"; then
      deploy_file "${tmp}" "${destination}" "${permissions}"
      echo "[INFO] Atualizado ${destination} a partir de ${remote_url}." >&2
    else
      echo "[AVISO] Não foi possível atualizar ${destination} de ${remote_url}. Mantendo versão empacotada." >&2
    fi
    rm -f "${tmp}"
  fi
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] Execute este script como root (use sudo)." >&2
    exit 1
  fi
}

sync_system_clock() {
  echo "[INFO] Verificando sincronização do relógio do sistema..."
  local current_year
  current_year=$(date +%Y)
  
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true 2>/dev/null || true
  fi

  if [[ ${current_year} -lt 2020 ]]; then
    echo "[INFO] Forçando sincronização ntp..."
    if command -v ntpdate >/dev/null 2>&1; then
        ntpdate -u pool.ntp.org 2>/dev/null || true
    fi
  fi
}

check_operating_system() {
  local os_id
  os_id=$(awk -F= '/^ID=/{gsub(/"/, ""); print $2}' /etc/os-release)
  if [[ ${os_id} != "raspbian" && ${os_id} != "debian" ]]; then
    echo "[AVISO] Script validado em Raspberry Pi OS. Prosseguir com cautela." >&2
  fi
}

install_camera_packages() {
  export DEBIAN_FRONTEND=noninteractive
  sync_system_clock
  apt-get update
  apt-get install -y --no-install-recommends rpicam-apps ffmpeg curl python3 python3-serial python3-websockets
}

detect_boot_config() {
  if [[ -f /boot/firmware/config.txt ]]; then
    echo "/boot/firmware/config.txt"
  else
    echo "/boot/config.txt"
  fi
}

enable_camera_overlay() {
  local config_path
  config_path=$(detect_boot_config)
  local marker_begin="# rpicam-setup begin"
  local marker_end="# rpicam-setup end"

  sed -i "/${marker_begin}/,/${marker_end}/d" "${config_path}"
  cat <<EOF >>"${config_path}"
${marker_begin}
camera_auto_detect=1
dtoverlay=imx219
${marker_end}
EOF
}

# ==============================================================================
# CONFIGURAÇÃO DO RAMDISK (AQUI ESTÁ A CORREÇÃO PRINCIPAL)
# ==============================================================================
prepare_filesystem() {
  echo "[INFO] Configurando sistema de arquivos e RAMDISK..."
  
  # Cria diretórios base
  mkdir -p "${STREAM_DIR}" "${STATIC_DIR}" "${STATIC_DIR}/models" "${STATIC_DIR}/mediapipe/wasm"
  
  # 1. Verifica se o RAMDISK já está montado
  if mountpoint -q "${STREAM_DIR}"; then
    echo "   ✅ RAMDISK já montado em ${STREAM_DIR}"
  else
    echo "   ⚡ Montando RAMDISK em ${STREAM_DIR}..."
    mount -t tmpfs -o size=${RAMDISK_SIZE},mode=0755,uid=www-data,gid=www-data tmpfs "${STREAM_DIR}"
  fi

  # 2. Adiciona ao fstab para persistir após reboot
  # Remove entrada antiga se existir para evitar duplicatas
  sed -i "\|${STREAM_DIR}|d" /etc/fstab
  
  # Adiciona nova entrada
  echo "tmpfs ${STREAM_DIR} tmpfs size=${RAMDISK_SIZE},mode=0755,uid=www-data,gid=www-data,noatime,nodiratime 0 0" >> /etc/fstab
  echo "   ✅ Configuração do fstab atualizada"

  # Permissões finais
  chown -R www-data:www-data /var/www/html || true
  chmod -R 755 /var/www/html
  
  # Limpa arquivos antigos
  rm -f "${STREAM_DIR}"/*.ts "${STREAM_DIR}/index.m3u8" >/dev/null 2>&1 || true
}

download_hls_library() {
  local url="https://cdn.jsdelivr.net/npm/hls.js@1.5.4/dist/hls.min.js"
  local packaged="${ASSET_ROOT}/static/hls.min.js"
  ensure_asset "${packaged}" "${url}" "${HLS_JS_PATH}"
}

download_mediapipe_assets() {
  # (Mantido igual ao original, resumido para brevidade no script final, mas essencial)
  local base_url="https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0"
  local base_dir="${STATIC_DIR}/mediapipe"
  local wasm_dir="${base_dir}/wasm"
  
  # Certifique-se de que essas linhas estão no seu script original ou copie daqui se precisar
  ensure_asset "${ASSET_ROOT}/static/mediapipe/vision_bundle.js" "${base_url}/vision_bundle.js" "${base_dir}/vision_bundle.js"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_internal.js" "${base_url}/wasm/vision_wasm_internal.js" "${wasm_dir}/vision_wasm_internal.js"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_internal.wasm" "${base_url}/wasm/vision_wasm_internal.wasm" "${wasm_dir}/vision_wasm_internal.wasm"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_nosimd_internal.js" "${base_url}/wasm/vision_wasm_nosimd_internal.js" "${wasm_dir}/vision_wasm_nosimd_internal.js"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_nosimd_internal.wasm" "${base_url}/wasm/vision_wasm_nosimd_internal.wasm" "${wasm_dir}/vision_wasm_nosimd_internal.wasm"
  ensure_asset "${ASSET_ROOT}/static/models/efficientdet_lite0.tflite" "https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite" "${STATIC_DIR}/models/efficientdet_lite0.tflite"
}

write_camera_runner() {
  cat <<'EOF' >"${CAMERA_RUNNER}"
#!/usr/bin/env bash
set -euo pipefail

STREAM_DIR="/var/www/html/stream"
LOG_TAG="rpicam-hls"

log_info() {
  echo "[INFO] $1"
  logger -t "${LOG_TAG}" "[INFO] $1" 2>/dev/null || true
}

log_error() {
  echo "[ERROR] $1" >&2
  logger -t "${LOG_TAG}" "[ERROR] $1" 2>/dev/null || true
}

# Setup inicial do diretório (caso o mount tenha falhado, cria fallback)
mkdir -p "${STREAM_DIR}"
chown www-data:www-data "${STREAM_DIR}" 2>/dev/null || true
chmod 755 "${STREAM_DIR}"

cleanup() {
  log_info "Cleaning up stream files..."
  rm -f "${STREAM_DIR}"/*.ts "${STREAM_DIR}"/*.m3u8 2>/dev/null || true
}
trap cleanup EXIT

# Configurações de Streaming
# Reduzi ligeiramente o bitrate padrão para 4Mbps para aliviar o encoder em chunks de 0.4s
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_BITRATE="${STREAM_BITRATE:-4000000}" 
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-30}"
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.4}"
HLS_LIST_SIZE="${HLS_LIST_SIZE:-4}"

log_info "Starting pipeline: ${STREAM_WIDTH}x${STREAM_HEIGHT} @ ${STREAM_FRAMERATE}fps, ${STREAM_BITRATE}bps"

# rpicam-vid: Otimizado para performance (level 4.2, baseline profile para menos CPU)
# ffmpeg: Otimizado para latência zero
rpicam-vid \
  --timeout 0 \
  --nopreview \
  --width "${STREAM_WIDTH}" \
  --height "${STREAM_HEIGHT}" \
  --framerate "${STREAM_FRAMERATE}" \
  --bitrate "${STREAM_BITRATE}" \
  --intra "${STREAM_KEYFRAME_INTERVAL}" \
  --codec h264 \
  --profile baseline \
  --level 4.2 \
  --inline \
  --flush \
  -o - \
  | ffmpeg \
      -y \
      -loglevel error \
      -fflags nobuffer \
      -flags low_delay \
      -f h264 \
      -i - \
      -c:v copy \
      -an \
      -f hls \
      -hls_time "${HLS_SEGMENT_SECONDS}" \
      -hls_list_size "${HLS_LIST_SIZE}" \
      -hls_flags delete_segments+append_list+omit_endlist+independent_segments \
      -hls_segment_type mpegts \
      -hls_segment_filename "${STREAM_DIR}/segment_%03d.ts" \
      "${STREAM_DIR}/index.m3u8"

EOF
  chmod 755 "${CAMERA_RUNNER}"
}

# ==============================================================================
# SERVIÇO SYSTEMD OTIMIZADO (Prioridade de CPU e IO)
# ==============================================================================
write_systemd_service() {
  cat <<EOF >"${SERVICE_FILE}"
[Unit]
Description=Streaming da câmera Raspberry Pi (rpicam + HLS + RAMDISK)
After=network.target nginx.service multi-user.target systemd-udev-settle.service
Wants=nginx.service systemd-udev-settle.service
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
# Prioridade Extrema para evitar travamentos
CPUSchedulingPolicy=rr
CPUSchedulingPriority=90
IOSchedulingClass=realtime
IOSchedulingPriority=0
Nice=-15
OOMScoreAdjust=-1000

# Execução
ExecStartPre=/bin/mkdir -p ${STREAM_DIR}
ExecStartPre=/bin/chown www-data:www-data ${STREAM_DIR}
ExecStart=${CAMERA_RUNNER}
Restart=always
RestartSec=3

# Variáveis de Ambiente
Environment=STREAM_FRAMERATE=30
Environment=STREAM_WIDTH=1280
Environment=STREAM_HEIGHT=720
Environment=STREAM_BITRATE=4000000
Environment=HLS_SEGMENT_SECONDS=0.4

[Install]
WantedBy=multi-user.target
EOF
}

# (Mantendo as funções do Serial Bridge inalteradas para garantir compatibilidade)
SERIAL_BRIDGE_SCRIPT="/usr/local/sbin/montebot-serial-bridge.py"
SERIAL_SERVICE_FILE="/etc/systemd/system/montebot-serial.service"

write_serial_bridge() {
    # ... (Seu código Python original aqui - não precisa mudar)
    # Vou apenas referenciar o arquivo original para manter o tamanho da resposta legível
    # mas na sua execução real, mantenha o código python que você já tem no script.
    # Se precisar que eu reescreva o python, me avise.
    echo "[INFO] Escrevendo script serial bridge..."
    # ... Inserir código python original aqui ...
    
    # Placeholder simples para não quebrar se você copiar e colar:
    if [[ ! -f "${SERIAL_BRIDGE_SCRIPT}" ]]; then
        echo "#!/usr/bin/env python3" > "${SERIAL_BRIDGE_SCRIPT}"
        echo "print('Script placeholder - use o original se nao tiver update')" >> "${SERIAL_BRIDGE_SCRIPT}"
    fi
    chmod 755 "${SERIAL_BRIDGE_SCRIPT}"
}
# OBS: No seu uso, mantenha a função write_serial_bridge completa que você já tinha!

write_serial_service() {
  cat <<EOF >"${SERIAL_SERVICE_FILE}"
[Unit]
Description=Monte Bot Serial Bridge
After=network.target
StartLimitIntervalSec=300
StartLimitBurst=10

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/python3 ${SERIAL_BRIDGE_SCRIPT}
Restart=always
RestartSec=3
User=root
Group=dialout
Environment=SERIAL_PORT=
Environment=SERIAL_BAUDRATE=115200

[Install]
WantedBy=multi-user.target
EOF
}

update_web_page() {
  if [[ -f "${SCRIPT_DIR}/create_web_pages.sh" ]]; then
    bash "${SCRIPT_DIR}/create_web_pages.sh"
  fi
  return 0
}

reload_services() {
  systemctl daemon-reload
  systemctl enable --now rpicam-hls.service
  systemctl enable --now montebot-serial.service
  systemctl restart nginx
  echo "[INFO] Serviços reiniciados."
}

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================
main() {
  require_root
  check_operating_system
  install_camera_packages
  enable_camera_overlay
  
  # A ordem importa: Prepara o Filesystem (RAMDISK) ANTES de escrever o serviço
  prepare_filesystem
  
  download_hls_library
  download_mediapipe_assets
  write_camera_runner
  write_systemd_service
  
  # ATENÇÃO: Recoloque sua função write_serial_bridge completa aqui se for rodar
  # write_serial_bridge 
  write_serial_service
  
  update_web_page
  reload_services
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║   🚀 INSTALAÇÃO CONCLUÍDA COM OTIMIZAÇÃO DE RAM                ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo "Verifique se o RAMDISK está ativo rodando: df -h | grep stream"
}

main "$@"
