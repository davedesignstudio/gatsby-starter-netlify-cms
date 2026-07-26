import assert from "node:assert/strict";
import test from "node:test";

import {
  calculatePosition,
  clamp,
  createTrack,
  formatTime,
  nearestTrackPoint,
  ordinal,
  seededRandom,
  shortestAngle,
  trackPointAt,
  wrap,
} from "../js/game-core.js";

test("numeric helpers clamp and wrap values", () => {
  assert.equal(clamp(14, 0, 10), 10);
  assert.equal(clamp(-2, 0, 10), 0);
  assert.equal(wrap(-1, 10), 9);
  assert.equal(wrap(12, 10), 2);
});

test("formatters produce race-friendly labels", () => {
  assert.equal(formatTime(0), "0:00.00");
  assert.equal(formatTime(65432), "1:05.43");
  assert.equal(ordinal(1), "1st");
  assert.equal(ordinal(2), "2nd");
  assert.equal(ordinal(3), "3rd");
  assert.equal(ordinal(11), "11th");
  assert.equal(ordinal(22), "22nd");
});

test("seeded random sequences are deterministic", () => {
  const first = seededRandom(42);
  const second = seededRandom(42);
  assert.deepEqual(
    Array.from({ length: 8 }, () => first()),
    Array.from({ length: 8 }, () => second()),
  );
});

test("track points can be sampled and found again", () => {
  const track = createTrack(20);
  assert.equal(track.points.length, 200);
  assert.ok(track.length > 5000);

  const sample = trackPointAt(track, 0.375, 40);
  const nearest = nearestTrackPoint(track, sample.x, sample.y);
  assert.ok(Math.abs(nearest.progress - 0.375) < 0.02);
  assert.ok(nearest.distance >= 35 && nearest.distance <= 45);
});

test("track interpolation wraps at the start line", () => {
  const track = createTrack(20);
  const before = trackPointAt(track, -0.01);
  const wrapped = trackPointAt(track, 0.99);
  assert.ok(Math.hypot(before.x - wrapped.x, before.y - wrapped.y) < 0.001);
});

test("shortest angle crosses the positive-negative boundary", () => {
  const turn = shortestAngle(Math.PI - 0.1, -Math.PI + 0.1);
  assert.ok(Math.abs(turn - 0.2) < 0.0001);
});

test("race position counts only rivals with more total progress", () => {
  const rivals = [{ totalProgress: 1.2 }, { totalProgress: 0.8 }, { totalProgress: 1.6 }];
  assert.equal(calculatePosition(1.1, rivals), 3);
  assert.equal(calculatePosition(2, rivals), 1);
});
