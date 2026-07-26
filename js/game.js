import {
  TAU,
  calculatePosition,
  clamp,
  createTrack,
  formatTime,
  nearestTrackPoint,
  ordinal,
  seededRandom,
  shortestAngle,
  trackPointAt,
} from "./game-core.js";

const canvas = document.querySelector("#game");
const context = canvas.getContext("2d", { alpha: false });
const elements = {
  startScreen: document.querySelector("#start-screen"),
  finishScreen: document.querySelector("#finish-screen"),
  startButton: document.querySelector("#start-button"),
  restartButton: document.querySelector("#restart-button"),
  soundToggle: document.querySelector("#sound-toggle"),
  left: document.querySelector("#left-control"),
  right: document.querySelector("#right-control"),
  action: document.querySelector("#action-control"),
  actionIcon: document.querySelector("#action-icon"),
  countdown: document.querySelector("#countdown"),
  position: document.querySelector("#position"),
  lap: document.querySelector("#lap"),
  itemSlot: document.querySelector(".item-slot"),
  itemName: document.querySelector("#item-name"),
  itemIcon: document.querySelector("#item-icon"),
  finishTitle: document.querySelector("#finish-title"),
  finishResult: document.querySelector("#finish-result"),
  finishTime: document.querySelector("#finish-time"),
  bestLap: document.querySelector("#best-lap"),
};

const COLORS = {
  ink: "#151b33",
  paper: "#fff9e9",
  orange: "#ff6b35",
  yellow: "#ffd23f",
  mint: "#63e6be",
  blue: "#4dabf7",
  purple: "#9b5de5",
  red: "#f03e3e",
};
const TRACK_WIDTH = 350;
const TOTAL_LAPS = 3;
const track = createTrack();
const random = seededRandom(4921);
const keys = { left: false, right: false };
const powerUps = [
  { name: "HOT COFFEE", icon: "☕", kind: "boost" },
  { name: "WARM SHIELD", icon: "🛡", kind: "shield" },
  { name: "BELL BLAST", icon: "🔔", kind: "bell" },
];
const racerProfiles = [
  { name: "MAYA", color: COLORS.orange, accent: COLORS.yellow, lane: -52, pace: 0.98 },
  { name: "SOL", color: COLORS.blue, accent: "#d0ebff", lane: 58, pace: 0.95 },
  { name: "DEE", color: COLORS.purple, accent: "#e5dbff", lane: -96, pace: 0.92 },
  { name: "OTIS", color: COLORS.mint, accent: "#c3fae8", lane: 96, pace: 0.9 },
  { name: "RUE", color: COLORS.red, accent: "#ffc9c9", lane: 5, pace: 0.87 },
];
const shelves = [
  { x: 610, y: 500, w: 360, h: 130, label: "PANTRY", color: COLORS.orange },
  { x: 1060, y: 500, w: 360, h: 130, label: "HOME", color: COLORS.blue },
  { x: 1510, y: 500, w: 320, h: 130, label: "FRESH", color: COLORS.mint },
  { x: 610, y: 820, w: 360, h: 130, label: "BAKERY", color: COLORS.yellow },
  { x: 1060, y: 820, w: 360, h: 130, label: "CARE", color: COLORS.purple },
  { x: 1510, y: 820, w: 320, h: 130, label: "WARMTH", color: COLORS.red },
];
const pickups = Array.from({ length: 9 }, (_, index) => ({
  progress: 0.075 + index * 0.108,
  lane: [-90, 0, 90][index % 3],
  active: true,
  respawnAt: 0,
  spin: random() * TAU,
}));
const particles = [];

let width = window.innerWidth;
let height = window.innerHeight;
let dpr = 1;
let previousTime = performance.now();
let gameMode = "idle";
let countdownStartedAt = 0;
let countdownStep = -1;
let raceStartedAt = 0;
let finishTime = 0;
let lapStartedAt = 0;
let lapTimes = [];
let soundEnabled = true;
let audioContext = null;
let shake = 0;

