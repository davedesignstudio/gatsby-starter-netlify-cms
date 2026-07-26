(function () {
  const canvas = document.getElementById("cart-chaos-canvas")
  if (!canvas) {
    return
  }

  const context = canvas.getContext("2d")
  const restartButton = document.getElementById("cart-chaos-restart")
  const messageEl = document.getElementById("cart-chaos-message")
  const hudLap = document.getElementById("cart-chaos-lap")
  const hudPlace = document.getElementById("cart-chaos-place")
  const hudBoost = document.getElementById("cart-chaos-boost")
  const hudSpeed = document.getElementById("cart-chaos-speed")
  const hudTimer = document.getElementById("cart-chaos-timer")
  const hudStatus = document.getElementById("cart-chaos-status")
  const controlButtons = document.querySelectorAll(".cart-chaos-control")

  const WORLD = {
    width: 2000,
    height: 1200,
    laneHalfWidth: 108,
    startLineX: 170,
    startLineY: 1030,
    waypoints: [
      { x: 250, y: 1030 },
      { x: 760, y: 1030 },
      { x: 1320, y: 1030 },
      { x: 1760, y: 1030 },
      { x: 1820, y: 920 },
      { x: 1820, y: 790 },
      { x: 1270, y: 790 },
      { x: 720, y: 790 },
      { x: 220, y: 790 },
      { x: 180, y: 690 },
      { x: 180, y: 560 },
      { x: 720, y: 560 },
      { x: 1280, y: 560 },
      { x: 1820, y: 560 },
      { x: 1820, y: 450 },
      { x: 1820, y: 320 },
      { x: 1280, y: 320 },
      { x: 720, y: 320 },
      { x: 220, y: 320 },
      { x: 180, y: 220 },
      { x: 180, y: 160 },
      { x: 95, y: 320 },
      { x: 95, y: 720 },
      { x: 175, y: 920 },
      { x: 250, y: 1030 },
    ],
    shelves: [
      { x: 320, y: 120, w: 310, h: 90, label: "produce" },
      { x: 860, y: 120, w: 310, h: 90, label: "snacks" },
      { x: 1400, y: 120, w: 310, h: 90, label: "frozen" },
      { x: 420, y: 400, w: 260, h: 92, label: "soda" },
      { x: 920, y: 400, w: 260, h: 92, label: "cereal" },
      { x: 1420, y: 400, w: 260, h: 92, label: "candy" },
      { x: 320, y: 650, w: 310, h: 92, label: "bakery" },
      { x: 860, y: 650, w: 310, h: 92, label: "toys" },
      { x: 1400, y: 650, w: 310, h: 92, label: "cleanup" },
      { x: 420, y: 900, w: 260, h: 92, label: "pets" },
      { x: 920, y: 900, w: 260, h: 92, label: "garden" },
      { x: 1420, y: 900, w: 260, h: 92, label: "checkout" },
    ],
    spills: [
      { x: 1560, y: 1030, radius: 46, color: "#2ac6ff" },
      { x: 960, y: 790, radius: 40, color: "#43e97b" },
      { x: 500, y: 560, radius: 38, color: "#ff6b6b" },
      { x: 1520, y: 320, radius: 42, color: "#ffd166" },
    ],
    pickupPositions: [
      { x: 1020, y: 1030 },
      { x: 1820, y: 675 },
      { x: 1060, y: 790 },
      { x: 380, y: 560 },
      { x: 1040, y: 320 },
      { x: 95, y: 545 },
      { x: 190, y: 905 },
    ],
  }

  const inputs = {
    left: false,
    right: false,
    throttle: false,
    brake: false,
    boost: false,
  }

  const state = {
    totalLaps: 3,
    timeLimit: 110,
    countdown: 3.4,
    elapsed: 0,
    finished: false,
    finishText: "",
    messageTimer: -1,
    karts: [],
    pickups: [],
    particles: [],
    ranking: [],
    player: null,
    lastFrame: 0,
    camera: {
      x: WORLD.startLineX,
      y: WORLD.startLineY,
      zoom: 0.58,
    },
  }

  const STARTING_GRID = [
    { name: "You", color: "#ffc857", x: 160, y: 1008, ai: false, topSpeed: 585, accel: 660, turn: 3.4 },
    { name: "Mop Bucket", color: "#31d3ff", x: 95, y: 1070, ai: true, topSpeed: 560, accel: 620, turn: 3.05 },
    { name: "Coupon Kid", color: "#ff7a90", x: 92, y: 950, ai: true, topSpeed: 552, accel: 610, turn: 3.1 },
    { name: "Night Shift", color: "#9bff8a", x: 28, y: 1012, ai: true, topSpeed: 545, accel: 600, turn: 3.0 },
  ]

  function setupControlButtons() {
    controlButtons.forEach(function (button) {
      const inputName = button.getAttribute("data-input")
      if (!inputName) {
        return
      }

      const release = function () {
        inputs[inputName] = false
        button.classList.remove("is-active")
      }

      button.addEventListener("pointerdown", function (event) {
        event.preventDefault()
        inputs[inputName] = true
        button.classList.add("is-active")
        if (button.setPointerCapture) {
          button.setPointerCapture(event.pointerId)
        }
      })

      button.addEventListener("pointerup", release)
      button.addEventListener("pointercancel", release)
      button.addEventListener("lostpointercapture", release)
      button.addEventListener("pointerleave", function (event) {
        if (event.buttons === 0) {
          release()
        }
      })
    })
  }

  function setupKeyboard() {
    const keyMap = {
      ArrowLeft: "left",
      KeyA: "left",
      ArrowRight: "right",
      KeyD: "right",
      ArrowUp: "throttle",
      KeyW: "throttle",
      ArrowDown: "brake",
      KeyS: "brake",
      ShiftLeft: "boost",
      ShiftRight: "boost",
      Space: "boost",
    }

    window.addEventListener("keydown", function (event) {
      if (event.code === "KeyR") {
        resetGame()
        return
      }

      const inputName = keyMap[event.code]
      if (!inputName) {
        return
      }

      inputs[inputName] = true
      event.preventDefault()
    })

    window.addEventListener("keyup", function (event) {
      const inputName = keyMap[event.code]
      if (!inputName) {
        return
      }

      inputs[inputName] = false
      event.preventDefault()
    })

    window.addEventListener("blur", resetInputs)
  }

  function resetInputs() {
    Object.keys(inputs).forEach(function (key) {
      inputs[key] = false
    })
    controlButtons.forEach(function (button) {
      button.classList.remove("is-active")
    })
  }

  function resetGame() {
    resetInputs()
    state.countdown = 3.4
    state.elapsed = 0
    state.finished = false
    state.finishText = ""
    state.messageTimer = -1
    state.karts = STARTING_GRID.map(function (kartConfig, index) {
      return createKart(kartConfig, index)
    })
    state.player = state.karts[0]
    state.particles = []
    state.pickups = WORLD.pickupPositions.map(function (position, index) {
      return {
        id: index,
        x: position.x,
        y: position.y,
        radius: 26,
        active: true,
        respawn: 0,
      }
    })
    updateRanking()
    updateHud()
    updateMessage("Countdown: 3")
  }

  function createKart(config, index) {
    return {
      name: config.name,
      color: config.color,
      x: config.x,
      y: config.y,
      angle: 0,
      speed: 0,
      radius: 22,
      boost: 30 + index * 12,
      boostActive: false,
      completedLaps: 0,
      waypointIndex: 0,
      justWrapped: false,
      ai: config.ai,
      topSpeed: config.topSpeed,
      accel: config.accel,
      turnRate: config.turn,
      grip: config.ai ? 0.992 : 0.993,
      shieldTimer: 0,
      subProgress: 0,
      throttleBias: 0,
      lastCollision: 0,
    }
  }

  function update(deltaSeconds) {
    if (state.finished) {
      updateParticles(deltaSeconds)
      updateCamera(deltaSeconds)
      updateHud()
      return
    }

    if (state.countdown > 0) {
      const previousCountdown = state.countdown
      state.countdown = Math.max(0, state.countdown - deltaSeconds)
      const countValue = Math.ceil(state.countdown)
      if (state.countdown > 0.1) {
        updateMessage("Countdown: " + countValue)
      } else if (previousCountdown > 0.1) {
        updateMessage("Go! Grab the energy drinks and boost.", 1.25)
      }
    }

    state.elapsed += deltaSeconds

    if (state.messageTimer > 0) {
      state.messageTimer = Math.max(0, state.messageTimer - deltaSeconds)
      if (state.messageTimer === 0 && !state.finished) {
        hideMessage()
      }
    }

    state.pickups.forEach(function (pickup) {
      if (!pickup.active) {
        pickup.respawn = Math.max(0, pickup.respawn - deltaSeconds)
        if (pickup.respawn === 0) {
          pickup.active = true
        }
      }
    })

    state.karts.forEach(function (kart) {
      if (kart.ai) {
        updateAiControls(kart, deltaSeconds)
      }
      updateKart(kart, deltaSeconds)
      updateWaypointProgress(kart)
      handlePickups(kart)
      handleSpills(kart, deltaSeconds)
      kart.shieldTimer = Math.max(0, kart.shieldTimer - deltaSeconds)
      kart.lastCollision = Math.max(0, kart.lastCollision - deltaSeconds)
    })

    updateParticles(deltaSeconds)
    updateRanking()
    updateCamera(deltaSeconds)

    if (state.elapsed >= state.timeLimit) {
      finishRace("Time is up. " + describePlayerResult())
      return
    }

    const leadingKart = state.ranking[0]
    if (leadingKart && leadingKart.completedLaps >= state.totalLaps) {
      finishRace(leadingKart === state.player ? "You won the store dash!" : leadingKart.name + " hit the checkout first.")
      return
    }

    updateHud()
  }

  function updateAiControls(kart, deltaSeconds) {
    const target = WORLD.waypoints[kart.waypointIndex]
    const dx = target.x - kart.x
    const dy = target.y - kart.y
    const desiredAngle = Math.atan2(dy, dx)
    const turnDelta = normalizeAngle(desiredAngle - kart.angle)
    const steerStrength = clamp(turnDelta * 2.2, -1, 1)

    kart.aiLeft = steerStrength < -0.12
    kart.aiRight = steerStrength > 0.12
    kart.aiThrottle = true
    kart.aiBrake = Math.abs(turnDelta) > 1.0 && kart.speed > kart.topSpeed * 0.45

    const targetDistance = Math.hypot(dx, dy)
    if (kart.boost > 24 && targetDistance > 260 && Math.abs(turnDelta) < 0.16 && kart.completedLaps > 0) {
      kart.aiBoost = true
    } else {
      kart.aiBoost = false
    }

    if (kart.speed < 50 && state.elapsed > 6 && Math.random() < 0.015 * deltaSeconds * 60) {
      kart.angle += (Math.random() - 0.5) * 0.9
    }
  }

  function updateKart(kart, deltaSeconds) {
    const controls = kart.ai
      ? {
          left: kart.aiLeft,
          right: kart.aiRight,
          throttle: kart.aiThrottle,
          brake: kart.aiBrake,
          boost: kart.aiBoost,
        }
      : inputs

    const canMove = state.countdown <= 0
    const offTrack = distanceToTrack(kart.x, kart.y) > WORLD.laneHalfWidth
    const maxForwardSpeed = offTrack ? kart.topSpeed * 0.62 : kart.topSpeed
    const acceleration = offTrack ? kart.accel * 0.55 : kart.accel
    const turnMultiplier = clamp(Math.abs(kart.speed) / Math.max(160, kart.topSpeed), 0.25, 1)

    if (canMove && controls.throttle) {
      kart.speed += acceleration * deltaSeconds
    } else if (canMove && controls.brake) {
      kart.speed -= 840 * deltaSeconds
    } else {
      kart.speed *= kart.grip
      if (offTrack) {
        kart.speed *= 0.985
      }
    }

    if (canMove && controls.left) {
      kart.angle -= kart.turnRate * turnMultiplier * deltaSeconds
    }
    if (canMove && controls.right) {
      kart.angle += kart.turnRate * turnMultiplier * deltaSeconds
    }

    kart.boostActive = false
    if (canMove && controls.boost && kart.boost > 0) {
      kart.speed += 1060 * deltaSeconds
      kart.boost = Math.max(0, kart.boost - 34 * deltaSeconds)
      kart.boostActive = true
      spawnTrail(kart, "rgba(124, 92, 255, 0.5)")
    } else {
      kart.boost = Math.min(100, kart.boost + 8 * deltaSeconds)
    }

    kart.speed = clamp(kart.speed, -180, maxForwardSpeed + (kart.boostActive ? 95 : 0))

    const moveX = Math.cos(kart.angle) * kart.speed * deltaSeconds
    const moveY = Math.sin(kart.angle) * kart.speed * deltaSeconds

    let nextX = kart.x + moveX
    let nextY = kart.y + moveY
    let collided = false

    if (positionBlocked(nextX, kart.y, kart.radius)) {
      nextX = kart.x
      kart.speed *= -0.24
      collided = true
    }

    if (positionBlocked(nextX, nextY, kart.radius)) {
      nextY = kart.y
      kart.speed *= -0.24
      collided = true
    }

    if (collided && kart.lastCollision === 0) {
      spawnImpact(nextX, nextY, kart.color)
      kart.lastCollision = 0.12
    }

    kart.x = nextX
    kart.y = nextY
  }

  function positionBlocked(x, y, radius) {
    if (x - radius < 28 || x + radius > WORLD.width - 28 || y - radius < 28 || y + radius > WORLD.height - 28) {
      return true
    }

    return WORLD.shelves.some(function (shelf) {
      return circleRectCollision(x, y, radius, shelf)
    })
  }

  function handlePickups(kart) {
    state.pickups.forEach(function (pickup) {
      if (!pickup.active) {
        return
      }

      const distance = Math.hypot(kart.x - pickup.x, kart.y - pickup.y)
      if (distance <= kart.radius + pickup.radius) {
        pickup.active = false
        pickup.respawn = 5.2
        kart.boost = Math.min(100, kart.boost + 28)
        if (kart === state.player) {
          updateMessage("Energy drink snagged. Hit boost to rocket ahead.", 2.2)
        }
      }
    })
  }

  function handleSpills(kart, deltaSeconds) {
    WORLD.spills.forEach(function (spill) {
      const distance = Math.hypot(kart.x - spill.x, kart.y - spill.y)
      if (distance < spill.radius + kart.radius) {
        kart.speed *= 0.984
        if (!kart.ai) {
          kart.boost = Math.max(0, kart.boost - 8 * deltaSeconds)
        }
      }
    })
  }

  function updateWaypointProgress(kart) {
    const currentTarget = WORLD.waypoints[kart.waypointIndex]
    const previousIndex = kart.waypointIndex === 0 ? WORLD.waypoints.length - 2 : kart.waypointIndex - 1
    const previousPoint = WORLD.waypoints[previousIndex]
    const segmentLength = Math.max(1, Math.hypot(currentTarget.x - previousPoint.x, currentTarget.y - previousPoint.y))
    const distanceToTarget = Math.hypot(currentTarget.x - kart.x, currentTarget.y - kart.y)

    kart.subProgress = 1 - clamp(distanceToTarget / segmentLength, 0, 1)

    if (distanceToTarget <= 78) {
      kart.waypointIndex += 1
      if (kart.waypointIndex >= WORLD.waypoints.length - 1) {
        kart.waypointIndex = 0
        kart.completedLaps += 1
      }
    }
  }

  function updateRanking() {
    state.ranking = state.karts
      .slice()
      .sort(function (a, b) {
        return progressScore(b) - progressScore(a)
      })
  }

  function progressScore(kart) {
    return kart.completedLaps * (WORLD.waypoints.length - 1) + kart.waypointIndex + kart.subProgress
  }

  function finishRace(message) {
    state.finished = true
    state.finishText = message
    updateRanking()
    updateHud()
    updateMessage(message)
  }

  function describePlayerResult() {
    const place = state.ranking.indexOf(state.player) + 1
    if (place === 1) {
      return "You were leading when the store closed."
    }
    return "You finished " + ordinal(place) + " overall."
  }

  function updateParticles(deltaSeconds) {
    state.particles = state.particles.filter(function (particle) {
      particle.life -= deltaSeconds
      particle.x += particle.vx * deltaSeconds
      particle.y += particle.vy * deltaSeconds
      particle.vx *= 0.97
      particle.vy *= 0.97
      return particle.life > 0
    })
  }

  function spawnImpact(x, y, color) {
    for (let index = 0; index < 10; index += 1) {
      const angle = Math.random() * Math.PI * 2
      const speed = 110 + Math.random() * 180
      state.particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: color,
        size: 2 + Math.random() * 4,
        life: 0.28 + Math.random() * 0.2,
      })
    }
  }

  function spawnTrail(kart, color) {
    if (Math.random() > 0.65) {
      return
    }

    state.particles.push({
      x: kart.x - Math.cos(kart.angle) * 18,
      y: kart.y - Math.sin(kart.angle) * 18,
      vx: (Math.random() - 0.5) * 16,
      vy: (Math.random() - 0.5) * 16,
      color: color,
      size: 4 + Math.random() * 3,
      life: 0.12 + Math.random() * 0.1,
    })
  }

  function updateCamera(deltaSeconds) {
    if (!state.player) {
      return
    }

    const targetX = state.player.x + Math.cos(state.player.angle) * 160
    const targetY = state.player.y + Math.sin(state.player.angle) * 110
    const cameraEase = clamp(deltaSeconds * 4.4, 0, 1)
    state.camera.x += (targetX - state.camera.x) * cameraEase
    state.camera.y += (targetY - state.camera.y) * cameraEase
    state.camera.zoom = window.innerWidth < 720 ? 0.5 : 0.58
  }

  function updateHud() {
    if (!state.player) {
      return
    }

    const place = state.ranking.indexOf(state.player) + 1
    const shownLap = Math.min(state.totalLaps, state.player.completedLaps + 1)
    hudLap.textContent = shownLap + " / " + state.totalLaps
    hudPlace.textContent = ordinal(place) + " / " + state.karts.length
    hudSpeed.textContent = Math.round(Math.max(0, state.player.speed) * 0.18) + " mph"
    hudTimer.textContent = formatTime(Math.max(0, state.timeLimit - state.elapsed))
    hudStatus.textContent = state.finished
      ? "Finished"
      : state.countdown > 0
      ? "Countdown"
      : place === 1
      ? "Leading"
      : "Chasing"
    hudBoost.style.width = state.player.boost + "%"
  }

  function updateMessage(text, durationSeconds) {
    messageEl.textContent = text
    messageEl.classList.remove("is-hidden")
    state.messageTimer = typeof durationSeconds === "number" ? durationSeconds : -1
  }

  function hideMessage() {
    messageEl.classList.add("is-hidden")
  }

  function render() {
    context.setTransform(1, 0, 0, 1, 0, 0)
    context.clearRect(0, 0, canvas.width, canvas.height)
    context.fillStyle = "#0a0f16"
    context.fillRect(0, 0, canvas.width, canvas.height)

    context.save()
    context.translate(canvas.width / 2, canvas.height / 2)
    context.scale(state.camera.zoom, state.camera.zoom)
    context.translate(-state.camera.x, -state.camera.y)

    drawStoreFloor()
    drawTrack()
    drawShelves()
    drawSpills()
    drawPickups()
    drawStartLine()
    drawParticles()
    state.karts.forEach(drawKart)

    context.restore()

    drawMiniMap()
  }

  function drawStoreFloor() {
    const gradient = context.createLinearGradient(0, 0, WORLD.width, WORLD.height)
    gradient.addColorStop(0, "#161c26")
    gradient.addColorStop(1, "#0d1118")
    context.fillStyle = gradient
    context.fillRect(0, 0, WORLD.width, WORLD.height)

    context.strokeStyle = "rgba(255, 255, 255, 0.035)"
    context.lineWidth = 1
    for (let x = 0; x <= WORLD.width; x += 80) {
      context.beginPath()
      context.moveTo(x, 0)
      context.lineTo(x, WORLD.height)
      context.stroke()
    }
    for (let y = 0; y <= WORLD.height; y += 80) {
      context.beginPath()
      context.moveTo(0, y)
      context.lineTo(WORLD.width, y)
      context.stroke()
    }
  }

  function drawTrack() {
    context.save()
    traceRaceLine()
    context.strokeStyle = "rgba(255, 196, 74, 0.14)"
    context.lineWidth = WORLD.laneHalfWidth * 2 + 30
    context.lineCap = "round"
    context.lineJoin = "round"
    context.stroke()

    traceRaceLine()
    context.strokeStyle = "#2a3444"
    context.lineWidth = WORLD.laneHalfWidth * 2
    context.lineCap = "round"
    context.lineJoin = "round"
    context.stroke()

    traceRaceLine()
    context.strokeStyle = "rgba(255, 255, 255, 0.08)"
    context.lineWidth = WORLD.laneHalfWidth * 2 - 30
    context.lineCap = "round"
    context.lineJoin = "round"
    context.stroke()

    traceRaceLine()
    context.setLineDash([48, 32])
    context.strokeStyle = "rgba(255, 255, 255, 0.22)"
    context.lineWidth = 6
    context.stroke()
    context.setLineDash([])
    context.restore()
  }

  function traceRaceLine() {
    context.beginPath()
    WORLD.waypoints.forEach(function (point, index) {
      if (index === 0) {
        context.moveTo(point.x, point.y)
      } else {
        context.lineTo(point.x, point.y)
      }
    })
  }

  function drawShelves() {
    WORLD.shelves.forEach(function (shelf) {
      context.fillStyle = "#2f3948"
      fillRoundedRect(shelf.x, shelf.y, shelf.w, shelf.h, 14)
      context.fillStyle = "#1c2430"
      fillRoundedRect(shelf.x + 10, shelf.y + 10, shelf.w - 20, shelf.h - 20, 12)

      for (let x = shelf.x + 22; x < shelf.x + shelf.w - 18; x += 26) {
        context.fillStyle = x % 52 === 0 ? "#ff8c61" : "#6fe7dd"
        context.fillRect(x, shelf.y + 24, 12, shelf.h - 48)
      }

      context.fillStyle = "rgba(255, 255, 255, 0.72)"
      context.font = "bold 18px Arial"
      context.textAlign = "center"
      context.fillText(shelf.label.toUpperCase(), shelf.x + shelf.w / 2, shelf.y + shelf.h / 2 + 7)
    })
  }

  function drawSpills() {
    WORLD.spills.forEach(function (spill) {
      const gradient = context.createRadialGradient(spill.x, spill.y, 8, spill.x, spill.y, spill.radius)
      gradient.addColorStop(0, spill.color)
      gradient.addColorStop(1, "rgba(255, 255, 255, 0.02)")
      context.fillStyle = gradient
      context.beginPath()
      context.arc(spill.x, spill.y, spill.radius, 0, Math.PI * 2)
      context.fill()
    })
  }

  function drawPickups() {
    const pulse = 0.75 + Math.sin(state.elapsed * 5.5) * 0.15

    state.pickups.forEach(function (pickup) {
      if (!pickup.active) {
        return
      }

      context.save()
      context.translate(pickup.x, pickup.y - 6)
      context.scale(pulse, pulse)
      context.fillStyle = "#7c5cff"
      fillRoundedRect(-15, -18, 30, 36, 9)
      context.fillStyle = "#31d3ff"
      context.fillRect(-7, -12, 14, 24)
      context.fillStyle = "#ffffff"
      context.fillRect(-3, -18, 6, 4)
      context.restore()
    })
  }

  function drawStartLine() {
    const yTop = WORLD.startLineY - 90
    const tileSize = 18
    for (let row = 0; row < 10; row += 1) {
      for (let column = 0; column < 2; column += 1) {
        context.fillStyle = (row + column) % 2 === 0 ? "#ffffff" : "#11151c"
        context.fillRect(WORLD.startLineX + column * tileSize, yTop + row * tileSize, tileSize, tileSize)
      }
    }
  }

  function drawKart(kart) {
    context.save()
    context.translate(kart.x, kart.y)
    context.rotate(kart.angle)

    context.fillStyle = "rgba(0, 0, 0, 0.34)"
    context.beginPath()
    context.ellipse(0, 18, 24, 10, 0, 0, Math.PI * 2)
    context.fill()

    if (kart.boostActive) {
      context.fillStyle = "rgba(49, 211, 255, 0.3)"
      context.beginPath()
      context.ellipse(-24, 0, 26, 12, 0, 0, Math.PI * 2)
      context.fill()
    }

    context.fillStyle = "#0c1118"
    fillRoundedRect(-22, -18, 44, 36, 12)
    context.fillStyle = kart.color
    fillRoundedRect(-16, -14, 32, 28, 10)
    context.fillStyle = "#dfe8f5"
    context.fillRect(-6, -12, 12, 18)
    context.fillStyle = "#0c1118"
    context.fillRect(-12, -6, 24, 4)
    context.fillRect(-26, -18, 8, 12)
    context.fillRect(18, -18, 8, 12)
    context.fillRect(-26, 6, 8, 12)
    context.fillRect(18, 6, 8, 12)

    if (kart === state.player) {
      context.strokeStyle = "#ffffff"
      context.lineWidth = 3
      strokeRoundedRect(-20, -16, 40, 32, 12)
    }

    context.restore()

    context.fillStyle = "rgba(255, 255, 255, 0.8)"
    context.font = "bold 16px Arial"
    context.textAlign = "center"
    context.fillText(kart.name, kart.x, kart.y - 30)
  }

  function drawParticles() {
    state.particles.forEach(function (particle) {
      context.globalAlpha = clamp(particle.life * 2.4, 0, 1)
      context.fillStyle = particle.color
      context.beginPath()
      context.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2)
      context.fill()
      context.globalAlpha = 1
    })
  }

  function drawMiniMap() {
    const mapWidth = 220
    const mapHeight = 132
    const mapX = 20
    const mapY = 18
    const scaleX = mapWidth / WORLD.width
    const scaleY = mapHeight / WORLD.height

    context.save()
    context.fillStyle = "rgba(6, 10, 16, 0.78)"
    fillRoundedRect(mapX, mapY, mapWidth + 20, mapHeight + 20, 18)
    context.translate(mapX + 10, mapY + 10)

    context.strokeStyle = "rgba(255, 255, 255, 0.18)"
    context.lineWidth = 1.2
    context.strokeRect(0, 0, mapWidth, mapHeight)

    context.beginPath()
    WORLD.waypoints.forEach(function (point, index) {
      const x = point.x * scaleX
      const y = point.y * scaleY
      if (index === 0) {
        context.moveTo(x, y)
      } else {
        context.lineTo(x, y)
      }
    })
    context.strokeStyle = "rgba(255, 200, 87, 0.65)"
    context.lineWidth = 8
    context.lineCap = "round"
    context.lineJoin = "round"
    context.stroke()

    WORLD.shelves.forEach(function (shelf) {
      context.fillStyle = "rgba(255, 255, 255, 0.14)"
      context.fillRect(shelf.x * scaleX, shelf.y * scaleY, shelf.w * scaleX, shelf.h * scaleY)
    })

    state.karts.forEach(function (kart) {
      context.fillStyle = kart.color
      context.beginPath()
      context.arc(kart.x * scaleX, kart.y * scaleY, kart === state.player ? 5 : 4, 0, Math.PI * 2)
      context.fill()
    })

    context.restore()
  }

  function animate(timestamp) {
    if (!state.lastFrame) {
      state.lastFrame = timestamp
    }
    const deltaSeconds = Math.min(0.033, (timestamp - state.lastFrame) / 1000)
    state.lastFrame = timestamp

    update(deltaSeconds)
    render()
    requestAnimationFrame(animate)
  }

  function distanceToTrack(x, y) {
    let bestDistance = Infinity
    for (let index = 0; index < WORLD.waypoints.length - 1; index += 1) {
      const from = WORLD.waypoints[index]
      const to = WORLD.waypoints[index + 1]
      const distance = distanceToSegment(x, y, from.x, from.y, to.x, to.y)
      if (distance < bestDistance) {
        bestDistance = distance
      }
    }
    return bestDistance
  }

  function distanceToSegment(px, py, x1, y1, x2, y2) {
    const segmentX = x2 - x1
    const segmentY = y2 - y1
    const lengthSquared = segmentX * segmentX + segmentY * segmentY
    if (lengthSquared === 0) {
      return Math.hypot(px - x1, py - y1)
    }
    const projection = clamp(((px - x1) * segmentX + (py - y1) * segmentY) / lengthSquared, 0, 1)
    const nearestX = x1 + projection * segmentX
    const nearestY = y1 + projection * segmentY
    return Math.hypot(px - nearestX, py - nearestY)
  }

  function circleRectCollision(cx, cy, radius, rect) {
    const closestX = clamp(cx, rect.x, rect.x + rect.w)
    const closestY = clamp(cy, rect.y, rect.y + rect.h)
    return Math.hypot(cx - closestX, cy - closestY) < radius
  }

  function fillRoundedRect(x, y, width, height, radius) {
    context.beginPath()
    context.moveTo(x + radius, y)
    context.lineTo(x + width - radius, y)
    context.quadraticCurveTo(x + width, y, x + width, y + radius)
    context.lineTo(x + width, y + height - radius)
    context.quadraticCurveTo(x + width, y + height, x + width - radius, y + height)
    context.lineTo(x + radius, y + height)
    context.quadraticCurveTo(x, y + height, x, y + height - radius)
    context.lineTo(x, y + radius)
    context.quadraticCurveTo(x, y, x + radius, y)
    context.closePath()
    context.fill()
  }

  function strokeRoundedRect(x, y, width, height, radius) {
    context.beginPath()
    context.moveTo(x + radius, y)
    context.lineTo(x + width - radius, y)
    context.quadraticCurveTo(x + width, y, x + width, y + radius)
    context.lineTo(x + width, y + height - radius)
    context.quadraticCurveTo(x + width, y + height, x + width - radius, y + height)
    context.lineTo(x + radius, y + height)
    context.quadraticCurveTo(x, y + height, x, y + height - radius)
    context.lineTo(x, y + radius)
    context.quadraticCurveTo(x, y, x + radius, y)
    context.closePath()
    context.stroke()
  }

  function normalizeAngle(angle) {
    while (angle > Math.PI) {
      angle -= Math.PI * 2
    }
    while (angle < -Math.PI) {
      angle += Math.PI * 2
    }
    return angle
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value))
  }

  function ordinal(number) {
    const modTen = number % 10
    const modHundred = number % 100
    if (modTen === 1 && modHundred !== 11) {
      return number + "st"
    }
    if (modTen === 2 && modHundred !== 12) {
      return number + "nd"
    }
    if (modTen === 3 && modHundred !== 13) {
      return number + "rd"
    }
    return number + "th"
  }

  function formatTime(totalSeconds) {
    const safeSeconds = Math.max(0, Math.floor(totalSeconds))
    const minutes = Math.floor(safeSeconds / 60)
    const seconds = safeSeconds % 60
    return String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
  }

  restartButton.addEventListener("click", resetGame)

  setupControlButtons()
  setupKeyboard()
  resetGame()
  requestAnimationFrame(animate)
})()
