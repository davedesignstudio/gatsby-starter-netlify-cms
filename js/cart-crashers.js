/* global CartCore */
(function () {
  'use strict'

  const { clamp, angleDiff, nearestOnLoop, pointOnLoop, ordinal, formatTime } = CartCore
  const canvas = document.querySelector('#game')
  const ctx = canvas.getContext('2d')
  const shell = document.querySelector('#game-shell')
  const $ = (selector) => document.querySelector(selector)
  const screens = ['#start-screen', '#briefing-screen', '#finish-screen']
  const track = [
    { x: 320, y: 830 }, { x: 210, y: 640 }, { x: 225, y: 320 },
    { x: 430, y: 175 }, { x: 900, y: 170 }, { x: 1260, y: 280 },
    { x: 1370, y: 565 }, { x: 1210, y: 855 }, { x: 860, y: 985 },
    { x: 505, y: 945 },
  ]
  const trackLength = track.reduce((total, point, index) => {
    const next = track[(index + 1) % track.length]
    return total + Math.hypot(next.x - point.x, next.y - point.y)
  }, 0)
  const colors = ['#f04437', '#ffd24a', '#58d7b1', '#8f6be8', '#ff8d35', '#52a8ed']
  const aisleSigns = [
    { x: 520, y: 360, label: 'CEREAL', color: '#ffcd44' },
    { x: 830, y: 360, label: 'SNACKS', color: '#f04437' },
    { x: 1140, y: 360, label: 'FROZEN', color: '#53a8e8' },
    { x: 550, y: 640, label: 'PRODUCE', color: '#57c58c' },
    { x: 900, y: 640, label: 'BAKERY', color: '#ef8c45' },
  ]
  const controls = { left: false, right: false, drift: false }
  let state = 'menu'
  let width = 390
  let height = 844
  let dpr = 1
  let lastFrame = performance.now()
  let raceStart = 0
  let countdownTimer = 0
  let countdownValue = 3
  let toastTimer = 0
  let soundOn = false
  let audioContext = null
  let player
  let racers = []
  let particles = []
  let pickups = []
  let lapTimes = []
  let lastLapAt = 0
  let driftRushes = 0

  function resetRace() {
    const start = pointOnLoop(track, 0.004)
    player = {
      x: start.x,
      y: start.y,
      angle: start.angle,
      speed: 0,
      progress: 0.004,
      previousProgress: 0.004,
      lap: 0,
      boost: 0,
      driftCharge: 0,
      drifting: false,
      position: 1,
    }
    racers = colors.slice(1).map((color, index) => ({
      total: -0.018 * (index + 1),
      speed: 226 + index * 5 + Math.random() * 12,
      color,
      lane: (index % 2 ? 1 : -1) * (30 + Math.floor(index / 2) * 16),
      wobble: Math.random() * Math.PI * 2,
    }))
    pickups = [0.13, 0.35, 0.57, 0.78].map((progress, index) => ({
      progress,
      lane: index % 2 ? 48 : -48,
      active: true,
      respawn: 0,
    }))
    particles = []
    lapTimes = []
    lastLapAt = 0
    driftRushes = 0
    updateHud(0)
  }

  function resize() {
    const bounds = shell.getBoundingClientRect()
    width = bounds.width
    height = bounds.height
    dpr = Math.min(window.devicePixelRatio || 1, 2)
    canvas.width = Math.round(width * dpr)
    canvas.height = Math.round(height * dpr)
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`
  }

  function showOnly(selector) {
    screens.forEach((id) => $(id).classList.toggle('hidden', id !== selector))
  }

  function startCountdown() {
    resetRace()
    showOnly(null)
    $('#hud').classList.remove('hidden')
    $('#controls').classList.remove('hidden')
    state = 'countdown'
    countdownValue = 3
    countdownTimer = 0
    showCountdown('3')
    beep(220, 0.08)
  }

  function showCountdown(value) {
    const node = $('#countdown')
    node.textContent = value
    node.classList.remove('hidden', 'go')
    if (value === 'GO!') node.classList.add('go')
    node.style.animation = 'none'
    void node.offsetHeight
    node.style.animation = ''
  }

  function beginRace(now) {
    state = 'racing'
    raceStart = now
    lastLapAt = now
    showCountdown('GO!')
    beep(520, 0.18)
    window.setTimeout(() => $('#countdown').classList.add('hidden'), 580)
  }

  function finishRace() {
    state = 'finished'
    const elapsed = performance.now() - raceStart
    const place = player.position
    $('#hud').classList.add('hidden')
    $('#controls').classList.add('hidden')
    $('#finish-place').innerHTML = `${place}<span>${ordinal(place).replace(String(place), '').toUpperCase()}</span>`
    $('#finish-title').innerHTML = place === 1 ? 'AISLE<br><em>LEGEND!</em>' : place <= 3 ? 'PODIUM<br><em>HUSTLE!</em>' : 'CART<br><em>COMEBACK!</em>'
    $('#total-time').textContent = formatTime(elapsed)
    $('#best-lap').textContent = formatTime(Math.min(...lapTimes))
    $('#drifts').textContent = driftRushes
    $('#receipt-time').textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    showOnly('#finish-screen')
    beep(place === 1 ? 660 : 440, 0.35)
  }

  function update(dt, now) {
    if (state === 'countdown') {
      countdownTimer += dt
      if (countdownTimer >= 1) {
        countdownTimer -= 1
        countdownValue -= 1
        if (countdownValue > 0) {
          showCountdown(String(countdownValue))
          beep(220 + (3 - countdownValue) * 55, 0.08)
        } else beginRace(now)
      }
      return
    }
    if (state !== 'racing') return

    updatePlayer(dt)
    updateRacers(dt)
    updatePickups(dt)
    updateParticles(dt)
    const elapsed = now - raceStart
    updateHud(elapsed)
    if (player.lap >= 3) finishRace()
  }

  function updatePlayer(dt) {
    const road = nearestOnLoop(player, track)
    const onRoad = road.distance < 154
    const throttle = onRoad ? 180 : 85
    const maxSpeed = onRoad ? 285 : 128
    player.speed += throttle * dt
    player.speed *= Math.pow(onRoad ? 0.997 : 0.984, dt * 60)
    if (player.boost > 0) {
      player.boost -= dt
      player.speed += 330 * dt
    }
    player.speed = clamp(player.speed, 0, maxSpeed + (player.boost > 0 ? 115 : 0))

    const steering = (controls.right ? 1 : 0) - (controls.left ? 1 : 0)
    const moving = clamp(player.speed / 120, 0, 1)
    const driftFactor = controls.drift && steering ? 1.38 : 1
    player.angle += steering * 2.25 * moving * driftFactor * dt

    if (controls.drift && steering && player.speed > 135) {
      player.drifting = true
      player.driftCharge = clamp(player.driftCharge + dt * 0.58, 0, 1)
      const side = player.angle + Math.PI / 2
      player.x += Math.cos(side) * steering * player.speed * 0.16 * dt
      player.y += Math.sin(side) * steering * player.speed * 0.16 * dt
      if (Math.random() < dt * 18) spawnParticle(player.x, player.y, player.driftCharge > 0.55 ? '#ffd24a' : '#dce8df')
    } else if (player.drifting) {
      if (player.driftCharge > 0.32) {
        player.boost = 0.65 + player.driftCharge * 0.65
        driftRushes += 1
        toast(player.driftCharge > 0.75 ? 'MEGA RUSH!' : 'DRIFT RUSH!')
        beep(620, 0.12)
      }
      player.drifting = false
      player.driftCharge = 0
    }

    player.x += Math.cos(player.angle) * player.speed * dt
    player.y += Math.sin(player.angle) * player.speed * dt

    if (!onRoad) {
      const pull = clamp(dt * 1.7, 0, 1)
      player.x += (road.x - player.x) * pull
      player.y += (road.y - player.y) * pull
    }

    const current = nearestOnLoop(player, track)
    player.previousProgress = player.progress
    player.progress = current.progress
    if (player.previousProgress > 0.82 && player.progress < 0.18 && player.speed > 40) {
      player.lap += 1
      const now = performance.now()
      lapTimes.push(now - lastLapAt)
      lastLapAt = now
      if (player.lap < 3) {
        toast(`LAP ${player.lap + 1} · KEEP ROLLING!`)
        beep(480, 0.16)
      }
    }
  }

  function updateRacers(dt) {
    racers.forEach((racer, index) => {
      const targetSpeed = racer.speed + Math.sin(performance.now() * 0.0012 + racer.wobble) * 12
      const catchup = player.lap + player.progress - racer.total
      racer.total += (targetSpeed + clamp(catchup * 28, -20, 24)) / trackLength * dt
      racer.wobble += dt * (0.7 + index * 0.04)
    })
    const playerTotal = player.lap + player.progress
    player.position = 1 + racers.filter((racer) => racer.total > playerTotal).length
  }

  function updatePickups(dt) {
    pickups.forEach((pickup) => {
      if (!pickup.active) {
        pickup.respawn -= dt
        if (pickup.respawn <= 0) pickup.active = true
        return
      }
      const point = offsetTrackPoint(pickup.progress, pickup.lane)
      if (Math.hypot(player.x - point.x, player.y - point.y) < 55) {
        pickup.active = false
        pickup.respawn = 7
        player.boost = Math.max(player.boost, 1.15)
        player.speed += 65
        toast('EXPRESS LANE!')
        beep(760, 0.1)
        for (let i = 0; i < 14; i += 1) spawnParticle(point.x, point.y, '#56d9b4', true)
      }
    })
  }

  function spawnParticle(x, y, color, burst) {
    particles.push({
      x, y, color, life: burst ? 0.8 : 0.45,
      vx: (Math.random() - 0.5) * (burst ? 190 : 55),
      vy: (Math.random() - 0.5) * (burst ? 190 : 55),
      size: 3 + Math.random() * 5,
    })
  }

  function updateParticles(dt) {
    particles.forEach((particle) => {
      particle.x += particle.vx * dt
      particle.y += particle.vy * dt
      particle.life -= dt
    })
    particles = particles.filter((particle) => particle.life > 0)
  }

  function updateHud(elapsed) {
    $('#position').textContent = ordinal(player.position)
    $('#lap').textContent = `${Math.min(player.lap + 1, 3)} / 3`
    $('#time').textContent = formatTime(elapsed)
    $('#boost-fill').style.width = `${Math.max(player.driftCharge, clamp(player.boost / 1.2, 0, 1)) * 100}%`
  }

  function offsetTrackPoint(progress, offset) {
    const point = pointOnLoop(track, progress)
    return {
      x: point.x + Math.cos(point.angle + Math.PI / 2) * offset,
      y: point.y + Math.sin(point.angle + Math.PI / 2) * offset,
      angle: point.angle,
    }
  }

  function draw(now) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, width, height)
    ctx.fillStyle = '#101b2c'
    ctx.fillRect(0, 0, width, height)

    if (!player) {
      drawMenuBackdrop(now)
      return
    }

    const zoom = clamp(width / 520, 0.7, 0.92)
    ctx.save()
    ctx.translate(width / 2, height * 0.48)
    ctx.scale(zoom, zoom)
    ctx.translate(-player.x, -player.y)
    drawStoreFloor()
    drawTrack()
    drawStoreFixtures()
    drawPickups(now)
    drawRacers()
    drawParticles()
    drawCart(player.x, player.y, player.angle, colors[0], true, player.drifting)
    ctx.restore()
    drawSpeedVignette()
  }

  function pathLoop() {
    ctx.beginPath()
    ctx.moveTo(track[0].x, track[0].y)
    track.slice(1).forEach((point) => ctx.lineTo(point.x, point.y))
    ctx.closePath()
  }

  function drawMenuBackdrop(now) {
    ctx.save()
    ctx.globalAlpha = 0.18
    ctx.strokeStyle = '#7d9cb4'
    ctx.lineWidth = 1
    const shift = (now * 0.02) % 42
    for (let y = -42 + shift; y < height + 50; y += 42) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
    }
    for (let x = 0; x < width; x += 42) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
    }
    ctx.restore()
  }

  function drawStoreFloor() {
    ctx.fillStyle = '#dfe3da'
    ctx.fillRect(0, 0, 1560, 1160)
    ctx.strokeStyle = 'rgba(53,75,87,.08)'
    ctx.lineWidth = 2
    for (let x = 0; x <= 1560; x += 80) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, 1160); ctx.stroke()
    }
    for (let y = 0; y <= 1160; y += 80) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(1560, y); ctx.stroke()
    }
  }

  function drawTrack() {
    ctx.save()
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    pathLoop()
    ctx.strokeStyle = '#26354a'
    ctx.lineWidth = 340
    ctx.stroke()
    pathLoop()
    ctx.strokeStyle = '#45566b'
    ctx.lineWidth = 306
    ctx.stroke()
    pathLoop()
    ctx.strokeStyle = 'rgba(245,234,215,.34)'
    ctx.lineWidth = 3
    ctx.setLineDash([26, 25])
    ctx.stroke()
    ctx.setLineDash([])
    const start = pointOnLoop(track, 0)
    ctx.translate(start.x, start.y)
    ctx.rotate(start.angle + Math.PI / 2)
    for (let row = -1; row <= 1; row += 1) {
      for (let column = -5; column <= 5; column += 1) {
        ctx.fillStyle = (row + column) % 2 ? '#f5ead7' : '#111927'
        ctx.fillRect(column * 24, row * 24, 24, 24)
      }
    }
    ctx.restore()
  }

  function drawStoreFixtures() {
    aisleSigns.forEach((aisle, index) => {
      drawShelf(aisle.x, aisle.y, 250, 110, aisle.color, aisle.label, index + 1)
    })
    drawShelf(650, 790, 230, 80, '#7953bd', 'HOME', 7)
    ctx.fillStyle = '#ec4542'
    ctx.fillRect(30, 40, 1500, 55)
    ctx.fillStyle = '#fff2d1'
    ctx.font = '900 28px "Barlow Condensed", sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText('FRESHMART  •  LOW PRICES, HIGH SPEEDS', 780, 78)
    ctx.textAlign = 'left'
  }

  function drawShelf(x, y, shelfWidth, shelfHeight, color, label, number) {
    ctx.save()
    ctx.translate(x, y)
    ctx.fillStyle = 'rgba(16,25,39,.18)'
    ctx.fillRect(10, 15, shelfWidth, shelfHeight)
    ctx.fillStyle = '#f2e8d4'
    ctx.fillRect(0, 0, shelfWidth, shelfHeight)
    ctx.fillStyle = color
    ctx.fillRect(0, 0, shelfWidth, 23)
    ctx.fillStyle = '#1a2433'
    for (let row = 0; row < 2; row += 1) {
      for (let column = 0; column < 8; column += 1) {
        const productColors = ['#e84d45', '#efb942', '#58b58d', '#4f86ce']
        ctx.fillStyle = productColors[(column + row + number) % productColors.length]
        ctx.fillRect(10 + column * 29, 33 + row * 30, 18, 22)
      }
    }
    ctx.fillStyle = color
    ctx.fillRect(-8, -31, 75, 31)
    ctx.fillStyle = '#fff'
    ctx.font = '800 15px "Barlow Condensed", sans-serif'
    ctx.fillText(`${number}  ${label}`, 0, -10)
    ctx.restore()
  }

  function drawPickups(now) {
    pickups.forEach((pickup) => {
      if (!pickup.active) return
      const point = offsetTrackPoint(pickup.progress, pickup.lane)
      const pulse = 1 + Math.sin(now * 0.006 + pickup.progress * 20) * 0.12
      ctx.save()
      ctx.translate(point.x, point.y)
      ctx.scale(pulse, pulse)
      ctx.rotate(now * 0.001)
      ctx.fillStyle = 'rgba(86,217,180,.23)'
      ctx.beginPath(); ctx.arc(0, 0, 35, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = '#56d9b4'
      ctx.beginPath()
      for (let index = 0; index < 8; index += 1) {
        const angle = index * Math.PI / 4
        const radius = index % 2 ? 12 : 23
        ctx.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius)
      }
      ctx.closePath(); ctx.fill()
      ctx.fillStyle = '#102035'; ctx.font = '900 14px sans-serif'; ctx.textAlign = 'center'; ctx.fillText('⚡', 0, 5)
      ctx.restore()
    })
  }

  function drawRacers() {
    racers.forEach((racer) => {
      const point = offsetTrackPoint(racer.total, racer.lane + Math.sin(racer.wobble) * 5)
      drawCart(point.x, point.y, point.angle, racer.color, false, false)
    })
  }

  function drawCart(x, y, angle, color, isPlayer, drifting) {
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(angle)
    ctx.fillStyle = 'rgba(4,10,17,.28)'
    ctx.beginPath(); ctx.ellipse(-4, 8, 39, 24, 0, 0, Math.PI * 2); ctx.fill()
    if (isPlayer && player.boost > 0) {
      ctx.fillStyle = '#ffd24a'
      ctx.beginPath(); ctx.moveTo(-36, -10); ctx.lineTo(-65 - Math.random() * 15, 0); ctx.lineTo(-36, 10); ctx.fill()
      ctx.fillStyle = '#f04437'
      ctx.beginPath(); ctx.moveTo(-34, -6); ctx.lineTo(-52 - Math.random() * 10, 0); ctx.lineTo(-34, 6); ctx.fill()
    }
    ctx.strokeStyle = '#d9e1dd'
    ctx.lineWidth = 5
    ctx.fillStyle = color
    ctx.beginPath()
    ctx.moveTo(-27, -23); ctx.lineTo(30, -17); ctx.lineTo(24, 20); ctx.lineTo(-27, 24); ctx.closePath()
    ctx.fill(); ctx.stroke()
    ctx.strokeStyle = 'rgba(255,255,255,.5)'
    ctx.lineWidth = 2
    for (let line = -12; line <= 12; line += 12) {
      ctx.beginPath(); ctx.moveTo(-19, line); ctx.lineTo(24, line * 0.75); ctx.stroke()
    }
    ctx.strokeStyle = color; ctx.lineWidth = 7
    ctx.beginPath(); ctx.moveTo(-34, -27); ctx.lineTo(-34, 28); ctx.stroke()
    ctx.fillStyle = '#111927'
    ;[-20, 20].forEach((wheelY) => {
      ctx.beginPath(); ctx.arc(22, wheelY, 7, 0, Math.PI * 2); ctx.fill()
      ctx.beginPath(); ctx.arc(-23, wheelY, 6, 0, Math.PI * 2); ctx.fill()
    })
    if (isPlayer) {
      ctx.fillStyle = '#ffd24a'
      ctx.beginPath(); ctx.moveTo(36, 0); ctx.lineTo(25, -9); ctx.lineTo(25, 9); ctx.closePath(); ctx.fill()
      if (drifting) {
        ctx.strokeStyle = '#f5ead7'; ctx.lineWidth = 3; ctx.globalAlpha = 0.6
        ctx.beginPath(); ctx.moveTo(-26, -20); ctx.quadraticCurveTo(-55, -28, -72, -10); ctx.stroke()
      }
    }
    ctx.restore()
  }

  function drawParticles() {
    particles.forEach((particle) => {
      ctx.globalAlpha = clamp(particle.life * 2, 0, 1)
      ctx.fillStyle = particle.color
      ctx.fillRect(particle.x - particle.size / 2, particle.y - particle.size / 2, particle.size, particle.size)
    })
    ctx.globalAlpha = 1
  }

  function drawSpeedVignette() {
    if (!player || player.speed < 300) return
    const intensity = clamp((player.speed - 300) / 100, 0, 1)
    ctx.save()
    ctx.globalAlpha = intensity * 0.5
    ctx.strokeStyle = '#f5ead7'
    ctx.lineWidth = 2
    for (let index = 0; index < 16; index += 1) {
      const angle = index / 16 * Math.PI * 2
      const x = width / 2 + Math.cos(angle) * width * 0.42
      const y = height / 2 + Math.sin(angle) * height * 0.42
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(angle) * 45, y + Math.sin(angle) * 65); ctx.stroke()
    }
    ctx.restore()
  }

  function toast(message) {
    const node = $('#toast')
    node.textContent = message
    node.classList.remove('hidden')
    node.style.animation = 'none'
    void node.offsetHeight
    node.style.animation = ''
    window.clearTimeout(toastTimer)
    toastTimer = window.setTimeout(() => node.classList.add('hidden'), 950)
  }

  function beep(frequency, duration) {
    if (!soundOn) return
    audioContext = audioContext || new (window.AudioContext || window.webkitAudioContext)()
    const oscillator = audioContext.createOscillator()
    const gain = audioContext.createGain()
    oscillator.type = 'square'
    oscillator.frequency.value = frequency
    gain.gain.setValueAtTime(0.045, audioContext.currentTime)
    gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + duration)
    oscillator.connect(gain).connect(audioContext.destination)
    oscillator.start()
    oscillator.stop(audioContext.currentTime + duration)
  }

  function bindHold(button, key) {
    const activate = (event) => {
      event.preventDefault()
      controls[key] = true
      button.classList.add('active')
      if (button.setPointerCapture && event.pointerId !== undefined) button.setPointerCapture(event.pointerId)
    }
    const release = (event) => {
      if (event) event.preventDefault()
      controls[key] = false
      button.classList.remove('active')
    }
    button.addEventListener('pointerdown', activate)
    button.addEventListener('pointerup', release)
    button.addEventListener('pointercancel', release)
    button.addEventListener('lostpointercapture', release)
  }

  $('#start-button').addEventListener('click', () => showOnly('#briefing-screen'))
  $('#race-button').addEventListener('click', startCountdown)
  $('#restart-button').addEventListener('click', startCountdown)
  $('#sound-button').addEventListener('click', () => {
    soundOn = !soundOn
    $('#sound-button').setAttribute('aria-pressed', String(soundOn))
    $('#sound-button').textContent = soundOn ? '♫' : '♪'
    beep(440, 0.08)
  })
  bindHold($('#left-button'), 'left')
  bindHold($('#right-button'), 'right')
  bindHold($('#drift-button'), 'drift')
  window.addEventListener('keydown', (event) => {
    if (['ArrowLeft', 'a', 'A'].includes(event.key)) controls.left = true
    if (['ArrowRight', 'd', 'D'].includes(event.key)) controls.right = true
    if ([' ', 'Shift'].includes(event.key)) controls.drift = true
  })
  window.addEventListener('keyup', (event) => {
    if (['ArrowLeft', 'a', 'A'].includes(event.key)) controls.left = false
    if (['ArrowRight', 'd', 'D'].includes(event.key)) controls.right = false
    if ([' ', 'Shift'].includes(event.key)) controls.drift = false
  })
  window.addEventListener('resize', resize)
  document.addEventListener('visibilitychange', () => { lastFrame = performance.now() })

  function frame(now) {
    const dt = Math.min((now - lastFrame) / 1000, 0.05)
    lastFrame = now
    update(dt, now)
    draw(now)
    requestAnimationFrame(frame)
  }

  resize()
  resetRace()
  player = null
  requestAnimationFrame(frame)

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    window.addEventListener('load', () => navigator.serviceWorker.register('service-worker.js').catch(() => {}))
  }
})()
