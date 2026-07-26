const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const output = path.join(root, "public");
const assets = [
  "index.html",
  "manifest.webmanifest",
  "sw.js",
  "css/game.css",
  "js/game.js",
  "icons/cart-rush-icon.svg"
];

fs.rmSync(output, { recursive: true, force: true });

for (const asset of assets) {
  const source = path.join(root, asset);
  const destination = path.join(output, asset);

  if (!fs.existsSync(source)) {
    throw new Error(`Missing required game asset: ${asset}`);
  }

  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
}

console.log(`Built Cart Rush with ${assets.length} assets in public/`);
