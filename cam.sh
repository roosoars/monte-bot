#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Monte Bot - Setup Camera HLS Streaming
# VERSÃO: 2.0 - Ultra-Baixa Latência (300-500ms)
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
    echo "[AVISO] Não foi possível sincronizar o relógio do sistema. apt-get update pode falhar."
    echo "[AVISO] Certifique-se de que o Raspberry Pi tem acesso à internet e tente novamente."
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
    echo "[AVISO] Script validado em Raspberry Pi OS (Bookworm). Prosseguir com cautela." >&2
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
  cat <<'EOF' >"${CAMERA_RUNNER}"
#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Monte Bot - Camera Runner (Ultra-Low Latency Mode)
# Latência esperada: 300-500ms
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

# Wait for camera to be ready (timeout: 30s)
wait_for_camera() {
  log_info "Waiting for camera to be ready..."
  local max_wait=30
  local waited=0
  
  log_info "Initial diagnostics:"
  log_info "  - Available video devices: $(ls /dev/video* 2>/dev/null || echo 'none')"
  
  while [[ ${waited} -lt ${max_wait} ]]; do
    # Check if libcamera can detect a camera
    if command -v libcamera-hello >/dev/null 2>&1; then
      local libcamera_output
      libcamera_output=$(libcamera-hello --list-cameras 2>&1 || true)
      if echo "${libcamera_output}" | grep -q -E "^[0-9]+\s*:"; then
        log_info "Camera detected via libcamera after ${waited} seconds"
        log_info "Camera: $(echo "${libcamera_output}" | grep -E "^[0-9]+\s*:" | head -1)"
        return 0
      fi
    fi
    
    # Check if rpicam-vid can detect a camera
    if command -v rpicam-vid >/dev/null 2>&1; then
      local rpicam_output
      rpicam_output=$(rpicam-vid --list-cameras 2>&1 || true)
      if echo "${rpicam_output}" | grep -q "Available cameras"; then
        log_info "Camera detected via rpicam-vid after ${waited} seconds"
        return 0
      fi
    fi
    
    # Alternative check: look for video devices
    if [[ -e /dev/video0 ]]; then
      if command -v v4l2-ctl >/dev/null 2>&1; then
        if v4l2-ctl --list-devices 2>/dev/null | grep -q -i "camera\|unicam\|bcm\|imx\|ov5647"; then
          log_info "Video device found via v4l2-ctl after ${waited} seconds"
          return 0
        fi
      else
        local min_wait_no_v4l2=5
        if [[ ${waited} -ge ${min_wait_no_v4l2} ]]; then
          log_info "Video device /dev/video0 found after ${waited} seconds (v4l2-ctl not available)"
          return 0
        fi
      fi
    fi
    
    sleep 1
    waited=$((waited + 1))
    if [[ $((waited % 10)) -eq 0 ]]; then
      log_info "Still waiting for camera... (${waited}/${max_wait}s)"
      log_info "Checking: ls /dev/video* = $(ls /dev/video* 2>/dev/null || echo 'none')"
    fi
  done
  
  local video_devices
  video_devices=$(ls /dev/video* 2>/dev/null || echo 'none')
  
  log_error "Camera not detected after ${max_wait} seconds"
  log_error "Diagnostic info:"
  log_error "  - /dev/video* devices: ${video_devices}"
  log_error "  - Check journalctl for camera driver errors: journalctl -b | grep -i camera"
  log_error "  - Try running manually: libcamera-hello --list-cameras"
  log_error "  - Verify camera is enabled in /boot/firmware/config.txt or /boot/config.txt"
  log_error "  - Check if camera ribbon cable is properly connected"
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# ULTRA-LOW LATENCY SETTINGS (300-500ms expected latency)
# ═══════════════════════════════════════════════════════════════════════════
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-854}"               # ⚡ 480p para baixa latência
STREAM_HEIGHT="${STREAM_HEIGHT:-480}"             # ⚡ 480p para baixa latência
STREAM_BITRATE="${STREAM_BITRATE:-3000000}"       # ⚡ 3Mbps (balanceado)
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-15}"  # ⚡ Keyframe a cada 0.5s
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.2}" # ⚡⚡⚡ CRÍTICO: 200ms segments
HLS_LIST_SIZE="${HLS_LIST_SIZE:-2}"               # ⚡⚡⚡ CRÍTICO: buffer mínimo

