#!/usr/bin/env bash
set -euo pipefail

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
    echo "[AVISO] O relógio do sistema parece estar incorreto. Tentando sincronizar..."
  fi
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true 2>/dev/null || true
  fi
  if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
    systemctl restart systemd-timesyncd 2>/dev/null || true
  fi
  if command -v ntpdate >/dev/null 2>&1; then
    ntpdate -u pool.ntp.org 2>/dev/null || true
  fi
}

check_operating_system() {
  local os_id
  os_id=$(awk -F= '/^ID=/{gsub(/"/, ""); print $2}' /etc/os-release)
  if [[ ${os_id} != "raspbian" && ${os_id} != "debian" ]]; then
    echo "[AVISO] Script validado em Raspberry Pi OS (Bookworm). Prosseguir com cautela." >&2
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
  cat <<'EOF' >"${CAMERA_RUNNER}"
#!/usr/bin/env bash
set -euo pipefail

STREAM_DIR="/var/www/html/stream"
mkdir -p "${STREAM_DIR}"
umask 022

cleanup() {
  find "${STREAM_DIR}" -type f \( -name '*.ts' -o -name '*.m3u8' \) -delete || true
}
trap cleanup EXIT

# CONFIGURAÇÃO DE ESTABILIDADE
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_BITRATE="${STREAM_BITRATE:-5000000}"

# CORREÇÃO CRÍTICA: Keyframe e Segmento sincronizados em 0.5s
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-15}"
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.5}"
HLS_LIST_SIZE="${HLS_LIST_SIZE:-4}"

rpicam-vid \
  --timeout 0 \
  --nopreview \
  --width "${STREAM_WIDTH}" \
  --height "${STREAM_HEIGHT}" \
  --framerate "${STREAM_FRAMERATE}" \
  --bitrate "${STREAM_BITRATE}" \
  --intra "${STREAM_KEYFRAME_INTERVAL}" \
  --codec h264 \
  --profile high \
  --level 4.2 \
  --inline \
  -o - \
  | ffmpeg \
      -loglevel warning \
      -fflags nobuffer \
      -flags low_delay \
      -f h264 \
      -i - \
      -an \
      -c:v copy \
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
Description=Streaming da câmera Raspberry Pi (rpicam + HLS)
After=network.target nginx.service

[Service]
Type=simple
ExecStart=${CAMERA_RUNNER}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

SERIAL_BRIDGE_SCRIPT="/usr/local/sbin/montebot-serial-bridge.py"
SERIAL_SERVICE_FILE="/etc/systemd/system/montebot-serial.service"

