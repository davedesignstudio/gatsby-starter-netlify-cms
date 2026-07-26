import {
  POWER_UPS,
  RACERS,
  TOTAL_LAPS,
  advanceProgress,
  clamp,
  createRaceState,
  formatTime,
  ordinal,
  updateOpponents,
  updatePlayer,
  usePowerUp,
  wrapProgress,
} from "./game-core.js";

const canvas = document.querySelector("#game");
const ctx = canvas.getContext("2d", { alpha: false });
const $ = (selector) => document.querySelector(selector);
const elements = {
  menu: $("#menu"),
  hud: $("#hud"),
  controls: $("#controls"),
  pause: $("#pause-screen"),
  results: $("#results"),
  position: $("#position"),
  lap: $("#lap"),
  boost: $("#boost-fill"),
  item: $("#item-slot"),
  message: $("#race-message"),
};

let selectedRacer = 0;
let state = null;
let view = "menu";
let previousTime = performance.now();
let audioContext = null;
const input = { left: false, right: false, gas: false };

const CONTROL_POINTS = [
  [-650, 250], [-760, -80], [-600, -410], [-140, -500],
  [260, -390], [650, -470], [780, -100], [480, 110],
  [740, 400], [260, 510], [-90, 310], [-390, 520], [-700, 410],
];

const SHELVES = [
  [-390, -270, 300, 64, "BAKERY", "#f4b855"],
  [-40, -270, 280, 64, "PANTRY", "#eb785d"],
  [310, -230, 280, 64, "SNACKS", "#75c49c"],
  [-445, 120, 250, 62, "FROZEN", "#62a4d8"],
  [-120, 105, 240, 62, "HOME", "#c48cce"],
  [210, 255, 255, 62, "PRODUCE", "#84ba5b"],
  [-20, 670, 350, 65, "CHECKOUT", "#f0c84f"],
];

const ITEM_POINTS = [
  { progress: .10, lane: -24 },
  { progress: .27, lane: 28 },
  { progress: .44, lane: -8 },
  { progress: .61, lane: 30 },
  { progress: .78, lane: -30 },
  { progress: .91, lane: 16 },
];

function catmullRom(p0, p1, p2, p3, t) {
  const t2 = t * t;
  const t3 = t2 * t;
  return [
    .5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2*p0[0] - 5*p1[0] + 4*p2[0] - p3[0]) * t2 + (-p0[0] + 3*p1[0] - 3*p2[0] + p3[0]) * t3),
    .5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2*p0[1] - 5*p1[1] + 4*p2[1] - p3[1]) * t2 + (-p0[1] + 3*p1[1] - 3*p2[1] + p3[1]) * t3),
  ];
}

function createTrack(points, detail = 36) {
  const samples = [];
  for (let index = 0; index < points.length; index += 1) {
    const p0 = points[(index - 1 + points.length) % points.length];
    const p1 = points[index];
    const p2 = points[(index + 1) % points.length];
    const p3 = points[(index + 2) % points.length];
    for (let step = 0; step < detail; step += 1) {
      samples.push(catmullRom(p0, p1, p2, p3, step / detail));
    }
  }
  return samples;
}

const TRACK = createTrack(CONTROL_POINTS);

function pointOnTrack(progress, lane = 0) {
  const exact = wrapProgress(progress) * TRACK.length;
  const index = Math.floor(exact) % TRACK.length;
  const next = (index + 1) % TRACK.length;
  const mix = exact - Math.floor(exact);
  const x = TRACK[index][0] + (TRACK[next][0] - TRACK[index][0]) * mix;
  const y = TRACK[index][1] + (TRACK[next][1] - TRACK[index][1]) * mix;
  const angle = Math.atan2(TRACK[next][1] - TRACK[index][1], TRACK[next][0] - TRACK[index][0]);
  return {
    x: x - Math.sin(angle) * lane,
    y: y + Math.cos(angle) * lane,
    angle,
  };
}

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const width = window.innerWidth;
  const height = window.innerHeight;
  canvas.width = Math.round(width * dpr);
  canvas.height = Math.round(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  canvas.dataset.dpr = dpr;
}

function roundedRect(context, x, y, width, height, radius) {
  const r = Math.min(radius, width / 2, height / 2);
  context.beginPath();
  context.roundRect(x, y, width, height, r);
}

function drawFloor(width, height) {
  const gradient = ctx.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, "#293746");
  gradient.addColorStop(1, "#17212c");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);
  ctx.globalAlpha = .08;
  ctx.strokeStyle = "#fff";
  ctx.lineWidth = 1;
  for (let x = 0; x < width + height; x += 70) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x - height, height);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

