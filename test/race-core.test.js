const test = require("node:test");
const assert = require("node:assert/strict");
const Core = require("../js/race-core.js");

test("clamp keeps steering inside the aisle", function () {
  assert.equal(Core.clamp(1.4, -1, 1), 1);
  assert.equal(Core.clamp(-1.4, -1, 1), -1);
  assert.equal(Core.clamp(0.25, -1, 1), 0.25);
});

test("formatTime produces race timer text", function () {
  assert.equal(Core.formatTime(0), "0:00.00");
  assert.equal(Core.formatTime(65_432), "1:05.43");
});

test("ordinal handles teen suffixes", function () {
  assert.equal(Core.ordinal(1), "1st");
  assert.equal(Core.ordinal(2), "2nd");
  assert.equal(Core.ordinal(3), "3rd");
  assert.equal(Core.ordinal(11), "11th");
  assert.equal(Core.ordinal(22), "22nd");
});

test("calculatePlace counts racers that are ahead", function () {
  const opponents = [{ progress: 120 }, { progress: 80 }, { progress: 101 }];
  assert.equal(Core.calculatePlace(100, opponents), 3);
  assert.equal(Core.calculatePlace(130, opponents), 1);
});

test("hitTest requires matching lane and nearby forward distance", function () {
  assert.equal(Core.hitTest(0, 0.2, 12), true);
  assert.equal(Core.hitTest(0, 0.5, 12), false);
  assert.equal(Core.hitTest(0, 0.1, 50), false);
  assert.equal(Core.hitTest(0, 0.1, -1), false);
});

test("projectRoadPoint grows toward the player", function () {
  const far = Core.projectRoadPoint(1, 200, 900, 40, 500, 220);
  const near = Core.projectRoadPoint(0, 200, 900, 40, 500, 220);
  assert.ok(near.y > far.y);
  assert.ok(near.width > far.width);
});
