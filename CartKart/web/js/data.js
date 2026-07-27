export const TOTAL_LAPS = 3;

export const POWER_UPS = {
  banana: { id: 'banana', name: 'Banana Peel', icon: '🍌' },
  boost: { id: 'boost', name: 'Coupon Boost', icon: '🏷️' },
  milk: { id: 'milk', name: 'Spilled Milk', icon: '🥛' },
  cans: { id: 'cans', name: 'Can Pyramid', icon: '🥫' },
};

export const CHARACTERS = [
  { id: 'will', name: 'Wobbly Will', emoji: '🧢', tagline: 'Balanced aisle cruiser', body: '#3388ee', cart: '#c8c8c8', speed: 1, accel: 1, turn: 1, weight: 1 },
  { id: 'sal', name: 'Speedy Sal', emoji: '⚡', tagline: 'Fast but wobbly steering', body: '#f23333', cart: '#b3b3b8', speed: 1.15, accel: 1.1, turn: 0.85, weight: 0.9 },
  { id: 'king', name: 'Drift King', emoji: '👑', tagline: 'Corners like a pro', body: '#bf59d9', cart: '#80808c', speed: 0.95, accel: 0.95, turn: 1.25, weight: 1 },
  { id: 'tanya', name: 'Tank Tanya', emoji: '💪', tagline: 'Slow, heavy, unstoppable', body: '#40b359', cart: '#66666b', speed: 0.88, accel: 0.85, turn: 0.9, weight: 1.35 },
  { id: 'carla', name: 'Coupon Carla', emoji: '🏷️', tagline: 'Quick off the line', body: '#f28c26', cart: '#808080', speed: 1, accel: 1.2, turn: 1.05, weight: 0.95 },
];

export const CUPS = [
  { id: 'store', name: 'Store Championship', emoji: '🏆', trackIds: ['grocery', 'frozen', 'produce'], points: [15, 12, 10, 8] },
  { id: 'night', name: 'Night Shift Cup', emoji: '🌙', trackIds: ['bakery', 'liquor', 'midnight'], points: [15, 12, 10, 8] },
  { id: 'grand', name: 'Grand Aisle Prix', emoji: '🛒', trackIds: ['grocery', 'frozen', 'produce', 'bakery', 'liquor', 'midnight'], points: [15, 12, 10, 8, 6, 4] },
];

function rect(x, y, w, h) { return { x, y, w, h }; }
function pt(x, y) { return { x, y }; }