function drawWorldFloor() {
  ctx.fillStyle = "#d8d1c4";
  ctx.fillRect(-1400, -1100, 2800, 2200);
  ctx.strokeStyle = "rgba(64,70,77,.09)";
  ctx.lineWidth = 2;
  for (let x = -1400; x <= 1400; x += 90) {
    ctx.beginPath();
    ctx.moveTo(x, -1100);
    ctx.lineTo(x, 1100);
    ctx.stroke();
  }
  for (let y = -1100; y <= 1100; y += 90) {
    ctx.beginPath();
    ctx.moveTo(-1400, y);
    ctx.lineTo(1400, y);
    ctx.stroke();
  }
}

function traceTrack() {
  ctx.beginPath();
  ctx.moveTo(TRACK[0][0], TRACK[0][1]);
  for (let i = 1; i < TRACK.length; i += 1) ctx.lineTo(TRACK[i][0], TRACK[i][1]);
  ctx.closePath();
}

function drawTrack() {
  traceTrack();
  ctx.strokeStyle = "#17202b";
  ctx.lineWidth = 184;
  ctx.lineJoin = "round";
  ctx.stroke();

  traceTrack();
  ctx.strokeStyle = "#656d72";
  ctx.lineWidth = 164;
  ctx.stroke();

  traceTrack();
  ctx.strokeStyle = "#858b8e";
  ctx.lineWidth = 144;
  ctx.stroke();

  traceTrack();
  ctx.setLineDash([26, 34]);
  ctx.strokeStyle = "rgba(255,250,241,.36)";
  ctx.lineWidth = 4;
  ctx.stroke();
  ctx.setLineDash([]);

  const start = pointOnTrack(0);
  ctx.save();
  ctx.translate(start.x, start.y);
  ctx.rotate(start.angle);
  for (let row = -3; row < 4; row += 1) {
    for (let column = -4; column < 4; column += 1) {
      ctx.fillStyle = (row + column) % 2 ? "#f7f1e6" : "#17202b";
      ctx.fillRect(row * 12, column * 20, 12, 20);
    }
  }
  ctx.restore();
}

function drawShelf([x, y, width, height, label, color]) {
  ctx.save();
  ctx.translate(x, y);
  ctx.shadowColor = "rgba(17,24,39,.35)";
  ctx.shadowBlur = 0;
  ctx.shadowOffsetX = 10;
  ctx.shadowOffsetY = 12;
  roundedRect(ctx, -width / 2, -height / 2, width, height, 8);
  ctx.fillStyle = "#273341";
  ctx.fill();
  ctx.shadowColor = "transparent";
  ctx.fillStyle = color;
  ctx.fillRect(-width / 2 + 9, -height / 2 + 9, width - 18, 14);
  ctx.fillStyle = "#f7f1e6";
  ctx.font = "800 17px 'Barlow Condensed', sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(label, 0, 11);
  for (let px = -width / 2 + 20; px < width / 2 - 16; px += 34) {
    ctx.fillStyle = ["#ff725f", "#ffd541", "#53d6a8", "#4e81ff"][Math.abs(Math.floor(px / 34)) % 4];
    ctx.fillRect(px, -height / 2 + 27, 20, 23);
  }
  ctx.restore();
}

function drawItem(item, index) {
  const point = pointOnTrack(item.progress, item.lane);
  const collected = state && state.collected.has(`${state.player.lap}-${index}`);
  if (collected) return;
  const pulse = 1 + Math.sin(performance.now() / 180 + index) * .08;
  ctx.save();
  ctx.translate(point.x, point.y);
  ctx.rotate(performance.now() / 800 + index);
  ctx.scale(pulse, pulse);
  ctx.fillStyle = "#ffd541";
  ctx.strokeStyle = "#fffaf1";
  ctx.lineWidth = 5;
  ctx.shadowColor = "#ffd541";
  ctx.shadowBlur = 18;
  ctx.beginPath();
  ctx.rect(-18, -18, 36, 36);
  ctx.fill();
  ctx.stroke();
  ctx.rotate(-performance.now() / 800 - index);
  ctx.fillStyle = "#17202b";
  ctx.font = "900 24px 'Barlow Condensed', sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("?", 0, 1);
  ctx.restore();
}

