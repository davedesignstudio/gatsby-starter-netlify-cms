const canvas = document.querySelector("#track");
const ctx = canvas.getContext("2d", { alpha: false });
const game = document.querySelector("#game");

const ui = {
  position: document.querySelector("#position"),
  suffix: document.querySelector("#positionSuffix"),
  lap: document.querySelector("#lap"),
  lapProgress: document.querySelector("#lapProgress"),
  speed: document.querySelector("#speed"),
  speedRing: document.querySelector("#speedRing"),
  boostCount: document.querySelector("#boostCount"),
  boostButton: document.querySelector('[data-control="boost"]'),
  rivalTag: document.querySelector("#rivalTag"),
  rivalName: document.querySelector("#rivalName"),
  rivalDistance: document.querySelector("#rivalDistance"),
  announcement: document.querySelector("#announcement"),
  startScreen: document.querySelector("#startScreen"),
  howScreen: document.querySelector("#howScreen"),
  pauseScreen: document.querySelector("#pauseScreen"),
  finishScreen: document.querySelector("#finishScreen"),
  finishPosition: document.querySelector("#finishPosition"),
  finishTitle: document.querySelector("#finishTitle"),
  finishStats: document.querySelector("#finishStats"),
};

const COLORS = {
  cream: "#f7f0dc",
  ink: "#19141e",
  purple: "#4a2a68",
  purpleDark: "#2c193f",
  orange: "#ff5b2e",
  yellow: "#ffd93d",
  mint: "#7de0b2",
  floor: "#bcb6a9",
};

const TRACK_LENGTH = 1300;
const LAPS = 3;
const RACE_LENGTH = TRACK_LENGTH * LAPS;
const VIEW_DISTANCE = 230;

const controls = { left: false, right: false, drift: false };
const state = {
  mode: "menu",
  distance: 0,
  speed: 0,
  displaySpeed: 0,
  x: 0,
  xVelocity: 0,
  boost: 3,
  boostTimer: 0,
  driftCharge: 0,
  elapsed: 0,
  countdown: 0,
  lastTime: performance.now(),
  shake: 0,
  flash: 0,
  position: 3,
};

const opponents = [
  { name: "Bulk Benny", color: COLORS.mint, progress: 35, speed: 48.3, lane: 0.42, phase: 0.2 },
  { name: "Coupon Carl", color: COLORS.orange, progress: 14, speed: 46.8, lane: -0.48, phase: 2.1 },
  { name: "Loose Wheel", color: COLORS.yellow, progress: -22, speed: 47.6, lane: 0.12, phase: 4.4 },
];

const courseObjects = [];
const objectPattern = [
  [125, -0.48, "boost"],
  [210, 0.32, "oranges"],
  [298, -0.18, "crate"],
  [375, 0.5, "boost"],
  [487, -0.57, "oranges"],
  [556, 0.1, "crate"],
  [650, -0.35, "boost"],
  [742, 0.48, "oranges"],
  [838, -0.05, "crate"],
  [930, 0.57, "boost"],
  [1042, -0.47, "oranges"],
  [1138, 0.22, "crate"],
  [1225, -0.18, "boost"],
];

for (let lap = 0; lap < LAPS; lap += 1) {
  objectPattern.forEach(([distance, lane, type], index) => {
    courseObjects.push({
      distance: lap * TRACK_LENGTH + distance + (lap === 1 ? (index % 2) * 18 : 0),
      lane: lap === 2 ? -lane : lane,
      type,
      collected: false,
    });
  });
}

let width = 0;
let height = 0;
let dpr = 1;
let audioContext = null;
let engineOscillator = null;
let engineGain = null;
let announcementTimer = 0;

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