log_info "Starting camera stream service (ULTRA-LOW LATENCY MODE)"
log_info "Settings: ${STREAM_WIDTH}x${STREAM_HEIGHT} @ ${STREAM_FRAMERATE}fps, bitrate=${STREAM_BITRATE}"
log_info "HLS: segments=${HLS_SEGMENT_SECONDS}s, playlist=${HLS_LIST_SIZE}, keyframe every ${STREAM_KEYFRAME_INTERVAL} frames"
log_info "Expected latency: 300-500ms"

# Wait for camera to be ready
if ! wait_for_camera; then
  log_error "Failed to detect camera, exiting"
  exit 1
fi

log_info "Starting rpicam-vid and ffmpeg pipeline..."

# Additional delay to ensure camera is fully initialized after detection
sleep 2

log_info "Launching ultra-low latency streaming pipeline..."

# ═══════════════════════════════════════════════════════════════════════════
# ULTRA-LOW LATENCY PIPELINE
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
  -o - \
  2>&1 | tee >(grep -i "error\|warn" | head -20 | while read line; do log_warn "rpicam: $line"; done) | \
  ffmpeg \
      -y \
      -loglevel warning \
      -fflags nobuffer+flush_packets \
      -flags low_delay \
      -probesize 32 \
      -analyzeduration 0 \
      -f h264 \
      -i - \
      -an \
      -c:v copy \
      -f hls \
      -hls_time "${HLS_SEGMENT_SECONDS}" \
      -hls_list_size "${HLS_LIST_SIZE}" \
      -hls_flags delete_segments+append_list+omit_endlist+independent_segments+discont_start+split_by_time \
      -hls_segment_type mpegts \
      -start_number 1 \
      -hls_segment_filename "${STREAM_DIR}/segment_%03d.ts" \
      "${STREAM_DIR}/index.m3u8"

PIPELINE_EXIT=$?

if [[ ${PIPELINE_EXIT} -ne 0 ]]; then
  log_error "Pipeline exited with code ${PIPELINE_EXIT}"
  log_error "Common causes of pipeline failure:"
  log_error "  - Camera not connected or not enabled"
  log_error "  - Another process is using the camera"
  log_error "  - Insufficient permissions"
  log_error "  - ffmpeg not installed or misconfigured"
  log_error "To diagnose, run: rpicam-vid --timeout 5000 -o test.h264"
  exit ${PIPELINE_EXIT}
fi

log_info "Stream ended gracefully"
EOF
  chmod 755 "${CAMERA_RUNNER}"
}

write_systemd_service() {
  cat <<EOF >"${SERVICE_FILE}"
[Unit]
Description=Streaming da câmera Raspberry Pi (rpicam + HLS) - Ultra-Low Latency
After=network.target nginx.service multi-user.target
Wants=nginx.service
# Wait for the system to be fully booted before starting camera service
After=systemd-udev-settle.service
Wants=systemd-udev-settle.service
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
# Delay inicial reduzido para 3 segundos
ExecStartPre=/bin/sleep 3
ExecStart=${CAMERA_RUNNER}
Restart=always
RestartSec=10
# Timeout reduzido para 60 segundos
TimeoutStartSec=60
StandardOutput=journal
StandardError=journal
# Environment variables for ULTRA-LOW LATENCY streaming
Environment=STREAM_FRAMERATE=30
Environment=STREAM_WIDTH=854
Environment=STREAM_HEIGHT=480
Environment=STREAM_BITRATE=3000000
Environment=STREAM_KEYFRAME_INTERVAL=15
Environment=HLS_SEGMENT_SECONDS=0.2
Environment=HLS_LIST_SIZE=2

[Install]
WantedBy=multi-user.target
EOF
}

