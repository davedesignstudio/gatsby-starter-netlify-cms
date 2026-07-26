(function (root, factory) {
  const api = factory()
  if (typeof module === 'object' && module.exports) module.exports = api
  root.CartDashCore = api
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict'

  const GOAL_DISTANCE = 1200
  const MAX_VISIBLE_DISTANCE = 138
  const LANES = [-1, 0, 1]

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value))
  }

  function ordinal(value) {
    const number = Math.max(1, Math.floor(value))
    const remainder = number % 100
    if (remainder >= 11 && remainder <= 13) return `${number}th`
    if (number % 10 === 1) return `${number}st`
    if (number % 10 === 2) return `${number}nd`
    if (number % 10 === 3) return `${number}rd`
    return `${number}th`
  }

  function formatTime(totalSeconds) {
    const safeSeconds = Math.max(0, Math.floor(totalSeconds))
    const minutes = Math.floor(safeSeconds / 60)
    const seconds = String(safeSeconds % 60).padStart(2, '0')
    return `${minutes}:${seconds}`
  }

  function calculatePlacement(playerDistance, rivalDistances) {
    return 1 + rivalDistances.filter(function (distance) {
      return distance > playerDistance
    }).length
  }

  function projectEntity(z, lane, width, height) {
    const closeness = clamp(1 - z / MAX_VISIBLE_DISTANCE, 0, 1)
    const eased = closeness * closeness
    const horizon = height * 0.255
    const y = horizon + eased * height * 0.65
    const roadHalfWidth = width * (0.105 + closeness * 0.38)
    const x = width / 2 + lane * roadHalfWidth * 0.58
    return {
      x: x,
      y: y,
      scale: 0.18 + closeness * 1.05,
      visible: z >= -5 && z <= MAX_VISIBLE_DISTANCE,
    }
  }

  function pickEntity(randomValue, raceProgress) {
    const difficulty = clamp(raceProgress / GOAL_DISTANCE, 0, 1)
    if (randomValue < 0.25) return 'supply'
    if (randomValue < 0.34) return 'doubleSupply'
    if (randomValue < 0.44) return 'boost'
    if (randomValue < 0.66 + difficulty * 0.08) return 'box'
    if (randomValue < 0.83) return 'spill'
    return 'cone'
  }

  function createRaceState() {
    return {
      distance: 0,
      elapsed: 0,
      supplies: 0,
      combo: 0,
      bestCombo: 0,
      boost: 72,
      lane: 0,
      targetLane: 0,
      speed: 20,
      hitTimer: 0,
      rivals: [
        { name: 'Rosa', distance: -9, pace: 19.2, color: '#ef5b37' },
        { name: 'Junebug', distance: -16, pace: 20.1, color: '#875e9e' },
        { name: 'Old Gold', distance: -23, pace: 18.8, color: '#d5a836' },
      ],
    }
  }

  return {
    GOAL_DISTANCE: GOAL_DISTANCE,
    MAX_VISIBLE_DISTANCE: MAX_VISIBLE_DISTANCE,
    LANES: LANES,
    clamp: clamp,
    ordinal: ordinal,
    formatTime: formatTime,
    calculatePlacement: calculatePlacement,
    projectEntity: projectEntity,
    pickEntity: pickEntity,
    createRaceState: createRaceState,
  }
})