const player = {
  x: 0,
  y: 0,
  angle: 0,
  speed: 0,
  trackIndex: 0,
  progress: 0,
  previousProgress: 0,
  lap: 0,
  totalProgress: 0,
  item: null,
  boostTimer: 0,
  shieldTimer: 0,
};
let rivals = [];

function resize() {
  width = window.innerWidth;
  height = window.innerHeight;
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(width * dpr);
  canvas.height = Math.round(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  context.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function resetRace() {
  const start = trackPointAt(track, 0.012, 0);
  Object.assign(player, {
    x: start.x,
    y: start.y,
    angle: start.angle,
    speed: 0,
    trackIndex: Math.floor(track.points.length * 0.012),
    progress: 0.012,
    previousProgress: 0.012,
    lap: 0,
    totalProgress: 0.012,
    item: null,
    boostTimer: 0,
    shieldTimer: 0,
  });
  rivals = racerProfiles.map((profile, index) => ({
    ...profile,
    distance: -58 * (index + 1),
    totalProgress: (-58 * (index + 1)) / track.length,
    speed: 305 * profile.pace,
    targetLane: profile.lane,
    laneShiftAt: 2 + random() * 4,
    slowedTimer: 0,
  }));
  pickups.forEach((pickup) => {
    pickup.active = true;
    pickup.respawnAt = 0;
  });
  particles.length = 0;
  lapTimes = [];
  updateItemHud();
}

function beginCountdown() {
  ensureAudio();
  resetRace();
  elements.startScreen.classList.remove("show");
  elements.finishScreen.classList.remove("show");
  countdownStartedAt = performance.now();
  countdownStep = -1;
  gameMode = "countdown";
  playTone(220, 0.08, "square", 0.06);
}

function updateCountdown(now) {
  const elapsed = now - countdownStartedAt;
  const step = Math.floor(elapsed / 760);
  if (step !== countdownStep && step <= 3) {
    countdownStep = step;
    const labels = ["3", "2", "1", "GO!"];
    elements.countdown.textContent = labels[step];
    elements.countdown.classList.remove("pop");
    void elements.countdown.offsetWidth;
    elements.countdown.classList.add("pop");
    playTone(step === 3 ? 620 : 300 + step * 80, step === 3 ? 0.24 : 0.1, "square", 0.08);
  }
  if (elapsed >= 3040) {
    gameMode = "racing";
    raceStartedAt = now;
    lapStartedAt = now;
  }
}

function inputDirection() {
  return (keys.right ? 1 : 0) - (keys.left ? 1 : 0);
}

function updatePlayer(delta, now) {
  if (gameMode !== "racing") {
    player.speed *= Math.pow(0.01, delta);
    return;
  }

  player.boostTimer = Math.max(0, player.boostTimer - delta);
  player.shieldTimer = Math.max(0, player.shieldTimer - delta);
  const direction = inputDirection();
  const boostMultiplier = player.boostTimer > 0 ? 1.42 : 1;
  const targetSpeed = 385 * boostMultiplier;
  player.speed += (targetSpeed - player.speed) * Math.min(1, delta * 1.7);
  const steeringGrip = clamp(player.speed / 250, 0.45, 1);
  player.angle += direction * 2.25 * steeringGrip * delta;
  player.x += Math.cos(player.angle) * player.speed * delta;
  player.y += Math.sin(player.angle) * player.speed * delta;

  const nearest = nearestTrackPoint(track, player.x, player.y, player.trackIndex);
  player.trackIndex = nearest.index;
  player.progress = nearest.progress;
  const alignment = shortestAngle(player.angle, nearest.point.angle);

  if (!direction) player.angle += alignment * Math.min(1, delta * 0.75);
  if (nearest.distance > TRACK_WIDTH * 0.39) {
    player.speed *= Math.pow(0.22, delta);
    const pull = Math.min(1, delta * 2.6);
    player.x += (nearest.point.x - player.x) * pull;
    player.y += (nearest.point.y - player.y) * pull;
    createDust(player.x, player.y, "#c4bea9", 1);
  }

  if (player.previousProgress > 0.83 && player.progress < 0.17) {
    player.lap += 1;
    const lapTime = now - lapStartedAt;
    if (player.lap > 0) lapTimes.push(lapTime);
    lapStartedAt = now;
    if (player.lap >= TOTAL_LAPS) finishRace(now);
    else {
      playJingle();
      announce(`LAP ${player.lap + 1}`);
    }
  } else if (player.previousProgress < 0.17 && player.progress > 0.83 && player.lap > 0) {
    player.lap -= 1;
  }
  player.previousProgress = player.progress;
  player.totalProgress = player.lap + player.progress;

  for (const rival of rivals) {
    const rivalPoint = trackPointAt(track, rival.distance / track.length, rival.targetLane);
    const distance = Math.hypot(player.x - rivalPoint.x, player.y - rivalPoint.y);
    if (distance < 57 && player.shieldTimer <= 0) {
      player.speed *= 0.72;
      player.x -= Math.cos(player.angle) * 12;
      player.y -= Math.sin(player.angle) * 12;
      shake = Math.max(shake, 7);
      createBurst((player.x + rivalPoint.x) / 2, (player.y + rivalPoint.y) / 2, COLORS.yellow, 7);
      playTone(95, 0.09, "sawtooth", 0.07);
    }
  }

  for (const pickup of pickups) {
    if (!pickup.active) {
      if (now >= pickup.respawnAt) pickup.active = true;
      continue;
    }
    const pickupPoint = trackPointAt(track, pickup.progress, pickup.lane);
    if (Math.hypot(player.x - pickupPoint.x, player.y - pickupPoint.y) < 56) {
      pickup.active = false;
      pickup.respawnAt = now + 7500;
      player.item = powerUps[Math.floor(random() * powerUps.length)];
      createBurst(pickupPoint.x, pickupPoint.y, COLORS.yellow, 14);
      playArpeggio();
      updateItemHud();
    }
  }
}

function updateRivals(delta, raceSeconds) {
  if (gameMode !== "racing") return;
  rivals.forEach((rival, index) => {
    rival.slowedTimer = Math.max(0, rival.slowedTimer - delta);
    const rubberBand = clamp((player.totalProgress - rival.totalProgress) * 0.1, -0.08, 0.1);
    const lapVariation = Math.sin(raceSeconds * 0.7 + index * 1.8) * 0.035;
    const speedFactor = rival.slowedTimer > 0 ? 0.52 : 1;
    rival.distance += rival.speed * (1 + rubberBand + lapVariation) * speedFactor * delta;
    rival.totalProgress = rival.distance / track.length;
    if (raceSeconds > rival.laneShiftAt) {
      rival.targetLane = clamp(rival.lane + (random() - 0.5) * 90, -115, 115);
      rival.laneShiftAt = raceSeconds + 3 + random() * 5;
    }
  });
}

function useItem() {
  if (gameMode !== "racing" || !player.item) return;
  const item = player.item;
  player.item = null;
  if (item.kind === "boost") {
    player.boostTimer = 2;
    createBurst(player.x, player.y, COLORS.orange, 18);
    playSweep(180, 650, 0.35);
  } else if (item.kind === "shield") {
    player.shieldTimer = 4;
    createBurst(player.x, player.y, COLORS.blue, 16);
    playSweep(500, 850, 0.22);
  } else {
    rivals.forEach((rival) => {
      if (Math.abs(rival.totalProgress - player.totalProgress) < 0.16) rival.slowedTimer = 1.8;
    });
    createBurst(player.x, player.y, COLORS.yellow, 28);
    shake = 8;
    playTone(740, 0.35, "sine", 0.12);
  }
  updateItemHud();
}

function finishRace(now) {
  if (gameMode === "finished") return;
  gameMode = "finished";
  finishTime = now - raceStartedAt;
  player.speed *= 0.6;
  const position = calculatePosition(player.totalProgress, rivals);
  const title = position === 1 ? "AISLE LEGEND!" : position <= 3 ? "PODIUM POWER!" : "CART CREW!";
  elements.finishTitle.textContent = title;
  elements.finishResult.textContent = `You placed ${ordinal(position)} in the Community Cup`;
  elements.finishTime.textContent = formatTime(finishTime);
  elements.bestLap.textContent = formatTime(Math.min(...lapTimes));
  setTimeout(() => elements.finishScreen.classList.add("show"), 650);
  playJingle(true);
}

function updateParticles(delta) {
  for (let index = particles.length - 1; index >= 0; index -= 1) {
    const particle = particles[index];
    particle.life -= delta;
    if (particle.life <= 0) {
      particles.splice(index, 1);
      continue;
    }
    particle.x += particle.vx * delta;
    particle.y += particle.vy * delta;
    particle.vx *= Math.pow(0.12, delta);
    particle.vy *= Math.pow(0.12, delta);
    particle.rotation += particle.spin * delta;
  }
}

function createBurst(x, y, color, count) {
  for (let index = 0; index < count; index += 1) {
    const angle = random() * TAU;
    const force = 70 + random() * 180;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * force,
      vy: Math.sin(angle) * force,
      color,
      size: 3 + random() * 7,
      life: 0.45 + random() * 0.5,
      maxLife: 1,
      rotation: random() * TAU,
      spin: (random() - 0.5) * 9,
    });
  }
}

