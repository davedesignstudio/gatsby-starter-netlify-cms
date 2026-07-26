import { TRACK, nearestPathProgress, pointOnPath, solidRects, circleRectCollision } from "./track.js";
import { CART_ROSTER, createCart, startGrid } from "./carts.js";
import { rollItem, createPickup, createHazard, createProjectile } from "./items.js";
import { renderWorld, renderMinimap } from "./render.js";
import { createInput } from "./input.js";

const app = document.getElementById("app");
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const minimap = document.getElementById("minimap");
const mctx = minimap.getContext("2d");

const ui = {
  title: document.getElementById("title"),
  select: document.getElementById("select"),
  countdown: document.getElementById("countdown"),
  results: document.getElementById("results"),
  hud: document.getElementById("hud"),
  place: document.getElementById("place"),
  lap: document.getElementById("lap"),
  timer: document.getElementById("timer"),
  itemIcon: document.getElementById("itemIcon"),
  itemBox: document.getElementById("itemBox"),
  countNum: document.getElementById("countNum"),
  standings: document.getElementById("standings"),
  resultTitle: document.getElementById("resultTitle"),
  toast: document.getElementById("toast"),
  cartGrid: document.getElementById("cartGrid"),
  btnPlay: document.getElementById("btnPlay"),
  btnRace: document.getElementById("btnRace"),
  btnRetry: document.getElementById("btnRetry"),
  btnMenu: document.getElementById("btnMenu"),
};

const input = createInput(app);

let selectedCartId = null;
let mode = "title"; // title | select | countdown | race | results
let state = null;
let cam = { x: 0, y: 0, scale: 1, screenW: 0, screenH: 0 };
let lastTs = 0;
let countdownValue = 3;
let countdownAcc = 0;
let toastTimer = 0;

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.floor(window.innerWidth * dpr);
  canvas.height = Math.floor(window.innerHeight * dpr);
  cam.screenW = canvas.width;
  cam.screenH = canvas.height;
  cam.scale = (0.85 * dpr) * Math.min(window.innerWidth / 900, window.innerHeight / 600, 1.35);
}
window.addEventListener("resize", resize);
resize();

function showScreen(name) {
  ui.title.classList.toggle("hidden", name !== "title");
  ui.select.classList.toggle("hidden", name !== "select");
  ui.countdown.classList.toggle("hidden", name !== "countdown");
  ui.results.classList.toggle("hidden", name !== "results");
  ui.hud.classList.toggle("hidden", name !== "race" && name !== "countdown");
  input.showTouch(name === "race");
}

function toast(msg, ms = 1400) {
  ui.toast.textContent = msg;
  ui.toast.classList.remove("hidden");
  toastTimer = ms;
}

function buildSelect() {
  ui.cartGrid.innerHTML = "";
  for (const c of CART_ROSTER) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "cart-card";
    btn.dataset.id = c.id;
    btn.innerHTML = `
      <div class="cart-swatch" style="background: linear-gradient(135deg, ${c.color}, ${c.accent})"></div>
      <strong>${c.name}</strong>
      <span>${c.blurb}</span>
    `;
    btn.addEventListener("click", () => {
      selectedCartId = c.id;
      ui.cartGrid.querySelectorAll(".cart-card").forEach((el) => el.classList.remove("selected"));
      btn.classList.add("selected");
      ui.btnRace.disabled = false;
    });
    ui.cartGrid.appendChild(btn);
  }
}

function initRace() {
  // Start just after the finish line so the opening green light isn't a free lap.
  const start = pointOnPath(0.02);
  const grid = startGrid(start, 4);
  const playerDef = CART_ROSTER.find((c) => c.id === selectedCartId) || CART_ROSTER[0];
  const others = CART_ROSTER.filter((c) => c.id !== playerDef.id).slice(0, 3);

  const carts = [];
  carts.push(createCart(playerDef, grid[0], true));
  others.forEach((def, i) => carts.push(createCart(def, grid[i + 1], false)));

  // Seed progress near start
  for (const c of carts) {
    const p = nearestPathProgress(c.x, c.y);
    c.progress = p.progress;
    c.lastProgress = p.progress;
  }

  state = {
    carts,
    pickups: TRACK.itemSpawns.map((p) => createPickup(p.x, p.y)),
    hazards: [],
    shots: [],
    time: 0,
    raceTime: 0,
    finishCount: 0,
    running: false,
  };

  cam.x = carts[0].x;
  cam.y = carts[0].y;
}

