import "./style.css";
import {
  MAX_SPEED,
  TOTAL_LAPS,
  TRACK_LENGTH,
  clamp,
  createTrackObjects,
  formatTime,
  lapForDistance,
  ordinalSuffix,
  playerPlace,
} from "./game-core.js";

const canvas = document.querySelector("#game");
const ctx = canvas.getContext("2d", { alpha: false, desynchronized: true });
const shell = document.querySelector("#game-shell");
const startScreen = document.querySelector("#start-screen");
const pauseScreen = document.querySelector("#pause-screen");
const finishScreen = document.querySelector("#finish-screen");
const countdownEl = document.querySelector("#countdown");
const toastEl = document.querySelector("#toast");

const ui = {
  place: document.querySelector("#place-value"),
  suffix: document.querySelector("#place-suffix"),
  lap: document.querySelector("#lap-value"),
  speed: document.querySelector("#speed-value"),
  boostFill: document.querySelector("#boost-fill"),
  boostLabel: document.querySelector("#boost-label"),
  boostButton: document.querySelector("#boost-button"),
};

const RACERS = [
  { name: "Maya", number: "09", body: "#f36b21", accent: "#ffd447", skin: "#7b452d", hat: "#46cdb7" },
  { name: "Jax", number: "24", body: "#2a86d1", accent: "#ff6f91", skin: "#c98559", hat: "#ffd447" },
  { name: "Sol", number: "77", body: "#815bc7", accent: "#46cdb7", skin: "#9d6544", hat: "#f36b21" },
];

const OPPONENT_TEMPLATES = [
  { name: "Rae", number: "13", body: "#ef4770", accent: "#ffd447", speed: 322, lane: -0.58, phase: 1.2 },
  { name: "Bo", number: "31", body: "#43b99f", accent: "#172e37", speed: 309, lane: 0.38, phase: 2.6 },
  { name: "Kit", number: "88", body: "#e8b72b", accent: "#e65322", speed: 298, lane: 0.66, phase: 4.1 },
  { name: "Lou", number: "05", body: "#4276d0", accent: "#f3eee0", speed: 286, lane: -0.2, phase: 5.5 },
  { name: "Dee", number: "42", body: "#9659c7", accent: "#42d2b5", speed: 276, lane: 0.12, phase: 0.4 },
];

const state = {
  mode: "menu",
  selectedRacer: 0,
  width: 0,
  height: 0,
  dpr: 1,
  time: 0,
  raceTime: 0,
  countdown: 3.6,
  countdownStep: 4,
  distance: 0,
  speed: 0,
  x: 0,
  steerVisual: 0,
  boost: 58,
  boostTimer: 0,
  impactTimer: 0,
  shake: 0,
  lapTimes: [],
  currentLapStart: 0,
  trackObjects: [],
  opponents: [],
  keys: { left: false, right: false },
};

let lastFrame = performance.now();
let toastTimer;
let audioContext;

function resize() {
  const rect = shell.getBoundingClientRect();
  state.width = rect.width;
  state.height = rect.height;
  state.dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(rect.width * state.dpr);
  canvas.height = Math.round(rect.height * state.dpr);
  ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0);
}

function makeOpponents() {
  return OPPONENT_TEMPLATES.map((opponent, index) => ({
    ...opponent,
    distance: 35 + index * 22,
    baseLane: opponent.lane,
    finished: false,
  }));
}

function resetRace() {
  Object.assign(state, {
    mode: "countdown",
    raceTime: 0,
    countdown: 3.6,
    countdownStep: 4,
    distance: 0,
    speed: 0,
    x: 0,
    steerVisual: 0,
    boost: 58,
    boostTimer: 0,
    impactTimer: 0,
    shake: 0,
    lapTimes: [],
    currentLapStart: 0,
    trackObjects: createTrackObjects(),
    opponents: makeOpponents(),
  });
  startScreen.classList.remove("screen--active");
  pauseScreen.classList.remove("screen--active");
  finishScreen.classList.remove("screen--active");
  pauseScreen.setAttribute("aria-hidden", "true");
  finishScreen.setAttribute("aria-hidden", "true");
  shell.classList.add("is-racing");
  updateHud();
  sound("start");
}