function createDust(x, y, color, count) {
  if (random() > 0.45) return;
  for (let index = 0; index < count; index += 1) {
    particles.push({
      x: x - Math.cos(player.angle) * 30 + (random() - 0.5) * 25,
      y: y - Math.sin(player.angle) * 30 + (random() - 0.5) * 25,
      vx: (random() - 0.5) * 25,
      vy: (random() - 0.5) * 25,
      color,
      size: 7 + random() * 8,
      life: 0.4 + random() * 0.4,
      maxLife: 1,
      rotation: 0,
      spin: 0,
    });
  }
}

function roundedRect(ctx, x, y, w, h, radius) {
  const r = Math.min(radius, w / 2, h / 2);
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function drawStore() {
  context.fillStyle = "#d8d6ca";
  context.fillRect(-100, -100, 2600, 1700);

  context.strokeStyle = "rgba(81, 82, 86, 0.08)";
  context.lineWidth = 2;
  for (let x = 0; x <= 2400; x += 80) {
    context.beginPath();
    context.moveTo(x, 0);
    context.lineTo(x, 1500);
    context.stroke();
  }
  for (let y = 0; y <= 1500; y += 80) {
    context.beginPath();
    context.moveTo(0, y);
    context.lineTo(2400, y);
    context.stroke();
  }

  context.strokeStyle = COLORS.ink;
  context.lineWidth = 18;
  roundedRect(context, 10, 10, 2380, 1480, 28);
  context.stroke();

  shelves.forEach(drawShelf);
  drawCheckout(280, 650);
  drawCheckout(1900, 650);
  drawCommunityTable(1100, 1035);
  drawSign(330, 142, "AISLE 9");
  drawSign(1880, 1370, "COMMUNITY NIGHT");
}

function drawShelf(shelf) {
  context.save();
  context.translate(shelf.x, shelf.y);
  context.fillStyle = "rgba(21, 27, 51, 0.14)";
  roundedRect(context, 10, 12, shelf.w, shelf.h, 14);
  context.fill();
  context.fillStyle = "#f4efe0";
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 7;
  roundedRect(context, 0, 0, shelf.w, shelf.h, 14);
  context.fill();
  context.stroke();

  const productColors = [shelf.color, COLORS.paper, COLORS.blue, COLORS.yellow];
  for (let x = 18; x < shelf.w - 18; x += 34) {
    context.fillStyle = productColors[Math.floor(x / 34) % productColors.length];
    roundedRect(context, x, 20, 22, 34, 4);
    context.fill();
    context.strokeStyle = "rgba(21, 27, 51, 0.3)";
    context.lineWidth = 2;
    context.stroke();
    context.fillStyle = productColors[(Math.floor(x / 34) + 2) % productColors.length];
    roundedRect(context, x, 75, 22, 34, 4);
    context.fill();
    context.stroke();
  }

  context.fillStyle = shelf.color;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 4;
  roundedRect(context, shelf.w / 2 - 54, -15, 108, 28, 5);
  context.fill();
  context.stroke();
  context.fillStyle = COLORS.ink;
  context.font = "900 16px 'Barlow Condensed', sans-serif";
  context.textAlign = "center";
  context.fillText(shelf.label, shelf.w / 2, 5);
  context.restore();
}

function drawCheckout(x, y) {
  context.save();
  context.translate(x, y);
  context.fillStyle = COLORS.blue;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 6;
  roundedRect(context, -70, -120, 140, 240, 12);
  context.fill();
  context.stroke();
  context.fillStyle = COLORS.ink;
  for (let offset = -78; offset <= 78; offset += 52) {
    context.fillRect(-55, offset, 110, 9);
  }
  context.fillStyle = COLORS.yellow;
  roundedRect(context, -25, -105, 50, 35, 5);
  context.fill();
  context.stroke();
  context.restore();
}

function drawCommunityTable(x, y) {
  context.save();
  context.translate(x, y);
  context.fillStyle = COLORS.orange;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 6;
  roundedRect(context, -190, -55, 380, 110, 18);
  context.fill();
  context.stroke();
  context.fillStyle = COLORS.paper;
  context.font = "900 25px 'Barlow Condensed', sans-serif";
  context.textAlign = "center";
  context.fillText("OUTREACH FUND", 0, 8);
  context.restore();
}

function drawSign(x, y, text) {
  context.save();
  context.translate(x, y);
  context.rotate(-0.025);
  context.fillStyle = COLORS.yellow;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 5;
  roundedRect(context, -90, -25, 180, 50, 8);
  context.fill();
  context.stroke();
  context.fillStyle = COLORS.ink;
  context.font = "900 22px 'Barlow Condensed', sans-serif";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(text, 0, 1);
  context.restore();
}

function traceTrack() {
  context.beginPath();
  track.points.forEach((point, index) => {
    if (index === 0) context.moveTo(point.x, point.y);
    else context.lineTo(point.x, point.y);
  });
  context.closePath();
}

function drawTrack() {
  context.lineCap = "round";
  context.lineJoin = "round";
  traceTrack();
  context.strokeStyle = COLORS.ink;
  context.lineWidth = TRACK_WIDTH + 24;
  context.stroke();
  traceTrack();
  context.strokeStyle = "#eee8d7";
  context.lineWidth = TRACK_WIDTH;
  context.stroke();
  traceTrack();
  context.strokeStyle = "rgba(21, 27, 51, 0.08)";
  context.lineWidth = 3;
  context.stroke();

  context.strokeStyle = "rgba(21, 27, 51, 0.34)";
  context.lineWidth = 5;
  context.setLineDash([26, 26]);
  traceTrack();
  context.stroke();
  context.setLineDash([]);

  const start = trackPointAt(track, 0.012);
  context.save();
  context.translate(start.x, start.y);
  context.rotate(start.angle);
  const tile = 22;
  for (let row = -8; row < 8; row += 1) {
    for (let column = -1; column <= 1; column += 1) {
      context.fillStyle = (row + column) % 2 ? COLORS.ink : COLORS.paper;
      context.fillRect(column * tile - tile / 2, row * tile, tile, tile);
    }
  }
  context.restore();
}

function drawPickup(pickup, time) {
  if (!pickup.active) return;
  const point = trackPointAt(track, pickup.progress, pickup.lane);
  context.save();
  context.translate(point.x, point.y + Math.sin(time * 4 + pickup.spin) * 5);
  context.rotate(time * 1.7 + pickup.spin);
  context.shadowColor = COLORS.yellow;
  context.shadowBlur = 15;
  context.fillStyle = COLORS.yellow;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 4;
  roundedRect(context, -19, -19, 38, 38, 8);
  context.fill();
  context.stroke();
  context.shadowBlur = 0;
  context.rotate(-(time * 1.7 + pickup.spin));
  context.fillStyle = COLORS.ink;
  context.font = "900 24px 'Barlow Condensed', sans-serif";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText("?", 0, 1);
  context.restore();
}

function drawCart(x, y, angle, profile, isPlayer = false) {
  context.save();
  context.translate(x, y);
  context.rotate(angle);

  if (isPlayer && player.boostTimer > 0) {
    context.fillStyle = COLORS.orange;
    context.beginPath();
    context.moveTo(-44, -13);
    context.lineTo(-72 - random() * 20, 0);
    context.lineTo(-44, 13);
    context.closePath();
    context.fill();
    context.fillStyle = COLORS.yellow;
    context.beginPath();
    context.moveTo(-42, -7);
    context.lineTo(-62 - random() * 13, 0);
    context.lineTo(-42, 7);
    context.closePath();
    context.fill();
  }

  if (isPlayer && player.shieldTimer > 0) {
    context.strokeStyle = `rgba(77, 171, 247, ${0.65 + Math.sin(performance.now() / 90) * 0.2})`;
    context.lineWidth = 7;
    context.beginPath();
    context.arc(0, 0, 51, 0, TAU);
    context.stroke();
  }

  context.fillStyle = "rgba(21, 27, 51, 0.18)";
  context.beginPath();
  context.ellipse(2, 8, 47, 28, 0, 0, TAU);
  context.fill();

  context.fillStyle = COLORS.ink;
  for (const wheel of [
    [-21, -24],
    [-21, 24],
    [27, -24],
    [27, 24],
  ]) {
    context.beginPath();
    context.arc(wheel[0], wheel[1], 7, 0, TAU);
    context.fill();
  }

  context.fillStyle = profile.color;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 5;
  context.beginPath();
  context.moveTo(-20, -27);
  context.lineTo(31, -22);
  context.lineTo(37, 22);
  context.lineTo(-20, 27);
  context.closePath();
  context.fill();
  context.stroke();

  context.strokeStyle = profile.accent;
  context.lineWidth = 3;
  for (let xLine = -7; xLine <= 23; xLine += 15) {
    context.beginPath();
    context.moveTo(xLine, -22);
    context.lineTo(xLine + 4, 22);
    context.stroke();
  }
  for (let yLine = -10; yLine <= 10; yLine += 10) {
    context.beginPath();
    context.moveTo(-17, yLine);
    context.lineTo(34, yLine);
    context.stroke();
  }

  context.fillStyle = profile.accent;
  context.strokeStyle = COLORS.ink;
  context.lineWidth = 4;
  roundedRect(context, -12, -18, 24, 36, 8);
  context.fill();
  context.stroke();

  context.fillStyle = "#9c6644";
  context.beginPath();
  context.arc(-25, 0, 12, 0, TAU);
  context.fill();
  context.stroke();
  context.fillStyle = profile.color;
  context.beginPath();
  context.arc(-28, 0, 13, Math.PI, TAU);
  context.fill();

  context.strokeStyle = COLORS.ink;
  context.lineWidth = 5;
  context.beginPath();
  context.moveTo(-34, -25);
  context.lineTo(-34, 25);
  context.stroke();

  if (isPlayer) {
    context.fillStyle = COLORS.yellow;
    context.strokeStyle = COLORS.ink;
    context.lineWidth = 3;
    context.beginPath();
    context.moveTo(4, -9);
    context.lineTo(8, -2);
    context.lineTo(16, -1);
    context.lineTo(10, 5);
    context.lineTo(12, 13);
    context.lineTo(4, 8);
    context.lineTo(-3, 13);
    context.lineTo(-1, 5);
    context.lineTo(-7, -1);
    context.lineTo(1, -2);
    context.closePath();
    context.fill();
    context.stroke();
  }

  context.restore();
}

function drawRacerName(x, y, name) {
  context.save();
  context.translate(x, y);
  context.fillStyle = "rgba(21, 27, 51, 0.86)";
  roundedRect(context, -25, -48, 50, 19, 5);
  context.fill();
  context.fillStyle = "white";
  context.font = "800 11px 'DM Sans', sans-serif";
  context.textAlign = "center";
  context.fillText(name, 0, -34);
  context.restore();
}

function drawParticles() {
  particles.forEach((particle) => {
    context.save();
    context.globalAlpha = clamp(particle.life / particle.maxLife, 0, 1);
    context.translate(particle.x, particle.y);
    context.rotate(particle.rotation);
    context.fillStyle = particle.color;
    context.fillRect(-particle.size / 2, -particle.size / 2, particle.size, particle.size);
    context.restore();
  });
}

function drawWorld(now) {
  context.setTransform(dpr, 0, 0, dpr, 0, 0);
  context.fillStyle = "#cbc8b9";
  context.fillRect(0, 0, width, height);
  const zoom = clamp(Math.min(width / 1020, height / 560), 0.62, 1.08);
  const shakeX = shake > 0 ? (random() - 0.5) * shake : 0;
  const shakeY = shake > 0 ? (random() - 0.5) * shake : 0;
  shake *= 0.88;

  context.save();
  context.translate(width / 2 + shakeX, height * 0.62 + shakeY);
  context.scale(zoom, zoom);
  context.rotate(-player.angle - Math.PI / 2);
  context.translate(-player.x, -player.y);

  drawStore();
  drawTrack();
  pickups.forEach((pickup) => drawPickup(pickup, now / 1000));

  const visibleRivals = rivals
    .map((rival) => ({ rival, point: trackPointAt(track, rival.distance / track.length, rival.targetLane) }))
    .sort((a, b) => a.point.y - b.point.y);
  visibleRivals.forEach(({ rival, point }) => {
    drawCart(point.x, point.y, point.angle, rival);
    drawRacerName(point.x, point.y, rival.name);
  });

  drawParticles();
  drawCart(player.x, player.y, player.angle, {
    color: COLORS.orange,
    accent: COLORS.yellow,
  }, true);
  context.restore();

  const gradient = context.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, "rgba(21, 27, 51, 0.15)");
  gradient.addColorStop(0.2, "transparent");
  gradient.addColorStop(0.75, "transparent");
  gradient.addColorStop(1, "rgba(21, 27, 51, 0.3)");
  context.fillStyle = gradient;
  context.fillRect(0, 0, width, height);
}