function placeOf(cart) {
  const ranked = [...state.carts].sort((a, b) => {
    const sa = a.lap + a.progress;
    const sb = b.lap + b.progress;
    return sb - sa;
  });
  return ranked.findIndex((c) => c === cart) + 1;
}

function formatTime(t) {
  const m = Math.floor(t / 60);
  const s = t % 60;
  return `${m}:${s.toFixed(2).padStart(5, "0")}`;
}

function updateHUD() {
  const player = state.carts.find((c) => c.isPlayer);
  if (!player) return;
  ui.place.textContent = String(placeOf(player));
  ui.lap.textContent = String(Math.min(player.lap + 1, TRACK.laps));
  ui.timer.textContent = formatTime(state.raceTime);
  if (player.item) {
    ui.itemIcon.textContent = player.item.icon;
    ui.itemBox.classList.add("ready");
  } else {
    ui.itemIcon.textContent = "—";
    ui.itemBox.classList.remove("ready");
  }
}

function resolveSolids(cart, r = 22) {
  for (const rect of solidRects()) {
    const hit = circleRectCollision(cart.x, cart.y, r, rect);
    if (!hit) continue;
    cart.x += hit.nx * hit.depth;
    cart.y += hit.ny * hit.depth;
    const vn = cart.vx * hit.nx + cart.vy * hit.ny;
    if (vn < 0) {
      cart.vx -= vn * hit.nx * 1.4;
      cart.vy -= vn * hit.ny * 1.4;
    }
    cart.speed *= 0.75;
  }
}

function cartCollision(a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const dist = Math.hypot(dx, dy);
  const min = 40;
  if (dist >= min || dist < 0.001) return;
  const nx = dx / dist;
  const ny = dy / dist;
  const overlap = (min - dist) / 2;
  a.x -= nx * overlap;
  a.y -= ny * overlap;
  b.x += nx * overlap;
  b.y += ny * overlap;
  const av = a.vx * nx + a.vy * ny;
  const bv = b.vx * nx + b.vy * ny;
  const exchange = bv - av;
  a.vx += exchange * nx * 0.55;
  a.vy += exchange * ny * 0.55;
  b.vx -= exchange * nx * 0.55;
  b.vy -= exchange * ny * 0.55;
}

function useItem(cart) {
  if (!cart.item) return;
  const item = cart.item;
  cart.item = null;

  if (item.id === "boost") {
    cart.boostTimer = 1.35;
    if (cart.isPlayer) toast("SODA BOOST!");
  } else if (item.id === "coupon") {
    cart.shieldTimer = 3.5;
    if (cart.isPlayer) toast("COUPON SHIELD!");
  } else if (item.id === "banana") {
    const hx = cart.x - Math.cos(cart.angle) * 48;
    const hy = cart.y - Math.sin(cart.angle) * 48;
    state.hazards.push(createHazard("banana", hx, hy, cart.id));
    if (cart.isPlayer) toast("BANANA DROP!");
  } else if (item.id === "milk") {
    const hx = cart.x - Math.cos(cart.angle) * 50;
    const hy = cart.y - Math.sin(cart.angle) * 50;
    state.hazards.push(createHazard("milk", hx, hy, cart.id));
    if (cart.isPlayer) toast("MILK SPILL!");
  } else if (item.id === "can") {
    state.shots.push(createProjectile(cart));
    if (cart.isPlayer) toast("SOUP CAN!");
  }
}

