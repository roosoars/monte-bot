#!/usr/bin/env bash
set -euo pipefail

# Este script cria as páginas web para o Monte Bot
# Deve ser chamado pelo setup_camera_stream.sh

create_config_page() {
  cat <<'EOF' >/var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Configuração</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' ry='12' fill='%23002233'/%3E%3Cpath d='M16 42l8-20h4l8 20h-4l-1.8-5.2h-9.2L20 42zm7.4-8.4h6.4L27 24.4zM40 22h4v20h-4z' fill='%2300c6ff'/%3E%3C/svg%3E" />
  <style>
    :root {
      color-scheme: dark;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: radial-gradient(circle at top, #0f2c48, #03070d 75%);
      color: #e2f3ff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      max-width: 500px;
      width: 100%;
      background: rgba(0, 14, 30, 0.6);
      border: 1px solid rgba(0, 140, 255, 0.3);
      border-radius: 20px;
      padding: 40px 30px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    }
    .header {
      text-align: center;
      margin-bottom: 40px;
    }
    .badge {
      display: inline-block;
      padding: 6px 14px;
      border-radius: 999px;
      background: rgba(0, 153, 255, 0.2);
      border: 1px solid rgba(0, 153, 255, 0.4);
      color: #7fe1ff;
      font-size: 0.75rem;
      letter-spacing: 0.1rem;
      text-transform: uppercase;
      margin-bottom: 15px;
    }
    h1 {
      font-size: 2rem;
      letter-spacing: 0.1rem;
      margin-bottom: 10px;
    }
    .subtitle {
      color: rgba(226, 243, 255, 0.7);
      font-size: 0.95rem;
      line-height: 1.5;
    }
    .menu {
      display: grid;
      gap: 15px;
    }
    .menu-item {
      background: linear-gradient(135deg, rgba(0, 198, 255, 0.1), rgba(0, 114, 255, 0.1));
      border: 1px solid rgba(0, 140, 255, 0.3);
      border-radius: 15px;
      padding: 25px 20px;
      text-decoration: none;
      color: #e2f3ff;
      display: flex;
      align-items: center;
      justify-content: space-between;
      transition: all 0.3s ease;
      cursor: pointer;
    }
    .menu-item:hover {
      background: linear-gradient(135deg, rgba(0, 198, 255, 0.2), rgba(0, 114, 255, 0.2));
      border-color: rgba(0, 198, 255, 0.5);
      transform: translateY(-2px);
      box-shadow: 0 10px 30px rgba(0, 198, 255, 0.2);
    }
    .menu-item-content {
      flex: 1;
    }
    .menu-item-title {
      font-size: 1.2rem;
      font-weight: 600;
      margin-bottom: 5px;
      color: #7fe1ff;
    }
    .menu-item-desc {
      font-size: 0.85rem;
      color: rgba(226, 243, 255, 0.6);
    }
    .menu-item-icon {
      font-size: 2rem;
      opacity: 0.7;
    }
    .info-box {
      margin-top: 30px;
      padding: 20px;
      background: rgba(0, 0, 0, 0.3);
      border: 1px solid rgba(0, 140, 255, 0.2);
      border-radius: 12px;
    }
    .info-box p {
      font-size: 0.85rem;
      color: rgba(226, 243, 255, 0.65);
      line-height: 1.6;
      margin-bottom: 10px;
    }
    .info-box p:last-child {
      margin-bottom: 0;
    }
    .info-box strong {
      color: #7fe1ff;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span class="badge">Monte Bot R2D2</span>
      <h1>Configuração</h1>
      <p class="subtitle">Sistema de controle e rastreamento autônomo</p>
    </div>

    <nav class="menu">
      <a href="/live.html" class="menu-item">
        <div class="menu-item-content">
          <div class="menu-item-title">Live</div>
          <div class="menu-item-desc">Controle ao vivo com câmera e detecção</div>
        </div>
        <span class="menu-item-icon">▶</span>
      </a>

      <div class="menu-item" onclick="alert('Configurações em desenvolvimento')">
        <div class="menu-item-content">
          <div class="menu-item-title">Configurações</div>
          <div class="menu-item-desc">Ajustar parâmetros do sistema</div>
        </div>
        <span class="menu-item-icon">⚙</span>
      </div>

      <div class="menu-item" onclick="alert('Calibração em desenvolvimento')">
        <div class="menu-item-content">
          <div class="menu-item-title">Calibração</div>
          <div class="menu-item-desc">Calibrar sensores e motores</div>
        </div>
        <span class="menu-item-icon">🎯</span>
      </div>
    </nav>

    <div class="info-box">
      <p><strong>Dica:</strong> Para melhor experiência, use o modo Live em tela cheia com o telefone na horizontal.</p>
      <p><strong>Rede:</strong> Conectado ao hotspot MonteHotspot</p>
      <p><strong>IP:</strong> 192.168.50.1</p>
    </div>
  </div>
</body>
</html>
EOF
  chown www-data:www-data /var/www/html/index.html
  chmod 644 /var/www/html/index.html
}

create_live_page() {
  cat <<'LIVEEOF' >/var/www/html/live.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Live</title>
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' ry='12' fill='%23002233'/%3E%3Cpath d='M16 42l8-20h4l8 20h-4l-1.8-5.2h-9.2L20 42zm7.4-8.4h6.4L27 24.4zM40 22h4v20h-4z' fill='%2300c6ff'/%3E%3C/svg%3E" />
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-tap-highlight-color: transparent;
    }
    body {
      font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #000;
      color: #fff;
      overflow: hidden;
      position: fixed;
      width: 100%;
      height: 100%;
    }
    #video-container {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: #000;
    }
    #cameraStream {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    #overlay {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
    }

    /* Controles sobrepostos */
    #controls-overlay {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 10;
    }

    /* Slide horizontal */
    #slide-control {
      position: absolute;
      top: 20px;
      left: 50%;
      transform: translateX(-50%);
      pointer-events: all;
    }
    .slide-container {
      width: 300px;
      height: 60px;
      background: rgba(0, 0, 0, 0.7);
      border: 2px solid rgba(0, 198, 255, 0.5);
      border-radius: 30px;
      position: relative;
      overflow: hidden;
    }
    .slide-bar {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 90%;
      height: 4px;
      background: rgba(255, 255, 255, 0.2);
      border-radius: 2px;
    }
    .slide-handle {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 50px;
      height: 50px;
      background: linear-gradient(135deg, #00c6ff, #0072ff);
      border-radius: 25px;
      cursor: grab;
      touch-action: none;
      box-shadow: 0 4px 12px rgba(0, 198, 255, 0.4);
    }
    .slide-handle:active {
      cursor: grabbing;
    }
    #slide-status {
      position: absolute;
      top: 85px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.8);
      padding: 8px 16px;
      border-radius: 15px;
      font-size: 0.9rem;
      color: #00c6ff;
      font-weight: 600;
      pointer-events: none;
    }

    /* Joystick */
    #joystick-control {
      position: absolute;
      bottom: 30px;
      right: 30px;
      pointer-events: all;
    }
    .joystick-container {
      width: 150px;
      height: 150px;
      background: rgba(0, 0, 0, 0.7);
      border: 2px solid rgba(0, 198, 255, 0.5);
      border-radius: 50%;
      position: relative;
    }
    .joystick-inner {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 60px;
      height: 60px;
      background: linear-gradient(135deg, #00c6ff, #0072ff);
      border-radius: 50%;
      cursor: grab;
      touch-action: none;
      box-shadow: 0 4px 12px rgba(0, 198, 255, 0.4);
    }
    .joystick-inner:active {
      cursor: grabbing;
    }
    .joystick-arrow {
      position: absolute;
      color: rgba(255, 255, 255, 0.3);
      font-size: 1.2rem;
      pointer-events: none;
    }
    .joystick-arrow.up {
      top: 10px;
      left: 50%;
      transform: translateX(-50%);
    }
    .joystick-arrow.down {
      bottom: 10px;
      left: 50%;
      transform: translateX(-50%);
    }
    .joystick-arrow.left {
      left: 10px;
      top: 50%;
      transform: translateY(-50%);
    }
    .joystick-arrow.right {
      right: 10px;
      top: 50%;
      transform: translateY(-50%);
    }
    #joystick-status {
      position: absolute;
      bottom: -40px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.8);
      padding: 8px 16px;
      border-radius: 15px;
      font-size: 0.9rem;
      color: #00c6ff;
      font-weight: 600;
      white-space: nowrap;
    }

    /* Status de detecção */
    #detection-status {
      position: absolute;
      top: 20px;
      left: 20px;
      background: rgba(0, 0, 0, 0.8);
      padding: 12px 18px;
      border-radius: 15px;
      font-size: 1rem;
      color: #00c6ff;
      font-weight: 600;
      pointer-events: none;
      border: 2px solid rgba(0, 198, 255, 0.5);
    }

    /* Botão de voltar */
    #back-button {
      position: absolute;
      bottom: 30px;
      left: 30px;
      background: rgba(0, 0, 0, 0.7);
      border: 2px solid rgba(0, 198, 255, 0.5);
      color: #00c6ff;
      padding: 12px 20px;
      border-radius: 25px;
      font-size: 0.9rem;
      font-weight: 600;
      cursor: pointer;
      pointer-events: all;
      transition: all 0.3s ease;
    }
    #back-button:hover {
      background: rgba(0, 198, 255, 0.2);
      transform: scale(1.05);
    }

    @media (max-width: 768px) and (orientation: portrait) {
      body::before {
        content: "Por favor, gire o telefone para o modo horizontal";
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: rgba(0, 0, 0, 0.95);
        padding: 30px;
        border-radius: 20px;
        text-align: center;
        font-size: 1.2rem;
        z-index: 9999;
        max-width: 80%;
      }
    }
  </style>
