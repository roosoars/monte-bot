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
  # Raspberry Pi não possui um RTC de hardware, então o relógio pode estar incorreto
  # após a inicialização se o NTP ainda não sincronizou. Isso causa falha no apt-get update
  # com erros "Release file not valid yet".
  echo "[INFO] Verificando sincronização do relógio do sistema..."

  # Verificar se o horário do sistema está obviamente errado (antes de 2020)
  # Usando 2020 como ano mínimo seguro, pois qualquer instalação razoável do
  # Raspberry Pi OS seria de 2020 ou posterior.
  local current_year
  current_year=$(date +%Y)
  if [[ ${current_year} -lt 2020 ]]; then
    echo "[AVISO] O relógio do sistema parece estar incorreto (ano: ${current_year}). Tentando sincronizar..."
  fi

  # Habilitar sincronização NTP via timedatectl (funciona com systemd-timesyncd)
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true 2>/dev/null || true
  fi

  # Tentar forçar sincronização imediata com systemd-timesyncd
  if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
    systemctl restart systemd-timesyncd 2>/dev/null || true
  fi

  # Aguardar sincronização do horário (até 30 segundos)
  local max_wait=30
  local waited=0
  while [[ ${waited} -lt ${max_wait} ]]; do
    # Verificar se o horário está sincronizado via timedatectl
    if command -v timedatectl >/dev/null 2>&1; then
      local sync_status
      sync_status=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "no")
      if [[ "${sync_status}" == "yes" ]]; then
        echo "[INFO] Relógio do sistema sincronizado com sucesso."
        return 0
      fi
    fi

    # Alternativa: verificar se o ano agora está razoável (2020 ou posterior)
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

  # Se ainda não sincronizou, tentar usar ntpdate como fallback
  if command -v ntpdate >/dev/null 2>&1; then
    echo "[INFO] Tentando sincronizar relógio usando ntpdate..."
    ntpdate -u pool.ntp.org 2>/dev/null || ntpdate -u time.google.com 2>/dev/null || true
  fi

  # Verificação final
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

# Variables to hold error file paths (set when pipeline starts)
RPICAM_ERR=""
FFMPEG_ERR=""
PIPELINE_PID=""

cleanup() {
  log_info "Cleaning up stream files..."
  # Kill the pipeline if it's still running
  if [[ -n "${PIPELINE_PID}" ]]; then
    kill -TERM ${PIPELINE_PID} 2>/dev/null || true
    wait ${PIPELINE_PID} 2>/dev/null || true
  fi
  find "${STREAM_DIR}" -type f \( -name '*.ts' -o -name '*.m3u8' \) -delete || true
  # Clean up error files if they exist
  if [[ -n "${RPICAM_ERR}" && -f "${RPICAM_ERR}" ]]; then
    rm -f "${RPICAM_ERR}" || true
  fi
  if [[ -n "${FFMPEG_ERR}" && -f "${FFMPEG_ERR}" ]]; then
    rm -f "${FFMPEG_ERR}" || true
  fi
}
trap cleanup EXIT

# Wait for camera to be ready
wait_for_camera() {
  log_info "Waiting for camera to be ready..."
  local max_wait=60
  local waited=0
  
  # Log initial diagnostic information
  log_info "Initial diagnostics:"
  log_info "  - Available video devices: $(ls /dev/video* 2>/dev/null || echo 'none')"
  
  while [[ ${waited} -lt ${max_wait} ]]; do
    # Check if libcamera can detect a camera (preferred method on Bookworm)
    if command -v libcamera-hello >/dev/null 2>&1; then
      local libcamera_output
      libcamera_output=$(libcamera-hello --list-cameras 2>&1 || true)
      if echo "${libcamera_output}" | grep -q -E "^[0-9]+\s*:"; then
        log_info "Camera detected via libcamera after ${waited} seconds"
        # Log only the first camera line to avoid verbose output
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
      # Additional check: verify the device is a camera and not just a dummy device
      if command -v v4l2-ctl >/dev/null 2>&1; then
        if v4l2-ctl --list-devices 2>/dev/null | grep -q -i "camera\|unicam\|bcm\|imx\|ov5647"; then
          log_info "Video device found via v4l2-ctl after ${waited} seconds"
          return 0
        fi
      else
        # If v4l2-ctl is not available, accept /dev/video0 as-is after minimum wait
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
      # Log diagnostic info every 10 seconds
      log_info "Checking: ls /dev/video* = $(ls /dev/video* 2>/dev/null || echo 'none')"
    fi
  done
  
  # Cache diagnostic info to avoid delays in error reporting
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

# Ultra-low latency streaming settings
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-640}"
STREAM_HEIGHT="${STREAM_HEIGHT:-480}"
STREAM_BITRATE="${STREAM_BITRATE:-1500000}"
# Keyframe every 15 frames (0.5s at 30fps) for faster seeking
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-15}"
# Ultra-short segments for minimal latency (0.2 seconds)
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.2}"
# Minimal playlist size for faster updates
HLS_LIST_SIZE="${HLS_LIST_SIZE:-3}"