function updateAI(cart, dt) {
  const look = nearestPathProgress(cart.x, cart.y);
  const targetProg = (look.progress + cart.aiTarget) % 1;
  const target = pointOnPath(targetProg);
  let desired = Math.atan2(target.y - cart.y, target.x - cart.x);
  cart.aiSteerNoise += (Math.random() - 0.5) * dt * 2;
  cart.aiSteerNoise *= 0.96;
  desired += cart.aiSteerNoise * 0.15;

  let diff = desired - cart.angle;
  while (diff > Math.PI) diff -= Math.PI * 2;
  while (diff < -Math.PI) diff += Math.PI * 2;

  const steer = Math.max(-1, Math.min(1, diff * 1.8));
  const place = placeOf(cart);
  const gas = cart.spinTimer <= 0;
  const brake = Math.abs(diff) > 1.1 && cart.speed > 180;

  // Occasional item use
  if (cart.item && Math.random() < dt * (place === 1 ? 0.35 : 0.7)) {
    useItem(cart);
  }

  tickCart(cart, dt, { steer, gas, brake });
}

function tickCart(cart, dt, controls) {
  if (cart.finished) {
    cart.speed *= 0.96;
    cart.vx *= 0.96;
    cart.vy *= 0.96;
    cart.x += cart.vx * dt;
    cart.y += cart.vy * dt;
    return;
  }

  cart.spinTimer = Math.max(0, cart.spinTimer - dt);
  cart.boostTimer = Math.max(0, cart.boostTimer - dt);
  cart.slowTimer = Math.max(0, cart.slowTimer - dt);
  cart.shieldTimer = Math.max(0, cart.shieldTimer - dt);
  cart.invuln = Math.max(0, cart.invuln - dt);

  if (cart.spinTimer > 0) {
    cart.angle += 10 * dt;
    cart.speed *= 0.92;
    controls = { steer: 0, gas: false, brake: true };
  }

  const maxSpeed = 265 * cart.top * (cart.boostTimer > 0 ? 1.45 : 1) * (cart.slowTimer > 0 ? 0.55 : 1);
  const accel = 340 * cart.accel * (cart.boostTimer > 0 ? 1.5 : 1);
  const turnRate = (2.55 * cart.turn) * (0.45 + 0.55 * (1 - Math.min(cart.speed / maxSpeed, 1) * 0.35));

  if (controls.gas) cart.speed += accel * dt;
  if (controls.brake) cart.speed -= accel * 1.35 * dt;
  if (!controls.gas && !controls.brake) cart.speed -= 90 * dt;

  cart.speed = Math.max(0, Math.min(maxSpeed, cart.speed));
  cart.angle += controls.steer * turnRate * (cart.speed > 20 ? 1 : 0.35) * dt;

  // Kart-ish velocity blend
  const tx = Math.cos(cart.angle);
  const ty = Math.sin(cart.angle);
  cart.vx = cart.vx * 0.86 + tx * cart.speed * 0.14;
  cart.vy = cart.vy * 0.86 + ty * cart.speed * 0.14;

  // Soft lateral drift
  const latx = -ty;
  const laty = tx;
  const lat = cart.vx * latx + cart.vy * laty;
  cart.vx -= latx * lat * 0.08;
  cart.vy -= laty * lat * 0.08;

  cart.x += cart.vx * dt;
  cart.y += cart.vy * dt;
  cart.wheelPhase += cart.speed * dt * 0.12;

  resolveSolids(cart);

  // Off-road / far from path friction
  const onPath = nearestPathProgress(cart.x, cart.y);
  if (onPath.dist > TRACK.roadHalf + 10) {
    cart.speed *= 1 - 1.2 * dt;
    cart.vx *= 1 - 0.8 * dt;
    cart.vy *= 1 - 0.8 * dt;
  }

  // Lap detection via progress wrap
  cart.lastProgress = cart.progress;
  cart.progress = onPath.progress;
  if (cart.lastProgress > 0.85 && cart.progress < 0.15) {
    cart.lap += 1;
    if (cart.isPlayer && cart.lap < TRACK.laps) toast(`LAP ${cart.lap + 1}`);
    if (cart.lap >= TRACK.laps && !cart.finished) {
      cart.finished = true;
      state.finishCount += 1;
      cart.finishPlace = state.finishCount;
      cart.finishTime = state.raceTime;
      if (cart.isPlayer) toast(placeLabel(cart.finishPlace));
    }
  }
}