function setMenu() {
  state.mode = "menu";
  shell.classList.remove("is-racing");
  finishScreen.classList.remove("screen--active");
  finishScreen.setAttribute("aria-hidden", "true");
  startScreen.classList.add("screen--active");
}

function setPaused(paused) {
  if (paused && (state.mode === "race" || state.mode === "countdown")) {
    state.previousMode = state.mode;
    state.mode = "paused";
    pauseScreen.classList.add("screen--active");
    pauseScreen.setAttribute("aria-hidden", "false");
  } else if (!paused && state.mode === "paused") {
    state.mode = state.previousMode || "race";
    pauseScreen.classList.remove("screen--active");
    pauseScreen.setAttribute("aria-hidden", "true");
    lastFrame = performance.now();
  }
}

function finishRace() {
  state.mode = "finished";
  state.speed *= 0.82;
  shell.classList.remove("is-racing");
  const place = playerPlace(state.distance, state.opponents);
  const suffix = ordinalSuffix(place);
  const titles = ["Aisle legend!", "So close!", "Podium power!", "Strong finish!", "Cart comeback!"];
  document.querySelector("#finish-place").innerHTML = `${place}<sup>${suffix}</sup>`;
  document.querySelector("#finish-title").textContent = titles[Math.min(place - 1, titles.length - 1)];
  document.querySelector("#finish-eyebrow").textContent = place === 1 ? "Freezer Run champion" : "Race complete";
  document.querySelector("#finish-time").textContent = formatTime(state.raceTime);
  document.querySelector("#best-lap").textContent = formatTime(Math.min(...state.lapTimes));
  finishScreen.classList.add("screen--active");
  finishScreen.setAttribute("aria-hidden", "false");
  sound(place === 1 ? "win" : "finish");
}

function useBoost() {
  if (state.mode !== "race" || state.boost < 30 || state.boostTimer > 0.15) return;
  state.boost -= 30;
  state.boostTimer = 1.65;
  showToast("Turbo trolley!");
  sound("boost");
  navigator.vibrate?.(35);
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  toastEl.textContent = message;
  toastEl.classList.remove("is-visible");
  void toastEl.offsetWidth;
  toastEl.classList.add("is-visible");
  toastTimer = window.setTimeout(() => toastEl.classList.remove("is-visible"), 1300);
}

function sound(type) {
  try {
    audioContext ||= new AudioContext();
    if (audioContext.state === "suspended") audioContext.resume();
    const now = audioContext.currentTime;
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    const settings = {
      start: [180, 0.06, "square"],
      tick: [360, 0.08, "square"],
      go: [680, 0.18, "square"],
      pickup: [840, 0.12, "sine"],
      crash: [90, 0.2, "sawtooth"],
      boost: [210, 0.28, "sawtooth"],
      win: [760, 0.45, "triangle"],
      finish: [490, 0.3, "triangle"],
    }[type] || [220, 0.05, "sine"];
    oscillator.type = settings[2];
    oscillator.frequency.setValueAtTime(settings[0], now);
    oscillator.frequency.exponentialRampToValueAtTime(
      type === "crash" ? 45 : settings[0] * 1.55,
      now + settings[1],
    );
    gain.gain.setValueAtTime(0.06, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + settings[1]);
    oscillator.connect(gain).connect(audioContext.destination);
    oscillator.start(now);
    oscillator.stop(now + settings[1]);
  } catch {
    // Audio is optional and may be blocked until a user gesture.
  }
}