</head>
<body>
  <div id="video-container">
    <video id="cameraStream" autoplay playsinline muted>
      Seu navegador não suporta vídeo.
    </video>
    <canvas id="overlay"></canvas>
  </div>

  <div id="controls-overlay">
    <div id="detection-status">PARADO</div>

    <div id="slide-control">
      <div class="slide-container">
        <div class="slide-bar"></div>
        <div class="slide-handle" id="slideHandle"></div>
      </div>
      <div id="slide-status">POSIÇÃO CENTRAL</div>
    </div>

    <div id="joystick-control">
      <div class="joystick-container">
        <span class="joystick-arrow up">↑</span>
        <span class="joystick-arrow down">↓</span>
        <span class="joystick-arrow left">←</span>
        <span class="joystick-arrow right">→</span>
        <div class="joystick-inner" id="joystickHandle"></div>
      </div>
      <div id="joystick-status">CENTRO</div>
    </div>

    <button id="back-button" onclick="window.location.href='/'">← Voltar</button>
  </div>

  <script type="module">
    const video = document.getElementById('cameraStream');
    const overlay = document.getElementById('overlay');
    const overlayCtx = overlay.getContext('2d');
    const slideHandle = document.getElementById('slideHandle');
    const slideStatus = document.getElementById('slide-status');
    const joystickHandle = document.getElementById('joystickHandle');
    const joystickStatus = document.getElementById('joystick-status');
    const detectionStatus = document.getElementById('detection-status');
    const source = 'stream/index.m3u8';

    // MediaPipe variables
    let visionModule = null;
    let detector = null;
    let trackingActive = false;
    let lastVideoTime = -1;
    let animationFrameId = 0;
    let frameWidth = 1920;
    let frameHeight = 1080;
    let targetProfile = null;
    let previousCenter = null;
    let lostFrames = 0;
    const MIN_DISTANCE_AREA = 0.20; // 2 metros (aproximadamente 20% da área)

    // Configuração de canvas
    function ensureVideoSizing() {
      const width = video.videoWidth || 1920;
      const height = video.videoHeight || 1080;
      frameWidth = width;
      frameHeight = height;
      if (overlay.width !== width || overlay.height !== height) {
        overlay.width = width;
        overlay.height = height;
      }
    }

    // Carregar stream HLS
    function loadStream() {
      if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = source;
        video.addEventListener('loadeddata', () => {
          ensureVideoSizing();
          initTracking();
        });
        return;
      }

      const script = document.createElement('script');
      script.onload = () => {
        if (typeof Hls === 'undefined' || !Hls.isSupported()) {
          console.error('HLS não suportado');
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
          video.play().catch(() => {});
          ensureVideoSizing();
          initTracking();
        });
      };
      script.src = 'static/hls.min.js';
      document.body.appendChild(script);
    }

    // SLIDE CONTROL
    let isDraggingSlide = false;
    let slideStartX = 0;
    let slideCurrentX = 0;

    function updateSlidePosition(clientX) {
      const container = slideHandle.parentElement;
      const rect = container.getBoundingClientRect();
      const x = clientX - rect.left;
      const centerX = rect.width / 2;
      const maxOffset = rect.width / 2 - 25;

      let offset = x - centerX;
      offset = Math.max(-maxOffset, Math.min(maxOffset, offset));

      slideHandle.style.left = `calc(50% + ${offset}px)`;
      slideCurrentX = offset;

      // Determinar status
      if (offset > 30) {
        slideStatus.textContent = 'DIREITA';
        console.log('[MonteBot][Slide] DIREITA');
      } else if (offset < -30) {
        slideStatus.textContent = 'ESQUERDA';
        console.log('[MonteBot][Slide] ESQUERDA');
      } else {
        slideStatus.textContent = 'POSIÇÃO CENTRAL';
        console.log('[MonteBot][Slide] POSIÇÃO CENTRAL');
      }
    }

    slideHandle.addEventListener('mousedown', (e) => {
      isDraggingSlide = true;
      slideStartX = e.clientX;
    });

    slideHandle.addEventListener('touchstart', (e) => {
      isDraggingSlide = true;
      slideStartX = e.touches[0].clientX;
    });

    document.addEventListener('mousemove', (e) => {
      if (!isDraggingSlide) return;
      updateSlidePosition(e.clientX);
    });

    document.addEventListener('touchmove', (e) => {
      if (!isDraggingSlide) return;
      updateSlidePosition(e.touches[0].clientX);
    });

    document.addEventListener('mouseup', () => {
      if (isDraggingSlide) {
        isDraggingSlide = false;
        slideHandle.style.left = '50%';
        slideStatus.textContent = 'POSIÇÃO CENTRAL';
        console.log('[MonteBot][Slide] POSIÇÃO CENTRAL');
      }
    });

    document.addEventListener('touchend', () => {
      if (isDraggingSlide) {
        isDraggingSlide = false;
        slideHandle.style.left = '50%';
        slideStatus.textContent = 'POSIÇÃO CENTRAL';
        console.log('[MonteBot][Slide] POSIÇÃO CENTRAL');
      }
    });

    // JOYSTICK CONTROL
    let isDraggingJoystick = false;
    let joystickCenterX = 0;
    let joystickCenterY = 0;

    function updateJoystickPosition(clientX, clientY) {
      const container = joystickHandle.parentElement;
      const rect = container.getBoundingClientRect();
      const centerX = rect.width / 2;
      const centerY = rect.height / 2;
      const maxRadius = rect.width / 2 - 30;

      let offsetX = clientX - rect.left - centerX;
      let offsetY = clientY - rect.top - centerY;

      const distance = Math.sqrt(offsetX * offsetX + offsetY * offsetY);
      if (distance > maxRadius) {
        offsetX = (offsetX / distance) * maxRadius;
        offsetY = (offsetY / distance) * maxRadius;
      }

      joystickHandle.style.left = `calc(50% + ${offsetX}px)`;
      joystickHandle.style.top = `calc(50% + ${offsetY}px)`;

      // Determinar direção
      const threshold = 20;
      if (Math.abs(offsetY) > Math.abs(offsetX)) {
        if (offsetY < -threshold) {
          joystickStatus.textContent = 'FRENTE';
          console.log('[MonteBot][Joystick] FRENTE');
        } else if (offsetY > threshold) {
          joystickStatus.textContent = 'ATRÁS';
          console.log('[MonteBot][Joystick] ATRÁS');
        } else {
          joystickStatus.textContent = 'CENTRO';
        }
      } else {
        if (offsetX > threshold) {
          joystickStatus.textContent = 'DIREITA';
          console.log('[MonteBot][Joystick] DIREITA');
        } else if (offsetX < -threshold) {
          joystickStatus.textContent = 'ESQUERDA';
          console.log('[MonteBot][Joystick] ESQUERDA');
        } else {
          joystickStatus.textContent = 'CENTRO';
        }
      }
    }

    joystickHandle.addEventListener('mousedown', (e) => {
      isDraggingJoystick = true;
    });

    joystickHandle.addEventListener('touchstart', (e) => {
      isDraggingJoystick = true;
    });

    document.addEventListener('mousemove', (e) => {
      if (!isDraggingJoystick) return;
      updateJoystickPosition(e.clientX, e.clientY);
    });

    document.addEventListener('touchmove', (e) => {
      if (!isDraggingJoystick) return;
      updateJoystickPosition(e.touches[0].clientX, e.touches[0].clientY);
    });

    document.addEventListener('mouseup', () => {
      if (isDraggingJoystick) {
        isDraggingJoystick = false;
        joystickHandle.style.left = '50%';
        joystickHandle.style.top = '50%';
        joystickStatus.textContent = 'CENTRO';
      }
    });

    document.addEventListener('touchend', () => {
      if (isDraggingJoystick) {
        isDraggingJoystick = false;
        joystickHandle.style.left = '50%';
        joystickHandle.style.top = '50%';
        joystickStatus.textContent = 'CENTRO';
      }
    });

    // MEDIAPIPE DETECTION
    async function loadVisionModule() {
      if (visionModule) return visionModule;
      const visionSources = [
        './static/mediapipe/vision_bundle.js',
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/vision_bundle.js'
      ];
      for (const src of visionSources) {
        try {
          const mod = await import(src);
          if (mod && mod.FilesetResolver && mod.ObjectDetector) {
            visionModule = mod;
            console.log('[MediaPipe] Carregado de', src);
            return visionModule;
          }
        } catch (err) {
          console.warn('[MediaPipe] Falha ao importar', src, err);
        }
      }
      throw new Error('Nenhum vision_bundle disponível.');
    }

    async function ensureDetector() {
      if (detector) return detector;
      const visionApi = await loadVisionModule();
      const wasmBases = ['static/mediapipe/wasm', 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/wasm'];
      const modelUris = [
        'static/models/efficientdet_lite0.tflite',
        'https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite'
      ];

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
            console.log('[MediaPipe] Detector criado');
            return detector;
          } catch (err) {
            console.warn('[MediaPipe] Falha ao abrir modelo', model, 'via', base, err);
          }
        }
      }
      throw new Error('Falha ao criar detector MediaPipe');
    }

    function drawOverlay(bbox) {
      overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
      if (!bbox) return;

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
        detectionStatus.textContent = 'PARADO';
        console.log('[MonteBot][Detecção] PARADO');
        return;
      }

      const frameArea = Math.max(1, frameWidth * frameHeight);
      const centerX = bbox.originX + bbox.width / 2;
      const areaRatio = (bbox.width * bbox.height) / frameArea;
      const offset = centerX / frameWidth - 0.5;

      // Se está a 2 metros ou menos (área maior que MIN_DISTANCE_AREA), parar
      if (areaRatio >= MIN_DISTANCE_AREA) {
        detectionStatus.textContent = 'PARADO';
        console.log('[MonteBot][Detecção] PARADO - 2 metros alcançados');
        return;
      }

      // Determinar movimento
      if (offset > 0.12) {
        detectionStatus.textContent = 'DIREITA';
        console.log('[MonteBot][Detecção] DIREITA');
      } else if (offset < -0.12) {
        detectionStatus.textContent = 'ESQUERDA';
        console.log('[MonteBot][Detecção] ESQUERDA');
      } else {
        detectionStatus.textContent = 'FRENTE';
        console.log('[MonteBot][Detecção] FRENTE');
      }
    }

    function processFrame() {
      if (!trackingActive || !detector) return;

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
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      overlayCtx.clearRect(0, 0, overlay.width, overlay.height);

      if (!result || !result.detections || result.detections.length === 0) {
        lostFrames++;
        if (lostFrames > 30) {
          detectionStatus.textContent = 'PARADO';
          console.log('[MonteBot][Detecção] PARADO - Pessoa não detectada');
        }
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      lostFrames = 0;
      const detection = result.detections[0];
      const bbox = detection.boundingBox;

      drawOverlay(bbox);
      computeMovement(bbox);

      animationFrameId = requestAnimationFrame(processFrame);
    }

    async function initTracking() {
      try {
        await ensureDetector();
        trackingActive = true;
        animationFrameId = requestAnimationFrame(processFrame);
        console.log('[MonteBot] Rastreamento iniciado');
      } catch (err) {
        console.error('[MonteBot] Erro ao iniciar rastreamento', err);
      }
    }

    video.addEventListener('loadedmetadata', ensureVideoSizing);
    window.addEventListener('resize', ensureVideoSizing);

    loadStream();
  </script>
</body>
</html>
LIVEEOF
  chown www-data:www-data /var/www/html/live.html
  chmod 644 /var/www/html/live.html
}

# Executar criação das páginas
create_config_page
create_live_page

echo "[INFO] Páginas web criadas com sucesso."
