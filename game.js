(() => {
  "use strict";

  const canvas = document.querySelector("#game-canvas");
  const ctx = canvas.getContext("2d", { alpha: false });
  const $ = (selector) => document.querySelector(selector);

  const ui = {
    startScreen: $("#start-screen"),
    pauseScreen: $("#pause-screen"),
    finishScreen: $("#finish-screen"),
    startButton: $("#start-button"),
    pauseButton: $("#pause-button"),
    resumeButton: $("#resume-button"),
    restartPauseButton: $("#restart-pause-button"),
    raceAgainButton: $("#race-again-button"),
    soundButton: $("#sound-button"),
    raceHud: $("#race-hud"),
    itemSlot: $("#item-slot"),
    touchControls: $("#touch-controls"),
    speedValue: $("#speed-value"),
    boostFill: $("#boost-fill"),
    positionValue: $("#position-value"),
    positionSuffix: $("#position-suffix"),
    lapValue: $("#lap-value"),
    raceTime: $("#race-time"),
    raceMessage: $("#race-message"),
    toast: $("#toast"),
    finishKicker: $("#finish-kicker"),
    finishTitle: $("#finish-title"),
    finishPlace: $("#finish-place"),
    finishTime: $("#finish-time"),
    bestLap: $("#best-lap"),
    speedLines: $("#speed-lines"),
    leftButton: $("#left-button"),
    rightButton: $("#right-button"),
    boostButton: $("#boost-button"),
  };

  const COLORS = {
    ink: "#111f19",
    floor: "#d9d0b9",
    floorAlt: "#cec4ab",
    yellow: "#ffc62e",
    orange: "#ff6d32",
    mint: "#75e0a1",
    cream: "#fff8e5",
    shelf: "#203e30",
    shelfDark: "#142b20",
  };

  const TRACK_LENGTH = 2400;
  const TOTAL_LAPS = 3;
  const RENDER_DISTANCE = 1450;
  const keys = { left: false, right: false, boost: false };
  const particles = [];
  const trackObjects = [];
  const racers = [
    { name: "RUSTY", color: "#ef5d35", stripe: "#ffd66b", skill: 0.96 },
    { name: "WOBBLES", color: "#59b8e8", stripe: "#f7f0d6", skill: 0.93 },
    { name: "BANANA JOE", color: "#f7c93e", stripe: "#27392e", skill: 0.91 },
    { name: "TROLLEY DOLLY", color: "#d870b5", stripe: "#ffda63", skill: 0.89 },
    { name: "THE SQUEAKER", color: "#68c887", stripe: "#f4f1dd", skill: 0.87 },
  ];

  let width = 0;
  let height = 0;
  let dpr = 1;
  let lastFrame = performance.now();
  let state = "menu";
  let stateBeforePause = "racing";
  let sceneTime = 0;
  let raceTime = 0;
  let countdownTime = 0;
  let lastCountdownMark = 0;
  let lastLap = 1;
  let lapStartedAt = 0;
  let lapTimes = [];
  let position = 1;
  let shake = 0;
  let toastTimer = 0;
  let messageTimer = 0;
  let finishTimer = 0;

  const player = {
    x: 0,
    speed: 0,
    distance: 0,
    boost: 74,
    lean: 0,
    hitCooldown: 0,
    boostActive: false,
  };

  class ArcadeAudio {
    constructor() {
      this.context = null;
      this.muted = false;
      this.engineNode = null;
      this.engineGain = null;
    }

    ensure() {
      if (this.context) {
        if (this.context.state === "suspended") this.context.resume();
        return;
      }
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      this.context = new AudioContext();
      this.engineNode = this.context.createOscillator();
      this.engineGain = this.context.createGain();
      this.engineNode.type = "sawtooth";
      this.engineNode.frequency.value = 42;
      this.engineGain.gain.value = 0;
      this.engineNode.connect(this.engineGain).connect(this.context.destination);
      this.engineNode.start();
    }

    tone(frequency, duration = 0.1, type = "square", volume = 0.05, slide = 0) {
      if (this.muted) return;
      this.ensure();
      if (!this.context) return;
      const now = this.context.currentTime;
      const oscillator = this.context.createOscillator();
      const gain = this.context.createGain();
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, now);
      if (slide) oscillator.frequency.exponentialRampToValueAtTime(Math.max(20, frequency + slide), now + duration);
      gain.gain.setValueAtTime(volume, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
      oscillator.connect(gain).connect(this.context.destination);
      oscillator.start(now);
      oscillator.stop(now + duration);
    }

    engine(speed, boosting) {
      if (!this.context || !this.engineNode || !this.engineGain) return;
      const now = this.context.currentTime;
      const volume = this.muted || state !== "racing" ? 0 : 0.012 + speed / 30000;
      this.engineNode.frequency.setTargetAtTime(36 + speed * 0.22 + (boosting ? 24 : 0), now, 0.05);
      this.engineGain.gain.setTargetAtTime(volume, now, 0.08);
    }

    countdown(mark) {
      this.tone(mark === "GO!" ? 620 : 310, mark === "GO!" ? 0.38 : 0.14, "square", 0.065, mark === "GO!" ? 400 : 0);
    }

    pickup() {
      this.tone(520, 0.08, "sine", 0.07, 320);
      window.setTimeout(() => this.tone(820, 0.12, "sine", 0.055, 260), 70);
    }

    crash() {
      this.tone(110, 0.22, "sawtooth", 0.08, -70);
    }

    finish() {
      [392, 523, 659, 784].forEach((note, i) => {
        window.setTimeout(() => this.tone(note, 0.32, "square", 0.05, 40), i * 120);
      });
    }

    toggle() {
      this.muted = !this.muted;
      this.ensure();
      return this.muted;
    }
  }

  const audio = new ArcadeAudio();

  function resize() {
    width = window.innerWidth;
    height = window.innerHeight;
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(start, end, amount) {
    return start + (end - start) * amount;
  }

  function ease(current, target, speed, dt) {
    return lerp(current, target, 1 - Math.exp(-speed * dt));
  }

  function seededNoise(seed) {
    const x = Math.sin(seed * 91.731 + 17.17) * 43758.5453;
    return x - Math.floor(x);
  }

  function ordinal(number) {
    if (number % 100 >= 11 && number % 100 <= 13) return "TH";
    return ({ 1: "ST", 2: "ND", 3: "RD" })[number % 10] || "TH";
  }

  function formatTime(seconds) {
    const safe = Math.max(0, seconds);
    const minutes = Math.floor(safe / 60);
    const secs = Math.floor(safe % 60);
    const tenths = Math.floor((safe % 1) * 10);
    return `${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${tenths}`;
  }

  function makeTrack() {
    trackObjects.length = 0;
    const totalDistance = TRACK_LENGTH * TOTAL_LAPS;
    for (let distance = 280, index = 0; distance < totalDistance; distance += 250 + seededNoise(index) * 135, index += 1) {
      const lane = -0.72 + seededNoise(index + 40) * 1.44;
      const pickup = index % 3 !== 1;
      trackObjects.push({
        distance,
        x: lane,
        type: pickup ? "boost" : (index % 2 ? "boxes" : "spill"),
        used: false,
        phase: seededNoise(index + 90) * Math.PI * 2,
      });
      if (index % 5 === 3) {
        trackObjects.push({
          distance: distance + 25,
          x: clamp(lane + (seededNoise(index + 13) > 0.5 ? 0.58 : -0.58), -0.78, 0.78),
          type: "boost",
          used: false,
          phase: seededNoise(index + 190) * Math.PI * 2,
        });
      }
    }
  }

  function resetRace() {
    player.x = 0;
    player.speed = 0;
    player.distance = 0;
    player.boost = 74;
    player.lean = 0;
    player.hitCooldown = 0;
    player.boostActive = false;
    raceTime = 0;
    countdownTime = 0;
    lastCountdownMark = 0;
    lastLap = 1;
    lapStartedAt = 0;
    lapTimes = [];
    position = 1;
    shake = 0;
    finishTimer = 0;
    particles.length = 0;
    makeTrack();

    racers.forEach((racer, index) => {
      racer.distance = -30 - index * 26;
      racer.x = [-0.42, 0.42, -0.16, 0.66, -0.7][index];
      racer.targetX = racer.x;
      racer.speed = 0;
      racer.seed = index * 7.3 + 2;
      racer.changeTimer = 1 + seededNoise(index) * 2;
    });

    updateHud();
  }

  function startRace() {
    audio.ensure();
    resetRace();
    state = "countdown";
    ui.startScreen.classList.add("hidden");
    ui.finishScreen.classList.add("hidden");
    ui.pauseScreen.classList.add("hidden");
    ui.raceHud.classList.remove("hidden");
    ui.itemSlot.classList.remove("hidden");
    ui.touchControls.classList.remove("hidden");
    ui.pauseButton.classList.remove("hidden");
  }

  function restartRace() {
    ui.pauseScreen.classList.add("hidden");
    startRace();
  }

  function pauseRace() {
    if (state !== "racing" && state !== "countdown") return;
    stateBeforePause = state;
    state = "paused";
    keys.left = false;
    keys.right = false;
    keys.boost = false;
    ui.pauseScreen.classList.remove("hidden");
  }

  function resumeRace() {
    if (state !== "paused") return;
    state = stateBeforePause;
    lastFrame = performance.now();
    ui.pauseScreen.classList.add("hidden");
    audio.ensure();
  }

  function showMessage(text) {
    window.clearTimeout(messageTimer);
    ui.raceMessage.textContent = text;
    ui.raceMessage.classList.remove("hidden");
    ui.raceMessage.style.animation = "none";
    void ui.raceMessage.offsetWidth;
    ui.raceMessage.style.animation = "";
    messageTimer = window.setTimeout(() => ui.raceMessage.classList.add("hidden"), 760);
  }

  function showToast(text) {
    window.clearTimeout(toastTimer);
    ui.toast.textContent = text;
    ui.toast.classList.remove("hidden");
    toastTimer = window.setTimeout(() => ui.toast.classList.add("hidden"), 1050);
  }

  function updateCountdown(dt) {
    countdownTime += dt;
    const mark = countdownTime < 1 ? "3" : countdownTime < 2 ? "2" : countdownTime < 3 ? "1" : "GO!";
    const numericMark = Math.min(4, Math.floor(countdownTime) + 1);
    if (numericMark !== lastCountdownMark) {
      lastCountdownMark = numericMark;
      showMessage(mark);
      audio.countdown(mark);
    }
    if (countdownTime >= 3.62) {
      state = "racing";
      lapStartedAt = 0;
    }
  }

  function updateRacers(dt) {
    racers.forEach((racer, index) => {
      racer.changeTimer -= dt;
      if (racer.changeTimer <= 0) {
        racer.changeTimer = 1.2 + seededNoise(racer.distance * 0.01 + racer.seed) * 2.5;
        racer.targetX = -0.72 + seededNoise(racer.distance * 0.031 + index * 12) * 1.44;
      }
      racer.x = ease(racer.x, racer.targetX, 0.9, dt);

      const progressDifference = player.distance - racer.distance;
      const rubberBand = clamp(progressDifference * 0.022, -18, 28);
      const baseSpeed = 244 * racer.skill + rubberBand;
      const pulse = Math.sin(raceTime * 1.3 + racer.seed) * 8;
      racer.speed = ease(racer.speed, baseSpeed + pulse, 1.8, dt);
      racer.distance += racer.speed * dt;
    });
  }

  function updateRace(dt) {
    raceTime += dt;
    player.hitCooldown = Math.max(0, player.hitCooldown - dt);

    const steer = (keys.right ? 1 : 0) - (keys.left ? 1 : 0);
    const wantsBoost = keys.boost && player.boost > 0.5;
    player.boostActive = wantsBoost;

    const maxSpeed = wantsBoost ? 360 : 282;
    const acceleration = wantsBoost ? 2.9 : 1.65;
    player.speed = ease(player.speed, maxSpeed, acceleration, dt);

    if (wantsBoost) {
      player.boost = Math.max(0, player.boost - 29 * dt);
      if (Math.random() < dt * 42) addBoostParticle();
    } else {
      player.boost = Math.min(100, player.boost + 4.5 * dt);
    }

    player.x += steer * dt * (0.82 + player.speed / 380);
    player.lean = ease(player.lean, steer, 7, dt);

    if (Math.abs(player.x) > 0.9) {
      player.x = clamp(player.x, -0.94, 0.94);
      player.speed *= Math.pow(0.3, dt);
      shake = Math.max(shake, 3);
      if (Math.random() < dt * 24) addSparkParticle(player.x > 0 ? 1 : -1);
    }

    player.distance += player.speed * dt;
    updateRacers(dt);
    checkCollisions();
    updatePosition();

    const lap = Math.min(TOTAL_LAPS, Math.floor(player.distance / TRACK_LENGTH) + 1);
    if (lap > lastLap && player.distance < TRACK_LENGTH * TOTAL_LAPS) {
      lapTimes.push(raceTime - lapStartedAt);
      lapStartedAt = raceTime;
      lastLap = lap;
      showMessage(`LAP ${lap}`);
      audio.tone(540, 0.22, "square", 0.05, 240);
    }

    if (player.distance >= TRACK_LENGTH * TOTAL_LAPS) finishRace();
    updateHud();
    audio.engine(player.speed, wantsBoost);
  }

  function checkCollisions() {
    trackObjects.forEach((object) => {
      if (object.used) return;
      const delta = object.distance - player.distance;
      if (delta < 16 && delta > -34 && Math.abs(object.x - player.x) < (object.type === "boost" ? 0.23 : 0.27)) {
        object.used = true;
        const screenX = width / 2 + object.x * width * 0.29;
        if (object.type === "boost") {
          player.boost = Math.min(100, player.boost + 38);
          player.speed = Math.min(360, player.speed + 22);
          burst(screenX, height * 0.7, COLORS.yellow, 15);
          showToast("TURBO JUICE +38");
          audio.pickup();
        } else if (player.hitCooldown <= 0) {
          player.speed *= 0.48;
          player.hitCooldown = 1;
          shake = 15;
          burst(screenX, height * 0.73, object.type === "spill" ? "#9cd75a" : "#d69a5b", 18);
          showToast(object.type === "spill" ? "LETTUCE DISASTER!" : "CLEANUP, AISLE 5!");
          audio.crash();
        }
      }
    });

    if (player.hitCooldown > 0) return;
    racers.forEach((racer) => {
      if (Math.abs(racer.distance - player.distance) < 25 && Math.abs(racer.x - player.x) < 0.25) {
        player.speed *= 0.72;
        player.x += player.x > racer.x ? 0.11 : -0.11;
        racer.x += racer.x > player.x ? 0.14 : -0.14;
        player.hitCooldown = 0.65;
        shake = 9;
        audio.crash();
      }
    });
  }

  function updatePosition() {
    position = 1 + racers.filter((racer) => racer.distance > player.distance).length;
  }

  function updateHud() {
    ui.speedValue.textContent = String(Math.round(player.speed * 0.31)).padStart(2, "0");
    ui.boostFill.style.width = `${player.boost}%`;
    ui.positionValue.textContent = position;
    ui.positionSuffix.textContent = ordinal(position);
    ui.lapValue.textContent = Math.min(TOTAL_LAPS, Math.floor(player.distance / TRACK_LENGTH) + 1);
    ui.raceTime.textContent = formatTime(raceTime);
    ui.speedLines.style.opacity = player.boostActive ? String(clamp((player.speed - 280) / 70, 0, 0.55)) : "0";
  }

  function finishRace() {
    if (state === "finished") return;
    state = "finished";
    lapTimes.push(raceTime - lapStartedAt);
    finishTimer = 0;
    keys.boost = false;
    player.boostActive = false;
    audio.finish();
    showMessage("FINISH!");
    burst(width / 2, height * 0.35, COLORS.yellow, 45);
    burst(width * 0.35, height * 0.42, COLORS.mint, 28);
    burst(width * 0.65, height * 0.42, COLORS.orange, 28);
  }

  function showResults() {
    const won = position === 1;
    ui.finishKicker.textContent = won ? "RUN COMPLETE · NEW CHAMPION" : "RUN COMPLETE";
    ui.finishTitle.innerHTML = won ? "AISLE<br><em>LEGEND!</em>" : `SOLID<br><em>${position}${ordinal(position)} PLACE!</em>`;
    ui.finishPlace.textContent = `${position}${ordinal(position)}`;
    ui.finishTime.textContent = formatTime(raceTime);
    ui.bestLap.textContent = formatTime(Math.min(...lapTimes));
    ui.finishScreen.classList.remove("hidden");
    ui.touchControls.classList.add("hidden");
    ui.pauseButton.classList.add("hidden");
  }

  function updateParticles(dt) {
    for (let index = particles.length - 1; index >= 0; index -= 1) {
      const particle = particles[index];
      particle.life -= dt;
      if (particle.life <= 0) {
        particles.splice(index, 1);
        continue;
      }
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vy += particle.gravity * dt;
      particle.rotation += particle.spin * dt;
    }
  }

  function addBoostParticle() {
    const cartX = width / 2 + player.x * width * 0.29;
    particles.push({
      x: cartX + (Math.random() - 0.5) * 58,
      y: height * 0.88,
      vx: (Math.random() - 0.5) * 32,
      vy: 90 + Math.random() * 90,
      gravity: 35,
      life: 0.35 + Math.random() * 0.25,
      maxLife: 0.6,
      color: Math.random() > 0.5 ? COLORS.yellow : COLORS.orange,
      size: 3 + Math.random() * 6,
      rotation: 0,
      spin: 0,
      shape: "streak",
    });
  }

  function addSparkParticle(side) {
    const cartX = width / 2 + player.x * width * 0.29;
    particles.push({
      x: cartX + side * 64,
      y: height * 0.84,
      vx: -side * (20 + Math.random() * 70),
      vy: -20 - Math.random() * 80,
      gravity: 180,
      life: 0.25 + Math.random() * 0.25,
      maxLife: 0.5,
      color: COLORS.yellow,
      size: 2 + Math.random() * 3,
      rotation: 0,
      spin: 0,
      shape: "dot",
    });
  }

  function burst(x, y, color, count) {
    for (let index = 0; index < count; index += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 50 + Math.random() * 240;
      particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 80,
        gravity: 230,
        life: 0.55 + Math.random() * 0.9,
        maxLife: 1.45,
        color: index % 4 === 0 ? COLORS.cream : color,
        size: 3 + Math.random() * 8,
        rotation: Math.random() * Math.PI,
        spin: (Math.random() - 0.5) * 12,
        shape: index % 3 ? "square" : "dot",
      });
    }
  }

  function trackCurve(distance) {
    return Math.sin(distance / 610) * 0.14 + Math.sin(distance / 245 + 0.8) * 0.035;
  }

  function project(relativeDistance, cameraDistance) {
    const horizon = height * 0.205;
    const p = 1 - clamp(relativeDistance / RENDER_DISTANCE, 0, 1);
    const depth = Math.pow(p, 1.72);
    const y = horizon + depth * (height - horizon);
    const halfWidth = lerp(width * 0.048, width * 0.365, depth);
    const currentCurve = trackCurve(cameraDistance);
    const aheadCurve = trackCurve(cameraDistance + relativeDistance);
    const curveShift = (aheadCurve - currentCurve) * width * (1 - depth) * 1.9;
    const playerShift = -player.x * width * 0.075 * depth;
    return { y, halfWidth, center: width / 2 + curveShift + playerShift, depth };
  }

  function drawScene() {
    const menuDistance = sceneTime * 47;
    const cameraDistance = state === "menu" ? menuDistance : player.distance;
    const displaySpeed = state === "menu" ? 150 : player.speed;
    const shakeX = shake ? (Math.random() - 0.5) * shake : 0;
    const shakeY = shake ? (Math.random() - 0.5) * shake * 0.55 : 0;
    shake *= 0.88;

    ctx.save();
    ctx.translate(shakeX, shakeY);
    drawStore(cameraDistance, displaySpeed);
    drawTrackObjects(cameraDistance);
    drawOpponents(cameraDistance);
    drawParticles();
    drawPlayerCart(cameraDistance);
    ctx.restore();

    drawVignette();
  }

  function drawStore(cameraDistance, displaySpeed) {
    const horizon = height * 0.205;
    const ceilingGradient = ctx.createLinearGradient(0, 0, 0, horizon + 80);
    ceilingGradient.addColorStop(0, "#0d1f17");
    ceilingGradient.addColorStop(1, "#32513f");
    ctx.fillStyle = ceilingGradient;
    ctx.fillRect(0, 0, width, horizon + 90);

    const far = project(RENDER_DISTANCE, cameraDistance);
    const near = project(0, cameraDistance);

    ctx.fillStyle = COLORS.shelfDark;
    ctx.beginPath();
    ctx.moveTo(0, horizon - 8);
    ctx.lineTo(far.center - far.halfWidth, far.y);
    ctx.lineTo(near.center - near.halfWidth, height + 2);
    ctx.lineTo(0, height + 2);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(width, horizon - 8);
    ctx.lineTo(far.center + far.halfWidth, far.y);
    ctx.lineTo(near.center + near.halfWidth, height + 2);
    ctx.lineTo(width, height + 2);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = COLORS.floor;
    ctx.beginPath();
    ctx.moveTo(far.center - far.halfWidth, far.y);
    ctx.lineTo(far.center + far.halfWidth, far.y);
    ctx.lineTo(near.center + near.halfWidth, height + 2);
    ctx.lineTo(near.center - near.halfWidth, height + 2);
    ctx.closePath();
    ctx.fill();

    const segmentSize = 90;
    const offset = cameraDistance % segmentSize;
    for (let distance = RENDER_DISTANCE + offset; distance > -segmentSize; distance -= segmentSize) {
      const farPoint = project(clamp(distance, 0, RENDER_DISTANCE), cameraDistance);
      const nearPoint = project(clamp(distance - segmentSize, 0, RENDER_DISTANCE), cameraDistance);
      const segmentIndex = Math.floor((cameraDistance + distance) / segmentSize);
      ctx.fillStyle = segmentIndex % 2 ? COLORS.floorAlt : COLORS.floor;
      ctx.beginPath();
      ctx.moveTo(farPoint.center - farPoint.halfWidth, farPoint.y);
      ctx.lineTo(farPoint.center + farPoint.halfWidth, farPoint.y);
      ctx.lineTo(nearPoint.center + nearPoint.halfWidth, nearPoint.y);
      ctx.lineTo(nearPoint.center - nearPoint.halfWidth, nearPoint.y);
      ctx.closePath();
      ctx.fill();

      ctx.strokeStyle = "rgba(60, 72, 60, 0.18)";
      ctx.lineWidth = Math.max(0.5, nearPoint.depth * 1.3);
      ctx.beginPath();
      ctx.moveTo(nearPoint.center - nearPoint.halfWidth, nearPoint.y);
      ctx.lineTo(nearPoint.center + nearPoint.halfWidth, nearPoint.y);
      ctx.stroke();

      if (segmentIndex % 2 === 0) {
        ctx.beginPath();
        ctx.moveTo(farPoint.center, farPoint.y);
        ctx.lineTo(nearPoint.center, nearPoint.y);
        ctx.stroke();
      }
    }

    drawAisleEdges(cameraDistance);
    drawShelves(cameraDistance);
    drawCeiling(cameraDistance);

    if (displaySpeed > 250) {
      ctx.fillStyle = `rgba(255, 246, 216, ${clamp((displaySpeed - 250) / 600, 0, 0.08)})`;
      ctx.fillRect(0, horizon, width, height - horizon);
    }
  }

  function drawAisleEdges(cameraDistance) {
    for (const side of [-1, 1]) {
      ctx.strokeStyle = side < 0 ? "#e64f38" : "#f0bd2f";
      ctx.lineWidth = Math.max(3, width * 0.008);
      ctx.beginPath();
      for (let distance = RENDER_DISTANCE; distance >= 0; distance -= 50) {
        const point = project(distance, cameraDistance);
        const x = point.center + side * point.halfWidth;
        if (distance === RENDER_DISTANCE) ctx.moveTo(x, point.y);
        else ctx.lineTo(x, point.y);
      }
      ctx.stroke();

      ctx.strokeStyle = "rgba(255, 255, 255, 0.22)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let distance = RENDER_DISTANCE; distance >= 0; distance -= 60) {
        const point = project(distance, cameraDistance);
        const x = point.center + side * point.halfWidth * 0.64;
        if (distance === RENDER_DISTANCE) ctx.moveTo(x, point.y);
        else ctx.lineTo(x, point.y);
      }
      ctx.stroke();
    }
  }

  function drawShelves(cameraDistance) {
    const spacing = 215;
    const offset = cameraDistance % spacing;
    for (let distance = RENDER_DISTANCE + offset; distance > 15; distance -= spacing) {
      const point = project(distance, cameraDistance);
      if (point.depth < 0.012) continue;
      const shelfHeight = 20 + point.depth * height * 0.31;
      const shelfWidth = 12 + point.depth * width * 0.17;
      const rackThickness = Math.max(1, point.depth * 7);
      const seed = Math.floor((cameraDistance + distance) / spacing);

      [-1, 1].forEach((side) => {
        const edgeX = point.center + side * point.halfWidth;
        const outerX = edgeX + side * shelfWidth;
        const left = side < 0 ? outerX : edgeX;
        const right = side < 0 ? edgeX : outerX;
        const top = point.y - shelfHeight;

        ctx.fillStyle = side < 0 ? "#294a39" : "#254634";
        ctx.fillRect(left, top, right - left, shelfHeight);
        ctx.fillStyle = "rgba(8, 20, 14, 0.42)";
        ctx.fillRect(left, top, right - left, shelfHeight * 0.12);

        const rows = 3;
        for (let row = 0; row < rows; row += 1) {
          const rowY = top + shelfHeight * (0.26 + row * 0.27);
          const productHeight = shelfHeight * 0.16;
          const productCount = 3 + Math.floor(point.depth * 5);
          for (let product = 0; product < productCount; product += 1) {
            const gap = (right - left) / productCount;
            const productColor = ["#e45c3a", "#f2bd33", "#74c891", "#6ba9d3", "#e184ad"][(seed + row + product) % 5];
            ctx.fillStyle = productColor;
            ctx.fillRect(left + product * gap + gap * 0.14, rowY - productHeight, gap * 0.68, productHeight);
            ctx.fillStyle = "rgba(255,255,255,.3)";
            ctx.fillRect(left + product * gap + gap * 0.24, rowY - productHeight * 0.82, gap * 0.2, productHeight * 0.09);
          }
          ctx.fillStyle = "#b6b29a";
          ctx.fillRect(left, rowY, right - left, rackThickness);
        }
      });
    }
  }

  function drawCeiling(cameraDistance) {
    const horizon = height * 0.205;
    const vanishingX = width / 2 + (trackCurve(cameraDistance + RENDER_DISTANCE) - trackCurve(cameraDistance)) * width * 0.18;
    ctx.strokeStyle = "rgba(203, 225, 201, 0.12)";
    ctx.lineWidth = 2;
    [-0.42, -0.17, 0.17, 0.42].forEach((amount) => {
      ctx.beginPath();
      ctx.moveTo(vanishingX, horizon);
      ctx.lineTo(width / 2 + width * amount, 0);
      ctx.stroke();
    });

    const spacing = 330;
    const offset = cameraDistance % spacing;
    for (let distance = RENDER_DISTANCE + offset; distance > 80; distance -= spacing) {
      const point = project(distance, cameraDistance);
      const scale = 0.06 + point.depth * 0.9;
      const y = horizon - (1 - point.depth) * height * 0.13 - 8;
      const lightWidth = width * 0.21 * scale;
      ctx.save();
      ctx.translate(point.center, y);
      ctx.transform(1, 0, -0.16, 1, 0, 0);
      ctx.shadowColor = "rgba(255, 244, 193, .8)";
      ctx.shadowBlur = 15 * scale;
      ctx.fillStyle = "rgba(255, 247, 205, .82)";
      ctx.fillRect(-lightWidth / 2, 0, lightWidth, Math.max(2, 8 * scale));
      ctx.restore();
    }

    const signDistance = 620 - (cameraDistance % 1100);
    if (signDistance > 120 && signDistance < RENDER_DISTANCE) {
      const point = project(signDistance, cameraDistance);
      const scale = 0.12 + point.depth * 0.9;
      const signWidth = 142 * scale;
      const signHeight = 51 * scale;
      const y = point.y - 130 * scale;
      ctx.fillStyle = "#e95b3a";
      ctx.fillRect(point.center - signWidth / 2, y, signWidth, signHeight);
      ctx.fillStyle = COLORS.cream;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.font = `900 ${Math.max(7, 20 * scale)}px "Barlow Condensed", sans-serif`;
      ctx.fillText("AISLE 5  •  PRODUCE", point.center, y + signHeight / 2);
      ctx.strokeStyle = "#a8b7a6";
      ctx.lineWidth = Math.max(1, scale * 2);
      ctx.beginPath();
      ctx.moveTo(point.center - signWidth * 0.35, y);
      ctx.lineTo(point.center - signWidth * 0.35, y - 70 * scale);
      ctx.moveTo(point.center + signWidth * 0.35, y);
      ctx.lineTo(point.center + signWidth * 0.35, y - 70 * scale);
      ctx.stroke();
    }
  }

  function visibleObjects(cameraDistance) {
    return trackObjects
      .filter((object) => !object.used && object.distance - cameraDistance > 15 && object.distance - cameraDistance < RENDER_DISTANCE)
      .sort((a, b) => b.distance - a.distance);
  }

  function drawTrackObjects(cameraDistance) {
    visibleObjects(cameraDistance).forEach((object) => {
      const relative = object.distance - cameraDistance;
      const point = project(relative, cameraDistance);
      const x = point.center + object.x * point.halfWidth * 0.9;
      const scale = 0.07 + point.depth * 1.05;
      if (object.type === "boost") drawBoostPickup(x, point.y, scale, object.phase);
      else if (object.type === "boxes") drawBoxes(x, point.y, scale);
      else drawSpill(x, point.y, scale);
    });
  }

  function drawBoostPickup(x, y, scale, phase) {
    const bob = Math.sin(sceneTime * 5 + phase) * 5 * scale;
    ctx.save();
    ctx.translate(x, y - 42 * scale + bob);
    ctx.scale(scale, scale);
    ctx.rotate(sceneTime * 1.3 + phase);
    ctx.shadowColor = COLORS.yellow;
    ctx.shadowBlur = 22;
    ctx.fillStyle = "rgba(255, 198, 46, 0.24)";
    ctx.beginPath();
    ctx.arc(0, 0, 26, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = COLORS.yellow;
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.arc(0, 0, 20, 0, Math.PI * 2);
    ctx.stroke();
    ctx.rotate(-sceneTime * 1.3 - phase);
    ctx.fillStyle = COLORS.yellow;
    ctx.beginPath();
    ctx.moveTo(4, -15);
    ctx.lineTo(-9, 3);
    ctx.lineTo(1, 3);
    ctx.lineTo(-5, 16);
    ctx.lineTo(13, -5);
    ctx.lineTo(2, -5);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawBoxes(x, y, scale) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.fillStyle = "rgba(18, 30, 22, .26)";
    ctx.beginPath();
    ctx.ellipse(0, 2, 45, 11, 0, 0, Math.PI * 2);
    ctx.fill();
    [[-24, -31, 39, 32], [12, -27, 32, 28], [-7, -56, 36, 27]].forEach((box, index) => {
      ctx.fillStyle = index === 1 ? "#bf7a43" : "#d29a5b";
      ctx.fillRect(box[0], box[1], box[2], box[3]);
      ctx.strokeStyle = "#7c4e2e";
      ctx.lineWidth = 2;
      ctx.strokeRect(box[0], box[1], box[2], box[3]);
      ctx.beginPath();
      ctx.moveTo(box[0] + box[2] / 2, box[1]);
      ctx.lineTo(box[0] + box[2] / 2, box[1] + box[3]);
      ctx.stroke();
    });
    ctx.restore();
  }

  function drawSpill(x, y, scale) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.fillStyle = "rgba(32, 89, 35, .3)";
    ctx.beginPath();
    ctx.ellipse(0, -3, 48, 15, 0, 0, Math.PI * 2);
    ctx.fill();
    for (let index = 0; index < 7; index += 1) {
      const angle = index * 2.1;
      const px = Math.sin(angle) * (11 + index * 4.5);
      const py = -7 + Math.cos(angle) * 8;
      ctx.fillStyle = index % 2 ? "#75bd4d" : "#a8dc61";
      ctx.beginPath();
      ctx.arc(px, py, 6 + index % 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#3d762d";
      ctx.lineWidth = 2;
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawOpponents(cameraDistance) {
    const visible = racers
      .map((racer) => ({ racer, relative: racer.distance - cameraDistance }))
      .filter(({ relative }) => relative > 20 && relative < RENDER_DISTANCE)
      .sort((a, b) => b.relative - a.relative);

    visible.forEach(({ racer, relative }) => {
      const point = project(relative, cameraDistance);
      const x = point.center + racer.x * point.halfWidth * 0.87;
      const scale = 0.055 + point.depth * 0.83;
      drawCart(x, point.y, scale, racer.color, racer.stripe, Math.sin(sceneTime * 2 + racer.seed) * 0.1, false, racer.name);
    });
  }

  function drawPlayerCart(cameraDistance) {
    const showCart = state !== "menu" || width > 700;
    if (!showCart) return;
    const previewX = state === "menu" ? Math.sin(sceneTime * 0.42) * 0.12 : player.x;
    const cartX = width / 2 + previewX * width * 0.29;
    const cartY = height * 0.91;
    const scale = clamp(Math.min(width / 1050, height / 710), 0.62, 1.15);
    const lean = state === "menu" ? Math.sin(sceneTime * 0.75) * 0.1 : player.lean * 0.14;
    drawCart(cartX, cartY, scale, "#e94f36", "#ffc62e", lean, true, "YOU");
  }

  function roundedRect(context, x, y, w, h, radius) {
    const r = Math.min(radius, Math.abs(w) / 2, Math.abs(h) / 2);
    context.beginPath();
    context.roundRect(x, y, w, h, r);
  }

  function drawCart(x, y, scale, color, stripe, lean, isPlayer, name) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(lean);
    ctx.scale(scale, scale);

    ctx.fillStyle = "rgba(9, 21, 15, .3)";
    ctx.beginPath();
    ctx.ellipse(0, 3, 72, 17, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#17231d";
    ctx.beginPath();
    ctx.ellipse(-47, -2, 12, 17, -0.12, 0, Math.PI * 2);
    ctx.ellipse(47, -2, 12, 17, 0.12, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#8e9b92";
    ctx.beginPath();
    ctx.arc(-47, -3, 4, 0, Math.PI * 2);
    ctx.arc(47, -3, 4, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(-60, -85);
    ctx.lineTo(60, -85);
    ctx.lineTo(49, -15);
    ctx.lineTo(-47, -15);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = stripe;
    ctx.fillRect(-57, -82, 114, 13);
    ctx.fillStyle = "rgba(255,255,255,.16)";
    ctx.beginPath();
    ctx.moveTo(-52, -64);
    ctx.lineTo(52, -64);
    ctx.lineTo(48, -52);
    ctx.lineTo(-50, -52);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "rgba(22, 34, 28, .52)";
    ctx.lineWidth = 3;
    for (let line = -34; line <= 34; line += 17) {
      ctx.beginPath();
      ctx.moveTo(line, -68);
      ctx.lineTo(line * 0.83, -20);
      ctx.stroke();
    }
    [-51, -35].forEach((lineY) => {
      ctx.beginPath();
      ctx.moveTo(-51, lineY);
      ctx.lineTo(51, lineY);
      ctx.stroke();
    });

    ctx.fillStyle = "#c98b4a";
    roundedRect(ctx, -34, -104, 39, 32, 3);
    ctx.fill();
    ctx.strokeStyle = "#77502e";
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.fillStyle = "#6bb876";
    ctx.beginPath();
    ctx.arc(21, -94, 19, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#4b945d";
    ctx.beginPath();
    ctx.arc(31, -101, 12, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#efe7c7";
    ctx.lineWidth = 9;
    ctx.beginPath();
    ctx.moveTo(-2, -100);
    ctx.quadraticCurveTo(16, -127, 35, -106);
    ctx.stroke();

    ctx.strokeStyle = "#b9c3bb";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(-58, -86);
    ctx.lineTo(-72, -118);
    ctx.lineTo(72, -118);
    ctx.lineTo(59, -85);
    ctx.stroke();
    ctx.strokeStyle = stripe;
    ctx.lineWidth = 10;
    ctx.beginPath();
    ctx.moveTo(-73, -119);
    ctx.lineTo(73, -119);
    ctx.stroke();

    ctx.fillStyle = COLORS.ink;
    roundedRect(ctx, -28, -77, 56, 17, 4);
    ctx.fill();
    ctx.fillStyle = stripe;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = "900 11px 'Barlow Condensed', sans-serif";
    ctx.fillText(name, 0, -68);

    if (isPlayer && player.boostActive) {
      ctx.fillStyle = COLORS.yellow;
      ctx.shadowColor = COLORS.orange;
      ctx.shadowBlur = 13;
      ctx.beginPath();
      ctx.moveTo(-33, 6);
      ctx.lineTo(-19, 34 + Math.random() * 17);
      ctx.lineTo(-8, 5);
      ctx.closePath();
      ctx.moveTo(18, 5);
      ctx.lineTo(30, 37 + Math.random() * 18);
      ctx.lineTo(40, 4);
      ctx.closePath();
      ctx.fill();
    }

    ctx.restore();
  }

  function drawParticles() {
    particles.forEach((particle) => {
      ctx.save();
      ctx.globalAlpha = clamp(particle.life / Math.min(0.5, particle.maxLife), 0, 1);
      ctx.translate(particle.x, particle.y);
      ctx.rotate(particle.rotation);
      ctx.fillStyle = particle.color;
      if (particle.shape === "dot") {
        ctx.beginPath();
        ctx.arc(0, 0, particle.size, 0, Math.PI * 2);
        ctx.fill();
      } else if (particle.shape === "streak") {
        ctx.fillRect(-particle.size / 2, -particle.size * 3, particle.size, particle.size * 4);
      } else {
        ctx.fillRect(-particle.size / 2, -particle.size / 2, particle.size, particle.size);
      }
      ctx.restore();
    });
  }

  function drawVignette() {
    const gradient = ctx.createRadialGradient(width / 2, height * 0.55, Math.min(width, height) * 0.25, width / 2, height * 0.5, Math.max(width, height) * 0.75);
    gradient.addColorStop(0, "rgba(6, 18, 12, 0)");
    gradient.addColorStop(1, "rgba(5, 15, 10, 0.37)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
  }

  function tick(now) {
    const dt = Math.min((now - lastFrame) / 1000, 0.033);
    lastFrame = now;
    sceneTime += dt;

    if (state === "countdown") updateCountdown(dt);
    else if (state === "racing") updateRace(dt);
    else if (state === "finished") {
      finishTimer += dt;
      player.speed = ease(player.speed, 70, 1.4, dt);
      player.distance += player.speed * dt;
      racers.forEach((racer) => { racer.distance += racer.speed * dt; });
      if (finishTimer > 1.45 && ui.finishScreen.classList.contains("hidden")) showResults();
    }

    if (state !== "paused") updateParticles(dt);
    audio.engine(player.speed, player.boostActive);
    drawScene();
    requestAnimationFrame(tick);
  }

  function setKey(event, pressed) {
    const key = event.key.toLowerCase();
    if (["arrowleft", "a"].includes(key)) keys.left = pressed;
    if (["arrowright", "d"].includes(key)) keys.right = pressed;
    if ([" ", "arrowup", "w"].includes(key)) keys.boost = pressed;
    if (["arrowleft", "arrowright", "arrowup", " "].includes(key)) event.preventDefault();
  }

  function bindHold(button, keyName) {
    const press = (event) => {
      event.preventDefault();
      audio.ensure();
      keys[keyName] = true;
      button.classList.add("active");
      if (button.setPointerCapture && event.pointerId !== undefined) button.setPointerCapture(event.pointerId);
    };
    const release = (event) => {
      if (event) event.preventDefault();
      keys[keyName] = false;
      button.classList.remove("active");
    };
    button.addEventListener("pointerdown", press);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("lostpointercapture", release);
  }

  window.addEventListener("resize", resize);
  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" || event.key.toLowerCase() === "p") {
      if (state === "paused") resumeRace();
      else pauseRace();
      return;
    }
    if (state === "menu" && event.key === "Enter") {
      startRace();
      return;
    }
    if (state === "finished" && event.key === "Enter") {
      startRace();
      return;
    }
    setKey(event, true);
  });
  window.addEventListener("keyup", (event) => setKey(event, false));
  window.addEventListener("blur", () => {
    if (state === "racing" || state === "countdown") pauseRace();
  });
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && (state === "racing" || state === "countdown")) pauseRace();
  });

  ui.startButton.addEventListener("click", startRace);
  ui.pauseButton.addEventListener("click", pauseRace);
  ui.resumeButton.addEventListener("click", resumeRace);
  ui.restartPauseButton.addEventListener("click", restartRace);
  ui.raceAgainButton.addEventListener("click", startRace);
  ui.soundButton.addEventListener("click", () => {
    const muted = audio.toggle();
    ui.soundButton.classList.toggle("muted", muted);
    ui.soundButton.setAttribute("aria-label", muted ? "Turn sound on" : "Mute sound");
    ui.soundButton.setAttribute("aria-pressed", String(muted));
    if (!muted) audio.tone(540, 0.08, "sine", 0.04, 120);
  });

  bindHold(ui.leftButton, "left");
  bindHold(ui.rightButton, "right");
  bindHold(ui.boostButton, "boost");

  resize();
  makeTrack();
  requestAnimationFrame(tick);
})();
