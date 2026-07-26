"use strict";

const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

const requiredFiles = [
  "index.html",
  "css/game.css",
  "js/game.js",
  "manifest.webmanifest",
  "service-worker.js",
  "images/game/cart-mark.svg",
];

requiredFiles.forEach((file) => {
  assert.ok(fs.existsSync(path.join(root, file)), `Missing required game asset: ${file}`);
});

const html = read("index.html");
assert.match(html, /viewport-fit=cover/, "The iOS safe-area viewport setting is required");
assert.match(html, /id="game-canvas"/, "The game canvas is required");
assert.match(html, /id="touch-controls"/, "Touch controls are required");
assert.match(html, /aria-live="polite"/, "An accessible live status region is required");

const localAssetPattern = /(?:src|href)="([^"#][^"]*)"/g;
for (const match of html.matchAll(localAssetPattern)) {
  const asset = match[1];
  if (/^(?:https?:|mailto:|tel:)/.test(asset)) continue;
  assert.ok(fs.existsSync(path.join(root, asset)), `HTML references a missing local asset: ${asset}`);
}

const manifest = JSON.parse(read("manifest.webmanifest"));
assert.equal(manifest.display, "standalone");
assert.equal(manifest.orientation, "landscape");
assert.ok(manifest.icons.length > 0, "The installable game needs an icon");

const gameSource = read("js/game.js");
assert.match(gameSource, /const TOTAL_LAPS = 3/);
assert.match(gameSource, /navigator\.getGamepads/);
assert.match(gameSource, /pointerdown/);
assert.match(gameSource, /visibilitychange/);

console.log("Build verification passed: game shell, assets, PWA metadata, and input support are present.");
