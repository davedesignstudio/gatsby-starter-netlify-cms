export const TOTAL_LAPS = 3;

export const CARTS = [
  {
    id: "rusty",
    name: "Rusty",
    blurb: "Left by the bottle return in '09.",
    color: "#c45c26",
    accent: "#5c2b12",
    speed: 1.02,
    handling: 0.92,
    accel: 1.05,
  },
  {
    id: "squeaky",
    name: "Squeaky",
    blurb: "Wheels sing the song of aisle 4.",
    color: "#d9e1e4",
    accent: "#6b7a80",
    speed: 0.96,
    handling: 1.12,
    accel: 1.08,
  },
  {
    id: "bent",
    name: "Bent Wheel",
    blurb: "Steers like a rumor. Hits like a sale.",
    color: "#3d8bfd",
    accent: "#163a6b",
    speed: 1.08,
    handling: 0.84,
    accel: 0.95,
  },
  {
    id: "coupon",
    name: "Coupon King",
    blurb: "Filled with Sunday inserts and spite.",
    color: "#f2c14e",
    accent: "#8a6410",
    speed: 1.0,
    handling: 1.0,
    accel: 1.0,
  },
];

export const AI_NAMES = ["Dumpster Duo", "Parking Lot Pete", "Rain Cap Rita", "Night Shift Ned"];

export const ITEM_LABELS = {
  none: "Empty",
  banana: "Banana",
  soup: "Soup Can",
  boost: "Bag Boost",
  oil: "Spilled Oil",
};

export function placeLabel(n) {
  const v = n % 100;
  if (v >= 11 && v <= 13) return `${n}th`;
  const d = n % 10;
  if (d === 1) return `${n}st`;
  if (d === 2) return `${n}nd`;
  if (d === 3) return `${n}rd`;
  return `${n}th`;
}
