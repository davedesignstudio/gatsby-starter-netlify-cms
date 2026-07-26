export const ITEM_TYPES = {
  banana: {
    id: "banana",
    icon: "🍌",
    label: "BANANA",
    kind: "drop",
  },
  boost: {
    id: "boost",
    icon: "⚡",
    label: "SODA",
    kind: "self",
  },
  can: {
    id: "can",
    icon: "🥫",
    label: "SOUP CAN",
    kind: "projectile",
  },
  coupon: {
    id: "coupon",
    icon: "🎟️",
    label: "COUPON",
    kind: "self",
  },
  milk: {
    id: "milk",
    icon: "🥛",
    label: "SPILL",
    kind: "drop",
  },
};

const BAG = ["banana", "boost", "can", "coupon", "milk", "boost", "banana", "can"];

export function rollItem(place) {
  // Slight catch-up: worse place gets better odds of boost/can
  let pool = [...BAG];
  if (place >= 3) pool = pool.concat(["boost", "boost", "can"]);
  if (place === 1) pool = pool.concat(["banana", "milk"]);
  return ITEM_TYPES[pool[Math.floor(Math.random() * pool.length)]];
}

export function createPickup(x, y) {
  return {
    x,
    y,
    r: 22,
    alive: true,
    spin: Math.random() * Math.PI * 2,
    respawn: 0,
  };
}

export function createHazard(type, x, y, ownerId) {
  return {
    type,
    x,
    y,
    r: type === "milk" ? 34 : 18,
    ownerId,
    life: type === "milk" ? 12 : 18,
    angle: Math.random() * Math.PI * 2,
  };
}

export function createProjectile(cart) {
  const speed = 520;
  return {
    x: cart.x + Math.cos(cart.angle) * 40,
    y: cart.y + Math.sin(cart.angle) * 40,
    vx: Math.cos(cart.angle) * speed,
    vy: Math.sin(cart.angle) * speed,
    r: 14,
    ownerId: cart.id,
    life: 2.2,
  };
}
