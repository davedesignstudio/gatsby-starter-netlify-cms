"use strict";

var test = require("node:test");
var assert = require("node:assert/strict");
var Core = require("./js/game-core");

test("clamp keeps values within a range", function () {
  assert.equal(Core.clamp(-2, 0, 10), 0);
  assert.equal(Core.clamp(6, 0, 10), 6);
  assert.equal(Core.clamp(14, 0, 10), 10);
});

test("forwardDistance wraps around a lap", function () {
  assert.equal(Core.forwardDistance(1800, 100, 1900), 200);
  assert.equal(Core.forwardDistance(200, 500, 1900), 300);
});

test("racePosition counts racers ahead", function () {
  assert.equal(Core.racePosition(500, [499, 700, 800, 200]), 3);
  assert.equal(Core.racePosition(900, [499, 700, 800, 200]), 1);
});

test("ordinal handles teens and common suffixes", function () {
  assert.equal(Core.ordinal(1), "ST");
  assert.equal(Core.ordinal(2), "ND");
  assert.equal(Core.ordinal(3), "RD");
  assert.equal(Core.ordinal(11), "TH");
  assert.equal(Core.ordinal(23), "RD");
});

test("formatTime creates race-clock text", function () {
  assert.equal(Core.formatTime(0), "0:00.00");
  assert.equal(Core.formatTime(65.429), "1:05.43");
});

test("seededRandom is deterministic and bounded", function () {
  var first = Core.seededRandom(42);
  var second = Core.seededRandom(42);
  for (var index = 0; index < 8; index += 1) {
    var value = first();
    assert.equal(value, second());
    assert.ok(value >= 0 && value < 1);
  }
});
