(function () {
  "use strict";

  const {
    clamp,
    lerp,
    wrap,
    forwardDistance,
    ordinal,
    formatTime,
    calculateRank,
    seededRandom,
  } = window.CartDashCore;

  const canvas = document.querySelector("#game-canvas");
  const context = canvas.getContext("2d");
  const menuScreen = document.querySelector("#menu-screen");
  const raceScreen = document.querySelector("#race-screen");
  const pauseScreen = document.querySelector("#pause-screen");
  const finishScreen = document.querySelector("#finish-screen");
  const countdownElement = document.querySelector("#countdown");
  const itemToast = document.querySelector("#item-toast");

  const TRACK_LENGTH = 3000;
  const LAPS = 3;
  const RACE_DISTANCE = TRACK_LENGTH * LAPS;
  const VIEW_DISTANCE = 1320;

  const RACERS = {
    ace: {
      name: "Ace",
      shirt: "#bd482f",
      skin: "#a96541",
      speed: 330,
      grip: 0.84,
      boost: 1,
    },
    nova: {
      name: "Nova",
      shirt: "#3c897d",
      skin: "#774934",
      speed: 310,
      grip: 1.04,
      boost: 0.92,
    },
    milo: {
      name: "Milo",
      shirt: "#80434c",
      skin: "#c0885d",
      speed: 342,
      grip: 0.7,
      boost: 1.16,
    },
  };

  const RIVAL_TEMPLATES = [
    { name: "Rook", color: "#4b8b80", skin: "#805138", x: -0.58, speed: 287 },
    { name: "Sunny", color: "#d99a35", skin: "#b67750", x: 0.52, speed: 298 },
    { name: "Duke", color: "#7f586d", skin: "#6c4330", x: 0.1, speed: 279 },
  ];

  const input = { left: false, right: false, drift: false };
  const state = {
    mode: "menu",
    selectedRacer: "ace",
    player: createPlayer(),
    rivals: [],
    items: createItems(),
    particles: [],
    collected: new Set(),
    elapsed: 0,
    startAt: 0,
    startedAt: 0,
    pausedAt: 0,
    pauseOffset: 0,
    countdownValue: "",
    toastUntil: 0,
    finishRank: 1,
    muted: false,
    lastFrame: performance.now(),
    shake: 0,
  };

  let width = 1;
  let height = 1;
  let pixelRatio = 1;
  let audioContext = null;
  let engineOscillator = null;
  let engineGain = null;

  function createPlayer() {
    return {
      x: 0,
      speed: 0,
      distance: 0,
      driftCharge: 0,
      boostTimer: 0,
      snacks: 0,
      previousDrift: false,
      hitCooldown: 0,
      lean: 0,
    };
  }

  function createRivals() {
    return RIVAL_TEMPLATES.map((rival, index) => ({
      ...rival,
      distance: -70 - index * 58,
      baseX: rival.x,
      phase: index * 2.1,
      finished: false,
    }));
  }

  function createItems() {
    const random = seededRandom(2026);
    const items = [];
    for (let distance = 290, index = 0; distance < TRACK_LENGTH - 80; distance += 195, index += 1) {
      const roll = random();
      items.push({
        id: index,
        distance,
        x: random() * 1.55 - 0.775,
        type: roll < 0.18 ? "spill" : roll < 0.52 ? "boost" : "snack",
        spin: random() * Math.PI * 2,
      });
    }
    return items;
  }

  function resizeCanvas() {
    width = window.innerWidth;
    height = window.innerHeight;
    pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * pixelRatio);
    canvas.height = Math.round(height * pixelRatio);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  }

  function initAudio() {
    if (audioContext || state.muted) return;
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    audioContext = new AudioContext();
    engineOscillator = audioContext.createOscillator();
    engineGain = audioContext.createGain();
    engineOscillator.type = "sawtooth";
    engineOscillator.frequency.value = 55;
    engineGain.gain.value = 0;
    engineOscillator.connect(engineGain);
    engineGain.connect(audioContext.destination);
    engineOscillator.start();
  }

  function setEngineSound() {
    if (!audioContext || !engineGain || !engineOscillator) return;
    const active = (state.mode === "racing" || state.mode === "countdown") && !state.muted;
    const ratio = state.player.speed / RACERS[state.selectedRacer].speed;
    engineGain.gain.setTargetAtTime(active ? 0.018 + ratio * 0.018 : 0, audioContext.currentTime, 0.08);
    engineOscillator.frequency.setTargetAtTime(47 + ratio * 72, audioContext.currentTime, 0.05);
  }

  function playTone(frequency, duration, type = "sine", volume = 0.06) {
    if (state.muted) return;
    initAudio();
    if (!audioContext) return;
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    oscillator.type = type;
    oscillator.frequency.value = frequency;
    gain.gain.setValueAtTime(volume, audioContext.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioContext.currentTime + duration);
    oscillator.connect(gain);
    gain.connect(audioContext.destination);
    oscillator.start();
    oscillator.stop(audioContext.currentTime + duration);
  }

  function chooseRacer(racerId) {
    if (!RACERS[racerId]) return;
    state.selectedRacer = racerId;
    document.querySelectorAll(".racer-card").forEach((card) => {
      const selected = card.dataset.racer === racerId;
      card.classList.toggle("is-selected", selected);
      card.setAttribute("aria-checked", String(selected));
    });
    playTone(320, 0.08, "triangle", 0.04);
  }

  function beginRace() {
    initAudio();
    if (audioContext?.state === "suspended") audioContext.resume();
    state.player = createPlayer();
    state.rivals = createRivals();
    state.collected.clear();
    state.particles.length = 0;
    state.elapsed = 0;
    state.pauseOffset = 0;
    state.startAt = performance.now() + 2950;
    state.startedAt = state.startAt;
    state.mode = "countdown";
    state.countdownValue = "";
    state.shake = 0;
    clearInputs();
    menuScreen.classList.remove("is-active");
    finishScreen.classList.remove("is-active");
    pauseScreen.classList.remove("is-active");
    raceScreen.classList.add("is-active");
    updateHud();
  }

  function pauseRace() {
    if (state.mode !== "racing") return;
    state.mode = "paused";
    state.pausedAt = performance.now();
    clearInputs();
    pauseScreen.classList.add("is-active");
  }

  function resumeRace() {
    if (state.mode !== "paused") return;
    const pauseDuration = performance.now() - state.pausedAt;
    state.startedAt += pauseDuration;
    state.mode = "racing";
    state.lastFrame = performance.now();
    pauseScreen.classList.remove("is-active");
  }

  function quitRace() {
    state.mode = "menu";
    state.player.speed = 0;
    clearInputs();
    raceScreen.classList.remove("is-active");
    pauseScreen.classList.remove("is-active");
    finishScreen.classList.remove("is-active");
    menuScreen.classList.add("is-active");
  }

  function finishRace() {
    if (state.mode === "finished") return;
    state.mode = "finished";
    state.finishRank = calculateRank(state.player.distance, state.rivals);
    const result = ordinal(state.finishRank);
    const suffix = result.slice(String(state.finishRank).length);
    const bestKey = `cart-dash-best-${state.selectedRacer}`;
    const oldBest = Number(localStorage.getItem(bestKey)) || Infinity;
    const newBest = Math.min(oldBest, state.elapsed);
    localStorage.setItem(bestKey, String(newBest));

    document.querySelector("#finish-position").innerHTML = `${state.finishRank}<span>${suffix}</span>`;
    document.querySelector("#finish-time").textContent = formatTime(state.elapsed);
    document.querySelector("#best-time").textContent = formatTime(newBest);
    document.querySelector("#finish-snacks").textContent = String(state.player.snacks);
    document.querySelector("#finish-kicker").innerHTML =
      state.finishRank === 1 ? "<span></span> Aisle legend" : "<span></span> One more run";
    document.querySelector("#finish-title").textContent =
      state.finishRank === 1 ? "You owned the night." : "The night fights back.";
    finishScreen.classList.add("is-active");
    playTone(state.finishRank === 1 ? 680 : 420, 0.5, "triangle", 0.08);
  }

  function clearInputs() {
    input.left = false;
    input.right = false;
    input.drift = false;
    document.querySelectorAll(".touch-button").forEach((button) => button.classList.remove("is-pressed"));
  }

  function setControl(control, pressed) {
    if (!(control in input)) return;
    input[control] = pressed;
    document.querySelectorAll(`[data-control="${control}"]`).forEach((button) => {
      button.classList.toggle("is-pressed", pressed);
    });
  }

  function updateCountdown(now) {
    const remaining = state.startAt - now;
    let value = "";
    if (remaining > 2000) value = "3";
    else if (remaining > 1000) value = "2";
    else if (remaining > 0) value = "1";
    else if (remaining > -650) value = "GO!";
    else {
      state.mode = "racing";
      countdownElement.classList.remove("is-visible");
      return;
    }

    if (value !== state.countdownValue) {
      state.countdownValue = value;
      countdownElement.textContent = value;
      countdownElement.classList.remove("is-visible");
      requestAnimationFrame(() => countdownElement.classList.add("is-visible"));
      playTone(value === "GO!" ? 620 : 360, value === "GO!" ? 0.24 : 0.1, "square", 0.045);
    }
  }

  function updateRace(delta, now) {
    const player = state.player;
    const racer = RACERS[state.selectedRacer];
    const steer = Number(input.right) - Number(input.left);
    const offTrack = Math.abs(player.x) > 1;
    const targetSpeed = racer.speed * (offTrack ? 0.57 : 1) * (player.boostTimer > 0 ? 1.26 : 1);
    const acceleration = player.speed < targetSpeed ? 92 : 140;

    player.speed += Math.sign(targetSpeed - player.speed) * Math.min(Math.abs(targetSpeed - player.speed), acceleration * delta);
    player.hitCooldown = Math.max(0, player.hitCooldown - delta);
    player.boostTimer = Math.max(0, player.boostTimer - delta);

    const steerStrength = input.drift ? 1.23 : racer.grip;
    player.x += steer * steerStrength * delta * clamp(player.speed / 175, 0.28, 1.55);
    player.x = clamp(player.x, -1.34, 1.34);
    player.lean = lerp(player.lean, steer * (input.drift ? 0.95 : 0.58), Math.min(1, delta * 9));

    if (input.drift && steer !== 0 && player.speed > racer.speed * 0.5) {
      player.driftCharge = clamp(player.driftCharge + delta * 34 * racer.boost, 0, 100);
      if (Math.random() < delta * 22) createDriftParticle();
    } else if (player.previousDrift && !input.drift) {
      if (player.driftCharge >= 18) {
        player.boostTimer = 0.45 + player.driftCharge / 62;
        showToast("⚡", "Drift boost!");
        playTone(520, 0.16, "sawtooth", 0.055);
      }
      player.driftCharge = 0;
    } else if (!input.drift) {
      player.driftCharge = Math.max(0, player.driftCharge - delta * 6);
    }
    player.previousDrift = input.drift;

    player.distance += player.speed * delta;
    state.elapsed = now - state.startedAt;

    state.rivals.forEach((rival, index) => {
      const rubberBand = clamp((player.distance - rival.distance) / 1600, -0.1, 0.12);
      rival.distance += rival.speed * (1 + rubberBand) * delta;
      rival.x = clamp(
        rival.baseX + Math.sin(rival.distance * 0.004 + rival.phase) * (0.18 + index * 0.025),
        -0.88,
        0.88,
      );
      rival.finished = rival.distance >= RACE_DISTANCE;
    });

    checkItemCollisions();
    checkRivalCollisions();
    updateParticles(delta);

    if (player.distance >= RACE_DISTANCE) {
      player.distance = RACE_DISTANCE;
      finishRace();
    }
  }

  function itemKey(item) {
    const lap = Math.floor(state.player.distance / TRACK_LENGTH);
    return `${lap}:${item.id}`;
  }

  function checkItemCollisions() {
    const playerLocal = wrap(state.player.distance, TRACK_LENGTH);
    state.items.forEach((item) => {
      const key = itemKey(item);
      if (state.collected.has(key)) return;
      let distance = item.distance - playerLocal;
      if (distance < -TRACK_LENGTH / 2) distance += TRACK_LENGTH;
      if (Math.abs(distance) > 42 || Math.abs(state.player.x - item.x) > 0.18) return;

      state.collected.add(key);
      if (item.type === "boost") {
        state.player.boostTimer = Math.max(state.player.boostTimer, 1.25);
        showToast("⚡", "Night boost!");
        playTone(610, 0.18, "sawtooth", 0.06);
      } else if (item.type === "snack") {
        state.player.snacks += 1;
        state.player.driftCharge = clamp(state.player.driftCharge + 14, 0, 100);
        showToast("★", "Snack scored!");
        playTone(760, 0.13, "triangle", 0.055);
      } else {
        state.player.speed *= 0.46;
        state.player.hitCooldown = 0.7;
        state.shake = 0.5;
        showToast("!", "Cleanup on aisle 5!");
        playTone(110, 0.25, "square", 0.05);
      }
    });
  }

  function checkRivalCollisions() {
    if (state.player.hitCooldown > 0) return;
    const rival = state.rivals.find(
      (entry) => Math.abs(entry.distance - state.player.distance) < 38 && Math.abs(entry.x - state.player.x) < 0.23,
    );
    if (!rival) return;
    state.player.speed *= 0.72;
    state.player.x += state.player.x > rival.x ? 0.12 : -0.12;
    state.player.hitCooldown = 0.55;
    state.shake = 0.35;
    showToast("✦", "Cart check!");
    playTone(145, 0.16, "square", 0.045);
  }

  function showToast(icon, message) {
    itemToast.innerHTML = `<span>${icon}</span><strong>${message}</strong>`;
    itemToast.classList.add("is-visible");
    state.toastUntil = performance.now() + 1250;
  }

  function createDriftParticle() {
    const player = state.player;
    state.particles.push({
      x: width / 2 + player.lean * 25 + (Math.random() - 0.5) * 64,
      y: height * 0.84 + Math.random() * 18,
      vx: (Math.random() - 0.5) * 40,
      vy: 22 + Math.random() * 30,
      life: 0.45 + Math.random() * 0.35,
      maxLife: 0.8,
      color: player.driftCharge > 65 ? "#f8c92c" : "#ef7134",
    });
  }

  function updateParticles(delta) {
    state.particles.forEach((particle) => {
      particle.x += particle.vx * delta;
      particle.y += particle.vy * delta;
      particle.life -= delta;
    });
    state.particles = state.particles.filter((particle) => particle.life > 0);
    state.shake = Math.max(0, state.shake - delta);
  }

  function updateHud() {
    const rank = calculateRank(state.player.distance, state.rivals);
    const rankText = ordinal(rank);
    const suffix = rankText.slice(String(rank).length);
    document.querySelector("#hud-position").innerHTML = `${rank}<span>${suffix}</span>`;
    document.querySelector("#hud-lap").textContent = String(clamp(Math.floor(state.player.distance / TRACK_LENGTH) + 1, 1, LAPS));
    document.querySelector("#hud-time").textContent = formatTime(state.elapsed);
    document.querySelector("#speed-value").textContent = String(Math.round(state.player.speed * 0.21));
    document.querySelector("#boost-fill").style.width = `${state.player.driftCharge}%`;
  }

  function trackCurve(position) {
    return Math.sin(position * 0.0021) * 0.52 + Math.sin(position * 0.0054 + 1.7) * 0.21;
  }

  function project(distance, x = 0) {
    const horizon = height * 0.275;
    const near = clamp(1 - distance / VIEW_DISTANCE, 0, 1);
    const depth = near * near;
    const roadWidth = lerp(width * 0.055, width * 0.62, Math.pow(near, 1.1));
    const curve = trackCurve(state.player.distance + distance) - trackCurve(state.player.distance);
    const center =
      width / 2 +
      curve * width * 0.2 * depth -
      state.player.x * width * 0.26 * depth;
    return {
      x: center + x * roadWidth * 0.73,
      y: horizon + depth * (height - horizon),
      roadWidth,
      scale: 0.12 + near * 1.18,
      near,
      center,
    };
  }

  function drawGame() {
    context.save();
    if (state.shake > 0) {
      context.translate((Math.random() - 0.5) * 12 * state.shake, (Math.random() - 0.5) * 8 * state.shake);
    }
    drawStore();
    drawTrackObjects();
    drawParticles();
    drawPlayerCart();
    context.restore();
  }

  function drawStore() {
    const horizon = height * 0.275;
    const ceiling = context.createLinearGradient(0, 0, 0, horizon);
    ceiling.addColorStop(0, "#080b11");
    ceiling.addColorStop(1, "#1d2022");
    context.fillStyle = ceiling;
    context.fillRect(0, 0, width, horizon + 2);

    context.fillStyle = "#d9d3bd";
    const lightWidth = Math.max(38, width * 0.065);
    for (let x = -lightWidth; x < width + lightWidth; x += lightWidth * 2.7) {
      context.globalAlpha = 0.32;
      context.fillRect(x + wrap(state.player.distance * 0.12, lightWidth * 2.7), horizon * 0.34, lightWidth, 4);
    }
    context.globalAlpha = 1;

    const far = project(VIEW_DISTANCE);
    context.fillStyle = "#313535";
    context.fillRect(0, horizon - 4, width, 12);
    context.fillStyle = "#1a1e20";
    context.fillRect(far.center - width * 0.06, horizon - 40, width * 0.12, 42);

    for (let distance = VIEW_DISTANCE; distance > 0; distance -= 74) {
      const farPoint = project(distance);
      const nearPoint = project(Math.max(0, distance - 74));
      const stripe = Math.floor((state.player.distance + distance) / 74) % 2 === 0;
      drawQuad(
        farPoint.center - farPoint.roadWidth,
        farPoint.y,
        farPoint.center + farPoint.roadWidth,
        farPoint.y,
        nearPoint.center + nearPoint.roadWidth,
        nearPoint.y,
        nearPoint.center - nearPoint.roadWidth,
        nearPoint.y,
        stripe ? "#3d403d" : "#373a38",
      );

      const edge = stripe ? "#e0c650" : "#c7b347";
      drawQuad(
        farPoint.center - farPoint.roadWidth,
        farPoint.y,
        farPoint.center - farPoint.roadWidth * 0.94,
        farPoint.y,
        nearPoint.center - nearPoint.roadWidth * 0.94,
        nearPoint.y,
        nearPoint.center - nearPoint.roadWidth,
        nearPoint.y,
        edge,
      );
      drawQuad(
        farPoint.center + farPoint.roadWidth * 0.94,
        farPoint.y,
        farPoint.center + farPoint.roadWidth,
        farPoint.y,
        nearPoint.center + nearPoint.roadWidth,
        nearPoint.y,
        nearPoint.center + nearPoint.roadWidth * 0.94,
        nearPoint.y,
        edge,
      );
      drawShelves(farPoint, nearPoint, stripe);
    }

    drawCeilingSigns();
    const vignette = context.createRadialGradient(width / 2, height * 0.52, width * 0.18, width / 2, height * 0.52, width * 0.8);
    vignette.addColorStop(0, "rgba(0,0,0,0)");
    vignette.addColorStop(1, "rgba(0,0,0,.48)");
    context.fillStyle = vignette;
    context.fillRect(0, 0, width, height);
  }

  function drawShelves(farPoint, nearPoint, alternate) {
    const farHeight = farPoint.roadWidth * 0.52;
    const nearHeight = nearPoint.roadWidth * 0.52;
    const leftFar = farPoint.center - farPoint.roadWidth;
    const leftNear = nearPoint.center - nearPoint.roadWidth;
    const rightFar = farPoint.center + farPoint.roadWidth;
    const rightNear = nearPoint.center + nearPoint.roadWidth;

    drawQuad(
      leftFar - farPoint.roadWidth * 0.38,
      farPoint.y - farHeight,
      leftFar,
      farPoint.y,
      leftNear,
      nearPoint.y,
      leftNear - nearPoint.roadWidth * 0.38,
      nearPoint.y - nearHeight,
      alternate ? "#313b3c" : "#283133",
    );
    drawQuad(
      rightFar,
      farPoint.y,
      rightFar + farPoint.roadWidth * 0.38,
      farPoint.y - farHeight,
      rightNear + nearPoint.roadWidth * 0.38,
      nearPoint.y - nearHeight,
      rightNear,
      nearPoint.y,
      alternate ? "#343b39" : "#2c3331",
    );

    context.strokeStyle = "rgba(224,218,189,.18)";
    context.lineWidth = Math.max(0.5, nearPoint.scale * 1.2);
    [0.26, 0.52, 0.77].forEach((level) => {
      context.beginPath();
      context.moveTo(leftFar - farPoint.roadWidth * 0.38, farPoint.y - farHeight * level);
      context.lineTo(leftNear - nearPoint.roadWidth * 0.38, nearPoint.y - nearHeight * level);
      context.moveTo(rightFar + farPoint.roadWidth * 0.38, farPoint.y - farHeight * level);
      context.lineTo(rightNear + nearPoint.roadWidth * 0.38, nearPoint.y - nearHeight * level);
      context.stroke();
    });

    if (nearPoint.near > 0.23 && Math.floor((state.player.distance + nearPoint.y) / 74) % 3 === 0) {
      const productColor = alternate ? "#bf5a39" : "#d0a94c";
      context.fillStyle = productColor;
      const size = Math.max(1, nearPoint.scale * 5);
      context.fillRect(leftNear - nearPoint.roadWidth * 0.29, nearPoint.y - nearHeight * 0.62, size, size * 1.25);
      context.fillRect(rightNear + nearPoint.roadWidth * 0.19, nearPoint.y - nearHeight * 0.4, size * 1.3, size);
    }
  }

  function drawCeilingSigns() {
    const local = wrap(state.player.distance + 650, 700);
    const distance = 650 - local;
    if (distance < 60 || distance > VIEW_DISTANCE) return;
    const point = project(distance);
    const signWidth = Math.max(18, point.roadWidth * 0.58);
    const signHeight = signWidth * 0.22;
    context.fillStyle = "#ddac24";
    context.fillRect(point.center - signWidth / 2, point.y - signHeight * 2.7, signWidth, signHeight);
    context.fillStyle = "#17191b";
    context.font = `800 ${Math.max(5, signHeight * 0.52)}px "Barlow Condensed", sans-serif`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText("CHECKOUT  ·  AISLE  07", point.center, point.y - signHeight * 2.18);
  }

  function drawTrackObjects() {
    const renderables = [];
    const playerLocal = wrap(state.player.distance, TRACK_LENGTH);
    const lap = Math.floor(state.player.distance / TRACK_LENGTH);

    state.items.forEach((item) => {
      let delta = forwardDistance(playerLocal, item.distance, TRACK_LENGTH);
      if (delta > VIEW_DISTANCE) return;
      if (state.collected.has(`${lap}:${item.id}`)) return;
      renderables.push({ kind: "item", delta, data: item });
    });

    state.rivals.forEach((rival) => {
      const delta = rival.distance - state.player.distance;
      if (delta > 12 && delta < VIEW_DISTANCE) renderables.push({ kind: "rival", delta, data: rival });
    });

    renderables
      .sort((a, b) => b.delta - a.delta)
      .forEach((entry) => {
        const point = project(entry.delta, entry.data.x);
        if (entry.kind === "rival") drawRivalCart(point, entry.data);
        else drawItem(point, entry.data);
      });
  }

  function drawItem(point, item) {
    const size = Math.max(3, point.scale * (item.type === "spill" ? 28 : 22));
    context.save();
    context.translate(point.x, point.y - size * 0.35);

    if (item.type === "spill") {
      context.scale(1.5, 0.42);
      context.fillStyle = "rgba(107,180,193,.72)";
      context.beginPath();
      context.ellipse(0, 0, size, size * 0.55, 0, 0, Math.PI * 2);
      context.fill();
      context.fillStyle = "rgba(215,242,238,.48)";
      context.beginPath();
      context.ellipse(-size * 0.2, -size * 0.1, size * 0.36, size * 0.14, 0, 0, Math.PI * 2);
      context.fill();
    } else {
      context.rotate(performance.now() * 0.002 + item.spin);
      context.fillStyle = item.type === "boost" ? "#f8c92c" : "#ef7134";
      context.shadowBlur = point.scale * 12;
      context.shadowColor = context.fillStyle;
      context.beginPath();
      for (let index = 0; index < 8; index += 1) {
        const angle = (Math.PI * 2 * index) / 8 - Math.PI / 2;
        const radius = index % 2 === 0 ? size : size * 0.7;
        const x = Math.cos(angle) * radius;
        const y = Math.sin(angle) * radius;
        if (index === 0) context.moveTo(x, y);
        else context.lineTo(x, y);
      }
      context.closePath();
      context.fill();
      context.shadowBlur = 0;
      context.fillStyle = "#17191b";
      context.font = `900 ${size * 0.95}px "Barlow Condensed", sans-serif`;
      context.textAlign = "center";
      context.textBaseline = "middle";
      context.fillText(item.type === "boost" ? "⚡" : "★", 0, 1);
    }
    context.restore();
  }

  function drawRivalCart(point, rival) {
    const size = Math.max(5, point.scale * 32);
    context.save();
    context.translate(point.x, point.y - size * 0.25);
    context.scale(point.scale, point.scale);
    drawCartShape(rival.color, rival.skin, Math.sin(rival.distance * 0.035) * 0.12, 0.64);
    context.restore();

    if (point.near > 0.62) {
      context.fillStyle = "rgba(8,11,18,.7)";
      context.fillRect(point.x - size * 0.7, point.y - size * 1.9, size * 1.4, size * 0.42);
      context.fillStyle = "#f3eee2";
      context.font = `700 ${Math.max(7, size * 0.25)}px Inter, sans-serif`;
      context.textAlign = "center";
      context.fillText(rival.name.toUpperCase(), point.x, point.y - size * 1.59);
    }
  }

  function drawPlayerCart() {
    if (state.mode === "menu") return;
    const player = state.player;
    const racer = RACERS[state.selectedRacer];
    const baseSize = clamp(Math.min(width, height) / 430, 0.72, 1.45);
    const bob = Math.sin(performance.now() * 0.018) * clamp(player.speed / 130, 0, 2);
    const x = width / 2 + player.lean * width * 0.028;
    const y = height * 0.83 + bob;

    if (player.boostTimer > 0) {
      context.save();
      context.globalCompositeOperation = "lighter";
      for (let index = 0; index < 4; index += 1) {
        const gradient = context.createLinearGradient(x, y, x, y + 90 * baseSize);
        gradient.addColorStop(0, "rgba(248,201,44,.8)");
        gradient.addColorStop(1, "rgba(239,87,38,0)");
        context.strokeStyle = gradient;
        context.lineWidth = (7 - index) * baseSize;
        context.beginPath();
        context.moveTo(x + (index - 1.5) * 18 * baseSize, y + 20 * baseSize);
        context.lineTo(x + (index - 1.5) * 25 * baseSize, y + (62 + Math.random() * 30) * baseSize);
        context.stroke();
      }
      context.restore();
    }

    context.save();
    context.translate(x, y);
    context.rotate(player.lean * 0.09);
    context.scale(baseSize * 2.05, baseSize * 2.05);
    drawCartShape(racer.shirt, racer.skin, player.lean, 1);
    context.restore();
  }

  function drawCartShape(shirt, skin, lean, alpha) {
    context.globalAlpha = alpha;
    context.lineJoin = "round";
    context.lineCap = "round";

    context.fillStyle = "rgba(0,0,0,.35)";
    context.beginPath();
    context.ellipse(0, 18, 34, 10, 0, 0, Math.PI * 2);
    context.fill();

    context.strokeStyle = "#ced3d1";
    context.lineWidth = 2.2;
    context.fillStyle = "#505b5d";
    context.beginPath();
    context.moveTo(-28, -6);
    context.lineTo(25, -6);
    context.lineTo(20, 18);
    context.lineTo(-22, 18);
    context.closePath();
    context.fill();
    context.stroke();

    context.strokeStyle = "rgba(225,232,229,.55)";
    context.lineWidth = 1;
    [-14, 0, 14].forEach((x) => {
      context.beginPath();
      context.moveTo(x, -5);
      context.lineTo(x * 0.74, 17);
      context.stroke();
    });
    [1, 8].forEach((y) => {
      context.beginPath();
      context.moveTo(-25, y);
      context.lineTo(23, y);
      context.stroke();
    });

    context.strokeStyle = "#d9ddda";
    context.lineWidth = 3;
    context.beginPath();
    context.moveTo(-29, -7);
    context.lineTo(-34, -24);
    context.lineTo(-46, -24);
    context.stroke();

    context.fillStyle = "#1a1d20";
    context.beginPath();
    context.arc(-17, 23, 5, 0, Math.PI * 2);
    context.arc(17, 23, 5, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "#8b9292";
    context.beginPath();
    context.arc(-17, 23, 2, 0, Math.PI * 2);
    context.arc(17, 23, 2, 0, Math.PI * 2);
    context.fill();

    context.save();
    context.translate(-7 + lean * 3, -13);
    context.rotate(lean * 0.13);
    context.fillStyle = shirt;
    context.beginPath();
    context.ellipse(0, 0, 17, 21, -0.18, 0, Math.PI * 2);
    context.fill();
    context.strokeStyle = shirt;
    context.lineWidth = 7;
    context.beginPath();
    context.moveTo(-9, -7);
    context.lineTo(-28, -22);
    context.stroke();

    context.fillStyle = skin;
    context.beginPath();
    context.arc(-5, -29, 10.5, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "#252322";
    context.beginPath();
    context.arc(-6, -32, 11, Math.PI, Math.PI * 2);
    context.fill();
    context.restore();
    context.globalAlpha = 1;
  }

  function drawParticles() {
    state.particles.forEach((particle) => {
      context.globalAlpha = clamp(particle.life / particle.maxLife, 0, 1);
      context.fillStyle = particle.color;
      context.beginPath();
      context.arc(particle.x, particle.y, 2 + particle.life * 3, 0, Math.PI * 2);
      context.fill();
    });
    context.globalAlpha = 1;
  }

  function drawQuad(x1, y1, x2, y2, x3, y3, x4, y4, color) {
    context.fillStyle = color;
    context.beginPath();
    context.moveTo(x1, y1);
    context.lineTo(x2, y2);
    context.lineTo(x3, y3);
    context.lineTo(x4, y4);
    context.closePath();
    context.fill();
  }

  function frame(now) {
    const delta = Math.min((now - state.lastFrame) / 1000, 0.05);
    state.lastFrame = now;

    if (state.mode === "countdown") updateCountdown(now);
    if (state.mode === "racing") updateRace(delta, now);
    if (state.toastUntil && now > state.toastUntil) {
      itemToast.classList.remove("is-visible");
      state.toastUntil = 0;
    }
    setEngineSound();
    drawGame();
    if (state.mode !== "menu") updateHud();
    requestAnimationFrame(frame);
  }

  document.querySelectorAll(".racer-card").forEach((card) => {
    card.addEventListener("click", () => chooseRacer(card.dataset.racer));
  });
  document.querySelector("#start-button").addEventListener("click", beginRace);
  document.querySelector("#pause-button").addEventListener("click", pauseRace);
  document.querySelector("#resume-button").addEventListener("click", resumeRace);
  document.querySelector("#race-again-button").addEventListener("click", beginRace);
  document.querySelectorAll(".js-quit").forEach((button) => button.addEventListener("click", quitRace));

  document.querySelector("#sound-toggle").addEventListener("click", (event) => {
    state.muted = !state.muted;
    event.currentTarget.classList.toggle("is-muted", state.muted);
    event.currentTarget.setAttribute("aria-pressed", String(state.muted));
    event.currentTarget.setAttribute("aria-label", state.muted ? "Unmute sound" : "Mute sound");
    if (!state.muted) {
      initAudio();
      playTone(420, 0.08, "triangle", 0.04);
    }
  });

  document.querySelectorAll("[data-control]").forEach((button) => {
    const control = button.dataset.control;
    const press = (event) => {
      event.preventDefault();
      button.setPointerCapture?.(event.pointerId);
      setControl(control, true);
    };
    const release = (event) => {
      event.preventDefault();
      setControl(control, false);
    };
    button.addEventListener("pointerdown", press);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("pointerleave", (event) => {
      if (event.buttons === 0) release(event);
    });
  });

  window.addEventListener("keydown", (event) => {
    const key = event.key.toLowerCase();
    if (key === "arrowleft" || key === "a") setControl("left", true);
    if (key === "arrowright" || key === "d") setControl("right", true);
    if (key === "shift" || key === " " || key === "arrowdown") setControl("drift", true);
    if (key === "escape" && state.mode === "racing") pauseRace();
    else if (key === "escape" && state.mode === "paused") resumeRace();
    if (["arrowleft", "arrowright", "arrowdown", " "].includes(key)) event.preventDefault();
  });

  window.addEventListener("keyup", (event) => {
    const key = event.key.toLowerCase();
    if (key === "arrowleft" || key === "a") setControl("left", false);
    if (key === "arrowright" || key === "d") setControl("right", false);
    if (key === "shift" || key === " " || key === "arrowdown") setControl("drift", false);
  });

  window.addEventListener("blur", () => {
    clearInputs();
    if (state.mode === "racing") pauseRace();
  });
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && state.mode === "racing") pauseRace();
  });
  window.addEventListener("resize", resizeCanvas);

  resizeCanvas();
  requestAnimationFrame(frame);

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    navigator.serviceWorker.register("service-worker.js").catch(() => {});
  }
})();
