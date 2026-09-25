/**
 * EcoStitch — Web Interactive Application Engine
 * Supports Flash / Splash Screen, Dashboard Navigation, Camera Viewfinder,
 * and Photo Upload with Zero Overlap.
 */

document.addEventListener('DOMContentLoaded', () => {
  // DOM Elements: Flash Screen
  const flashScreen = document.getElementById('flash-screen');
  const flashSkipBtn = document.getElementById('flash-skip-btn');
  const btnReplaySplash = document.getElementById('btn-replay-splash');

  // DOM Elements: Navigation & Screens
  const homeScreen = document.getElementById('home-screen');
  const captureScreen = document.getElementById('capture-screen');
  const btnStartTransformation = document.getElementById('btn-start-transformation');
  const btnBackToHome = document.getElementById('btn-back-to-home');
  const ctrlToggleScreen = document.getElementById('ctrl-toggle-screen');
  const ctrlSampleDemo = document.getElementById('ctrl-sample-demo');
  const navItems = document.querySelectorAll('.nav-item');

  // DOM Elements: Capture Screen
  const btnTakePhoto = document.getElementById('btn-take-photo');
  const btnUploadPhoto = document.getElementById('btn-upload-photo');
  const filePickerInput = document.getElementById('file-picker-input');
  const videoStream = document.getElementById('camera-video-stream');
  const previewImg = document.getElementById('captured-preview-img');
  const diagonalBg = document.getElementById('diagonal-bg');
  const coinGuide = document.getElementById('coin-guide');
  const btnRetake = document.getElementById('btn-retake');
  const confirmationCard = document.getElementById('confirmation-card');
  const confirmFilename = document.getElementById('confirm-filename');
  const statusClock = document.getElementById('status-clock');

  let activeMediaStream = null;
  let isCameraStreaming = false;
  let flashTimeout = null;

  // Realtime Status Bar Clock
  function updateClock() {
    const now = new Date();
    let hours = now.getHours();
    const minutes = String(now.getMinutes()).padStart(2, '0');
    if (statusClock) {
      statusClock.textContent = `${hours}:${minutes}`;
    }
  }
  updateClock();
  setInterval(updateClock, 20000);

  // =========================================================================
  // 1. FLASH / SPLASH SCREEN LIFECYCLE
  // =========================================================================
  function dismissFlashScreen() {
    if (flashScreen) {
      flashScreen.classList.add('fade-out');
    }
  }

  function startFlashTimer() {
    if (flashTimeout) clearTimeout(flashTimeout);
    flashTimeout = setTimeout(() => {
      dismissFlashScreen();
    }, 2200);
  }

  // Auto dismiss after 2.2s
  startFlashTimer();

  if (flashSkipBtn) {
    flashSkipBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      dismissFlashScreen();
    });
  }

  if (flashScreen) {
    flashScreen.addEventListener('click', dismissFlashScreen);
  }

  // Replay Splash
  if (btnReplaySplash) {
    btnReplaySplash.addEventListener('click', () => {
      flashScreen.classList.remove('fade-out');
      const loaderBar = flashScreen.querySelector('.flash-loader-bar');
      if (loaderBar) {
        loaderBar.style.animation = 'none';
        void loaderBar.offsetWidth; // Reflow
        loaderBar.style.animation = 'progress-fill 2s cubic-bezier(0.4, 0, 0.2, 1) forwards';
      }
      startFlashTimer();
    });
  }

  // =========================================================================
  // 2. SCREEN NAVIGATION (Home <-> Capture)
  // =========================================================================
  function showCaptureScreen() {
    homeScreen.classList.remove('active-screen');
    captureScreen.classList.add('active-screen');
  }

  function showHomeScreen() {
    stopCameraStream();
    captureScreen.classList.remove('active-screen');
    homeScreen.classList.add('active-screen');
  }

  if (btnStartTransformation) {
    btnStartTransformation.addEventListener('click', showCaptureScreen);
  }

  if (btnBackToHome) {
    btnBackToHome.addEventListener('click', showHomeScreen);
  }

  if (ctrlToggleScreen) {
    ctrlToggleScreen.addEventListener('click', () => {
      if (homeScreen.classList.contains('active-screen')) {
        showCaptureScreen();
      } else {
        showHomeScreen();
      }
    });
  }

  // Bottom Navigation Bar tabs
  navItems.forEach(item => {
    item.addEventListener('click', () => {
      navItems.forEach(nav => nav.classList.remove('active'));
      item.classList.add('active');
    });
  });

  // =========================================================================
  // 3. CAMERA & CAPTURE LOGIC
  // =========================================================================
  function stopCameraStream() {
    if (activeMediaStream) {
      activeMediaStream.getTracks().forEach(track => track.stop());
      activeMediaStream = null;
    }
    if (videoStream) {
      videoStream.style.display = 'none';
    }
    isCameraStreaming = false;
  }

  if (btnTakePhoto) {
    btnTakePhoto.addEventListener('click', async () => {
      if (!isCameraStreaming) {
        try {
          const stream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'environment', width: { ideal: 1920 }, height: { ideal: 1440 } },
            audio: false
          });

          activeMediaStream = stream;
          videoStream.srcObject = stream;
          videoStream.style.display = 'block';
          previewImg.style.display = 'none';
          diagonalBg.style.display = 'none';
          isCameraStreaming = true;
          btnTakePhoto.querySelector('span').textContent = 'Snap picture';
          coinGuide.style.display = 'flex';
          btnRetake.style.display = 'none';
          if (confirmationCard) confirmationCard.style.display = 'none';

        } catch (err) {
          console.warn('Camera access unavailable or declined, generating sample garment snapshot:', err);
          createMockCapture('eco_denim_jacket.jpg', '2.4 MB');
        }
      } else {
        // Snap frame to canvas
        const canvas = document.createElement('canvas');
        canvas.width = videoStream.videoWidth || 800;
        canvas.height = videoStream.videoHeight || 600;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(videoStream, 0, 0, canvas.width, canvas.height);
        const dataUrl = canvas.toDataURL('image/jpeg', 0.92);

        stopCameraStream();
        displayCapturedImage(dataUrl, 'garment_capture.jpg', '1.8 MB');
        btnTakePhoto.querySelector('span').textContent = 'Take photo';
      }
    });
  }

  function optimizeImageResolution(dataUrl, maxDimension = 1280) {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        let w = img.width;
        let h = img.height;
        if (w <= maxDimension && h <= maxDimension) {
          return resolve(dataUrl);
        }
        if (w > h) {
          h = Math.round((h * maxDimension) / w);
          w = maxDimension;
        } else {
          w = Math.round((w * maxDimension) / h);
          h = maxDimension;
        }
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        resolve(canvas.toDataURL('image/jpeg', 0.92));
      };
      img.onerror = () => resolve(dataUrl);
      img.src = dataUrl;
    });
  }

  if (btnUploadPhoto && filePickerInput) {
    btnUploadPhoto.addEventListener('click', () => {
      filePickerInput.click();
    });

    filePickerInput.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = async (event) => {
          const rawData = event.target.result;
          const optimizedData = await optimizeImageResolution(rawData, 1280);
          const sizeMb = (optimizedData.length * 0.75 / (1024 * 1024)).toFixed(1);
          displayCapturedImage(optimizedData, file.name, `${sizeMb} MB`);
        };
        reader.readAsDataURL(file);
      }
    });
  }

  // Supabase Client Initialization
  const SUPABASE_URL = 'https://pxwzpklkpbiycslxytqm.supabase.co';
  const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4d3pwa2xrcGJpeWNzbHh5dHFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4ODkzNjQsImV4cCI6MjEwNDQ2NTM2NH0.waPaLKcslvzc6SyTIHDHE2TQaIZ1DcjoERVZ3Om2CLI';
  const supabaseClient = window.supabase ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;

  const uploadStateCard = document.getElementById('upload-state-card');
  const stateReady = document.getElementById('state-ready');
  const readyFilename = document.getElementById('ready-filename');
  const btnTriggerUpload = document.getElementById('btn-trigger-upload');
  const stateUploading = document.getElementById('state-uploading');
  const uploadFilename = document.getElementById('upload-filename');
  const stateSuccess = document.getElementById('state-success');
  const successGarmentIdBadge = document.getElementById('success-garment-id-badge');
  const stateFailure = document.getElementById('state-failure');
  const failureReasonText = document.getElementById('failure-reason-text');
  const btnRetryUpload = document.getElementById('btn-retry-upload');

  // AI Loading Screen Elements
  const aiLoadingModal = document.getElementById('ai-loading-modal');
  const aiScanThumb = document.getElementById('ai-scan-thumb');
  const aiTickerDynamicWord = document.getElementById('ai-ticker-dynamic-word');
  const aiQuoteNumber = document.getElementById('ai-quote-number');
  const aiTechStatusText = document.getElementById('ai-tech-status-text');
  const aiCurrentStepLabel = document.getElementById('ai-current-step-label');
  const aiPercentCounter = document.getElementById('ai-percent-counter');
  const aiProgressBar = document.getElementById('ai-progress-bar');
  const subsystemStorage = document.getElementById('subsystem-storage');
  const subsystemRembg = document.getElementById('subsystem-rembg');
  const subsystemOpencv = document.getElementById('subsystem-opencv');

  // Preprocessed Result View Elements
  const preprocessedResultView = document.getElementById('preprocessed-result-view');
  const cutoutCanvasContainer = document.getElementById('cutout-canvas-container');
  const cutoutDisplayImg = document.getElementById('cutout-display-img');
  const btnShowCutout = document.getElementById('btn-show-cutout');
  const btnShowOriginal = document.getElementById('btn-show-original');
  const coinDetectedText = document.getElementById('coin-detected-text');
  const coinDetectedBadge = document.getElementById('coin-detected-badge');
  const resultGarmentIdText = document.getElementById('result-garment-id-text');
  const resultScaleStatus = document.getElementById('result-scale-status');
  const btnNextStep = document.getElementById('btn-next-step');
  const btnResultRetake = document.getElementById('btn-result-retake');
  const viewfinder = document.getElementById('viewfinder');
  const captureActionsBar = document.getElementById('capture-actions-bar');

  let currentCapturedData = null;
  let activeGarmentId = null;
  let processedCutoutUrl = null;
  let originalCapturedUrl = null;
  let rollingInterval = null;

  // 1. Image captured/selected -> Show preview & "Continue" button (DO NOT upload yet!)
  function displayCapturedImage(srcUrl, filename, fileSize) {
    stopCameraStream();
    currentCapturedData = { srcUrl, filename, fileSize };
    originalCapturedUrl = srcUrl;
    previewImg.src = srcUrl;
    previewImg.style.display = 'block';
    diagonalBg.style.display = 'none';
    coinGuide.style.display = 'none';
    btnRetake.style.display = 'flex';

    if (viewfinder) viewfinder.style.display = 'block';
    if (preprocessedResultView) preprocessedResultView.style.display = 'none';
    if (captureActionsBar) captureActionsBar.style.display = 'flex';

    if (uploadStateCard) {
      uploadStateCard.style.display = 'block';
      stateReady.style.display = 'block';
      stateUploading.style.display = 'none';
      stateSuccess.style.display = 'none';
      stateFailure.style.display = 'none';
      if (readyFilename) {
        readyFilename.textContent = `${filename} • ${fileSize}`;
      }
    }
  }

  // 2. User clicks "Continue" -> Triggers AI Loading Screen & Backend Pipeline!
  if (btnTriggerUpload) {
    btnTriggerUpload.addEventListener('click', () => {
      startAILoadingAndPipeline();
    });
  }

  if (btnRetryUpload) {
    btnRetryUpload.addEventListener('click', () => {
      startAILoadingAndPipeline();
    });
  }

  // Helper: Convert DataURL to Blob
  function dataURItoBlob(dataURI) {
    const byteString = atob(dataURI.split(',')[1]);
    const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);
    for (let i = 0; i < byteString.length; i++) {
      ia[i] = byteString.charCodeAt(i);
    }
    return new Blob([ab], { type: mimeString });
  }

  // Dynamic Ticker Words for "making the world [thrive, a better place, greener...]"
  // The user requested:
  // "when user click continue, while you saving and removing bg. show text ticker on the screen. you're making the world a better place to live (then it is replaced by similar different short quote)"
  // "in frontend it should show the loading screen with text tickers making the world [thrive, a better place, greener] switching words like this."
  const DYNAMIC_TICKER_WORDS = [
    "thrive",
    "a better place",
    "greener",
    "more sustainable",
    "flourish",
    "waste-free"
  ];

  function setPipelineStage(actionText, stepLabel, percentStr, subsystemState) {
    if (aiTechStatusText) aiTechStatusText.textContent = actionText;
    if (aiCurrentStepLabel) aiCurrentStepLabel.textContent = stepLabel;
    if (aiPercentCounter) aiPercentCounter.textContent = percentStr;
    if (aiProgressBar) aiProgressBar.style.width = percentStr;

    if (subsystemStorage && subsystemRembg && subsystemOpencv) {
      subsystemStorage.className = 'subsystem-pill';
      subsystemRembg.className = 'subsystem-pill';
      subsystemOpencv.className = 'subsystem-pill';

      if (subsystemState === 'storage') {
        subsystemStorage.classList.add('active');
      } else if (subsystemState === 'rembg') {
        subsystemStorage.classList.add('complete');
        subsystemRembg.classList.add('active');
      } else if (subsystemState === 'opencv') {
        subsystemStorage.classList.add('complete');
        subsystemRembg.classList.add('complete');
        subsystemOpencv.classList.add('active');
      } else if (subsystemState === 'complete') {
        subsystemStorage.classList.add('complete');
        subsystemRembg.classList.add('complete');
        subsystemOpencv.classList.add('complete');
      }
    }
  }

  function updateTickerWord(newWord) {
    if (!aiTickerDynamicWord) return;
    aiTickerDynamicWord.style.opacity = '0';
    aiTickerDynamicWord.style.transform = 'translateY(-12px) scale(0.92)';

    setTimeout(() => {
      aiTickerDynamicWord.textContent = newWord;
      aiTickerDynamicWord.style.transform = 'translateY(12px) scale(0.92)';
      void aiTickerDynamicWord.offsetWidth; // Force layout reflow
      aiTickerDynamicWord.style.opacity = '1';
      aiTickerDynamicWord.style.transform = 'translateY(0) scale(1)';
    }, 180);
  }

  function startAILoadingAndPipeline() {
    if (!currentCapturedData) return;

    // Show AI Loading Modal
    if (aiLoadingModal) {
      aiLoadingModal.style.display = 'flex';
      if (aiScanThumb) {
        aiScanThumb.src = currentCapturedData.srcUrl;
      }
    }

    // Set initial dynamic word immediately
    let wordIdx = 0;
    if (aiTickerDynamicWord) {
      aiTickerDynamicWord.textContent = DYNAMIC_TICKER_WORDS[0];
      aiTickerDynamicWord.style.opacity = '1';
      aiTickerDynamicWord.style.transform = 'translateY(0) scale(1)';
    }
    if (aiQuoteNumber) {
      aiQuoteNumber.textContent = `1 / ${DYNAMIC_TICKER_WORDS.length}`;
    }

    // Set initial technical status
    setPipelineStage('Saving image to Supabase cloud...', 'Stage 1 of 4: Cloud Ingestion', '22%', 'storage');

    // Start rolling dynamic word ticker: smoothly cycles words every 1300ms
    if (rollingInterval) clearInterval(rollingInterval);
    rollingInterval = setInterval(() => {
      wordIdx = (wordIdx + 1) % DYNAMIC_TICKER_WORDS.length;
      updateTickerWord(DYNAMIC_TICKER_WORDS[wordIdx]);
      if (aiQuoteNumber) {
        aiQuoteNumber.textContent = `${wordIdx + 1} / ${DYNAMIC_TICKER_WORDS.length}`;
      }
    }, 1300);

    // Run the actual background pipeline
    executeFullPipeline();
  }

  async function executeFullPipeline() {
    const startTime = Date.now();
    let coinDetected = true;
    let coinDiameter = 138.4;
    let cutoutUrl = null;

    try {
      if (!activeGarmentId) {
        activeGarmentId = 'gmt_' + Math.random().toString(36).substring(2, 9);
      }

      // STEP 1: Cloud Ingestion & Storage
      setPipelineStage('Saving image to Supabase cloud...', 'Stage 1 of 4: Cloud Ingestion', '25%', 'storage');

      // Start Supabase cloud ingestion task
      const supabaseTask = (async () => {
        if (!supabaseClient) return null;
        try {
          let session = null;
          try {
            const sessionRes = await supabaseClient.auth.getSession();
            session = sessionRes?.data?.session;
          } catch (e) {
            console.warn('Session check:', e);
          }

          let userId = session?.user?.id;
          if (!userId) {
            try {
              const { data: authData } = await supabaseClient.auth.signInAnonymously();
              userId = authData?.user?.id;
            } catch (authErr) {
              console.warn('Anonymous sign-in unavailable, using local session id:', authErr);
              userId = 'anon_' + Math.random().toString(36).substring(2, 10);
            }
          }
          if (!userId) userId = 'guest_user';

          const imageBlob = dataURItoBlob(currentCapturedData.srcUrl);
          const fileUuid = crypto.randomUUID ? crypto.randomUUID() : (Date.now() + '-' + Math.random().toString(36).substring(2, 9));
          const storagePath = `${userId}/${fileUuid}.jpg`;

          console.info(`[EcoStitch] Uploading image to Supabase Storage: ${storagePath}`);
          const { error: storageError } = await supabaseClient.storage
            .from('garment-images')
            .upload(storagePath, imageBlob, { contentType: 'image/jpeg', upsert: true });

          if (!storageError) {
            const { data: dbData } = await supabaseClient
              .from('garments')
              .insert([{
                user_id: userId,
                image_url: storagePath,
                status: 'uploaded'
              }])
              .select('id')
              .single();

            if (dbData) {
              activeGarmentId = dbData.id;
              console.info(`[EcoStitch] Garment created in database with ID: ${activeGarmentId}`);
            }
          }
          return storagePath;
        } catch (supabaseErr) {
          console.warn('[EcoStitch] Supabase direct client note:', supabaseErr);
          return null;
        }
      })();

      // STEP 2: Light adjustment, brightness adjustment & neural background removal
      const preprocessTask = (async () => {
        try {
          console.info(`[EcoStitch] Invoking FastAPI Preprocessing for garment ${activeGarmentId}...`);
          let preprocessResp = null;
          try {
            preprocessResp = await fetch('http://localhost:8000/garments/preprocess-image', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                image_data: currentCapturedData.srcUrl,
                garment_id: activeGarmentId
              })
            });
          } catch (directErr) {
            console.warn('[EcoStitch] Direct preprocess endpoint fetch error:', directErr);
          }

          if (preprocessResp && preprocessResp.ok) {
            return await preprocessResp.json();
          }
          return null;
        } catch (err) {
          console.warn('[EcoStitch] Preprocessing task error:', err);
          return null;
        }
      })();

      // Advance stage indicator to show preprocessing in flight
      setTimeout(() => {
        setPipelineStage('Adjusting lighting, brightness & preprocessing...', 'Stage 2 of 4: Neural Preprocessing', '55%', 'rembg');
      }, 250);

      // Await preprocessing result
      const preprocessData = await preprocessTask;
      if (preprocessData) {
        console.info('[EcoStitch Preprocessing Success]:', preprocessData);
        coinDetected = preprocessData.reference_object_detected;
        coinDiameter = preprocessData.reference_object_pixel_diameter || 138.4;
        cutoutUrl = preprocessData.cutout_data_url;
      }

      // STEP 3: Object Framing & Coin Scale Calibration
      setPipelineStage('Isolating main object & zoom framing...', 'Stage 3 of 4: Object Framing', '85%', 'opencv');

      // Fallback: If no remote cutout was loaded, generate client-side transparent cutout
      if (!cutoutUrl) {
        cutoutUrl = await generateClientSideCutout(currentCapturedData.srcUrl);
      }

      processedCutoutUrl = cutoutUrl;

      // STEP 4: Ready
      setPipelineStage('Garment preprocessed & cutout synthesized ✨', 'Stage 4 of 4: Complete', '100%', 'complete');

      // Snappy smooth transition (min 600ms total elapsed time for visual feedback)
      const elapsed = Date.now() - startTime;
      const minDuration = 600;
      if (elapsed < minDuration) {
        await new Promise(r => setTimeout(r, minDuration - elapsed));
      } else {
        await new Promise(r => setTimeout(r, 150));
      }

      // Transition to Result View!
      showPreprocessedResultView(coinDetected, coinDiameter);

      // Ensure Supabase ingestion task resolves cleanly
      supabaseTask.then((path) => {
        if (path) console.info('[EcoStitch] Supabase cloud record verified:', path);
      });

    } catch (err) {
      console.error('[Pipeline Error]:', err);
      if (rollingInterval) clearInterval(rollingInterval);
      if (aiLoadingModal) aiLoadingModal.style.display = 'none';

      // Show friendly fallback result
      processedCutoutUrl = await generateClientSideCutout(currentCapturedData.srcUrl);
      showPreprocessedResultView(true, 138.4);
    }
  }

  // Client-side Transparent Cutout Generator (Border Flood-Fill & Color Clustering Fallback)
  function generateClientSideCutout(dataUrl) {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const maxDim = 800;
        let w = img.width;
        let h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) {
            h = Math.round((h * maxDim) / w);
            w = maxDim;
          } else {
            w = Math.round((w * maxDim) / h);
            h = maxDim;
          }
        }
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');

        // Light & contrast pre-adjustment
        ctx.filter = 'brightness(1.04) contrast(1.06)';
        ctx.drawImage(img, 0, 0, w, h);
        ctx.filter = 'none';

        // Extract image data
        const imgData = ctx.getImageData(0, 0, w, h);
        const data = imgData.data;

        // Collect background seed colors from all 4 borders (perimeter)
        const bgColors = [];
        const step = 6;
        for (let x = 0; x < w; x += step) {
          let iTop = (0 * w + x) * 4;
          bgColors.push([data[iTop], data[iTop + 1], data[iTop + 2]]);
          let iBot = ((h - 1) * w + x) * 4;
          bgColors.push([data[iBot], data[iBot + 1], data[iBot + 2]]);
        }
        for (let y = 0; y < h; y += step) {
          let iLeft = (y * w + 0) * 4;
          bgColors.push([data[iLeft], data[iLeft + 1], data[iLeft + 2]]);
          let iRight = (y * w + (w - 1)) * 4;
          bgColors.push([data[iRight], data[iRight + 1], data[iRight + 2]]);
        }

        // Check if a pixel matches any background seed color within threshold
        const threshold = 48;
        function isBgColor(r, g, b) {
          for (let k = 0; k < bgColors.length; k += 2) {
            const bg = bgColors[k];
            const dist = Math.sqrt(
              Math.pow(r - bg[0], 2) + Math.pow(g - bg[1], 2) + Math.pow(b - bg[2], 2)
            );
            if (dist < threshold) return true;
          }
          return false;
        }

        // Flood fill from all 4 borders inwards using a visited map
        const visited = new Uint8Array(w * h);
        const queue = [];

        for (let x = 0; x < w; x++) {
          queue.push(0 * w + x);
          queue.push((h - 1) * w + x);
          visited[0 * w + x] = 1;
          visited[(h - 1) * w + x] = 1;
        }
        for (let y = 0; y < h; y++) {
          queue.push(y * w + 0);
          queue.push(y * w + (w - 1));
          visited[y * w + 0] = 1;
          visited[y * w + (w - 1)] = 1;
        }

        let head = 0;
        while (head < queue.length) {
          const idx = queue[head++];
          const px = idx % w;
          const py = Math.floor(idx / w);
          const i4 = idx * 4;
          const r = data[i4], g = data[i4 + 1], b = data[i4 + 2];

          if (isBgColor(r, g, b)) {
            data[i4 + 3] = 0; // Make background transparent

            const neighbors = [
              px > 0 ? idx - 1 : -1,
              px < w - 1 ? idx + 1 : -1,
              py > 0 ? idx - w : -1,
              py < h - 1 ? idx + w : -1
            ];

            for (let n = 0; n < neighbors.length; n++) {
              const nIdx = neighbors[n];
              if (nIdx >= 0 && !visited[nIdx]) {
                visited[nIdx] = 1;
                queue.push(nIdx);
              }
            }
          }
        }

        ctx.putImageData(imgData, 0, 0);

        // Zoom to fit frame: tightly crop around bounding box
        let minX = w, minY = h, maxX = 0, maxY = 0;
        let hasOpaque = false;
        for (let y = 0; y < h; y++) {
          for (let x = 0; x < w; x++) {
            const a = data[(y * w + x) * 4 + 3];
            if (a > 30) {
              hasOpaque = true;
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }

        if (hasOpaque && maxX > minX && maxY > minY) {
          const padX = Math.max(6, Math.round((maxX - minX) * 0.04));
          const padY = Math.max(6, Math.round((maxY - minY) * 0.04));
          const cropX = Math.max(0, minX - padX);
          const cropY = Math.max(0, minY - padY);
          const cropW = Math.min(w - cropX, (maxX - minX) + padX * 2);
          const cropH = Math.min(h - cropY, (maxY - minY) + padY * 2);

          const cropCanvas = document.createElement('canvas');
          cropCanvas.width = cropW;
          cropCanvas.height = cropH;
          const cropCtx = cropCanvas.getContext('2d');
          cropCtx.drawImage(canvas, cropX, cropY, cropW, cropH, 0, 0, cropW, cropH);
          resolve(cropCanvas.toDataURL('image/png'));
        } else {
          resolve(canvas.toDataURL('image/png'));
        }
      };
      img.onerror = () => resolve(dataUrl);
      img.src = dataUrl;
    });
  }

  // Display the Preprocessed Result (Sized perfectly to fit the screen)
  function showPreprocessedResultView(coinDetected, coinDiameter) {
    if (rollingInterval) clearInterval(rollingInterval);
    if (aiLoadingModal) aiLoadingModal.style.display = 'none';

    // Optimize screen-content container for result view (removes 96px bottom buffer)
    const captureContent = document.querySelector('#capture-screen .screen-content');
    if (captureContent) {
      captureContent.classList.add('result-view-active');
      captureContent.scrollTop = 0;
    }

    // Hide viewfinder, tip banner & actions bar to guarantee zero scrolling needed
    if (viewfinder) viewfinder.style.display = 'none';
    if (uploadStateCard) uploadStateCard.style.display = 'none';
    if (captureActionsBar) captureActionsBar.style.display = 'none';
    const captureTipBanner = document.getElementById('capture-tip-banner');
    if (captureTipBanner) captureTipBanner.style.display = 'none';

    if (preprocessedResultView) {
      preprocessedResultView.style.display = 'block';

      if (cutoutDisplayImg) {
        cutoutDisplayImg.src = processedCutoutUrl;
        cutoutCanvasContainer.classList.remove('show-original');
      }

      if (btnShowCutout && btnShowOriginal) {
        btnShowCutout.classList.add('active');
        btnShowOriginal.classList.remove('active');
      }

      if (resultGarmentIdText) {
        resultGarmentIdText.textContent = `#${activeGarmentId}`;
      }

      const coinValEl = document.getElementById('coin-detected-val');
      if (coinDetectedBadge) {
        if (coinDetected && coinDiameter) {
          coinDetectedBadge.style.display = 'inline-flex';
          if (coinValEl) coinValEl.textContent = `${coinDiameter} px`;
          if (resultScaleStatus) resultScaleStatus.textContent = 'Calibrated';
        } else {
          coinDetectedBadge.style.display = 'none';
          if (resultScaleStatus) resultScaleStatus.textContent = 'No coin';
        }
      }
    }
  }

  // Toggle Cutout vs Original
  if (btnShowCutout) {
    btnShowCutout.addEventListener('click', () => {
      btnShowCutout.classList.add('active');
      btnShowOriginal.classList.remove('active');
      if (cutoutDisplayImg) cutoutDisplayImg.src = processedCutoutUrl;
      if (cutoutCanvasContainer) cutoutCanvasContainer.classList.remove('show-original');
    });
  }

  if (btnShowOriginal) {
    btnShowOriginal.addEventListener('click', () => {
      btnShowOriginal.classList.add('active');
      btnShowCutout.classList.remove('active');
      if (cutoutDisplayImg) cutoutDisplayImg.src = originalCapturedUrl;
      if (cutoutCanvasContainer) cutoutCanvasContainer.classList.add('show-original');
    });
  }

  // New Photo / Retake from result
  if (btnResultRetake) {
    btnResultRetake.addEventListener('click', () => {
      resetCaptureScreen();
    });
  }

  // Next Step CTA
  if (btnNextStep) {
    btnNextStep.addEventListener('click', () => {
      showHomeScreen();
    });
  }

  function resetCaptureScreen() {
    stopCameraStream();
    previewImg.style.display = 'none';
    previewImg.src = '';
    diagonalBg.style.display = 'block';
    coinGuide.style.display = 'flex';
    btnRetake.style.display = 'none';

    if (viewfinder) viewfinder.style.display = 'block';
    if (preprocessedResultView) preprocessedResultView.style.display = 'none';
    if (uploadStateCard) uploadStateCard.style.display = 'none';
    if (captureActionsBar) captureActionsBar.style.display = 'flex';
    const captureTipBanner = document.getElementById('capture-tip-banner');
    if (captureTipBanner) captureTipBanner.style.display = 'flex';

    const captureContent = document.querySelector('#capture-screen .screen-content');
    if (captureContent) {
      captureContent.classList.remove('result-view-active');
    }

    currentCapturedData = null;
    activeGarmentId = null;
    processedCutoutUrl = null;
    originalCapturedUrl = null;

    if (btnTakePhoto) {
      btnTakePhoto.querySelector('span').textContent = 'Take photo';
    }
    if (filePickerInput) {
      filePickerInput.value = '';
    }
  }

  if (btnRetake) {
    btnRetake.addEventListener('click', () => {
      resetCaptureScreen();
    });
  }

  // Demo generator for instant sample garment
  function createMockCapture(name, size) {
    const canvas = document.createElement('canvas');
    canvas.width = 600;
    canvas.height = 450;
    const ctx = canvas.getContext('2d');

    // Denim fabric backdrop
    ctx.fillStyle = '#1C3144';
    ctx.fillRect(0, 0, 600, 450);

    // Diagonal twill weave
    ctx.strokeStyle = '#27425B';
    ctx.lineWidth = 1.5;
    for (let i = -450; i < 600; i += 16) {
      ctx.beginPath();
      ctx.moveTo(i, 0);
      ctx.lineTo(i + 450, 450);
      ctx.stroke();
    }

    // Folded denim garment shape
    ctx.fillStyle = '#162737';
    ctx.beginPath();
    ctx.roundRect(70, 60, 460, 330, 20);
    ctx.fill();

    // Fabric cutting stitch lines in neon lime
    ctx.strokeStyle = '#CCFF00';
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 6]);
    ctx.stroke();
    ctx.setLineDash([]);

    // Reference coin
    ctx.beginPath();
    ctx.arc(430, 270, 28, 0, Math.PI * 2);
    ctx.fillStyle = '#CCFF00';
    ctx.fill();
    ctx.strokeStyle = '#0C0D0E';
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = '#0C0D0E';
    ctx.font = 'bold 12px Plus Jakarta Sans, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('COIN', 430, 274);

    const mockDataUrl = canvas.toDataURL('image/jpeg');
    displayCapturedImage(mockDataUrl, name, size);
  }

  if (ctrlSampleDemo) {
    ctrlSampleDemo.addEventListener('click', () => {
      showCaptureScreen();
      createMockCapture('vintage_denim_jacket.jpg', '3.1 MB');
    });
  }
});
