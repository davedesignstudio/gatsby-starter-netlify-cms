(function () {
  'use strict'

  const Core = window.CartDashCore
  const canvas = document.getElementById('gameCanvas')
  const ctx = canvas.getContext('2d')
  const viewport = document.getElementById('gameViewport')
  const menuScreen = document.getElementById('menuScreen')
  const raceHud = document.getElementById('raceHud')
  const touchControls = document.getElementById('touchControls')
  const countdown = document.getElementById('countdown')
  const resultsScreen = document.getElementById('resultsScreen')
  const pauseDialog = document.getElementById('pauseDialog')
  const howToDialog = document.getElementById('howToDialog')
  const boostButton = document.getElementById('boostButton')

  const hud = {
    place: document.getElementById('placeValue'),
    distance: document.getElementById('distanceValue'),
    progress: document.getElementById('progressFill'),
    supplies: document.getElementById('supplyValue'),
    speed: document.getElementById('speedValue'),
    boost: document.getElementById('boostFill'),
  }

  const results = {
    eyebrow: document.getElementById('resultsEyebrow'),
    place: document.getElementById('resultsPlace'),
    title: document.getElementById('resultsTitle'),
    message: document.getElementById('resultsMessage'),
    supplies: document.getElementById('finalSupplies'),
    time: document.getElementById('finalTime'),
    combo: document.getElementById('finalCombo'),
    impact: document.getElementById('impactMessage'),
  }

  let width = 390
  let height = 844
  let pixelRatio = 1
  let mode = 'menu'
  let race = Core.createRaceState()
  let entities = []
  let particles = []
  let lastFrame = performance.now()
  let ambientTime = 0
  let spawnTimer = 0
  let boostHeld = false
  let toastTimer = 0
  let pointerStart = null
  let nextEntityId = 0
  let finishTimer = 0
  let screenShake = 0

  class GameAudio {
    constructor() {
      this.context = null
      this.muted = false
    }

    unlock() {
      if (this.muted) return
      const AudioContext = window.AudioContext || window.webkitAudioContext
      if (!AudioContext) return
      if (!this.context) this.context = new AudioContext()
      if (this.context.state === 'suspended') this.context.resume()
    }

    tone(frequency, duration, type, volume, delay) {
      if (this.muted) return
      this.unlock()
      if (!this.context) return
      const start = this.context.currentTime + (delay || 0)
      const oscillator = this.context.createOscillator()
      const gain = this.context.createGain()
      oscillator.type = type || 'square'
      oscillator.frequency.setValueAtTime(frequency, start)
      gain.gain.setValueAtTime(0.0001, start)
      gain.gain.exponentialRampToValueAtTime(volume || 0.045, start + 0.012)
      gain.gain.exponentialRampToValueAtTime(0.0001, start + duration)
      oscillator.connect(gain)
      gain.connect(this.context.destination)
      oscillator.start(start)
      oscillator.stop(start + duration + 0.02)
    }

    collect(doubleValue) {
      this.tone(doubleValue ? 680 : 520, 0.1, 'square', 0.035)
      this.tone(doubleValue ? 920 : 720, 0.13, 'square', 0.03, 0.07)
    }

    hit() {
      this.tone(110, 0.24, 'sawtooth', 0.055)
      this.tone(75, 0.3, 'square', 0.035, 0.04)
    }

    move() {
      this.tone(260, 0.045, 'triangle', 0.018)
    }

    countdown(value) {
      this.tone(value === 'GO!' ? 660 : 330, value === 'GO!' ? 0.34 : 0.12, 'square', 0.045)
      if (value === 'GO!') this.tone(880, 0.3, 'square', 0.03, 0.08)
    }

    finish(place) {
      const notes = place === 1 ? [520, 660, 780, 1040] : [440, 520, 660, 780]
      notes.forEach((note, index) => this.tone(note, 0.22, 'square', 0.035, index * 0.11))
    }
  }

  const audio = new GameAudio()

  function resizeCanvas() {
    const rect = viewport.getBoundingClientRect()
    width = Math.max(1, rect.width)
    height = Math.max(1, rect.height)
    pixelRatio = Math.min(window.devicePixelRatio || 1, 2)
    canvas.width = Math.round(width * pixelRatio)
    canvas.height = Math.round(height * pixelRatio)
    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)
  }

  function roundedRect(context, x, y, w, h, radius) {
    const r = Math.min(radius, Math.abs(w) / 2, Math.abs(h) / 2)
    context.beginPath()
    context.roundRect(x, y, w, h, r)
  }

  function drawStore(scroll) {
    const horizon = height * 0.255
    const floorGradient = ctx.createLinearGradient(0, horizon, 0, height)
    floorGradient.addColorStop(0, '#d8d0b4')
    floorGradient.addColorStop(1, '#fff6d8')
    ctx.fillStyle = '#244b39'
    ctx.fillRect(0, 0, width, height)

    drawCeiling(horizon, scroll)

    ctx.fillStyle = floorGradient
    ctx.beginPath()
    ctx.moveTo(width * 0.36, horizon)
    ctx.lineTo(width * 0.64, horizon)
    ctx.lineTo(width * 1.08, height)
    ctx.lineTo(-width * 0.08, height)
    ctx.closePath()
    ctx.fill()

    drawFloorTiles(horizon, scroll)
    drawShelves(horizon, scroll)
    drawLaneMarkers(horizon, scroll)
    drawHorizonSign(horizon)
  }

  function drawCeiling(horizon, scroll) {
    ctx.fillStyle = '#315b47'
    ctx.fillRect(0, 0, width, horizon + 2)

    ctx.strokeStyle = 'rgba(255,247,225,.12)'
    ctx.lineWidth = 1
    for (let i = -4; i <= 4; i += 1) {
      ctx.beginPath()
      ctx.moveTo(width / 2, horizon)
      ctx.lineTo(width / 2 + i * width * 0.25, 0)
      ctx.stroke()
    }

    for (let i = 0; i < 4; i += 1) {
      const y = 20 + i * horizon * 0.25
      const factor = 1 - y / horizon
      ctx.fillStyle = 'rgba(255,248,207,.78)'
      roundedRect(ctx, width * (0.45 - factor * 0.11), y, width * (0.1 + factor * 0.22), 5 + factor * 7, 3)
      ctx.fill()
    }

    const signShift = (scroll * 0.08) % 1
    ctx.fillStyle = 'rgba(15,38,27,.28)'
    ctx.fillRect(0, horizon - 4 + signShift, width, 5)
  }

  function drawFloorTiles(horizon, scroll) {
    const cycle = 18
    const offset = (scroll * 2.4) % cycle
    ctx.strokeStyle = 'rgba(43,66,52,.13)'
    ctx.lineWidth = 1

    for (let i = 0; i < 15; i += 1) {
      const t = ((i * cycle + offset) % (15 * cycle)) / (15 * cycle)
      const eased = t * t
      const y = horizon + eased * (height - horizon)
      ctx.beginPath()
      ctx.moveTo(width * 0.36 * (1 - eased) - width * 0.08 * eased, y)
      ctx.lineTo(width * 0.64 * (1 - eased) + width * 1.08 * eased, y)
      ctx.stroke()
    }

    for (let lane = -4; lane <= 4; lane += 1) {
      ctx.beginPath()
      ctx.moveTo(width / 2 + lane * width * 0.035, horizon)
      ctx.lineTo(width / 2 + lane * width * 0.17, height)
      ctx.stroke()
    }
  }

  function drawShelves(horizon, scroll) {
    drawShelfSide(true, horizon, scroll)
    drawShelfSide(false, horizon, scroll)
  }

  function drawShelfSide(left, horizon, scroll) {
    const edge = left ? 0 : width
    const innerTop = left ? width * 0.355 : width * 0.645
    const innerBottom = left ? -width * 0.04 : width * 1.04
    const direction = left ? 1 : -1

    ctx.fillStyle = left ? '#b94d32' : '#286985'
    ctx.beginPath()
    ctx.moveTo(edge, horizon * 0.47)
    ctx.lineTo(innerTop, horizon)
    ctx.lineTo(innerBottom, height)
    ctx.lineTo(edge, height)
    ctx.closePath()
    ctx.fill()

    ctx.fillStyle = 'rgba(23,37,29,.23)'
    for (let row = 0; row < 4; row += 1) {
      const topY = horizon * (0.51 + row * 0.12)
      const bottomY = height * (0.42 + row * 0.18)
      ctx.beginPath()
      ctx.moveTo(edge, topY)
      ctx.lineTo(innerTop, horizon + row * 4)
      ctx.lineTo(innerBottom, bottomY)
      ctx.lineTo(edge, bottomY + 24)
      ctx.closePath()
      ctx.fill()
    }

    const productColors = ['#f6c957', '#fff7e1', '#74b59a', '#ef7657', '#e89ab0']
    for (let depth = 0; depth < 9; depth += 1) {
      const phase = ((depth * 0.12 + (scroll * 0.0015)) % 1)
      const y = horizon + phase * phase * (height - horizon)
      const scale = 0.18 + phase * 0.88
      const innerX = width / 2 + direction * (width * 0.14 + phase * width * 0.39)
      const productWidth = 12 * scale
      const productHeight = 24 * scale
      for (let row = 0; row < 3; row += 1) {
        const x = innerX + direction * (row * productWidth * 1.18 + 8 * scale)
        ctx.fillStyle = productColors[(depth + row + (left ? 0 : 2)) % productColors.length]
        roundedRect(ctx, x - productWidth / 2, y - productHeight - row * 2, productWidth, productHeight, 2 * scale)
        ctx.fill()
        ctx.fillStyle = 'rgba(23,37,29,.22)'
        ctx.fillRect(x - productWidth / 2, y - 6 * scale - row * 2, productWidth, 2 * scale)
      }
    }

    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = Math.max(2, width * 0.008)
    ctx.beginPath()
    ctx.moveTo(innerTop, horizon)
    ctx.lineTo(innerBottom, height)
    ctx.stroke()
  }

  function drawLaneMarkers(horizon, scroll) {
    for (const laneBoundary of [-0.5, 0.5]) {
      for (let index = 0; index < 9; index += 1) {
        const raw = ((index * 0.14 + scroll * 0.006) % 1)
        const start = raw * raw
        const endRaw = Math.min(1, raw + 0.055 + raw * 0.025)
        const end = endRaw * endRaw
        const startY = horizon + start * (height - horizon)
        const endY = horizon + end * (height - horizon)
        const startHalf = width * (0.105 + raw * 0.38)
        const endHalf = width * (0.105 + endRaw * 0.38)
        ctx.fillStyle = 'rgba(255,255,255,.66)'
        ctx.beginPath()
        ctx.moveTo(width / 2 + laneBoundary * startHalf, startY)
        ctx.lineTo(width / 2 + laneBoundary * endHalf - 2, endY)
        ctx.lineTo(width / 2 + laneBoundary * endHalf + 2, endY)
        ctx.lineTo(width / 2 + laneBoundary * startHalf + 0.6, startY)
        ctx.closePath()
        ctx.fill()
      }
    }
  }

  function drawHorizonSign(horizon) {
    const signWidth = Math.min(80, width * 0.22)
    ctx.fillStyle = '#f6c957'
    roundedRect(ctx, width / 2 - signWidth / 2, horizon - 31, signWidth, 20, 3)
    ctx.fill()
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 2
    ctx.stroke()
    ctx.fillStyle = '#17251d'
    ctx.font = '900 7px "Avenir Next", sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText('CHECKOUT  →', width / 2, horizon - 18)
  }

  function drawEntity(entity) {
    const projected = Core.projectEntity(entity.z, entity.lane, width, height)
    if (!projected.visible) return
    ctx.save()
    ctx.translate(projected.x, projected.y)
    ctx.scale(projected.scale, projected.scale)
    if (entity.type === 'supply') drawSupplyBag(false)
    if (entity.type === 'doubleSupply') drawSupplyBag(true)
    if (entity.type === 'boost') drawBoostPad()
    if (entity.type === 'box') drawBox()
    if (entity.type === 'spill') drawSpill()
    if (entity.type === 'cone') drawCone()
    ctx.restore()
  }

  function drawSupplyBag(doubleValue) {
    ctx.save()
    ctx.rotate(-0.04)
    ctx.shadowColor = 'rgba(17,30,21,.28)'
    ctx.shadowBlur = 7
    ctx.shadowOffsetY = 5
    ctx.fillStyle = doubleValue ? '#ef5b37' : '#f6c957'
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 3
    roundedRect(ctx, -17, -26, 34, 37, 5)
    ctx.fill()
    ctx.stroke()
    ctx.shadowColor = 'transparent'
    ctx.beginPath()
    ctx.arc(0, -25, 9, Math.PI, 0)
    ctx.stroke()
    ctx.fillStyle = '#fff7e1'
    ctx.beginPath()
    ctx.moveTo(0, -12)
    ctx.bezierCurveTo(-11, -20, -15, -5, 0, 5)
    ctx.bezierCurveTo(15, -5, 11, -20, 0, -12)
    ctx.fill()
    if (doubleValue) {
      ctx.fillStyle = '#17251d'
      ctx.font = '900 8px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('×2', 0, 9)
    }
    ctx.restore()
  }

  function drawBoostPad() {
    ctx.shadowColor = 'rgba(17,30,21,.25)'
    ctx.shadowBlur = 7
    ctx.shadowOffsetY = 5
    ctx.fillStyle = '#3485a8'
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo(-25, -9)
    ctx.lineTo(25, -9)
    ctx.lineTo(19, 12)
    ctx.lineTo(-19, 12)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
    ctx.shadowColor = 'transparent'
    ctx.fillStyle = '#f6c957'
    for (let x = -12; x <= 12; x += 12) {
      ctx.beginPath()
      ctx.moveTo(x - 5, 6)
      ctx.lineTo(x + 1, -4)
      ctx.lineTo(x + 6, 6)
      ctx.closePath()
      ctx.fill()
    }
  }

  function drawBox() {
    ctx.fillStyle = '#b87b4d'
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 3
    ctx.shadowColor = 'rgba(17,30,21,.3)'
    ctx.shadowBlur = 7
    ctx.shadowOffsetY = 5
    ctx.fillRect(-22, -31, 44, 42)
    ctx.strokeRect(-22, -31, 44, 42)
    ctx.shadowColor = 'transparent'
    ctx.fillStyle = '#d6a06b'
    ctx.fillRect(-3, -30, 7, 40)
    ctx.strokeStyle = 'rgba(23,37,29,.55)'
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(-17, -22)
    ctx.lineTo(-8, -13)
    ctx.moveTo(-8, -22)
    ctx.lineTo(-17, -13)
    ctx.stroke()
  }

  function drawSpill() {
    ctx.fillStyle = 'rgba(52,133,168,.75)'
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.ellipse(0, 2, 28, 10, 0, 0, Math.PI * 2)
    ctx.ellipse(-19, -2, 10, 7, -0.4, 0, Math.PI * 2)
    ctx.ellipse(20, 2, 9, 5, 0.2, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()
    ctx.fillStyle = 'rgba(255,255,255,.48)'
    ctx.beginPath()
    ctx.ellipse(-7, -1, 8, 2, -0.1, 0, Math.PI * 2)
    ctx.fill()
  }

  function drawCone() {
    ctx.fillStyle = '#ef5b37'
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo(0, -34)
    ctx.lineTo(17, 7)
    ctx.lineTo(-17, 7)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
    ctx.fillStyle = '#fff7e1'
    ctx.beginPath()
    ctx.moveTo(-7, -13)
    ctx.lineTo(8, -13)
    ctx.lineTo(12, -3)
    ctx.lineTo(-11, -3)
    ctx.closePath()
    ctx.fill()
    ctx.fillStyle = '#17251d'
    roundedRect(ctx, -23, 5, 46, 8, 3)
    ctx.fill()
  }

  function drawCart(x, y, scale, color, lean, label) {
    ctx.save()
    ctx.translate(x, y)
    ctx.scale(scale, scale)
    ctx.rotate(lean || 0)

    ctx.fillStyle = 'rgba(20,31,24,.25)'
    ctx.beginPath()
    ctx.ellipse(0, 25, 48, 13, 0, 0, Math.PI * 2)
    ctx.fill()

    ctx.fillStyle = '#17251d'
    ctx.beginPath()
    ctx.arc(-29, 20, 8, 0, Math.PI * 2)
    ctx.arc(29, 20, 8, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = '#d9e1d8'
    ctx.beginPath()
    ctx.arc(-29, 20, 3, 0, Math.PI * 2)
    ctx.arc(29, 20, 3, 0, Math.PI * 2)
    ctx.fill()

    ctx.fillStyle = '#71503c'
    roundedRect(ctx, -23, -52, 46, 47, 16)
    ctx.fill()
    ctx.fillStyle = '#c48259'
    ctx.beginPath()
    ctx.arc(0, -67, 16, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = '#4c3428'
    ctx.beginPath()
    ctx.arc(0, -63, 17, 0.1, Math.PI - 0.1)
    ctx.lineTo(12, -48)
    ctx.lineTo(-12, -48)
    ctx.closePath()
    ctx.fill()
    ctx.fillStyle = color
    ctx.beginPath()
    ctx.ellipse(0, -80, 20, 8, 0, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillRect(-19, -81, 30, 7)
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 4
    ctx.beginPath()
    ctx.moveTo(-17, -27)
    ctx.lineTo(-36, -5)
    ctx.moveTo(17, -27)
    ctx.lineTo(36, -5)
    ctx.stroke()

    ctx.fillStyle = color
    ctx.strokeStyle = '#17251d'
    ctx.lineWidth = 4
    ctx.beginPath()
    ctx.moveTo(-42, -5)
    ctx.lineTo(42, -5)
    ctx.lineTo(33, 17)
    ctx.lineTo(-32, 17)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()

    ctx.strokeStyle = 'rgba(255,247,225,.6)'
    ctx.lineWidth = 2
    for (let gx = -25; gx <= 25; gx += 12) {
      ctx.beginPath()
      ctx.moveTo(gx, -3)
      ctx.lineTo(gx * 0.78, 15)
      ctx.stroke()
    }
    ctx.beginPath()
    ctx.moveTo(-37, 5)
    ctx.lineTo(37, 5)
    ctx.stroke()

    ctx.fillStyle = '#f6c957'
    ctx.beginPath()
    ctx.arc(-11, -3, 8, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = '#ef5b37'
    roundedRect(ctx, 3, -11, 18, 13, 3)
    ctx.fill()

    if (label) {
      ctx.fillStyle = '#fff7e1'
      ctx.strokeStyle = '#17251d'
      ctx.lineWidth = 3
      ctx.font = '900 8px "Avenir Next", sans-serif'
      ctx.textAlign = 'center'
      ctx.strokeText(label, 0, 36)
      ctx.fillText(label, 0, 36)
    }
    ctx.restore()
  }

  function drawRivals() {
    race.rivals.forEach(function (rival, index) {
      const relative = rival.distance - race.distance
      const z = 23 + relative
      if (z < 3 || z > Core.MAX_VISIBLE_DISTANCE) return
      const lane = rival.lane
      const projected = Core.projectEntity(z, lane, width, height)
      drawCart(projected.x, projected.y, projected.scale * 0.78, rival.color, 0, rival.name.toUpperCase())
      ctx.fillStyle = 'rgba(23,37,29,.82)'
      roundedRect(ctx, projected.x - 17 * projected.scale, projected.y - 85 * projected.scale, 34 * projected.scale, 10 * projected.scale, 4)
      ctx.fill()
    })
  }

  function drawPlayer() {
    const bottomHalfWidth = width * (0.105 + 0.92 * 0.38)
    const playerX = width / 2 + race.lane * bottomHalfWidth * 0.58
    const playerY = height * 0.79 + Math.sin(ambientTime * 10) * 1.3
    const lean = (race.targetLane - race.lane) * 0.13

    if (boostHeld && race.boost > 0 && mode === 'race') {
      for (let index = 0; index < 4; index += 1) {
        ctx.fillStyle = index % 2 ? '#ef5b37' : '#f6c957'
        ctx.beginPath()
        const flameX = playerX + (index - 1.5) * 12 + (Math.random() - 0.5) * 5
        ctx.moveTo(flameX - 4, playerY + 28)
        ctx.lineTo(flameX + 4, playerY + 28)
        ctx.lineTo(flameX, playerY + 45 + Math.random() * 12)
        ctx.fill()
      }
    }
    drawCart(playerX, playerY, Math.min(1.05, height / 760), '#3485a8', lean, '')
  }

  function drawAmbient() {
    const lane = Math.sin(ambientTime * 0.35) * 0.25
    const bottomHalfWidth = width * 0.45
    drawCart(width / 2 + lane * bottomHalfWidth, height * 0.82, Math.min(1.1, height / 730), '#3485a8', Math.sin(ambientTime) * 0.02, '')
  }

  function drawParticles(delta) {
    particles = particles.filter(function (particle) {
      particle.life -= delta
      if (particle.life <= 0) return false
      particle.x += particle.vx * delta
      particle.y += particle.vy * delta
      particle.vy += 45 * delta
      ctx.globalAlpha = Core.clamp(particle.life * 2, 0, 1)
      ctx.fillStyle = particle.color
      ctx.save()
      ctx.translate(particle.x, particle.y)
      ctx.rotate(particle.life * 7)
      ctx.fillRect(-particle.size / 2, -particle.size / 2, particle.size, particle.size)
      ctx.restore()
      ctx.globalAlpha = 1
      return true
    })
  }

  function burst(x, y, colors, count) {
    for (let index = 0; index < count; index += 1) {
      const angle = Math.random() * Math.PI * 2
      const speed = 45 + Math.random() * 100
      particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 50,
        life: 0.45 + Math.random() * 0.4,
        color: colors[index % colors.length],
        size: 3 + Math.random() * 6,
      })
    }
  }

  function render(delta) {
    ctx.save()
    if (screenShake > 0) {
      ctx.translate((Math.random() - 0.5) * screenShake, (Math.random() - 0.5) * screenShake)
      screenShake = Math.max(0, screenShake - delta * 30)
    }
    const scroll = mode === 'race' || mode === 'countdown' || mode === 'finish' ? race.distance : ambientTime * 11
    drawStore(scroll)

    if (mode === 'menu') {
      drawAmbient()
    } else {
      entities
        .slice()
        .sort(function (a, b) { return b.z - a.z })
        .forEach(drawEntity)
      drawRivals()
      drawPlayer()
    }
    drawParticles(delta)
    ctx.restore()
  }

  function updateRace(delta) {
    race.elapsed += delta
    race.hitTimer = Math.max(0, race.hitTimer - delta)
    race.lane += (race.targetLane - race.lane) * Math.min(1, delta * 9)

    const boosting = boostHeld && race.boost > 0.5 && race.hitTimer <= 0
    const targetSpeed = race.hitTimer > 0 ? 10.5 : boosting ? 32 : 20
    race.speed += (targetSpeed - race.speed) * Math.min(1, delta * 4.5)
    race.distance += race.speed * delta

    if (boosting) {
      race.boost = Math.max(0, race.boost - delta * 24)
      if (Math.random() < delta * 14) {
        const bottomHalfWidth = width * 0.45
        burst(width / 2 + race.lane * bottomHalfWidth * 0.58, height * 0.83, ['#f6c957', '#ef5b37'], 1)
      }
    } else {
      race.boost = Math.min(100, race.boost + delta * 5.5)
    }

    race.rivals.forEach(function (rival, index) {
      const rubberBand = Core.clamp((race.distance - rival.distance) * 0.018, -1.6, 1.9)
      rival.distance += (rival.pace + rubberBand + Math.sin(race.elapsed * 0.65 + index * 2) * 0.8) * delta
      if (race.elapsed > rival.nextLaneChange) {
        rival.lane = Core.LANES[Math.floor(Math.random() * Core.LANES.length)]
        rival.nextLaneChange = race.elapsed + 3.5 + Math.random() * 4
      }
    })

    spawnTimer -= delta
    if (spawnTimer <= 0) {
      spawnEntity()
      spawnTimer = Math.max(0.48, 0.8 - (race.distance / Core.GOAL_DISTANCE) * 0.18) + Math.random() * 0.3
    }

    entities.forEach(function (entity) {
      entity.z -= race.speed * delta * 1.23
      if (!entity.resolved && entity.z < 5 && entity.z > -6 && Math.abs(race.lane - entity.lane) < 0.47) {
        resolveCollision(entity)
      }
    })
    entities = entities.filter(function (entity) { return entity.z > -8 })

    updateHud()
    if (race.distance >= Core.GOAL_DISTANCE) beginFinish()
  }

  function spawnEntity() {
    let lane = Core.LANES[Math.floor(Math.random() * Core.LANES.length)]
    const nearby = entities.filter(function (entity) { return entity.z > 112 })
    if (nearby.some(function (entity) { return entity.lane === lane })) {
      lane = Core.LANES.filter(function (candidate) {
        return !nearby.some(function (entity) { return entity.lane === candidate })
      })[0] ?? lane
    }
    entities.push({
      id: nextEntityId += 1,
      type: Core.pickEntity(Math.random(), race.distance),
      lane: lane,
      z: Core.MAX_VISIBLE_DISTANCE,
      resolved: false,
    })

    if (race.distance > 220 && Math.random() < 0.22) {
      const openLanes = Core.LANES.filter(function (candidate) { return candidate !== lane })
      entities.push({
        id: nextEntityId += 1,
        type: Math.random() < 0.48 ? 'supply' : Core.pickEntity(0.72 + Math.random() * 0.25, race.distance),
        lane: openLanes[Math.floor(Math.random() * openLanes.length)],
        z: Core.MAX_VISIBLE_DISTANCE + 1,
        resolved: false,
      })
    }
  }

  function resolveCollision(entity) {
    entity.resolved = true
    const projected = Core.projectEntity(entity.z, entity.lane, width, height)
    if (entity.type === 'supply' || entity.type === 'doubleSupply') {
      const value = entity.type === 'doubleSupply' ? 2 : 1
      race.supplies += value
      race.combo += 1
      race.bestCombo = Math.max(race.bestCombo, race.combo)
      race.boost = Math.min(100, race.boost + 8 * value)
      burst(projected.x, projected.y, ['#f6c957', '#fff7e1', '#ef5b37'], 11)
      audio.collect(value === 2)
      haptic(18)
      showToast(race.combo > 2 ? `×${race.combo} COMBO!` : value === 2 ? 'DOUBLE!' : 'BAGGED!', `+${value} ${value === 1 ? 'supply' : 'supplies'}`)
    } else if (entity.type === 'boost') {
      race.boost = Math.min(100, race.boost + 36)
      race.combo += 1
      race.bestCombo = Math.max(race.bestCombo, race.combo)
      burst(projected.x, projected.y, ['#3485a8', '#f6c957', '#fff7e1'], 12)
      audio.collect(true)
      haptic([12, 20, 12])
      showToast('FULL CHARGE!', '+36 boost')
    } else {
      race.hitTimer = entity.type === 'spill' ? 1.25 : 0.9
      race.combo = 0
      race.speed = Math.min(race.speed, 11)
      screenShake = entity.type === 'spill' ? 8 : 13
      burst(projected.x, projected.y, ['#b87b4d', '#ef5b37', '#17251d'], 15)
      audio.hit()
      haptic([45, 25, 45])
      showToast(entity.type === 'spill' ? 'SLIPPERY!' : 'CART JAM!', 'Keep moving')
    }
    entity.z = -20
  }

  function updateHud() {
    const placement = Core.calculatePlacement(race.distance, race.rivals.map(function (rival) { return rival.distance }))
    hud.place.textContent = Core.ordinal(placement)
    hud.distance.textContent = `${Math.min(Core.GOAL_DISTANCE, Math.floor(race.distance)).toLocaleString()} / 1,200 m`
    hud.progress.style.width = `${Core.clamp(race.distance / Core.GOAL_DISTANCE * 100, 0, 100)}%`
    hud.supplies.textContent = race.supplies
    hud.speed.textContent = Math.round(race.speed * 2.25)
    hud.boost.style.height = `${race.boost}%`
    boostButton.classList.toggle('is-active', boostHeld && race.boost > 0)
  }

  function moveLane(direction) {
    if (mode !== 'race') return
    const previous = race.targetLane
    race.targetLane = Core.clamp(race.targetLane + direction, -1, 1)
    if (race.targetLane !== previous) {
      audio.move()
      haptic(10)
    }
  }

  function resetRace() {
    race = Core.createRaceState()
    race.rivals.forEach(function (rival, index) {
      rival.lane = Core.LANES[index]
      rival.nextLaneChange = 2.5 + index
    })
    entities = []
    particles = []
    spawnTimer = 0.45
    boostHeld = false
    finishTimer = 0
    updateHud()
  }

  function startRace() {
    audio.unlock()
    resetRace()
    menuScreen.classList.add('is-leaving')
    resultsScreen.classList.add('is-hidden')
    howToDialog.classList.add('is-hidden')
    raceHud.classList.remove('is-hidden')
    touchControls.classList.add('is-hidden')
    mode = 'countdown'
    window.setTimeout(function () {
      menuScreen.classList.add('is-hidden')
      menuScreen.classList.remove('is-leaving')
      runCountdown()
    }, 260)
  }

  function runCountdown() {
    const values = ['3', '2', '1', 'GO!']
    let index = 0
    countdown.classList.remove('is-hidden')
    function tick() {
      const value = values[index]
      countdown.textContent = value
      countdown.style.animation = 'none'
      void countdown.offsetHeight
      countdown.style.animation = ''
      audio.countdown(value)
      if (value === 'GO!') {
        countdown.style.fontSize = '105px'
      } else {
        countdown.style.fontSize = ''
      }
      index += 1
      if (index < values.length) {
        window.setTimeout(tick, 650)
      } else {
        window.setTimeout(function () {
          countdown.classList.add('is-hidden')
          countdown.style.fontSize = ''
          touchControls.classList.remove('is-hidden')
          mode = 'race'
        }, 520)
      }
    }
    tick()
  }

  function beginFinish() {
    if (mode !== 'race') return
    mode = 'finish'
    boostHeld = false
    touchControls.classList.add('is-hidden')
    finishTimer = 1.1
    hud.progress.style.width = '100%'
  }

  function showResults() {
    const placement = Core.calculatePlacement(race.distance, race.rivals.map(function (rival) { return rival.distance }))
    const suffix = Core.ordinal(placement).replace(String(placement), '').toUpperCase()
    const messages = {
      1: ['Aisle legend!', 'You brought the goods home.'],
      2: ['So close!', 'A strong run and a cart full of supplies.'],
      3: ['Solid hustle!', 'The pantry still wins tonight.'],
      4: ['Cart with heart!', 'Every supply collected counts.'],
    }
    const copy = messages[placement] || messages[4]
    results.eyebrow.textContent = placement === 1 ? 'MARKET MILE CHAMPION' : 'RUN COMPLETE'
    results.place.innerHTML = `${placement}<sup>${suffix}</sup>`
    results.title.textContent = copy[0]
    results.message.textContent = copy[1]
    results.supplies.textContent = race.supplies
    results.time.textContent = Core.formatTime(race.elapsed)
    results.combo.textContent = `×${race.bestCombo}`
    results.impact.textContent = race.supplies >= 14
      ? 'Pantry shelves fully restocked!'
      : race.supplies >= 7
        ? 'A full crate delivered!'
        : 'Every little bit helps!'
    raceHud.classList.add('is-hidden')
    resultsScreen.classList.remove('is-hidden')
    audio.finish(placement)
    haptic([30, 35, 30, 35, 80])
    mode = 'results'
  }

  function showMenu() {
    mode = 'menu'
    boostHeld = false
    menuScreen.classList.remove('is-hidden', 'is-leaving')
    resultsScreen.classList.add('is-hidden')
    pauseDialog.classList.add('is-hidden')
    raceHud.classList.add('is-hidden')
    touchControls.classList.add('is-hidden')
    entities = []
    particles = []
  }

  function pauseRace() {
    if (mode !== 'race') return
    mode = 'paused'
    boostHeld = false
    pauseDialog.classList.remove('is-hidden')
    touchControls.classList.add('is-hidden')
  }

  function resumeRace() {
    if (mode !== 'paused') return
    pauseDialog.classList.add('is-hidden')
    touchControls.classList.remove('is-hidden')
    lastFrame = performance.now()
    mode = 'race'
  }

  function showToast(title, copy) {
    const toast = document.getElementById('gameToast')
    document.getElementById('toastTitle').textContent = title
    document.getElementById('toastCopy').textContent = copy
    toast.classList.remove('is-hidden')
    window.clearTimeout(toastTimer)
    toastTimer = window.setTimeout(function () {
      toast.classList.add('is-hidden')
    }, 950)
  }

  function haptic(pattern) {
    if (navigator.vibrate) navigator.vibrate(pattern)
  }

  function setBoost(active) {
    boostHeld = active && mode === 'race'
    boostButton.classList.toggle('is-active', boostHeld)
  }

  function animate(now) {
    const delta = Math.min(0.035, (now - lastFrame) / 1000 || 0)
    lastFrame = now
    ambientTime += delta
    if (mode === 'race') updateRace(delta)
    if (mode === 'finish') {
      finishTimer -= delta
      race.distance += race.speed * delta * 0.45
      race.speed += (8 - race.speed) * Math.min(1, delta * 2)
      if (finishTimer <= 0) showResults()
    }
    render(delta)
    requestAnimationFrame(animate)
  }

  document.getElementById('playButton').addEventListener('click', startRace)
  document.getElementById('raceAgainButton').addEventListener('click', startRace)
  document.getElementById('homeButton').addEventListener('click', showMenu)
  document.getElementById('pauseButton').addEventListener('click', pauseRace)
  document.getElementById('resumeButton').addEventListener('click', resumeRace)
  document.getElementById('quitButton').addEventListener('click', showMenu)
  document.getElementById('leftButton').addEventListener('pointerdown', function (event) {
    event.preventDefault()
    moveLane(-1)
  })
  document.getElementById('rightButton').addEventListener('pointerdown', function (event) {
    event.preventDefault()
    moveLane(1)
  })

  ;['pointerdown', 'touchstart'].forEach(function (eventName) {
    boostButton.addEventListener(eventName, function (event) {
      event.preventDefault()
      setBoost(true)
    }, { passive: false })
  })
  ;['pointerup', 'pointercancel', 'pointerleave', 'touchend', 'touchcancel'].forEach(function (eventName) {
    boostButton.addEventListener(eventName, function (event) {
      event.preventDefault()
      setBoost(false)
    }, { passive: false })
  })

  document.getElementById('howToButton').addEventListener('click', function () {
    howToDialog.classList.remove('is-hidden')
  })
  document.getElementById('howToClose').addEventListener('click', function () {
    howToDialog.classList.add('is-hidden')
  })
  document.getElementById('howToPlay').addEventListener('click', startRace)

  const soundButton = document.getElementById('soundButton')
  soundButton.addEventListener('click', function () {
    audio.muted = !audio.muted
    soundButton.setAttribute('aria-pressed', String(audio.muted))
    soundButton.setAttribute('aria-label', audio.muted ? 'Turn sound on' : 'Mute sound')
    if (!audio.muted) {
      audio.unlock()
      audio.tone(520, 0.1, 'square', 0.03)
    }
  })

  canvas.addEventListener('pointerdown', function (event) {
    if (mode !== 'race') return
    pointerStart = { x: event.clientX, y: event.clientY }
  })
  canvas.addEventListener('pointerup', function (event) {
    if (!pointerStart || mode !== 'race') return
    const deltaX = event.clientX - pointerStart.x
    if (Math.abs(deltaX) > 24) moveLane(deltaX > 0 ? 1 : -1)
    pointerStart = null
  })

  window.addEventListener('keydown', function (event) {
    if (['ArrowLeft', 'ArrowRight', ' ', 'Escape'].includes(event.key)) event.preventDefault()
    if (event.repeat && event.key !== ' ') return
    if (event.key === 'ArrowLeft' || event.key.toLowerCase() === 'a') moveLane(-1)
    if (event.key === 'ArrowRight' || event.key.toLowerCase() === 'd') moveLane(1)
    if (event.key === ' ') setBoost(true)
    if (event.key === 'Escape') {
      if (mode === 'race') pauseRace()
      else if (mode === 'paused') resumeRace()
    }
  })
  window.addEventListener('keyup', function (event) {
    if (event.key === ' ') setBoost(false)
  })

  document.addEventListener('visibilitychange', function () {
    if (document.hidden && mode === 'race') pauseRace()
  })
  window.addEventListener('resize', resizeCanvas)

  resizeCanvas()
  requestAnimationFrame(animate)
})()
