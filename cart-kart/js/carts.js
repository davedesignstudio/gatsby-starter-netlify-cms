/** Cart Kart — playable cart definitions */
window.CARTS = [
  {
    id: "rusty",
    name: "Rusty",
    blurb: "Veteran cart. Sticky wheels, big heart.",
    color: "#c45c26",
    accent: "#8b3a12",
    basket: "#9aa7b0",
    maxSpeed: 4.2,
    accel: 0.085,
    turn: 0.048,
    grip: 0.92,
  },
  {
    id: "squeaky",
    name: "Squeaky",
    blurb: "Loudest wheels in aisle 7.",
    color: "#2bb3ff",
    accent: "#1677a8",
    basket: "#dce8ef",
    maxSpeed: 4.0,
    accel: 0.1,
    turn: 0.055,
    grip: 0.88,
  },
  {
    id: "neon",
    name: "Neon",
    blurb: "Escaped the electronics wing.",
    color: "#b44dff",
    accent: "#6e1fa8",
    basket: "#e8d5ff",
    maxSpeed: 4.5,
    accel: 0.08,
    turn: 0.05,
    grip: 0.9,
  },
  {
    id: "basket",
    name: "Basket Case",
    blurb: "Handheld energy. Tiny, snappy.",
    color: "#6dbf4b",
    accent: "#3d7a2a",
    basket: "#d4efc8",
    maxSpeed: 3.9,
    accel: 0.11,
    turn: 0.062,
    grip: 0.94,
  },
  {
    id: "graffiti",
    name: "Rolling Stone",
    blurb: "Tagged up. Drifts like gossip.",
    color: "#e8452f",
    accent: "#9a2416",
    basket: "#f5c4bc",
    maxSpeed: 4.3,
    accel: 0.09,
    turn: 0.052,
    grip: 0.84,
  },
  {
    id: "coupon",
    name: "Coupon Queen",
    blurb: "Clipped deals. Clips corners.",
    color: "#f0c419",
    accent: "#b8920a",
    basket: "#fff6d0",
    maxSpeed: 4.1,
    accel: 0.095,
    turn: 0.058,
    grip: 0.91,
  },
];

window.ITEM_DEFS = {
  banana: { icon: "🍌", label: "Banana", kind: "drop" },
  soda: { icon: "🥤", label: "Soda Boost", kind: "self" },
  can: { icon: "🥫", label: "Can Cannon", kind: "projectile" },
  milk: { icon: "🥛", label: "Milk Spill", kind: "drop" },
  bag: { icon: "🛍️", label: "Bag Bomb", kind: "aoe" },
};

window.ordinal = function ordinal(n) {
  const s = ["th", "st", "nd", "rd"];
  const v = n % 100;
  return s[(v - 20) % 10] || s[v] || s[0];
};
