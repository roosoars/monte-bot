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

log_warn() {
  echo "[WARN] $1" >&2
  logger -t "${LOG_TAG}" "[WARN] $1" 2>/dev/null || true
}

# Setup inicial do diretório (caso o mount tenha falhado, cria fallback)
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

# Configurações de Streaming otimizadas para RAMDISK
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_BITRATE="${STREAM_BITRATE:-4000000}" 
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-30}"
HLS_SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-0.4}"
HLS_LIST_SIZE="${HLS_LIST_SIZE:-4}"

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
# rpicam-vid: Otimizado para performance (level 4.2, baseline profile para menos CPU)
# ffmpeg: Otimizado para latência zero com RAMDISK
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

# ==============================================================================
# SERVIÇO SYSTEMD OTIMIZADO (Prioridade de CPU e IO)
# ==============================================================================
write_systemd_service() {
  cat <<EOF >"${SERVICE_FILE}"
[Unit]
Description=Streaming da câmera Raspberry Pi (rpicam + HLS + RAMDISK)
After=network.target nginx.service multi-user.target systemd-udev-settle.service
Wants=nginx.service systemd-udev-settle.service
StartLimitIntervalSec=600
StartLimitBurst=10

[Service]
Type=simple
# Prioridade Extrema para evitar travamentos
CPUSchedulingPolicy=rr
CPUSchedulingPriority=90
IOSchedulingClass=realtime
IOSchedulingPriority=0
Nice=-15
OOMScoreAdjust=-1000

# Longer initial delay to ensure camera drivers are fully loaded
ExecStartPre=/bin/sleep 5
ExecStartPre=/bin/mkdir -p ${STREAM_DIR}
ExecStartPre=/bin/chown www-data:www-data ${STREAM_DIR}
ExecStart=${CAMERA_RUNNER}
Restart=always
RestartSec=10
# Longer timeout since camera detection can take up to 60 seconds
TimeoutStartSec=120
StandardOutput=journal
StandardError=journal

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

# (Mantendo as funções do Serial Bridge para garantir compatibilidade)
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
  
  write_serial_bridge
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
