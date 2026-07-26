(() => {
  const canvas = document.getElementById("raceCanvas")
  const ctx = canvas ? canvas.getContext("2d") : null
  const overlay = document.getElementById("overlay")
  const overlayTitle = document.getElementById("overlayTitle")
  const overlayText = document.getElementById("overlayText")
  const startButton = document.getElementById("startButton")
  const lapValue = document.getElementById("lapValue")
  const placeValue = document.getElementById("placeValue")
  const speedValue = document.getElementById("speedValue")
  const turboFill = document.getElementById("turboFill")

  if (!canvas || !ctx || !overlay || !overlayTitle || !overlayText || !startButton) {
    return
  }

  const WORLD = {
    width: 1600,
    height: 980,
    bounds: { left: 60, top: 60, right: 1540, bottom: 920 },
  }

  const TRACK_POINTS = [
    { x: 250, y: 180 },
    { x: 520, y: 180 },
    { x: 520, y: 400 },
    { x: 1090, y: 400 },
    { x: 1090, y: 180 },
    { x: 1380, y: 180 },
    { x: 1380, y: 780 },
    { x: 1090, y: 780 },
    { x: 1090, y: 560 },
    { x: 520, y: 560 },
    { x: 520, y: 780 },
    { x: 250, y: 780 },
  ]
  const TRACK_WIDTH = 96
  const MAX_LAPS = 3

  const SHELVES = [
    { x: 250, y: 260, w: 180, h: 130, label: "SNACKS" },
    { x: 250, y: 590, w: 180, h: 100, label: "FROZEN" },
    { x: 600, y: 250, w: 320, h: 120, label: "CANNED" },
    { x: 600, y: 600, w: 320, h: 120, label: "PRODUCE" },
    { x: 1170, y: 260, w: 180, h: 130, label: "DRINKS" },
    { x: 1170, y: 590, w: 180, h: 100, label: "DELI" },
  ]

  const BOOST_PADS = [
    { x: 810, y: 400, r: 26, glow: 0, playerLock: 0 },
    { x: 1380, y: 470, r: 26, glow: 0, playerLock: 0 },
    { x: 810, y: 560, r: 26, glow: 0, playerLock: 0 },
    { x: 520, y: 310, r: 26, glow: 0, playerLock: 0 },
  ]

  const SPILLS = [
    { x: 1295, y: 190, r: 22, wobble: 0, playerLock: 0 },
    { x: 1100, y: 665, r: 22, wobble: 1.3, playerLock: 0 },
    { x: 505, y: 665, r: 22, wobble: 2.1, playerLock: 0 },
    { x: 720, y: 400, r: 22, wobble: 0.7, playerLock: 0 },
  ]

  const track = buildTrack(TRACK_POINTS)

  const input = {
    left: false,
    right: false,
    brake: false,
    boost: false,
  }

  const race = {
    state: "idle",
    countdown: 3.4,
    time: 0,
    messageTimer: 0,
    finishedText: "",
  }

  const player = {
    id: "player",
    name: "You",
    color: "#ff6b6b",
    accent: "#ffd7d7",
    radius: 20,
    maxSpeed: 370,
    speed: 0,
    angle: 0,
    turnRate: 2.6,
    turbo: 68,
    lap: 1,
    progress: 0,
    previousProgress: 0,
    onTrack: true,
    boostBurst: 0,
    spinTime: 0,
    hitLock: 0,
    bounceFlash: 0,
    started: false,
    finished: false,
    finishOrder: 0,
  }

  const aiRacers = [
    makeAi("Night Shift", "#4de3c0", 330, -70, 0.2),
    makeAi("Loose Wheel", "#4c8dff", 320, -145, 1.8),
    makeAi("Express Lane", "#ffb84d", 338, -215, 3.1),
  ]

  const racers = [player, ...aiRacers]
  const camera = { x: 0, y: 0, zoom: 0.78 }
  const introTitle = "Tap play to roll out"
  const introText =
    "Win three laps around the store by hugging the racing line, avoiding spills, and using turbo on the straightaways."
  let previousTimestamp = 0

  function makeAi(name, color, pace, startOffset, wobbleSeed) {
    return {
      id: name.toLowerCase().replace(/\s+/g, "-"),
      name,
      color,
      accent: "#eaf4ff",
      radius: 18,
      baseSpeed: pace,
      speed: pace,
      lap: 1,
      progress: 0,
      previousProgress: 0,
      angle: 0,
      finished: false,
      finishOrder: 0,
      wobbleSeed,
      lateralOffset: 0,
      startOffset,
    }
  }

  function buildTrack(points) {
    const segments = []
    const cumulative = [0]
    let totalLength = 0

    for (let index = 0; index < points.length; index += 1) {
      const start = points[index]
      const end = points[(index + 1) % points.length]
      const dx = end.x - start.x
      const dy = end.y - start.y
      const length = Math.hypot(dx, dy)

      segments.push({
        start,
        end,
        dx,
        dy,
        length,
      })

      totalLength += length
      cumulative.push(totalLength)
    }

    return { points, segments, cumulative, totalLength }
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value))
  }

  function lerp(start, end, amount) {
    return start + (end - start) * amount
  }

  function distanceSquared(aX, aY, bX, bY) {
    const dx = aX - bX
    const dy = aY - bY
    return dx * dx + dy * dy
  }

  function worldToScreen(x, y) {
    return {
      x: (x - camera.x) * camera.zoom + canvas.width * 0.5,
      y: (y - camera.y) * camera.zoom + canvas.height * 0.5,
    }
  }

  function pointAtProgress(progress, lateralOffset = 0) {
    let wrapped = progress % track.totalLength
    if (wrapped < 0) {
      wrapped += track.totalLength
    }

    let segmentIndex = 0
    while (segmentIndex < track.segments.length - 1 && wrapped > track.cumulative[segmentIndex + 1]) {
      segmentIndex += 1
    }

    const segment = track.segments[segmentIndex]
    const segmentStart = track.cumulative[segmentIndex]
    const local = clamp((wrapped - segmentStart) / segment.length, 0, 1)
    const x = lerp(segment.start.x, segment.end.x, local)
    const y = lerp(segment.start.y, segment.end.y, local)
    const nx = -segment.dy / segment.length
    const ny = segment.dx / segment.length

    return {
      x: x + nx * lateralOffset,
      y: y + ny * lateralOffset,
      angle: Math.atan2(segment.dy, segment.dx),
      segmentIndex,
    }
  }

  function projectOntoTrack(x, y) {
    let best = null

    for (let index = 0; index < track.segments.length; index += 1) {
      const segment = track.segments[index]
      const lengthSquared = segment.length * segment.length
      let projection = 0

      if (lengthSquared > 0) {
        projection =
          ((x - segment.start.x) * segment.dx + (y - segment.start.y) * segment.dy) / lengthSquared
      }

      const t = clamp(projection, 0, 1)
      const closestX = segment.start.x + segment.dx * t
      const closestY = segment.start.y + segment.dy * t
      const dx = x - closestX
      const dy = y - closestY
      const distance = Math.hypot(dx, dy)

      if (!best || distance < best.distance) {
        best = {
          x: closestX,
          y: closestY,
          distance,
          progress: track.cumulative[index] + segment.length * t,
          angle: Math.atan2(segment.dy, segment.dx),
        }
      }
    }

    return best
  }

  function resetRace() {
    const baseProgress = 160
    const spawnPoint = pointAtProgress(baseProgress, 0)
    player.x = spawnPoint.x
    player.y = spawnPoint.y
    player.angle = spawnPoint.angle
    player.speed = 0
    player.turbo = 68
    player.lap = 1
    player.progress = baseProgress
    player.previousProgress = player.progress
    player.onTrack = true
    player.boostBurst = 0
    player.spinTime = 0
    player.hitLock = 0
    player.bounceFlash = 0
    player.started = false
    player.finished = false
    player.finishOrder = 0

    aiRacers.forEach((racer) => {
      const startProgress = baseProgress + racer.startOffset
      const slot = pointAtProgress(startProgress, 22 * Math.sin(racer.wobbleSeed))
      racer.progress = startProgress % track.totalLength
      if (racer.progress < 0) {
        racer.progress += track.totalLength
      }
      racer.previousProgress = racer.progress
      racer.lap = 1
      racer.finished = false
      racer.finishOrder = 0
      racer.speed = racer.baseSpeed
      racer.x = slot.x
      racer.y = slot.y
      racer.angle = slot.angle
      racer.lateralOffset = 22 * Math.sin(racer.wobbleSeed)
    })

    camera.x = player.x
    camera.y = player.y
    BOOST_PADS.forEach((pad) => {
      pad.glow = 0
      pad.playerLock = 0
    })
    SPILLS.forEach((spill) => {
      spill.playerLock = 0
    })
    race.state = "countdown"
    race.countdown = 3.4
    race.time = 0
    race.messageTimer = 0
    race.finishedText = ""
    hideOverlay()
    updateHud()
  }

  function finishRace() {
    player.finished = true
    player.finishOrder = placeRacers().findIndex((racer) => racer.id === player.id) + 1
    race.state = "finished"
    race.finishedText = ordinal(player.finishOrder)
    overlayTitle.textContent = player.finishOrder === 1 ? "Checkout champion" : `${race.finishedText} place`
    overlayText.textContent =
      player.finishOrder === 1
        ? "You threaded the shelves, managed the spills, and crossed the line first. Hit restart for another run."
        : "The other carts got the jump this time. Restart and take a tighter line through the middle aisles."
    startButton.textContent = "Restart race"
    showOverlay()
  }

  function updateHud() {
    lapValue.textContent = `${Math.min(player.lap, MAX_LAPS)} / ${MAX_LAPS}`
    placeValue.textContent = ordinal(placeRacers().findIndex((racer) => racer.id === player.id) + 1)
    speedValue.textContent = `${Math.round(player.speed * 0.42)} mph`
    turboFill.style.width = `${clamp(player.turbo, 0, 100)}%`
  }

  function ordinal(value) {
    if (value === 1) {
      return "1st"
    }
    if (value === 2) {
      return "2nd"
    }
    if (value === 3) {
      return "3rd"
    }
    return `${value}th`
  }

  function placeRacers() {
    return [...racers].sort((left, right) => racerScore(right) - racerScore(left))
  }

  function racerScore(racer) {
    const completedLaps = clamp(racer.lap - 1, 0, MAX_LAPS)
    return completedLaps * track.totalLength + racer.progress + (racer.finished ? track.totalLength : 0)
  }

  function setOverlay(title, text, buttonText) {
    overlayTitle.textContent = title
    overlayText.textContent = text
    startButton.textContent = buttonText
  }

  function showOverlay() {
    overlay.classList.remove("is-hidden")
  }

  function hideOverlay() {
    overlay.classList.add("is-hidden")
  }

  function steerIntent() {
    return (input.right ? 1 : 0) - (input.left ? 1 : 0)
  }

  function updatePlayer(delta) {
    if (player.finished) {
      player.speed = Math.max(0, player.speed - 180 * delta)
      return
    }

    const wasX = player.x
    const wasY = player.y
    const steer = steerIntent()
    const onTrackProjection = projectOntoTrack(player.x, player.y)
    player.progress = onTrackProjection.progress
    player.onTrack = onTrackProjection.distance <= TRACK_WIDTH

    const raceActive = race.state === "running"
    const targetSpeed = player.onTrack ? player.maxSpeed : player.maxSpeed * 0.58
    const accel = raceActive ? 3.8 : 0
    const boostPressed = input.boost && player.turbo > 0 && raceActive
    const braking = input.brake && raceActive

    if (boostPressed) {
      player.boostBurst = clamp(player.boostBurst + delta * 2.8, 0, 1)
      player.turbo = Math.max(0, player.turbo - delta * 26)
    } else {
      player.boostBurst = Math.max(0, player.boostBurst - delta * 2.6)
      player.turbo = Math.min(100, player.turbo + delta * (player.onTrack ? 4.1 : 1.4))
    }

    let desired = targetSpeed + player.boostBurst * 125
    if (braking) {
      desired *= 0.42
    }

    player.speed += (desired - player.speed) * accel * delta
    player.speed -= delta * (player.onTrack ? 14 : 70)
    player.speed = clamp(player.speed, 0, player.maxSpeed + 130)

    if (player.spinTime > 0) {
      player.spinTime = Math.max(0, player.spinTime - delta)
      player.angle += 6.6 * delta
    } else if (Math.abs(steer) > 0.01) {
      const grip = 0.35 + (player.speed / (player.maxSpeed + 130)) * 0.95
      player.angle += steer * player.turnRate * grip * delta
    } else {
      player.angle += angleDelta(player.angle, onTrackProjection.angle) * 0.65 * delta
    }

    player.x += Math.cos(player.angle) * player.speed * delta
    player.y += Math.sin(player.angle) * player.speed * delta

    resolveWorldBounds(player)
    resolveShelfCollisions(player)
    handlePadsAndSpills(player, delta)

    const updatedProjection = projectOntoTrack(player.x, player.y)
    const progressDelta = updatedProjection.progress - player.previousProgress

    if (raceActive && progressDelta < -track.totalLength * 0.6) {
      player.lap += 1
      if (player.lap > MAX_LAPS) {
        player.lap = MAX_LAPS
        finishRace()
      }
    }

    player.previousProgress = updatedProjection.progress
    player.progress = updatedProjection.progress

    if (distanceSquared(player.x, player.y, wasX, wasY) < 1 && player.speed > 0) {
      player.speed *= 0.86
    }

    player.bounceFlash = Math.max(0, player.bounceFlash - delta * 3)
    player.hitLock = Math.max(0, player.hitLock - delta)
  }

  function updateAi(delta) {
    const raceActive = race.state === "running"

    aiRacers.forEach((racer) => {
      if (racer.finished) {
        return
      }

      if (!raceActive) {
        const parked = pointAtProgress(racer.progress, racer.lateralOffset)
        racer.x = parked.x
        racer.y = parked.y
        racer.angle = parked.angle
        return
      }

      racer.lateralOffset = Math.sin(race.time * 0.85 + racer.wobbleSeed + racer.progress / 180) * 28
      const boostWave = Math.sin(race.time * 1.6 + racer.wobbleSeed) * 14
      const trackPenalty = racers[0].lap > racer.lap ? 10 : 0
      racer.speed = racer.baseSpeed + boostWave + trackPenalty

      racer.progress += racer.speed * delta
      if (racer.progress >= track.totalLength) {
        racer.progress -= track.totalLength
        racer.lap += 1
        if (racer.lap > MAX_LAPS) {
          racer.lap = MAX_LAPS
          racer.finished = true
          racer.finishOrder = placeRacers().findIndex((entry) => entry.id === racer.id) + 1
        }
      }

      const point = pointAtProgress(racer.progress, racer.lateralOffset)
      racer.x = point.x
      racer.y = point.y
      racer.angle = point.angle
    })
  }

  function angleDelta(current, target) {
    let difference = target - current
    while (difference > Math.PI) {
      difference -= Math.PI * 2
    }
    while (difference < -Math.PI) {
      difference += Math.PI * 2
    }
    return difference
  }

  function resolveWorldBounds(racer) {
    const minX = WORLD.bounds.left + racer.radius
    const maxX = WORLD.bounds.right - racer.radius
    const minY = WORLD.bounds.top + racer.radius
    const maxY = WORLD.bounds.bottom - racer.radius

    if (racer.x < minX) {
      racer.x = minX
      if (racer === player) {
        player.speed *= 0.52
        player.bounceFlash = 1
      }
    }
    if (racer.x > maxX) {
      racer.x = maxX
      if (racer === player) {
        player.speed *= 0.52
        player.bounceFlash = 1
      }
    }
    if (racer.y < minY) {
      racer.y = minY
      if (racer === player) {
        player.speed *= 0.52
        player.bounceFlash = 1
      }
    }
    if (racer.y > maxY) {
      racer.y = maxY
      if (racer === player) {
        player.speed *= 0.52
        player.bounceFlash = 1
      }
    }
  }

  function resolveShelfCollisions(racer) {
    SHELVES.forEach((shelf) => {
      const nearestX = clamp(racer.x, shelf.x, shelf.x + shelf.w)
      const nearestY = clamp(racer.y, shelf.y, shelf.y + shelf.h)
      const dx = racer.x - nearestX
      const dy = racer.y - nearestY
      const distSq = dx * dx + dy * dy

      if (distSq >= racer.radius * racer.radius) {
        return
      }

      let pushX = 0
      let pushY = 0

      if (distSq === 0) {
        const toLeft = Math.abs(racer.x - shelf.x)
        const toRight = Math.abs(shelf.x + shelf.w - racer.x)
        const toTop = Math.abs(racer.y - shelf.y)
        const toBottom = Math.abs(shelf.y + shelf.h - racer.y)
        const smallest = Math.min(toLeft, toRight, toTop, toBottom)

        if (smallest === toLeft) {
          pushX = -(racer.radius + 2)
        } else if (smallest === toRight) {
          pushX = racer.radius + 2
        } else if (smallest === toTop) {
          pushY = -(racer.radius + 2)
        } else {
          pushY = racer.radius + 2
        }
      } else {
        const dist = Math.sqrt(distSq)
        const overlap = racer.radius - dist + 1
        pushX = (dx / dist) * overlap
        pushY = (dy / dist) * overlap
      }

      racer.x += pushX
      racer.y += pushY

      if (racer === player && player.hitLock <= 0) {
        player.speed *= 0.48
        player.bounceFlash = 1
        player.hitLock = 0.18
      }
    })
  }

  function handlePadsAndSpills(racer, delta) {
    BOOST_PADS.forEach((pad) => {
      pad.glow = Math.max(0, pad.glow - delta * 2.4)
      pad.playerLock = Math.max(0, pad.playerLock - delta)
      if (distanceSquared(racer.x, racer.y, pad.x, pad.y) <= (pad.r + racer.radius) ** 2) {
        pad.glow = 1
        if (racer === player && pad.playerLock <= 0) {
          player.speed = clamp(player.speed + 140, 0, player.maxSpeed + 130)
          player.turbo = clamp(player.turbo + 22, 0, 100)
          player.boostBurst = clamp(player.boostBurst + 0.18, 0, 1)
          pad.playerLock = 0.38
        }
      }
    })

    SPILLS.forEach((spill) => {
      spill.wobble += delta * 2.2
      spill.playerLock = Math.max(0, spill.playerLock - delta)
      if (distanceSquared(racer.x, racer.y, spill.x, spill.y) <= (spill.r + racer.radius - 3) ** 2) {
        if (racer === player && player.hitLock <= 0 && spill.playerLock <= 0) {
          player.speed *= 0.68
          player.spinTime = 0.32
          player.hitLock = 0.24
          spill.playerLock = 0.55
        }
      }
    })
  }

  function update(delta) {
    race.time += delta

    if (race.state === "countdown") {
      race.countdown -= delta
      if (race.countdown <= 0) {
        race.state = "running"
        player.started = true
      }
    }

    updateAi(delta)
    updatePlayer(delta)
    updateHud()

    const lookAhead = 85 + player.speed * 0.18
    camera.x += (player.x + Math.cos(player.angle) * lookAhead - camera.x) * 0.09
    camera.y += (player.y + Math.sin(player.angle) * lookAhead - camera.y) * 0.09
  }

  function render() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    drawBackdrop()
    drawStoreFloor()
    drawTrack()
    drawDecor()
    drawRacers()
    drawCountdown()
  }

  function drawBackdrop() {
    const sky = ctx.createLinearGradient(0, 0, 0, canvas.height)
    sky.addColorStop(0, "#152132")
    sky.addColorStop(0.55, "#0d1622")
    sky.addColorStop(1, "#08111a")
    ctx.fillStyle = sky
    ctx.fillRect(0, 0, canvas.width, canvas.height)
  }

  function drawStoreFloor() {
    const topLeft = worldToScreen(WORLD.bounds.left, WORLD.bounds.top)
    const bottomRight = worldToScreen(WORLD.bounds.right, WORLD.bounds.bottom)
    ctx.fillStyle = "#eef1f3"
    ctx.fillRect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y)

    ctx.strokeStyle = "rgba(76, 104, 126, 0.2)"
    ctx.lineWidth = Math.max(1, 2 * camera.zoom)

    for (let x = 120; x <= WORLD.width; x += 110) {
      const start = worldToScreen(x, WORLD.bounds.top)
      const end = worldToScreen(x, WORLD.bounds.bottom)
      ctx.beginPath()
      ctx.moveTo(start.x, start.y)
      ctx.lineTo(end.x, end.y)
      ctx.stroke()
    }

    for (let y = 120; y <= WORLD.height; y += 110) {
      const start = worldToScreen(WORLD.bounds.left, y)
      const end = worldToScreen(WORLD.bounds.right, y)
      ctx.beginPath()
      ctx.moveTo(start.x, start.y)
      ctx.lineTo(end.x, end.y)
      ctx.stroke()
    }
  }

  function drawTrack() {
    const screenPoints = TRACK_POINTS.map((point) => worldToScreen(point.x, point.y))
    const closed = [...screenPoints, screenPoints[0]]

    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    ctx.beginPath()
    closed.forEach((point, index) => {
      if (index === 0) {
        ctx.moveTo(point.x, point.y)
      } else {
        ctx.lineTo(point.x, point.y)
      }
    })
    ctx.strokeStyle = "#293543"
    ctx.lineWidth = TRACK_WIDTH * 2.3 * camera.zoom
    ctx.stroke()

    ctx.beginPath()
    closed.forEach((point, index) => {
      if (index === 0) {
        ctx.moveTo(point.x, point.y)
      } else {
        ctx.lineTo(point.x, point.y)
      }
    })
    ctx.strokeStyle = player.onTrack ? "#435361" : "#584648"
    ctx.lineWidth = TRACK_WIDTH * 2 * camera.zoom
    ctx.stroke()

    ctx.setLineDash([34 * camera.zoom, 26 * camera.zoom])
    ctx.beginPath()
    closed.forEach((point, index) => {
      if (index === 0) {
        ctx.moveTo(point.x, point.y)
      } else {
        ctx.lineTo(point.x, point.y)
      }
    })
    ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
    ctx.lineWidth = Math.max(2, 6 * camera.zoom)
    ctx.stroke()
    ctx.setLineDash([])

    drawStartLine()
    drawDirectionArrows()
  }

  function drawStartLine() {
    const lineCenter = pointAtProgress(0, 0)
    const normalAngle = lineCenter.angle + Math.PI / 2
    const halfWidth = TRACK_WIDTH * 0.9

    for (let index = 0; index < 8; index += 1) {
      const offsetA = -halfWidth + (index / 8) * (halfWidth * 2)
      const offsetB = -halfWidth + ((index + 1) / 8) * (halfWidth * 2)
      const start = worldToScreen(
        lineCenter.x + Math.cos(normalAngle) * offsetA,
        lineCenter.y + Math.sin(normalAngle) * offsetA
      )
      const end = worldToScreen(
        lineCenter.x + Math.cos(normalAngle) * offsetB,
        lineCenter.y + Math.sin(normalAngle) * offsetB
      )

      ctx.strokeStyle = index % 2 === 0 ? "#ffffff" : "#111111"
      ctx.lineWidth = Math.max(3, 11 * camera.zoom)
      ctx.beginPath()
      ctx.moveTo(start.x, start.y)
      ctx.lineTo(end.x, end.y)
      ctx.stroke()
    }
  }

  function drawDirectionArrows() {
    for (let progress = 240; progress < track.totalLength; progress += 480) {
      const point = pointAtProgress(progress, 0)
      const screen = worldToScreen(point.x, point.y)
      const size = 16 * camera.zoom

      ctx.save()
      ctx.translate(screen.x, screen.y)
      ctx.rotate(point.angle)
      ctx.fillStyle = "rgba(77, 227, 192, 0.55)"
      ctx.beginPath()
      ctx.moveTo(size, 0)
      ctx.lineTo(-size * 0.8, size * 0.58)
      ctx.lineTo(-size * 0.25, 0)
      ctx.lineTo(-size * 0.8, -size * 0.58)
      ctx.closePath()
      ctx.fill()
      ctx.restore()
    }
  }

  function drawDecor() {
    BOOST_PADS.forEach((pad) => {
      const screen = worldToScreen(pad.x, pad.y)
      const radius = pad.r * camera.zoom
      const pulse = 1 + pad.glow * 0.18

      ctx.fillStyle = `rgba(49, 214, 255, ${0.18 + pad.glow * 0.25})`
      ctx.beginPath()
      ctx.arc(screen.x, screen.y, radius * 1.8 * pulse, 0, Math.PI * 2)
      ctx.fill()

      ctx.fillStyle = "#54d8ff"
      ctx.beginPath()
      ctx.arc(screen.x, screen.y, radius * pulse, 0, Math.PI * 2)
      ctx.fill()

      ctx.strokeStyle = "#d5fbff"
      ctx.lineWidth = Math.max(1, 3 * camera.zoom)
      ctx.beginPath()
      ctx.arc(screen.x, screen.y, radius * 0.54 * pulse, 0, Math.PI * 2)
      ctx.stroke()
    })

    SPILLS.forEach((spill) => {
      const screen = worldToScreen(spill.x, spill.y)
      const radius = spill.r * camera.zoom
      ctx.fillStyle = "#ffdb63"
      ctx.beginPath()
      ctx.ellipse(
        screen.x,
        screen.y,
        radius * (1 + Math.sin(spill.wobble) * 0.08),
        radius * 0.7 * (1 + Math.cos(spill.wobble * 1.3) * 0.08),
        spill.wobble * 0.1,
        0,
        Math.PI * 2
      )
      ctx.fill()
    })

    SHELVES.forEach((shelf) => {
      const topLeft = worldToScreen(shelf.x, shelf.y)
      const bottomRight = worldToScreen(shelf.x + shelf.w, shelf.y + shelf.h)
      const width = bottomRight.x - topLeft.x
      const height = bottomRight.y - topLeft.y

      ctx.fillStyle = "#c7884f"
      ctx.fillRect(topLeft.x, topLeft.y, width, height)
      ctx.strokeStyle = "#8a5828"
      ctx.lineWidth = Math.max(2, 4 * camera.zoom)
      ctx.strokeRect(topLeft.x, topLeft.y, width, height)

      ctx.fillStyle = "rgba(255, 255, 255, 0.18)"
      for (let stripe = 1; stripe < 4; stripe += 1) {
        const stripeY = topLeft.y + (height / 4) * stripe
        ctx.fillRect(topLeft.x + width * 0.08, stripeY, width * 0.84, Math.max(2, 4 * camera.zoom))
      }

      ctx.fillStyle = "#f5ecd8"
      ctx.font = `${Math.max(10, 18 * camera.zoom)}px sans-serif`
      ctx.textAlign = "center"
      ctx.fillText(shelf.label, topLeft.x + width / 2, topLeft.y + height / 2 + 6 * camera.zoom)
    })

    drawStoreSigns()
  }

  function drawStoreSigns() {
    const signs = [
      { x: 210, y: 120, text: "START" },
      { x: 1470, y: 120, text: "EXPRESS" },
      { x: 1470, y: 850, text: "CHECKOUT" },
      { x: 150, y: 850, text: "STOCKROOM" },
    ]

    signs.forEach((sign) => {
      const screen = worldToScreen(sign.x, sign.y)
      ctx.fillStyle = "#182432"
      ctx.fillRect(screen.x - 60 * camera.zoom, screen.y - 18 * camera.zoom, 120 * camera.zoom, 36 * camera.zoom)
      ctx.strokeStyle = "#4de3c0"
      ctx.lineWidth = Math.max(1, 2 * camera.zoom)
      ctx.strokeRect(screen.x - 60 * camera.zoom, screen.y - 18 * camera.zoom, 120 * camera.zoom, 36 * camera.zoom)
      ctx.fillStyle = "#eafaf8"
      ctx.font = `${Math.max(10, 18 * camera.zoom)}px sans-serif`
      ctx.textAlign = "center"
      ctx.fillText(sign.text, screen.x, screen.y + 6 * camera.zoom)
    })
  }

  function drawRacers() {
    placeRacers()
      .slice()
      .reverse()
      .forEach((racer) => {
        const screen = worldToScreen(racer.x, racer.y)
        drawCart(screen.x, screen.y, racer.angle, racer.color, racer.accent, racer === player)
      })
  }

  function drawCart(x, y, angle, color, accent, isPlayer) {
    const scale = camera.zoom
    const bodyLength = isPlayer ? 42 * scale : 36 * scale
    const bodyWidth = isPlayer ? 26 * scale : 22 * scale

    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(angle)

    if (isPlayer && player.bounceFlash > 0) {
      ctx.shadowColor = "rgba(255, 106, 106, 0.65)"
      ctx.shadowBlur = 20 * player.bounceFlash
    }

    ctx.fillStyle = "rgba(0, 0, 0, 0.22)"
    ctx.beginPath()
    ctx.ellipse(-2 * scale, 8 * scale, bodyLength * 0.62, bodyWidth * 0.72, 0, 0, Math.PI * 2)
    ctx.fill()

    ctx.strokeStyle = accent
    ctx.lineWidth = Math.max(2, 3 * scale)
    ctx.strokeRect(-bodyLength * 0.42, -bodyWidth * 0.48, bodyLength * 0.84, bodyWidth * 0.72)

    ctx.fillStyle = color
    ctx.fillRect(-bodyLength * 0.34, -bodyWidth * 0.34, bodyLength * 0.62, bodyWidth * 0.48)

    ctx.strokeStyle = accent
    ctx.beginPath()
    ctx.moveTo(bodyLength * 0.28, -bodyWidth * 0.34)
    ctx.lineTo(bodyLength * 0.52, -bodyWidth * 0.64)
    ctx.lineTo(bodyLength * 0.52, bodyWidth * 0.64)
    ctx.lineTo(bodyLength * 0.28, bodyWidth * 0.34)
    ctx.stroke()

    ctx.fillStyle = "#ecf1f8"
    ctx.fillRect(bodyLength * 0.18, -bodyWidth * 0.16, bodyLength * 0.18, bodyWidth * 0.32)

    ctx.fillStyle = "#1d2733"
    ;[
      [-bodyLength * 0.18, -bodyWidth * 0.48],
      [bodyLength * 0.18, -bodyWidth * 0.48],
      [-bodyLength * 0.18, bodyWidth * 0.48],
      [bodyLength * 0.18, bodyWidth * 0.48],
    ].forEach(([wheelX, wheelY]) => {
      ctx.beginPath()
      ctx.arc(wheelX, wheelY, Math.max(2, 4 * scale), 0, Math.PI * 2)
      ctx.fill()
    })

    if (isPlayer && player.boostBurst > 0.05) {
      ctx.fillStyle = `rgba(255, 184, 77, ${0.4 + player.boostBurst * 0.3})`
      ctx.beginPath()
      ctx.moveTo(-bodyLength * 0.5, 0)
      ctx.lineTo(-bodyLength * 0.88, -bodyWidth * 0.22)
      ctx.lineTo(-bodyLength * 0.88, bodyWidth * 0.22)
      ctx.closePath()
      ctx.fill()
    }

    ctx.restore()
  }

  function drawCountdown() {
    if (race.state === "countdown") {
      const display = race.countdown > 1 ? Math.ceil(race.countdown) : "GO!"
      ctx.fillStyle = "rgba(0, 0, 0, 0.36)"
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.fillStyle = "#ffffff"
      ctx.font = "800 88px sans-serif"
      ctx.textAlign = "center"
      ctx.fillText(String(display), canvas.width * 0.5, canvas.height * 0.5)
      ctx.font = "600 24px sans-serif"
      ctx.fillStyle = "#d5e4f5"
      ctx.fillText("Thread the aisles and hit the boost pads.", canvas.width * 0.5, canvas.height * 0.5 + 56)
    }
  }

  function frame(timestamp) {
    if (!previousTimestamp) {
      previousTimestamp = timestamp
    }
    const delta = clamp((timestamp - previousTimestamp) / 1000, 0, 0.033)
    previousTimestamp = timestamp

    update(delta)
    render()
    requestAnimationFrame(frame)
  }

  function bindKeyboard() {
    const keyMap = {
      ArrowLeft: "left",
      a: "left",
      A: "left",
      ArrowRight: "right",
      d: "right",
      D: "right",
      ArrowDown: "brake",
      s: "brake",
      S: "brake",
      " ": "brake",
      ArrowUp: "boost",
      w: "boost",
      W: "boost",
      Shift: "boost",
    }

    window.addEventListener("keydown", (event) => {
      const control = keyMap[event.key]
      if (!control) {
        return
      }
      input[control] = true
      event.preventDefault()
    })

    window.addEventListener("keyup", (event) => {
      const control = keyMap[event.key]
      if (!control) {
        return
      }
      input[control] = false
      event.preventDefault()
    })
  }

  function bindTouchButtons() {
    document.querySelectorAll("[data-control]").forEach((button) => {
      const control = button.getAttribute("data-control")
      if (!control || !(control in input)) {
        return
      }

      const activate = (event) => {
        input[control] = true
        button.classList.add("is-active")
        event.preventDefault()
      }

      const release = (event) => {
        input[control] = false
        button.classList.remove("is-active")
        event.preventDefault()
      }

      button.addEventListener("pointerdown", activate)
      button.addEventListener("pointerup", release)
      button.addEventListener("pointerleave", release)
      button.addEventListener("pointercancel", release)
      button.addEventListener("touchstart", activate, { passive: false })
      button.addEventListener("touchend", release, { passive: false })
    })
  }

  startButton.addEventListener("click", () => {
    resetRace()
  })

  bindKeyboard()
  bindTouchButtons()
  resetRace()
  showOverlay()
  setOverlay(introTitle, introText, "Start race")
  race.state = "idle"
  requestAnimationFrame(frame)
})()
