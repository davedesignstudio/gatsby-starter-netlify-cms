import { TOTAL_LAPS, AI_NAMES, CARTS } from "./data.js";
import {
  createTrack,
  isOnRoad,
  progressAlongTrack,
  raceDistance,
} from "./track.js";

const ITEM_TYPES = ["banana", "soup", "boost", "oil"];

export function createRace(playerCartId) {
  const track = createTrack();
  const playerDef = CARTS.find((c) => c.id === playerCartId) || CARTS[0];
  const karts = [];

  // Grid spawn near start
  const start = track.start;
  const player = makeKart({
    ...playerDef,
    name: playerDef.name,
    isPlayer: true,
    x: start.x,
    y: start.y,
    angle: start.angle,
  });
  karts.push(player);

  const aiDefs = CARTS.filter((c) => c.id !== playerDef.id);
  while (aiDefs.length < 3) aiDefs.push(CARTS[aiDefs.length % CARTS.length]);

  for (let i = 0; i < 3; i++) {
    const def = aiDefs[i];
    const lane = (i + 1) % 2 === 0 ? -18 : 18;
    const back = 28 + i * 26;
    karts.push(
      makeKart({
        ...def,
        name: AI_NAMES[i] || def.name,
        isPlayer: false,
        x: start.x + Math.cos(start.angle + Math.PI / 2) * lane,
        y: start.y + Math.sin(start.angle) * back,
        angle: start.angle,
        aiSkill: 0.72 + Math.random() * 0.18,
      })
    );
  }

  const state = {
    track,
    karts,
    player,
    hazards: [],
    particles: [],
    pickups: track.itemSpawns.map((p) => ({ ...p })),
    status: "countdown", // countdown | racing | finished | paused
    countdown: 3,
    countdownTimer: 0,
    raceTime: 0,
    shake: 0,
    finishedOrder: [],
    input: { left: false, right: false, brake: false, item: false, itemPressed: false },
  };

  return state;
}

function makeKart(def) {
  return {
    id: def.id + (def.isPlayer ? "-p" : "-" + Math.random().toString(36).slice(2, 6)),
    name: def.name,
    color: def.color,
    accent: def.accent,
    isPlayer: !!def.isPlayer,
    speedStat: def.speed || 1,
    handling: def.handling || 1,
    accelStat: def.accel || 1,
    aiSkill: def.aiSkill || 1,
    x: def.x,
    y: def.y,
    angle: def.angle,
    speed: 0,
    maxSpeed: 168 * (def.speed || 1),
    item: "none",
    spin: 0,
    boost: 0,
    slip: 0,
    wp: 0,
    laps: 0,
    lapFraction: 0,
    place: 1,
    finished: false,
    finishTime: 0,
    invuln: 0,
  };
}

export function updateRace(state, dt) {
  if (state.status === "paused" || state.status === "finished") {
    updateParticles(state, dt);
    return;
  }

  if (state.status === "countdown") {
    state.countdownTimer += dt;
    if (state.countdownTimer >= 1) {
      state.countdownTimer = 0;
      state.countdown -= 1;
      if (state.countdown < 0) {
        state.status = "racing";
        state.countdown = 0;
      }
    }
    // Still draw karts settling — light updates without drive
    for (const k of state.karts) {
      k.wp = progressAlongTrack(state.track, k.x, k.y, k.wp);
    }
    updateParticles(state, dt);
    return;
  }

  state.raceTime += dt;
  state.shake = Math.max(0, state.shake - dt * 30);

  // Respawning pickups
  for (const pk of state.pickups) {
    if (!pk.alive) {
      pk.cooldown -= dt;
      if (pk.cooldown <= 0) pk.alive = true;
    }
  }

  for (const kart of state.karts) {
    if (kart.finished) continue;
    if (kart.isPlayer) updatePlayer(state, kart, dt);
    else updateAI(state, kart, dt);
    integrateKart(state, kart, dt);
    handlePickups(state, kart);
    handleHazards(state, kart);
  }

  // Kart bump collisions
  resolveKartCollisions(state);

  // Hazards lifetime / projectiles
  updateHazards(state, dt);
  updateParticles(state, dt);
  updatePlaces(state);
  checkLapsAndFinish(state, dt);
}

function updatePlayer(state, kart, dt) {
  const input = state.input;
  if (kart.spin > 0) {
    kart.spin -= dt;
    kart.angle += 8 * dt;
    kart.speed *= 1 - 1.8 * dt;
    return;
  }
  if (kart.slip > 0) {
    kart.slip -= dt;
    kart.angle += (Math.random() - 0.5) * 3 * dt;
  }

  const turn = 2.5 * kart.handling * (0.45 + Math.min(1, kart.speed / kart.maxSpeed));
  let steer = 0;
  if (input.left) {
    kart.angle -= turn * dt;
    steer -= 1;
  }
  if (input.right) {
    kart.angle += turn * dt;
    steer += 1;
  }
  kart._steerLean = (kart._steerLean || 0) * 0.8 + steer * 0.2;

  if (input.brake) {
    kart.speed -= 140 * dt;
  } else {
    const accel = 95 * kart.accelStat;
    kart.speed += accel * dt;
  }

  if (kart.boost > 0) {
    kart.boost -= dt;
    kart.speed = Math.max(kart.speed, kart.maxSpeed * 1.35);
  }

  if (input.itemPressed) {
    useItem(state, kart);
    input.itemPressed = false;
  }
}

