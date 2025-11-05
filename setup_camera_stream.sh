#!/usr/bin/env bash
set -euo pipefail

STREAM_DIR="/var/www/html/stream"
STATIC_DIR="/var/www/html/static"
HLS_JS_PATH="${STATIC_DIR}/hls.min.js"
CAMERA_RUNNER="/usr/local/sbin/rpicam-hls.sh"
SERVICE_FILE="/etc/systemd/system/rpicam-hls.service"

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] Execute este script como root (use sudo)." >&2
    exit 1
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
  apt-get update
  apt-get install -y --no-install-recommends rpicam-apps ffmpeg curl
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
  mkdir -p "${STREAM_DIR}" "${STATIC_DIR}"
  chown -R www-data:www-data /var/www/html || true
  chmod -R 755 /var/www/html
  rm -f "${STREAM_DIR}"/*.ts "${STREAM_DIR}/index.m3u8" >/dev/null 2>&1 || true
}

download_hls_library() {
  local url="https://cdn.jsdelivr.net/npm/hls.js@1.5.4/dist/hls.min.js"
  if curl -fL --connect-timeout 10 --max-time 30 -o "${HLS_JS_PATH}" "${url}"; then
    chown www-data:www-data "${HLS_JS_PATH}"
    chmod 644 "${HLS_JS_PATH}"
    echo "[INFO] hls.js baixado para ${HLS_JS_PATH}." >&2
  else
    echo "[AVISO] Não foi possível baixar hls.js. Navegadores sem suporte nativo a HLS precisarão de conexão externa." >&2
    rm -f "${HLS_JS_PATH}" >/dev/null 2>&1 || true
  fi
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

STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_BITRATE="${STREAM_BITRATE:-5000000}"
STREAM_KEYFRAME_INTERVAL="${STREAM_KEYFRAME_INTERVAL:-${STREAM_FRAMERATE}}"

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
  --inline \
  -o - \
  | ffmpeg \
      -loglevel warning \
      -f h264 \
      -i - \
      -an \
      -c:v copy \
      -f hls \
      -hls_time 1 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list+omit_endlist \
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

update_web_page() {
  cat <<'EOF' >/var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Câmera Ao Vivo</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root {
      color-scheme: dark;
    }
    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: radial-gradient(circle at top, #0d2a45, #05080f 70%);
      font-family: "Segoe UI", Roboto, sans-serif;
      color: #e0f2ff;
      padding: 32px 16px;
      box-sizing: border-box;
    }
    main {
      width: min(960px, 100%);
      display: grid;
      grid-template-columns: 1fr;
      gap: 24px;
      text-align: center;
    }
    h1 {
      margin: 0;
      letter-spacing: 0.2rem;
      text-transform: uppercase;
      font-size: clamp(1.8rem, 4vw, 2.6rem);
    }
    #video-wrapper {
      position: relative;
      background: rgba(0, 0, 0, 0.65);
      border: 1px solid rgba(0, 153, 255, 0.35);
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 18px 35px rgba(0, 0, 0, 0.35);
    }
    video {
      width: 100%;
      height: auto;
      display: block;
      background: #000;
    }
    #status {
      font-size: 0.95rem;
      color: rgba(224, 242, 255, 0.75);
    }
    a {
      color: #4fc3f7;
    }
  </style>
</head>
<body>
  <main>
    <h1>Monte Bot • Câmera Ao Vivo</h1>
    <div id="video-wrapper">
      <video id="cameraStream" autoplay playsinline muted controls poster="">
        Seu navegador não suporta vídeo.
      </video>
    </div>
    <p id="status">Iniciando stream da câmera...</p>
  </main>
  <script>
    (function () {
      const video = document.getElementById('cameraStream');
      const statusEl = document.getElementById('status');
      const source = 'stream/index.m3u8';

      function updateStatus(message, isError) {
        statusEl.textContent = message;
        statusEl.style.color = isError ? '#ff867c' : 'rgba(224, 242, 255, 0.75)';
      }

      function attachHls() {
        if (typeof Hls === 'undefined') {
          updateStatus('Carregando suporte HLS. Se nada aparecer, use Safari/iOS ou forneça internet para baixar hls.js.', false);
          return;
        }
        if (!Hls.isSupported()) {
          updateStatus('Seu navegador não oferece suporte a HLS.', true);
          return;
        }

        const hls = new Hls({
          enableWorker: true,
          lowLatencyMode: true,
          backBufferLength: 30
        });
        hls.loadSource(source);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function () {
          updateStatus('Transmissão ao vivo ativa.', false);
          video.play().catch(() => {});
        });
        hls.on(Hls.Events.ERROR, function (event, data) {
          if (data.fatal) {
            updateStatus('Erro fatal no stream: ' + data.type + ' - ' + data.details, true);
            hls.destroy();
          }
        });
      }

      if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = source;
        video.addEventListener('loadeddata', () => {
          updateStatus('Transmissão ao vivo ativa.', false);
        });
        video.addEventListener('error', () => {
          updateStatus('Não foi possível iniciar o stream. Verifique o serviço rpicam-hls.', true);
        });
      } else {
        const script = document.createElement('script');
        script.onload = attachHls;
        script.onerror = function () {
          updateStatus('Não foi possível carregar hls.js. Conecte-se à internet ou abra com Safari/iOS.', true);
        };
        script.src = 'static/hls.min.js';
        document.body.appendChild(script);
      }
    })();
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
  systemctl restart nginx
}

main() {
  require_root
  check_operating_system
  install_camera_packages
  enable_camera_overlay
  prepare_filesystem
  download_hls_library
  write_camera_runner
  write_systemd_service
  update_web_page
  reload_services
  echo "[INFO] Configuração da câmera concluída. Reinicie o Raspberry Pi para garantir que o overlay da câmera seja carregado." >&2
}

main "$@"
