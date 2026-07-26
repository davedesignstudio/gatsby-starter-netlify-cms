const { cpSync, mkdirSync, rmSync } = require("node:fs");
const { join } = require("node:path");

const root = join(__dirname, "..");
const output = join(root, "public");
const files = [
  "index.html",
  "game.css",
  "game.js",
  "manifest.webmanifest",
  "service-worker.js",
  "icon.svg"
];

rmSync(output, { recursive: true, force: true });
mkdirSync(output, { recursive: true });
files.forEach(file => cpSync(join(root, file), join(output, file)));

console.log(`Built Midnight Cart Rally (${files.length} files)`);