function updateAI(state, kart, dt) {
  if (kart.spin > 0) {
    kart.spin -= dt;
    kart.angle += 8 * dt;
    kart.speed *= 1 - 1.8 * dt;
    return;
  }
  if (kart.slip > 0) {
    kart.slip -= dt;
    kart.angle += (Math.random() - 0.5) * 2 * dt;
  }

  const track = state.track;
  const look = (kart.wp + 3) % track.waypoints.length;
  const target = track.waypoints[look];
  const desired = Math.atan2(target.y - kart.y, target.x - kart.x);
  let diff = wrapAngle(desired - kart.angle);
  const steer = Math.max(-1, Math.min(1, diff * 2.2));
  const turn = 2.3 * kart.handling * kart.aiSkill;
  kart.angle += steer * turn * dt;

  const accel = 88 * kart.accelStat * kart.aiSkill;
  kart.speed += accel * dt;
  // Brake into sharp corners
  if (Math.abs(diff) > 0.7) kart.speed -= 60 * dt;

  if (kart.boost > 0) {
    kart.boost -= dt;
    kart.speed = Math.max(kart.speed, kart.maxSpeed * 1.3);
  }

  // Occasional item use
  if (kart.item !== "none" && Math.random() < 0.4 * dt) {
    useItem(state, kart);
  }
}

function integrateKart(state, kart, dt) {
  kart.speed = Math.max(0, Math.min(kart.maxSpeed * (kart.boost > 0 ? 1.4 : 1), kart.speed));
  // Drag
  kart.speed *= 1 - 0.35 * dt;

  const nx = kart.x + Math.cos(kart.angle) * kart.speed * dt;
  const ny = kart.y + Math.sin(kart.angle) * kart.speed * dt;

  if (isOnRoad(state.track, nx, ny)) {
    kart.x = nx;
    kart.y = ny;
  } else if (isOnRoad(state.track, nx, kart.y)) {
    kart.x = nx;
    kart.speed *= 0.55;
    state.shake = kart.isPlayer ? 6 : state.shake;
  } else if (isOnRoad(state.track, kart.x, ny)) {
    kart.y = ny;
    kart.speed *= 0.55;
    state.shake = kart.isPlayer ? 6 : state.shake;
  } else {
    kart.speed *= 0.3;
    kart.angle += Math.PI * 0.15;
    // Nudge back toward track center
    kart.x += (state.track.size / 2 - kart.x) * 0.02;
    kart.y += (state.track.size / 2 - kart.y) * 0.02;
    if (kart.isPlayer) state.shake = 10;
  }

  if (kart.invuln > 0) kart.invuln -= dt;

  const prev = kart.wp;
  kart.wp = progressAlongTrack(state.track, kart.x, kart.y, kart.wp);
  const n = state.track.waypoints.length;
  // Lap crossed when wrapping from high wp to low near start
  if (prev > n * 0.75 && kart.wp < n * 0.15 && kart.speed > 10) {
    kart.laps += 1;
  }
  kart.lapFraction = kart.wp / n;
}

function handlePickups(state, kart) {
  if (kart.item !== "none") return;
  for (const pk of state.pickups) {
    if (!pk.alive) continue;
    const dx = pk.x - kart.x;
    const dy = pk.y - kart.y;
    if (dx * dx + dy * dy < 26 * 26) {
      pk.alive = false;
      pk.cooldown = 6;
      kart.item = ITEM_TYPES[(Math.random() * ITEM_TYPES.length) | 0];
      spawnBurst(state, kart.x, kart.y, "#5eead4", 8);
    }
  }
}

function handleHazards(state, kart) {
  if (kart.invuln > 0 || kart.spin > 0) return;
  for (let i = state.hazards.length - 1; i >= 0; i--) {
    const hz = state.hazards[i];
    if (hz.owner === kart) continue;
    const dx = hz.x - kart.x;
    const dy = hz.y - kart.y;
    const rad = hz.type === "soup" ? 18 : 22;
    if (dx * dx + dy * dy < rad * rad) {
      if (hz.type === "banana" || hz.type === "oil") {
        kart.spin = 1.15;
        kart.speed *= 0.35;
        if (hz.type === "oil") kart.slip = 1.4;
        state.hazards.splice(i, 1);
        if (kart.isPlayer) state.shake = 14;
        spawnBurst(state, kart.x, kart.y, "#ff5c6c", 10);
      } else if (hz.type === "soup") {
        kart.spin = 0.85;
        kart.speed *= 0.4;
        state.hazards.splice(i, 1);
        if (kart.isPlayer) state.shake = 12;
        spawnBurst(state, kart.x, kart.y, "#c45c26", 10);
      }
    }
  }
}

