#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Monte Bot - Setup Camera HLS Streaming
# VERSÃO: 2.2 - TEMPO REAL INSTANTÂNEO (200ms)
# CORREÇÃO: Remove TODOS os buffers do rpicam-vid
# ═══════════════════════════════════════════════════════════════════════════

STREAM_DIR="/var/www/html/stream"
STATIC_DIR="/var/www/html/static"
HLS_JS_PATH="${STATIC_DIR}/hls.min.js"
CAMERA_RUNNER="/usr/local/sbin/rpicam-hls.sh"
SERVICE_FILE="/etc/systemd/system/rpicam-hls.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_ROOT="${SCRIPT_DIR}/assets"

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
  if [[ ${current_year} -lt 2020 ]]; then
    echo "[AVISO] O relógio do sistema parece estar incorreto (ano: ${current_year}). Tentando sincronizar..."
  fi

  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true 2>/dev/null || true
  fi

  if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
    systemctl restart systemd-timesyncd 2>/dev/null || true
  fi

  local max_wait=30
  local waited=0
  while [[ ${waited} -lt ${max_wait} ]]; do
    if command -v timedatectl >/dev/null 2>&1; then
      local sync_status
      sync_status=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "no")
      if [[ "${sync_status}" == "yes" ]]; then
        echo "[INFO] Relógio do sistema sincronizado com sucesso."
        return 0
      fi
    fi

    current_year=$(date +%Y)
    if [[ ${current_year} -ge 2020 ]]; then
      echo "[INFO] O relógio do sistema parece estar correto (ano: ${current_year})."
      return 0
    fi

    sleep 1
    waited=$((waited + 1))
    if [[ $((waited % 5)) -eq 0 ]]; then
      echo "[INFO] Aguardando sincronização do relógio... (${waited}/${max_wait}s)"
    fi
  done

  if command -v ntpdate >/dev/null 2>&1; then
    echo "[INFO] Tentando sincronizar relógio usando ntpdate..."
    ntpdate -u pool.ntp.org 2>/dev/null || ntpdate -u time.google.com 2>/dev/null || true
  fi

  current_year=$(date +%Y)
  if [[ ${current_year} -lt 2020 ]]; then
    echo "[AVISO] Não foi possível sincronizar o relógio do sistema."
  else
    echo "[INFO] Verificação do relógio do sistema concluída (ano: ${current_year})."
  fi
}

check_operating_system() {
  local os_id
  os_id=$(awk -F= '/^ID=/{gsub(/"/, ""); print $2}' /etc/os-release)
  local version
  version=$(awk -F= '/^VERSION_ID=/{gsub(/"/, ""); print $2}' /etc/os-release)
  if [[ ${os_id} != "raspbian" && ${os_id} != "debian" ]]; then
    echo "[AVISO] Script validado em Raspberry Pi OS (Bookworm)." >&2
  fi
  if [[ ${version} != "12" ]]; then
    echo "[AVISO] Detectado VERSION_ID=${version}. Esperado 12 (Bookworm)." >&2
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

prepare_filesystem() {
  mkdir -p "${STREAM_DIR}" "${STATIC_DIR}" "${STATIC_DIR}/models" "${STATIC_DIR}/mediapipe/wasm"
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

  ensure_asset "${ASSET_ROOT}/static/mediapipe/vision_bundle.js" \
    "${base_url}/vision_bundle.js" \
    "${base_dir}/vision_bundle.js"

  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_internal.js" \
    "${base_url}/wasm/vision_wasm_internal.js" \
    "${wasm_dir}/vision_wasm_internal.js"

  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_internal.wasm" \
    "${base_url}/wasm/vision_wasm_internal.wasm" \
    "${wasm_dir}/vision_wasm_internal.wasm"

  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_nosimd_internal.js" \
    "${base_url}/wasm/vision_wasm_nosimd_internal.js" \
    "${wasm_dir}/vision_wasm_nosimd_internal.js"

  ensure_asset "${ASSET_ROOT}/static/mediapipe/wasm/vision_wasm_nosimd_internal.wasm" \
    "${base_url}/wasm/vision_wasm_nosimd_internal.wasm" \
    "${wasm_dir}/vision_wasm_nosimd_internal.wasm"

  ensure_asset "${ASSET_ROOT}/static/models/efficientdet_lite0.tflite" \
    "https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite" \
    "${STATIC_DIR}/models/efficientdet_lite0.tflite"
}

write_camera_runner() {
  cat <<'CAMERAEOF' >"${CAMERA_RUNNER}"
#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Monte Bot - Camera Runner (TEMPO REAL INSTANTÂNEO)
# Latência: ~200ms (frames enviados IMEDIATAMENTE)
# ═══════════════════════════════════════════════════════════════════════════

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

log_warn() {
  echo "[WARN] $1" >&2
  logger -t "${LOG_TAG}" "[WARN] $1" 2>/dev/null || true
}

mkdir -p "${STREAM_DIR}"
chown www-data:www-data "${STREAM_DIR}" 2>/dev/null || true
chmod 755 "${STREAM_DIR}"
umask 022

cleanup() {
  log_info "Cleaning up stream files..."
  find "${STREAM_DIR}" -type f \( -name '*.ts' -o -name '*.m3u8' \) -delete || true
}
trap cleanup EXIT

wait_for_camera() {
  log_info "Waiting for camera..."
  local max_wait=30
  local waited=0
  
  while [[ ${waited} -lt ${max_wait} ]]; do
    if command -v rpicam-vid >/dev/null 2>&1; then
      if rpicam-vid --list-cameras 2>&1 | grep -q "Available cameras"; then
        log_info "✅ Camera detected after ${waited}s"
        return 0
      fi
    fi
    
    if [[ -e /dev/video0 ]]; then
      if [[ ${waited} -ge 5 ]]; then
        log_info "✅ Video device found after ${waited}s"
        return 0
      fi
    fi
    
    sleep 1
    waited=$((waited + 1))
  done
  
  log_error "❌ Camera not found after ${max_wait}s"
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO: ZERO BUFFER = TEMPO REAL INSTANTÂNEO
# ═══════════════════════════════════════════════════════════════════════════
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-854}"
STREAM_HEIGHT="${STREAM_HEIGHT:-480}"
STREAM_BITRATE="${STREAM_BITRATE:-3000000}"
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-15}"
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.2}"
HLS_LIST_SIZE="${HLS_LIST_SIZE:-3}"

