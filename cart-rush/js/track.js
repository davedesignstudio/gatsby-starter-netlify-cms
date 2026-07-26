/** Supermarket aisle track — closed loop with walls and item pads. */

export const TRACK = {
  name: "MegaMart Circuit",
  laps: 3,
  width: 2400,
  height: 1800,
  // Centerline waypoints (racing line)
  path: [
    { x: 400, y: 1400 },
    { x: 700, y: 1450 },
    { x: 1100, y: 1480 },
    { x: 1500, y: 1420 },
    { x: 1850, y: 1280 },
    { x: 2050, y: 1050 },
    { x: 2100, y: 750 },
    { x: 1980, y: 480 },
    { x: 1700, y: 320 },
    { x: 1350, y: 260 },
    { x: 1000, y: 280 },
    { x: 700, y: 380 },
    { x: 480, y: 560 },
    { x: 360, y: 820 },
    { x: 320, y: 1100 },
    { x: 340, y: 1300 },
  ],
  // Road half-width along the path
  roadHalf: 95,
  // Rectangular shelf obstacles (solid)
  shelves: [
    { x: 900, y: 700, w: 420, h: 90, label: "CEREAL" },
    { x: 900, y: 980, w: 420, h: 90, label: "SOUP" },
    { x: 1450, y: 700, w: 280, h: 90, label: "CHIPS" },
    { x: 1450, y: 980, w: 280, h: 90, label: "SODA" },
    { x: 600, y: 650, w: 90, h: 380, label: "FROZEN" },
    { x: 1750, y: 650, w: 90, h: 380, label: "DAIRY" },
    { x: 1100, y: 450, w: 200, h: 70, label: "BAKERY" },
    { x: 1100, y: 1200, w: 200, h: 70, label: "PRODUCE" },
  ],
  // Outer store walls
  walls: [
    { x: 80, y: 80, w: 2240, h: 40 },
    { x: 80, y: 1680, w: 2240, h: 40 },
    { x: 80, y: 80, w: 40, h: 1640 },
    { x: 2280, y: 80, w: 40, h: 1640 },
  ],
  startLine: { x1: 300, y1: 1350, x2: 500, y2: 1480 },
  itemSpawns: [
    { x: 1100, y: 1480 },
    { x: 2050, y: 900 },
    { x: 1700, y: 320 },
    { x: 480, y: 560 },
    { x: 1350, y: 260 },
    { x: 1980, y: 480 },
  ],
};

export function pathLength(path = TRACK.path) {
  let len = 0;
  for (let i = 0; i < path.length; i++) {
    const a = path[i];
    const b = path[(i + 1) % path.length];
    len += Math.hypot(b.x - a.x, b.y - a.y);
  }
  return len;
}

export function nearestPathProgress(x, y, path = TRACK.path) {
  let bestDist = Infinity;
  let bestProgress = 0;
  let bestSeg = 0;
  let accum = 0;
  const total = pathLength(path);

  for (let i = 0; i < path.length; i++) {
    const a = path[i];
    const b = path[(i + 1) % path.length];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const segLen = Math.hypot(dx, dy) || 1;
    const t = Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / (segLen * segLen)));
    const px = a.x + dx * t;
    const py = a.y + dy * t;
    const dist = Math.hypot(x - px, y - py);
    if (dist < bestDist) {
      bestDist = dist;
      bestProgress = (accum + segLen * t) / total;
      bestSeg = i;
    }
    accum += segLen;
  }
  return { progress: bestProgress, dist: bestDist, seg: bestSeg, total };
}

export function pointOnPath(progress, path = TRACK.path) {
  const total = pathLength(path);
  let target = ((progress % 1) + 1) % 1 * total;
  for (let i = 0; i < path.length; i++) {
    const a = path[i];
    const b = path[(i + 1) % path.length];
    const segLen = Math.hypot(b.x - a.x, b.y - a.y) || 1;
    if (target <= segLen) {
      const t = target / segLen;
      const angle = Math.atan2(b.y - a.y, b.x - a.x);
      return {
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        angle,
      };
    }
    target -= segLen;
  }
  return { x: path[0].x, y: path[0].y, angle: 0 };
}

export function solidRects() {
  return [...TRACK.shelves, ...TRACK.walls];
}

export function circleRectCollision(cx, cy, r, rect) {
  const nearestX = Math.max(rect.x, Math.min(cx, rect.x + rect.w));
  const nearestY = Math.max(rect.y, Math.min(cy, rect.y + rect.h));
  const dx = cx - nearestX;
  const dy = cy - nearestY;
  const dist2 = dx * dx + dy * dy;
  if (dist2 >= r * r) return null;
  const dist = Math.sqrt(dist2) || 0.001;
  return {
    nx: dx / dist,
    ny: dy / dist,
    depth: r - dist,
  };
}
