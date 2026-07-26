const test = require("node:test");
const assert = require("node:assert/strict");
const {
  clamp,
  wrap,
  forwardDistance,
  ordinal,
  formatTime,
  calculateRank,
  seededRandom,
} = require("../js/game-core");

test("clamp keeps values inside the supplied range", () => {
  assert.equal(clamp(-3, 0, 10), 0);
  assert.equal(clamp(7, 0, 10), 7);
  assert.equal(clamp(18, 0, 10), 10);
});

test("track positions wrap and preserve forward distance", () => {
  assert.equal(wrap(3050, 3000), 50);
  assert.equal(wrap(-20, 3000), 2980);
  assert.equal(forwardDistance(2950, 75, 3000), 125);
});

test("ordinal handles teen exceptions and common suffixes", () => {
  assert.equal(ordinal(1), "1st");
  assert.equal(ordinal(2), "2nd");
  assert.equal(ordinal(3), "3rd");
  assert.equal(ordinal(11), "11th");
  assert.equal(ordinal(23), "23rd");
});

test("race time is formatted to hundredths", () => {
  assert.equal(formatTime(0), "00:00.00");
  assert.equal(formatTime(65_432), "01:05.43");
  assert.equal(formatTime(Infinity), "--:--.--");
});

test("rank counts rivals ahead of the player", () => {
  const rivals = [{ distance: 400 }, { distance: 700 }, { distance: 200 }];
  assert.equal(calculateRank(500, rivals), 2);
  assert.equal(calculateRank(800, rivals), 1);
});

test("seeded random returns a reproducible sequence", () => {
  const first = seededRandom(42);
  const second = seededRandom(42);
  assert.deepEqual([first(), first(), first()], [second(), second(), second()]);
});