function placeLabel(p) {
  return p === 1 ? "1ST PLACE!" : p === 2 ? "2ND PLACE" : p === 3 ? "3RD PLACE" : `${p}TH PLACE`;
}

function updateRace(dt) {
  state.time += dt;
  if (!state.running) return;
  state.raceTime += dt;

  const player = state.carts.find((c) => c.isPlayer);
  if (player && !player.finished) {
    if (input.consumeUseItem()) useItem(player);
    tickCart(player, dt, {
      steer: input.state.steer,
      gas: input.state.gas,
      brake: input.state.brake,
    });
  } else if (player) {
    tickCart(player, dt, { steer: 0, gas: false, brake: true });
    input.consumeUseItem();
  }

  for (const c of state.carts) {
    if (!c.isPlayer) updateAI(c, dt);
  }

  // Cart vs cart
  for (let i = 0; i < state.carts.length; i++) {
    for (let j = i + 1; j < state.carts.length; j++) {
      cartCollision(state.carts[i], state.carts[j]);
    }
  }

  // Pickups
  for (const p of state.pickups) {
    if (!p.alive) {
      p.respawn -= dt;
      if (p.respawn <= 0) p.alive = true;
      continue;
    }
    p.spin += dt;
    for (const c of state.carts) {
      if (c.item || c.finished) continue;
      if (Math.hypot(c.x - p.x, c.y - p.y) < p.r + 20) {
        c.item = rollItem(placeOf(c));
        p.alive = false;
        p.respawn = 4.5;
        if (c.isPlayer) toast(c.item.label);
      }
    }
  }

  // Hazards
  for (let i = state.hazards.length - 1; i >= 0; i--) {
    const h = state.hazards[i];
    h.life -= dt;
    if (h.life <= 0) {
      state.hazards.splice(i, 1);
      continue;
    }
    for (const c of state.carts) {
      if (c.id === h.ownerId || c.invuln > 0 || c.shieldTimer > 0) continue;
      if (Math.hypot(c.x - h.x, c.y - h.y) < h.r + 18) {
        if (h.type === "banana") {
          c.spinTimer = 1.1;
          c.invuln = 1.3;
          if (c.isPlayer) toast("SLIPPED!");
        } else {
          c.slowTimer = 1.6;
          c.invuln = 0.8;
          if (c.isPlayer) toast("WET FLOOR!");
        }
        if (h.type === "banana") state.hazards.splice(i, 1);
        break;
      }
    }
  }

  // Projectiles
  for (let i = state.shots.length - 1; i >= 0; i--) {
    const s = state.shots[i];
    s.life -= dt;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    let dead = s.life <= 0;
    for (const rect of solidRects()) {
      if (circleRectCollision(s.x, s.y, s.r, rect)) {
        dead = true;
        break;
      }
    }
    if (!dead) {
      for (const c of state.carts) {
        if (c.id === s.ownerId || c.invuln > 0) continue;
        if (Math.hypot(c.x - s.x, c.y - s.y) < s.r + 22) {
          if (c.shieldTimer > 0) {
            c.shieldTimer = 0;
          } else {
            c.spinTimer = 0.9;
            c.speed *= 0.4;
            c.invuln = 1.2;
            if (c.isPlayer) toast("HIT BY SOUP!");
          }
          dead = true;
          break;
        }
      }
    }
    if (dead) state.shots.splice(i, 1);
  }

  // Camera follow player
  if (player) {
    const lead = 60;
    const tx = player.x + Math.cos(player.angle) * lead;
    const ty = player.y + Math.sin(player.angle) * lead;
    cam.x += (tx - cam.x) * Math.min(1, 4 * dt);
    cam.y += (ty - cam.y) * Math.min(1, 4 * dt);
  }

  updateHUD();
  renderMinimap(mctx, state);

  // End race when player finished or everyone done / timeout
  if (player?.finished) {
    const allDone = state.carts.every((c) => c.finished);
    if (allDone || state.raceTime - player.finishTime > 4) {
      endRace();
    }
  } else if (state.raceTime > 180) {
    // Safety timeout — finish unfinished by distance
    for (const c of state.carts) {
      if (!c.finished) {
        c.finished = true;
        state.finishCount += 1;
        c.finishPlace = state.finishCount;
        c.finishTime = state.raceTime;
      }
    }
    endRace();
  }
}

