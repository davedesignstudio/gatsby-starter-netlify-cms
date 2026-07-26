import { CARTS, ITEM_LABELS, TOTAL_LAPS, placeLabel } from "./data.js";
import { createRace, updateRace, cameraFromPlayer } from "./engine.js";
import { createRenderer } from "./renderer.js";

const canvas = document.getElementById("game");
const renderer = createRenderer(canvas);

const screens = {
  title: document.getElementById("screen-title"),
  how: document.getElementById("screen-how"),
  select: document.getElementById("screen-select"),
  hud: document.getElementById("screen-hud"),
  pause: document.getElementById("screen-pause"),
  results: document.getElementById("screen-results"),
};

const hudPlace = document.getElementById("hud-place");
const hudLap = document.getElementById("hud-lap");
const hudItem = document.getElementById("hud-item");
const countdownEl = document.getElementById("countdown");
const cartGrid = document.getElementById("cart-grid");
const btnStartRace = document.getElementById("btn-start-race");
const resultsTitle = document.getElementById("results-title");
const resultsList = document.getElementById("results-list");

let selectedCartId = null;
let race = null;
let raf = 0;
let lastTs = 0;
let uiMode = "title";

function showScreen(name) {
  for (const key of Object.keys(screens)) {
    screens[key].classList.toggle("active", key === name);
  }
  uiMode = name;
  // Keep canvas visible during race/pause/results backdrop
  canvas.style.opacity = name === "title" || name === "how" || name === "select" ? "0" : "1";
}

function buildCartSelect() {
  cartGrid.innerHTML = "";
  for (const cart of CARTS) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "cart-card";
    btn.dataset.id = cart.id;
    btn.innerHTML = `
      <span class="cart-swatch" style="background: linear-gradient(180deg, ${cart.color}, ${cart.accent})"></span>
      <span>
        <strong>${cart.name}</strong>
        <span>${cart.blurb}</span>
      </span>
      <em>SPD ${(cart.speed * 100) | 0}</em>
    `;
    btn.addEventListener("click", () => {
      selectedCartId = cart.id;
      for (const el of cartGrid.querySelectorAll(".cart-card")) {
        el.classList.toggle("selected", el.dataset.id === cart.id);
      }
      btnStartRace.disabled = false;
    });
    cartGrid.appendChild(btn);
  }
}

function resize() {
  const app = document.getElementById("app");
  const rect = app.getBoundingClientRect();
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  renderer.resize(rect.width, rect.height, dpr);
}

function bindUI() {
  document.getElementById("btn-play").addEventListener("click", () => showScreen("select"));
  document.getElementById("btn-how").addEventListener("click", () => showScreen("how"));
  document.getElementById("btn-how-back").addEventListener("click", () => showScreen("title"));
  btnStartRace.addEventListener("click", () => startRace());
  document.getElementById("btn-pause").addEventListener("click", () => {
    if (!race || race.status === "finished" || race.status === "countdown") return;
    race.status = "paused";
    showScreen("pause");
  });
  document.getElementById("btn-resume").addEventListener("click", () => {
    if (!race) return;
    race.status = "racing";
    showScreen("hud");
  });
  document.getElementById("btn-quit").addEventListener("click", () => {
    stopLoop();
    race = null;
    showScreen("title");
    startIdlePreview();
  });
  document.getElementById("btn-again").addEventListener("click", () => startRace());
  document.getElementById("btn-title").addEventListener("click", () => {
    stopLoop();
    race = null;
    showScreen("title");
    startIdlePreview();
  });

  bindControls();
}

function bindControls() {
  const setKey = (code, down) => {
    if (!race) return;
    const input = race.input;
    if (code === "ArrowLeft" || code === "KeyA") input.left = down;
    if (code === "ArrowRight" || code === "KeyD") input.right = down;
    if (code === "Space" || code === "ArrowDown" || code === "KeyS") input.brake = down;
    if ((code === "KeyE" || code === "KeyZ" || code === "KeyX") && down) {
      input.itemPressed = true;
    }
  };

  window.addEventListener("keydown", (e) => {
    if (["ArrowLeft", "ArrowRight", "ArrowDown", "Space"].includes(e.code)) e.preventDefault();
    setKey(e.code, true);
  });
  window.addEventListener("keyup", (e) => setKey(e.code, false));

  const controls = document.getElementById("touch-controls");
  const map = {
    left: "left",
    right: "right",
    brake: "brake",
    item: "item",
  };

  const press = (action, down) => {
    if (!race) return;
    if (action === "item") {
      if (down) race.input.itemPressed = true;
      return;
    }
    race.input[action] = down;
  };

  for (const btn of controls.querySelectorAll(".ctrl")) {
    const action = map[btn.dataset.action];
    const onDown = (e) => {
      e.preventDefault();
      btn.classList.add("pressed");
      press(action, true);
    };
    const onUp = (e) => {
      e.preventDefault();
      btn.classList.remove("pressed");
      press(action, false);
    };
    btn.addEventListener("pointerdown", onDown);
    btn.addEventListener("pointerup", onUp);
    btn.addEventListener("pointerleave", onUp);
    btn.addEventListener("pointercancel", onUp);
  }
}