function drawCart(racer, isPlayer = false) {
  const point = pointOnTrack(racer.progress, racer.lane);
  const scale = isPlayer ? 1.05 : .92;
  ctx.save();
  ctx.translate(point.x, point.y);
  ctx.rotate(point.angle + Math.PI / 2);
  ctx.scale(scale, scale);

  if (isPlayer && racer.boost > 0) {
    ctx.fillStyle = "#ffd541";
    ctx.shadowColor = "#ff5c35";
    ctx.shadowBlur = 18;
    ctx.beginPath();
    ctx.moveTo(-11, 22);
    ctx.lineTo(0, 54 + Math.random() * 14);
    ctx.lineTo(11, 22);
    ctx.fill();
  }
  if (isPlayer) {
    ctx.strokeStyle = "rgba(255,213,65,.35)";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(0, 0, 38 + Math.sin(performance.now() / 100) * 2, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (racer.shield > 0) {
    ctx.fillStyle = "rgba(100,210,255,.24)";
    ctx.strokeStyle = "rgba(200,245,255,.8)";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(0, 0, 48, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  }

  ctx.shadowColor = "rgba(0,0,0,.38)";
  ctx.shadowBlur = 0;
  ctx.shadowOffsetX = 6;
  ctx.shadowOffsetY = 8;
  roundedRect(ctx, -25, -32, 50, 63, 8);
  ctx.fillStyle = racer.color;
  ctx.fill();
  ctx.shadowColor = "transparent";
  ctx.strokeStyle = "#f7f1e6";
  ctx.lineWidth = 4;
  ctx.stroke();

  ctx.strokeStyle = "rgba(17,24,39,.55)";
  ctx.lineWidth = 3;
  for (let x = -14; x <= 14; x += 14) {
    ctx.beginPath();
    ctx.moveTo(x, -25);
    ctx.lineTo(x, 24);
    ctx.stroke();
  }
  ctx.fillStyle = "#111827";
  ctx.fillRect(-31, 22, 62, 8);
  ctx.fillStyle = "#111827";
  ctx.beginPath();
  ctx.arc(-20, 34, 7, 0, Math.PI * 2);
  ctx.arc(20, 34, 7, 0, Math.PI * 2);
  ctx.fill();

  ctx.font = "25px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(racer.emoji, 0, -4);

  if (!isPlayer) {
    ctx.save();
    ctx.rotate(-point.angle - Math.PI / 2);
    ctx.fillStyle = "rgba(17,24,39,.78)";
    roundedRect(ctx, -25, -59, 50, 17, 5);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "800 10px 'DM Sans', sans-serif";
    ctx.fillText(racer.name.toUpperCase(), 0, -50);
    ctx.restore();
  }
  ctx.restore();
}

function drawMiniMap(width) {
  if (!state) return;
  const mapWidth = 115;
  const mapHeight = 68;
  const x = width - mapWidth - 22;
  const y = 142;
  ctx.save();
  ctx.translate(x + mapWidth / 2, y + mapHeight / 2);
  ctx.scale(.055, .055);
  traceTrack();
  ctx.strokeStyle = "rgba(17,24,39,.58)";
  ctx.lineWidth = 110;
  ctx.stroke();
  [...state.opponents, state.player].forEach((racer, index, list) => {
    const point = pointOnTrack(racer.progress);
    ctx.fillStyle = index === list.length - 1 ? "#ffd541" : racer.color;
    ctx.beginPath();
    ctx.arc(point.x, point.y, index === list.length - 1 ? 55 : 38, 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.restore();
}

function drawScene() {
  const dpr = Number(canvas.dataset.dpr || 1);
  const width = canvas.width / dpr;
  const height = canvas.height / dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  drawFloor(width, height);

  const player = state?.player || { progress: .49, lane: 0 };
  const camera = pointOnTrack(player.progress, player.lane * .25);
  const cameraAngle = state ? camera.angle : -.15;
  const zoom = clamp(Math.min(width / 700, height / 430), .72, 1.18);
  ctx.save();
  ctx.translate(width * .5, height * (state ? .61 : .5));
  ctx.scale(zoom, zoom);
  ctx.rotate(-cameraAngle + Math.PI / 2);
  ctx.translate(-camera.x, -camera.y);
  drawWorldFloor();
  SHELVES.forEach(drawShelf);
  drawTrack();
  if (state) {
    ITEM_POINTS.forEach(drawItem);
    state.opponents.forEach((opponent) => drawCart(opponent));
    drawCart(state.player, true);
  } else {
    drawCart({ ...RACERS[0], progress: .49, lane: 0, emoji: RACERS[0].emoji }, true);
    drawCart({ name: "Reina", color: "#ff725f", emoji: "🧣", progress: .46, lane: -28 });
  }
  ctx.restore();
  if (state && view === "race") drawMiniMap(width);
}

function setView(nextView) {
  view = nextView;
  elements.menu.classList.toggle("hidden", nextView !== "menu");
  elements.hud.classList.toggle("hidden", nextView !== "race");
  elements.controls.classList.toggle("hidden", nextView !== "race");
  elements.pause.classList.toggle("hidden", nextView !== "paused");
  elements.results.classList.toggle("hidden", nextView !== "results");
}

function playTone(frequency = 440, duration = .08, type = "square") {
  try {
    audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    oscillator.type = type;
    oscillator.frequency.value = frequency;
    gain.gain.setValueAtTime(.06, audioContext.currentTime);
    gain.gain.exponentialRampToValueAtTime(.001, audioContext.currentTime + duration);
    oscillator.connect(gain).connect(audioContext.destination);
    oscillator.start();
    oscillator.stop(audioContext.currentTime + duration);
  } catch {
    // Sound is a progressive enhancement and can be blocked by iOS.
  }
}

function updateRacerPicker(index) {
  selectedRacer = index;
  const racer = RACERS[index];
  $("#racer-name").textContent = racer.name;
  $("#racer-number").textContent = racer.number;
  $("#racer-bio").textContent = racer.bio;
  $("#stat-speed").style.width = `${racer.stats.speed}%`;
  $("#stat-grip").style.width = `${racer.stats.grip}%`;
  $("#stat-boost").style.width = `${racer.stats.boost}%`;
  $(".racer-head").textContent = racer.emoji;
  document.querySelectorAll(".racer-card").forEach((card, cardIndex) => {
    const selected = cardIndex === index;
    card.classList.toggle("selected", selected);
    card.setAttribute("aria-selected", String(selected));
  });
  playTone(280 + index * 80, .06, "sine");
}

function startRace() {
  state = createRaceState(selectedRacer);
  state.startedAt = performance.now();
  state.countdownMark = 4;
  setView("race");
  input.gas = false;
  updateHud();
}

function showMessage(message, duration = 700) {
  elements.message.textContent = message;
  elements.message.style.opacity = "1";
  elements.message.style.transform = "translate(-50%,-50%) rotate(-3deg) scale(1)";
  clearTimeout(showMessage.timer);
  showMessage.timer = setTimeout(() => {
    elements.message.style.opacity = "0";
    elements.message.style.transform = "translate(-50%,-50%) rotate(-3deg) scale(1.3)";
  }, duration);
}

function updateHud() {
  if (!state) return;
  elements.position.textContent = state.position;
  elements.lap.textContent = `${Math.min(state.player.lap + 1, TOTAL_LAPS)} / ${TOTAL_LAPS}`;
  elements.boost.style.width = `${clamp(state.player.boost / 2.2 * 100, 0, 100)}%`;
  const power = POWER_UPS.find((item) => item.id === state.player.item);
  elements.item.classList.toggle("empty", !power);
  elements.item.querySelector("span").textContent = power?.icon || "?";
  elements.item.querySelector("small").textContent = power?.name || "POWER-UP";
}

function circularDistance(a, b) {
  const direct = Math.abs(a - b);
  return Math.min(direct, 1 - direct);
}

function checkItems() {
  ITEM_POINTS.forEach((item, index) => {
    const key = `${state.player.lap}-${index}`;
    if (state.collected.has(key)) return;
    if (circularDistance(state.player.progress, item.progress) < .012 && Math.abs(state.player.lane - item.lane) < 25) {
      state.collected.add(key);
      if (!state.player.item) {
        const power = POWER_UPS[(index + state.player.lap + selectedRacer) % POWER_UPS.length];
        state.player.item = power.id;
        showMessage(power.name, 900);
        playTone(720, .12, "sine");
      } else {
        state.player.boost = Math.max(state.player.boost, .6);
      }
    }
  });
}

function finishRace() {
  state.phase = "finished";
  const elapsed = state.elapsed * 1000;
  const best = state.lapTimes.length ? Math.min(...state.lapTimes) : elapsed / TOTAL_LAPS;
  const place = state.position;
  $("#result-place").textContent = ordinal(place);
  $("#result-title").textContent = place === 1 ? "AISLE CHAMPION!" : place === 2 ? "SHELF SPEEDSTER!" : "SOLID FINISH!";
  $("#result-copy").textContent = place === 1
    ? "You found the fastest line through produce."
    : "The neighborhood rematch starts whenever you’re ready.";
  $("#result-time").textContent = formatTime(elapsed);
  $("#best-lap").textContent = formatTime(best);
  setView("results");
  playTone(place === 1 ? 880 : 520, .3, "triangle");
}

function updateRace(dt) {
  if (!state || view !== "race") return;
  if (state.phase === "countdown") {
    state.countdown -= dt;
    const mark = Math.ceil(state.countdown);
    if (mark !== state.countdownMark) {
      state.countdownMark = mark;
      if (mark > 0 && mark <= 3) {
        showMessage(String(mark), 650);
        playTone(350 + (3 - mark) * 65);
      } else if (mark <= 0) {
        state.phase = "racing";
        showMessage("GO!", 850);
        playTone(720, .18);
      }
    }
    return;
  }
  if (state.phase !== "racing") return;

  const previousLap = state.player.lap;
  state.elapsed += dt;
  state.player.shield = Math.max(0, state.player.shield - dt);
  updatePlayer(state, input, dt);
  updateOpponents(state, dt);
  checkItems();

  if (state.player.lap > previousLap) {
    const lapMilliseconds = state.elapsed * 1000 - state.lastLapAt;
    state.lapTimes.push(lapMilliseconds);
    state.lastLapAt = state.elapsed * 1000;
    if (state.player.lap < TOTAL_LAPS) {
      showMessage("FINAL LAP", 1100);
      playTone(620, .18);
    }
  }
  if (state.player.lap >= TOTAL_LAPS) finishRace();
  updateHud();
}

function triggerItem() {
  if (!state || state.phase !== "racing" || !state.player.item) return;
  const used = usePowerUp(state);
  const power = POWER_UPS.find((item) => item.id === used);
  showMessage(power?.name || "BOOST!", 700);
  playTone(790, .15, "sawtooth");
  updateHud();
}

function loop(now) {
  const dt = Math.min((now - previousTime) / 1000, .04);
  previousTime = now;
  updateRace(dt);
  drawScene();
  requestAnimationFrame(loop);
}

function bindHoldButton(button, control) {
  const down = (event) => {
    event.preventDefault();
    input[control] = true;
    button.classList.add("active");
    if (button.setPointerCapture && event.pointerId != null) button.setPointerCapture(event.pointerId);
  };
  const up = (event) => {
    event.preventDefault();
    input[control] = false;
    button.classList.remove("active");
  };
  button.addEventListener("pointerdown", down);
  button.addEventListener("pointerup", up);
  button.addEventListener("pointercancel", up);
  button.addEventListener("lostpointercapture", up);
}

document.querySelectorAll(".racer-card").forEach((card) => {
  card.addEventListener("click", () => updateRacerPicker(Number(card.dataset.racer)));
});

document.querySelectorAll("[data-control]").forEach((button) => {
  const control = button.dataset.control;
  if (control === "item") button.addEventListener("pointerdown", (event) => { event.preventDefault(); triggerItem(); });
  else bindHoldButton(button, control);
});

window.addEventListener("keydown", (event) => {
  if (["ArrowLeft", "a", "A"].includes(event.key)) input.left = true;
  if (["ArrowRight", "d", "D"].includes(event.key)) input.right = true;
  if (["ArrowUp", "w", "W"].includes(event.key)) input.gas = true;
  if (event.key === " " || event.key === "Shift") triggerItem();
  if (event.key === "Escape" && view === "race") $("#pause-button").click();
  if (event.key === "Enter" && view === "menu") startRace();
});

window.addEventListener("keyup", (event) => {
  if (["ArrowLeft", "a", "A"].includes(event.key)) input.left = false;
  if (["ArrowRight", "d", "D"].includes(event.key)) input.right = false;
  if (["ArrowUp", "w", "W"].includes(event.key)) input.gas = false;
});

$("#start-button").addEventListener("click", startRace);
$("#pause-button").addEventListener("click", () => {
  if (view !== "race") return;
  setView("paused");
  input.left = input.right = input.gas = false;
});
$("#resume-button").addEventListener("click", () => setView("race"));
$("#quit-button").addEventListener("click", () => { state = null; setView("menu"); });
$("#race-again-button").addEventListener("click", startRace);
$("#select-button").addEventListener("click", () => { state = null; setView("menu"); });
window.addEventListener("resize", resize);
document.addEventListener("visibilitychange", () => {
  if (document.hidden && view === "race") $("#pause-button").click();
});

if ("serviceWorker" in navigator && window.location.protocol.startsWith("http")) {
  window.addEventListener("load", () => navigator.serviceWorker.register("./sw.js").catch(() => {}));
}

resize();
updateRacerPicker(0);
requestAnimationFrame(loop);