# Timeout for waiting for stream files to be created
STREAM_STARTUP_TIMEOUT="${STREAM_STARTUP_TIMEOUT:-30}"

log_info "Starting camera stream service"
log_info "Settings: ${STREAM_WIDTH}x${STREAM_HEIGHT} @ ${STREAM_FRAMERATE}fps, bitrate=${STREAM_BITRATE}"

# Wait for camera to be ready
if ! wait_for_camera; then
  log_error "Failed to detect camera, exiting"
  exit 1
fi

log_info "Starting rpicam-vid and ffmpeg pipeline..."

# Additional delay to ensure camera is fully initialized after detection
sleep 2

# Function to verify that the HLS stream is actually being created
verify_stream_startup() {
  local max_wait=${STREAM_STARTUP_TIMEOUT}
  local waited=0
  local m3u8_file="${STREAM_DIR}/index.m3u8"
  
  log_info "Waiting for HLS stream to start (timeout: ${max_wait}s)..."
  
  while [[ ${waited} -lt ${max_wait} ]]; do
    # Check if m3u8 file exists and has content
    if [[ -f "${m3u8_file}" && -s "${m3u8_file}" ]]; then
      # Also check if at least one .ts segment exists
      if ls "${STREAM_DIR}"/segment_*.ts >/dev/null 2>&1; then
        log_info "HLS stream started successfully (m3u8 and segments detected after ${waited}s)"
        return 0
      fi
    fi
    
    sleep 1
    waited=$((waited + 1))
    if [[ $((waited % 5)) -eq 0 ]]; then
      log_info "Still waiting for stream files... (${waited}/${max_wait}s)"
      # Check what's in the stream directory
      local stream_files
      stream_files=$(ls -la "${STREAM_DIR}" 2>/dev/null || echo "directory not accessible")
      log_info "Stream directory contents: ${stream_files}"
    fi
  done
  
  log_error "Stream files not created within ${max_wait} seconds"
  log_error "Expected: ${m3u8_file} with content and .ts segment files"
  log_error "Stream directory contents: $(ls -la "${STREAM_DIR}" 2>/dev/null || echo 'directory not accessible')"
  return 1
}

# Run the pipeline with error handling
# Note: We redirect rpicam-vid stderr to a temporary file for better debugging
RPICAM_ERR=$(mktemp /tmp/rpicam_err.XXXXXX)
FFMPEG_ERR=$(mktemp /tmp/ffmpeg_err.XXXXXX)

# Start the pipeline in the background so we can monitor it
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
  -o - \
  2>"${RPICAM_ERR}" | ffmpeg \
      -y \
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
      "${STREAM_DIR}/index.m3u8" \
      2>"${FFMPEG_ERR}" &

PIPELINE_PID=$!
log_info "Pipeline started with PID ${PIPELINE_PID}"

# Wait a moment for the pipeline to initialize
sleep 2

# Check if pipeline is still running
if ! kill -0 ${PIPELINE_PID} 2>/dev/null; then
  wait ${PIPELINE_PID} 2>/dev/null || true
  PIPELINE_EXIT=$?
  log_error "Pipeline exited immediately with code ${PIPELINE_EXIT}"
  if [[ -f "${RPICAM_ERR}" && -s "${RPICAM_ERR}" ]]; then
    log_error "rpicam-vid errors: $(cat "${RPICAM_ERR}")"
  fi
  if [[ -f "${FFMPEG_ERR}" && -s "${FFMPEG_ERR}" ]]; then
    log_error "ffmpeg errors: $(cat "${FFMPEG_ERR}")"
  fi
  log_error "Common causes of pipeline failure:"
  log_error "  - Camera not connected or not enabled"
  log_error "  - Another process is using the camera"
  log_error "  - Insufficient permissions (ensure script runs as root or video group)"
  log_error "  - ffmpeg not installed or misconfigured"
  log_error "To diagnose, run: rpicam-vid --timeout 5000 -o test.h264"
  rm -f "${RPICAM_ERR}" "${FFMPEG_ERR}" 2>/dev/null || true
  exit ${PIPELINE_EXIT}
fi

# Verify that stream files are actually being created
if ! verify_stream_startup; then
  log_error "Stream verification failed - pipeline is running but not producing output"
  # Kill the pipeline since it's not working
  kill -TERM ${PIPELINE_PID} 2>/dev/null || true
  wait ${PIPELINE_PID} 2>/dev/null || true
  if [[ -f "${RPICAM_ERR}" && -s "${RPICAM_ERR}" ]]; then
    log_error "rpicam-vid errors: $(cat "${RPICAM_ERR}")"
  fi
  if [[ -f "${FFMPEG_ERR}" && -s "${FFMPEG_ERR}" ]]; then
    log_error "ffmpeg errors: $(cat "${FFMPEG_ERR}")"
  fi
  log_error "The camera may be producing invalid video data or ffmpeg may not be receiving it"
  log_error "To diagnose:"
  log_error "  1. Test camera: rpicam-vid --timeout 5000 -o /tmp/test.h264"
  log_error "  2. Test ffmpeg: ffmpeg -f h264 -i /tmp/test.h264 -c:v copy /tmp/test.mp4"
  rm -f "${RPICAM_ERR}" "${FFMPEG_ERR}" 2>/dev/null || true
  exit 1
