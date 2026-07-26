const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const output = path.join(root, "dist");
const files = [
  "index.html",
  "game.css",
  "game.js",
  "manifest.webmanifest",
  "service-worker.js",
  "assets"
];

fs.rmSync(output, { recursive: true, force: true });
fs.mkdirSync(output, { recursive: true });

for (const file of files) {
  fs.cpSync(path.join(root, file), path.join(output, file), { recursive: true });
}

console.log(`Built Aisle Outlaws to ${path.relative(root, output)}/`);