function updateHud() {
  const position = calculatePosition(player.totalProgress, rivals);
  const label = ordinal(position);
  const suffix = label.replace(String(position), "");
  elements.position.innerHTML = `${position}<sup>${suffix}</sup>`;
  elements.lap.textContent = `${Math.min(player.lap + 1, TOTAL_LAPS)}/${TOTAL_LAPS}`;
}

function updateItemHud() {
  const item = player.item;
  elements.itemName.textContent = item ? item.name : "FIND ONE";
  elements.itemIcon.textContent = item ? item.icon : "?";
  elements.actionIcon.textContent = item ? item.icon : "⚡";
  elements.itemSlot.classList.toggle("ready", Boolean(item));
  elements.action.classList.toggle("charged", Boolean(item));
}

function announce(text) {
  elements.countdown.textContent = text;
  elements.countdown.classList.remove("pop");
  void elements.countdown.offsetWidth;
  elements.countdown.classList.add("pop");
}

function frame(now) {
  const delta = Math.min((now - previousTime) / 1000, 0.04);
  previousTime = now;
  if (gameMode === "countdown") updateCountdown(now);
  updatePlayer(delta, now);
  updateRivals(delta, gameMode === "racing" ? (now - raceStartedAt) / 1000 : 0);
  updateParticles(delta);
  drawWorld(now);
  updateHud();
  requestAnimationFrame(frame);
}