fi

log_info "Stream is running successfully, waiting for pipeline..."

# Wait for the pipeline (it should run indefinitely unless there's an error)
wait ${PIPELINE_PID}
PIPELINE_EXIT=$?

if [[ ${PIPELINE_EXIT} -ne 0 ]]; then
  log_error "Pipeline exited with code ${PIPELINE_EXIT}"
  if [[ -f "${RPICAM_ERR}" && -s "${RPICAM_ERR}" ]]; then
    log_error "rpicam-vid errors: $(cat "${RPICAM_ERR}")"
  fi
  if [[ -f "${FFMPEG_ERR}" && -s "${FFMPEG_ERR}" ]]; then
    log_error "ffmpeg errors: $(cat "${FFMPEG_ERR}")"
  fi
  log_error "Common causes of pipeline failure:"
  log_error "  - Camera not connected or not enabled"
  log_error "  - Another process is using the camera"
  log_error "  - Insufficient permissions (ensure script runs as root or video group)"
  log_error "  - ffmpeg not installed or misconfigured"
  log_error "To diagnose, run: rpicam-vid --timeout 5000 -o test.h264"
  rm -f "${RPICAM_ERR}" "${FFMPEG_ERR}" 2>/dev/null || true
  exit ${PIPELINE_EXIT}
fi

# Clear error files
rm -f "${RPICAM_ERR}" "${FFMPEG_ERR}" 2>/dev/null || true
RPICAM_ERR=""
FFMPEG_ERR=""
EOF
  chmod 755 "${CAMERA_RUNNER}"
}