SERIAL_BRIDGE_SCRIPT="/usr/local/sbin/montebot-serial-bridge.py"
SERIAL_SERVICE_FILE="/etc/systemd/system/montebot-serial.service"

write_serial_bridge() {
  cat <<'SERIALEOF' >"${SERIAL_BRIDGE_SCRIPT}"
#!/usr/bin/env python3
"""
Monte Bot Serial Bridge - WebSocket to Serial communication with real-time logging.
Receives commands from the web UI via WebSocket and sends them to Arduino via USB serial.
Broadcasts all logs to connected clients for real-time monitoring.
"""
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
SERIAL_PORT = os.environ.get('SERIAL_PORT', '')  # Empty means auto-detect
SERIAL_BAUDRATE = int(os.environ.get('SERIAL_BAUDRATE', '115200'))
LOG_HISTORY_SIZE = 500  # Keep last 500 log entries
SERIAL_RESPONSE_TIMEOUT = 0.05  # Seconds to wait for Arduino response
SERIAL_READ_INTERVAL = 0.1  # Seconds between serial read checks
SERIAL_INIT_DELAY = 2.0  # Seconds to wait after opening serial for Arduino reset

# Global state
ser: Optional[serial.Serial] = None
connected_clients: Set = set()
log_history: deque = deque(maxlen=LOG_HISTORY_SIZE)
serial_status = {"connected": False, "port": None, "last_error": None}
command_stats = {"sent": 0, "failed": 0, "last_command": None, "last_time": None}

def create_log_entry(level: str, source: str, message: str, data: dict = None) -> dict:
    """Create a structured log entry."""
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
    """Broadcast a log entry to all connected clients."""
    if not connected_clients:
        return
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
    """Log a message and broadcast to clients."""
    # Log locally
    log_func = getattr(logger, level.lower(), logger.info)
    log_func(f"[{source}] {message}")
    
    # Create entry and broadcast
    entry = create_log_entry(level, source, message, data)
    await broadcast_log(entry)

def find_usb_ports() -> list:
    """Find all available USB serial ports."""
    ports = []
    
    # Method 1: Use pyserial's list_ports
    try:
        for port in serial.tools.list_ports.comports():
            ports.append({
                "device": port.device,
                "description": port.description,
                "hwid": port.hwid,
                "vid": port.vid,
                "pid": port.pid
            })
    except Exception as e:
        logger.warning(f"Failed to list ports via pyserial: {e}")
    
    # Method 2: Check common device paths
    common_ports = [
        '/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyUSB2', '/dev/ttyUSB3',
        '/dev/ttyACM0', '/dev/ttyACM1', '/dev/ttyACM2', '/dev/ttyACM3',
        '/dev/ttyAMA0', '/dev/ttyAMA1',
        '/dev/serial0', '/dev/serial1'
    ]
    
    existing_devices = set(p["device"] for p in ports)
    for port_path in common_ports:
        if port_path not in existing_devices and os.path.exists(port_path):
            ports.append({
                "device": port_path,
                "description": "Found via filesystem",
                "hwid": None,
                "vid": None,
                "pid": None
            })
    
    return ports

async def init_serial() -> Optional[serial.Serial]:
    """Initialize serial connection to Arduino with auto-detection."""
    global ser, serial_status
    
    # Close existing connection if any
    if ser and ser.is_open:
        try:
            ser.close()
        except Exception:
            pass
        ser = None
    
    # Find available ports
    available_ports = find_usb_ports()
    await log_and_broadcast("INFO", "SERIAL", f"Found {len(available_ports)} USB ports", 
                           {"ports": [p["device"] for p in available_ports]})
    
    for port_info in available_ports:
        await log_and_broadcast("DEBUG", "SERIAL", f"Port details: {port_info['device']}", port_info)
    
    # Determine which ports to try
    if SERIAL_PORT:
        ports_to_try = [SERIAL_PORT]
        await log_and_broadcast("INFO", "SERIAL", f"Using configured port: {SERIAL_PORT}")
    else:
        # Prioritize Arduino-like devices (ACM first, then USB)
        ports_to_try = sorted([p["device"] for p in available_ports], 
                             key=lambda x: (0 if 'ACM' in x else 1 if 'USB' in x else 2))
        await log_and_broadcast("INFO", "SERIAL", f"Auto-detecting port from: {ports_to_try}")
    
    for port in ports_to_try:
        try:
            await log_and_broadcast("INFO", "SERIAL", f"Trying to connect to {port} at {SERIAL_BAUDRATE} baud...")
            ser = serial.Serial(port, SERIAL_BAUDRATE, timeout=1)
            
            # Wait a bit for Arduino to reset
            await asyncio.sleep(SERIAL_INIT_DELAY)
            
            # Flush any garbage
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            
            serial_status = {"connected": True, "port": port, "last_error": None}
            await log_and_broadcast("INFO", "SERIAL", f"✅ Connected to serial port: {port}", 
                                   {"port": port, "baudrate": SERIAL_BAUDRATE})
            return ser
            
        except (serial.SerialException, OSError) as e:
            error_msg = str(e)
            await log_and_broadcast("WARNING", "SERIAL", f"❌ Could not open {port}: {error_msg}")
            serial_status = {"connected": False, "port": None, "last_error": error_msg}
    
    await log_and_broadcast("ERROR", "SERIAL", "No serial port available. Commands will be logged only.")
    return None

async def send_command(cmd: str, websocket=None) -> bool:
    """Send command to Arduino via serial."""
    global ser, command_stats
    
    # Clean the command
    cmd = cmd.strip()
    if not cmd:
        return False
    
    command_stats["last_command"] = cmd
    command_stats["last_time"] = datetime.now().isoformat()
    
    # Log the command
    await log_and_broadcast("INFO", "COMMAND", f"📤 Sending: {cmd}", 
                           {"command": cmd, "serial_connected": ser is not None and ser.is_open})
    
    # Send via serial if available
    if ser and ser.is_open:
        try:
            data = f"{cmd}\n".encode()
            bytes_written = ser.write(data)
            ser.flush()
            command_stats["sent"] += 1
            await log_and_broadcast("DEBUG", "SERIAL", f"✅ Wrote {bytes_written} bytes to serial", 
                                   {"command": cmd, "bytes": bytes_written})
            
            # Try to read response (non-blocking)
            await asyncio.sleep(SERIAL_RESPONSE_TIMEOUT)
            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting).decode('utf-8', errors='replace').strip()
                if response:
                    await log_and_broadcast("INFO", "SERIAL", f"📥 Arduino response: {response}", 
                                           {"response": response})
            
            return True
        except serial.SerialException as e:
            error_msg = str(e)
            command_stats["failed"] += 1
            await log_and_broadcast("ERROR", "SERIAL", f"❌ Serial write error: {error_msg}")
            # Try to reconnect
            await init_serial()
            return False
    else:
        command_stats["failed"] += 1
        await log_and_broadcast("WARNING", "COMMAND", f"⚠️ No serial connection - command logged only: {cmd}")
        return False

