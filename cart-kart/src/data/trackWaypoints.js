// World size: 2000 x 1600
// Track: rectangular loop with a chicane in the top straight
// Direction: clockwise (start going RIGHT at the bottom)

export const TRACK_WIDTH = 190;

// Centerline waypoints for AI navigation (clockwise order)
export const WAYPOINTS = [
  { x: 1000, y: 1370 }, // 0  Start / Finish
  { x: 1650, y: 1370 }, // 1  Bottom straight right
  { x: 1860, y: 1280 }, // 2  Bottom-right corner enter
  { x: 1860, y: 800  }, // 3  Right straight mid
  { x: 1860, y: 320  }, // 4  Top-right corner enter
  { x: 1750, y: 170  }, // 5  Top-right corner
  { x: 1300, y: 170  }, // 6  Top straight right (before chicane)
  { x: 1050, y: 280  }, // 7  Chicane right bump
  { x: 900,  y: 170  }, // 8  Chicane left gap
  { x: 650,  y: 170  }, // 9  Top straight left
  { x: 250,  y: 170  }, // 10 Top-left corner
  { x: 140,  y: 320  }, // 11 Left straight top
  { x: 140,  y: 800  }, // 12 Left straight mid
  { x: 140,  y: 1280 }, // 13 Bottom-left corner enter
  { x: 250,  y: 1370 }, // 14 Bottom straight left
  { x: 700,  y: 1370 }, // 15 Bottom straight mid-left
];

// Lap checkpoints – cart must pass ALL of them in sequence before SF counts
export const CHECKPOINTS = [
  { x: 1780, y: 700,  w: 160, h: 240, id: 'cp1' }, // Right straight
  { x: 900,  y: 90,   w: 500, h: 160, id: 'cp2' }, // Top straight
  { x: 80,   y: 700,  w: 160, h: 240, id: 'cp3' }, // Left straight
  { x: 700,  y: 1310, w: 400, h: 160, id: 'sf'  }, // Start / Finish line
];

// Power-up box spawn positions
export const ITEM_BOX_POSITIONS = [
  { x: 1860, y: 600  },
  { x: 1860, y: 1000 },
  { x: 1000, y: 170  },
  { x: 140,  y: 600  },
  { x: 140,  y: 1000 },
  { x: 600,  y: 1370 },
  { x: 1400, y: 1370 },
];

// Store section decorations (visual only, painted on background)
export const STORE_SECTIONS = [
  { label: '🥦 PRODUCE',      color: 0x2D6A4F, x: 140,  y: 1200, w: 300, h: 280 },
  { label: '🧊 FROZEN FOODS', color: 0x2980B9, x: 140,  y: 200,  w: 300, h: 500 },
  { label: '🥐 BAKERY',       color: 0xD4789A, x: 1560, y: 200,  w: 300, h: 380 },
  { label: '🥫 CANNED GOODS', color: 0xD4A017, x: 1560, y: 1150, w: 300, h: 330 },
  { label: '💳 CHECKOUT',     color: 0xAA9966, x: 620,  y: 1240, w: 760, h: 240 },
];