function update(dt) {
  state.time += dt;
  if (state.mode === "menu") return;
  if (state.mode === "paused" || state.mode === "finished") return;

  if (state.mode === "countdown") {
    state.countdown -= dt;
    const step = Math.ceil(state.countdown);
    if (step !== state.countdownStep) {
      state.countdownStep = step;
      if (step > 0) {
        countdownEl.textContent = step;
        countdownEl.className = "is-visible";
        sound("tick");
      } else {
        countdownEl.textContent = "GO!";
        countdownEl.className = "is-visible go";
        sound("go");
      }
    }
    if (state.countdown <= -0.7) {
      countdownEl.className = "";
      state.mode = "race";
    }
    updateOpponents(dt, 0.65);
    return;
  }

  state.raceTime += dt;
  state.impactTimer = Math.max(0, state.impactTimer - dt);
  state.boostTimer = Math.max(0, state.boostTimer - dt);
  state.shake = Math.max(0, state.shake - dt * 2.4);

  const steer = Number(state.keys.right) - Number(state.keys.left);
  state.steerVisual += (steer - state.steerVisual) * Math.min(1, dt * 10);
  const steeringPower = 1.05 + state.speed / MAX_SPEED;
  state.x = clamp(state.x + steer * steeringPower * dt, -1.08, 1.08);

  const offCourse = Math.abs(state.x) > 0.88;
  const targetSpeed = state.boostTimer > 0 ? MAX_SPEED : offCourse ? 238 : 345;
  const acceleration = state.speed < targetSpeed ? 150 : 210;
  state.speed += Math.sign(targetSpeed - state.speed) * Math.min(Math.abs(targetSpeed - state.speed), acceleration * dt);
  if (state.impactTimer > 0) state.speed = Math.min(state.speed, 185);

  if (Math.abs(steer) && state.speed > 270 && !offCourse) {
    state.boost = clamp(state.boost + dt * 5.5, 0, 100);
  }

  const previousDistance = state.distance;
  state.distance += state.speed * dt;
  updateOpponents(dt, 1);
  checkTrackObjects(previousDistance, state.distance);
  checkLap(previousDistance);
  updateHud();

  if (state.distance >= TRACK_LENGTH * TOTAL_LAPS) finishRace();
}

function updateOpponents(dt, speedScale) {
  state.opponents.forEach((opponent, index) => {
    const catchup = clamp((state.distance - opponent.distance) * 0.012, -24, 28);
    const variation = Math.sin(state.time * 0.7 + opponent.phase) * 7;
    opponent.distance += Math.max(230, opponent.speed + catchup + variation) * dt * speedScale;
    opponent.lane = clamp(
      opponent.baseLane + Math.sin(state.time * (0.45 + index * 0.03) + opponent.phase) * 0.13,
      -0.8,
      0.8,
    );
  });
}

function checkTrackObjects(previousDistance, currentDistance) {
  state.trackObjects.forEach((object) => {
    if (object.collected || object.distance < previousDistance - 10 || object.distance > currentDistance + 16) return;
    if (Math.abs(state.x - object.lane) > (object.type === "boost" ? 0.24 : 0.19)) return;
    object.collected = true;
    if (object.type === "boost") {
      state.boost = clamp(state.boost + 42, 0, 100);
      showToast("Boost charged!");
      sound("pickup");
      navigator.vibrate?.(18);
    } else {
      state.impactTimer = 0.58;
      state.speed *= 0.55;
      state.shake = 0.85;
      showToast(object.type === "spill" ? "Slippery spill!" : "Watch the aisle!");
      sound("crash");
      navigator.vibrate?.([45, 30, 55]);
    }
  });
}

function checkLap(previousDistance) {
  const oldLap = Math.floor(previousDistance / TRACK_LENGTH);
  const newLap = Math.floor(state.distance / TRACK_LENGTH);
  if (newLap <= oldLap || newLap > TOTAL_LAPS) return;
  const lapTime = state.raceTime - state.currentLapStart;
  state.lapTimes.push(lapTime);
  state.currentLapStart = state.raceTime;
  if (newLap < TOTAL_LAPS) showToast(newLap === TOTAL_LAPS - 1 ? "Final lap!" : `Lap ${newLap + 1}`);
}

function updateHud() {
  const place = playerPlace(state.distance, state.opponents);
  ui.place.textContent = place;
  ui.suffix.textContent = ordinalSuffix(place);
  ui.lap.textContent = lapForDistance(state.distance);
  ui.speed.textContent = Math.round(state.speed * 0.16);
  ui.boostFill.style.width = `${state.boost}%`;
  const ready = state.boost >= 30;
  ui.boostLabel.textContent = state.boostTimer > 0 ? "Active" : ready ? "Ready" : "Charge";
  ui.boostButton.disabled = !ready;
  ui.boostButton.classList.toggle("is-ready", ready && state.boostTimer <= 0);
}