function bindHoldButton(element, key) {
  const activate = (event) => {
    event.preventDefault();
    keys[key] = true;
    element.classList.add("pressed");
    element.setPointerCapture?.(event.pointerId);
  };
  const release = (event) => {
    event.preventDefault();
    keys[key] = false;
    element.classList.remove("pressed");
  };
  element.addEventListener("pointerdown", activate);
  element.addEventListener("pointerup", release);
  element.addEventListener("pointercancel", release);
  element.addEventListener("lostpointercapture", release);
}

function ensureAudio() {
  if (!audioContext) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (AudioContext) audioContext = new AudioContext();
  }
  if (audioContext?.state === "suspended") audioContext.resume();
}

function playTone(frequency, duration, type = "sine", volume = 0.05, delay = 0) {
  if (!soundEnabled) return;
  ensureAudio();
  if (!audioContext) return;
  const oscillator = audioContext.createOscillator();
  const gain = audioContext.createGain();
  const start = audioContext.currentTime + delay;
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, start);
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(volume, start + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain).connect(audioContext.destination);
  oscillator.start(start);
  oscillator.stop(start + duration + 0.02);
}

function playSweep(from, to, duration) {
  if (!soundEnabled) return;
  ensureAudio();
  if (!audioContext) return;
  const oscillator = audioContext.createOscillator();
  const gain = audioContext.createGain();
  const now = audioContext.currentTime;
  oscillator.type = "sawtooth";
  oscillator.frequency.setValueAtTime(from, now);
  oscillator.frequency.exponentialRampToValueAtTime(to, now + duration);
  gain.gain.setValueAtTime(0.06, now);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
  oscillator.connect(gain).connect(audioContext.destination);
  oscillator.start(now);
  oscillator.stop(now + duration);
}

