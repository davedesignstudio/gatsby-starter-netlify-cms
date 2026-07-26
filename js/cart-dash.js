(() => {
  "use strict";

  const canvas = document.querySelector("#game");
  const ctx = canvas.getContext("2d");
  const shell = document.querySelector("#game-shell");
  const raceUI = document.querySelector("#race-ui");
  const message = document.querySelector("#race-message");
  const positionEl = document.querySelector("#position");
  const lapEl = document.querySelector("#lap");
  const itemSlot = document.querySelector(".item-slot");
  const itemIcon = document.querySelector("#item-icon");
  const itemLabel = document.querySelector("#item-label");
  const boostLines = document.querySelector("#speed-lines");

  const WORLD = { width: 1800, height: 1100 };
  const TOTAL_LAPS = 3;
  const keys = { up: false, down: false, left: false, right: false, drift: false };
  const camera = { x: 900, y: 550, zoom: 1 };
  let mode = "menu";
  let countdown = 0;
  let raceStart = 0;
  let elapsed = 0;
  let lastTime = performance.now();
  let animationId = 0;
  let muted = false;
  let audioContext = null;
  let itemPressed = false;

  const waypoints = [
    { x: 240, y: 205 },
    { x: 890, y: 205 },
    { x: 1570, y: 205 },
    { x: 1635, y: 510 },
    { x: 1580, y: 900 },
    { x: 1320, y: 900 },
    { x: 1305, y: 315 },
    { x: 1010, y: 315 },
    { x: 995, y: 900 },
    { x: 705, y: 900 },
    { x: 690, y: 315 },
    { x: 395, y: 315 },
    { x: 390, y: 900 },
    { x: 175, y: 865 },
    { x: 165, y: 475 },
    { x: 240, y: 205 },
  ];

  const shelves = [
    { x: 455, y: 405, w: 170, h: 355, color: "#e76b53", label: "SNACKS" },
    { x: 760, y: 405, w: 170, h: 355, color: "#50afd2", label: "CEREAL" },
    { x: 1065, y: 405, w: 170, h: 355, color: "#dbb936", label: "PANTRY" },
    { x: 1375, y: 405, w: 130, h: 355, color: "#75b45c", label: "FRESH" },
    { x: 540, y: 60, w: 155, h: 80, color: "#965fc2", label: "BAKERY" },
    { x: 1080, y: 60, w: 190, h: 80, color: "#e16086", label: "DELI" },
  ];

  const decor = [
    { x: 95, y: 100, kind: "plant" },
    { x: 1650, y: 100, kind: "plant" },
    { x: 90, y: 970, kind: "crate" },
    { x: 1640, y: 970, kind: "crate" },
    { x: 820, y: 1000, kind: "crate" },
  ];

  const pickups = [
    { x: 840, y: 205, active: true, timer: 0 },
    { x: 1585, y: 620, active: true, timer: 0 },
    { x: 1160, y: 900, active: true, timer: 0 },
    { x: 845, y: 900, active: true, timer: 0 },
    { x: 540, y: 315, active: true, timer: 0 },
    { x: 170, y: 610, active: true, timer: 0 },
  ];

  const spills = [
    { x: 1510, y: 300, r: 34 },
    { x: 1135, y: 820, r: 38 },
    { x: 535, y: 845, r: 32 },
    { x: 325, y: 235, r: 30 },
  ];

  const racers = [];
  let player = null;

  function createRacer(options) {
    return {
      x: options.x,
      y: options.y,
      angle: options.angle || 0,
      speed: 0,
      color: options.color,
      accent: options.accent,
      name: options.name,
      emoji: options.emoji,
      target: 1,
      lap: 0,
      finished: false,
      finishTime: 0,
      radius: 24,
      boost: 0,
      item: null,
      ai: Boolean(options.ai),
      skill: options.skill || 1,
      wobble: Math.random() * Math.PI * 2,
      lastLapAt: 0,
      lapTimes: [],
      position: 1,
      hitCooldown: 0,
      slip: 0,
    };
  }

  function resetRace() {
    racers.length = 0;
    player = createRacer({
      x: 235,
      y: 188,
      color: "#d9ff43",
      accent: "#22222a",
      name: "You",
      emoji: "🧢",
    });
    racers.push(
      player,
      createRacer({ x: 190, y: 230, color: "#ff674d", accent: "#ffd45c", name: "Mara", emoji: "🧣", ai: true, skill: 1.01 }),
      createRacer({ x: 130, y: 185, color: "#49bdf8", accent: "#24334c", name: "Dee", emoji: "🎧", ai: true, skill: .97 }),
      createRacer({ x: 85, y: 230, color: "#bd75f5", accent: "#f3b6e5", name: "Sol", emoji: "🧤", ai: true, skill: 1.04 })
    );
    pickups.forEach((pickup) => {
      pickup.active = true;
      pickup.timer = 0;
    });
    elapsed = 0;
    raceStart = 0;
    countdown = 3.8;
    updateItemUI();
    updateHUD();
  }

  function showScreen(id) {
    document.querySelectorAll(".screen").forEach((screen) => screen.classList.remove("active"));
    if (id) document.querySelector(id).classList.add("active");
  }

  function startRace() {
    resetRace();
    showScreen(null);
    raceUI.classList.add("active");
    mode = "countdown";
    camera.x = player.x;
    camera.y = player.y;
    beep(320, .08);
  }

  function pauseRace() {
    if (mode !== "racing" && mode !== "countdown") return;
    mode = "paused";
    showScreen("#pause-screen");
    clearControls();
  }

  function resumeRace() {
    showScreen(null);
    mode = "racing";
    lastTime = performance.now();
  }

  function menu() {
    mode = "menu";
    clearControls();
    raceUI.classList.remove("active");
    boostLines.classList.remove("active");
    showScreen("#home-screen");
  }

  function clearControls() {
    Object.keys(keys).forEach((key) => { keys[key] = false; });
    document.querySelectorAll("[data-control]").forEach((button) => button.classList.remove("pressed"));
  }

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(innerWidth * dpr);
    canvas.height = Math.round(innerHeight * dpr);
    canvas.style.width = `${innerWidth}px`;
    canvas.style.height = `${innerHeight}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function shortestAngle(from, to) {
    let difference = (to - from + Math.PI) % (Math.PI * 2) - Math.PI;
    if (difference < -Math.PI) difference += Math.PI * 2;
    return difference;
  }

  function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y);
  }

  function movePlayer(dt) {
    if (mode !== "racing") return;
    const boosting = player.boost > 0;
    const maxSpeed = boosting ? 530 : 345;
    const acceleration = boosting ? 410 : 270;
    if (keys.up) player.speed += acceleration * dt;
    else player.speed -= 72 * dt;
    if (keys.down) player.speed -= 260 * dt;

    player.speed = Math.max(-105, Math.min(maxSpeed, player.speed));
    const speedRatio = Math.min(1, Math.abs(player.speed) / 180);
    const steer = (keys.right ? 1 : 0) - (keys.left ? 1 : 0);
    const turnStrength = keys.drift ? 3.05 : 2.05;
    player.angle += steer * turnStrength * speedRatio * dt * (player.speed >= 0 ? 1 : -1);

    if (keys.drift && steer && Math.abs(player.speed) > 150) {
      player.slip = Math.min(1, player.slip + dt * 5);
      player.speed -= 30 * dt;
      if (Math.random() < dt * 12) addParticle(player.x, player.y, "#d7d7d9", 1);
    } else {
      player.slip = Math.max(0, player.slip - dt * 4);
    }

    const movementAngle = player.angle - steer * player.slip * .22;
    player.x += Math.cos(movementAngle) * player.speed * dt;
    player.y += Math.sin(movementAngle) * player.speed * dt;
    player.speed *= Math.pow(.996, dt * 60);
    if (player.boost > 0) player.boost -= dt;
    if (player.hitCooldown > 0) player.hitCooldown -= dt;
    collideWorld(player);
    collectPickups(player);
    checkSpills(player);
    updateWaypoint(player);
  }

  function moveAI(racer, dt) {
    if (mode !== "racing" || racer.finished) return;
    const target = waypoints[racer.target];
    const wobble = Math.sin(elapsed * 1.1 + racer.wobble) * 12;
    const desired = Math.atan2(target.y - racer.y + wobble, target.x - racer.x - wobble);
    const difference = shortestAngle(racer.angle, desired);
    racer.angle += Math.max(-2.2 * dt, Math.min(2.2 * dt, difference));

    const cornerSlowdown = Math.min(1, Math.max(.54, 1 - Math.abs(difference) * .35));
    const targetSpeed = (racer.boost > 0 ? 455 : 310 * racer.skill) * cornerSlowdown;
    racer.speed += (targetSpeed - racer.speed) * dt * 2.4;
    racer.x += Math.cos(racer.angle) * racer.speed * dt;
    racer.y += Math.sin(racer.angle) * racer.speed * dt;
    if (racer.boost > 0) racer.boost -= dt;
    if (racer.hitCooldown > 0) racer.hitCooldown -= dt;
    collideWorld(racer);
    collectPickups(racer);
    updateWaypoint(racer);
    if (racer.item && Math.random() < dt * .18) useItem(racer);
  }

  function collideWorld(racer) {
    const margin = 42;
    if (racer.x < margin || racer.x > WORLD.width - margin) {
      racer.x = Math.max(margin, Math.min(WORLD.width - margin, racer.x));
      racer.speed *= -.28;
      collisionFeedback(racer);
    }
    if (racer.y < margin || racer.y > WORLD.height - margin) {
      racer.y = Math.max(margin, Math.min(WORLD.height - margin, racer.y));
      racer.speed *= -.28;
      collisionFeedback(racer);
    }

    shelves.forEach((shelf) => {
      const nearestX = Math.max(shelf.x, Math.min(racer.x, shelf.x + shelf.w));
      const nearestY = Math.max(shelf.y, Math.min(racer.y, shelf.y + shelf.h));
      const dx = racer.x - nearestX;
      const dy = racer.y - nearestY;
      const length = Math.hypot(dx, dy);
      if (length < racer.radius + 5) {
        const nx = length ? dx / length : (racer.x < shelf.x + shelf.w / 2 ? -1 : 1);
        const ny = length ? dy / length : 0;
        const push = racer.radius + 6 - length;
        racer.x += nx * push;
        racer.y += ny * push;
        racer.speed *= -.2;
        collisionFeedback(racer);
      }
    });

    racers.forEach((other) => {
      if (other === racer) return;
      const dx = racer.x - other.x;
      const dy = racer.y - other.y;
      const length = Math.hypot(dx, dy);
      if (length > 0 && length < racer.radius + other.radius - 5) {
        const overlap = (racer.radius + other.radius - 5 - length) / 2;
        racer.x += dx / length * overlap;
        racer.y += dy / length * overlap;
        racer.speed *= .92;
      }
    });
  }

  function collisionFeedback(racer) {
    if (racer.hitCooldown > 0) return;
    racer.hitCooldown = .35;
    addParticle(racer.x, racer.y, "#f2d34f", 7);
    if (racer === player) beep(95, .07, "square");
  }

  function checkSpills(racer) {
    spills.forEach((spill) => {
      if (distance(racer, spill) < spill.r + racer.radius - 7 && Math.abs(racer.speed) > 120) {
        racer.angle += .9 * (Math.random() > .5 ? 1 : -1);
        racer.speed *= .72;
        addParticle(racer.x, racer.y, "#78d8e7", 5);
      }
    });
  }

  function collectPickups(racer) {
    pickups.forEach((pickup) => {
      if (pickup.active && distance(racer, pickup) < 45) {
        pickup.active = false;
        pickup.timer = 5.5;
        racer.item = "boost";
        addParticle(pickup.x, pickup.y, "#d9ff43", 14);
        if (racer === player) {
          updateItemUI();
          beep(650, .08);
          setTimeout(() => beep(900, .09), 75);
        }
      }
    });
  }

  function useItem(racer) {
    if (!racer.item) return;
    racer.item = null;
    racer.boost = 2.2;
    racer.speed = Math.max(racer.speed, 300);
    addParticle(racer.x, racer.y, racer.color, 18);
    if (racer === player) {
      updateItemUI();
      boostLines.classList.add("active");
      beep(180, .22, "sawtooth", 520);
      setTimeout(() => boostLines.classList.remove("active"), 2200);
    }
  }

  function updateWaypoint(racer) {
    const target = waypoints[racer.target];
    if (distance(racer, target) > 112) return;
    racer.target = (racer.target + 1) % waypoints.length;
    if (racer.target === 1) {
      racer.lap += 1;
      const now = elapsed;
      racer.lapTimes.push(now - racer.lastLapAt);
      racer.lastLapAt = now;
      if (racer.lap >= TOTAL_LAPS) finishRacer(racer);
      else if (racer === player) {
        lapEl.textContent = String(racer.lap + 1);
        flashMessage(`LAP ${racer.lap + 1}`);
        beep(520, .08);
      }
    }
  }

  function finishRacer(racer) {
    if (racer.finished) return;
    racer.finished = true;
    racer.finishTime = elapsed;
    if (racer === player) {
      mode = "finished";
      player.speed *= .7;
      setTimeout(showFinish, 800);
    }
  }

  function racerProgress(racer) {
    const previous = (racer.target - 1 + waypoints.length) % waypoints.length;
    const sectionLength = distance(waypoints[previous], waypoints[racer.target]) || 1;
    const remaining = distance(racer, waypoints[racer.target]);
    const fraction = Math.max(0, Math.min(.99, 1 - remaining / sectionLength));
    return racer.lap * waypoints.length + previous + fraction;
  }

  function updatePositions() {
    const ranked = [...racers].sort((a, b) => {
      if (a.finished && b.finished) return a.finishTime - b.finishTime;
      if (a.finished) return -1;
      if (b.finished) return 1;
      return racerProgress(b) - racerProgress(a);
    });
    ranked.forEach((racer, index) => { racer.position = index + 1; });
    const suffix = player.position === 1 ? "st" : player.position === 2 ? "nd" : player.position === 3 ? "rd" : "th";
    positionEl.innerHTML = `${player.position}<sup>${suffix}</sup>`;
  }

  function updateItemUI() {
    const ready = Boolean(player && player.item);
    itemSlot.classList.toggle("ready", ready);
    itemIcon.textContent = ready ? "⚡" : "?";
    itemLabel.textContent = ready ? "BOOST" : "ITEM";
  }

  function updateHUD() {
    lapEl.textContent = String(Math.min(TOTAL_LAPS, (player?.lap || 0) + 1));
    positionEl.innerHTML = "1<sup>st</sup>";
  }

  function flashMessage(text, color = "#f7f4ea") {
    message.textContent = text;
    message.style.color = color;
    message.classList.remove("show");
    void message.offsetWidth;
    message.classList.add("show");
  }

  function showFinish() {
    raceUI.classList.remove("active");
    const position = player.position;
    document.querySelector("#finish-badge").textContent = String(position);
    document.querySelector("#finish-title").textContent =
      position === 1 ? "Aisle champion!" : position === 2 ? "So close!" : "Wild ride!";
    document.querySelector("#finish-copy").textContent =
      position === 1
        ? "You left the competition in the cereal dust."
        : "One more run and that checkout lane is yours.";
    document.querySelector("#finish-time").textContent = formatTime(player.finishTime);
    const best = Math.min(...player.lapTimes);
    document.querySelector("#best-lap").textContent = formatTime(Number.isFinite(best) ? best : player.finishTime);
    showScreen("#finish-screen");
    beep(position === 1 ? 740 : 440, .14);
    setTimeout(() => beep(position === 1 ? 980 : 620, .2), 150);
  }

  function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainder = (seconds % 60).toFixed(2).padStart(5, "0");
    return `${minutes}:${remainder}`;
  }

  const particles = [];

  function addParticle(x, y, color, count) {
    for (let i = 0; i < count; i += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 45 + Math.random() * 110;
      particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: .35 + Math.random() * .55,
        maxLife: .9,
        color,
        size: 2 + Math.random() * 5,
      });
    }
  }

  function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i -= 1) {
      const particle = particles[i];
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= .96;
      particle.vy *= .96;
      particle.life -= dt;
      if (particle.life <= 0) particles.splice(i, 1);
    }
  }

  function update(dt) {
    if (mode === "countdown") {
      const oldCount = Math.ceil(countdown);
      countdown -= dt;
      const newCount = Math.ceil(countdown);
      if (newCount !== oldCount && newCount > 0) {
        flashMessage(String(newCount), "#d9ff43");
        beep(330 + (3 - newCount) * 90, .07);
      }
      if (countdown <= 0) {
        mode = "racing";
        raceStart = performance.now();
        flashMessage("GO!", "#d9ff43");
        beep(720, .16);
      }
    } else if (mode === "racing") {
      elapsed += dt;
      movePlayer(dt);
      racers.filter((racer) => racer.ai).forEach((racer) => moveAI(racer, dt));
      pickups.forEach((pickup) => {
        if (!pickup.active) {
          pickup.timer -= dt;
          if (pickup.timer <= 0) pickup.active = true;
        }
      });
      updatePositions();
    } else if (mode === "finished") {
      player.speed *= Math.pow(.96, dt * 60);
      player.x += Math.cos(player.angle) * player.speed * dt;
      player.y += Math.sin(player.angle) * player.speed * dt;
    }
    updateParticles(dt);
    if (player && mode !== "menu") {
      const landscape = innerWidth > innerHeight;
      camera.zoom = Math.min(1.05, Math.max(.62, (landscape ? innerHeight : innerWidth) / 720));
      camera.x += (player.x + Math.cos(player.angle) * 85 - camera.x) * Math.min(1, dt * 4.5);
      camera.y += (player.y + Math.sin(player.angle) * 85 - camera.y) * Math.min(1, dt * 4.5);
    }
  }

  function draw() {
    ctx.clearRect(0, 0, innerWidth, innerHeight);
    if (mode === "menu") {
      drawMenuBackdrop();
      return;
    }
    ctx.save();
    ctx.translate(innerWidth / 2, innerHeight / 2);
    ctx.scale(camera.zoom, camera.zoom);
    ctx.translate(-camera.x, -camera.y);
    drawStore();
    drawTrackDetails();
    drawPickups();
    drawParticles();
    [...racers].sort((a, b) => a.y - b.y).forEach(drawRacer);
    ctx.restore();
    drawMinimap();
  }

  function drawMenuBackdrop() {
    const gradient = ctx.createLinearGradient(0, 0, innerWidth, innerHeight);
    gradient.addColorStop(0, "#2b1e42");
    gradient.addColorStop(.5, "#151522");
    gradient.addColorStop(1, "#111119");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, innerWidth, innerHeight);
    ctx.globalAlpha = .055;
    ctx.strokeStyle = "#fff";
    for (let x = -innerHeight; x < innerWidth + innerHeight; x += 70) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x - innerHeight * .4, innerHeight);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  function drawStore() {
    ctx.fillStyle = "#dad6ca";
    ctx.fillRect(0, 0, WORLD.width, WORLD.height);

    ctx.lineWidth = 1;
    for (let x = 0; x <= WORLD.width; x += 55) {
      for (let y = 0; y <= WORLD.height; y += 55) {
        ctx.fillStyle = ((x / 55 + y / 55) % 2) ? "#d4d0c4" : "#dedacf";
        ctx.fillRect(x, y, 55, 55);
      }
    }

    ctx.fillStyle = "#262631";
    ctx.fillRect(0, 0, WORLD.width, 34);
    ctx.fillRect(0, WORLD.height - 34, WORLD.width, 34);
    ctx.fillRect(0, 0, 34, WORLD.height);
    ctx.fillRect(WORLD.width - 34, 0, 34, WORLD.height);

    ctx.fillStyle = "#bbb7aa";
    ctx.fillRect(36, 150, WORLD.width - 72, 14);
    ctx.fillRect(36, 962, WORLD.width - 72, 14);

    shelves.forEach(drawShelf);
    decor.forEach(drawDecor);

    ctx.save();
    ctx.translate(184, 205);
    for (let i = 0; i < 8; i += 1) {
      ctx.fillStyle = i % 2 ? "#f6f3e8" : "#292933";
      ctx.fillRect(i * 19, -52, 19, 104);
    }
    ctx.restore();

    ctx.fillStyle = "#292933";
    ctx.font = "900 24px 'Barlow Condensed', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("CHECKOUT →", 1460, 1040);
  }

  function drawShelf(shelf) {
    ctx.save();
    ctx.shadowColor = "rgba(30, 27, 24, .26)";
    ctx.shadowBlur = 14;
    ctx.shadowOffsetY = 9;
    ctx.fillStyle = "#77766f";
    roundedRect(shelf.x, shelf.y, shelf.w, shelf.h, 8);
    ctx.fill();
    ctx.shadowColor = "transparent";

    ctx.fillStyle = "#eee9dc";
    roundedRect(shelf.x + 8, shelf.y + 8, shelf.w - 16, shelf.h - 16, 4);
    ctx.fill();

    const rows = Math.floor((shelf.h - 35) / 42);
    for (let row = 0; row < rows; row += 1) {
      const y = shelf.y + 31 + row * 42;
      ctx.fillStyle = row % 2 ? shelf.color : shadeColor(shelf.color, -18);
      for (let x = shelf.x + 14; x < shelf.x + shelf.w - 17; x += 24) {
        roundedRect(x, y, 17, 26, 2);
        ctx.fill();
      }
      ctx.fillStyle = "#6c6b66";
      ctx.fillRect(shelf.x + 8, y + 28, shelf.w - 16, 4);
    }

    ctx.fillStyle = shelf.color;
    ctx.fillRect(shelf.x, shelf.y, shelf.w, 25);
    ctx.fillStyle = "#fff";
    ctx.font = "800 14px 'Barlow Condensed', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(shelf.label, shelf.x + shelf.w / 2, shelf.y + 18);
    ctx.restore();
  }

  function drawDecor(item) {
    ctx.save();
    ctx.translate(item.x, item.y);
    if (item.kind === "plant") {
      ctx.fillStyle = "#7f6351";
      ctx.fillRect(-21, 10, 42, 30);
      ctx.fillStyle = "#5e9d54";
      for (let i = 0; i < 7; i += 1) {
        ctx.beginPath();
        ctx.ellipse(Math.sin(i * 2.4) * 22, -3 - (i % 3) * 12, 12, 25, i, 0, Math.PI * 2);
        ctx.fill();
      }
    } else {
      ctx.fillStyle = "#b88a4d";
      ctx.fillRect(-28, -22, 56, 44);
      ctx.strokeStyle = "#795831";
      ctx.lineWidth = 3;
      ctx.strokeRect(-28, -22, 56, 44);
      ctx.beginPath();
      ctx.moveTo(-28, -22);
      ctx.lineTo(28, 22);
      ctx.moveTo(28, -22);
      ctx.lineTo(-28, 22);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawTrackDetails() {
    spills.forEach((spill) => {
      ctx.save();
      ctx.translate(spill.x, spill.y);
      ctx.fillStyle = "rgba(54, 175, 196, .43)";
      ctx.beginPath();
      for (let i = 0; i < 12; i += 1) {
        const angle = i / 12 * Math.PI * 2;
        const radius = spill.r * (.72 + Math.sin(i * 7) * .18);
        ctx.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
      }
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,.5)";
      ctx.beginPath();
      ctx.ellipse(-9, -8, 9, 4, -.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    });

    ctx.fillStyle = "rgba(38, 38, 48, .18)";
    ctx.font = "900 52px 'Barlow Condensed', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("AISLE 9 AFTER DARK", 900, 1050);
  }

  function drawPickups() {
    pickups.forEach((pickup, index) => {
      if (!pickup.active) return;
      const bob = Math.sin(elapsed * 4 + index) * 5;
      ctx.save();
      ctx.translate(pickup.x, pickup.y + bob);
      ctx.rotate(elapsed * .7 + index);
      ctx.shadowColor = "#d9ff43";
      ctx.shadowBlur = 18;
      ctx.fillStyle = "#25252d";
      roundedRect(-20, -20, 40, 40, 10);
      ctx.fill();
      ctx.strokeStyle = "#d9ff43";
      ctx.lineWidth = 4;
      ctx.stroke();
      ctx.rotate(-elapsed * .7 - index);
      ctx.fillStyle = "#d9ff43";
      ctx.font = "900 25px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("?", 0, 1);
      ctx.restore();
    });
  }

  function drawParticles() {
    particles.forEach((particle) => {
      ctx.globalAlpha = Math.max(0, particle.life / particle.maxLife);
      ctx.fillStyle = particle.color;
      ctx.beginPath();
      ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.globalAlpha = 1;
  }

  function drawRacer(racer) {
    ctx.save();
    ctx.translate(racer.x, racer.y);
    ctx.rotate(racer.angle);

    if (racer.boost > 0) {
      ctx.strokeStyle = racer.color;
      ctx.lineWidth = 4;
      for (let i = 0; i < 3; i += 1) {
        ctx.globalAlpha = .7 - i * .2;
        ctx.beginPath();
        ctx.moveTo(-38 - i * 15, -12);
        ctx.lineTo(-72 - i * 20, -12);
        ctx.moveTo(-38 - i * 15, 12);
        ctx.lineTo(-72 - i * 20, 12);
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }

    ctx.fillStyle = "rgba(0,0,0,.22)";
    ctx.beginPath();
    ctx.ellipse(-2, 8, 42, 27, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#25252c";
    ctx.fillRect(-28, -29, 12, 10);
    ctx.fillRect(-28, 19, 12, 10);
    ctx.fillRect(22, -29, 12, 10);
    ctx.fillRect(22, 19, 12, 10);

    ctx.fillStyle = racer.color;
    roundedRect(-31, -25, 61, 50, 8);
    ctx.fill();
    ctx.strokeStyle = "#f0f0ed";
    ctx.lineWidth = 4;
    ctx.stroke();

    ctx.fillStyle = racer.accent;
    roundedRect(-22, -18, 40, 36, 4);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.48)";
    ctx.lineWidth = 2;
    for (let x = -15; x < 18; x += 10) {
      ctx.beginPath();
      ctx.moveTo(x, -17);
      ctx.lineTo(x, 17);
      ctx.stroke();
    }

    ctx.fillStyle = "#f0efe9";
    ctx.fillRect(26, -31, 5, 62);
    ctx.fillRect(31, -30, 11, 5);
    ctx.fillRect(31, 25, 11, 5);

    ctx.font = "26px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(racer.emoji, -9, 0);
    ctx.restore();

    ctx.save();
    ctx.translate(racer.x, racer.y - 44);
    ctx.fillStyle = "rgba(20,20,27,.72)";
    roundedRect(-25, -8, 50, 16, 7);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "800 9px 'DM Sans', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(racer.name.toUpperCase(), 0, 0);
    ctx.restore();
  }

  function drawMinimap() {
    const width = 104;
    const height = 68;
    const x = innerWidth - width - 17;
    const y = Math.max(156, (window.visualViewport?.height || innerHeight) * .22);
    ctx.save();
    ctx.globalAlpha = .9;
    ctx.fillStyle = "rgba(15,15,22,.68)";
    roundedRect(x, y, width, height, 12);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.12)";
    ctx.stroke();
    racers.forEach((racer) => {
      ctx.fillStyle = racer === player ? "#d9ff43" : racer.color;
      ctx.beginPath();
      ctx.arc(x + 7 + racer.x / WORLD.width * (width - 14), y + 7 + racer.y / WORLD.height * (height - 14), racer === player ? 4 : 3, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.restore();
  }

  function roundedRect(x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + width, y, x + width, y + height, r);
    ctx.arcTo(x + width, y + height, x, y + height, r);
    ctx.arcTo(x, y + height, x, y, r);
    ctx.arcTo(x, y, x + width, y, r);
    ctx.closePath();
  }

  function shadeColor(hex, amount) {
    const number = parseInt(hex.slice(1), 16);
    const red = Math.max(0, Math.min(255, (number >> 16) + amount));
    const green = Math.max(0, Math.min(255, ((number >> 8) & 255) + amount));
    const blue = Math.max(0, Math.min(255, (number & 255) + amount));
    return `rgb(${red}, ${green}, ${blue})`;
  }

  function beep(frequency, duration, type = "sine", endFrequency = frequency) {
    if (muted) return;
    try {
      audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, audioContext.currentTime);
      oscillator.frequency.exponentialRampToValueAtTime(Math.max(1, endFrequency), audioContext.currentTime + duration);
      gain.gain.setValueAtTime(.045, audioContext.currentTime);
      gain.gain.exponentialRampToValueAtTime(.001, audioContext.currentTime + duration);
      oscillator.connect(gain).connect(audioContext.destination);
      oscillator.start();
      oscillator.stop(audioContext.currentTime + duration);
    } catch (_) {
      muted = true;
    }
  }

  function frame(now) {
    const dt = Math.min(.033, Math.max(0, (now - lastTime) / 1000));
    lastTime = now;
    if (mode !== "paused") update(dt);
    draw();
    animationId = requestAnimationFrame(frame);
  }

  function setKey(event, active) {
    const map = {
      ArrowUp: "up",
      KeyW: "up",
      ArrowDown: "down",
      KeyS: "down",
      ArrowLeft: "left",
      KeyA: "left",
      ArrowRight: "right",
      KeyD: "right",
      Space: "drift",
    };
    const control = map[event.code];
    if (control) {
      keys[control] = active;
      event.preventDefault();
    }
    if (active && (event.code === "ShiftLeft" || event.code === "ShiftRight" || event.code === "KeyE")) {
      useItem(player);
      event.preventDefault();
    }
    if (active && event.code === "Escape") {
      mode === "paused" ? resumeRace() : pauseRace();
    }
  }

  document.addEventListener("keydown", (event) => setKey(event, true));
  document.addEventListener("keyup", (event) => setKey(event, false));
  window.addEventListener("resize", resize);
  window.addEventListener("blur", () => {
    if (mode === "racing") pauseRace();
  });

  document.querySelectorAll("[data-control]").forEach((button) => {
    const control = button.dataset.control;
    const activate = (event) => {
      event.preventDefault();
      button.classList.add("pressed");
      if (control === "item") {
        if (!itemPressed) useItem(player);
        itemPressed = true;
      } else {
        keys[control] = true;
      }
    };
    const deactivate = (event) => {
      event.preventDefault();
      button.classList.remove("pressed");
      if (control === "item") itemPressed = false;
      else keys[control] = false;
    };
    button.addEventListener("pointerdown", activate);
    button.addEventListener("pointerup", deactivate);
    button.addEventListener("pointercancel", deactivate);
    button.addEventListener("pointerleave", deactivate);
  });

  document.querySelector("#race-button").addEventListener("click", startRace);
  document.querySelector(".modal-play").addEventListener("click", startRace);
  document.querySelector("#how-button").addEventListener("click", () => showScreen("#how-screen"));
  document.querySelector(".modal-close").addEventListener("click", () => showScreen("#home-screen"));
  document.querySelector("#pause-button").addEventListener("click", pauseRace);
  document.querySelector("#resume-button").addEventListener("click", resumeRace);
  document.querySelector("#again-button").addEventListener("click", startRace);
  document.querySelectorAll(".quit-button").forEach((button) => button.addEventListener("click", menu));
  document.querySelectorAll(".sound-toggle").forEach((button) => {
    button.addEventListener("click", () => {
      muted = !muted;
      document.querySelectorAll(".sound-toggle").forEach((toggle) => toggle.classList.toggle("muted", muted));
      if (!muted) beep(540, .08);
    });
  });

  resize();
  drawMenuBackdrop();
  cancelAnimationFrame(animationId);
  animationId = requestAnimationFrame(frame);

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("service-worker.js").catch(() => {}));
  }
})();