async def read_serial_data():
    """Background task to read data from serial port."""
    global ser
    while True:
        try:
            if ser and ser.is_open and ser.in_waiting > 0:
                data = ser.read(ser.in_waiting).decode('utf-8', errors='replace').strip()
                if data:
                    for line in data.split('\n'):
                        line = line.strip()
                        if line:
                            await log_and_broadcast("INFO", "ARDUINO", f"📥 {line}", {"raw": line})
        except serial.SerialException as e:
            await log_and_broadcast("ERROR", "SERIAL", f"Serial read error: {e}")
            await init_serial()
        except Exception as e:
            await log_and_broadcast("ERROR", "SERIAL", f"Unexpected error reading serial: {e}")
        
        await asyncio.sleep(SERIAL_READ_INTERVAL)

async def handle_connection(websocket):
    """Handle incoming WebSocket connections."""
    client_addr = websocket.remote_address
    connected_clients.add(websocket)
    
    await log_and_broadcast("INFO", "WEBSOCKET", f"🔌 Client connected: {client_addr}", 
                           {"address": str(client_addr), "total_clients": len(connected_clients)})
    
    # Send current status to new client
    status_msg = json.dumps({
        "type": "status",
        "serial": serial_status,
        "stats": command_stats,
        "clients": len(connected_clients)
    })
    await websocket.send(status_msg)
    
    # Send log history
    history_msg = json.dumps({
        "type": "history",
        "entries": list(log_history)
    })
    await websocket.send(history_msg)
    
    try:
        async for message in websocket:
            try:
                # Try to parse as JSON first
                try:
                    data = json.loads(message)
                    msg_type = data.get("type", "command")
                    
                    if msg_type == "command":
                        cmd = data.get("cmd", data.get("command", "")).strip()
                    elif msg_type == "ping":
                        await websocket.send(json.dumps({"type": "pong", "time": time.time()}))
                        continue
                    elif msg_type == "status":
                        status_msg = json.dumps({
                            "type": "status",
                            "serial": serial_status,
                            "stats": command_stats,
                            "clients": len(connected_clients)
                        })
                        await websocket.send(status_msg)
                        continue
                    elif msg_type == "reconnect_serial":
                        await log_and_broadcast("INFO", "SERIAL", "🔄 Manual serial reconnection requested")
                        await init_serial()
                        continue
                    else:
                        cmd = ""
                except json.JSONDecodeError:
                    # Treat as plain command
                    cmd = message.strip()
                
                if cmd:
                    success = await send_command(cmd, websocket)
                    # Echo back confirmation
                    response = json.dumps({
                        "type": "command_result",
                        "command": cmd,
                        "success": success,
                        "serial_connected": serial_status["connected"]
                    })
                    await websocket.send(response)
                    
            except Exception as e:
                await log_and_broadcast("ERROR", "WEBSOCKET", f"Error processing message: {e}")
                
    except websockets.exceptions.ConnectionClosed:
        pass
    except Exception as e:
        await log_and_broadcast("ERROR", "WEBSOCKET", f"Error handling client {client_addr}: {e}")
    finally:
        connected_clients.discard(websocket)
        await log_and_broadcast("INFO", "WEBSOCKET", f"🔌 Client disconnected: {client_addr}", 
                               {"total_clients": len(connected_clients)})

