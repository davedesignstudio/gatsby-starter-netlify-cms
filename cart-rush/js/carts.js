export const CART_ROSTER = [
  {
    id: "squeaky",
    name: "Squeaky",
    blurb: "Loud wheels. Soft heart. Fast off the line.",
    color: "#f0c646",
    accent: "#c49212",
    accel: 1.12,
    top: 0.96,
    turn: 1.08,
  },
  {
    id: "dent",
    name: "Dent",
    blurb: "Bent frame. Bulletproof attitude.",
    color: "#4ea0d9",
    accent: "#2a6f9c",
    accel: 0.95,
    top: 1.05,
    turn: 0.92,
  },
  {
    id: "wobbles",
    name: "Wobbles",
    blurb: "One sticky caster. Surprisingly grip-y.",
    color: "#5cbf7a",
    accent: "#2f8a4c",
    accel: 1.0,
    top: 1.0,
    turn: 1.15,
  },
  {
    id: "chrome",
    name: "Chrome",
    blurb: "Parking-lot legend. Pure aisle royalty.",
    color: "#d7dde3",
    accent: "#8a939c",
    accel: 1.05,
    top: 1.08,
    turn: 0.98,
  },
];

export function createCart(def, start, isPlayer = false) {
  return {
    id: def.id,
    name: def.name,
    color: def.color,
    accent: def.accent,
    accel: def.accel,
    top: def.top,
    turn: def.turn,
    x: start.x,
    y: start.y,
    angle: start.angle,
    vx: 0,
    vy: 0,
    speed: 0,
    isPlayer,
    lap: 0,
    progress: 0,
    lastProgress: 0,
    finished: false,
    finishPlace: 0,
    finishTime: 0,
    item: null,
    spinTimer: 0,
    boostTimer: 0,
    slowTimer: 0,
    shieldTimer: 0,
    invuln: 0,
    aiTarget: 0.02 + Math.random() * 0.04,
    aiSteerNoise: 0,
    wheelPhase: Math.random() * Math.PI * 2,
  };
}

export function startGrid(pathPoint, count) {
  const starts = [];
  const nx = Math.cos(pathPoint.angle + Math.PI / 2);
  const ny = Math.sin(pathPoint.angle + Math.PI / 2);
  const bx = Math.cos(pathPoint.angle + Math.PI);
  const by = Math.sin(pathPoint.angle + Math.PI);
  for (let i = 0; i < count; i++) {
    const lane = i % 2 === 0 ? -28 : 28;
    const row = Math.floor(i / 2);
    starts.push({
      x: pathPoint.x + nx * lane + bx * row * 55,
      y: pathPoint.y + ny * lane + by * row * 55,
      angle: pathPoint.angle,
    });
  }
  return starts;
}