export const TRACKS = [
  {
    id: 'grocery', name: 'Grocery Gauntlet', subtitle: 'Classic aisle loop', emoji: '🛒',
    floor: '#c7bfb3', island: '#a69e94', shelf: '#805933', islandLabel: 'DAIRY',
    shelfLabels: ['CEREAL', 'SOUP', 'CHIPS', 'PASTA', 'COOKIES', 'JUICE'],
    outer: rect(-640, -480, 1280, 960), inner: rect(-280, -180, 560, 360),
    checkpoints: [pt(0, -360), pt(560, 0), pt(0, 360), pt(-560, 0)],
    items: [pt(-520, -200), pt(520, -200), pt(520, 200), pt(-520, 200), pt(0, 0), pt(-200, 320), pt(200, -320)],
    shelves: [rect(-600, 60, 180, 80), rect(420, 60, 180, 80), rect(-600, -140, 180, 80), rect(420, -140, 180, 80), rect(-120, 240, 240, 60), rect(-120, -300, 240, 60)],
    starts: [{ x: -40, y: -360, a: Math.PI / 2 }, { x: 40, y: -360, a: Math.PI / 2 }, { x: -40, y: -400, a: Math.PI / 2 }, { x: 40, y: -400, a: Math.PI / 2 }],
    dark: false,
  },
  {
    id: 'frozen', name: 'Frozen Fury', subtitle: 'Icy freezer maze', emoji: '🧊',
    floor: '#b8d9f2', island: '#8cb8e0', shelf: '#598cbf', islandLabel: 'ICE CREAM',
    shelfLabels: ['PIZZA', 'WAFFLES', 'BERRIES', 'FISH', 'VEGGIES', 'DESSERT'],
    outer: rect(-700, -500, 1400, 1000), inner: rect(-220, -140, 440, 280),
    checkpoints: [pt(0, -380), pt(600, 40), pt(-80, 380), pt(-600, -40)],
    items: [pt(-560, -220), pt(560, -220), pt(560, 220), pt(-560, 220), pt(200, 0), pt(-200, 0), pt(0, 300)],
    shelves: [rect(-640, 120, 200, 70), rect(440, 120, 200, 70), rect(-640, -190, 200, 70), rect(440, -190, 200, 70), rect(-80, 260, 260, 55), rect(-80, -315, 260, 55)],
    starts: [{ x: -50, y: -380, a: Math.PI / 2 }, { x: 50, y: -380, a: Math.PI / 2 }, { x: -50, y: -420, a: Math.PI / 2 }, { x: 50, y: -420, a: Math.PI / 2 }],
    dark: false,
  },
  {
    id: 'produce', name: 'Produce Pit', subtitle: 'Wet floor sprint', emoji: '🥬',
    floor: '#b3d1a6', island: '#8cb37a', shelf: '#598c47', islandLabel: 'ORGANIC',
    shelfLabels: ['APPLES', 'BANANAS', 'KALE', 'TOMATO', 'GRAPES', 'CARROT'],
    outer: rect(-600, -520, 1200, 1040), inner: rect(-200, -220, 400, 440),
    checkpoints: [pt(0, -400), pt(480, -120), pt(0, 400), pt(-480, 120)],
    items: [pt(-460, -260), pt(460, -260), pt(460, 260), pt(-460, 260), pt(0, -40), pt(280, 180), pt(-280, -180)],
    shelves: [rect(-520, 80, 150, 90), rect(370, 80, 150, 90), rect(-520, -170, 150, 90), rect(370, -170, 150, 90), rect(-60, 300, 200, 70), rect(-60, -370, 200, 70)],
    starts: [{ x: -35, y: -400, a: Math.PI / 2 }, { x: 35, y: -400, a: Math.PI / 2 }, { x: -35, y: -440, a: Math.PI / 2 }, { x: 35, y: -440, a: Math.PI / 2 }],
    dark: false,
  },
  {
    id: 'bakery', name: 'Bakery Blitz', subtitle: 'Flour-dusted sprint', emoji: '🥐',
    floor: '#e0d1b8', island: '#c7ad85', shelf: '#9e6b47', islandLabel: 'OVEN',
    shelfLabels: ['BREAD', 'BAGELS', 'MUFFIN', 'DONUT', 'ROLLS', 'CAKE'],
    outer: rect(-620, -460, 1240, 920), inner: rect(-240, -160, 480, 320),
    checkpoints: [pt(0, -340), pt(500, 80), pt(0, 340), pt(-500, -80)],
    items: [pt(-480, -180), pt(480, -180), pt(480, 180), pt(-480, 180), pt(0, 0), pt(250, 280), pt(-250, -280)],
    shelves: [rect(-560, 80, 160, 75), rect(400, 80, 160, 75), rect(-560, -155, 160, 75), rect(400, -155, 160, 75), rect(-100, 250, 200, 55), rect(-100, -280, 200, 55)],
    starts: [{ x: -40, y: -340, a: Math.PI / 2 }, { x: 40, y: -340, a: Math.PI / 2 }, { x: -40, y: -380, a: Math.PI / 2 }, { x: 40, y: -380, a: Math.PI / 2 }],
    dark: false,
  },
  {
    id: 'liquor', name: 'Liquor Lane', subtitle: 'Bottle-lined bends', emoji: '🍷',
    floor: '#8c7a6b', island: '#6b5247', shelf: '#59382e', islandLabel: 'VINTAGE',
    shelfLabels: ['WINE', 'BEER', 'VODKA', 'WHISKY', 'GIN', 'CIDER'],
    outer: rect(-660, -490, 1320, 980), inner: rect(-300, -200, 600, 400),
    checkpoints: [pt(0, -370), pt(580, 0), pt(0, 370), pt(-580, 0)],
    items: [pt(-540, -210), pt(540, -210), pt(540, 210), pt(-540, 210), pt(0, 0), pt(-220, 300), pt(220, -300)],
    shelves: [rect(-620, 70, 170, 85), rect(450, 70, 170, 85), rect(-620, -155, 170, 85), rect(450, -155, 170, 85), rect(-130, 260, 260, 60), rect(-130, -320, 260, 60)],
    starts: [{ x: -45, y: -370, a: Math.PI / 2 }, { x: 45, y: -370, a: Math.PI / 2 }, { x: -45, y: -410, a: Math.PI / 2 }, { x: 45, y: -410, a: Math.PI / 2 }],
    dark: false,
  },
  {
    id: 'midnight', name: 'Midnight Shift', subtitle: 'Dark store dash', emoji: '🌙',
    floor: '#2e333f', island: '#1f242e', shelf: '#404759', islandLabel: 'CLOSED',
    shelfLabels: ['SNACKS', 'SODA', 'RAMEN', 'CANDY', 'CHIPS', 'ENERGY'],
    outer: rect(-640, -480, 1280, 960), inner: rect(-260, -170, 520, 340),
    checkpoints: [pt(0, -360), pt(550, 50), pt(0, 360), pt(-550, -50)],
    items: [pt(-500, -200), pt(500, -200), pt(500, 200), pt(-500, 200), pt(0, 0), pt(180, 300), pt(-180, -300)],
    shelves: [rect(-580, 65, 175, 80), rect(405, 65, 175, 80), rect(-580, -145, 175, 80), rect(405, -145, 175, 80), rect(-110, 235, 220, 58), rect(-110, -295, 220, 58)],
    starts: [{ x: -40, y: -360, a: Math.PI / 2 }, { x: 40, y: -360, a: Math.PI / 2 }, { x: -40, y: -400, a: Math.PI / 2 }, { x: 40, y: -400, a: Math.PI / 2 }],
    dark: true,
  },
];

