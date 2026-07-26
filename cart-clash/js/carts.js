window.CARTS = [
  {
    id: "rustbucket",
    name: "Rustbucket",
    blurb: "Wonky wheel. Pure spite.",
    color: "#b85c38",
    accent: "#5a2a18",
    speed: 0.96,
    accel: 1.08,
    handling: 1.12,
  },
  {
    id: "couponqueen",
    name: "Coupon Queen",
    blurb: "Clipped every deal. Still broke.",
    color: "#d9a441",
    accent: "#7a5314",
    speed: 1.0,
    accel: 1.0,
    handling: 1.05,
  },
  {
    id: "freezerburn",
    name: "Freezer Burn",
    blurb: "Cold chrome. Hot temper.",
    color: "#6ec4c8",
    accent: "#24575a",
    speed: 1.08,
    accel: 0.92,
    handling: 0.9,
  },
  {
    id: "aisleghost",
    name: "Aisle Ghost",
    blurb: "Never paid. Never caught.",
    color: "#9aa7b0",
    accent: "#3d464c",
    speed: 1.02,
    accel: 1.02,
    handling: 1.0,
  },
];

window.ITEMS = {
  banana: { name: "Banana Peel", color: "#f0d24b" },
  soda: { name: "Soda Boost", color: "#e23a2e" },
  pricegun: { name: "Price Gun", color: "#1fa7a0" },
  coupon: { name: "Coupon Shield", color: "#f0b429" },
};

window.PLACE_SUFFIX = (n) => {
  if (n === 1) return "1st";
  if (n === 2) return "2nd";
  if (n === 3) return "3rd";
  return `${n}th`;
};