log_info "🚀 MODO: TEMPO REAL INSTANTÂNEO (200ms latency)"
log_info "📺 ${STREAM_WIDTH}x${STREAM_HEIGHT} @ ${STREAM_FRAMERATE}fps"
log_info "📦 Segments: ${HLS_SEGMENT_SECONDS}s | Buffer: ${HLS_LIST_SIZE}"

if ! wait_for_camera; then
  exit 1
fi

sleep 2
log_info "▶️  Starting ZERO-BUFFER pipeline..."

# ═══════════════════════════════════════════════════════════════════════════
# PIPELINE: REMOVER TODOS OS BUFFERS!
# - rpicam-vid: --flush + --denoise off = frames imediatos
# - stdbuf -o0: forçar stdout sem buffer
# - ffmpeg: -avioflags direct + -muxdelay 0 = sem espera
# ═══════════════════════════════════════════════════════════════════════════
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
  --level 4.0 \
  --inline \
  --flush \
  --denoise off \
  --tuning-file - \
  -o - \
  2>&1 | tee >(grep -i "error\|warn" | head -20 | while read line; do log_warn "rpicam: $line"; done) | \
  stdbuf -o0 ffmpeg \
      -y \
      -loglevel warning \
      -fflags nobuffer+flush_packets+genpts \
      -flags low_delay \
      -probesize 32 \
      -analyzeduration 0 \
      -avioflags direct \
      -thread_queue_size 512 \
      -f h264 \
      -i - \
      -an \
      -c:v copy \
      -muxdelay 0 \
      -muxpreload 0 \
      -max_delay 0 \
      -f hls \
      -hls_time "${HLS_SEGMENT_SECONDS}" \
      -hls_list_size "${HLS_LIST_SIZE}" \
      -hls_flags delete_segments+append_list+omit_endlist+independent_segments+discont_start+split_by_time+program_date_time \
      -hls_segment_type mpegts \
      -start_number 1 \
      -hls_segment_filename "${STREAM_DIR}/segment_%03d.ts" \
      "${STREAM_DIR}/index.m3u8"

EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  log_error "Pipeline failed with code ${EXIT_CODE}"
fi
CAMERAEOF
  chmod 755 "${CAMERA_RUNNER}"
}

