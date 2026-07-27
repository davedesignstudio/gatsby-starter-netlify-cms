import { isOnTrack, nearestTrackPoint, randomPowerUp } from './data.js';

export function createRacer(character, { isPlayer = false, slot = 0, name = null } = {}) {
  return {
    name: name || character.name,
    isPlayer,
    slot,
    body: character.body,
    cart: character.cart,
    emoji: character.emoji,
    x: 0,
    y: 0,
    angle: Math.PI / 2,
    speed: 0,
    maxSpeed: 320 * character.speed,
    accel: 520 * character.accel,
    turnRate: 3.8 * character.turn,
    weight: character.weight,
    drift: 0,
    boostTimer: 0,
    slipTimer: 0,
    spinTimer: 0,
    item: null,
    lap: 0,
    checkpoint: 0,
    position: 1,
    finished: false,
    finishTime: 0,
    wobble: 0,
  };
}

export function applyInput(racer, { steer, accel, brake, drift, useItem }) {
  if (racer.finished || racer.spinTimer > 0) return null;

  const slip = racer.slipTimer > 0 ? 0.55 : 1;
  const boost = racer.boostTimer > 0 ? 1.35 : 1;
  const max = racer.maxSpeed * boost * slip;

  if (accel) racer.speed = Math.min(racer.speed + racer.accel * 0.016, max);
  else if (brake) racer.speed = Math.max(racer.speed - racer.accel * 1.4 * 0.016, -max * 0.35);
  else racer.speed *= 0.985;

  if (Math.abs(racer.speed) > 20) {
    const mult = (racer.slipTimer > 0 ? 1.8 : 1) * (racer.speed / max);
    racer.angle += steer * racer.turnRate * mult * 0.016;
  }

  racer.drift = drift && Math.abs(racer.speed) > 120 ? 0.35 : 0;

  if (useItem && racer.item) {
    const used = racer.item;
    racer.item = null;
    return used;
  }
  return null;
}

export function updateRacer(racer, dt, track) {
  if (racer.spinTimer > 0) {
    racer.spinTimer -= dt;
    racer.angle += dt * 12;
    racer.speed *= 0.92;
  }
  if (racer.boostTimer > 0) racer.boostTimer -= dt;
  if (racer.slipTimer > 0) racer.slipTimer -= dt;

  const fwd = { x: Math.cos(racer.angle), y: Math.sin(racer.angle) };
  const side = { x: -Math.sin(racer.angle), y: Math.cos(racer.angle) };
  const sideSpd = racer.speed * racer.drift * 0.5;

  racer.x += (fwd.x * racer.speed + side.x * sideSpd) * dt;
  racer.y += (fwd.y * racer.speed + side.y * sideSpd) * dt;
  racer.wobble = Math.sin(performance.now() * 0.014) * Math.min(Math.abs(racer.speed) / racer.maxSpeed, 1) * 0.08;

  if (!isOnTrack(track, racer.x, racer.y)) {
    const p = nearestTrackPoint(track, racer.x, racer.y);
    racer.x = p.x;
    racer.y = p.y;
    racer.speed *= 0.6;
    return 'collision';
  }
  return null;
}

export function checkCheckpoint(racer, track) {
  const cp = track.checkpoints[racer.checkpoint % track.checkpoints.length];
  const dist = Math.hypot(racer.x - cp.x, racer.y - cp.y);
  if (dist < 90) {
    const prevLap = racer.lap;
    racer.checkpoint += 1;
    if (racer.checkpoint % track.checkpoints.length === 0) {
      racer.lap += 1;
      return prevLap < racer.lap ? 'lap' : null;
    }
  }
  return null;
}

export function deployItem(item, racer, racers, hazards) {
  const behind = {
    x: racer.x - Math.cos(racer.angle) * 45,
    y: racer.y - Math.sin(racer.angle) * 45,
  };
  if (item.id === 'boost') {
    racer.boostTimer = 1.8;
    return 'boost';
  }
  if (item.id === 'banana') {
    hazards.push({ type: 'banana', x: behind.x, y: behind.y, r: 16 });
    return 'banana';
  }
  if (item.id === 'milk') {
    hazards.push({ type: 'milk', x: behind.x, y: behind.y, r: 34 });
    return 'milk';
  }
  if (item.id === 'cans') {
    hazards.push({ type: 'cans', x: behind.x, y: behind.y, r: 24 });
    for (const other of racers) {
      if (other === racer) continue;
      if (Math.hypot(other.x - racer.x, other.y - racer.y) < 120) {
        other.spinTimer = 0.8;
      }
    }
    return 'cans';
  }
  return null;
}

export function hitHazard(racer, hazard) {
  if (hazard.type === 'banana') racer.spinTimer = 1;
  if (hazard.type === 'milk') racer.slipTimer = 1.4;
  if (hazard.type === 'cans') { racer.spinTimer = 0.6; racer.speed *= 0.7; }
}

export function collectItemBox(racer) {
  racer.item = randomPowerUp();
}
