(function () {
  "use strict";

  const Core = window.RaceCore;
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const shell = document.querySelector(".game-shell");

  const ui = {
    startScreen: document.getElementById("startScreen"),
    pauseScreen: document.getElementById("pauseScreen"),
    finishScreen: document.getElementById("finishScreen"),
    startButton: document.getElementById("startButton"),
    pauseButton: document.getElementById("pauseButton"),
    resumeButton: document.getElementById("resumeButton"),
    restartButton: document.getElementById("restartButton"),
    raceAgainButton: document.getElementById("raceAgainButton"),
    leftButton: document.getElementById("leftButton"),
    rightButton: document.getElementById("rightButton"),
    boostButton: document.getElementById("boostButton"),
    position: document.getElementById("position"),
    positionSuffix: document.getElementById("positionSuffix"),
    lap: document.getElementById("lap"),
    timer: document.getElementById("timer"),
    collected: document.getElementById("collected"),
    boostCount: document.getElementById("boostCount"),
    countdown: document.getElementById("countdown"),
    toast: document.getElementById("toast"),
    finalPlace: document.getElementById("finalPlace"),
    finalTime: document.getElementById("finalTime"),
    finalGoods: document.getElementById("finalGoods"),
    finishTitle: document.getElementById("finishTitle"),
    finishCopy: document.getElementById("finishCopy"),
  };

  const TOTAL_LAPS = 2;
  const TRACK_LENGTH = 2200;
  const TOTAL_DISTANCE = TRACK_LENGTH * TOTAL_LAPS;
  const VIEW_DISTANCE = 760;
  const PANTRY_GOAL = 8;
  const COLORS = ["#f64471", "#4ee0b7", "#ffd938", "#6c54d9"];

  let width = 430;
  let height = 932;
  let lastFrame = performance.now();
  let touchStartX = null;
  let toastTimer;

  const input = { left: false, right: false };
  const state = {
    mode: "start",
    progress: 0,
    lane: 0,
    velocity: 0,
    targetSpeed: 0,
    boostTime: 0,
    boosts: 0,
    collected: 0,
    raceStartedAt: 0,
    elapsed: 0,
    collisionCooldown: 0,
    shake: 0,
    flash: 0,
    place: 1,
    objects: [],
    opponents: [],
    particles: [],
  };

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = shell.clientWidth;
    height = shell.clientHeight;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function buildTrack() {
    const lanes = [-0.72, 0, 0.72];
    const pantry = ["🥫", "🍞", "🥕", "🥣"];
    state.objects = [];
    for (let progress = 250, index = 0; progress < TOTAL_DISTANCE - 100; progress += 115, index += 1) {
      const isPantry = index % 3 !== 1;
      const laneIndex = (index * 2 + Math.floor(index / 3)) % lanes.length;
      state.objects.push({
        progress,
        lane: lanes[laneIndex],
        type: isPantry ? "pantry" : index % 2 ? "spill" : "box",
        icon: pantry[index % pantry.length],
        active: true,
        bob: index * 0.8,
      });
    }

    state.opponents = [
      { name: "Rae", color: COLORS[0], progress: 36, speed: 101.5, lane: -0.55, phase: 0.2 },
      { name: "Mo", color: COLORS[1], progress: 12, speed: 104.2, lane: 0.52, phase: 2.1 },
      { name: "Kit", color: COLORS[2], progress: -24, speed: 99.8, lane: 0.05, phase: 4.4 },
    ];
  }

  function resetRace() {
    state.progress = 0;
    state.lane = 0;
    state.velocity = 0;
    state.targetSpeed = 0;
    state.boostTime = 0;
    state.boosts = 0;
    state.collected = 0;
    state.elapsed = 0;
    state.collisionCooldown = 0;
    state.shake = 0;
    state.flash = 0;
    state.place = 1;
    state.particles = [];
    buildTrack();
    updateHud();
  }

  function setScreen(screen, active) {
    screen.classList.toggle("active", active);
    screen.setAttribute("aria-hidden", String(!active));
  }

  function startRace() {
    resetRace();
    setScreen(ui.startScreen, false);
    setScreen(ui.pauseScreen, false);
    setScreen(ui.finishScreen, false);
    state.mode = "countdown";
    let count = 3;
    showCount(String(count));
    const timer = window.setInterval(function () {
      count -= 1;
      if (count > 0) showCount(String(count));
      else if (count === 0) showCount("GO!");
      else {
        window.clearInterval(timer);
        state.mode = "racing";
        state.raceStartedAt = performance.now();
        state.targetSpeed = 106;
      }
    }, 760);
  }

  function showCount(value) {
    ui.countdown.textContent = value;
    ui.countdown.classList.remove("pop");
    void ui.countdown.offsetWidth;
    ui.countdown.classList.add("pop");
  }

  function pauseRace() {
    if (state.mode !== "racing") return;
    state.mode = "paused";
    setScreen(ui.pauseScreen, true);
  }

  function resumeRace() {
    if (state.mode !== "paused") return;
    setScreen(ui.pauseScreen, false);
    state.mode = "racing";
    lastFrame = performance.now();
  }

  function finishRace() {
    state.mode = "finished";
    state.velocity = 0;
    const ordinal = Core.ordinal(state.place).toUpperCase();
    ui.finalPlace.textContent = ordinal;
    ui.finalTime.textContent = Core.formatTime(state.elapsed);
    ui.finalGoods.textContent = `${state.collected}/${PANTRY_GOAL}`;
    ui.finishTitle.textContent = state.place === 1 ? "AISLE CHAMPION!" : "CHECKOUT HERO!";
    ui.finishCopy.textContent =
      state.collected >= PANTRY_GOAL
        ? "Full basket, fast wheels. The community pantry wins too."
        : "Great run! Grab more pantry goods on your next lap.";
    setScreen(ui.finishScreen, true);
  }

  function useBoost() {
    if (state.mode !== "racing" || state.boosts < 1 || state.boostTime > 0) return;
    state.boosts -= 1;
    state.boostTime = 1.45;
    state.flash = 0.45;
    emitParticles(state.lane, 12, "#ffd938");
    showToast("SUPER CART BOOST!");
    updateHud();
    if (navigator.vibrate) navigator.vibrate(25);
  }

  function showToast(message) {
    window.clearTimeout(toastTimer);
    ui.toast.textContent = message;
    ui.toast.classList.add("show");
    toastTimer = window.setTimeout(function () {
      ui.toast.classList.remove("show");
    }, 1100);
  }

  function emitParticles(lane, count, color) {
    for (let i = 0; i < count; i += 1) {
      state.particles.push({
        lane: lane + (Math.random() - 0.5) * 0.22,
        x: (Math.random() - 0.5) * 70,
        y: 0,
        vx: (Math.random() - 0.5) * 55,
        vy: 60 + Math.random() * 110,
        life: 0.5 + Math.random() * 0.45,
        color,
      });
    }
  }

  function update(delta) {
    if (state.mode !== "racing") return;

    state.elapsed += delta * 1000;
    const steering = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    state.lane = Core.clamp(state.lane + steering * delta * 1.65, -1.03, 1.03);

    if (!steering) {
      state.lane *= Math.pow(0.997, delta * 60);
    }

    state.boostTime = Math.max(0, state.boostTime - delta);
    state.collisionCooldown = Math.max(0, state.collisionCooldown - delta);
    state.shake = Math.max(0, state.shake - delta * 2.4);
    state.flash = Math.max(0, state.flash - delta);

    const offRoad = Math.max(0, Math.abs(state.lane) - 0.87);
    const desiredSpeed = (state.boostTime > 0 ? 153 : state.targetSpeed) - offRoad * 72;
    state.velocity += (desiredSpeed - state.velocity) * Math.min(1, delta * 2.3);
    state.progress += state.velocity * delta;

    state.opponents.forEach(function (opponent, index) {
      const wobble = Math.sin(state.elapsed * 0.00055 + opponent.phase) * 2.4;
      opponent.progress += (opponent.speed + wobble) * delta;
      opponent.lane = Core.clamp(
        Math.sin(opponent.progress / (170 + index * 13) + opponent.phase) * 0.66,
        -0.8,
        0.8
      );
    });

    state.objects.forEach(function (object) {
      if (!object.active) return;
      const relative = object.progress - state.progress;
      if (Core.hitTest(state.lane, object.lane, relative, object.type === "pantry" ? 0.28 : 0.3, 22)) {
        object.active = false;
        if (object.type === "pantry") {
          state.collected += 1;
          state.boosts = Math.min(3, state.boosts + 1);
          state.flash = 0.22;
          emitParticles(object.lane, 9, "#4ee0b7");
          showToast(state.collected === PANTRY_GOAL ? "PANTRY GOAL COMPLETE!" : `${object.icon} PANTRY PICKUP + BOOST`);
          if (navigator.vibrate) navigator.vibrate(15);
        } else if (state.collisionCooldown <= 0) {
          state.velocity *= 0.48;
          state.collisionCooldown = 0.8;
          state.shake = 0.65;
          emitParticles(object.lane, 8, "#ff7845");
          showToast(object.type === "spill" ? "SLIPPERY AISLE!" : "CART CRASH!");
          if (navigator.vibrate) navigator.vibrate([35, 25, 35]);
        }
      }
    });

    state.particles.forEach(function (particle) {
      particle.life -= delta;
      particle.x += particle.vx * delta;
      particle.y += particle.vy * delta;
    });
    state.particles = state.particles.filter(function (particle) {
      return particle.life > 0;
    });

    state.place = Core.calculatePlace(state.progress, state.opponents);
    updateHud();
    if (state.progress >= TOTAL_DISTANCE) finishRace();
  }

  function updateHud() {
    const rank = Core.ordinal(state.place);
    ui.position.textContent = String(state.place);
    ui.positionSuffix.textContent = rank.replace(String(state.place), "");
    ui.lap.textContent = String(Math.min(TOTAL_LAPS, Math.floor(state.progress / TRACK_LENGTH) + 1));
    ui.timer.textContent = Core.formatTime(state.elapsed);
    ui.collected.textContent = String(state.collected);
    ui.boostCount.textContent = String(state.boosts);
    ui.boostButton.disabled = state.boosts < 1 || state.mode !== "racing";
  }

  function roadCenterAt(progress, depth) {
    const curve =
      Math.sin((progress + depth * VIEW_DISTANCE) / 370) * width * 0.07 +
      Math.sin((progress + depth * VIEW_DISTANCE) / 910) * width * 0.035;
    return width / 2 + curve * (1 - depth);
  }

  function roadPoint(depth) {
    const horizon = height * 0.245;
    const bottom = height * 1.03;
    return Core.projectRoadPoint(depth, horizon, bottom, width * 0.11, width * 1.28, roadCenterAt(state.progress, depth));
  }

  function drawBackground() {
    const horizon = height * 0.245;
    const gradient = ctx.createLinearGradient(0, 0, 0, horizon);
    gradient.addColorStop(0, "#322969");
    gradient.addColorStop(0.62, "#7558c8");
    gradient.addColorStop(1, "#ffad70");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, horizon + 4);

    ctx.fillStyle = "rgba(255,249,233,.16)";
    for (let x = 24; x < width; x += 58) {
      ctx.fillRect(x, 0, 4, horizon);
      ctx.beginPath();
      ctx.arc(x + 2, horizon * 0.32, 12, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.fillStyle = "#292139";
    ctx.fillRect(0, horizon - 35, width, 40);
    ctx.fillStyle = "#ffd938";
    ctx.font = `900 ${Math.max(9, width * 0.025)}px DM Sans`;
    ctx.textAlign = "center";
    ctx.fillText("FRESH  •  FAST  •  FRIENDLY  •  CHECKOUT", width / 2, horizon - 12);

    drawShelves(horizon);
  }

  function drawShelves(horizon) {
    const shelfGradient = ctx.createLinearGradient(0, horizon, 0, height);
    shelfGradient.addColorStop(0, "#4a394d");
    shelfGradient.addColorStop(1, "#241c2c");

    ctx.fillStyle = shelfGradient;
    ctx.beginPath();
    ctx.moveTo(0, horizon - 4);
    ctx.lineTo(width * 0.445, horizon);
    ctx.lineTo(-width * 0.12, height);
    ctx.lineTo(0, height);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(width, horizon - 4);
    ctx.lineTo(width * 0.555, horizon);
    ctx.lineTo(width * 1.12, height);
    ctx.lineTo(width, height);
    ctx.closePath();
    ctx.fill();

    const scroll = Core.wrapDistance(state.progress * 1.7, 130);
    for (let z = 0; z < 9; z += 1) {
      const depth = Core.clamp((z * 130 - scroll + 130) / 1100, 0.02, 1);
      const point = roadPoint(depth);
      const shelfY = point.y;
      const aisleGap = point.width * 0.56;
      const shelfWidth = Math.max(8, point.scale * 82);
      const shelfHeight = Math.max(5, point.scale * 95);
      drawShelfUnit(point.centerX - aisleGap, shelfY, shelfWidth, shelfHeight, -1, z);
      drawShelfUnit(point.centerX + aisleGap, shelfY, shelfWidth, shelfHeight, 1, z);
    }
  }

  function drawShelfUnit(x, y, w, h, side, index) {
    ctx.save();
    ctx.translate(x, y - h);
    ctx.fillStyle = index % 2 ? "#d9595f" : "#e78b45";
    ctx.fillRect(side < 0 ? -w : 0, 0, w, h);
    ctx.fillStyle = "#fff0c2";
    for (let row = 0; row < 3; row += 1) {
      const rowY = 7 + row * (h / 3);
      ctx.fillRect(side < 0 ? -w : 0, rowY, w, Math.max(1, h * 0.04));
    }
    ctx.fillStyle = "#4ee0b7";
    const itemW = Math.max(1, w * 0.13);
    for (let item = 0; item < 4; item += 1) {
      const itemX = (side < 0 ? -w : 0) + 4 + item * (w / 4.5);
      ctx.fillRect(itemX, h * 0.14, itemW, h * 0.13);
    }
    ctx.restore();
  }

  function drawRoad() {
    const horizon = height * 0.245;
    ctx.fillStyle = "#b7abb0";
    ctx.beginPath();
    ctx.moveTo(width * 0.44, horizon);
    ctx.lineTo(width * 0.56, horizon);
    ctx.lineTo(width * 1.15, height);
    ctx.lineTo(-width * 0.15, height);
    ctx.closePath();
    ctx.fill();

    const segments = 34;
    for (let i = segments - 1; i >= 0; i -= 1) {
      const farDepth = (i + 1) / segments;
      const nearDepth = i / segments;
      const far = roadPoint(farDepth);
      const near = roadPoint(nearDepth);
      const courseIndex = Math.floor((state.progress + (1 - nearDepth) * VIEW_DISTANCE) / 52);
      ctx.fillStyle = courseIndex % 2 ? "#70666b" : "#796e73";
      ctx.beginPath();
      ctx.moveTo(far.centerX - far.width / 2, far.y);
      ctx.lineTo(far.centerX + far.width / 2, far.y);
      ctx.lineTo(near.centerX + near.width / 2, near.y);
      ctx.lineTo(near.centerX - near.width / 2, near.y);
      ctx.closePath();
      ctx.fill();

      ctx.strokeStyle = courseIndex % 2 ? "#ffd938" : "#f64471";
      ctx.lineWidth = Math.max(1, near.scale * 5);
      ctx.beginPath();
      ctx.moveTo(far.centerX - far.width / 2, far.y);
      ctx.lineTo(near.centerX - near.width / 2, near.y);
      ctx.moveTo(far.centerX + far.width / 2, far.y);
      ctx.lineTo(near.centerX + near.width / 2, near.y);
      ctx.stroke();

      if (courseIndex % 2 === 0) {
        ctx.strokeStyle = "rgba(255,249,233,.6)";
        ctx.lineWidth = Math.max(0.7, near.scale * 2.5);
        [-0.33, 0.33].forEach(function (lane) {
          ctx.beginPath();
          ctx.moveTo(far.centerX + lane * far.width, far.y);
          ctx.lineTo(near.centerX + lane * near.width, near.y);
          ctx.stroke();
        });
      }
    }
  }

  function drawWorldObjects() {
    const visible = [];
    state.objects.forEach(function (object) {
      if (!object.active) return;
      const relative = object.progress - state.progress;
      if (relative > 0 && relative < VIEW_DISTANCE) visible.push({ kind: "object", relative, data: object });
    });
    state.opponents.forEach(function (opponent) {
      const relative = opponent.progress - state.progress;
      if (relative > -35 && relative < VIEW_DISTANCE) visible.push({ kind: "racer", relative: Math.max(2, relative), data: opponent });
    });
    visible.sort(function (a, b) {
      return b.relative - a.relative;
    });

    visible.forEach(function (entry) {
      const depth = Core.clamp(entry.relative / VIEW_DISTANCE, 0, 1);
      const point = roadPoint(depth);
      const x = Core.laneToX(entry.data.lane, point);
      if (entry.kind === "racer") drawCart(x, point.y, point.scale * 0.72, entry.data.color, false);
      else drawPickup(entry.data, x, point.y, point.scale);
    });
  }

  function drawPickup(object, x, y, scale) {
    ctx.save();
    ctx.translate(x, y - Math.sin(performance.now() * 0.004 + object.bob) * 4 * scale);
    if (object.type === "pantry") {
      ctx.shadowColor = "#ffd938";
      ctx.shadowBlur = 18 * scale;
      ctx.fillStyle = "#fff9e9";
      ctx.beginPath();
      ctx.arc(0, -20 * scale, 23 * scale, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.font = `${Math.max(8, 31 * scale)}px sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(object.icon, 0, -20 * scale);
    } else if (object.type === "box") {
      ctx.rotate(0.07);
      ctx.fillStyle = "#b87942";
      ctx.strokeStyle = "#5c3425";
      ctx.lineWidth = Math.max(1, 3 * scale);
      ctx.fillRect(-26 * scale, -43 * scale, 52 * scale, 43 * scale);
      ctx.strokeRect(-26 * scale, -43 * scale, 52 * scale, 43 * scale);
      ctx.fillStyle = "#ffd938";
      ctx.fillRect(-4 * scale, -43 * scale, 8 * scale, 43 * scale);
    } else {
      ctx.scale(1, 0.42);
      ctx.fillStyle = "rgba(78,224,183,.78)";
      ctx.beginPath();
      ctx.ellipse(0, -15 * scale, 38 * scale, 22 * scale, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#fff9e9";
      ctx.beginPath();
      ctx.arc(-8 * scale, -24 * scale, 8 * scale, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawCart(x, y, scale, color, player) {
    const s = Math.max(0.12, scale);
    ctx.save();
    ctx.translate(x, y);
    if (player && state.shake > 0) {
      ctx.translate((Math.random() - 0.5) * state.shake * 15, (Math.random() - 0.5) * state.shake * 8);
    }

    ctx.fillStyle = "rgba(10,8,18,.35)";
    ctx.beginPath();
    ctx.ellipse(0, 5 * s, 54 * s, 15 * s, 0, 0, Math.PI * 2);
    ctx.fill();

    if (player && state.boostTime > 0) {
      ctx.fillStyle = "#ffd938";
      for (let i = -1; i <= 1; i += 1) {
        ctx.beginPath();
        ctx.moveTo(i * 18 * s - 7 * s, -2 * s);
        ctx.lineTo(i * 18 * s, (30 + Math.random() * 30) * s);
        ctx.lineTo(i * 18 * s + 7 * s, -2 * s);
        ctx.fill();
      }
    }

    ctx.fillStyle = color;
    ctx.strokeStyle = "#171425";
    ctx.lineWidth = 5 * s;
    ctx.beginPath();
    ctx.moveTo(-44 * s, -70 * s);
    ctx.lineTo(41 * s, -70 * s);
    ctx.lineTo(32 * s, -17 * s);
    ctx.lineTo(-34 * s, -17 * s);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.strokeStyle = "rgba(255,255,255,.72)";
    ctx.lineWidth = 2.5 * s;
    for (let line = -22; line <= 22; line += 22) {
      ctx.beginPath();
      ctx.moveTo(line * s, -66 * s);
      ctx.lineTo(line * 0.8 * s, -21 * s);
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.moveTo(-38 * s, -48 * s);
    ctx.lineTo(36 * s, -48 * s);
    ctx.stroke();

    ctx.fillStyle = "#ffd938";
    ctx.fillRect(-25 * s, -88 * s, 19 * s, 20 * s);
    ctx.fillStyle = "#4ee0b7";
    ctx.fillRect(2 * s, -82 * s, 23 * s, 14 * s);

    ctx.strokeStyle = "#fff9e9";
    ctx.lineWidth = 6 * s;
    ctx.beginPath();
    ctx.moveTo(-35 * s, -14 * s);
    ctx.lineTo(-27 * s, 0);
    ctx.lineTo(31 * s, 0);
    ctx.stroke();

    ctx.fillStyle = "#171425";
    [-26, 27].forEach(function (wheel) {
      ctx.beginPath();
      ctx.arc(wheel * s, 8 * s, 10 * s, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#fff9e9";
      ctx.beginPath();
      ctx.arc(wheel * s, 8 * s, 3.5 * s, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#171425";
    });
    ctx.restore();
  }

  function drawPlayer() {
    const bottomPoint = roadPoint(0);
    const x = Core.laneToX(state.lane, bottomPoint);
    drawCart(x, height - Math.max(112, height * 0.13), Math.max(0.78, width / 485), "#f64471", true);
    state.particles.forEach(function (particle) {
      ctx.save();
      ctx.globalAlpha = Core.clamp(particle.life * 1.5, 0, 1);
      ctx.fillStyle = particle.color;
      ctx.translate(x + particle.x, height - 76 + particle.y);
      ctx.rotate(particle.x);
      ctx.fillRect(-3, -3, 7, 7);
      ctx.restore();
    });
  }

  function drawSpeedLines() {
    if (state.velocity < 125) return;
    ctx.save();
    ctx.globalAlpha = Core.clamp((state.velocity - 120) / 50, 0, 0.55);
    ctx.strokeStyle = "#fff9e9";
    ctx.lineWidth = 2;
    for (let i = 0; i < 16; i += 1) {
      const x = (i * 97 + state.progress * 3) % width;
      const y = height * 0.3 + ((i * 143 + state.progress * 5) % (height * 0.62));
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + (x < width / 2 ? -16 : 16), y + 54);
      ctx.stroke();
    }
    ctx.restore();
  }

  function render() {
    ctx.save();
    if (state.shake > 0) ctx.translate((Math.random() - 0.5) * 7, (Math.random() - 0.5) * 5);
    drawBackground();
    drawRoad();
    drawWorldObjects();
    drawSpeedLines();
    drawPlayer();

    if (state.mode === "countdown") {
      ctx.fillStyle = "rgba(23,20,37,.18)";
      ctx.fillRect(0, 0, width, height);
    }
    if (state.flash > 0) {
      ctx.globalAlpha = Core.clamp(state.flash * 0.45, 0, 0.22);
      ctx.fillStyle = state.boostTime > 0 ? "#ffd938" : "#fff9e9";
      ctx.fillRect(0, 0, width, height);
    }
    ctx.restore();
  }

  function frame(now) {
    const delta = Math.min(0.04, Math.max(0, (now - lastFrame) / 1000));
    lastFrame = now;
    update(delta);
    render();
    window.requestAnimationFrame(frame);
  }

  function bindHold(button, direction) {
    const down = function (event) {
      event.preventDefault();
      input[direction] = true;
      button.classList.add("pressed");
    };
    const up = function (event) {
      if (event) event.preventDefault();
      input[direction] = false;
      button.classList.remove("pressed");
    };
    button.addEventListener("pointerdown", down);
    button.addEventListener("pointerup", up);
    button.addEventListener("pointercancel", up);
    button.addEventListener("pointerleave", up);
  }

  ui.startButton.addEventListener("click", startRace);
  ui.pauseButton.addEventListener("click", function () {
    if (state.mode === "paused") resumeRace();
    else pauseRace();
  });
  ui.resumeButton.addEventListener("click", resumeRace);
  ui.restartButton.addEventListener("click", startRace);
  ui.raceAgainButton.addEventListener("click", startRace);
  ui.boostButton.addEventListener("click", useBoost);
  bindHold(ui.leftButton, "left");
  bindHold(ui.rightButton, "right");

  window.addEventListener("keydown", function (event) {
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") input.left = true;
    if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") input.right = true;
    if (event.key === " " || event.key === "ArrowUp") {
      event.preventDefault();
      useBoost();
    }
    if (event.key === "Escape") {
      if (state.mode === "paused") resumeRace();
      else pauseRace();
    }
  });

  window.addEventListener("keyup", function (event) {
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") input.left = false;
    if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") input.right = false;
  });

  canvas.addEventListener("pointerdown", function (event) {
    touchStartX = event.clientX;
  });
  canvas.addEventListener("pointermove", function (event) {
    if (touchStartX === null || state.mode !== "racing") return;
    const difference = event.clientX - touchStartX;
    state.lane = Core.clamp(state.lane + difference / width * 1.7, -1.03, 1.03);
    touchStartX = event.clientX;
  });
  window.addEventListener("pointerup", function () {
    touchStartX = null;
  });
  window.addEventListener("resize", resize);
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) pauseRace();
  });

  resize();
  resetRace();
  window.requestAnimationFrame(frame);
})();