function playArpeggio() {
  [440, 554, 659].forEach((note, index) => playTone(note, 0.1, "square", 0.045, index * 0.07));
}

function playJingle(isFinish = false) {
  const notes = isFinish ? [392, 523, 659, 784] : [440, 554, 659];
  notes.forEach((note, index) => playTone(note, 0.16, "square", 0.05, index * 0.1));
}

bindHoldButton(elements.left, "left");
bindHoldButton(elements.right, "right");
elements.action.addEventListener("pointerdown", (event) => {
  event.preventDefault();
  elements.action.classList.add("pressed");
  useItem();
});
elements.action.addEventListener("pointerup", () => elements.action.classList.remove("pressed"));
elements.action.addEventListener("pointercancel", () => elements.action.classList.remove("pressed"));
elements.startButton.addEventListener("click", beginCountdown);
elements.restartButton.addEventListener("click", beginCountdown);
elements.soundToggle.addEventListener("click", () => {
  soundEnabled = !soundEnabled;
  elements.soundToggle.textContent = soundEnabled ? "♪" : "×";
  elements.soundToggle.classList.toggle("muted", !soundEnabled);
  if (soundEnabled) playTone(440, 0.08, "square", 0.04);
});

window.addEventListener("keydown", (event) => {
  if (["ArrowLeft", "KeyA"].includes(event.code)) keys.left = true;
  if (["ArrowRight", "KeyD"].includes(event.code)) keys.right = true;
  if (event.code === "Space") {
    event.preventDefault();
    useItem();
  }
  if (event.code === "Enter" && gameMode === "idle") beginCountdown();
});
window.addEventListener("keyup", (event) => {
  if (["ArrowLeft", "KeyA"].includes(event.code)) keys.left = false;
  if (["ArrowRight", "KeyD"].includes(event.code)) keys.right = false;
});
window.addEventListener("resize", resize);
document.addEventListener("visibilitychange", () => {
  previousTime = performance.now();
  keys.left = false;
  keys.right = false;
});

if ("serviceWorker" in navigator && location.protocol !== "file:") {
  window.addEventListener("load", () => navigator.serviceWorker.register("./sw.js").catch(() => {}));
}

resize();
resetRace();
requestAnimationFrame(frame);
