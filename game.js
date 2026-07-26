(() => {
  "use strict";

  const canvas = document.querySelector("#game");
  const ctx = canvas.getContext("2d");
  const minimap = document.querySelector("#minimap");
  const mapCtx = minimap.getContext("2d");
  const shell = document.querySelector("#game-shell");
  const ui = {
    menu: document.querySelector("#menu"),
    hudPosition: document.querySelector("#position"),
    lap: document.querySelector("#lap"),
    timer: document.querySelector("#timer"),
    progress: document.querySelector("#race-progress-fill"),
    boost: document.querySelector("#boost-fill"),
    countdown: document.querySelector("#countdown"),
    toast: document.querySelector("#toast"),
    pause: document.querySelector("#pause-screen"),
    results: document.querySelector("#results"),
    resultPosition: document.querySelector("#result-position"),
    resultSuffix: document.querySelector("#result-suffix"),
    resultTitle: document.querySelector("#result-title"),
    resultKicker: document.querySelector("#result-kicker"),
    resultTime: document.querySelector("#result-time"),
    bestLap: document.querySelector("#best-lap"),
    pickupCount: document.querySelector("#pickup-count")
  };

  const TAU = Math.PI * 2;
  const WORLD = { width: 2040, height: 1260 };
  const TRACK_WIDTH = 270;
  const TOTAL_LAPS = 3;
  const COLORS = ["#65b7ff", "#ff6b35", "#75c985", "#c894ff"];
  const CARTS = [
    { name: "Blue Comet", color: COLORS[0], maxSpeed: 410, accel: 275, grip: 2.85 },
    { name: "Hot Mess", color: COLORS[1], maxSpeed: 445, accel: 250, grip: 2.55 },
    { name: "Moss Boss", color: COLORS[2], maxSpeed: 390, accel: 290, grip: 3.25 }
  ];

  const controlPoints = [
    { x: 460, y: 790 },
    { x: 355, y: 455 },
    { x: 575, y: 230 },
    { x: 1010, y: 185 },
    { x: 1440, y: 245 },
    { x: 1690, y: 505 },
    { x: 1630, y: 825 },
    { x: 1345, y: 1030 },
    { x: 880, y: 1045 },
    { x: 555, y: 945 }
  ];

  function catmullRom(p0, p1, p2, p3, t) {
    const t2 = t * t;
    const t3 = t2 * t;
    return {
      x: 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
      y: 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
    };
  }

  function createTrack(points, resolution = 32) {
    const sampled = [];
    for (let i = 0; i < points.length; i++) {
      const p0 = points[(i - 1 + points.length) % points.length];
      const p1 = points[i];
      const p2 = points[(i + 1) % points.length];
      const p3 = points[(i + 2) % points.length];
      for (let step = 0; step < resolution; step++) {
        sampled.push(catmullRom(p0, p1, p2, p3, step / resolution));
      }
    }
    sampled.forEach((point, i) => {
      const next = sampled[(i + 1) % sampled.length];
      const angle = Math.atan2(next.y - point.y, next.x - point.x);
      point.angle = angle;
      point.nx = -Math.sin(angle);
      point.ny = Math.cos(angle);
    });
    return sampled;
  }

  const track = createTrack(controlPoints);
  const trackLength = track.length;
  let dpr = 1;
  let width = 0;
  let height = 0;
  let state = "menu";
  let selectedCart = 0;
  let player;
  let racers = [];
  let particles = [];
  let pickups = [];
  let obstacles = [];
  let raceStart = 0;
  let raceTime = 0;
  let lastTime = performance.now();
  let toastTimer;
  let audioContext;
  let screenShake = 0;

  const keys = { up: false, down: false, left: false, right: false, boost: false };

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function pointAt(progress, lane = 0) {
    const wrapped = ((progress % trackLength) + trackLength) % trackLength;
    const index = Math.floor(wrapped);
    const fraction = wrapped - index;
    const a = track[index];
    const b = track[(index + 1) % trackLength];
    const x = a.x + (b.x - a.x) * fraction;
    const y = a.y + (b.y - a.y) * fraction;
    return {
      x: x + a.nx * lane,
      y: y + a.ny * lane,
      angle: Math.atan2(b.y - a.y, b.x - a.x)
    };
  }

  function nearestTrackPoint(x, y) {
    let best = { index: 0, distance: Infinity };
    for (let i = 0; i < trackLength; i++) {
      const dx = x - track[i].x;
      const dy = y - track[i].y;
      const distance = dx * dx + dy * dy;
      if (distance < best.distance) best = { index: i, distance };
    }
    best.distance = Math.sqrt(best.distance);
    return best;
  }

  function makeRacer(options) {
    const start = pointAt(options.progress, options.lane);
    return {
      name: options.name,
      color: options.color,
      x: start.x,
      y: start.y,
      angle: start.angle,
      speed: 0,
      progress: options.progress,
      lastIndex: Math.floor(options.progress),
      lap: 0,
      lane: options.lane,
      maxSpeed: options.maxSpeed,
      skill: options.skill || 1,
      isPlayer: !!options.isPlayer,
      finished: false,
      finishTime: 0,
      boost: options.isPlayer ? 65 : 100,
      boosting: false,
      hitCooldown: 0,
      pickups: 0,
      lapStarted: 0,
      lapTimes: [],
      rank: 1,
      cargo: options.cargo || "blanket"
    };
  }

  function resetRace() {
    const cart = CARTS[selectedCart];
    racers = [
      makeRacer({ name: cart.name, color: cart.color, progress: 2, lane: -42, maxSpeed: cart.maxSpeed, isPlayer: true, cargo: "roll" }),
      makeRacer({ name: "Patch", color: COLORS[3], progress: -5, lane: 38, maxSpeed: 388, skill: .99, cargo: "plant" }),
      makeRacer({ name: "Tin Can", color: "#f0c44d", progress: -12, lane: -38, maxSpeed: 398, skill: 1.01, cargo: "boxes" }),
      makeRacer({ name: "Rook", color: "#f06f98", progress: -19, lane: 42, maxSpeed: 382, skill: .985, cargo: "bag" })
    ];
    player = racers[0];
    player.grip = cart.grip;
    pickups = [38, 82, 126, 171, 218, 266, 305].map((progress, i) => {
      const p = pointAt(progress, i % 2 ? 52 : -52);
      return { x: p.x, y: p.y, active: true, respawn: 0, spin: i * .7 };
    });
    obstacles = [58, 154, 241].map((progress, i) => {
      const p = pointAt(progress, i === 1 ? -64 : 62);
      return { x: p.x, y: p.y, angle: p.angle, kind: i === 1 ? "box" : "cone" };
    });
    particles = [];
    raceTime = 0;
    screenShake = 0;
    raceStart = performance.now();
    updateHud();
  }

  function startCountdown() {
    resetRace();
    state = "countdown";
    ui.menu.classList.remove("active");
    ui.results.classList.remove("active");
    shell.classList.add("racing");
    const beats = ["3", "2", "1", "GO!"];
    let index = 0;
    const count = () => {
      ui.countdown.textContent = beats[index];
      ui.countdown.classList.remove("pop");
      void ui.countdown.offsetWidth;
      ui.countdown.classList.add("pop");
      tone(index === 3 ? 620 : 280 + index * 70, index === 3 ? .28 : .12, index === 3 ? "square" : "sine");
      if (index === 3) {
        state = "racing";
        raceStart = performance.now();
        racers.forEach(racer => { racer.lapStarted = raceStart; });
        return;
      }
      index += 1;
      window.setTimeout(count, 760);
    };
    count();
  }

  function updatePlayer(dt) {
    if (player.finished) return;
    const cart = CARTS[selectedCart];
    const accelerating = keys.up;
    const braking = keys.down;
    const canBoost = keys.boost && player.boost > 0 && player.speed > 90;
    player.boosting = canBoost;

    if (accelerating) player.speed += cart.accel * dt;
    else player.speed -= 92 * dt;
    if (braking) player.speed -= 330 * dt;

    const nearest = nearestTrackPoint(player.x, player.y);
    const offTrack = nearest.distance > TRACK_WIDTH * .48;
    const max = cart.maxSpeed * (offTrack ? .54 : 1) * (canBoost ? 1.28 : 1);
    player.speed = Math.max(braking ? -95 : 0, Math.min(player.speed, max));
    if (offTrack) player.speed *= Math.pow(.965, dt * 60);

    if (canBoost) {
      player.speed += 225 * dt;
      player.boost = Math.max(0, player.boost - 27 * dt);
      if (Math.random() < dt * 35) spawnTrail(player, "#ff9a45", 1.7);
    } else {
      player.boost = Math.min(100, player.boost + 4.5 * dt);
    }

    const steer = (keys.left ? -1 : 0) + (keys.right ? 1 : 0);
    const speedRatio = Math.min(Math.abs(player.speed) / cart.maxSpeed, 1);
    if (Math.abs(player.speed) > 8) {
      const direction = player.speed < 0 ? -1 : 1;
      player.angle += steer * cart.grip * (.24 + speedRatio * .76) * dt * direction;
      if (steer && speedRatio > .56 && Math.random() < dt * 24) spawnTrail(player, "#dad9c8", .8);
    }

    player.x += Math.cos(player.angle) * player.speed * dt;
    player.y += Math.sin(player.angle) * player.speed * dt;

    const current = nearestTrackPoint(player.x, player.y);
    const index = current.index;
    if (player.lastIndex > trackLength * .82 && index < trackLength * .18 && player.speed > 0) {
      player.lap += 1;
      const now = performance.now();
      player.lapTimes.push(now - player.lapStarted);
      player.lapStarted = now;
      if (player.lap >= TOTAL_LAPS) finishRace();
      else showToast(`Lap ${player.lap + 1} // keep pushing`);
    } else if (player.lastIndex < trackLength * .18 && index > trackLength * .82 && player.speed < 0) {
      player.lap = Math.max(0, player.lap - 1);
    }
    player.lastIndex = index;
    player.progress = player.lap * trackLength + index;

    if (player.hitCooldown > 0) player.hitCooldown -= dt;
    checkPickups();
    checkObstacles();
  }

  function updateAI(dt) {
    racers.slice(1).forEach((racer, aiIndex) => {
      if (racer.finished) return;
      const targetSpeed = racer.maxSpeed * racer.skill * (1 + Math.sin(raceTime * .0015 + aiIndex * 2) * .035);
      racer.speed += (targetSpeed - racer.speed) * dt * .9;
      racer.progress += racer.speed * dt / 12.2;
      const point = pointAt(racer.progress, racer.lane + Math.sin(racer.progress * .035 + aiIndex) * 8);
      racer.x = point.x;
      racer.y = point.y;
      racer.angle = point.angle;
      racer.lap = Math.max(0, Math.floor(racer.progress / trackLength));
      if (racer.lap >= TOTAL_LAPS) {
        racer.finished = true;
        racer.finishTime = raceTime;
      }
    });
  }

  function checkPickups() {
    pickups.forEach(pickup => {
      if (!pickup.active) return;
      const dx = pickup.x - player.x;
      const dy = pickup.y - player.y;
      if (dx * dx + dy * dy < 46 * 46) {
        pickup.active = false;
        pickup.respawn = 7;
        player.boost = Math.min(100, player.boost + 32);
        player.pickups += 1;
        showToast("Good find // boost +32");
        tone(720, .1, "triangle");
        window.setTimeout(() => tone(960, .08, "triangle"), 70);
        for (let i = 0; i < 12; i++) spawnParticle(pickup.x, pickup.y, "#d7fb47", 2.4);
      }
    });
  }

  function checkObstacles() {
    if (player.hitCooldown > 0) return;
    obstacles.forEach(obstacle => {
      const dx = obstacle.x - player.x;
      const dy = obstacle.y - player.y;
      if (dx * dx + dy * dy < 40 * 40) {
        player.speed *= .52;
        player.hitCooldown = .8;
        screenShake = 10;
        showToast(obstacle.kind === "box" ? "Cardboard ambush!" : "Cone says no.");
        tone(105, .14, "sawtooth");
        for (let i = 0; i < 10; i++) spawnParticle(obstacle.x, obstacle.y, "#ff6b35", 1.5);
      }
    });
  }

  function updatePickups(dt) {
    pickups.forEach(pickup => {
      pickup.spin += dt * 2.7;
      if (!pickup.active) {
        pickup.respawn -= dt;
        if (pickup.respawn <= 0) pickup.active = true;
      }
    });
  }

  function updateParticles(dt) {
    particles.forEach(particle => {
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.life -= dt;
      particle.size *= Math.pow(.975, dt * 60);
    });
    particles = particles.filter(particle => particle.life > 0);
    screenShake *= Math.pow(.82, dt * 60);
  }

  function spawnTrail(racer, color, force) {
    const rearX = racer.x - Math.cos(racer.angle) * 28;
    const rearY = racer.y - Math.sin(racer.angle) * 28;
    spawnParticle(rearX, rearY, color, force);
  }

  function spawnParticle(x, y, color, force) {
    const angle = Math.random() * TAU;
    const speed = (25 + Math.random() * 65) * force;
    particles.push({
      x, y, color,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      size: 3 + Math.random() * 5,
      life: .35 + Math.random() * .55
    });
  }

  function finishRace() {
    if (player.finished) return;
    player.finished = true;
    player.finishTime = raceTime;
    updateRanks();
    const rank = player.rank;
    state = "finished";
    shell.classList.remove("racing");
    ui.resultPosition.textContent = rank;
    ui.resultSuffix.textContent = ordinalSuffix(rank);
    ui.resultTime.textContent = formatTime(raceTime);
    ui.bestLap.textContent = formatTime(Math.min(...player.lapTimes));
    ui.pickupCount.textContent = player.pickups;
    ui.resultTitle.textContent = rank === 1 ? "Aisle legend." : rank === 2 ? "So close." : "Still rolling.";
    ui.resultKicker.textContent = rank === 1 ? "Checkout cleared" : "Made it through";
    window.setTimeout(() => ui.results.classList.add("active"), 600);
    tone(rank === 1 ? 660 : 440, .35, "square");
  }

  function updateRanks() {
    const sorted = [...racers].sort((a, b) => {
      const aProgress = a.finished ? TOTAL_LAPS * trackLength + (999999 - a.finishTime) / 999999 : a.progress;
      const bProgress = b.finished ? TOTAL_LAPS * trackLength + (999999 - b.finishTime) / 999999 : b.progress;
      return bProgress - aProgress;
    });
    sorted.forEach((racer, index) => { racer.rank = index + 1; });
  }

  function updateHud() {
    if (!player) return;
    updateRanks();
    ui.hudPosition.innerHTML = `${player.rank}<sup>${ordinalSuffix(player.rank)}</sup>`;
    ui.lap.textContent = `${Math.min(player.lap + 1, TOTAL_LAPS)} / ${TOTAL_LAPS}`;
    ui.timer.textContent = formatTime(raceTime);
    ui.progress.style.width = `${Math.min(100, (player.progress / (trackLength * TOTAL_LAPS)) * 100)}%`;
    ui.boost.style.width = `${player.boost}%`;
  }

  function formatTime(milliseconds) {
    if (!Number.isFinite(milliseconds)) return "--:--.---";
    const minutes = Math.floor(milliseconds / 60000);
    const seconds = Math.floor((milliseconds % 60000) / 1000);
    const ms = Math.floor(milliseconds % 1000);
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${String(ms).padStart(3, "0")}`;
  }

  function ordinalSuffix(number) {
    if (number === 1) return "st";
    if (number === 2) return "nd";
    if (number === 3) return "rd";
    return "th";
  }

  function showToast(message) {
    ui.toast.textContent = message;
    ui.toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => ui.toast.classList.remove("show"), 1400);
  }

  function tone(frequency, duration, type) {
    try {
      audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.type = type;
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(.045, audioContext.currentTime);
      gain.gain.exponentialRampToValueAtTime(.001, audioContext.currentTime + duration);
      oscillator.connect(gain);
      gain.connect(audioContext.destination);
      oscillator.start();
      oscillator.stop(audioContext.currentTime + duration);
    } catch (_) {
      // Sound is optional and may be blocked until the first gesture.
    }
  }

  function drawClosedPath(context) {
    context.beginPath();
    context.moveTo(track[0].x, track[0].y);
    for (let i = 1; i < trackLength; i++) context.lineTo(track[i].x, track[i].y);
    context.closePath();
  }

  function drawWorld() {
    ctx.fillStyle = "#25271d";
    ctx.fillRect(-900, -900, WORLD.width + 1800, WORLD.height + 1800);

    ctx.strokeStyle = "rgba(238,235,208,.045)";
    ctx.lineWidth = 2;
    for (let x = 0; x <= WORLD.width; x += 80) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, WORLD.height); ctx.stroke();
    }
    for (let y = 0; y <= WORLD.height; y += 80) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(WORLD.width, y); ctx.stroke();
    }

    drawShelves();

    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    drawClosedPath(ctx);
    ctx.strokeStyle = "#10110c";
    ctx.lineWidth = TRACK_WIDTH + 32;
    ctx.stroke();
    drawClosedPath(ctx);
    ctx.strokeStyle = "#505147";
    ctx.lineWidth = TRACK_WIDTH + 20;
    ctx.stroke();
    drawClosedPath(ctx);
    ctx.strokeStyle = "#b8b6aa";
    ctx.lineWidth = TRACK_WIDTH;
    ctx.stroke();
    drawClosedPath(ctx);
    ctx.strokeStyle = "#a5a399";
    ctx.lineWidth = TRACK_WIDTH - 12;
    ctx.stroke();

    ctx.setLineDash([18, 28]);
    drawClosedPath(ctx);
    ctx.strokeStyle = "rgba(246,241,214,.55)";
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.setLineDash([]);

    drawStartLine();
    drawTrackSigns();
    obstacles.forEach(drawObstacle);
    pickups.forEach(drawPickup);
    particles.forEach(drawParticle);
    racers.slice(1).forEach(drawCart);
    if (player) drawCart(player);
  }

  function drawShelves() {
    const shelves = [
      [700, 390, 390, 80, "CANNED GOODS", "#c6533f"],
      [700, 545, 390, 80, "HOME & GARDEN", "#4d8a66"],
      [700, 700, 390, 80, "ODDS & ENDS", "#d3a943"],
      [1145, 430, 300, 76, "SNACKS", "#d55b36"],
      [1145, 590, 300, 76, "SOFT GOODS", "#537caf"],
      [1145, 750, 300, 76, "LAST CHANCE", "#9970b5"],
      [70, 100, 360, 76, "OVERNIGHT", "#50728e"],
      [1570, 1040, 360, 76, "CLOSED", "#97513e"]
    ];
    shelves.forEach(([x, y, w, h, label, color]) => {
      ctx.save();
      ctx.translate(x, y);
      ctx.fillStyle = "rgba(0,0,0,.24)";
      roundRect(ctx, 10, 12, w, h, 8);
      ctx.fill();
      ctx.fillStyle = "#3a3b34";
      roundRect(ctx, 0, 0, w, h, 6);
      ctx.fill();
      ctx.fillStyle = color;
      ctx.fillRect(7, 7, w - 14, 15);
      ctx.fillStyle = "#16170f";
      ctx.font = "700 9px 'DM Mono', monospace";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(label, w / 2, 14.5);
      for (let bx = 12; bx < w - 12; bx += 31) {
        ctx.fillStyle = ["#d59b49", "#778d60", "#b96755"][Math.floor(bx / 31) % 3];
        ctx.fillRect(bx, 31, 20, h - 41);
        ctx.fillStyle = "rgba(255,255,255,.12)";
        ctx.fillRect(bx + 3, 35, 4, h - 49);
      }
      ctx.restore();
    });
  }

  function drawStartLine() {
    const p = track[0];
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(p.angle);
    for (let row = 0; row < 2; row++) {
      for (let col = -6; col < 6; col++) {
        ctx.fillStyle = (col + row) % 2 ? "#eee9d3" : "#1b1c16";
        ctx.fillRect(-10 + row * 10, col * 22, 10, 22);
      }
    }
    ctx.restore();
  }

  function drawTrackSigns() {
    [
      [460, 570, "START / FINISH"],
      [995, 54, "AISLE 09"],
      [1812, 570, "MIND THE MOP"],
      [1120, 1168, "NO RECEIPT NEEDED"]
    ].forEach(([x, y, text], i) => {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(i % 2 ? .03 : -.03);
      ctx.fillStyle = "#16170f";
      ctx.fillRect(-68, -15, 136, 30);
      ctx.strokeStyle = "#d7fb47";
      ctx.lineWidth = 2;
      ctx.strokeRect(-68, -15, 136, 30);
      ctx.fillStyle = "#d7fb47";
      ctx.font = "500 9px 'DM Mono', monospace";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(text, 0, 1);
      ctx.restore();
    });
  }

  function drawCart(racer) {
    ctx.save();
    ctx.translate(racer.x, racer.y);
    ctx.rotate(racer.angle);
    if (racer.boosting) {
      ctx.fillStyle = "rgba(255,107,53,.35)";
      ctx.beginPath();
      ctx.moveTo(-31, -12); ctx.lineTo(-58 - Math.random() * 14, 0); ctx.lineTo(-31, 12); ctx.fill();
    }
    ctx.fillStyle = "rgba(0,0,0,.22)";
    roundRect(ctx, -27, -19, 59, 42, 9); ctx.fill();
    ctx.fillStyle = "#171812";
    [-20, 17].forEach(x => {
      ctx.fillRect(x, -25, 10, 7);
      ctx.fillRect(x, 19, 10, 7);
    });
    ctx.fillStyle = racer.color;
    roundRect(ctx, -31, -19, 54, 38, 7); ctx.fill();
    ctx.strokeStyle = "rgba(16,17,12,.7)";
    ctx.lineWidth = 3;
    for (let x = -22; x < 18; x += 10) {
      ctx.beginPath(); ctx.moveTo(x, -16); ctx.lineTo(x + 3, 16); ctx.stroke();
    }
    ctx.beginPath(); ctx.moveTo(-26, -9); ctx.lineTo(20, -9); ctx.moveTo(-27, 4); ctx.lineTo(21, 4); ctx.stroke();
    ctx.strokeStyle = "#dedbc9";
    ctx.lineWidth = 4;
    ctx.beginPath(); ctx.moveTo(20, -20); ctx.lineTo(31, -20); ctx.lineTo(34, 20); ctx.lineTo(20, 20); ctx.stroke();

    ctx.fillStyle = cargoColor(racer.cargo);
    if (racer.cargo === "plant") {
      ctx.fillStyle = "#61482f";
      ctx.fillRect(-10, -8, 14, 16);
      ctx.fillStyle = "#76a75c";
      ctx.beginPath(); ctx.arc(-5, -10, 9, 0, TAU); ctx.fill();
    } else {
      roundRect(ctx, -17, -11, 25, 22, 6); ctx.fill();
      ctx.strokeStyle = "rgba(255,255,255,.28)";
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(-14, -5); ctx.lineTo(5, 7); ctx.stroke();
    }
    if (racer.isPlayer) {
      ctx.strokeStyle = "#fff";
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(5, -28); ctx.lineTo(5, -38); ctx.stroke();
      ctx.fillStyle = "#d7fb47";
      ctx.beginPath(); ctx.moveTo(5, -38); ctx.lineTo(20, -33); ctx.lineTo(5, -28); ctx.fill();
    }
    ctx.restore();
  }

  function cargoColor(cargo) {
    return { roll: "#d88455", boxes: "#b88a54", bag: "#657d9a", blanket: "#866a9e" }[cargo] || "#b88a54";
  }

  function drawPickup(pickup) {
    if (!pickup.active) return;
    ctx.save();
    ctx.translate(pickup.x, pickup.y);
    ctx.rotate(pickup.spin);
    const pulse = 1 + Math.sin(pickup.spin * 2) * .08;
    ctx.scale(pulse, pulse);
    ctx.fillStyle = "rgba(215,251,71,.15)";
    ctx.beginPath(); ctx.arc(0, 0, 25, 0, TAU); ctx.fill();
    ctx.strokeStyle = "#d7fb47";
    ctx.lineWidth = 3;
    ctx.beginPath();
    for (let i = 0; i < 8; i++) {
      const angle = i * TAU / 8;
      const radius = i % 2 ? 9 : 17;
      const x = Math.cos(angle) * radius;
      const y = Math.sin(angle) * radius;
      i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
    }
    ctx.closePath(); ctx.stroke();
    ctx.restore();
  }

  function drawObstacle(obstacle) {
    ctx.save();
    ctx.translate(obstacle.x, obstacle.y);
    ctx.rotate(obstacle.angle);
    if (obstacle.kind === "cone") {
      ctx.fillStyle = "rgba(0,0,0,.2)";
      ctx.beginPath(); ctx.ellipse(4, 5, 20, 15, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = "#ff6b35";
      ctx.beginPath(); ctx.moveTo(-15, 12); ctx.lineTo(0, -22); ctx.lineTo(15, 12); ctx.closePath(); ctx.fill();
      ctx.fillStyle = "#f4efd9";
      ctx.fillRect(-9, -1, 18, 7);
    } else {
      ctx.fillStyle = "#9b7547";
      ctx.fillRect(-19, -19, 38, 38);
      ctx.strokeStyle = "#604526";
      ctx.lineWidth = 2;
      ctx.strokeRect(-19, -19, 38, 38);
      ctx.beginPath(); ctx.moveTo(-19, -19); ctx.lineTo(19, 19); ctx.moveTo(19, -19); ctx.lineTo(-19, 19); ctx.stroke();
    }
    ctx.restore();
  }

  function drawParticle(particle) {
    ctx.globalAlpha = Math.min(1, particle.life * 2);
    ctx.fillStyle = particle.color;
    ctx.beginPath();
    ctx.arc(particle.x, particle.y, particle.size, 0, TAU);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function roundRect(context, x, y, w, h, radius) {
    const r = Math.min(radius, w / 2, h / 2);
    context.beginPath();
    context.moveTo(x + r, y);
    context.arcTo(x + w, y, x + w, y + h, r);
    context.arcTo(x + w, y + h, x, y + h, r);
    context.arcTo(x, y + h, x, y, r);
    context.arcTo(x, y, x + w, y, r);
    context.closePath();
  }

  function render() {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);
    const menuMode = state === "menu";
    const follow = player || { x: 1010, y: 620, angle: -Math.PI / 2 };
    const zoom = menuMode ? Math.min(width / WORLD.width, height / WORLD.height) * 1.28 : Math.max(.76, Math.min(1.12, width / 1050));
    const shakeX = screenShake ? (Math.random() - .5) * screenShake : 0;
    const shakeY = screenShake ? (Math.random() - .5) * screenShake : 0;
    ctx.save();
    ctx.translate(width / 2 + shakeX, height / 2 + shakeY);
    ctx.scale(zoom, zoom);
    if (!menuMode) ctx.rotate(-follow.angle - Math.PI / 2);
    ctx.translate(-follow.x, -follow.y);
    drawWorld();
    ctx.restore();
    if (!menuMode) drawSpeedLines();
    drawMinimap();
  }

  function drawSpeedLines() {
    if (!player || player.speed < player.maxSpeed * .72) return;
    const intensity = Math.min(1, (player.speed / player.maxSpeed - .72) / .35);
    ctx.save();
    ctx.strokeStyle = `rgba(244,239,217,${.08 * intensity})`;
    ctx.lineWidth = 1;
    for (let i = 0; i < 14 * intensity; i++) {
      const x = Math.random() * width;
      const y = Math.random() * height;
      const length = 20 + Math.random() * 55 * intensity;
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + length); ctx.stroke();
    }
    ctx.restore();
  }

  function drawMinimap() {
    const mw = minimap.width;
    const mh = minimap.height;
    mapCtx.clearRect(0, 0, mw, mh);
    mapCtx.save();
    mapCtx.scale(mw / WORLD.width, mh / WORLD.height);
    drawClosedPath(mapCtx);
    mapCtx.strokeStyle = "rgba(244,239,217,.22)";
    mapCtx.lineWidth = 55;
    mapCtx.stroke();
    racers.forEach(racer => {
      mapCtx.fillStyle = racer.isPlayer ? "#d7fb47" : racer.color;
      mapCtx.beginPath();
      mapCtx.arc(racer.x, racer.y, racer.isPlayer ? 25 : 18, 0, TAU);
      mapCtx.fill();
    });
    mapCtx.restore();
  }

  function gameLoop(now) {
    const dt = Math.min(.033, (now - lastTime) / 1000 || 0);
    lastTime = now;
    if (state === "racing") {
      raceTime = now - raceStart;
      updatePlayer(dt);
      updateAI(dt);
      updatePickups(dt);
      updateParticles(dt);
      updateHud();
    } else if (state === "finished") {
      updateAI(dt);
      updateParticles(dt);
    } else if (state === "menu") {
      updateAttractMode(dt);
    }
    render();
    requestAnimationFrame(gameLoop);
  }

  function updateAttractMode(dt) {
    if (!racers.length) {
      racers = [
        makeRacer({ name: "Blue Comet", color: COLORS[0], progress: 12, lane: -38, maxSpeed: 390 }),
        makeRacer({ name: "Hot Mess", color: COLORS[1], progress: 3, lane: 38, maxSpeed: 400 }),
        makeRacer({ name: "Moss Boss", color: COLORS[2], progress: -8, lane: -15, maxSpeed: 380 })
      ];
      racers.forEach(racer => { racer.speed = racer.maxSpeed * .55; });
      obstacles = [];
      pickups = [];
    }
    racers.forEach(racer => {
      racer.progress += racer.speed * dt / 12.2;
      const point = pointAt(racer.progress, racer.lane);
      racer.x = point.x;
      racer.y = point.y;
      racer.angle = point.angle;
    });
  }

  function pauseGame() {
    if (state !== "racing") return;
    state = "paused";
    ui.pause.classList.add("active");
  }

  function resumeGame() {
    if (state !== "paused") return;
    state = "racing";
    raceStart = performance.now() - raceTime;
    ui.pause.classList.remove("active");
  }

  function returnToMenu() {
    state = "menu";
    player = null;
    racers = [];
    particles = [];
    pickups = [];
    obstacles = [];
    shell.classList.remove("racing");
    ui.pause.classList.remove("active");
    ui.results.classList.remove("active");
    ui.menu.classList.add("active");
  }

  const keyMap = {
    ArrowUp: "up", KeyW: "up",
    ArrowDown: "down", KeyS: "down",
    ArrowLeft: "left", KeyA: "left",
    ArrowRight: "right", KeyD: "right",
    Space: "boost"
  };

  window.addEventListener("keydown", event => {
    if (keyMap[event.code]) {
      keys[keyMap[event.code]] = true;
      event.preventDefault();
    }
    if (event.code === "Escape") state === "paused" ? resumeGame() : pauseGame();
  });
  window.addEventListener("keyup", event => {
    if (keyMap[event.code]) {
      keys[keyMap[event.code]] = false;
      event.preventDefault();
    }
  });
  window.addEventListener("blur", () => {
    Object.keys(keys).forEach(key => { keys[key] = false; });
    pauseGame();
  });
  window.addEventListener("resize", resize);

  document.querySelectorAll(".cart-option").forEach(button => {
    button.addEventListener("click", () => {
      selectedCart = Number(button.dataset.cart);
      document.querySelectorAll(".cart-option").forEach(option => {
        const selected = option === button;
        option.classList.toggle("selected", selected);
        option.setAttribute("aria-pressed", selected);
      });
      tone(330 + selectedCart * 90, .07, "triangle");
    });
  });

  document.querySelectorAll("[data-control]").forEach(button => {
    const control = button.dataset.control;
    const press = event => {
      event.preventDefault();
      keys[control] = true;
      button.classList.add("pressed");
      button.setPointerCapture?.(event.pointerId);
    };
    const release = event => {
      event.preventDefault();
      keys[control] = false;
      button.classList.remove("pressed");
    };
    button.addEventListener("pointerdown", press);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("pointerleave", release);
  });

  document.querySelector("#start-button").addEventListener("click", startCountdown);
  document.querySelector("#again-button").addEventListener("click", startCountdown);
  document.querySelector("#garage-button").addEventListener("click", returnToMenu);
  document.querySelector("#pause-button").addEventListener("click", pauseGame);
  document.querySelector("#resume-button").addEventListener("click", resumeGame);
  document.querySelector("#quit-button").addEventListener("click", returnToMenu);

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) pauseGame();
  });

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("service-worker.js").catch(() => {}));
  }

  resize();
  requestAnimationFrame(gameLoop);
})();