async def periodic_status():
    """Periodically check and broadcast status."""
    global ser
    reconnect_attempts = 0
    max_reconnect_wait = 30
    
    while True:
        await asyncio.sleep(5)
        
        # Broadcast current status to all clients
        if connected_clients:
            status_msg = json.dumps({
                "type": "status",
                "serial": serial_status,
                "stats": command_stats,
                "clients": len(connected_clients)
            })
            disconnected = set()
            for client in connected_clients:
                try:
                    await client.send(status_msg)
                except Exception:
                    disconnected.add(client)
            connected_clients.difference_update(disconnected)
        
        # Check serial connection
        if ser:
            try:
                if not ser.is_open:
                    await log_and_broadcast("WARNING", "SERIAL", "Serial port closed unexpectedly, reconnecting...")
                    reconnect_attempts = 0
                    await init_serial()
            except Exception:
                await log_and_broadcast("WARNING", "SERIAL", "Serial connection lost, reconnecting...")
                reconnect_attempts = 0
                await init_serial()
        else:
            reconnect_attempts += 1
            wait_time = min(5 * reconnect_attempts, max_reconnect_wait)
            
            if reconnect_attempts <= 3 or reconnect_attempts % 6 == 0:
                await log_and_broadcast("DEBUG", "SERIAL", f"Attempting to find serial port (attempt {reconnect_attempts}, waiting {wait_time}s)...")
            
            if reconnect_attempts > 1:
                await asyncio.sleep(wait_time)
            
            result = await init_serial()
            if result:
                reconnect_attempts = 0
                await log_and_broadcast("INFO", "SERIAL", "Serial port reconnected successfully")

