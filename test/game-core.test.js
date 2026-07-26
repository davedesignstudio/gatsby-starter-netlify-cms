const test = require('node:test')
const assert = require('node:assert/strict')
const { angleDiff, clamp, formatTime, nearestOnLoop, ordinal, pointOnLoop } = require('../js/game-core')

const square = [
  { x: 0, y: 0 },
  { x: 100, y: 0 },
  { x: 100, y: 100 },
  { x: 0, y: 100 },
]

test('clamp keeps values inside the supplied range', () => {
  assert.equal(clamp(-2, 0, 10), 0)
  assert.equal(clamp(6, 0, 10), 6)
  assert.equal(clamp(12, 0, 10), 10)
})

test('angleDiff chooses the shortest turn across the wrap boundary', () => {
  assert.ok(Math.abs(angleDiff(-Math.PI + 0.1, Math.PI - 0.1) - 0.2) < 0.0001)
})

test('nearestOnLoop projects a point and reports normalized progress', () => {
  const nearest = nearestOnLoop({ x: 65, y: 12 }, square)
  assert.deepEqual({ x: nearest.x, y: nearest.y }, { x: 65, y: 0 })
  assert.equal(nearest.distance, 12)
  assert.equal(nearest.progress, 0.1625)
})

test('pointOnLoop wraps progress in either direction', () => {
  assert.deepEqual(pointOnLoop(square, 1.125), { x: 50, y: 0, angle: 0 })
  assert.deepEqual(pointOnLoop(square, -0.125), { x: 0, y: 50, angle: -Math.PI / 2 })
})

test('ordinal handles regular and teen suffixes', () => {
  assert.equal(ordinal(1), '1st')
  assert.equal(ordinal(2), '2nd')
  assert.equal(ordinal(3), '3rd')
  assert.equal(ordinal(11), '11th')
  assert.equal(ordinal(23), '23rd')
})

test('formatTime returns race clock minutes and hundredths', () => {
  assert.equal(formatTime(0), '0:00.00')
  assert.equal(formatTime(83456), '1:23.45')
})
