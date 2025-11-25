#!/usr/bin/env bash
set -euo pipefail

# Este script cria as páginas web para o Monte Bot
# Deve ser chamado pelo setup_camera_stream.sh

create_index_page() {
  cat <<'EOF' >/var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Menu Principal</title>
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
    .target-status {
      margin-top: 15px;
      padding: 15px;
      background: rgba(0, 100, 0, 0.2);
      border: 1px solid rgba(0, 255, 0, 0.3);
      border-radius: 10px;
    }
    .target-status.no-target {
      background: rgba(100, 50, 0, 0.2);
      border-color: rgba(255, 165, 0, 0.3);
    }
    .target-status p {
      margin: 0;
      font-size: 0.9rem;
      color: #7fe1ff;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span class="badge">Monte Bot R2D2</span>
      <h1>Menu Principal</h1>
      <p class="subtitle">Sistema de controle e rastreamento autônomo</p>
    </div>

    <nav class="menu">
      <a href="/config.html" class="menu-item">
        <div class="menu-item-content">
          <div class="menu-item-title">Configurar Alvo</div>
          <div class="menu-item-desc">Detectar e gravar pessoa para seguir</div>
        </div>
        <span class="menu-item-icon">👤</span>
      </a>

      <a href="/live.html" class="menu-item">
        <div class="menu-item-content">
          <div class="menu-item-title">Live</div>
          <div class="menu-item-desc">Controle ao vivo - seguir pessoa configurada</div>
        </div>
        <span class="menu-item-icon">▶</span>
      </a>

      <a href="/logs.html" class="menu-item">
        <div class="menu-item-content">
          <div class="menu-item-title">Logs em Tempo Real</div>
          <div class="menu-item-desc">Monitorar comunicação serial, WebSocket e comandos</div>
        </div>
        <span class="menu-item-icon">📋</span>
      </a>

    </nav>

    <div class="info-box">
      <p><strong>Dica:</strong> Configure o alvo e use "Live" para rastrear.</p>
      <p><strong>Rede:</strong> Conectado ao hotspot MonteHotspot</p>
      <p><strong>IP:</strong> 192.168.50.1</p>
      <div id="target-status" class="target-status no-target">
        <p id="target-text">⚠️ Nenhum alvo configurado</p>
      </div>
    </div>
  </div>
  <script>
    // Check if target is saved
    const savedTarget = localStorage.getItem('montebot_target');
    if (savedTarget) {
      const targetStatus = document.getElementById('target-status');
      const targetText = document.getElementById('target-text');
      targetStatus.classList.remove('no-target');
      targetText.textContent = '✅ Alvo configurado e pronto para seguir';
    }
  </script>
</body>
</html>
EOF
  chown www-data:www-data /var/www/html/index.html
  chmod 644 /var/www/html/index.html
}

create_config_page() {
  cat <<'CONFIGEOF' >/var/www/html/config.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Configurar Alvo</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' ry='12' fill='%23002233'/%3E%3Cpath d='M16 42l8-20h4l8 20h-4l-1.8-5.2h-9.2L20 42zm7.4-8.4h6.4L27 24.4zM40 22h4v20h-4z' fill='%2300c6ff'/%3E%3C/svg%3E" />
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: radial-gradient(circle at top, #0f2c48, #03070d 75%);
      color: #e2f3ff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px;
    }
    .container {
      max-width: 800px;
      width: 100%;
      background: rgba(0, 14, 30, 0.6);
      border: 1px solid rgba(0, 140, 255, 0.3);
      border-radius: 20px;
      padding: 30px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    }
    .header {
      text-align: center;
      margin-bottom: 30px;
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
    h1 { font-size: 1.8rem; letter-spacing: 0.1rem; margin-bottom: 10px; }
    .subtitle { color: rgba(226, 243, 255, 0.7); font-size: 0.95rem; line-height: 1.5; }
    #video-wrapper {
      position: relative;
      background: rgba(0, 0, 0, 0.7);
      border: 1px solid rgba(0, 140, 255, 0.38);
      border-radius: 18px;
      overflow: hidden;
      margin-bottom: 20px;
    }
    #video-wrapper video, #video-wrapper canvas {
      display: block;
      width: 100%;
    }
    #cameraStream { height: auto; background: #000; }
    #overlay {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
    }
    .controls {
      display: grid;
      gap: 15px;
      margin-bottom: 20px;
    }
    .btn {
      background: linear-gradient(135deg, #00c6ff, #0072ff);
      color: #032131;
      font-weight: 600;
      letter-spacing: 0.06rem;
      text-transform: uppercase;
      border: none;
      border-radius: 999px;
      padding: 14px 28px;
      cursor: pointer;
      transition: transform 0.2s ease, box-shadow 0.2s ease, opacity 0.2s ease;
      font-size: 1rem;
    }
    .btn:hover:not(:disabled) {
      transform: translateY(-2px);
      box-shadow: 0 12px 24px rgba(0, 153, 255, 0.35);
    }
    .btn:disabled { cursor: not-allowed; opacity: 0.6; }
    .btn-danger {
      background: linear-gradient(135deg, #ff6b6b, #c92a2a);
    }
    .btn-success {
      background: linear-gradient(135deg, #51cf66, #2f9e44);
    }
    .btn-secondary {
      background: linear-gradient(135deg, #495057, #343a40);
      color: #e2f3ff;
    }
    #status {
      text-align: center;
      font-size: 1rem;
      color: rgba(226, 243, 255, 0.78);
      margin-bottom: 20px;
      min-height: 24px;
    }
    #status strong { color: #7fe1ff; }
    #status.error { color: #ff867c; }
    #status.success { color: #51cf66; }
    .target-info {
      background: rgba(0, 14, 30, 0.45);
      border: 1px solid rgba(0, 140, 255, 0.25);
      border-radius: 14px;
      padding: 18px 22px;
      margin-bottom: 20px;
    }
    .target-info p { margin: 0 0 10px 0; font-size: 0.95rem; line-height: 1.6; color: rgba(226, 243, 255, 0.85); }
    .target-info p:last-child { margin-bottom: 0; }
    .target-info strong { color: #7fe1ff; }
    #targetSnapshot {
      width: 150px;
      height: auto;
      max-width: 100%;
      object-fit: cover;
      border-radius: 12px;
      border: 2px solid rgba(0, 153, 255, 0.4);
      box-shadow: 0 12px 24px rgba(0, 0, 0, 0.35);
      background: rgba(0, 0, 0, 0.7);
      aspect-ratio: 3 / 4;
    }
    .snapshot-wrapper {
      display: flex;
      align-items: center;
      gap: 20px;
      flex-wrap: wrap;
    }
    .back-link {
      display: inline-block;
      color: #7fe1ff;
      text-decoration: none;
      margin-bottom: 20px;
      font-size: 0.9rem;
    }
    .back-link:hover { text-decoration: underline; }
    .instructions {
      background: rgba(0, 0, 0, 0.3);
      border: 1px solid rgba(0, 140, 255, 0.2);
      border-radius: 12px;
      padding: 15px;
      margin-bottom: 20px;
    }
    .instructions h3 { font-size: 1rem; margin-bottom: 10px; color: #7fe1ff; }
    .instructions ol { margin-left: 20px; font-size: 0.9rem; color: rgba(226, 243, 255, 0.7); }
    .instructions li { margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="container">
    <a href="/" class="back-link">← Voltar ao Menu</a>
    
    <div class="header">
      <span class="badge">Configuração</span>
      <h1>Configurar Alvo para Seguir</h1>
      <p class="subtitle">Detecte e grave a pessoa que o robô deve seguir</p>
    </div>

    <div class="instructions">
      <h3>📋 Instruções:</h3>
      <ol>
        <li>Posicione a pessoa que deseja seguir em frente à câmera</li>
        <li>Clique em "Detectar Pessoa" e aguarde a detecção</li>
        <li>Quando a pessoa estiver destacada, clique em "Salvar Alvo"</li>
        <li>Vá para o modo "Live" para iniciar o rastreamento</li>
      </ol>
    </div>

    <section id="video-wrapper">
      <video id="cameraStream" autoplay playsinline muted></video>
      <canvas id="overlay" width="1280" height="720"></canvas>
    </section>

    <p id="status">Iniciando câmera...</p>

    <div class="controls">
      <button id="detectBtn" class="btn" disabled>Detectar Pessoa</button>
      <button id="saveBtn" class="btn btn-success" disabled>Salvar Alvo</button>
      <button id="clearBtn" class="btn btn-danger" disabled>Limpar Alvo Salvo</button>
    </div>

    <div class="target-info">
      <p><strong>Status do Alvo:</strong> <span id="targetStatus">Nenhum alvo configurado</span></p>
      <div class="snapshot-wrapper">
        <img id="targetSnapshot" alt="Referência do alvo" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==" />
        <div>
          <p id="colorInfo"><strong>Cor dominante:</strong> indefinida</p>
          <p id="sizeInfo"><strong>Tamanho:</strong> indefinido</p>
        </div>
      </div>
    </div>
  </div>

  <script type="module">
    const video = document.getElementById('cameraStream');
    const overlay = document.getElementById('overlay');
    const overlayCtx = overlay.getContext('2d');
    const statusEl = document.getElementById('status');
    const detectBtn = document.getElementById('detectBtn');
    const saveBtn = document.getElementById('saveBtn');
    const clearBtn = document.getElementById('clearBtn');
    const targetStatusEl = document.getElementById('targetStatus');
    const snapshotImg = document.getElementById('targetSnapshot');
    const colorInfo = document.getElementById('colorInfo');
    const sizeInfo = document.getElementById('sizeInfo');
    const source = 'stream/index.m3u8';

    let visionModule = null;
    let detector = null;
    let detecting = false;
    let currentDetection = null;
    let currentProfile = null;
    let animationFrameId = 0;
    let lastVideoTime = -1;
    let frameWidth = 1280;
    let frameHeight = 720;

    const analysisCanvas = document.createElement('canvas');
    const analysisCtx = analysisCanvas.getContext('2d', { willReadFrequently: true });
    const snapshotCanvas = document.createElement('canvas');
    const snapshotCtx = snapshotCanvas.getContext('2d');

    function updateStatus(message, type = '') {
      statusEl.innerHTML = message;
      statusEl.className = type;
    }

    function ensureVideoSizing() {
      const width = video.videoWidth || 1280;
      const height = video.videoHeight || 720;
      frameWidth = width;
      frameHeight = height;
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
          updateStatus('Câmera pronta. Clique em "Detectar Pessoa".', 'success');
          ensureVideoSizing();
          detectBtn.disabled = false;
          checkSavedTarget();
        });
        return;
      }

      const script = document.createElement('script');
      script.onload = () => {
        if (typeof Hls === 'undefined' || !Hls.isSupported()) {
          updateStatus('HLS não suportado', 'error');
          return;
        }
        const hls = new Hls({ enableWorker: true, lowLatencyMode: true });
        hls.loadSource(source);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function () {
          video.play().catch(() => {});
          updateStatus('Câmera pronta. Clique em "Detectar Pessoa".', 'success');
          ensureVideoSizing();
          detectBtn.disabled = false;
          checkSavedTarget();
        });
      };
      script.src = 'static/hls.min.js';
      document.body.appendChild(script);
    }

    function checkSavedTarget() {
      const savedTarget = localStorage.getItem('montebot_target');
      if (savedTarget) {
        const target = JSON.parse(savedTarget);
        targetStatusEl.textContent = 'Alvo salvo e pronto para seguir';
        targetStatusEl.style.color = '#51cf66';
        if (target.snapshot) {
          snapshotImg.src = target.snapshot;
        }
        if (target.colorLabel) {
          colorInfo.innerHTML = '<strong>Cor dominante:</strong> ' + target.colorLabel;
        }
        if (target.areaRatio) {
          sizeInfo.innerHTML = '<strong>Tamanho:</strong> ' + (target.areaRatio * 100).toFixed(1) + '% do quadro';
        }
        clearBtn.disabled = false;
      }
    }

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
            return detector;
          } catch (err) {
            console.warn('[MediaPipe] Falha ao abrir modelo', model, 'via', base, err);
          }
        }
      }
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
          case r: hue = ((g - b) / delta) % 6; break;
          case g: hue = (b - r) / delta + 2; break;
          default: hue = (r - g) / delta + 4;
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
      if (!analysisCtx || !bbox) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      analysisCtx.drawImage(video, 0, 0, analysisCanvas.width, analysisCanvas.height);
      const width = Math.max(1, Math.floor(bbox.width));
      const height = Math.max(1, Math.floor(bbox.height));
      const x = Math.max(0, Math.floor(bbox.originX));
      const y = Math.max(0, Math.floor(bbox.originY));
      if (width <= 0 || height <= 0) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      const sampleWidth = Math.min(width, analysisCanvas.width - x);
      const sampleHeight = Math.min(height, analysisCanvas.height - y);
      if (sampleWidth <= 0 || sampleHeight <= 0) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      let imageData;
      try {
        imageData = analysisCtx.getImageData(x, y, sampleWidth, sampleHeight);
      } catch (err) {
        return { label: 'indefinido', r: 0, g: 0, b: 0 };
      }
      const data = imageData.data;
      if (!data || !data.length) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      let r = 0, g = 0, b = 0, count = 0;
      const step = Math.max(1, Math.floor(data.length / (4 * 6000)));
      for (let i = 0; i < data.length; i += 4 * step) {
        r += data[i];
        g += data[i + 1];
        b += data[i + 2];
        count++;
      }
      if (count === 0) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);
      return { label: describeColor(r, g, b), r, g, b };
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
      overlayCtx.font = 'bold 18px sans-serif';
      overlayCtx.fillStyle = '#00d6ff';
      overlayCtx.fillText('PESSOA DETECTADA', bbox.originX, bbox.originY - 10);
    }

    function captureSnapshot(bbox) {
      if (!snapshotCtx || !bbox) return null;
      const width = Math.max(40, Math.floor(bbox.width));
      const height = Math.max(40, Math.floor(bbox.height));
      snapshotCanvas.width = width;
      snapshotCanvas.height = height;
      try {
        snapshotCtx.drawImage(video, bbox.originX, bbox.originY, bbox.width, bbox.height, 0, 0, width, height);
        return snapshotCanvas.toDataURL('image/jpeg', 0.85);
      } catch (err) {
        return null;
      }
    }

    function processFrame() {
      if (!detecting || !detector) return;
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
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      if (!result || !result.detections || result.detections.length === 0) {
        overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
        updateStatus('Nenhuma pessoa detectada. Posicione-se em frente à câmera.', 'error');
        currentDetection = null;
        currentProfile = null;
        saveBtn.disabled = true;
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      const detection = result.detections[0];
      const bbox = detection.boundingBox;
      currentDetection = detection;

      const profile = analyzeClothing(bbox);
      const areaRatio = (bbox.width * bbox.height) / (frameWidth * frameHeight);
      currentProfile = { ...profile, areaRatio };

      drawOverlay(bbox);
      updateStatus('Pessoa detectada! Clique em "Salvar Alvo" para gravar.', 'success');
      colorInfo.innerHTML = '<strong>Cor dominante:</strong> ' + profile.label + ' (RGB ' + profile.r + ', ' + profile.g + ', ' + profile.b + ')';
      sizeInfo.innerHTML = '<strong>Tamanho:</strong> ' + (areaRatio * 100).toFixed(1) + '% do quadro';
      saveBtn.disabled = false;

      animationFrameId = requestAnimationFrame(processFrame);
    }

    detectBtn.addEventListener('click', async () => {
      detectBtn.disabled = true;
      updateStatus('Carregando detector...', '');
      try {
        await ensureDetector();
        detecting = true;
        updateStatus('Detectando pessoas...', '');
        animationFrameId = requestAnimationFrame(processFrame);
        detectBtn.textContent = 'Detectando...';
      } catch (err) {
        updateStatus('Erro ao carregar detector: ' + err.message, 'error');
        detectBtn.disabled = false;
      }
    });

    saveBtn.addEventListener('click', () => {
      if (!currentDetection || !currentProfile) {
        updateStatus('Nenhuma detecção para salvar.', 'error');
        return;
      }
      const bbox = currentDetection.boundingBox;
      const snapshot = captureSnapshot(bbox);
      const targetData = {
        colorLabel: currentProfile.label,
        r: currentProfile.r,
        g: currentProfile.g,
        b: currentProfile.b,
        areaRatio: currentProfile.areaRatio,
        snapshot: snapshot,
        savedAt: new Date().toISOString()
      };
      localStorage.setItem('montebot_target', JSON.stringify(targetData));
      if (snapshot) snapshotImg.src = snapshot;
      targetStatusEl.textContent = 'Alvo salvo com sucesso!';
      targetStatusEl.style.color = '#51cf66';
      updateStatus('✅ Alvo salvo! Vá para o modo Live para iniciar o rastreamento.', 'success');
      clearBtn.disabled = false;
      console.log('[MonteBot][Config] Alvo salvo:', targetData);
    });

    clearBtn.addEventListener('click', () => {
      localStorage.removeItem('montebot_target');
      targetStatusEl.textContent = 'Nenhum alvo configurado';
      targetStatusEl.style.color = '';
      snapshotImg.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
      colorInfo.innerHTML = '<strong>Cor dominante:</strong> indefinida';
      sizeInfo.innerHTML = '<strong>Tamanho:</strong> indefinido';
      clearBtn.disabled = true;
      updateStatus('Alvo removido.', '');
      console.log('[MonteBot][Config] Alvo removido');
    });

    video.addEventListener('loadedmetadata', ensureVideoSizing);
    loadStream();
  </script>
</body>
</html>
CONFIGEOF
  chown www-data:www-data /var/www/html/config.html
  chmod 644 /var/www/html/config.html
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
    #controls-overlay {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 10;
    }
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
    .slide-handle:active { cursor: grabbing; }
    #slide-status {
      position: absolute;
      top: 85px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.8);
      padding: 8px 16px;
      border-radius: 15px;
      font-size: 1.2rem;
      color: #00c6ff;
      font-weight: 600;
      pointer-events: none;
    }
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
    .joystick-inner:active { cursor: grabbing; }
    .joystick-arrow {
      position: absolute;
      color: rgba(255, 255, 255, 0.3);
      font-size: 1.2rem;
      pointer-events: none;
    }
    .joystick-arrow.up { top: 10px; left: 50%; transform: translateX(-50%); }
    .joystick-arrow.down { bottom: 10px; left: 50%; transform: translateX(-50%); }
    .joystick-arrow.left { left: 10px; top: 50%; transform: translateY(-50%); }
    .joystick-arrow.right { right: 10px; top: 50%; transform: translateY(-50%); }
    #joystick-status {
      position: absolute;
      bottom: -40px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.8);
      padding: 8px 16px;
      border-radius: 15px;
      font-size: 1.2rem;
      color: #00c6ff;
      font-weight: 600;
      white-space: nowrap;
    }
    #detection-status {
      position: absolute;
      top: 20px;
      left: 20px;
      background: rgba(0, 0, 0, 0.8);
      padding: 15px 25px;
      border-radius: 15px;
      font-size: 2rem;
      color: #00c6ff;
      font-weight: 700;
      pointer-events: none;
      border: 2px solid rgba(0, 198, 255, 0.5);
      min-width: 60px;
      text-align: center;
    }
    #target-indicator {
      position: absolute;
      top: 90px;
      left: 20px;
      background: rgba(0, 100, 0, 0.7);
      padding: 8px 15px;
      border-radius: 10px;
      font-size: 0.8rem;
      color: #7fe1ff;
      pointer-events: none;
      border: 1px solid rgba(0, 255, 0, 0.5);
    }
    #target-indicator.no-target {
      background: rgba(100, 50, 0, 0.7);
      border-color: rgba(255, 165, 0, 0.5);
    }
    #serial-indicator {
      position: absolute;
      top: 130px;
      left: 20px;
      background: rgba(100, 0, 0, 0.7);
      padding: 8px 15px;
      border-radius: 10px;
      font-size: 0.8rem;
      color: #ff8888;
      pointer-events: none;
      border: 1px solid rgba(255, 0, 0, 0.5);
    }
    #serial-indicator.connected {
      background: rgba(0, 100, 0, 0.7);
      border-color: rgba(0, 255, 0, 0.5);
      color: #88ff88;
    }
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
    #back-button:hover { background: rgba(0, 198, 255, 0.2); transform: scale(1.05); }
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
    <video id="cameraStream" autoplay playsinline muted></video>
    <canvas id="overlay"></canvas>
  </div>

  <div id="controls-overlay">
    <div id="detection-status">P</div>
    <div id="target-indicator" class="no-target">⚠️ Sem alvo</div>
    <div id="serial-indicator" class="disconnected">🔴 Serial</div>

    <div id="slide-control">
      <div class="slide-container">
        <div class="slide-bar"></div>
        <div class="slide-handle" id="slideHandle"></div>
      </div>
      <div id="slide-status">P1</div>
    </div>

    <div id="joystick-control">
      <div class="joystick-container">
        <span class="joystick-arrow up">↑</span>
        <span class="joystick-arrow down">↓</span>
        <span class="joystick-arrow left">←</span>
        <span class="joystick-arrow right">→</span>
        <div class="joystick-inner" id="joystickHandle"></div>
      </div>
      <div id="joystick-status">P</div>
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
    const targetIndicator = document.getElementById('target-indicator');
    const serialIndicator = document.getElementById('serial-indicator');
    const source = 'stream/index.m3u8';

    // WebSocket for serial communication
    let ws = null;
    let wsReconnectTimer = null;
    let serialConnected = false;
    const WS_URL = 'ws://' + window.location.hostname + ':8765';

    function updateSerialStatus(connected, port) {
      serialConnected = connected;
      if (connected) {
        serialIndicator.textContent = '🟢 Serial' + (port ? ': ' + port : '');
        serialIndicator.className = 'connected';
      } else {
        serialIndicator.textContent = '🔴 Serial';
        serialIndicator.className = 'disconnected';
      }
    }

    function updateWsStatus(connected) {
      // Update WS indicator in serial indicator if disconnected
      if (!connected) {
        serialIndicator.textContent = '🔴 WS Offline';
        serialIndicator.className = 'disconnected';
      }
    }

    function connectWebSocket() {
      if (ws && ws.readyState === WebSocket.OPEN) return;
      
      try {
        console.log('[MonteBot] Conectando ao WebSocket:', WS_URL);
        ws = new WebSocket(WS_URL);
        
        ws.onopen = () => {
          console.log('[MonteBot] WebSocket conectado');
          updateWsStatus(true);
          if (wsReconnectTimer) {
            clearTimeout(wsReconnectTimer);
            wsReconnectTimer = null;
          }
        };
        
        ws.onclose = () => {
          console.log('[MonteBot] WebSocket desconectado, tentando reconectar em 3s...');
          updateWsStatus(false);
          updateSerialStatus(false, null);
          ws = null;
          wsReconnectTimer = setTimeout(connectWebSocket, 3000);
        };
        
        ws.onerror = (e) => {
          console.warn('[MonteBot] WebSocket erro:', e);
          updateWsStatus(false);
        };
        
        ws.onmessage = (e) => {
          try {
            const data = JSON.parse(e.data);
            
            // Handle status updates
            if (data.type === 'status') {
              if (data.serial) {
                updateSerialStatus(data.serial.connected, data.serial.port);
              }
              console.log('[MonteBot] Status:', data);
            }
            // Handle command results
            else if (data.type === 'command_result') {
              console.log('[MonteBot] Comando:', data.command, 'Sucesso:', data.success);
              if (data.serial_connected !== undefined) {
                updateSerialStatus(data.serial_connected, null);
              }
            }
            // Handle log entries
            else if (data.type === 'log') {
              const entry = data.entry;
              console.log('[MonteBot][' + entry.source + '] ' + entry.message);
              
              // Update serial status from log entries
              if (entry.source === 'SERIAL') {
                if (entry.message.includes('Connected to serial') || entry.message.includes('✅')) {
                  updateSerialStatus(true, entry.data?.port);
                } else if (entry.message.includes('No serial') || entry.message.includes('❌')) {
                  updateSerialStatus(false, null);
                }
              }
            }
          } catch (err) {
            // Fallback for plain text messages
            console.log('[MonteBot] Resposta:', e.data);
          }
        };
      } catch (e) {
        console.warn('[MonteBot] Falha ao conectar WebSocket:', e);
        updateWsStatus(false);
        wsReconnectTimer = setTimeout(connectWebSocket, 3000);
      }
    }

    function sendCommand(cmd) {
      console.log('[MonteBot] Enviando comando:', cmd);
      if (ws && ws.readyState === WebSocket.OPEN) {
        // Send as JSON for better handling
        ws.send(JSON.stringify({ type: 'command', cmd: cmd }));
      } else {
        console.warn('[MonteBot] WebSocket não conectado, comando não enviado:', cmd);
      }
    }

    // Initialize WebSocket connection
    connectWebSocket();

    // Load saved target profile
    let savedTarget = null;
    const savedTargetStr = localStorage.getItem('montebot_target');
    if (savedTargetStr) {
      savedTarget = JSON.parse(savedTargetStr);
      targetIndicator.textContent = '✅ Alvo: ' + savedTarget.colorLabel;
      targetIndicator.classList.remove('no-target');
      console.log('[MonteBot] Alvo carregado:', savedTarget);
    }

    // MediaPipe variables
    let visionModule = null;
    let detector = null;
    let trackingActive = false;
    let lastVideoTime = -1;
    let animationFrameId = 0;
    let frameWidth = 1920;
    let frameHeight = 1080;
    let lostFrames = 0;
    const MIN_DISTANCE_AREA = 0.20;  // Stop at ~2m distance
    const MAX_DISTANCE_AREA = 0.30;  // Back up when too close
    
    // Smart tracking thresholds
    const OFFSET_SLIGHT = 0.10;      // Slight offset - simple turn
    const OFFSET_MEDIUM = 0.25;      // Medium offset - turn + forward
    const OFFSET_EXTREME = 0.40;     // Extreme offset - head turn + track maneuver
    
    // Head servo positions (matching Arduino constants)
    const HEAD_CENTER = 90;          // Center position
    const HEAD_MAX_LEFT = 180;       // Maximum left (0-90 range from center)
    const HEAD_MAX_RIGHT = 0;        // Maximum right (0-90 range from center)
    
    // Tracking state
    let lastHeadPosition = HEAD_CENTER;
    let trackingCooldown = 0;        // Prevent rapid command spam
    const TRACKING_COOLDOWN_MS = 500; // Min time between tracking maneuvers

    const analysisCanvas = document.createElement('canvas');
    const analysisCtx = analysisCanvas.getContext('2d', { willReadFrequently: true });

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
          console.error('[MonteBot] HLS não suportado');
          return;
        }
        const hls = new Hls({ enableWorker: true, lowLatencyMode: true, backBufferLength: 10, maxBufferLength: 5 });
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
    let lastSlideCmd = 'P1';

    function updateSlidePosition(clientX) {
      const container = slideHandle.parentElement;
      const rect = container.getBoundingClientRect();
      const x = clientX - rect.left;
      const centerX = rect.width / 2;
      const maxOffset = rect.width / 2 - 25;
      let offset = x - centerX;
      offset = Math.max(-maxOffset, Math.min(maxOffset, offset));
      slideHandle.style.left = `calc(50% + ${offset}px)`;

      let cmd;
      if (offset > 30) {
        cmd = 'D1';
      } else if (offset < -30) {
        cmd = 'E1';
      } else {
        cmd = 'P1';
      }
      
      if (cmd !== lastSlideCmd) {
        lastSlideCmd = cmd;
        slideStatus.textContent = cmd;
        sendCommand(cmd);
      }
    }

    slideHandle.addEventListener('mousedown', () => { isDraggingSlide = true; });
    slideHandle.addEventListener('touchstart', () => { isDraggingSlide = true; });
    document.addEventListener('mousemove', (e) => { if (isDraggingSlide) updateSlidePosition(e.clientX); });
    document.addEventListener('touchmove', (e) => { if (isDraggingSlide) updateSlidePosition(e.touches[0].clientX); });
    document.addEventListener('mouseup', () => {
      if (isDraggingSlide) {
        isDraggingSlide = false;
        slideHandle.style.left = '50%';
        slideStatus.textContent = 'P1';
        if (lastSlideCmd !== 'P1') {
          lastSlideCmd = 'P1';
          sendCommand('P1');
        }
      }
    });
    document.addEventListener('touchend', () => {
      if (isDraggingSlide) {
        isDraggingSlide = false;
        slideHandle.style.left = '50%';
        slideStatus.textContent = 'P1';
        if (lastSlideCmd !== 'P1') {
          lastSlideCmd = 'P1';
          sendCommand('P1');
        }
      }
    });

    // JOYSTICK CONTROL
    let isDraggingJoystick = false;
    let lastJoystickCmd = 'P';

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

      let cmd = 'P';
      const threshold = 20;
      if (Math.abs(offsetY) > Math.abs(offsetX)) {
        if (offsetY < -threshold) {
          cmd = 'F';
        } else if (offsetY > threshold) {
          cmd = 'T';
        }
      } else {
        if (offsetX > threshold) {
          cmd = 'D';
        } else if (offsetX < -threshold) {
          cmd = 'E';
        }
      }
      
      if (cmd !== lastJoystickCmd) {
        lastJoystickCmd = cmd;
        joystickStatus.textContent = cmd;
        sendCommand(cmd);
      }
    }

    joystickHandle.addEventListener('mousedown', () => { isDraggingJoystick = true; });
    joystickHandle.addEventListener('touchstart', () => { isDraggingJoystick = true; });
    document.addEventListener('mousemove', (e) => { if (isDraggingJoystick) updateJoystickPosition(e.clientX, e.clientY); });
    document.addEventListener('touchmove', (e) => { if (isDraggingJoystick) updateJoystickPosition(e.touches[0].clientX, e.touches[0].clientY); });
    document.addEventListener('mouseup', () => {
      if (isDraggingJoystick) {
        isDraggingJoystick = false;
        joystickHandle.style.left = '50%';
        joystickHandle.style.top = '50%';
        joystickStatus.textContent = 'P';
        if (lastJoystickCmd !== 'P') {
          lastJoystickCmd = 'P';
          sendCommand('P');
        }
      }
    });
    document.addEventListener('touchend', () => {
      if (isDraggingJoystick) {
        isDraggingJoystick = false;
        joystickHandle.style.left = '50%';
        joystickHandle.style.top = '50%';
        joystickStatus.textContent = 'P';
        if (lastJoystickCmd !== 'P') {
          lastJoystickCmd = 'P';
          sendCommand('P');
        }
      }
    });

    // COLOR ANALYSIS
    function describeColor(r, g, b) {
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const luminance = (max + min) / 2;
      const delta = max - min;
      let hue = 0, saturation = 0;
      if (delta !== 0) {
        saturation = luminance > 127 ? delta / (510 - max - min) : delta / (max + min);
        switch (max) {
          case r: hue = ((g - b) / delta) % 6; break;
          case g: hue = (b - r) / delta + 2; break;
          default: hue = (r - g) / delta + 4;
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
      if (!analysisCtx || !bbox) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      analysisCtx.drawImage(video, 0, 0, analysisCanvas.width, analysisCanvas.height);
      const x = Math.max(0, Math.floor(bbox.originX));
      const y = Math.max(0, Math.floor(bbox.originY));
      const width = Math.min(Math.floor(bbox.width), analysisCanvas.width - x);
      const height = Math.min(Math.floor(bbox.height), analysisCanvas.height - y);
      if (width <= 0 || height <= 0) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      let imageData;
      try { imageData = analysisCtx.getImageData(x, y, width, height); } catch (err) { return { label: 'indefinido', r: 0, g: 0, b: 0 }; }
      const data = imageData.data;
      if (!data || !data.length) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      let r = 0, g = 0, b = 0, count = 0;
      const step = Math.max(1, Math.floor(data.length / (4 * 6000)));
      for (let i = 0; i < data.length; i += 4 * step) { r += data[i]; g += data[i + 1]; b += data[i + 2]; count++; }
      if (count === 0) return { label: 'indefinido', r: 0, g: 0, b: 0 };
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);
      return { label: describeColor(r, g, b), r, g, b };
    }

    function colorDistance(a, b) {
      if (!a || !b) return Infinity;
      const dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
      return Math.sqrt(dr * dr + dg * dg + db * db) / 442;
    }

    // MEDIAPIPE DETECTION
    async function loadVisionModule() {
      if (visionModule) return visionModule;
      const visionSources = ['./static/mediapipe/vision_bundle.js', 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/vision_bundle.js'];
      for (const src of visionSources) {
        try {
          const mod = await import(src);
          if (mod && mod.FilesetResolver && mod.ObjectDetector) { visionModule = mod; return visionModule; }
        } catch (err) { console.warn('[MediaPipe] Falha ao importar', src, err); }
      }
      throw new Error('Nenhum vision_bundle disponível.');
    }

    async function ensureDetector() {
      if (detector) return detector;
      const visionApi = await loadVisionModule();
      const wasmBases = ['static/mediapipe/wasm', 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/wasm'];
      const modelUris = ['static/models/efficientdet_lite0.tflite', 'https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite'];
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
          } catch (err) { console.warn('[MediaPipe] Falha ao abrir modelo', model, 'via', base, err); }
        }
      }
      throw new Error('Falha ao criar detector MediaPipe');
    }

    function drawOverlay(bbox, isTarget = false) {
      overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
      if (!bbox) return;
      overlayCtx.strokeStyle = isTarget ? 'rgba(0, 255, 0, 0.85)' : 'rgba(0, 214, 255, 0.85)';
      overlayCtx.lineWidth = 4;
      overlayCtx.setLineDash([12, 8]);
      overlayCtx.strokeRect(bbox.originX, bbox.originY, bbox.width, bbox.height);
      overlayCtx.setLineDash([]);
      const centerX = bbox.originX + bbox.width / 2;
      const centerY = bbox.originY + bbox.height / 2;
      overlayCtx.fillStyle = isTarget ? 'rgba(0, 255, 0, 0.85)' : 'rgba(0, 214, 255, 0.85)';
      overlayCtx.beginPath();
      overlayCtx.arc(centerX, centerY, 8, 0, Math.PI * 2);
      overlayCtx.fill();
      if (isTarget) {
        overlayCtx.font = 'bold 20px sans-serif';
        overlayCtx.fillStyle = '#00ff00';
        overlayCtx.fillText('ALVO', bbox.originX, bbox.originY - 10);
      }
    }

    function chooseDetection(detections) {
      if (!detections || detections.length === 0) return null;
      if (!savedTarget) {
        // No saved target, choose largest person
        let best = null, bestArea = 0;
        for (const d of detections) {
          if (!d.boundingBox) continue;
          const area = d.boundingBox.width * d.boundingBox.height;
          if (area > bestArea) { bestArea = area; best = d; }
        }
        return best ? { detection: best, isTarget: false } : null;
      }
      // Match by color
      let bestDetection = null, bestScore = Infinity;
      for (const d of detections) {
        if (!d.boundingBox) continue;
        const profile = analyzeClothing(d.boundingBox);
        const colorDist = colorDistance(profile, savedTarget);
        if (colorDist < bestScore) { bestScore = colorDist; bestDetection = d; }
      }
      return bestDetection ? { detection: bestDetection, isTarget: bestScore < 0.4 } : null;
    }

    let lastDetectionCmd = 'P';

    /**
     * Calculate head servo position based on user offset
     * Maps offset (-0.5 to 0.5) to servo angle (0-180)
     * Limits maximum rotation to 90 degrees from center
     */
    function calculateHeadPosition(offset) {
      // Map offset to servo position
      // offset = -0.5 (far left) -> servo = 180 (look left)
      // offset = 0 (center) -> servo = 90 (look straight)
      // offset = 0.5 (far right) -> servo = 0 (look right)
      let pos = HEAD_CENTER - (offset * 180);
      
      // Limit to valid range (0-180)
      if (pos < HEAD_MAX_RIGHT) pos = HEAD_MAX_RIGHT;
      if (pos > HEAD_MAX_LEFT) pos = HEAD_MAX_LEFT;
      
      return Math.round(pos);
    }
    
    /**
     * Send head servo command
     */
    function sendHeadCommand(position) {
      if (position !== lastHeadPosition) {
        lastHeadPosition = position;
        sendCommand('H' + position);
        console.log('[MonteBot] Head position:', position);
      }
    }

    function computeMovement(bbox) {
      let cmd = 'P';
      let headCmd = null;
      const now = Date.now();
      
      if (!bbox) {
        if (cmd !== lastDetectionCmd) {
          lastDetectionCmd = cmd;
          detectionStatus.textContent = cmd;
          localStorage.setItem('montebot_position', cmd);
          sendCommand(cmd);
        }
        // Center head when no target
        if (lastHeadPosition !== HEAD_CENTER) {
          sendHeadCommand(HEAD_CENTER);
        }
        return;
      }
      
      const frameArea = Math.max(1, frameWidth * frameHeight);
      const centerX = bbox.originX + bbox.width / 2;
      const areaRatio = (bbox.width * bbox.height) / frameArea;
      const offset = centerX / frameWidth - 0.5;  // -0.5 to 0.5 (left to right)
      const absOffset = Math.abs(offset);

      // Too close - back up (T = Trás)
      if (areaRatio >= MAX_DISTANCE_AREA) {
        cmd = 'T';
        // Center head when backing up
        headCmd = HEAD_CENTER;
      }
      // Good distance - stop (P = Parado)
      else if (areaRatio >= MIN_DISTANCE_AREA) {
        cmd = 'P';
        // Center head when at good distance
        headCmd = HEAD_CENTER;
      }
      // Person is significantly off-center - need to track
      else if (absOffset > OFFSET_SLIGHT) {
        
        // EXTREME offset - person is very far to one side
        // First move head to look at them, then do tracking maneuver
        if (absOffset > OFFSET_EXTREME) {
          // Calculate head position to look at user (max 90 degrees from center)
          headCmd = calculateHeadPosition(offset);
          
          // Check cooldown for tracking maneuver
          if (now - trackingCooldown > TRACKING_COOLDOWN_MS) {
            // Send smart tracking command (TE or TD)
            // This makes the robot: turn, advance, return to forward
            if (offset < 0) {
              cmd = 'TE';  // Track left
            } else {
              cmd = 'TD';  // Track right
            }
            trackingCooldown = now;
          } else {
            // During cooldown, just turn towards user
            if (offset < 0) {
              cmd = 'E';
            } else {
              cmd = 'D';
            }
          }
        }
        // MEDIUM offset - turn + forward to realign
        else if (absOffset > OFFSET_MEDIUM) {
          // Slight head movement to track user
          headCmd = calculateHeadPosition(offset * 0.5);  // Less aggressive head turn
          
          // Check cooldown for tracking maneuver
          if (now - trackingCooldown > TRACKING_COOLDOWN_MS) {
            if (offset < 0) {
              cmd = 'TE';  // Track left
            } else {
              cmd = 'TD';  // Track right  
            }
            trackingCooldown = now;
          } else {
            cmd = 'F';  // Move forward during cooldown
          }
        }
        // SLIGHT offset - simple turn to align
        else {
          headCmd = HEAD_CENTER;  // Keep head centered
          if (offset < 0) {
            cmd = 'E';  // Turn left
          } else {
            cmd = 'D';  // Turn right
          }
        }
      }
      // Person is centered - go forward (F = Frente)
      else {
        cmd = 'F';
        headCmd = HEAD_CENTER;  // Keep head centered when moving forward
      }

      // Send head command if needed
      if (headCmd !== null) {
        sendHeadCommand(headCmd);
      }

      // Send movement command
      if (cmd !== lastDetectionCmd) {
        lastDetectionCmd = cmd;
        detectionStatus.textContent = cmd;
        localStorage.setItem('montebot_position', cmd);
        sendCommand(cmd);
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
      try { result = detector.detectForVideo(video, nowInMs); }
      catch (err) { console.error('[MediaPipe] Erro durante detectForVideo', err); animationFrameId = requestAnimationFrame(processFrame); return; }

      if (!result || !result.detections || result.detections.length === 0) {
        lostFrames++;
        if (lostFrames > 30) {
          overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
          if (lastDetectionCmd !== 'P') {
            lastDetectionCmd = 'P';
            detectionStatus.textContent = 'P';
            localStorage.setItem('montebot_position', 'P');
            sendCommand('P');
          }
        }
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      lostFrames = 0;
      const selection = chooseDetection(result.detections);
      if (!selection) {
        overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
        if (lastDetectionCmd !== 'P') {
          lastDetectionCmd = 'P';
          detectionStatus.textContent = 'P';
          localStorage.setItem('montebot_position', 'P');
          sendCommand('P');
        }
        animationFrameId = requestAnimationFrame(processFrame);
        return;
      }

      const bbox = selection.detection.boundingBox;
      drawOverlay(bbox, selection.isTarget);
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

create_position_page() {
  cat <<'POSITIONEOF' >/var/www/html/position.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Posição</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' ry='12' fill='%23002233'/%3E%3Cpath d='M16 42l8-20h4l8 20h-4l-1.8-5.2h-9.2L20 42zm7.4-8.4h6.4L27 24.4zM40 22h4v20h-4z' fill='%2300c6ff'/%3E%3C/svg%3E" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #000;
      color: #fff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
    }
    #position-display {
      font-size: 40vw;
      font-weight: 900;
      color: #00c6ff;
      text-shadow: 0 0 60px rgba(0, 198, 255, 0.6);
      line-height: 1;
      transition: color 0.1s ease;
    }
    #position-display.cmd-F { color: #00ff00; }
    #position-display.cmd-T { color: #ff4444; }
    #position-display.cmd-D { color: #ffaa00; }
    #position-display.cmd-E { color: #ffaa00; }
    #position-display.cmd-P { color: #888888; }
    #info {
      position: absolute;
      bottom: 20px;
      left: 20px;
      font-size: 0.9rem;
      color: rgba(255, 255, 255, 0.5);
    }
    #info p { margin: 5px 0; }
    #legend {
      position: absolute;
      top: 20px;
      right: 20px;
      background: rgba(0, 0, 0, 0.8);
      border: 1px solid rgba(0, 198, 255, 0.3);
      border-radius: 10px;
      padding: 15px;
      font-size: 0.85rem;
    }
    #legend h3 {
      color: #00c6ff;
      margin-bottom: 10px;
      font-size: 1rem;
    }
    #legend ul {
      list-style: none;
      padding: 0;
    }
    #legend li {
      margin: 8px 0;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    #legend .code {
      display: inline-block;
      width: 30px;
      height: 30px;
      line-height: 30px;
      text-align: center;
      border-radius: 5px;
      font-weight: 700;
    }
    #legend .code-F { background: #00ff00; color: #000; }
    #legend .code-T { background: #ff4444; color: #fff; }
    #legend .code-D { background: #ffaa00; color: #000; }
    #legend .code-E { background: #ffaa00; color: #000; }
    #legend .code-P { background: #888888; color: #fff; }
    #back-link {
      position: absolute;
      bottom: 20px;
      right: 20px;
      background: rgba(0, 0, 0, 0.7);
      border: 1px solid rgba(0, 198, 255, 0.5);
      color: #00c6ff;
      padding: 10px 20px;
      border-radius: 20px;
      font-size: 0.9rem;
      text-decoration: none;
      transition: all 0.3s ease;
    }
    #back-link:hover {
      background: rgba(0, 198, 255, 0.2);
    }
    #status-indicator {
      position: absolute;
      top: 20px;
      left: 20px;
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 0.9rem;
    }
    #status-dot {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #888;
      animation: pulse 1.5s infinite;
    }
    #status-dot.active { background: #00ff00; }
    #status-dot.inactive { background: #ff4444; animation: none; }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
  </style>