write_systemd_service() {
  cat <<EOF >"${SERVICE_FILE}"
[Unit]
Description=Streaming da câmera Raspberry Pi (rpicam + HLS)
After=network.target nginx.service multi-user.target
Wants=nginx.service
# Wait for the system to be fully booted before starting camera service
After=systemd-udev-settle.service
Wants=systemd-udev-settle.service
StartLimitIntervalSec=600
StartLimitBurst=10

[Service]
Type=simple
# Longer initial delay to ensure camera drivers are fully loaded
ExecStartPre=/bin/sleep 5
ExecStart=${CAMERA_RUNNER}
Restart=always
RestartSec=10
# Longer timeout since camera detection can take up to 60 seconds
TimeoutStartSec=120
StandardOutput=journal
StandardError=journal
# Environment variables for camera stream configuration
Environment=STREAM_FRAMERATE=30
Environment=STREAM_WIDTH=640
Environment=STREAM_HEIGHT=480

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
    max_reconnect_wait = 30  # Max seconds between reconnect attempts
    
    while True:
        await asyncio.sleep(5)  # Every 5 seconds for faster response
        
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
            # Try to reconnect with exponential backoff
            reconnect_attempts += 1
            wait_time = min(5 * reconnect_attempts, max_reconnect_wait)
            
            if reconnect_attempts <= 3 or reconnect_attempts % 6 == 0:  # Log every 30 seconds after initial attempts
                await log_and_broadcast("DEBUG", "SERIAL", f"Attempting to find serial port (attempt {reconnect_attempts}, waiting {wait_time}s)...")
            
            # Wait before reconnection attempt (exponential backoff)
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

  # Legacy page code (kept for reference, not executed)
  cat <<'EOF' >/var/www/html/index.html.old
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Rastreamento ao Vivo</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' ry='12' fill='%23002233'/%3E%3Cpath d='M16 42l8-20h4l8 20h-4l-1.8-5.2h-9.2L20 42zm7.4-8.4h6.4L27 24.4zM40 22h4v20h-4z' fill='%2300c6ff'/%3E%3C/svg%3E" />
  <style>
    :root {
      color-scheme: dark;
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: radial-gradient(circle at top, #0f2c48, #03070d 75%);
      font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #e2f3ff;
      padding: 34px 18px;
    }
    main {
      width: min(1080px, 100%);
      display: grid;
      gap: 30px;
    }
    header {
      text-align: center;
      display: grid;
      gap: 8px;
    }
    h1 {
      margin: 0;
      font-size: clamp(1.8rem, 4vw, 2.7rem);
      letter-spacing: 0.18rem;
      text-transform: uppercase;
    }
    #subtitle {
      margin: 0;
      color: rgba(226, 243, 255, 0.75);
      font-size: 1rem;
    }
    #help-text {
      margin: 0;
      color: rgba(226, 243, 255, 0.6);
      font-size: 0.9rem;
    }
    #video-wrapper {
      position: relative;
      background: rgba(0, 0, 0, 0.7);
      border: 1px solid rgba(0, 140, 255, 0.38);
      border-radius: 18px;
      overflow: hidden;
      box-shadow: 0 24px 42px rgba(0, 0, 0, 0.5);
    }
    #video-wrapper video,
    #video-wrapper canvas {
      display: block;
      width: 100%;
    }
    #cameraStream {
      height: auto;
      background: #000;
    }
    #overlay {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
    }
    #controls {
      display: grid;
      gap: 16px;
      justify-items: center;
    }
    #startTracking {
      background: linear-gradient(135deg, #00c6ff, #0072ff);
      color: #032131;
      font-weight: 600;
      letter-spacing: 0.06rem;
      text-transform: uppercase;
      border: none;
      border-radius: 999px;
      padding: 14px 28px;
      cursor: pointer;
      min-width: 240px;
      transition: transform 0.2s ease, box-shadow 0.2s ease, opacity 0.2s ease;
    }
    #startTracking:hover:not(:disabled) {
      transform: translateY(-2px);
      box-shadow: 0 12px 24px rgba(0, 153, 255, 0.35);
    }
    #startTracking:disabled {
      cursor: not-allowed;
      opacity: 0.6;
    }
    #status {
      margin: 0;
      text-align: center;
      font-size: 1rem;
      color: rgba(226, 243, 255, 0.78);
    }
    #status strong {
      color: #7fe1ff;
    }
    #status.error {
      color: #ff867c;
    }
    #tracking-info {
      display: grid;
      background: rgba(0, 14, 30, 0.45);
      border: 1px solid rgba(0, 140, 255, 0.25);
      border-radius: 14px;
      padding: 18px 22px;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
      gap: 16px;
    }
    #tracking-info p {
      margin: 0;
      font-size: 0.95rem;
      line-height: 1.6;
      color: rgba(226, 243, 255, 0.85);
    }
    #tracking-info strong {
      color: #7fe1ff;
    }
    .badge {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 999px;
      background: rgba(0, 153, 255, 0.18);
      border: 1px solid rgba(0, 153, 255, 0.35);
      color: #7fe1ff;
      font-size: 0.8rem;
      letter-spacing: 0.05rem;
      text-transform: uppercase;
    }
    #targetSnapshotWrapper {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 18px;
      flex-wrap: wrap;
      padding-top: 4px;
    }
    #targetSnapshot {
      width: 180px;
      height: auto;
      max-width: 100%;
      object-fit: cover;
      border-radius: 12px;
      border: 1px solid rgba(0, 153, 255, 0.4);
      box-shadow: 0 12px 24px rgba(0, 0, 0, 0.35);
      background: rgba(0, 0, 0, 0.7);
      aspect-ratio: 3 / 4;
    }
    #snapshotStatus {
      max-width: 320px;
      color: rgba(226, 243, 255, 0.75);
      font-size: 0.9rem;
      line-height: 1.5;
      text-align: left;
    }
    @media (max-width: 720px) {
      #startTracking {
        width: 100%;
      }
      #targetSnapshotWrapper {
        justify-content: center;
      }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <span class="badge">Monte Bot</span>
      <h1>Rastreamento ao Vivo</h1>
      <p id="subtitle">Conecte-se ao hotspot, assista ao stream e acione o modo perseguição da pessoa à frente.</p>
      <p id="help-text">Posicione a pessoa centralizada. Após a contagem, uma imagem de referência será capturada para manter o rastreamento.</p>
    </header>

    <section id="video-wrapper">
      <video id="cameraStream" autoplay playsinline muted controls poster="">
        Seu navegador não suporta vídeo.
      </video>
      <canvas id="overlay" width="1280" height="720"></canvas>
    </section>

    <section id="controls">
      <button id="startTracking">Ativar Rastreamento</button>
      <p id="status">Iniciando stream da câmera...</p>
    </section>

    <section id="tracking-info">
      <p id="movementOutput"><strong>Movimento previsto:</strong> aguardando ativação.</p>
      <p id="clothingOutput"><strong>Traje dominante:</strong> indefinido.</p>
      <div id="targetSnapshotWrapper">
        <img id="targetSnapshot" alt="Referência do alvo" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==" />
        <p id="snapshotStatus">Nenhuma referência capturada ainda. Fique de frente para a câmera durante a contagem regressiva.</p>
      </div>
    </section>
  </main>

  <script type="module">
    const video = document.getElementById('cameraStream');
    const overlay = document.getElementById('overlay');
    const overlayCtx = overlay.getContext('2d');
    const analysisCanvas = document.createElement('canvas');
    const analysisCtx = analysisCanvas.getContext('2d', { willReadFrequently: true }) || analysisCanvas.getContext('2d');
    const snapshotCanvas = document.createElement('canvas');
    const snapshotCtx = snapshotCanvas.getContext('2d');
    const statusEl = document.getElementById('status');
    const startBtn = document.getElementById('startTracking');
    const movementEl = document.getElementById('movementOutput');
    const clothingEl = document.getElementById('clothingOutput');
    const snapshotImg = document.getElementById('targetSnapshot');
    const snapshotStatus = document.getElementById('snapshotStatus');
    const source = 'stream/index.m3u8';
    const PLACEHOLDER_SNAPSHOT = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
    const visionSources = [
      './static/mediapipe/vision_bundle.js',
      'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/vision_bundle.js'
    ];
    const wasmBases = ['static/mediapipe/wasm', 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/wasm'];
    const modelUris = [
      'static/models/efficientdet_lite0.tflite',
      'https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite'
    ];

    let visionModule = null;
    let detector = null;
    let trackingActive = false;
    let lastVideoTime = -1;
    let animationFrameId = 0;
    let frameWidth = 1280;
    let frameHeight = 720;
    let targetProfile = null;
    let bestAreaRatio = 0;
    let previousCenter = null;
    let lostFrames = 0;
    let streamRetryCount = 0;
    const MAX_STREAM_RETRIES = 3;
    const RETRY_DELAY_MS = 2000;

    function updateStatus(message, isError) {
      statusEl.innerHTML = message;
      statusEl.classList.toggle('error', Boolean(isError));
    }

    function getVideoErrorMessage(error) {
      if (!error) return 'Erro desconhecido';
      switch (error.code) {
        case MediaError.MEDIA_ERR_ABORTED:
          return 'Carregamento do vídeo foi cancelado';
        case MediaError.MEDIA_ERR_NETWORK:
          return 'Erro de rede ao carregar o vídeo. Execute: sudo systemctl restart rpicam-hls';
        case MediaError.MEDIA_ERR_DECODE:
          return 'Erro ao decodificar o vídeo. A câmera pode não estar gerando frames válidos';
        case MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED:
          return 'Stream não encontrado. O serviço de câmera pode não estar rodando. Execute: sudo systemctl restart rpicam-hls';
        default:
          return 'Erro desconhecido: código ' + error.code;
      }
    }

    function ensureVideoSizing() {
      const width = video.videoWidth || 1920;
      const height = video.videoHeight || 1080;
      frameWidth = width;
      frameHeight = height;
      if (overlay.width !== width || overlay.height !== height) {
        overlay.width = width;
        overlay.height = height;
      }
      analysisCanvas.width = width;
      analysisCanvas.height = height;
    }

    function updateAnalysisFrame() {
      if (!analysisCtx || analysisCanvas.width === 0 || analysisCanvas.height === 0) {
        return false;
      }
      analysisCtx.drawImage(video, 0, 0, analysisCanvas.width, analysisCanvas.height);
      return true;
    }

    function loadStream() {
      if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = source;
        video.addEventListener('loadeddata', () => {
          streamRetryCount = 0;
          updateStatus('Transmissão ao vivo ativa.', false);
          ensureVideoSizing();
        });
        video.addEventListener('error', (e) => {
          const errorMsg = getVideoErrorMessage(video.error);
          console.error('[MonteBot] Erro no stream:', errorMsg);
          if (streamRetryCount < MAX_STREAM_RETRIES) {
            streamRetryCount++;
            updateStatus('Tentando reconectar ao stream (' + streamRetryCount + '/' + MAX_STREAM_RETRIES + ')...', true);
            setTimeout(() => {
              video.src = '';
              video.src = source;
              video.load();
            }, RETRY_DELAY_MS);
          } else {
            updateStatus('Não foi possível iniciar o stream: ' + errorMsg + '. <br><small>Verifique: sudo systemctl status rpicam-hls</small>', true);
          }
        });
        return;
      }

      const script = document.createElement('script');
      script.onload = () => {
        if (typeof Hls === 'undefined') {
          updateStatus('Falha ao carregar hls.js. Tente acessar via Safari/iOS ou conecte-se à internet.', true);
          return;
        }
        if (!Hls.isSupported()) {
          updateStatus('Seu navegador não oferece suporte a HLS.', true);
          return;
        }

        const hls = new Hls({
          enableWorker: true,
          lowLatencyMode: true,
          backBufferLength: 10,
          maxBufferLength: 5
        });
        hls.loadSource(source);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function () {
          streamRetryCount = 0;
          updateStatus('Transmissão ao vivo ativa.', false);
          video.play().catch(() => {});
          ensureVideoSizing();
        });
        hls.on(Hls.Events.ERROR, function (event, data) {
          if (data.fatal) {
            console.error('[MonteBot] Erro HLS fatal:', data.type, data.details);
            if (streamRetryCount < MAX_STREAM_RETRIES) {
              streamRetryCount++;
              updateStatus('Tentando reconectar ao stream (' + streamRetryCount + '/' + MAX_STREAM_RETRIES + ')...', true);
              hls.destroy();
              setTimeout(loadStream, RETRY_DELAY_MS);
            } else {
              updateStatus('Erro fatal no stream: ' + data.type + ' - ' + data.details + '. <br><small>Verifique: sudo systemctl status rpicam-hls</small>', true);
              hls.destroy();
            }
          }
        });
      };
      script.onerror = function () {
        updateStatus('Não foi possível carregar hls.js. Conecte-se à internet ou utilize Safari.', true);
      };
      script.src = 'static/hls.min.js';
      document.body.appendChild(script);
    }

    async function loadVisionModule() {
      if (visionModule) {
        return visionModule;
      }
      for (const src of visionSources) {
        try {
          const mod = await import(src);
          if (mod && mod.FilesetResolver && mod.ObjectDetector) {
            visionModule = mod;
            console.log('[MediaPipe] vision_bundle carregado de', src);
            return visionModule;
          }
        } catch (err) {
          console.warn('[MediaPipe] Falha ao importar', src, err);
        }
      }
      throw new Error('Nenhum vision_bundle disponível.');
    }

    async function ensureDetector() {
      if (detector) {
        return detector;
      }
      let visionApi;
      try {
        visionApi = await loadVisionModule();
      } catch (err) {
        updateStatus('Biblioteca MediaPipe indisponível. Verifique o console.', true);
        throw err;
      }
      updateStatus('Carregando MediaPipe para rastreamento...', false);
      for (const base of wasmBases) {
        for (const model of modelUris) {
          try {
            const fileset = await visionApi.FilesetResolver.forVisionTasks(base);
            const created = await visionApi.ObjectDetector.createFromOptions(fileset, {
              baseOptions: { modelAssetPath: model },
              runningMode: 'VIDEO',
              scoreThreshold: 0.4,
              categoryAllowlist: ['person']
            });
            detector = created;
            updateStatus('MediaPipe pronto. Pessoa será detectada após a contagem regressiva.', false);
            return detector;
          } catch (err) {
            console.warn('[MediaPipe] Falha ao abrir modelo', model, 'via', base, err);
          }
        }
      }
      updateStatus('Não foi possível inicializar o detector. Verifique a conexão e tente novamente.', true);
      throw new Error('Falha ao criar detector MediaPipe');
    }

    function describeColor(r, g, b) {
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const luminance = (max + min) / 2;
      const delta = max - min;
      let hue = 0;
      let saturation = 0;
      if (delta !== 0) {
        saturation = luminance > 127 ? delta / (510 - max - min) : delta / (max + min);
        switch (max) {
          case r:
            hue = ((g - b) / delta) % 6;
            break;
          case g:
            hue = (b - r) / delta + 2;
            break;
          default:
            hue = (r - g) / delta + 4;
        }
        hue *= 60;
        if (hue < 0) hue += 360;
      }
      if (luminance < 40) return 'preto';
      if (luminance > 210 && saturation < 0.2) return 'branco';
      if (saturation < 0.18) return 'cinza';
      if (hue < 20 || hue >= 345) return 'vermelho';
      if (hue < 50) return 'laranja';
      if (hue < 70) return 'amarelo';
      if (hue < 160) return 'verde';
      if (hue < 210) return 'ciano';
      if (hue < 255) return 'azul';
      if (hue < 290) return 'anil';
      if (hue < 345) return 'roxo';
      return 'desconhecido';
    }

    function analyzeClothing(bbox) {
      if (!analysisCtx || !bbox) {
        return { label: 'indisponível', r: 0, g: 0, b: 0 };
      }
      const width = Math.max(1, Math.floor(bbox.width));
      const height = Math.max(1, Math.floor(bbox.height));
      const x = Math.max(0, Math.floor(bbox.originX));
      const y = Math.max(0, Math.floor(bbox.originY));
      if (width <= 0 || height <= 0 || x >= analysisCanvas.width || y >= analysisCanvas.height) {
        return { label: 'indefinido', r: 0, g: 0, b: 0 };
      }
      const sampleWidth = Math.min(width, Math.max(1, analysisCanvas.width - x));
      const sampleHeight = Math.min(height, Math.max(1, analysisCanvas.height - y));
      if (sampleWidth <= 0 || sampleHeight <= 0) {
        return { label: 'indefinido', r: 0, g: 0, b: 0 };
      }
      let imageData;
      try {
        imageData = analysisCtx.getImageData(x, y, sampleWidth, sampleHeight);
      } catch (err) {
        console.warn('[MediaPipe] Não foi possível ler pixels para análise', err);
        return { label: 'indisponível', r: 0, g: 0, b: 0 };
      }
      const data = imageData.data;
      if (!data || !data.length) {
        return { label: 'indefinido', r: 0, g: 0, b: 0 };
      }
      let r = 0;
      let g = 0;
      let b = 0;
      let count = 0;
      const step = Math.max(1, Math.floor(data.length / (4 * 6000)));
      for (let i = 0; i < data.length; i += 4 * step) {
        r += data[i];
        g += data[i + 1];
        b += data[i + 2];
        count++;
      }
      if (count === 0) {
        return { label: 'indefinido', r: 0, g: 0, b: 0 };
      }
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);
      return { label: describeColor(r, g, b), r, g, b };
    }

    function drawOverlay(bbox) {
      overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
      if (!bbox) {
        return;
      }
      overlayCtx.strokeStyle = 'rgba(0, 214, 255, 0.85)';
      overlayCtx.lineWidth = 4;
      overlayCtx.setLineDash([12, 8]);
      overlayCtx.strokeRect(bbox.originX, bbox.originY, bbox.width, bbox.height);
      overlayCtx.setLineDash([]);
      const centerX = bbox.originX + bbox.width / 2;
      const centerY = bbox.originY + bbox.height / 2;
      overlayCtx.fillStyle = 'rgba(0, 214, 255, 0.85)';
      overlayCtx.beginPath();
      overlayCtx.arc(centerX, centerY, 6, 0, Math.PI * 2);
      overlayCtx.fill();
    }

    function computeMovement(bbox) {
      if (!bbox) {
        return 'aguardar.';
      }
      const frameArea = Math.max(1, frameWidth * frameHeight);
      const centerX = bbox.originX + bbox.width / 2;
      const areaRatio = (bbox.width * bbox.height) / frameArea;
      const offset = centerX / frameWidth - 0.5;
      const commands = [];

      if (areaRatio < 0.06) {
        commands.push('andar para frente (alvo distante)');
      } else if (areaRatio > 0.25) {
        commands.push('reduzir velocidade (alvo muito próximo)');
      } else {
        commands.push('manter distância');
      }

      if (offset > 0.12) {
        commands.push(areaRatio < 0.22 ? 'virar para a direita e avançar' : 'virar para a direita');
      } else if (offset < -0.12) {
        commands.push(areaRatio < 0.22 ? 'virar para a esquerda e avançar' : 'virar para a esquerda');
      } else {
        commands.push('seguir em linha reta');
      }

      return commands.join(' + ');
    }

    function colorDistance(a, b) {
      if (!a || !b) {
        return Number.POSITIVE_INFINITY;
      }
      const dr = a.r - b.r;
      const dg = a.g - b.g;
      const db = a.b - b.b;
      return Math.sqrt(dr * dr + dg * dg + db * db) / 442;
    }

    function chooseDetection(detections) {
      if (!detections || detections.length === 0) {
        return null;
      }
      let bestDetection = null;
      let bestProfile = null;
      let bestScore = Number.POSITIVE_INFINITY;
      const hasTarget = Boolean(targetProfile);
      for (const detection of detections) {
        if (!detection.boundingBox) {
          continue;
        }
        const bbox = detection.boundingBox;
        const profile = analyzeClothing(bbox);
        const centerX = bbox.originX + bbox.width / 2;
        const centerY = bbox.originY + bbox.height / 2;
        const areaRatio = (bbox.width * bbox.height) / Math.max(1, frameWidth * frameHeight);
        let score;
        if (!hasTarget) {
          score = -areaRatio;
        } else {
          const colorDiff = colorDistance(profile, targetProfile);
          const centerDist = previousCenter
            ? Math.hypot((centerX - previousCenter.x) / frameWidth, (centerY - previousCenter.y) / frameHeight)
            : 0;
          const areaPenalty = targetProfile.areaRatio
            ? Math.abs(areaRatio - targetProfile.areaRatio) * 12
            : 0;
          score = colorDiff * 1.4 + centerDist * 2.6 + areaPenalty;
        }
        if (score < bestScore) {
          bestScore = score;
          bestDetection = detection;
          bestProfile = Object.assign({ areaRatio }, profile);
        }
      }
      return bestDetection ? { detection: bestDetection, profile: bestProfile } : null;
    }

    function captureSnapshot(bbox) {
      if (!snapshotCtx || !bbox) {
        return;
      }
      const width = Math.max(40, Math.floor(bbox.width));
      const height = Math.max(40, Math.floor(bbox.height));
      snapshotCanvas.width = width;
      snapshotCanvas.height = height;
      try {
        snapshotCtx.drawImage(
          video,
          bbox.originX,
          bbox.originY,
          bbox.width,
          bbox.height,
          0,
          0,
          width,
          height
        );
        const dataUrl = snapshotCanvas.toDataURL('image/jpeg', 0.85);
        snapshotImg.src = dataUrl;
        snapshotStatus.textContent = 'Referência capturada. Mantenha a pessoa com aparência similar para continuar o rastreamento.';
      } catch (err) {
        console.warn('[MediaPipe] Não foi possível capturar snapshot', err);
      }
    }

    function resetTargetState(message) {
      targetProfile = null;
      bestAreaRatio = 0;
      previousCenter = null;
      lostFrames = 0;
      snapshotImg.src = PLACEHOLDER_SNAPSHOT;
      snapshotStatus.textContent = message || 'Nenhuma referência capturada ainda. Fique de frente para a câmera durante a contagem regressiva.';
    }

    function processFrame() {
      if (!trackingActive || !detector) {
        return;
      }
      ensureVideoSizing();
      updateAnalysisFrame();
      const nowInMs = performance.now();
      if (video.currentTime === lastVideoTime) {
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }
      lastVideoTime = video.currentTime;
      let result;
      try {
        result = detector.detectForVideo(video, nowInMs);
      } catch (err) {
        console.error('[MediaPipe] Erro durante detectForVideo', err);
        updateStatus('Erro na detecção. Tentando novamente...', true);
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }
      overlayCtx.clearRect(0, 0, overlay.width, overlay.height);

      const selection = chooseDetection(result && result.detections ? result.detections : []);
      if (!selection) {
        lostFrames += 1;
        if (lostFrames < 30) {
          updateStatus('Rastreamento ativo, aguardando pessoa no enquadramento...', false);
        } else if (lostFrames < 120) {
          updateStatus('Alvo temporariamente fora de vista. Reposicione-se em frente à câmera.', true);
        } else {
          updateStatus('Alvo perdido. Clique novamente para reiniciar ou retorne ao quadro.', true);
        }
        movementEl.innerHTML = '<strong>Movimento previsto:</strong> aguardar.';
        clothingEl.innerHTML = '<strong>Traje dominante:</strong> indefinido.';
        if (lostFrames > 180) {
          resetTargetState('Alvo perdido. Clique em "Ativar Rastreamento" para começar de novo.');
          trackingActive = false;
          startBtn.disabled = false;
          startBtn.textContent = 'Ativar Rastreamento novamente';
        }
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      lostFrames = 0;
      const { detection, profile } = selection;
      const bbox = detection.boundingBox;
      previousCenter = {
        x: bbox.originX + bbox.width / 2,
        y: bbox.originY + bbox.height / 2
      };
      drawOverlay(bbox);
      updateStatus('Pessoa detectada. Rastreamento ativo.', false);

      const movement = computeMovement(bbox);
      movementEl.innerHTML = '<strong>Movimento previsto:</strong> ' + movement + '.';
      clothingEl.innerHTML = '<strong>Traje dominante:</strong> ' + profile.label +
        ' (RGB ' + profile.r + ', ' + profile.g + ', ' + profile.b + ').';

      if (!targetProfile) {
        targetProfile = Object.assign({}, profile);
        bestAreaRatio = profile.areaRatio || 0;
        captureSnapshot(bbox);
      } else {
        const blend = 0.3;
        targetProfile.r = Math.round(targetProfile.r * (1 - blend) + profile.r * blend);
        targetProfile.g = Math.round(targetProfile.g * (1 - blend) + profile.g * blend);
        targetProfile.b = Math.round(targetProfile.b * (1 - blend) + profile.b * blend);
        targetProfile.areaRatio = targetProfile.areaRatio
          ? targetProfile.areaRatio * (1 - blend) + (profile.areaRatio || 0) * blend
          : profile.areaRatio || targetProfile.areaRatio;
        targetProfile.label = profile.label;
        if (profile.areaRatio && profile.areaRatio > bestAreaRatio * 1.1 && colorDistance(profile, targetProfile) < 0.4) {
          bestAreaRatio = profile.areaRatio;
          captureSnapshot(bbox);
        }
      }

      console.log('[MonteBot][Rastreamento]', movement);
      animationFrameId = requestAnimationFrame(processFrame);
    }

    async function startTracking() {
      if (trackingActive) {
        return;
      }
      startBtn.disabled = true;
      startBtn.textContent = 'Preparando...';
      resetTargetState('Capturando referência em breve. Mantenha a pessoa centralizada durante a contagem regressiva.');
      updateStatus('Preparando rastreamento...', false);
      let detectorPromise;
      try {
        detectorPromise = ensureDetector();
      } catch (err) {
        console.error(err);
        trackingActive = false;
        startBtn.disabled = false;
        startBtn.textContent = 'Ativar Rastreamento';
        updateStatus('Não foi possível ativar o rastreamento. Veja o console para detalhes.', true);
        return;
      }

      try {
        for (let seconds = 5; seconds > 0; seconds--) {
          updateStatus('Iniciando detecção em <strong>' + seconds + '</strong> segundo' + (seconds === 1 ? '' : 's') + '...', false);
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
        await detectorPromise;
      } catch (err) {
        console.error(err);
        trackingActive = false;
        startBtn.disabled = false;
        startBtn.textContent = 'Ativar Rastreamento';
        updateStatus('Não foi possível ativar o rastreamento. Veja o console para detalhes.', true);
        return;
      }

      trackingActive = true;
      updateStatus('Rastreamento ativo. Aguardando a pessoa entrar no quadro.', false);
      movementEl.innerHTML = '<strong>Movimento previsto:</strong> aguardando pessoa.';
      clothingEl.innerHTML = '<strong>Traje dominante:</strong> indefinido.';
      lastVideoTime = -1;
      animationFrameId = requestAnimationFrame(processFrame);
      startBtn.textContent = 'Rastreamento em andamento';
    }

    video.addEventListener('loadedmetadata', ensureVideoSizing);
    window.addEventListener('resize', ensureVideoSizing);
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && animationFrameId) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = 0;
      } else if (!document.hidden && trackingActive) {
        animationFrameId = requestAnimationFrame(processFrame);
      }
    });

    resetTargetState();
    startBtn.addEventListener('click', startTracking);
    loadStream();
  </script>
</body>
</html>
EOF
  chown www-data:www-data /var/www/html/index.html
  chmod 644 /var/www/html/index.html
}

reload_services() {
  systemctl daemon-reload
  systemctl enable --now rpicam-hls.service
  systemctl enable --now montebot-serial.service
  systemctl restart nginx
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
  echo "[INFO] Configuração da câmera concluída. Reinicie o Raspberry Pi para garantir que o overlay da câmera seja carregado." >&2
}

main "$@"