function startRace() {
  if (!selectedCartId) selectedCartId = CARTS[0].id;
  race = createRace(selectedCartId);
  showScreen("hud");
  lastTs = 0;
  stopLoop();
  raf = requestAnimationFrame(frame);
}

function stopLoop() {
  if (raf) cancelAnimationFrame(raf);
  raf = 0;
}

function frame(ts) {
  if (!race) return;
  if (!lastTs) lastTs = ts;
  let dt = (ts - lastTs) / 1000;
  lastTs = ts;
  dt = Math.min(0.033, dt);

  if (uiMode === "pause") {
    // frozen
  } else {
    updateRace(race, dt);
  }

  const cam = cameraFromPlayer(race.player);
  projectParticles(race, cam);

  renderer.resetTransform();
  if (race.shake > 0) renderer.screenShake(race.shake);

  renderer.draw(
    race.track,
    cam,
    race.karts,
    race.hazards,
    race.pickups,
    race.particles.filter((p) => !p.world)
  );
  renderer.resetTransform();

  updateHud();

  if (race.status === "finished" && uiMode !== "results") {
    showResults();
  }

  raf = requestAnimationFrame(frame);
}

function projectParticles(race, cam) {
  const { w, h } = renderer.size;
  const horizon = (h * 0.34) | 0;
  for (const p of race.particles) {
    if (!p.world) continue;
    const dx = p.wx - cam.x;
    const dy = p.wy - cam.y;
    const cos = Math.cos(-cam.angle);
    const sin = Math.sin(-cam.angle);
    const rx = dx * cos - dy * sin;
    const ry = dx * sin + dy * cos;
    if (ry < 8) {
      p.x = -999;
      p.y = -999;
      continue;
    }
    const scale = 220 / ry;
    p.x = w / 2 + rx * scale;
    p.y = horizon + (42 * 180) / ry;
    // Convert remaining to screen-space drift
    p.world = false;
    p.vx = (Math.random() - 0.5) * 40;
    p.vy = -20 - Math.random() * 40;
  }
}

function updateHud() {
  if (!race) return;
  const p = race.player;
  hudPlace.textContent = placeLabel(p.place);
  const lapShow = Math.min(TOTAL_LAPS, p.laps + 1);
  hudLap.textContent = `Lap ${lapShow}/${TOTAL_LAPS}`;
  hudItem.textContent = ITEM_LABELS[p.item] || "Empty";

  if (race.status === "countdown") {
    countdownEl.hidden = false;
    const label = race.countdown === 0 ? "GO!" : String(Math.max(1, race.countdown));
    if (countdownEl.textContent !== label) {
      countdownEl.textContent = label;
      countdownEl.style.animation = "none";
      void countdownEl.offsetWidth;
      countdownEl.style.animation = "";
    }
  } else {
    countdownEl.hidden = true;
  }
}

function showResults() {
  showScreen("results");
  // Keep looping so backdrop stays live-ish
  const order = race.finishedOrder.length
    ? race.finishedOrder
    : [...race.karts].sort((a, b) => a.place - b.place);

  const playerPlace = order.findIndex((k) => k.isPlayer) + 1;
  resultsTitle.textContent =
    playerPlace === 1 ? "Aisle Champion!" : playerPlace === 2 ? "Silver Cart!" : "Race Over";

  resultsList.innerHTML = "";
  order.forEach((k, i) => {
    const li = document.createElement("li");
    if (k.isPlayer) li.classList.add("you");
    const time = k.finishTime ? formatTime(k.finishTime) : "DNF";
    li.innerHTML = `<span>${placeLabel(i + 1)} ${k.name}</span><span>${time}</span>`;
    resultsList.appendChild(li);
  });
}

function formatTime(t) {
  const m = Math.floor(t / 60);
  const s = t - m * 60;
  return `${m}:${s.toFixed(2).padStart(5, "0")}`;
}

let preview = null;
let idleRaf = 0;

function startIdlePreview() {
  if (idleRaf) return;
  preview = createRace(CARTS[0].id);
  let t0 = performance.now();
  const idle = (ts) => {
    if (race) {
      idleRaf = 0;
      return;
    }
    if (uiMode === "title" || uiMode === "how" || uiMode === "select") {
      canvas.style.opacity = "0.35";
      const dt = Math.min(0.033, (ts - t0) / 1000);
      t0 = ts;
      preview.player.angle += dt * 0.25;
      const a = preview.player.angle;
      preview.player.x = 512 + Math.cos(a) * 280;
      preview.player.y = 512 + Math.sin(a) * 180;
      const cam = cameraFromPlayer(preview.player);
      // Track only on menus — avoid item diamonds covering CTAs
      renderer.draw(preview.track, cam, [], [], [], []);
    }
    idleRaf = requestAnimationFrame(idle);
  };
  idleRaf = requestAnimationFrame(idle);
}

function boot() {
  buildCartSelect();
  bindUI();
  resize();
  window.addEventListener("resize", resize);
  showScreen("title");
  startIdlePreview();
  // Dev/test hook (used by smoke tests)
  window.__cartClash = {
    getRace: () => race,
    getUiMode: () => uiMode,
  };
}

boot();