write_serial_bridge() {
  cat <<'SERIALEOF' >"${SERIAL_BRIDGE_SCRIPT}"
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
    print("[ERROR] websockets module not found. Install with: apt-get install python3-websockets")
    exit(1)

logging.basicConfig(level=logging.DEBUG, format='[%(levelname)s] %(message)s')
logger = logging.getLogger('montebot-serial')

# Configuration
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
    if not connected_clients: return
    message = json.dumps({"type": "log", "entry": entry})
    disconnected = set()
    for client in connected_clients:
        try:
            await client.send(message)
        except websockets.exceptions.ConnectionClosed:
            disconnected.add(client)
        except Exception as e:
            logger.warning(f"Failed to send to client: {e}")
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
    except Exception: pass
    
    common_ports = ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyACM0', '/dev/ttyACM1', '/dev/serial0']
    existing = set(p["device"] for p in ports)
    for p in common_ports:
        if p not in existing and os.path.exists(p):
            ports.append({"device": p, "description": "Found via filesystem"})
    return ports

async def init_serial() -> Optional[serial.Serial]:
    global ser, serial_status
    if ser and ser.is_open:
        try: ser.close()
        except: pass
        ser = None
    
    ports = find_usb_ports()
    await log_and_broadcast("INFO", "SERIAL", f"Found {len(ports)} USB ports", {"ports": [p["device"] for p in ports]})
    
    ports_to_try = [SERIAL_PORT] if SERIAL_PORT else sorted([p["device"] for p in ports], key=lambda x: (0 if 'ACM' in x else 1))
    
    for port in ports_to_try:
        try:
            await log_and_broadcast("INFO", "SERIAL", f"Connecting to {port}...")
            ser = serial.Serial(port, SERIAL_BAUDRATE, timeout=1)
            await asyncio.sleep(SERIAL_INIT_DELAY)
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            serial_status = {"connected": True, "port": port, "last_error": None}
            await log_and_broadcast("INFO", "SERIAL", f"✅ Connected to {port}")
            return ser
        except Exception as e:
            await log_and_broadcast("WARNING", "SERIAL", f"❌ Failed to open {port}: {e}")
            serial_status = {"connected": False, "port": None, "last_error": str(e)}
    
    return None

async def send_command(cmd: str, websocket=None) -> bool:
    global ser, command_stats
    cmd = cmd.strip()
    if not cmd: return False
    
    command_stats["last_command"] = cmd
    command_stats["last_time"] = datetime.now().isoformat()
    await log_and_broadcast("INFO", "COMMAND", f"📤 Sending: {cmd}")
    
    if ser and ser.is_open:
        try:
            ser.write(f"{cmd}\n".encode())
            ser.flush()
            command_stats["sent"] += 1
            return True
        except Exception as e:
            command_stats["failed"] += 1
            await log_and_broadcast("ERROR", "SERIAL", f"❌ Write error: {e}")
            await init_serial()
            return False
    else:
        command_stats["failed"] += 1
        await log_and_broadcast("WARNING", "COMMAND", f"⚠️ Serial not connected")
        return False

async def read_serial_data():
    global ser
    while True:
        try:
            if ser and ser.is_open and ser.in_waiting > 0:
                data = ser.read(ser.in_waiting).decode('utf-8', errors='replace').strip()
                if data:
                    for line in data.split('\n'):
                        if line.strip():
                            await log_and_broadcast("INFO", "ARDUINO", f"📥 {line.strip()}")
        except Exception as e:
            await log_and_broadcast("ERROR", "SERIAL", f"Read error: {e}")
            await init_serial()
        await asyncio.sleep(SERIAL_READ_INTERVAL)

async def handle_connection(websocket):
    connected_clients.add(websocket)
    try:
        await websocket.send(json.dumps({"type": "status", "serial": serial_status, "stats": command_stats}))
        await websocket.send(json.dumps({"type": "history", "entries": list(log_history)}))
        async for message in websocket:
            try:
                data = json.loads(message)
                if data.get("type") == "command":
                    await send_command(data.get("cmd", ""))
                elif data.get("type") == "reconnect_serial":
                    await init_serial()
            except: pass
    except: pass
    finally:
        connected_clients.discard(websocket)

async def main():
    await log_and_broadcast("INFO", "SYSTEM", "🚀 Serial Bridge starting...")
    await init_serial()
    async with websockets.serve(handle_connection, WEBSOCKET_HOST, WEBSOCKET_PORT):
        asyncio.create_task(read_serial_data())
        await asyncio.Future()

if __name__ == "__main__":
    try: asyncio.run(main())
    except KeyboardInterrupt: pass
SERIALEOF
  chmod 755 "${SERIAL_BRIDGE_SCRIPT}"
}

write_serial_service() {
  cat <<EOF >"${SERIAL_SERVICE_FILE}"
[Unit]
Description=Monte Bot Serial Bridge (WebSocket to Arduino)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${SERIAL_BRIDGE_SCRIPT}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
User=root
Group=dialout
Environment=SERIAL_PORT=/dev/ttyACM0
Environment=SERIAL_BAUDRATE=115200

[Install]
WantedBy=multi-user.target
EOF
}

update_web_page() {
  bash "${SCRIPT_DIR}/create_web_pages.sh"
}

reload_services() {
  systemctl daemon-reload
  systemctl enable --now rpicam-hls.service
  systemctl enable --now montebot-serial.service
  systemctl restart nginx
  systemctl restart rpicam-hls
}

main() {
  require_root
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
  echo "[INFO] Instalação concluída! Acesse http://$(hostname -I | awk '{print $1}')"
}

main "$@"