write_systemd_service() {
  cat <<SERVICEEOF >"${SERVICE_FILE}"
[Unit]
Description=Monte Bot Camera Stream (TEMPO REAL INSTANTÂNEO)
After=network.target nginx.service
Wants=nginx.service
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
ExecStartPre=/bin/sleep 3
ExecStart=${CAMERA_RUNNER}
Restart=always
RestartSec=10
TimeoutStartSec=60
StandardOutput=journal
StandardError=journal
Environment=STREAM_FRAMERATE=30
Environment=STREAM_WIDTH=854
Environment=STREAM_HEIGHT=480
Environment=STREAM_BITRATE=3000000
Environment=STREAM_KEYFRAME_INTERVAL=15
Environment=HLS_SEGMENT_SECONDS=0.2
Environment=HLS_LIST_SIZE=3

[Install]
WantedBy=multi-user.target
SERVICEEOF
}

SERIAL_BRIDGE_SCRIPT="/usr/local/sbin/montebot-serial-bridge.py"
SERIAL_SERVICE_FILE="/etc/systemd/system/montebot-serial.service"

write_serial_bridge() {
  cat <<"PYEOF" >"${SERIAL_BRIDGE_SCRIPT}"
#!/usr/bin/env python3
import asyncio
import serial
import serial.tools.list_ports
import logging
import os
import json
import time
from datetime import datetime
from typing import Optional, Set
from collections import deque

try:
    import websockets
except ImportError:
    print("[ERROR] websockets not found")
    exit(1)

logging.basicConfig(level=logging.DEBUG, format='[%(levelname)s] %(message)s')
logger = logging.getLogger('montebot-serial')

WEBSOCKET_HOST = '0.0.0.0'
WEBSOCKET_PORT = 8765
SERIAL_PORT = os.environ.get('SERIAL_PORT', '')
SERIAL_BAUDRATE = int(os.environ.get('SERIAL_BAUDRATE', '115200'))
LOG_HISTORY_SIZE = 500
SERIAL_RESPONSE_TIMEOUT = 0.05
SERIAL_READ_INTERVAL = 0.1
SERIAL_INIT_DELAY = 2.0

ser: Optional[serial.Serial] = None
connected_clients: Set = set()
log_history: deque = deque(maxlen=LOG_HISTORY_SIZE)
serial_status = {"connected": False, "port": None, "last_error": None}
command_stats = {"sent": 0, "failed": 0, "last_command": None, "last_time": None}

def create_log_entry(level: str, source: str, message: str, data: dict = None) -> dict:
    entry = {
        "timestamp": datetime.now().isoformat(),
        "time_ms": int(time.time() * 1000),
        "level": level,
        "source": source,
        "message": message,
        "data": data or {}
    }
    log_history.append(entry)
    return entry

async def broadcast_log(entry: dict):
    if not connected_clients:
        return
    message = json.dumps({"type": "log", "entry": entry})
    disconnected = set()
    for client in connected_clients:
        try:
            await client.send(message)
        except:
            disconnected.add(client)
    connected_clients.difference_update(disconnected)

async def log_and_broadcast(level: str, source: str, message: str, data: dict = None):
    log_func = getattr(logger, level.lower(), logger.info)
    log_func(f"[{source}] {message}")
    entry = create_log_entry(level, source, message, data)
    await broadcast_log(entry)

def find_usb_ports() -> list:
    ports = []
    try:
        for port in serial.tools.list_ports.comports():
            ports.append({"device": port.device, "description": port.description})
    except:
        pass
    return ports

async def init_serial() -> Optional[serial.Serial]:
    global ser, serial_status
    if ser and ser.is_open:
        try:
            ser.close()
        except:
            pass
        ser = None
    
    available_ports = find_usb_ports()
    await log_and_broadcast("INFO", "SERIAL", f"Found {len(available_ports)} USB ports")
    
    if SERIAL_PORT:
        ports_to_try = [SERIAL_PORT]
    else:
        ports_to_try = [p["device"] for p in available_ports]
    
    for port in ports_to_try:
        try:
            await log_and_broadcast("INFO", "SERIAL", f"Trying {port}...")
            ser = serial.Serial(port, SERIAL_BAUDRATE, timeout=1)
            await asyncio.sleep(SERIAL_INIT_DELAY)
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            serial_status = {"connected": True, "port": port, "last_error": None}
            await log_and_broadcast("INFO", "SERIAL", f"✅ Connected: {port}")
            return ser
        except Exception as e:
            await log_and_broadcast("WARNING", "SERIAL", f"❌ Failed {port}")
    
    await log_and_broadcast("ERROR", "SERIAL", "No serial port available")
    return None

async def send_command(cmd: str, websocket=None) -> bool:
    global ser, command_stats
    cmd = cmd.strip()
    if not cmd:
        return False
    
    command_stats["last_command"] = cmd
    command_stats["last_time"] = datetime.now().isoformat()
    await log_and_broadcast("INFO", "COMMAND", f"📤 Sending: {cmd}")
    
    if ser and ser.is_open:
        try:
            data = f"{cmd}\n".encode()
            bytes_written = ser.write(data)
            ser.flush()
            command_stats["sent"] += 1
            await log_and_broadcast("DEBUG", "SERIAL", f"✅ Wrote {bytes_written} bytes")
            await asyncio.sleep(SERIAL_RESPONSE_TIMEOUT)
            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting).decode('utf-8', errors='replace').strip()
                if response:
                    await log_and_broadcast("INFO", "SERIAL", f"📥 Response: {response}")
            return True
        except Exception as e:
            command_stats["failed"] += 1
            await log_and_broadcast("ERROR", "SERIAL", f"❌ Write error")
            await init_serial()
            return False
    else:
        command_stats["failed"] += 1
        await log_and_broadcast("WARNING", "COMMAND", f"⚠️  No serial - command logged only")
        return False

