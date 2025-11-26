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

# Tamanho do RAMDISK (50MB é suficiente)
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
    # Fallback silencioso ou erro se crítico
    if [[ -n ${remote_url} ]]; then
       curl -fL --connect-timeout 10 --max-time 120 -o "/tmp/asset.tmp" "${remote_url}" && \
       deploy_file "/tmp/asset.tmp" "${destination}" "${permissions}" || true
    fi
  fi
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] Execute este script como root (use sudo)." >&2
    exit 1
  fi
}

install_camera_packages() {
  export DEBIAN_FRONTEND=noninteractive
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
# CONFIGURAÇÃO DO RAMDISK
# ==============================================================================
prepare_filesystem() {
  echo "[INFO] Configurando RAMDISK..."
  mkdir -p "${STREAM_DIR}" "${STATIC_DIR}" "${STATIC_DIR}/models" "${STATIC_DIR}/mediapipe/wasm"
  
  # Monta RAMDISK se não existir
  if ! mountpoint -q "${STREAM_DIR}"; then
    mount -t tmpfs -o size=${RAMDISK_SIZE},mode=0755,uid=www-data,gid=www-data tmpfs "${STREAM_DIR}"
  fi

  # Adiciona ao fstab para boot
  sed -i "\|${STREAM_DIR}|d" /etc/fstab
  echo "tmpfs ${STREAM_DIR} tmpfs size=${RAMDISK_SIZE},mode=0755,uid=www-data,gid=www-data,noatime,nodiratime 0 0" >> /etc/fstab

  chown -R www-data:www-data /var/www/html || true
  chmod -R 755 /var/www/html
  rm -f "${STREAM_DIR}"/*.ts "${STREAM_DIR}/index.m3u8" >/dev/null 2>&1 || true
}

download_hls_library() {
  local url="https://cdn.jsdelivr.net/npm/hls.js@1.5.4/dist/hls.min.js"
  local packaged="${ASSET_ROOT}/static/hls.min.js"
  ensure_asset "${packaged}" "${url}" "${HLS_JS_PATH}"
}

download_mediapipe_assets() {
  local base_url="https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0"
  local base_dir="${STATIC_DIR}/mediapipe"
  local wasm_dir="${base_dir}/wasm"

  ensure_asset "${ASSET_ROOT}/static/mediapipe/vision_bundle.js" "${base_url}/vision_bundle.js" "${base_dir}/vision_bundle.js"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_internal.js" "${base_url}/wasm/vision_wasm_internal.js" "${wasm_dir}/vision_wasm_internal.js"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_internal.wasm" "${base_url}/wasm/vision_wasm_internal.wasm" "${wasm_dir}/vision_wasm_internal.wasm"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_nosimd_internal.js" "${base_url}/wasm/vision_wasm_nosimd_internal.js" "${wasm_dir}/vision_wasm_nosimd_internal.js"
  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_nosimd_internal.wasm" "${base_url}/wasm/vision_wasm_nosimd_internal.wasm" "${wasm_dir}/vision_wasm_nosimd_internal.wasm"
  ensure_asset "${ASSET_ROOT}/static/models/efficientdet_lite0.tflite" "https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite" "${STATIC_DIR}/models/efficientdet_lite0.tflite"
}

# ==============================================================================
# SCRIPT DA CÂMERA (COM INTRA 12)
# ==============================================================================
write_camera_runner() {
  cat <<'EOF' >"${CAMERA_RUNNER}"
#!/usr/bin/env bash
set -euo pipefail

STREAM_DIR="/var/www/html/stream"
LOG_TAG="rpicam-hls"

# Garante diretório na RAM
mkdir -p "${STREAM_DIR}"
chown www-data:www-data "${STREAM_DIR}" 2>/dev/null || true
chmod 755 "${STREAM_DIR}"

cleanup() {
  rm -f "${STREAM_DIR}"/*.ts "${STREAM_DIR}"/*.m3u8 2>/dev/null || true
}
trap cleanup EXIT

# Configurações Otimizadas
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_BITRATE="${STREAM_BITRATE:-4000000}" 
# Segments de 0.4s
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.4}"
HLS_LIST_SIZE="${HLS_LIST_SIZE:-4}"

# INTRA 12 = Keyframe a cada 12 quadros. A 30fps, isso é exatos 0.4s.
# Isso sincroniza perfeitamente a geração da imagem com o corte do arquivo.

rpicam-vid \
  --timeout 0 \
  --nopreview \
  --width "${STREAM_WIDTH}" \
  --height "${STREAM_HEIGHT}" \
  --framerate "${STREAM_FRAMERATE}" \
  --bitrate "${STREAM_BITRATE}" \
  --intra 12 \
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
# Prioridade Extrema (Realtime IO)
CPUSchedulingPolicy=rr
CPUSchedulingPriority=90
IOSchedulingClass=realtime
IOSchedulingPriority=0
Nice=-15
OOMScoreAdjust=-1000

ExecStartPre=/bin/mkdir -p ${STREAM_DIR}
ExecStartPre=/bin/chown www-data:www-data ${STREAM_DIR}
ExecStart=${CAMERA_RUNNER}
Restart=always
RestartSec=3

Environment=STREAM_FRAMERATE=30
Environment=STREAM_WIDTH=1280
Environment=STREAM_HEIGHT=720
Environment=STREAM_BITRATE=4000000
Environment=HLS_SEGMENT_SECONDS=0.4

[Install]
WantedBy=multi-user.target
EOF
}

SERIAL_BRIDGE_SCRIPT="/usr/local/sbin/montebot-serial-bridge.py"
SERIAL_SERVICE_FILE="/etc/systemd/system/montebot-serial.service"

# Função placeholder para o python (presume-se que você já tenha o arquivo ou use o do script anterior)
write_serial_bridge() {
    # Se o arquivo não existir, criamos um básico, mas idealmente use o seu completo
    if [[ ! -f "${SERIAL_BRIDGE_SCRIPT}" ]]; then
        echo "#!/usr/bin/env python3" > "${SERIAL_BRIDGE_SCRIPT}"
        echo "print('Serial bridge placeholder')" >> "${SERIAL_BRIDGE_SCRIPT}"
    fi
    chmod 755 "${SERIAL_BRIDGE_SCRIPT}"
}

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
  # Chama o segundo script se ele existir
  if [[ -f "${SCRIPT_DIR}/create_web_pages.sh" ]]; then
    bash "${SCRIPT_DIR}/create_web_pages.sh"
  fi
}

reload_services() {
  systemctl daemon-reload
  systemctl enable --now rpicam-hls.service
  systemctl enable --now montebot-serial.service
  systemctl restart nginx
  echo "[INFO] Serviços reiniciados."
}

main() {
  require_root
  prepare_filesystem
  install_camera_packages
  enable_camera_overlay
  download_hls_library
  download_mediapipe_assets
  write_camera_runner
  write_systemd_service
  write_serial_bridge
  write_serial_service
  update_web_page
  reload_services
  echo "🚀 Instalação concluída! Verifique o df -h para confirmar o RAMDISK."
}

main "$@"