</head>
<body>
  <div id="status-indicator">
    <div id="status-dot"></div>
    <span id="status-text">Aguardando dados...</span>
  </div>

  <div id="position-display">P</div>

  <div id="legend">
    <h3>Legenda</h3>
    <ul>
      <li><span class="code code-F">F</span> Frente (avançar)</li>
      <li><span class="code code-T">T</span> Trás (recuar)</li>
      <li><span class="code code-D">D</span> Direita (virar)</li>
      <li><span class="code code-E">E</span> Esquerda (virar)</li>
      <li><span class="code code-P">P</span> Parado (manter)</li>
    </ul>
  </div>

  <div id="info">
    <p>Esta página exibe o comando de posição em tempo real.</p>
    <p>Abra a página <strong>/live.html</strong> em outro dispositivo para gerar os comandos.</p>
  </div>

  <a id="back-link" href="/">← Menu</a>

  <script>
    const display = document.getElementById('position-display');
    const statusDot = document.getElementById('status-dot');
    const statusText = document.getElementById('status-text');
    let lastUpdate = 0;
    let lastPosition = 'P';
    let updateCount = 0;
    const UPDATE_INTERVAL_MS = 1000 / 30;  // 30fps refresh rate

    function updateDisplay() {
      const position = localStorage.getItem('montebot_position') || 'P';
      const now = Date.now();

      // Check if data is being updated
      if (position !== lastPosition) {
        lastPosition = position;
        lastUpdate = now;
        updateCount++;
      }

      // Update display
      display.textContent = position;
      display.className = 'cmd-' + position;

      // Update status indicator
      const timeSinceUpdate = now - lastUpdate;
      if (lastUpdate === 0) {
        statusDot.className = '';
        statusText.textContent = 'Aguardando dados...';
      } else if (timeSinceUpdate < 5000) {
        statusDot.className = 'active';
        statusText.textContent = 'Recebendo dados (' + updateCount + ' comandos)';
      } else {
        statusDot.className = 'inactive';
        statusText.textContent = 'Sem atualizações há ' + Math.round(timeSinceUpdate / 1000) + 's';
      }

      // Output to console for motor integration
      console.log('[MonteBot][Position] ' + position);
    }

    // Update at 30fps for smooth real-time display
    setInterval(updateDisplay, UPDATE_INTERVAL_MS);

    // Initial update
    updateDisplay();
  </script>