function curveAt(distance) {
  return Math.sin(distance / 720) * 0.34 + Math.sin(distance / 260) * 0.09;
}

function perspective(relativeDistance) {
  const viewDistance = 1050;
  const normalized = clamp(1 - relativeDistance / viewDistance, 0, 1);
  const depth = normalized ** 1.65;
  const horizon = state.height * 0.255;
  return {
    visible: relativeDistance >= -35 && relativeDistance <= viewDistance,
    depth,
    y: horizon + depth * (state.height - horizon),
    scale: 0.08 + depth * 1.05,
    roadHalf: state.width * (0.055 + depth * 0.42),
    center: state.width / 2 + curveAt(state.distance + relativeDistance) * state.width * (0.08 + depth * 0.04),
  };
}

function render() {
  ctx.save();
  if (state.shake > 0) {
    const amount = state.shake * 8;
    ctx.translate((Math.random() - 0.5) * amount, (Math.random() - 0.5) * amount);
  }
  drawStore();
  drawCourse();
  drawWorldObjects();
  if (state.mode !== "menu") drawPlayerCart();
  ctx.restore();
}

function drawStore() {
  const { width: w, height: h } = state;
  const horizon = h * 0.255;
  const lightPulse = state.boostTimer > 0 ? 12 : 0;
  const ceiling = ctx.createLinearGradient(0, 0, 0, horizon);
  ceiling.addColorStop(0, `rgb(${18 + lightPulse}, ${43 + lightPulse}, ${51 + lightPulse})`);
  ceiling.addColorStop(1, "#31565a");
  ctx.fillStyle = ceiling;
  ctx.fillRect(0, 0, w, horizon + 2);

  ctx.fillStyle = "#8ca49b";
  ctx.fillRect(0, horizon - 12, w, 13);

  const floor = ctx.createLinearGradient(0, horizon, 0, h);
  floor.addColorStop(0, "#cfd2c3");
  floor.addColorStop(1, "#7b827b");
  ctx.fillStyle = floor;
  ctx.fillRect(0, horizon, w, h - horizon);

  ctx.strokeStyle = "rgba(255,255,255,.12)";
  ctx.lineWidth = 1;
  for (let x = -w; x < w * 2; x += w / 10) {
    ctx.beginPath();
    ctx.moveTo(w / 2, horizon);
    ctx.lineTo(x, h);
    ctx.stroke();
  }

  const scroll = (state.distance * 0.0014) % 1;
  for (let i = 0; i < 9; i += 1) {
    const t = ((i / 9 + scroll) % 1) ** 2;
    const y = horizon + t * (h - horizon);
    ctx.strokeStyle = `rgba(35,55,56,${0.08 + t * 0.15})`;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  drawCeilingLights();
  drawShelves();
  drawHangingSigns();
}

function drawCeilingLights() {
  const { width: w, height: h } = state;
  const horizon = h * 0.255;
  const offset = (state.distance * 0.0018) % 1;
  for (let row = 0; row < 5; row += 1) {
    const depth = ((row / 5 + offset) % 1) ** 1.35;
    const y = 8 + depth * (horizon - 28);
    const spread = w * (0.08 + depth * 0.55);
    const lampW = 30 + depth * 105;
    ctx.fillStyle = "rgba(255,248,205,.92)";
    ctx.shadowColor = "#fff4bd";
    ctx.shadowBlur = 8 + depth * 20;
    for (const side of [-1, 1]) {
      ctx.save();
      ctx.translate(w / 2 + side * spread, y);
      ctx.transform(1, 0, -side * 0.22, 1, 0, 0);
      ctx.fillRect(-lampW / 2, 0, lampW, 3 + depth * 7);
      ctx.restore();
    }
    ctx.shadowBlur = 0;
  }
}

function drawShelves() {
  const { width: w, height: h } = state;
  const horizon = h * 0.255;
  const shelfTop = h * 0.09;
  const leftEdge = w * 0.075;
  const rightEdge = w * 0.925;

  for (const side of [-1, 1]) {
    ctx.save();
    ctx.beginPath();
    if (side < 0) {
      ctx.moveTo(0, shelfTop);
      ctx.lineTo(w * 0.44, horizon);
      ctx.lineTo(w * 0.08, h);
      ctx.lineTo(0, h);
    } else {
      ctx.moveTo(w, shelfTop);
      ctx.lineTo(w * 0.56, horizon);
      ctx.lineTo(w * 0.92, h);
      ctx.lineTo(w, h);
    }
    ctx.closePath();
    ctx.clip();
    const gradient = ctx.createLinearGradient(side < 0 ? 0 : w, 0, side < 0 ? w * 0.45 : w * 0.55, 0);
    gradient.addColorStop(0, "#253e43");
    gradient.addColorStop(1, "#647574");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, shelfTop, w, h - shelfTop);

    for (let row = 0; row < 5; row += 1) {
      const y1 = shelfTop + row * (h - shelfTop) / 5;
      const y2 = y1 + (h - shelfTop) / 7;
      ctx.fillStyle = row % 2 ? "#dc783b" : "#3cae9b";
      ctx.globalAlpha = 0.52;
      ctx.fillRect(side < 0 ? 0 : rightEdge, y1, side < 0 ? leftEdge + row * 13 : w - rightEdge, y2 - y1);
      ctx.globalAlpha = 1;
      ctx.strokeStyle = "#d8ded4";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(0, y2);
      ctx.lineTo(w, y2);
      ctx.stroke();
    }
    ctx.restore();
  }
}