function roundedRect(x, y, w, h, radius) {
  const r = Math.min(radius, Math.abs(w) / 2, Math.abs(h) / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function curveAt(distance) {
  return (
    Math.sin(distance * 0.0062) * 0.37 +
    Math.sin(distance * 0.014 + 1.4) * 0.13 +
    Math.sin(distance * 0.0021 + 0.8) * 0.2
  );
}

function roadCenterAt(distance, depth) {
  const currentCurve = curveAt(state.distance);
  const aheadCurve = curveAt(distance);
  return width / 2 + (aheadCurve - currentCurve) * width * 0.34 * depth;
}

function projectDistance(relativeDistance, lane = 0) {
  const clamped = Math.max(0, Math.min(VIEW_DISTANCE, relativeDistance));
  const depth = 1 - clamped / VIEW_DISTANCE;
  const horizon = height * 0.205;
  const y = horizon + Math.pow(depth, 1.62) * (height * 0.78);
  const roadHalf = width * (0.075 + depth * 0.39);
  const center = roadCenterAt(state.distance + relativeDistance, depth);
  return {
    x: center + lane * roadHalf * 0.9,
    y,
    depth,
    scale: 0.16 + depth * 1.06,
    roadHalf,
    center,
  };
}

function drawBackground() {
  const horizon = height * 0.205;
  const ceiling = ctx.createLinearGradient(0, 0, 0, horizon);
  ceiling.addColorStop(0, "#22192a");
  ceiling.addColorStop(1, "#4d3b51");
  ctx.fillStyle = ceiling;
  ctx.fillRect(0, 0, width, horizon + 2);

  ctx.fillStyle = "#f0e8d2";
  for (let i = -2; i < 8; i += 1) {
    const x = ((i * width * 0.22 - state.distance * 0.55) % (width * 1.75)) - width * 0.1;
    ctx.globalAlpha = 0.68;
    roundedRect(x, horizon * 0.38, width * 0.13, 5, 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;

  ctx.strokeStyle = "rgba(255,255,255,.08)";
  ctx.lineWidth = 1;
  for (let i = 0; i <= 8; i += 1) {
    ctx.beginPath();
    ctx.moveTo((i / 8) * width, 0);
    ctx.lineTo(width / 2 + (i - 4) * width * 0.045, horizon);
    ctx.stroke();
  }

  const backWall = ctx.createLinearGradient(0, horizon * 0.72, 0, horizon * 1.18);
  backWall.addColorStop(0, "#6c5368");
  backWall.addColorStop(1, "#32273a");
  ctx.fillStyle = backWall;
  ctx.fillRect(0, horizon * 0.72, width, horizon * 0.5);

  ctx.fillStyle = COLORS.yellow;
  roundedRect(width / 2 - 54, horizon * 0.79, 108, 25, 4);
  ctx.fill();
  ctx.fillStyle = COLORS.ink;
  ctx.font = `800 ${Math.max(8, width * 0.008)}px "DM Sans"`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("HOUSEHOLD  •  AISLE 9", width / 2, horizon * 0.79 + 13);
}

function drawFloor() {
  const horizon = height * 0.205;
  const floorGradient = ctx.createLinearGradient(0, horizon, 0, height);
  floorGradient.addColorStop(0, "#8d887e");
  floorGradient.addColorStop(0.48, "#b7b1a5");
  floorGradient.addColorStop(1, "#cec8b9");
  ctx.fillStyle = floorGradient;
  ctx.fillRect(0, horizon, width, height - horizon);

  const segmentOffset = state.distance % 20;
  for (let relative = VIEW_DISTANCE + segmentOffset; relative > 0; relative -= 20) {
    const far = projectDistance(relative);
    const near = projectDistance(Math.max(0, relative - 20));
    const stripe = Math.floor((state.distance + relative) / 20);
    ctx.fillStyle = stripe % 2 ? "rgba(255,255,255,.035)" : "rgba(40,30,40,.035)";
    ctx.beginPath();
    ctx.moveTo(far.center - far.roadHalf, far.y);
    ctx.lineTo(far.center + far.roadHalf, far.y);
    ctx.lineTo(near.center + near.roadHalf, near.y);
    ctx.lineTo(near.center - near.roadHalf, near.y);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "rgba(65,55,65,.14)";
    ctx.lineWidth = Math.max(0.5, near.depth * 1.5);
    ctx.beginPath();
    ctx.moveTo(far.center - far.roadHalf, far.y);
    ctx.lineTo(far.center + far.roadHalf, far.y);
    ctx.stroke();
  }

  [-0.33, 0.33].forEach((lane) => {
    ctx.strokeStyle = "rgba(255,255,255,.2)";
    ctx.lineWidth = 1;
    ctx.setLineDash([10, 15]);
    ctx.beginPath();
    for (let relative = VIEW_DISTANCE; relative >= 0; relative -= 5) {
      const point = projectDistance(relative, lane);
      if (relative === VIEW_DISTANCE) ctx.moveTo(point.x, point.y);
      else ctx.lineTo(point.x, point.y);
    }
    ctx.stroke();
    ctx.setLineDash([]);
  });
}

function drawShelves() {
  const horizon = height * 0.205;
  const shelfTop = height * 0.035;
  const leftInnerBottom = projectDistance(0).center - projectDistance(0).roadHalf;
  const rightInnerBottom = projectDistance(0).center + projectDistance(0).roadHalf;
  const leftInnerHorizon = projectDistance(VIEW_DISTANCE).center - projectDistance(VIEW_DISTANCE).roadHalf;
  const rightInnerHorizon = projectDistance(VIEW_DISTANCE).center + projectDistance(VIEW_DISTANCE).roadHalf;

  ctx.fillStyle = "#39303c";
  ctx.beginPath();
  ctx.moveTo(0, shelfTop);
  ctx.lineTo(leftInnerHorizon, horizon);
  ctx.lineTo(leftInnerBottom, height);
  ctx.lineTo(0, height);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(width, shelfTop);
  ctx.lineTo(rightInnerHorizon, horizon);
  ctx.lineTo(rightInnerBottom, height);
  ctx.lineTo(width, height);
  ctx.closePath();
  ctx.fill();

  const shelfOffset = state.distance % 42;
  for (let relative = VIEW_DISTANCE + shelfOffset; relative > 3; relative -= 42) {
    const point = projectDistance(relative);
    const size = 6 + point.depth * 95;
    drawShelfSlice(point.center - point.roadHalf, point.y, size, -1, relative);
    drawShelfSlice(point.center + point.roadHalf, point.y, size, 1, relative);
  }

  ctx.strokeStyle = "#79717b";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(leftInnerHorizon, horizon);
  ctx.lineTo(leftInnerBottom, height);
  ctx.moveTo(rightInnerHorizon, horizon);
  ctx.lineTo(rightInnerBottom, height);
  ctx.stroke();
}

function drawShelfSlice(x, y, size, side, seed) {
  const shelfWidth = size * 1.22;
  const shelfHeight = size * 1.55;
  const left = side < 0 ? x - shelfWidth : x;
  const top = y - shelfHeight;

  ctx.fillStyle = "#66515d";
  ctx.fillRect(left, top, shelfWidth, shelfHeight);
  ctx.fillStyle = "#9c8c82";
  ctx.fillRect(left, y - size * 0.1, shelfWidth, size * 0.1);
  ctx.fillRect(left, y - size * 0.72, shelfWidth, size * 0.08);
  ctx.fillRect(left, y - size * 1.3, shelfWidth, size * 0.07);

  const palette = [COLORS.orange, COLORS.yellow, COLORS.mint, "#9a71b6", "#e5d1a6"];
  for (let row = 0; row < 2; row += 1) {
    for (let col = 0; col < 3; col += 1) {
      const hash = Math.abs(Math.floor(seed / 10) + row * 5 + col + (side > 0 ? 7 : 0));
      ctx.fillStyle = palette[hash % palette.length];
      const productW = shelfWidth * 0.19;
      const productH = size * (0.24 + (hash % 3) * 0.06);
      ctx.fillRect(left + shelfWidth * (0.11 + col * 0.28), y - size * (0.19 + row * 0.62) - productH, productW, productH);
    }
  }
}

function drawBoostPickup(x, y, scale) {
  const s = 32 * scale;
  ctx.save();
  ctx.translate(x, y - s * 0.5);
  ctx.rotate(Math.sin(performance.now() * 0.004) * 0.12);
  ctx.shadowColor = COLORS.yellow;
  ctx.shadowBlur = 18 * scale;
  ctx.fillStyle = COLORS.yellow;
  roundedRect(-s * 0.34, -s * 0.52, s * 0.68, s * 1.04, s * 0.12);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.fillStyle = COLORS.orange;
  ctx.fillRect(-s * 0.34, -s * 0.2, s * 0.68, s * 0.25);
  ctx.fillStyle = COLORS.ink;
  ctx.font = `900 ${s * 0.48}px "DM Sans"`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("ϟ", 0, 0);
  ctx.fillStyle = "#d8d2c4";
  ctx.fillRect(-s * 0.27, -s * 0.58, s * 0.54, s * 0.08);
  ctx.fillRect(-s * 0.27, s * 0.5, s * 0.54, s * 0.07);
  ctx.restore();
}

function drawHazard(type, x, y, scale) {
  const s = 36 * scale;
  ctx.save();
  ctx.translate(x, y);
  if (type === "crate") {
    ctx.fillStyle = "#9a5c34";
    ctx.fillRect(-s * 0.62, -s * 0.72, s * 1.24, s * 0.72);
    ctx.strokeStyle = "#d39355";
    ctx.lineWidth = Math.max(1, s * 0.09);
    ctx.strokeRect(-s * 0.57, -s * 0.67, s * 1.14, s * 0.62);
    ctx.beginPath();
    ctx.moveTo(-s * 0.53, -s * 0.6);
    ctx.lineTo(s * 0.53, -s * 0.08);
    ctx.moveTo(s * 0.53, -s * 0.6);
    ctx.lineTo(-s * 0.53, -s * 0.08);
    ctx.stroke();
  } else {
    for (let i = 0; i < 5; i += 1) {
      const ox = ((i % 3) - 1) * s * 0.34 + (i > 2 ? s * 0.18 : 0);
      const oy = i > 2 ? -s * 0.31 : -s * 0.1;
      ctx.fillStyle = "#f07a2b";
      ctx.beginPath();
      ctx.arc(ox, oy, s * 0.22, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#47814e";
      ctx.fillRect(ox - s * 0.03, oy - s * 0.25, s * 0.06, s * 0.08);
    }
  }
  ctx.restore();
}

function drawCart(x, y, scale, color, tilt = 0, isPlayer = false) {
  const s = (isPlayer ? 76 : 52) * scale;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(tilt);

  ctx.fillStyle = "rgba(20,15,25,.28)";
  ctx.beginPath();
  ctx.ellipse(0, s * 0.05, s * 0.65, s * 0.16, 0, 0, Math.PI * 2);
  ctx.fill();

  if (isPlayer && state.boostTimer > 0) {
    const flame = 0.65 + Math.random() * 0.5;
    ctx.fillStyle = COLORS.yellow;
    ctx.beginPath();
    ctx.moveTo(-s * 0.35, s * 0.04);
    ctx.lineTo(-s * 0.52, s * flame);
    ctx.lineTo(-s * 0.2, s * 0.12);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(s * 0.35, s * 0.04);
    ctx.lineTo(s * 0.52, s * flame);
    ctx.lineTo(s * 0.2, s * 0.12);
    ctx.fill();
  }

  ctx.fillStyle = "#222027";
  ctx.beginPath();
  ctx.arc(-s * 0.38, s * 0.03, s * 0.13, 0, Math.PI * 2);
  ctx.arc(s * 0.38, s * 0.03, s * 0.13, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = "#d2d3ce";
  ctx.lineWidth = Math.max(1.2, s * 0.055);
  ctx.lineJoin = "round";
  ctx.beginPath();
  ctx.moveTo(-s * 0.48, -s * 0.82);
  ctx.lineTo(-s * 0.37, -s * 0.11);
  ctx.lineTo(s * 0.43, -s * 0.11);
  ctx.lineTo(s * 0.56, -s * 0.73);
  ctx.stroke();

  ctx.fillStyle = color;
  ctx.globalAlpha = 0.94;
  ctx.beginPath();
  ctx.moveTo(-s * 0.47, -s * 0.83);
  ctx.lineTo(s * 0.5, -s * 0.73);
  ctx.lineTo(s * 0.38, -s * 0.25);
  ctx.lineTo(-s * 0.37, -s * 0.25);
  ctx.closePath();
  ctx.fill();
  ctx.globalAlpha = 1;

  ctx.strokeStyle = "rgba(247,240,220,.72)";
  ctx.lineWidth = Math.max(0.8, s * 0.018);
  for (let i = -2; i <= 2; i += 1) {
    ctx.beginPath();
    ctx.moveTo(i * s * 0.15, -s * 0.77);
    ctx.lineTo(i * s * 0.12, -s * 0.27);
    ctx.stroke();
  }
  for (let i = 0; i < 3; i += 1) {
    const yy = -s * (0.65 - i * 0.14);
    ctx.beginPath();
    ctx.moveTo(-s * 0.43, yy);
    ctx.lineTo(s * 0.45, yy + s * 0.05);
    ctx.stroke();
  }

  ctx.strokeStyle = "#e1e1dc";
  ctx.lineWidth = Math.max(1.5, s * 0.07);
  ctx.beginPath();
  ctx.moveTo(-s * 0.46, -s * 0.85);
  ctx.lineTo(s * 0.61, -s * 0.74);
  ctx.stroke();

  ctx.fillStyle = COLORS.orange;
  roundedRect(-s * 0.33, -s * 0.95, s * 0.5, s * 0.13, s * 0.05);
  ctx.fill();

  if (isPlayer) {
    ctx.fillStyle = COLORS.yellow;
    ctx.fillRect(-s * 0.12, -s * 0.74, s * 0.23, s * 0.22);
    ctx.fillStyle = COLORS.purple;
    ctx.fillRect(-s * 0.1, -s * 0.72, s * 0.19, s * 0.08);
  }
  ctx.restore();
}

function drawWorldObjects() {
  const visible = [];
  courseObjects.forEach((object) => {
    const relative = object.distance - state.distance;
    if (!object.collected && relative > -6 && relative < VIEW_DISTANCE) {
      visible.push({ kind: "object", relative, data: object });
    }
  });

  opponents.forEach((opponent) => {
    const relative = opponent.progress - state.distance;
    if (relative > -10 && relative < VIEW_DISTANCE) {
      visible.push({ kind: "opponent", relative, data: opponent });
    }
  });

  visible.sort((a, b) => b.relative - a.relative);
  visible.forEach(({ kind, relative, data }) => {
    const animatedLane = kind === "opponent"
      ? data.lane + Math.sin(state.elapsed * 0.9 + data.phase) * 0.08
      : data.lane;
    const point = projectDistance(Math.max(0, relative), animatedLane);
    if (kind === "opponent") {
      drawCart(point.x, point.y, point.scale * 0.72, data.color, Math.sin(state.elapsed * 1.3 + data.phase) * 0.05);
    } else if (data.type === "boost") {
      drawBoostPickup(point.x, point.y, point.scale);
    } else {
      drawHazard(data.type, point.x, point.y, point.scale);
    }
  });
}

function drawPlayer() {
  const near = projectDistance(0);
  const x = near.center + state.x * near.roadHalf * 0.7;
  const y = height * 0.86;
  const tilt = -state.xVelocity * 0.1 + (controls.drift ? -Math.sign(state.xVelocity || 1) * 0.11 : 0);
  drawCart(x, y, Math.max(0.8, Math.min(1.15, height / 650)), COLORS.purple, tilt, true);

  if (controls.drift && Math.abs(state.xVelocity) > 0.25) {
    ctx.strokeStyle = "rgba(247,240,220,.42)";
    ctx.lineWidth = 2;
    const offset = 30 * Math.max(0.8, height / 650);
    ctx.beginPath();
    ctx.moveTo(x - offset, y + 3);
    ctx.quadraticCurveTo(x - offset * 1.3, y + 28, x - offset * 1.7, y + 48);
    ctx.moveTo(x + offset, y + 3);
    ctx.quadraticCurveTo(x + offset * 1.1, y + 28, x + offset * 1.5, y + 48);
    ctx.stroke();
  }
}

function drawVignette() {
  const gradient = ctx.createRadialGradient(width / 2, height * 0.46, height * 0.15, width / 2, height * 0.5, width * 0.65);
  gradient.addColorStop(0.52, "rgba(20,15,25,0)");
  gradient.addColorStop(1, "rgba(15,10,18,.46)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  if (state.boostTimer > 0) {
    ctx.strokeStyle = `rgba(255,217,61,${0.09 + Math.random() * 0.12})`;
    ctx.lineWidth = 2;
    for (let i = 0; i < 14; i += 1) {
      const y = Math.random() * height;
      const x = Math.random() > 0.5 ? Math.random() * width * 0.18 : width * (0.82 + Math.random() * 0.18);
      const dir = x < width / 2 ? 1 : -1;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + dir * (30 + Math.random() * 70), y - 10);
      ctx.stroke();
    }
  }

  if (state.flash > 0) {
    ctx.fillStyle = `rgba(255,255,255,${state.flash * 0.22})`;
    ctx.fillRect(0, 0, width, height);
  }
}

function render() {
  ctx.save();
  if (state.shake > 0) {
    ctx.translate((Math.random() - 0.5) * state.shake, (Math.random() - 0.5) * state.shake);
  }
  drawBackground();
  drawFloor();
  drawShelves();
  drawWorldObjects();
  drawPlayer();
  drawVignette();
  ctx.restore();
}

function ordinalSuffix(number) {
  if (number === 1) return "st";
  if (number === 2) return "nd";
  if (number === 3) return "rd";
  return "th";
}

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  const hundredths = Math.floor((seconds % 1) * 100);
  return `${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${String(hundredths).padStart(2, "0")}`;
}

function updateHud() {
  const lap = Math.min(LAPS, Math.floor(state.distance / TRACK_LENGTH) + 1);
  const lapDistance = state.distance % TRACK_LENGTH;
  ui.position.textContent = state.position;
  ui.suffix.textContent = ordinalSuffix(state.position);
  ui.lap.textContent = `Lap ${lap} / ${LAPS}`;
  ui.lapProgress.style.width = `${Math.max(2, (lapDistance / TRACK_LENGTH) * 100)}%`;
  ui.speed.textContent = Math.round(state.displaySpeed);
  ui.speedRing.style.setProperty("--speed-angle", `${Math.min(278, state.displaySpeed * 3.75)}deg`);
  ui.boostCount.textContent = state.boost;
  ui.boostButton.classList.toggle("empty", state.boost <= 0);

  const nearest = opponents
    .map((opponent) => ({ opponent, difference: opponent.progress - state.distance }))
    .filter(({ difference }) => difference > 0)
    .sort((a, b) => a.difference - b.difference)[0];

  if (nearest && nearest.difference < 110) {
    ui.rivalTag.style.opacity = "1";
    ui.rivalName.textContent = nearest.opponent.name;
    ui.rivalDistance.textContent = `+${Math.round(nearest.difference)}m`;
    const point = projectDistance(nearest.difference, nearest.opponent.lane);
    ui.rivalTag.style.left = `${Math.min(width - 110, Math.max(20, point.x + 18))}px`;
    ui.rivalTag.style.top = `${Math.max(80, point.y - 65)}px`;
  } else {
    ui.rivalTag.style.opacity = "0";
  }
}

function showAnnouncement(text, duration = 900) {
  clearTimeout(announcementTimer);
  ui.announcement.textContent = text;
  ui.announcement.classList.add("show");
  announcementTimer = setTimeout(() => ui.announcement.classList.remove("show"), duration);
}

function pulseSound(frequency, duration = 0.1, type = "square", volume = 0.06) {
  if (!audioContext) return;
  const oscillator = audioContext.createOscillator();
  const gain = audioContext.createGain();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, audioContext.currentTime);
  gain.gain.setValueAtTime(volume, audioContext.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + duration);
  oscillator.connect(gain).connect(audioContext.destination);
  oscillator.start();
  oscillator.stop(audioContext.currentTime + duration);
}

function startAudio() {
  if (!audioContext) {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    audioContext = new AudioCtx();
    engineOscillator = audioContext.createOscillator();
    engineGain = audioContext.createGain();
    engineOscillator.type = "sawtooth";
    engineOscillator.frequency.value = 45;
    engineGain.gain.value = 0.012;
    engineOscillator.connect(engineGain).connect(audioContext.destination);
    engineOscillator.start();
  }
  if (audioContext.state === "suspended") audioContext.resume();
}

function vibrate(pattern) {
  if ("vibrate" in navigator) navigator.vibrate(pattern);
}

function resetRace() {
  state.distance = 0;
  state.speed = 0;
  state.displaySpeed = 0;
  state.x = 0;
  state.xVelocity = 0;
  state.boost = 3;
  state.boostTimer = 0;
  state.driftCharge = 0;
  state.elapsed = 0;
  state.position = 3;
  state.shake = 0;
  state.flash = 0;
  opponents[0].progress = 35;
  opponents[1].progress = 14;
  opponents[2].progress = -22;
  courseObjects.forEach((object) => { object.collected = false; });
}

function beginRace() {
  startAudio();
  resetRace();
  state.mode = "countdown";
  state.countdown = 3.25;
  game.classList.add("is-running");
  [ui.startScreen, ui.pauseScreen, ui.finishScreen, ui.howScreen].forEach((screen) => screen.classList.add("hidden"));
  showAnnouncement("3", 650);
  pulseSound(280);
}

function setPaused(paused) {
  if (paused && (state.mode === "racing" || state.mode === "countdown")) {
    state.mode = "paused";
    ui.pauseScreen.classList.remove("hidden");
    if (audioContext) audioContext.suspend();
  } else if (!paused && state.mode === "paused") {
    state.mode = "racing";
    ui.pauseScreen.classList.add("hidden");
    if (audioContext) audioContext.resume();
  }
}

function useBoost() {
  if (state.mode !== "racing" || state.boost <= 0 || state.boostTimer > 0.25) return;
  state.boost -= 1;
  state.boostTimer = 1.6;
  state.flash = 0.8;
  state.shake = 7;
  pulseSound(130, 0.35, "sawtooth", 0.09);
  vibrate([25, 25, 45]);
  showAnnouncement("Turbo!", 700);
}

function collect(object) {
  object.collected = true;
  if (object.type === "boost") {
    state.boost = Math.min(5, state.boost + 1);
    state.flash = 0.55;
    pulseSound(740, 0.12, "square", 0.07);
    setTimeout(() => pulseSound(980, 0.13, "square", 0.05), 70);
    vibrate(20);
    showAnnouncement("+ Boost", 650);
  } else {
    state.speed *= 0.48;
    state.shake = 13;
    pulseSound(95, 0.28, "sawtooth", 0.1);
    vibrate([50, 30, 80]);
    showAnnouncement("Spill!", 650);
  }
}

function finishRace() {
  state.mode = "finished";
  state.speed = 0;
  game.classList.remove("is-running");
  ui.finishPosition.textContent = `${state.position}${ordinalSuffix(state.position)}`;
  ui.finishTitle.textContent = state.position === 1 ? "Aisle royalty!" : state.position <= 3 ? "Podium produce!" : "Cart comeback?";
  ui.finishStats.textContent = `3 laps · ${formatTime(state.elapsed)}`;
  ui.finishScreen.classList.remove("hidden");
  pulseSound(state.position === 1 ? 660 : 440, 0.5, "square", 0.08);
  vibrate([80, 50, 80]);
}

function updateCountdown(delta) {
  const previous = Math.ceil(state.countdown);
  state.countdown -= delta;
  const current = Math.ceil(state.countdown);
  if (current !== previous && current > 0) {
    showAnnouncement(String(current), 650);
    pulseSound(280 + (3 - current) * 70);
  }
  if (state.countdown <= 0) {
    state.mode = "racing";
    state.speed = 34;
    showAnnouncement("Go!", 800);
    pulseSound(620, 0.22, "square", 0.08);
    vibrate(35);
  }
}

function updateRace(delta) {
  state.elapsed += delta;
  const steer = (controls.right ? 1 : 0) - (controls.left ? 1 : 0);
  const driftMultiplier = controls.drift ? 1.45 : 1;
  const acceleration = state.boostTimer > 0 ? 56 : 32;
  const targetSpeed = state.boostTimer > 0 ? 78 : controls.drift ? 47 : 54;

  state.speed += Math.sign(targetSpeed - state.speed) * Math.min(Math.abs(targetSpeed - state.speed), acceleration * delta);
  state.displaySpeed += (state.speed - state.displaySpeed) * Math.min(1, delta * 7);
  state.xVelocity += steer * delta * 3.9 * driftMultiplier;
  state.xVelocity *= Math.pow(controls.drift ? 0.25 : 0.08, delta);
  state.x += state.xVelocity * delta;

  if (Math.abs(state.x) > 0.93) {
    state.x = Math.sign(state.x) * 0.93;
    state.xVelocity *= -0.25;
    state.speed = Math.max(28, state.speed - 14 * delta);
    state.shake = Math.max(state.shake, 2.5);
  }

  if (controls.drift && Math.abs(steer) > 0) {
    state.driftCharge = Math.min(1, state.driftCharge + delta * 0.55);
  } else if (state.driftCharge > 0) {
    if (state.driftCharge > 0.38 && state.boost < 5) {
      state.boost += 1;
      showAnnouncement("Drift boost!", 700);
      pulseSound(550, 0.13, "triangle", 0.06);
    }
    state.driftCharge = 0;
  }

  state.distance += state.speed * delta;
  state.boostTimer = Math.max(0, state.boostTimer - delta);
  state.shake = Math.max(0, state.shake - delta * 22);
  state.flash = Math.max(0, state.flash - delta * 2.5);

  courseObjects.forEach((object) => {
    const deltaDistance = object.distance - state.distance;
    if (!object.collected && deltaDistance > -4 && deltaDistance < 3.5 && Math.abs(object.lane - state.x) < 0.25) {
      collect(object);
    }
  });

  opponents.forEach((opponent, index) => {
    const variance = Math.sin(state.elapsed * (0.42 + index * 0.07) + opponent.phase) * 2.1;
    opponent.progress += (opponent.speed + variance) * delta;
  });

  state.position = 1 + opponents.filter((opponent) => opponent.progress > state.distance).length;
  if (engineOscillator && audioContext?.state === "running") {
    engineOscillator.frequency.setTargetAtTime(38 + state.displaySpeed * 0.52, audioContext.currentTime, 0.08);
  }

  if (state.distance >= RACE_LENGTH) finishRace();
}

function update(delta) {
  if (state.mode === "countdown") updateCountdown(delta);
  if (state.mode === "racing") updateRace(delta);
  if (state.mode !== "racing") {
    state.distance += state.mode === "menu" ? delta * 9 : 0;
    state.shake = Math.max(0, state.shake - delta * 20);
    state.flash = Math.max(0, state.flash - delta * 2);
  }
  updateHud();
}

function frame(time) {
  const delta = Math.min(0.05, Math.max(0, (time - state.lastTime) / 1000));
  state.lastTime = time;
  update(delta);
  render();
  requestAnimationFrame(frame);
}

function bindHoldControl(button) {
  const control = button.dataset.control;
  const activate = (event) => {
    event.preventDefault();
    if (control === "boost") {
      useBoost();
      button.classList.add("active");
      return;
    }
    controls[control] = true;
    button.classList.add("active");
    button.setPointerCapture?.(event.pointerId);
  };
  const deactivate = (event) => {
    event.preventDefault();
    if (control !== "boost") controls[control] = false;
    button.classList.remove("active");
  };
  button.addEventListener("pointerdown", activate);
  button.addEventListener("pointerup", deactivate);
  button.addEventListener("pointercancel", deactivate);
  button.addEventListener("lostpointercapture", deactivate);
}

document.querySelectorAll("[data-control]").forEach(bindHoldControl);
document.querySelector("#startButton").addEventListener("click", beginRace);
document.querySelector("#raceAgainButton").addEventListener("click", beginRace);
document.querySelector("#pauseButton").addEventListener("click", () => setPaused(true));
document.querySelector("#resumeButton").addEventListener("click", () => setPaused(false));
document.querySelector("#restartButton").addEventListener("click", beginRace);
document.querySelector("#howButton").addEventListener("click", () => ui.howScreen.classList.remove("hidden"));

document.querySelectorAll("[data-close]").forEach((button) => {
  button.addEventListener("click", () => document.querySelector(`#${button.dataset.close}`).classList.add("hidden"));
});

window.addEventListener("keydown", (event) => {
  const key = event.key.toLowerCase();
  if (["arrowleft", "arrowright", "a", "d", " ", "b"].includes(key)) event.preventDefault();
  if (key === "arrowleft" || key === "a") controls.left = true;
  if (key === "arrowright" || key === "d") controls.right = true;
  if (key === " ") controls.drift = true;
  if (key === "b") useBoost();
  if (key === "escape") setPaused(state.mode !== "paused");
});

window.addEventListener("keyup", (event) => {
  const key = event.key.toLowerCase();
  if (key === "arrowleft" || key === "a") controls.left = false;
  if (key === "arrowright" || key === "d") controls.right = false;
  if (key === " ") controls.drift = false;
});

window.addEventListener("resize", resize);
document.addEventListener("visibilitychange", () => {
  if (document.hidden && (state.mode === "racing" || state.mode === "countdown")) setPaused(true);
});

resize();
updateHud();
requestAnimationFrame(frame);