async def main():
    """Main entry point."""
    await log_and_broadcast("INFO", "SYSTEM", "🚀 Monte Bot Serial Bridge starting...")
    await log_and_broadcast("INFO", "SYSTEM", f"WebSocket port: {WEBSOCKET_PORT}, Serial baudrate: {SERIAL_BAUDRATE}")
    
    # List USB devices
    ports = find_usb_ports()
    if ports:
        await log_and_broadcast("INFO", "SYSTEM", f"Available USB devices: {[p['device'] for p in ports]}")
    else:
        await log_and_broadcast("WARNING", "SYSTEM", "No USB serial devices found")
    
    # Initialize serial
    await init_serial()
    
    # Start WebSocket server
    await log_and_broadcast("INFO", "WEBSOCKET", f"WebSocket server listening on ws://{WEBSOCKET_HOST}:{WEBSOCKET_PORT}")
    
    async with websockets.serve(handle_connection, WEBSOCKET_HOST, WEBSOCKET_PORT):
        # Start background tasks
        asyncio.create_task(read_serial_data())
        asyncio.create_task(periodic_status())
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    finally:
        if ser and ser.is_open:
            ser.close()
SERIALEOF
  chmod 755 "${SERIAL_BRIDGE_SCRIPT}"
}

write_serial_service() {
  cat <<EOF >"${SERIAL_SERVICE_FILE}"
[Unit]
Description=Monte Bot Serial Bridge (WebSocket to Arduino)
After=network.target
StartLimitIntervalSec=300
StartLimitBurst=10

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/python3 ${SERIAL_BRIDGE_SCRIPT}
Restart=always
RestartSec=3
TimeoutStartSec=60
StandardOutput=journal
StandardError=journal
User=root
Group=dialout
# Empty SERIAL_PORT enables auto-detection of serial devices
Environment=SERIAL_PORT=
Environment=SERIAL_BAUDRATE=115200

[Install]
WantedBy=multi-user.target
EOF
}

update_web_page() {
  # Use the external script to create web pages
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
  echo "║   MONTE BOT - SETUP COMPLETO (ULTRA-LOW LATENCY MODE)        ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "⚡ CONFIGURAÇÃO: Ultra-Baixa Latência (300-500ms)"
  echo "📺 RESOLUÇÃO: 854x480 (480p)"
  echo "🎥 BITRATE: 3Mbps"
  echo "📦 SEGMENTOS: 0.2s (mínimo)"
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
  echo "║                  INSTALAÇÃO CONCLUÍDA!                        ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "📋 PRÓXIMOS PASSOS:"
  echo "   1. Reinicie o Raspberry Pi:"
  echo "      sudo reboot"
  echo ""
  echo "   2. Após reiniciar, verifique o serviço:"
  echo "      sudo systemctl status rpicam-hls.service"
  echo ""
  echo "   3. Teste no navegador:"
  echo "      http://$(hostname -I | awk '{print $1}')/"
  echo "      (Limpe o cache: Ctrl+Shift+R)"
  echo ""
  echo "⚡ LATÊNCIA ESPERADA: 300-500ms (quase tempo real!)"
  echo ""
}

main "$@"