function drawHangingSigns() {
  const { width: w, height: h } = state;
  const signs = [
    { x: w * 0.18, y: h * 0.13, label: "FROZEN", color: "#4f9fd5" },
    { x: w * 0.82, y: h * 0.16, label: "SNACKS", color: "#f36b21" },
  ];
  ctx.font = `800 ${clamp(w * 0.014, 10, 19)}px "Barlow Condensed"`;
  ctx.textAlign = "center";
  signs.forEach((sign) => {
    const width = clamp(w * 0.11, 75, 145);
    ctx.fillStyle = "rgba(5,22,28,.35)";
    ctx.fillRect(sign.x - 1, 0, 2, sign.y);
    ctx.fillStyle = sign.color;
    ctx.fillRect(sign.x - width / 2, sign.y, width, clamp(h * 0.045, 20, 42));
    ctx.fillStyle = "white";
    ctx.fillText(sign.label, sign.x, sign.y + clamp(h * 0.031, 15, 28));
  });
}

function drawCourse() {
  const { width: w, height: h } = state;
  const horizon = h * 0.255;
  const segments = 42;
  for (let i = segments - 1; i >= 0; i -= 1) {
    const near = perspective((i / segments) * 1050);
    const far = perspective(((i + 1) / segments) * 1050);
    const stripeIndex = Math.floor((state.distance + (i / segments) * 1050) / 70);
    ctx.beginPath();
    ctx.moveTo(far.center - far.roadHalf, far.y);
    ctx.lineTo(far.center + far.roadHalf, far.y);
    ctx.lineTo(near.center + near.roadHalf, near.y);
    ctx.lineTo(near.center - near.roadHalf, near.y);
    ctx.closePath();
    ctx.fillStyle = stripeIndex % 2 ? "rgba(53,67,67,.12)" : "rgba(255,255,255,.08)";
    ctx.fill();

    for (const side of [-1, 1]) {
      const outerNear = near.center + side * near.roadHalf;
      const innerNear = near.center + side * near.roadHalf * 0.965;
      const outerFar = far.center + side * far.roadHalf;
      const innerFar = far.center + side * far.roadHalf * 0.965;
      ctx.beginPath();
      ctx.moveTo(outerFar, far.y);
      ctx.lineTo(innerFar, far.y);
      ctx.lineTo(innerNear, near.y);
      ctx.lineTo(outerNear, near.y);
      ctx.fillStyle = stripeIndex % 2 ? "#f36b21" : "#f7ead2";
      ctx.fill();
    }
  }

  ctx.strokeStyle = "rgba(30,65,67,.25)";
  ctx.lineWidth = 2;
  for (const lane of [-0.5, 0, 0.5]) {
    ctx.beginPath();
    for (let i = 0; i <= 20; i += 1) {
      const p = perspective((i / 20) * 1050);
      const x = p.center + lane * p.roadHalf;
      if (i === 0) ctx.moveTo(x, p.y);
      else ctx.lineTo(x, p.y);
    }
    ctx.stroke();
  }

  if (state.distance < 180 || state.distance > TRACK_LENGTH * TOTAL_LAPS - 250) {
    const nextLine = state.distance < 180 ? 85 : TRACK_LENGTH * TOTAL_LAPS;
    const p = perspective(nextLine - state.distance);
    if (p.visible) {
      const block = Math.max(3, p.roadHalf / 9);
      for (let i = -8; i < 8; i += 1) {
        ctx.fillStyle = i % 2 ? "#fff5df" : "#102c38";
        ctx.fillRect(p.center + i * block, p.y - block * 0.3, block, Math.max(3, block * 0.35));
      }
    }
  }

  ctx.fillStyle = "rgba(16,44,56,.25)";
  ctx.fillRect(0, horizon - 1, w, 2);
}

