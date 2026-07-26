export const TAU = Math.PI * 2;

export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function lerp(a, b, amount) {
  return a + (b - a) * amount;
}

export function wrap(value, length) {
  return ((value % length) + length) % length;
}

export function shortestAngle(from, to) {
  return Math.atan2(Math.sin(to - from), Math.cos(to - from));
}

export function ordinal(value) {
  const suffixes = ["th", "st", "nd", "rd"];
  const remainder = value % 100;
  return `${value}${suffixes[(remainder - 20) % 10] || suffixes[remainder] || suffixes[0]}`;
}

export function formatTime(milliseconds) {
  const safeTime = Math.max(0, milliseconds);
  const minutes = Math.floor(safeTime / 60000);
  const seconds = Math.floor((safeTime % 60000) / 1000);
  const hundredths = Math.floor((safeTime % 1000) / 10);
  return `${minutes}:${String(seconds).padStart(2, "0")}.${String(hundredths).padStart(2, "0")}`;
}

export function seededRandom(seed = 1) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function catmullRom(a, b, c, d, t) {
  const t2 = t * t;
  const t3 = t2 * t;
  return {
    x:
      0.5 *
      (2 * b.x +
        (-a.x + c.x) * t +
        (2 * a.x - 5 * b.x + 4 * c.x - d.x) * t2 +
        (-a.x + 3 * b.x - 3 * c.x + d.x) * t3),
    y:
      0.5 *
      (2 * b.y +
        (-a.y + c.y) * t +
        (2 * a.y - 5 * b.y + 4 * c.y - d.y) * t2 +
        (-a.y + 3 * b.y - 3 * c.y + d.y) * t3),
  };
}

export function createTrack(samplesPerSegment = 60) {
  const controls = [
    { x: 480, y: 250 },
    { x: 1150, y: 215 },
    { x: 1920, y: 260 },
    { x: 2160, y: 515 },
    { x: 2130, y: 1040 },
    { x: 1880, y: 1260 },
    { x: 1130, y: 1300 },
    { x: 430, y: 1240 },
    { x: 230, y: 980 },
    { x: 260, y: 500 },
  ];
  const points = [];

  for (let segment = 0; segment < controls.length; segment += 1) {
    const a = controls[wrap(segment - 1, controls.length)];
    const b = controls[segment];
    const c = controls[wrap(segment + 1, controls.length)];
    const d = controls[wrap(segment + 2, controls.length)];
    for (let step = 0; step < samplesPerSegment; step += 1) {
      const point = catmullRom(a, b, c, d, step / samplesPerSegment);
      points.push(point);
    }
  }

  let length = 0;
  points.forEach((point, index) => {
    const next = points[(index + 1) % points.length];
    point.angle = Math.atan2(next.y - point.y, next.x - point.x);
    point.distance = length;
    length += Math.hypot(next.x - point.x, next.y - point.y);
  });

  return { controls, points, length };
}

export function nearestTrackPoint(track, x, y, hintIndex = null, searchRadius = 55) {
  const { points } = track;
  let closestIndex = 0;
  let closestDistanceSquared = Infinity;
  const checkPoint = (index) => {
    const safeIndex = wrap(index, points.length);
    const point = points[safeIndex];
    const dx = x - point.x;
    const dy = y - point.y;
    const distanceSquared = dx * dx + dy * dy;
    if (distanceSquared < closestDistanceSquared) {
      closestDistanceSquared = distanceSquared;
      closestIndex = safeIndex;
    }
  };

  if (hintIndex === null) {
    for (let index = 0; index < points.length; index += 1) checkPoint(index);
  } else {
    for (let offset = -searchRadius; offset <= searchRadius; offset += 1) {
      checkPoint(hintIndex + offset);
    }
  }

  return {
    index: closestIndex,
    point: points[closestIndex],
    distance: Math.sqrt(closestDistanceSquared),
    progress: closestIndex / points.length,
  };
}

export function trackPointAt(track, progress, laneOffset = 0) {
  const rawIndex = wrap(progress, 1) * track.points.length;
  const index = Math.floor(rawIndex);
  const nextIndex = (index + 1) % track.points.length;
  const amount = rawIndex - index;
  const point = track.points[index];
  const next = track.points[nextIndex];
  const angle = point.angle + shortestAngle(point.angle, next.angle) * amount;
  return {
    x: lerp(point.x, next.x, amount) - Math.sin(angle) * laneOffset,
    y: lerp(point.y, next.y, amount) + Math.cos(angle) * laneOffset,
    angle,
  };
}

export function calculatePosition(playerTotalProgress, rivals) {
  return (
    1 +
    rivals.reduce(
      (ahead, rival) => ahead + (rival.totalProgress > playerTotalProgress ? 1 : 0),
      0,
    )
  );
}
