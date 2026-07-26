const assert = require('node:assert/strict')
const test = require('node:test')
const Core = require('../js/game-core.js')

test('clamp keeps values inside inclusive bounds', function () {
  assert.equal(Core.clamp(-4, 0, 10), 0)
  assert.equal(Core.clamp(6, 0, 10), 6)
  assert.equal(Core.clamp(14, 0, 10), 10)
})

test('ordinal handles normal and teen suffixes', function () {
  assert.equal(Core.ordinal(1), '1st')
  assert.equal(Core.ordinal(2), '2nd')
  assert.equal(Core.ordinal(3), '3rd')
  assert.equal(Core.ordinal(4), '4th')
  assert.equal(Core.ordinal(11), '11th')
  assert.equal(Core.ordinal(22), '22nd')
})

test('formatTime returns a compact race clock', function () {
  assert.equal(Core.formatTime(0), '0:00')
  assert.equal(Core.formatTime(65.9), '1:05')
  assert.equal(Core.formatTime(-10), '0:00')
})

test('placement counts only rivals ahead of the player', function () {
  assert.equal(Core.calculatePlacement(500, [499, 480, 450]), 1)
  assert.equal(Core.calculatePlacement(500, [510, 480, 530]), 3)
  assert.equal(Core.calculatePlacement(500, [500, 500, 500]), 1)
})

test('track projection grows and moves toward the viewer', function () {
  const far = Core.projectEntity(120, 1, 390, 844)
  const near = Core.projectEntity(10, 1, 390, 844)
  assert.ok(near.y > far.y)
  assert.ok(near.x > far.x)
  assert.ok(near.scale > far.scale)
  assert.equal(near.visible, true)
})

test('entity selection spans pickups and hazards', function () {
  assert.equal(Core.pickEntity(0.1, 0), 'supply')
  assert.equal(Core.pickEntity(0.3, 0), 'doubleSupply')
  assert.equal(Core.pickEntity(0.4, 0), 'boost')
  assert.equal(Core.pickEntity(0.6, 0), 'box')
  assert.equal(Core.pickEntity(0.75, 0), 'spill')
  assert.equal(Core.pickEntity(0.95, 0), 'cone')
})

test('new races receive independent state', function () {
  const first = Core.createRaceState()
  const second = Core.createRaceState()
  first.rivals[0].distance = 999
  assert.equal(second.distance, 0)
  assert.equal(second.rivals[0].distance, -9)
  assert.equal(second.boost, 72)
})
