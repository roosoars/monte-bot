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
  mkdir -p "${STREAM_DIR}" "${STATIC_DIR}" "${STATIC_DIR}/models" "${STATIC_DIR}/mediapipe/wasm"
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

download_mediapipe_assets() {
  local base_url="https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0"
  local base_dir="${STATIC_DIR}/mediapipe"
  local wasm_dir="${base_dir}/wasm"
  local -A files=(
    ["${base_dir}/vision_bundle.js"]="${base_url}/vision_bundle.js"
    ["${wasm_dir}/vision_wasm_internal.js"]="${base_url}/wasm/vision_wasm_internal.js"
    ["${wasm_dir}/vision_wasm_internal.wasm"]="${base_url}/wasm/vision_wasm_internal.wasm"
    ["${wasm_dir}/vision_wasm_nosimd_internal.js"]="${base_url}/wasm/vision_wasm_nosimd_internal.js"
    ["${wasm_dir}/vision_wasm_nosimd_internal.wasm"]="${base_url}/wasm/vision_wasm_nosimd_internal.wasm"
  )

  for target in "${!files[@]}"; do
    if curl -fL --connect-timeout 10 --max-time 120 -o "${target}" "${files[${target}]}"; then
      chown www-data:www-data "${target}"
      chmod 644 "${target}"
    else
      echo "[AVISO] Falha ao baixar ${files[${target}]}. Modo offline do MediaPipe pode não funcionar." >&2
      rm -f "${target}" >/dev/null 2>&1 || true
    fi
  done

  local model_url="https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite"
  local model_path="${STATIC_DIR}/models/efficientdet_lite0.tflite"
  if curl -fL --connect-timeout 10 --max-time 120 -o "${model_path}" "${model_url}"; then
    chown www-data:www-data "${model_path}"
    chmod 644 "${model_path}"
    echo "[INFO] Modelo MediaPipe salvo em ${model_path}." >&2
  else
    echo "[AVISO] Não foi possível baixar o modelo efficientdet_lite0. Rastreamento exigirá acesso à internet." >&2
    rm -f "${model_path}" >/dev/null 2>&1 || true
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
  <title>Monte Bot - Rastreamento ao Vivo</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
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
      background: radial-gradient(circle at top, #102a44, #050609 72%);
      font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #e2f3ff;
      padding: 32px 18px;
    }
    main {
      width: min(1080px, 100%);
      display: grid;
      gap: 28px;
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
    #video-wrapper {
      position: relative;
      background: rgba(0, 0, 0, 0.7);
      border: 1px solid rgba(0, 140, 255, 0.35);
      border-radius: 18px;
      overflow: hidden;
      box-shadow: 0 22px 38px rgba(0, 0, 0, 0.45);
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
    #status.error {
      color: #ff867c;
    }
    #tracking-info {
      display: grid;
      gap: 12px;
      background: rgba(0, 14, 30, 0.45);
      border: 1px solid rgba(0, 140, 255, 0.25);
      border-radius: 14px;
      padding: 18px 22px;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
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
    @media (max-width: 720px) {
      #startTracking {
        width: 100%;
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
    </section>
  </main>

  <script src="static/mediapipe/vision_bundle.js"></script>
  <script>
    (function () {
      const video = document.getElementById('cameraStream');
      const overlay = document.getElementById('overlay');
      const overlayCtx = overlay.getContext('2d');
      const analysisCanvas = document.createElement('canvas');
      const analysisCtx = analysisCanvas.getContext('2d', { willReadFrequently: true });
      const statusEl = document.getElementById('status');
      const startBtn = document.getElementById('startTracking');
      const movementEl = document.getElementById('movementOutput');
      const clothingEl = document.getElementById('clothingOutput');
      const source = 'stream/index.m3u8';
      const wasmBases = ['static/mediapipe/wasm', 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/wasm'];
      const modelUris = [
        'static/models/efficientdet_lite0.tflite',
        'https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite'
      ];

      let detector = null;
      let trackingActive = false;
      let lastVideoTime = -1;
      let animationFrameId = 0;

      function updateStatus(message, isError) {
        statusEl.textContent = message;
        statusEl.classList.toggle('error', Boolean(isError));
      }

      function ensureVideoSizing() {
        const width = video.videoWidth || 1280;
        const height = video.videoHeight || 720;
        if (overlay.width !== width || overlay.height !== height) {
          overlay.width = width;
          overlay.height = height;
        }
        analysisCanvas.width = width;
        analysisCanvas.height = height;
      }

      function loadStream() {
        if (video.canPlayType('application/vnd.apple.mpegurl')) {
          video.src = source;
          video.addEventListener('loadeddata', () => {
            updateStatus('Transmissão ao vivo ativa.', false);
            ensureVideoSizing();
          });
          video.addEventListener('error', () => {
            updateStatus('Não foi possível iniciar o stream. Verifique o serviço rpicam-hls.', true);
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
            backBufferLength: 30
          });
          hls.loadSource(source);
          hls.attachMedia(video);
          hls.on(Hls.Events.MANIFEST_PARSED, function () {
            updateStatus('Transmissão ao vivo ativa.', false);
            video.play().catch(() => {});
            ensureVideoSizing();
          });
          hls.on(Hls.Events.ERROR, function (event, data) {
            if (data.fatal) {
              updateStatus('Erro fatal no stream: ' + data.type + ' - ' + data.details, true);
              hls.destroy();
            }
          });
        };
        script.onerror = function () {
          updateStatus('Não foi possível carregar hls.js. Conecte-se à internet ou utilize Safari.', true);
        };
        script.src = 'static/hls.min.js';
        document.body.appendChild(script);
      }

      async function ensureDetector() {
        if (detector) {
          return detector;
        }
        if (typeof vision === 'undefined' || !vision.FilesetResolver || !vision.ObjectDetector) {
          updateStatus('Biblioteca MediaPipe indisponível.', true);
          throw new Error('MediaPipe ausente');
        }
        updateStatus('Carregando MediaPipe para rastreamento...', false);
        for (const base of wasmBases) {
          for (const model of modelUris) {
            try {
              const fileset = await vision.FilesetResolver.forVisionTasks(base);
              const created = await vision.ObjectDetector.createFromOptions(fileset, {
                baseOptions: {
                  modelAssetPath: model
                },
                runningMode: 'VIDEO',
                scoreThreshold: 0.4,
                categoryAllowlist: ['person']
              });
              detector = created;
              updateStatus('MediaPipe pronto. Pessoa será detectada após a contagem regressiva.', false);
              return detector;
            } catch (err) {
              console.warn('[MediaPipe] Falha ao carregar com base', base, 'e modelo', model, err);
            }
          }
        }
        updateStatus('Não foi possível inicializar o MediaPipe. Verifique a conexão e tente novamente.', true);
        throw new Error('Falha ao criar detector');
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
        if (!analysisCtx) {
          return { label: 'indisponível', r: 0, g: 0, b: 0 };
        }
        const width = Math.max(1, Math.floor(bbox.width));
        const height = Math.max(1, Math.floor(bbox.height));
        const x = Math.max(0, Math.floor(bbox.originX));
        const y = Math.max(0, Math.floor(bbox.originY));
        if (width <= 0 || height <= 0) {
          return { label: 'indefinido', r: 0, g: 0, b: 0 };
        }
        analysisCtx.drawImage(video, 0, 0, analysisCanvas.width, analysisCanvas.height);
        const sampleWidth = Math.min(width, Math.max(1, analysisCanvas.width - x));
        const sampleHeight = Math.min(height, Math.max(1, analysisCanvas.height - y));
        if (sampleWidth <= 0 || sampleHeight <= 0) {
          return { label: 'indefinido', r: 0, g: 0, b: 0 };
        }
        const imageData = analysisCtx.getImageData(x, y, sampleWidth, sampleHeight);
        const data = imageData.data;
        if (!data.length) {
          return { label: 'indefinido', r: 0, g: 0, b: 0 };
        }
        let r = 0;
        let g = 0;
        let b = 0;
        let count = 0;
        const step = Math.max(1, Math.floor(data.length / (4 * 5000)));
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
        const frameWidth = overlay.width || 1;
        const frameHeight = overlay.height || 1;
        const centerX = bbox.originX + bbox.width / 2;
        const areaRatio = (bbox.width * bbox.height) / (frameWidth * frameHeight);
        const offset = centerX / frameWidth - 0.5;
        const commands = [];

        if (areaRatio < 0.075) {
          commands.push('andar para frente (alvo distante)');
        } else if (areaRatio > 0.22) {
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

      async function processFrame() {
        if (!trackingActive || !detector) {
          return;
        }
        ensureVideoSizing();
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

        if (!result || !result.detections || result.detections.length === 0) {
          updateStatus('Rastreamento ativo, aguardando pessoa no enquadramento...', false);
          movementEl.innerHTML = '<strong>Movimento previsto:</strong> aguardar.';
          clothingEl.innerHTML = '<strong>Traje dominante:</strong> indefinido.';
          animationFrameId = requestAnimationFrame(processFrame);
          return;
        }

        const detection = result.detections[0];
        const bbox = detection.boundingBox;
        drawOverlay(bbox);
        updateStatus('Pessoa detectada. Rastreamento ativo.', false);

        const clothing = analyzeClothing(bbox);
        const movement = computeMovement(bbox);

        movementEl.innerHTML = '<strong>Movimento previsto:</strong> ' + movement + '.';
        clothingEl.innerHTML = '<strong>Traje dominante:</strong> ' + clothing.label +
          ' (RGB ' + clothing.r + ', ' + clothing.g + ', ' + clothing.b + ').';

        console.log('[MonteBot][Rastreamento] ' + movement);
        animationFrameId = requestAnimationFrame(processFrame);
      }

      async function startTracking() {
        if (trackingActive) {
          return;
        }
        startBtn.disabled = true;
        updateStatus('Preparando rastreamento...', false);
        const detectorPromise = ensureDetector();
        try {
          for (let seconds = 5; seconds > 0; seconds--) {
            updateStatus('Iniciando detecção em ' + seconds + ' segundo' + (seconds === 1 ? '' : 's') + '...', false);
            await new Promise((resolve) => setTimeout(resolve, 1000));
          }
          await detectorPromise;
        } catch (err) {
          console.error(err);
          trackingActive = false;
          startBtn.disabled = false;
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

      startBtn.addEventListener('click', startTracking);
      loadStream();
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
  download_mediapipe_assets
  write_camera_runner
  write_systemd_service
  update_web_page
  reload_services
  echo "[INFO] Configuração da câmera concluída. Reinicie o Raspberry Pi para garantir que o overlay da câmera seja carregado." >&2
}

main "$@"