function endRace() {
  mode = "results";
  state.running = false;
  input.showTouch(false);
  const ranked = [...state.carts].sort((a, b) => {
    if (a.finishPlace && b.finishPlace) return a.finishPlace - b.finishPlace;
    if (a.finishPlace) return -1;
    if (b.finishPlace) return 1;
    return b.lap + b.progress - (a.lap + a.progress);
  });
  const player = ranked.find((c) => c.isPlayer);
  ui.resultTitle.textContent = player ? placeLabel(player.finishPlace || placeOf(player)) : "FINISH";
  ui.standings.innerHTML = ranked
    .map((c, i) => {
      const place = c.finishPlace || i + 1;
      return `<li class="${c.isPlayer ? "you" : ""}">
        <span class="place">${place}</span>
        <span>${c.name}${c.isPlayer ? " (YOU)" : ""}</span>
        <span>${c.finishTime ? formatTime(c.finishTime) : "—"}</span>
      </li>`;
    })
    .join("");
  showScreen("results");
}

function frame(ts) {
  const dt = Math.min(0.033, (ts - lastTs) / 1000 || 0.016);
  lastTs = ts;

  if (toastTimer > 0) {
    toastTimer -= dt * 1000;
    if (toastTimer <= 0) ui.toast.classList.add("hidden");
  }

  if (mode === "countdown") {
    countdownAcc += dt;
    if (countdownAcc >= 1) {
      countdownAcc = 0;
      countdownValue -= 1;
      if (countdownValue > 0) {
        ui.countNum.textContent = String(countdownValue);
        ui.countNum.style.animation = "none";
        void ui.countNum.offsetWidth;
        ui.countNum.style.animation = "";
      } else if (countdownValue === 0) {
        ui.countNum.textContent = "GO!";
        ui.countNum.style.animation = "none";
        void ui.countNum.offsetWidth;
        ui.countNum.style.animation = "";
      } else {
        mode = "race";
        state.running = true;
        showScreen("race");
        toast("GO GO GO!");
      }
    }
    // Keep drawing idle scene
    if (state) {
      renderWorld(ctx, state, cam);
      renderMinimap(mctx, state);
      updateHUD();
    }
  } else if (mode === "race" || mode === "countdown") {
    if (mode === "race") updateRace(dt);
    renderWorld(ctx, state, cam);
  } else if (state && (mode === "title" || mode === "select" || mode === "results")) {
    // Ambient preview idle on title after first race optional — skip
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = "#1a2e1f";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }

  requestAnimationFrame(frame);
}

// Wire UI
ui.btnPlay.addEventListener("click", () => {
  mode = "select";
  showScreen("select");
});

ui.btnRace.addEventListener("click", () => {
  if (!selectedCartId) return;
  initRace();
  mode = "countdown";
  countdownValue = 3;
  countdownAcc = 0;
  ui.countNum.textContent = "3";
  showScreen("countdown");
  updateHUD();
  renderMinimap(mctx, state);
});

ui.btnRetry.addEventListener("click", () => {
  initRace();
  mode = "countdown";
  countdownValue = 3;
  countdownAcc = 0;
  ui.countNum.textContent = "3";
  showScreen("countdown");
});

ui.btnMenu.addEventListener("click", () => {
  mode = "title";
  state = null;
  showScreen("title");
});

buildSelect();
showScreen("title");
requestAnimationFrame(frame);

// Auto-gas hint for desktop: allow holding nothing — actually require gas for control authenticity
// Prevent pull-to-refresh / bounce on iOS
document.body.addEventListener("touchmove", (e) => e.preventDefault(), { passive: false });