function drawWorldObjects() {
  const renderables = [];
  state.trackObjects.forEach((object) => {
    if (object.collected) return;
    const relative = object.distance - state.distance;
    const p = perspective(relative);
    if (p.visible) renderables.push({ kind: object.type, lane: object.lane, p, object });
  });
  state.opponents.forEach((opponent) => {
    const relative = opponent.distance - state.distance;
    const wrappedRelative = relative < -80 && state.distance < TRACK_LENGTH * TOTAL_LAPS - 400 ? relative + TRACK_LENGTH : relative;
    const p = perspective(wrappedRelative);
    if (p.visible) renderables.push({ kind: "opponent", lane: opponent.lane, p, opponent });
  });
  renderables.sort((a, b) => a.p.depth - b.p.depth);
  renderables.forEach((item) => {
    const x = item.p.center + item.lane * item.p.roadHalf * 0.82;
    if (item.kind === "opponent") drawRivalCart(x, item.p.y, item.p.scale, item.opponent);
    else drawTrackItem(x, item.p.y, item.p.scale, item.kind);
  });
}

function drawTrackItem(x, y, scale, type) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  if (type === "boost") {
    ctx.shadowColor = "#ffd447";
    ctx.shadowBlur = 22;
    ctx.fillStyle = "#ffd447";
    ctx.beginPath();
    ctx.arc(0, -24, 24, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.fillStyle = "#f36b21";
    ctx.beginPath();
    ctx.moveTo(5, -47);
    ctx.lineTo(-12, -20);
    ctx.lineTo(0, -20);
    ctx.lineTo(-7, 0);
    ctx.lineTo(18, -31);
    ctx.lineTo(5, -31);
    ctx.closePath();
    ctx.fill();
  } else if (type === "box") {
    ctx.fillStyle = "#a86a36";
    ctx.fillRect(-26, -42, 52, 42);
    ctx.strokeStyle = "#e1af70";
    ctx.lineWidth = 5;
    ctx.strokeRect(-26, -42, 52, 42);
    ctx.beginPath();
    ctx.moveTo(-24, -40);
    ctx.lineTo(24, -2);
    ctx.moveTo(24, -40);
    ctx.lineTo(-24, -2);
    ctx.stroke();
  } else if (type === "spill") {
    ctx.fillStyle = "rgba(77,180,211,.75)";
    ctx.beginPath();
    ctx.ellipse(0, -3, 47, 13, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#e8f5f4";
    ctx.font = "900 18px Inter";
    ctx.textAlign = "center";
    ctx.fillText("WET", 0, -5);
  } else {
    for (const offset of [-22, 22]) {
      ctx.fillStyle = "#f36b21";
      ctx.beginPath();
      ctx.moveTo(offset, -43);
      ctx.lineTo(offset - 17, 0);
      ctx.lineTo(offset + 17, 0);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#fff5df";
      ctx.fillRect(offset - 10, -19, 20, 7);
    }
  }
  ctx.restore();
}

function drawRivalCart(x, y, scale, rival) {
  const s = scale * 0.78;
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.fillStyle = "rgba(8,18,22,.28)";
  ctx.beginPath();
  ctx.ellipse(0, 2, 52, 13, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#19282d";
  ctx.beginPath();
  ctx.arc(-34, -3, 9, 0, Math.PI * 2);
  ctx.arc(34, -3, 9, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = rival.body;
  ctx.beginPath();
  ctx.moveTo(-45, -69);
  ctx.lineTo(45, -69);
  ctx.lineTo(34, -10);
  ctx.lineTo(-34, -10);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = "#d6dfdb";
  ctx.lineWidth = 5;
  ctx.stroke();
  ctx.strokeStyle = "rgba(255,255,255,.65)";
  ctx.lineWidth = 2;
  for (let row = -56; row < -17; row += 13) {
    ctx.beginPath();
    ctx.moveTo(-38, row);
    ctx.lineTo(38, row);
    ctx.stroke();
  }
  ctx.fillStyle = rival.accent;
  ctx.fillRect(-17, -85, 34, 25);
  ctx.fillStyle = "#102c38";
  ctx.font = "900 17px Barlow Condensed";
  ctx.textAlign = "center";
  ctx.fillText(rival.number, 0, -67);
  ctx.fillStyle = "#b87852";
  ctx.beginPath();
  ctx.arc(0, -90, 15, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawPlayerCart() {
  const racer = RACERS[state.selectedRacer];
  const { width: w, height: h } = state;
  const baseScale = clamp(Math.min(w / 1100, h / 620), 0.55, 1.12);
  const bounce = Math.sin(state.time * (8 + state.speed * 0.015)) * Math.min(2.5, state.speed / 130);
  const x = w / 2 + state.x * w * 0.28;
  const y = h - 26 + bounce;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(-state.steerVisual * 0.065);
  ctx.scale(baseScale, baseScale);

  if (state.boostTimer > 0) {
    for (const side of [-1, 1]) {
      const length = 55 + Math.random() * 35;
      const gradient = ctx.createLinearGradient(side * 48, -4, side * 48, length);
      gradient.addColorStop(0, "#fff");
      gradient.addColorStop(.25, "#ffd447");
      gradient.addColorStop(1, "rgba(243,107,33,0)");
      ctx.fillStyle = gradient;
      ctx.beginPath();
      ctx.moveTo(side * 33, -5);
      ctx.lineTo(side * 55, -5);
      ctx.lineTo(side * 42, length);
      ctx.closePath();
      ctx.fill();
    }
  }

  ctx.fillStyle = "rgba(5,14,17,.35)";
  ctx.beginPath();
  ctx.ellipse(0, -3, 104, 21, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#17272d";
  for (const wheelX of [-74, 74]) {
    ctx.beginPath();
    ctx.arc(wheelX, -5, 18, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#dce1db";
    ctx.lineWidth = 6;
    ctx.stroke();
  }

  ctx.fillStyle = racer.body;
  ctx.beginPath();
  ctx.moveTo(-104, -141);
  ctx.lineTo(104, -141);
  ctx.lineTo(76, -24);
  ctx.lineTo(-76, -24);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = "#e2e6df";
  ctx.lineWidth = 11;
  ctx.stroke();

  ctx.strokeStyle = "rgba(255,255,255,.7)";
  ctx.lineWidth = 4;
  for (let row = -119; row <= -45; row += 23) {
    ctx.beginPath();
    ctx.moveTo(-89 + (row + 119) * .12, row);
    ctx.lineTo(89 - (row + 119) * .12, row);
    ctx.stroke();
  }
  for (let column = -65; column <= 65; column += 33) {
    ctx.beginPath();
    ctx.moveTo(column, -136);
    ctx.lineTo(column * .72, -29);
    ctx.stroke();
  }

  ctx.fillStyle = "#d5a45d";
  ctx.fillRect(-82, -124, 49, 72);
  ctx.fillStyle = racer.accent;
  ctx.fillRect(26, -111, 58, 57);
  ctx.fillStyle = "#fff5df";
  ctx.font = "900 19px Barlow Condensed";
  ctx.textAlign = "center";
  ctx.fillText("GO!", 55, -77);

  ctx.fillStyle = racer.skin;
  ctx.beginPath();
  ctx.arc(0, -180, 31, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = racer.hat;
  ctx.beginPath();
  ctx.arc(0, -188, 32, Math.PI, 0);
  ctx.fill();
  ctx.fillRect(-31, -191, 75, 9);

  ctx.strokeStyle = "#dce1db";
  ctx.lineWidth = 10;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.moveTo(-97, -151);
  ctx.lineTo(-112, -215);
  ctx.lineTo(76, -215);
  ctx.stroke();
  ctx.strokeStyle = "#102c38";
  ctx.lineWidth = 13;
  ctx.beginPath();
  ctx.moveTo(-112, -215);
  ctx.lineTo(-43, -215);
  ctx.stroke();

  ctx.fillStyle = racer.accent;
  ctx.fillRect(76, -204, 47, 38);
  ctx.fillStyle = "#102c38";
  ctx.font = "900 25px Barlow Condensed";
  ctx.fillText(racer.number, 99, -177);
  ctx.restore();
}

function bindHoldButton(element, key) {
  const press = (event) => {
    event.preventDefault();
    state.keys[key] = true;
    element.classList.add("is-pressed");
    element.setPointerCapture?.(event.pointerId);
  };
  const release = (event) => {
    event.preventDefault();
    state.keys[key] = false;
    element.classList.remove("is-pressed");
  };
  element.addEventListener("pointerdown", press);
  element.addEventListener("pointerup", release);
  element.addEventListener("pointercancel", release);
  element.addEventListener("lostpointercapture", release);
}

document.querySelectorAll(".racer-card").forEach((card) => {
  card.addEventListener("click", () => {
    state.selectedRacer = Number(card.dataset.racer);
    document.querySelectorAll(".racer-card").forEach((item) => {
      const selected = item === card;
      item.classList.toggle("racer-card--active", selected);
      item.setAttribute("aria-pressed", selected);
    });
    sound("tick");
  });
});

document.querySelector("#start-button").addEventListener("click", resetRace);
document.querySelector("#pause-button").addEventListener("click", () => setPaused(true));
document.querySelector("#resume-button").addEventListener("click", () => setPaused(false));
document.querySelector("#restart-from-pause").addEventListener("click", resetRace);
document.querySelector("#race-again-button").addEventListener("click", resetRace);
document.querySelector("#change-cart-button").addEventListener("click", setMenu);
ui.boostButton.addEventListener("pointerdown", (event) => {
  event.preventDefault();
  useBoost();
});

bindHoldButton(document.querySelector("#left-button"), "left");
bindHoldButton(document.querySelector("#right-button"), "right");

window.addEventListener("keydown", (event) => {
  if (["ArrowLeft", "a", "A"].includes(event.key)) state.keys.left = true;
  if (["ArrowRight", "d", "D"].includes(event.key)) state.keys.right = true;
  if (event.code === "Space") {
    event.preventDefault();
    useBoost();
  }
  if (event.key === "Escape") setPaused(state.mode !== "paused");
});

window.addEventListener("keyup", (event) => {
  if (["ArrowLeft", "a", "A"].includes(event.key)) state.keys.left = false;
  if (["ArrowRight", "d", "D"].includes(event.key)) state.keys.right = false;
});

document.addEventListener("visibilitychange", () => {
  if (document.hidden) setPaused(true);
});

window.addEventListener("resize", resize);
window.addEventListener("orientationchange", resize);

function frame(now) {
  const dt = Math.min((now - lastFrame) / 1000, 0.05);
  lastFrame = now;
  update(dt);
  render();
  requestAnimationFrame(frame);
}

resize();
state.opponents = makeOpponents();
updateHud();
requestAnimationFrame(frame);

if ("serviceWorker" in navigator && import.meta.env.PROD) {
  window.addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}));
}