async def read_serial_data():
    global ser
    while True:
        try:
            if ser and ser.is_open and ser.in_waiting > 0:
                data = ser.read(ser.in_waiting).decode('utf-8', errors='replace').strip()
                if data:
                    for line in data.split('\n'):
                        line = line.strip()
                        if line:
                            await log_and_broadcast("INFO", "ARDUINO", f"📥 {line}")
        except:
            await init_serial()
        await asyncio.sleep(SERIAL_READ_INTERVAL)

async def handle_connection(websocket):
    client_addr = websocket.remote_address
    connected_clients.add(websocket)
    await log_and_broadcast("INFO", "WEBSOCKET", f"🔌 Client connected: {client_addr}")
    
    status_msg = json.dumps({"type": "status", "serial": serial_status, "stats": command_stats})
    await websocket.send(status_msg)
    
    history_msg = json.dumps({"type": "history", "entries": list(log_history)})
    await websocket.send(history_msg)
    
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                if data.get("type") == "command":
                    cmd = data.get("cmd", "").strip()
                    if cmd:
                        success = await send_command(cmd, websocket)
                        response = json.dumps({"type": "command_result", "command": cmd, "success": success})
                        await websocket.send(response)
            except:
                pass
    except:
        pass
    finally:
        connected_clients.discard(websocket)
        await log_and_broadcast("INFO", "WEBSOCKET", f"🔌 Client disconnected")

async def main():
    await log_and_broadcast("INFO", "SYSTEM", "🚀 Serial Bridge starting...")
    await init_serial()
    await log_and_broadcast("INFO", "WEBSOCKET", f"WebSocket on ws://*:{WEBSOCKET_PORT}")
    
    async with websockets.serve(handle_connection, WEBSOCKET_HOST, WEBSOCKET_PORT):
        asyncio.create_task(read_serial_data())
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Shutting down...")
PYEOF
  chmod 755 "${SERIAL_BRIDGE_SCRIPT}"
}

write_serial_service() {
  cat <<SEREOF >"${SERIAL_SERVICE_FILE}"
[Unit]
Description=Monte Bot Serial Bridge
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${SERIAL_BRIDGE_SCRIPT}
Restart=always
RestartSec=3
User=root
Group=dialout

[Install]
WantedBy=multi-user.target
SEREOF
}

update_web_page() {
  bash "${SCRIPT_DIR}/create_web_pages.sh"
  return 0
}

reload_services() {
  systemctl daemon-reload
  systemctl enable --now rpicam-hls.service
  systemctl enable --now montebot-serial.service
  systemctl restart nginx
}

main() {
  require_root
  
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║   MONTE BOT - TEMPO REAL INSTANTÂNEO (200ms)                  ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "⚡ ZERO BUFFER MODE"
  echo "📺 854x480 @ 30fps"
  echo "⏱️  Latência: ~200ms"
  echo ""
  
  check_operating_system
  install_camera_packages
  enable_camera_overlay
  prepare_filesystem
  download_hls_library
  download_mediapipe_assets
  write_camera_runner
  write_systemd_service
  write_serial_bridge
  write_serial_service
  update_web_page
  reload_services
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                  ✅ INSTALAÇÃO CONCLUÍDA!                     ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "⚡ PRÓXIMO PASSO: sudo reboot"
  echo ""
}

main "$@"
