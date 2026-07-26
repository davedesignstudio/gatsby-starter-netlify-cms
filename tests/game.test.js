const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const html = fs.readFileSync(path.join(root, "index.html"), "utf8");
const source = fs.readFileSync(path.join(root, "game.js"), "utf8");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.webmanifest"), "utf8"));

[
  "game",
  "menu",
  "start-button",
  "hud",
  "touch-controls",
  "pause-screen",
  "results"
].forEach(id => assert.match(html, new RegExp(`id="${id}"`), `missing #${id}`));

assert.match(html, /viewport-fit=cover/, "iOS safe-area viewport support is required");
assert.match(html, /apple-mobile-web-app-capable/, "iOS standalone mode is required");
assert.match(source, /requestAnimationFrame\(gameLoop\)/, "game loop must be scheduled");
assert.match(source, /pointerdown/, "touch/pointer controls must be wired");
assert.match(source, /TOTAL_LAPS = 3/, "race should contain three laps");
assert.strictEqual(manifest.display, "standalone");
assert.strictEqual(manifest.orientation, "landscape");

console.log("Game smoke tests passed");