</body>
</html>
POSITIONEOF
  chown www-data:www-data /var/www/html/position.html
  chmod 644 /var/www/html/position.html
}

create_logs_page() {
  cat <<'LOGSEOF' >/var/www/html/logs.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>Monte Bot - Logs em Tempo Real</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' ry='12' fill='%23002233'/%3E%3Cpath d='M16 42l8-20h4l8 20h-4l-1.8-5.2h-9.2L20 42zm7.4-8.4h6.4L27 24.4zM40 22h4v20h-4z' fill='%2300c6ff'/%3E%3C/svg%3E" />
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: "SF Mono", Monaco, "Cascadia Code", "Consolas", monospace;
      background: #0a0a0a;
      color: #e2f3ff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    .header {
      background: rgba(0, 14, 30, 0.9);
      border-bottom: 1px solid rgba(0, 140, 255, 0.3);
      padding: 15px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 15px;
    }
    .header-left {
      display: flex;
      align-items: center;
      gap: 15px;
    }
    .back-link {
      color: #7fe1ff;
      text-decoration: none;
      font-size: 0.9rem;
    }
    .back-link:hover { text-decoration: underline; }
    h1 {
      font-size: 1.3rem;
      letter-spacing: 0.05rem;
      color: #7fe1ff;
    }
    .status-indicators {
      display: flex;
      gap: 15px;
      flex-wrap: wrap;
    }
    .status-badge {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 0.8rem;
      font-weight: 500;
    }
    .status-badge.connected {
      background: rgba(0, 100, 0, 0.4);
      border: 1px solid rgba(0, 255, 0, 0.4);
      color: #88ff88;
    }
    .status-badge.disconnected {
      background: rgba(100, 0, 0, 0.4);
      border: 1px solid rgba(255, 0, 0, 0.4);
      color: #ff8888;
    }
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    .status-badge.connected .status-dot { background: #00ff00; }
    .status-badge.disconnected .status-dot { background: #ff4444; animation: none; }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.4; }
    }
    .toolbar {
      background: rgba(0, 14, 30, 0.6);
      border-bottom: 1px solid rgba(0, 140, 255, 0.2);
      padding: 10px 20px;
      display: flex;
      align-items: center;
      gap: 15px;
      flex-wrap: wrap;
    }
    .toolbar-group {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .toolbar label {
      font-size: 0.8rem;
      color: rgba(226, 243, 255, 0.7);
    }
    .toolbar select, .toolbar input {
      background: rgba(0, 0, 0, 0.5);
      border: 1px solid rgba(0, 140, 255, 0.3);
      border-radius: 6px;
      padding: 6px 10px;
      color: #e2f3ff;
      font-size: 0.85rem;
    }
    .toolbar button {
      background: linear-gradient(135deg, #00c6ff, #0072ff);
      color: #032131;
      font-weight: 600;
      border: none;
      border-radius: 6px;
      padding: 8px 16px;
      cursor: pointer;
      font-size: 0.85rem;
      transition: all 0.2s ease;
    }
    .toolbar button:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(0, 153, 255, 0.3);
    }
    .toolbar button.danger {
      background: linear-gradient(135deg, #ff6b6b, #c92a2a);
    }
    .toolbar button.secondary {
      background: rgba(0, 140, 255, 0.2);
      border: 1px solid rgba(0, 140, 255, 0.4);
      color: #7fe1ff;
    }
    .stats-bar {
      background: rgba(0, 0, 0, 0.3);
      padding: 8px 20px;
      display: flex;
      gap: 20px;
      font-size: 0.75rem;
      color: rgba(226, 243, 255, 0.6);
      border-bottom: 1px solid rgba(0, 140, 255, 0.1);
    }
    .stat {
      display: flex;
      gap: 6px;
    }
    .stat-value {
      color: #7fe1ff;
      font-weight: 600;
    }
    .log-container {
      flex: 1;
      overflow-y: auto;
      padding: 10px 20px;
    }
    .log-entry {
      padding: 6px 12px;
      margin-bottom: 2px;
      border-radius: 4px;
      font-size: 0.85rem;
      line-height: 1.5;
      display: flex;
      gap: 12px;
      align-items: flex-start;
    }
    .log-entry:hover {
      background: rgba(255, 255, 255, 0.03);
    }
    .log-time {
      color: rgba(226, 243, 255, 0.4);
      font-size: 0.75rem;
      min-width: 85px;
      flex-shrink: 0;
    }
    .log-source {
      font-weight: 600;
      min-width: 80px;
      flex-shrink: 0;
    }
    .log-source.WEBSOCKET { color: #9b59b6; }
    .log-source.SERIAL { color: #e74c3c; }
    .log-source.COMMAND { color: #3498db; }
    .log-source.SYSTEM { color: #2ecc71; }
    .log-source.ARDUINO { color: #f39c12; }
    .log-level {
      font-size: 0.7rem;
      padding: 2px 6px;
      border-radius: 3px;
      min-width: 50px;
      text-align: center;
      flex-shrink: 0;
    }
    .log-level.INFO { background: rgba(52, 152, 219, 0.3); color: #3498db; }
    .log-level.DEBUG { background: rgba(149, 165, 166, 0.3); color: #95a5a6; }
    .log-level.WARNING { background: rgba(241, 196, 15, 0.3); color: #f1c40f; }
    .log-level.ERROR { background: rgba(231, 76, 60, 0.3); color: #e74c3c; }
    .log-message {
      flex: 1;
      word-break: break-word;
    }
    .log-data {
      font-size: 0.75rem;
      color: rgba(226, 243, 255, 0.5);
      margin-left: 180px;
      padding: 4px 8px;
      background: rgba(0, 0, 0, 0.3);
      border-radius: 4px;
      margin-top: 4px;
    }
    .command-input-area {
      background: rgba(0, 14, 30, 0.9);
      border-top: 1px solid rgba(0, 140, 255, 0.3);
      padding: 15px 20px;
    }
    .command-input-wrapper {
      display: flex;
      gap: 10px;
      max-width: 800px;
    }
    .command-input {
      flex: 1;
      background: rgba(0, 0, 0, 0.5);
      border: 1px solid rgba(0, 140, 255, 0.4);
      border-radius: 8px;
      padding: 12px 16px;
      color: #e2f3ff;
      font-family: inherit;
      font-size: 1rem;
    }
    .command-input:focus {
      outline: none;
      border-color: #00c6ff;
      box-shadow: 0 0 0 2px rgba(0, 198, 255, 0.2);
    }
    .quick-commands {
      display: flex;
      gap: 8px;
      margin-top: 10px;
      flex-wrap: wrap;
    }
    .quick-cmd {
      background: rgba(0, 140, 255, 0.15);
      border: 1px solid rgba(0, 140, 255, 0.3);
      color: #7fe1ff;
      padding: 8px 16px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.9rem;
      font-weight: 600;
      transition: all 0.2s ease;
    }
    .quick-cmd:hover {
      background: rgba(0, 140, 255, 0.3);
      transform: translateY(-1px);
    }
    .quick-cmd.forward { border-color: #2ecc71; color: #2ecc71; }
    .quick-cmd.back { border-color: #e74c3c; color: #e74c3c; }
    .quick-cmd.left { border-color: #f39c12; color: #f39c12; }
    .quick-cmd.right { border-color: #f39c12; color: #f39c12; }
    .quick-cmd.stop { border-color: #95a5a6; color: #95a5a6; }
    .empty-state {
      text-align: center;
      padding: 60px 20px;
      color: rgba(226, 243, 255, 0.4);
    }
    .empty-state h2 {
      font-size: 1.2rem;
      margin-bottom: 10px;
      color: rgba(226, 243, 255, 0.6);
    }
    #auto-scroll-indicator {
      position: fixed;
      bottom: 120px;
      right: 20px;
      background: rgba(0, 0, 0, 0.8);
      border: 1px solid rgba(0, 140, 255, 0.4);
      padding: 8px 16px;
      border-radius: 20px;
      font-size: 0.8rem;
      color: #7fe1ff;
      cursor: pointer;
      display: none;
    }
    @media (max-width: 768px) {
      .header { padding: 10px 15px; }
      h1 { font-size: 1.1rem; }
      .log-entry { flex-wrap: wrap; font-size: 0.8rem; gap: 6px; }
      .log-time { min-width: auto; }
      .log-source { min-width: 60px; }
      .log-data { margin-left: 0; }
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="header-left">
      <a href="/" class="back-link">← Menu</a>
      <h1>📋 Logs em Tempo Real</h1>
    </div>
    <div class="status-indicators">
      <div id="ws-status" class="status-badge disconnected">
        <span class="status-dot"></span>
        <span id="ws-status-text">WebSocket: Desconectado</span>
      </div>
      <div id="serial-status" class="status-badge disconnected">
        <span class="status-dot"></span>
        <span id="serial-status-text">Serial: Desconectado</span>
      </div>
    </div>
  </div>

  <div class="toolbar">
    <div class="toolbar-group">
      <label>Filtrar por fonte:</label>
      <select id="filter-source">
        <option value="">Todas</option>
        <option value="WEBSOCKET">WebSocket</option>
        <option value="SERIAL">Serial</option>
        <option value="COMMAND">Comandos</option>
        <option value="ARDUINO">Arduino</option>
        <option value="SYSTEM">Sistema</option>
      </select>
    </div>
    <div class="toolbar-group">
      <label>Nível mínimo:</label>
      <select id="filter-level">
        <option value="DEBUG">DEBUG</option>
        <option value="INFO" selected>INFO</option>
        <option value="WARNING">WARNING</option>
        <option value="ERROR">ERROR</option>
      </select>
    </div>
    <div class="toolbar-group">
      <input type="text" id="filter-text" placeholder="Buscar nos logs...">
    </div>
    <button id="clear-logs" class="danger">Limpar Logs</button>
    <button id="reconnect-ws" class="secondary">Reconectar WS</button>
    <button id="reconnect-serial" class="secondary">Reconectar Serial</button>
  </div>

  <div class="stats-bar">
    <div class="stat">Logs: <span id="stat-logs" class="stat-value">0</span></div>
    <div class="stat">Comandos enviados: <span id="stat-sent" class="stat-value">0</span></div>
    <div class="stat">Comandos falhos: <span id="stat-failed" class="stat-value">0</span></div>
    <div class="stat">Último comando: <span id="stat-last-cmd" class="stat-value">-</span></div>
    <div class="stat">Porta Serial: <span id="stat-port" class="stat-value">-</span></div>
  </div>

  <div class="log-container" id="log-container">
    <div class="empty-state" id="empty-state">
      <h2>Aguardando logs...</h2>
      <p>Os logs aparecerão aqui quando o sistema estiver ativo.</p>
    </div>
  </div>

  <div id="auto-scroll-indicator" onclick="enableAutoScroll()">
    ↓ Novos logs disponíveis - Clique para rolar
  </div>

  <div class="command-input-area">
    <div class="command-input-wrapper">
      <input type="text" id="command-input" class="command-input" placeholder="Digite um comando para enviar ao Arduino (ex: F, T, E, D, P, TE, TD, H90)..." />
      <button id="send-command">Enviar</button>
    </div>
    <div class="quick-commands">
      <button class="quick-cmd forward" data-cmd="F">F - Frente</button>
      <button class="quick-cmd back" data-cmd="T">T - Trás</button>
      <button class="quick-cmd left" data-cmd="E">E - Esquerda</button>
      <button class="quick-cmd right" data-cmd="D">D - Direita</button>
      <button class="quick-cmd stop" data-cmd="P">P - Parar</button>
      <button class="quick-cmd" data-cmd="E1">E1 - Slide Esq</button>
      <button class="quick-cmd" data-cmd="D1">D1 - Slide Dir</button>
      <button class="quick-cmd" data-cmd="P1">P1 - Slide Centro</button>
      <button class="quick-cmd left" data-cmd="TE">TE - Track Esq</button>
      <button class="quick-cmd right" data-cmd="TD">TD - Track Dir</button>
      <button class="quick-cmd" data-cmd="H0">H0 - Cabeça Dir</button>
      <button class="quick-cmd" data-cmd="H90">H90 - Cabeça Centro</button>
      <button class="quick-cmd" data-cmd="H180">H180 - Cabeça Esq</button>
    </div>
  </div>

  <script>
    // Configuration
    const WS_URL = 'ws://' + window.location.hostname + ':8765';
    const LOG_LEVELS = { DEBUG: 0, INFO: 1, WARNING: 2, ERROR: 3 };

    // State
    let ws = null;
    let logs = [];
    let autoScroll = true;
    let reconnectTimer = null;
    let stats = { sent: 0, failed: 0, lastCommand: null };

    // DOM elements
    const logContainer = document.getElementById('log-container');
    const emptyState = document.getElementById('empty-state');
    const wsStatus = document.getElementById('ws-status');
    const wsStatusText = document.getElementById('ws-status-text');
    const serialStatus = document.getElementById('serial-status');
    const serialStatusText = document.getElementById('serial-status-text');
    const filterSource = document.getElementById('filter-source');
    const filterLevel = document.getElementById('filter-level');
    const filterText = document.getElementById('filter-text');
    const commandInput = document.getElementById('command-input');
    const autoScrollIndicator = document.getElementById('auto-scroll-indicator');

    // Stats elements
    const statLogs = document.getElementById('stat-logs');
    const statSent = document.getElementById('stat-sent');
    const statFailed = document.getElementById('stat-failed');
    const statLastCmd = document.getElementById('stat-last-cmd');
    const statPort = document.getElementById('stat-port');

    function formatTime(timestamp) {
      const date = new Date(timestamp);
      return date.toLocaleTimeString('pt-BR', { 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit',
        fractionalSecondDigits: 3
      });
    }

    function createLogElement(entry) {
      const div = document.createElement('div');
      div.className = 'log-entry';
      div.dataset.source = entry.source;
      div.dataset.level = entry.level;
      
      const time = document.createElement('span');
      time.className = 'log-time';
      time.textContent = formatTime(entry.timestamp);
      
      const level = document.createElement('span');
      level.className = 'log-level ' + entry.level;
      level.textContent = entry.level;
      
      const source = document.createElement('span');
      source.className = 'log-source ' + entry.source;
      source.textContent = entry.source;
      
      const message = document.createElement('span');
      message.className = 'log-message';
      message.textContent = entry.message;
      
      div.appendChild(time);
      div.appendChild(level);
      div.appendChild(source);
      div.appendChild(message);
      
      if (entry.data && Object.keys(entry.data).length > 0) {
        const data = document.createElement('div');
        data.className = 'log-data';
        data.textContent = JSON.stringify(entry.data);
        div.appendChild(data);
      }
      
      return div;
    }

    function addLogEntry(entry) {
      logs.push(entry);
      statLogs.textContent = logs.length;
      
      if (shouldShowLog(entry)) {
        emptyState.style.display = 'none';
        const logEl = createLogElement(entry);
        logContainer.appendChild(logEl);
        
        if (autoScroll) {
          logContainer.scrollTop = logContainer.scrollHeight;
        } else {
          autoScrollIndicator.style.display = 'block';
        }
      }
    }

    function shouldShowLog(entry) {
      const sourceFilter = filterSource.value;
      const levelFilter = filterLevel.value;
      const textFilter = filterText.value.toLowerCase();
      
      if (sourceFilter && entry.source !== sourceFilter) return false;
      if (LOG_LEVELS[entry.level] < LOG_LEVELS[levelFilter]) return false;
      if (textFilter && !entry.message.toLowerCase().includes(textFilter)) return false;
      
      return true;
    }

    function refreshLogs() {
      // Clear container except empty state
      logContainer.innerHTML = '';
      logContainer.appendChild(emptyState);
      
      let visibleCount = 0;
      logs.forEach(entry => {
        if (shouldShowLog(entry)) {
          if (visibleCount === 0) emptyState.style.display = 'none';
          logContainer.appendChild(createLogElement(entry));
          visibleCount++;
        }
      });
      
      if (visibleCount === 0) {
        emptyState.style.display = 'block';
      }
      
      if (autoScroll) {
        logContainer.scrollTop = logContainer.scrollHeight;
      }
    }

    function updateSerialStatus(serialInfo) {
      if (serialInfo.connected) {
        serialStatus.className = 'status-badge connected';
        serialStatusText.textContent = 'Serial: ' + (serialInfo.port || 'Conectado');
        statPort.textContent = serialInfo.port || '-';
      } else {
        serialStatus.className = 'status-badge disconnected';
        serialStatusText.textContent = 'Serial: Desconectado';
        statPort.textContent = serialInfo.last_error ? 'Erro' : '-';
      }
    }

    function updateStats(statsInfo) {
      statSent.textContent = statsInfo.sent || 0;
      statFailed.textContent = statsInfo.failed || 0;
      statLastCmd.textContent = statsInfo.last_command || '-';
    }

    function connectWebSocket() {
      if (ws && ws.readyState === WebSocket.OPEN) return;
      
      ws = new WebSocket(WS_URL);
      
      ws.onopen = () => {
        wsStatus.className = 'status-badge connected';
        wsStatusText.textContent = 'WebSocket: Conectado';
        addLogEntry({
          timestamp: new Date().toISOString(),
          level: 'INFO',
          source: 'SYSTEM',
          message: '🔌 Conectado ao servidor WebSocket',
          data: { url: WS_URL }
        });
        if (reconnectTimer) {
          clearTimeout(reconnectTimer);
          reconnectTimer = null;
        }
      };
      
      ws.onclose = () => {
        wsStatus.className = 'status-badge disconnected';
        wsStatusText.textContent = 'WebSocket: Desconectado';
        addLogEntry({
          timestamp: new Date().toISOString(),
          level: 'WARNING',
          source: 'SYSTEM',
          message: '🔌 Desconectado do servidor WebSocket, tentando reconectar...',
          data: {}
        });
        reconnectTimer = setTimeout(connectWebSocket, 3000);
      };
      
      ws.onerror = (e) => {
        addLogEntry({
          timestamp: new Date().toISOString(),
          level: 'ERROR',
          source: 'SYSTEM',
          message: '❌ Erro de conexão WebSocket',
          data: { error: e.message || 'Unknown error' }
        });
      };
      
      ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          
          if (data.type === 'log') {
            addLogEntry(data.entry);
          } else if (data.type === 'history') {
            data.entries.forEach(entry => addLogEntry(entry));
          } else if (data.type === 'status') {
            updateSerialStatus(data.serial);
            updateStats(data.stats);
          } else if (data.type === 'command_result') {
            // Command result handled via logs
          }
        } catch (err) {
          console.error('Failed to parse message:', err);
        }
      };
    }

    function sendCommand(cmd) {
      if (!cmd) return;
      
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'command', cmd: cmd }));
      } else {
        addLogEntry({
          timestamp: new Date().toISOString(),
          level: 'ERROR',
          source: 'SYSTEM',
          message: '❌ Não foi possível enviar comando - WebSocket desconectado',
          data: { command: cmd }
        });
      }
    }

    function enableAutoScroll() {
      autoScroll = true;
      autoScrollIndicator.style.display = 'none';
      logContainer.scrollTop = logContainer.scrollHeight;
    }

    // Event listeners
    filterSource.addEventListener('change', refreshLogs);
    filterLevel.addEventListener('change', refreshLogs);
    filterText.addEventListener('input', refreshLogs);
    
    document.getElementById('clear-logs').addEventListener('click', () => {
      logs = [];
      logContainer.innerHTML = '';
      logContainer.appendChild(emptyState);
      emptyState.style.display = 'block';
      statLogs.textContent = '0';
    });
    
    document.getElementById('reconnect-ws').addEventListener('click', () => {
      if (ws) {
        ws.close();
      }
      setTimeout(connectWebSocket, 500);
    });
    
    document.getElementById('reconnect-serial').addEventListener('click', () => {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'reconnect_serial' }));
      }
    });
    
    document.getElementById('send-command').addEventListener('click', () => {
      const cmd = commandInput.value.trim();
      if (cmd) {
        sendCommand(cmd);
        commandInput.value = '';
      }
    });
    
    commandInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        const cmd = commandInput.value.trim();
        if (cmd) {
          sendCommand(cmd);
          commandInput.value = '';
        }
      }
    });
    
    document.querySelectorAll('.quick-cmd').forEach(btn => {
      btn.addEventListener('click', () => {
        sendCommand(btn.dataset.cmd);
      });
    });
    
    logContainer.addEventListener('scroll', () => {
      const atBottom = logContainer.scrollHeight - logContainer.scrollTop - logContainer.clientHeight < 50;
      if (atBottom) {
        autoScroll = true;
        autoScrollIndicator.style.display = 'none';
      } else {
        autoScroll = false;
      }
    });

    // Initialize
    connectWebSocket();
    
    // Add initial log
    addLogEntry({
      timestamp: new Date().toISOString(),
      level: 'INFO',
      source: 'SYSTEM',
      message: '🚀 Página de logs iniciada',
      data: { ws_url: WS_URL }
    });
  </script>
</body>
</html>
LOGSEOF
  chown www-data:www-data /var/www/html/logs.html
  chmod 644 /var/www/html/logs.html
}

# Executar criação das páginas
create_index_page
create_config_page
create_live_page
create_position_page
create_logs_page

echo "[INFO] Páginas web criadas com sucesso."