function useItem(state, kart) {
  if (kart.item === "none" || kart.spin > 0) return;
  const item = kart.item;
  kart.item = "none";

  if (item === "boost") {
    kart.boost = 1.2;
    kart.speed = kart.maxSpeed * 1.25;
    spawnBurst(state, kart.x, kart.y, "#ff8a3d", 14);
    return;
  }

  if (item === "banana" || item === "oil") {
    state.hazards.push({
      type: item,
      x: kart.x - Math.cos(kart.angle) * 28,
      y: kart.y - Math.sin(kart.angle) * 28,
      owner: kart,
      life: 18,
      vx: 0,
      vy: 0,
    });
    return;
  }

  if (item === "soup") {
    state.hazards.push({
      type: "soup",
      x: kart.x + Math.cos(kart.angle) * 24,
      y: kart.y + Math.sin(kart.angle) * 24,
      owner: kart,
      life: 2.5,
      vx: Math.cos(kart.angle) * 260,
      vy: Math.sin(kart.angle) * 260,
    });
  }
}

function updateHazards(state, dt) {
  for (let i = state.hazards.length - 1; i >= 0; i--) {
    const hz = state.hazards[i];
    hz.life -= dt;
    if (hz.type === "soup") {
      hz.x += hz.vx * dt;
      hz.y += hz.vy * dt;
      if (!isOnRoad(state.track, hz.x, hz.y)) hz.life = 0;
    }
    if (hz.life <= 0) state.hazards.splice(i, 1);
  }
}

function resolveKartCollisions(state) {
  const karts = state.karts;
  for (let i = 0; i < karts.length; i++) {
    for (let j = i + 1; j < karts.length; j++) {
      const a = karts[i];
      const b = karts[j];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const dist2 = dx * dx + dy * dy;
      const min = 22;
      if (dist2 < min * min && dist2 > 0.01) {
        const dist = Math.sqrt(dist2);
        const nx = dx / dist;
        const ny = dy / dist;
        const overlap = (min - dist) * 0.5;
        a.x -= nx * overlap;
        a.y -= ny * overlap;
        b.x += nx * overlap;
        b.y += ny * overlap;
        const swap = (a.speed + b.speed) * 0.5;
        a.speed = swap * 0.85;
        b.speed = swap * 0.85;
      }
    }
  }
}

function updatePlaces(state) {
  const ranked = [...state.karts].sort(
    (a, b) => raceDistance(state.track, b) - raceDistance(state.track, a)
  );
  ranked.forEach((k, i) => {
    k.place = i + 1;
  });
}

function checkLapsAndFinish(state, dt) {
  for (const kart of state.karts) {
    if (!kart.finished && kart.laps >= TOTAL_LAPS) {
      kart.finished = true;
      kart.finishTime = state.raceTime;
      kart.speed = 0;
      state.finishedOrder.push(kart);
      kart.invuln = 99;
    }
  }
  if (state.player.finished) {
    state._finishDelay = (state._finishDelay || 0) + dt;
    const allDone = state.karts.every((k) => k.finished);
    if (allDone || state._finishDelay > 2.5) {
      const rest = state.karts
        .filter((k) => !state.finishedOrder.includes(k))
        .sort((a, b) => raceDistance(state.track, b) - raceDistance(state.track, a));
      for (const k of rest) {
        k.finished = true;
        state.finishedOrder.push(k);
      }
      state.status = "finished";
    }
  }
}

function spawnBurst(state, x, y, color, n) {
  // Screen-space particles approximated from world later — store world and convert in main
  for (let i = 0; i < n; i++) {
    state.particles.push({
      world: true,
      wx: x,
      wy: y,
      x: 0,
      y: 0,
      vx: (Math.random() - 0.5) * 80,
      vy: (Math.random() - 0.5) * 80,
      life: 0.6 + Math.random() * 0.4,
      size: 2 + Math.random() * 3,
      color,
    });
  }
}

function updateParticles(state, dt) {
  for (let i = state.particles.length - 1; i >= 0; i--) {
    const p = state.particles[i];
    p.life -= dt;
    if (p.world) {
      p.wx += p.vx * dt;
      p.wy += p.vy * dt;
    } else {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
    if (p.life <= 0) state.particles.splice(i, 1);
  }
}

function wrapAngle(a) {
  while (a > Math.PI) a -= Math.PI * 2;
  while (a < -Math.PI) a += Math.PI * 2;
  return a;
}

export function cameraFromPlayer(player) {
  return {
    x: player.x - Math.cos(player.angle) * 18,
    y: player.y - Math.sin(player.angle) * 18,
    angle: player.angle,
  };
}
