import test from "node:test";
import assert from "node:assert/strict";
import {
  TOTAL_LAPS,
  advanceProgress,
  calculatePosition,
  createRaceState,
  formatTime,
  ordinal,
  updatePlayer,
  usePowerUp,
  wrapProgress,
} from "../js/game-core.js";

test("progress wraps in both directions", () => {
  assert.equal(wrapProgress(1.2), .19999999999999996);
  assert.equal(wrapProgress(-.25), .75);
});

test("advancing over the finish line increments the lap", () => {
  const racer = { progress: .98, lap: 0 };
  advanceProgress(racer, .04);
  assert.ok(Math.abs(racer.progress - .02) < Number.EPSILON * 10);
  assert.equal(racer.lap, 1);
});

test("position compares combined lap and track progress", () => {
  const player = { lap: 1, progress: .1 };
  const opponents = [
    { lap: 1, progress: .2 },
    { lap: 0, progress: .9 },
    { lap: 1, progress: .05 },
  ];
  assert.equal(calculatePosition(player, opponents), 2);
});

test("race state contains two laps and three opponents", () => {
  const state = createRaceState(1);
  assert.equal(TOTAL_LAPS, 2);
  assert.equal(state.player.name, "Reina");
  assert.equal(state.opponents.length, 3);
  assert.equal(state.phase, "countdown");
});

test("player accelerates and steering stays inside the track", () => {
  const state = createRaceState();
  for (let frame = 0; frame < 600; frame += 1) {
    updatePlayer(state, { gas: true, left: false, right: true }, 1 / 60);
  }
  assert.ok(state.player.speed > 0);
  assert.equal(state.player.lane, 55);
  assert.ok(state.player.lap >= 1);
});

test("power-up is consumed and activates its effect", () => {
  const state = createRaceState();
  state.player.item = "boost";
  assert.equal(usePowerUp(state), "boost");
  assert.equal(state.player.item, null);
  assert.equal(state.player.boost, 2.2);
});

test("time and placing labels are formatted for the HUD", () => {
  assert.equal(formatTime(83456), "1:23.45");
  assert.equal(formatTime(-200), "0:00.00");
  assert.equal(ordinal(1), "1ST");
  assert.equal(ordinal(2), "2ND");
  assert.equal(ordinal(3), "3RD");
  assert.equal(ordinal(11), "11TH");
});
