(function (root, factory) {
  const api = factory()
  if (typeof module === 'object' && module.exports) module.exports = api
  else root.CartCore = api
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value))

  function angleDiff(target, current) {
    let value = (target - current + Math.PI) % (Math.PI * 2)
    if (value < 0) value += Math.PI * 2
    return value - Math.PI
  }

  function nearestOnLoop(point, loop) {
    let nearest = { x: 0, y: 0, distance: Infinity, progress: 0, segment: 0 }
    for (let index = 0; index < loop.length; index += 1) {
      const start = loop[index]
      const end = loop[(index + 1) % loop.length]
      const dx = end.x - start.x
      const dy = end.y - start.y
      const lengthSquared = dx * dx + dy * dy
      const t = lengthSquared ? clamp(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared, 0, 1) : 0
      const x = start.x + dx * t
      const y = start.y + dy * t
      const distance = Math.hypot(point.x - x, point.y - y)
      if (distance < nearest.distance) {
        nearest = { x, y, distance, progress: (index + t) / loop.length, segment: index, t }
      }
    }
    return nearest
  }

  function pointOnLoop(loop, progress) {
    const wrapped = ((progress % 1) + 1) % 1
    const scaled = wrapped * loop.length
    const index = Math.floor(scaled)
    const t = scaled - index
    const start = loop[index]
    const end = loop[(index + 1) % loop.length]
    return {
      x: start.x + (end.x - start.x) * t,
      y: start.y + (end.y - start.y) * t,
      angle: Math.atan2(end.y - start.y, end.x - start.x),
    }
  }

  function ordinal(value) {
    const mod100 = value % 100
    if (mod100 >= 11 && mod100 <= 13) return `${value}th`
    return `${value}${value % 10 === 1 ? 'st' : value % 10 === 2 ? 'nd' : value % 10 === 3 ? 'rd' : 'th'}`
  }

  function formatTime(milliseconds) {
    const safe = Math.max(0, milliseconds)
    const minutes = Math.floor(safe / 60000)
    const seconds = Math.floor((safe % 60000) / 1000)
    const hundredths = Math.floor((safe % 1000) / 10)
    return `${minutes}:${String(seconds).padStart(2, '0')}.${String(hundredths).padStart(2, '0')}`
  }

  return { clamp, angleDiff, nearestOnLoop, pointOnLoop, ordinal, formatTime }
})