export function getTrack(id) {
  return TRACKS.find((t) => t.id === id) || TRACKS[0];
}

export function inRect(px, py, r) {
  return px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h;
}

export function isOnTrack(track, px, py) {
  if (!inRect(px, py, track.outer)) return false;
  if (inRect(px, py, track.inner)) return false;
  return !track.shelves.some((s) => inRect(px, py, s));
}

export function nearestTrackPoint(track, px, py) {
  let x = Math.min(Math.max(px, track.outer.x + 40), track.outer.x + track.outer.w - 40);
  let y = Math.min(Math.max(py, track.outer.y + 40), track.outer.y + track.outer.h - 40);
  const inner = track.inner;

  if (inRect(x, y, inner)) {
    const options = [
      { x, y: inner.y + inner.h + 30, d: Math.abs(y - (inner.y + inner.h)) },
      { x, y: inner.y - 30, d: Math.abs(y - inner.y) },
      { x: inner.x + inner.w + 30, y, d: Math.abs(x - (inner.x + inner.w)) },
      { x: inner.x - 30, y, d: Math.abs(x - inner.x) },
    ];
    const best = options.reduce((a, b) => (a.d < b.d ? a : b));
    x = best.x;
    y = best.y;
  }

  for (const shelf of track.shelves) {
    if (inRect(x, y, shelf)) y = shelf.y + shelf.h + 35;
  }
  return { x, y };
}

export function randomPowerUp() {
  const keys = Object.keys(POWER_UPS);
  return POWER_UPS[keys[Math.floor(Math.random() * keys.length)]];
}
