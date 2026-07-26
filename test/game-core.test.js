import test from "node:test";
import assert from "node:assert/strict";
import {
  TOTAL_LAPS,
  TRACK_LENGTH,
  createTrackObjects,
  formatTime,
  lapForDistance,
  ordinalSuffix,
  playerPlace,
} from "../src/game-core.js";

test("formats race times", () => {
  assert.equal(formatTime(0), "00:00.00");
  assert.equal(formatTime(65.128), "01:05.13");
});

test("uses correct ordinal suffixes including teens", () => {
  assert.equal(ordinalSuffix(1), "st");
  assert.equal(ordinalSuffix(2), "nd");
  assert.equal(ordinalSuffix(3), "rd");
  assert.equal(ordinalSuffix(11), "th");
  assert.equal(ordinalSuffix(23), "rd");
});

test("calculates lap and finishing place", () => {
  assert.equal(lapForDistance(0), 1);
  assert.equal(lapForDistance(TRACK_LENGTH), 2);
  assert.equal(lapForDistance(TRACK_LENGTH * TOTAL_LAPS), TOTAL_LAPS);
  assert.equal(playerPlace(100, [{ distance: 120 }, { distance: 90 }, { distance: 200 }]), 3);
});

test("track generation is deterministic and spans every lap", () => {
  const first = createTrackObjects(42);
  const second = createTrackObjects(42);
  assert.deepEqual(first, second);
  assert.ok(first.some((object) => object.type === "boost"));
  assert.ok(first.some((object) => object.distance > TRACK_LENGTH * (TOTAL_LAPS - 1)));
});
