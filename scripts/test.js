const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

global.window = { addEventListener() {} };
const game = require("../game.js");

assert.equal(game.clamp(12, 0, 10), 10);
assert.equal(game.clamp(-2, 0, 10), 0);
assert.equal(game.lerp(10, 20, .25), 12.5);
assert.equal(game.wrap(-10, 100), 90);
assert.equal(game.suffix(1), "ST");
assert.equal(game.suffix(2), "ND");
assert.equal(game.suffix(3), "RD");
assert.equal(game.suffix(6), "TH");
assert.equal(game.formatTime(65.42), "01:05.42");
assert.equal(game.TRACK_LENGTH, 7800);
assert.equal(game.TOTAL_LAPS, 3);

const root = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(root, "index.html"), "utf8");
const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]);
assert.equal(ids.length, new Set(ids).size, "HTML ids must be unique");

for (const required of ["game", "play-button", "touch-controls", "boost-button", "result-screen"]) {
  assert.ok(ids.includes(required), `Missing required element #${required}`);
}

const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.webmanifest"), "utf8"));
assert.equal(manifest.display, "standalone");
assert.equal(manifest.orientation, "landscape");

console.log("Aisle Outlaws checks passed.");
