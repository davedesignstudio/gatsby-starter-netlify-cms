import { isOnTrack, nearestTrackPoint } from './data.js';
import { applyInput } from './racer.js';

export function updateAI(racer, track, racers, dt) {
  if (racer.finished) return null;

  const cps = track.checkpoints;
  const idx = racer.checkpoint % cps.length;
  let target = { ...cps[idx] };
  const lane = racer.position * 28 - 42;
  if (idx === 0) target.x += lane;
  else if (idx === 1) target.y += lane;
  else if (idx === 2) target.x -= lane;
  else target.y -= lane;

  if (!isOnTrack(track, target.x, target.y)) {
    const p = nearestTrackPoint(track, target.x, target.y);
    target = p;
  }

  const dx = target.x - racer.x;
  const dy = target.y - racer.y;
  let diff = Math.atan2(dy, dx) - racer.angle;
  while (diff > Math.PI) diff -= Math.PI * 2;
  while (diff < -Math.PI) diff += Math.PI * 2;

  const steer = Math.max(-1, Math.min(1, diff * 1.6));
  const accel = Math.abs(diff) < 1.2;
  const drift = Math.abs(diff) > 0.7 && racer.speed > 140;

  const useItem = racer.item && racers.some((o) => o !== racer && !o.finished && Math.hypot(o.x - racer.x, o.y - racer.y) < 180);
  return applyInput(racer, { steer, accel, brake: false, drift, useItem });
}
