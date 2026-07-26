(function () {
  "use strict";

  var Core = window.CartCore;
  var canvas = document.getElementById("game");
  var ctx = canvas.getContext("2d", { alpha: false });
  var shell = document.getElementById("game-shell");
  var ui = {
    menu: document.getElementById("menu"),
    hud: document.getElementById("hud"),
    lap: document.getElementById("lap-value"),
    position: document.getElementById("position-value"),
    positionSuffix: document.getElementById("position-suffix"),
    boost: document.getElementById("boost-fill"),
    toast: document.getElementById("toast"),
    countdown: document.getElementById("countdown"),
    touch: document.getElementById("touch-controls"),
    pause: document.getElementById("pause-panel"),
    finish: document.getElementById("finish-panel"),
    finishPlace: document.getElementById("finish-place"),
    finishTitle: document.getElementById("finish-title"),
    finishTime: document.getElementById("finish-time"),
    finishScore: document.getElementById("finish-score"),
    sound: document.getElementById("sound-button"),
  };

  var CARTS = [
    { name: "Rocket", color: "#ff6d38", accent: "#ffe45d", maxSpeed: 188, turn: 1.48, toughness: 0.78, load: "boxes" },
    { name: "Hauler", color: "#57c98d", accent: "#d9ff43", maxSpeed: 171, turn: 1.12, toughness: 1.38, load: "blanket" },
    { name: "Nimble", color: "#f172b6", accent: "#8effe1", maxSpeed: 179, turn: 1.76, toughness: 0.94, load: "fruit" },
  ];
  var RIVALS = [
    { name: "Moxie", color: "#ffcf48", speed: 174, lane: -0.5, load: "fruit" },
    { name: "Rico", color: "#6be1ff", speed: 169, lane: 0.42, load: "boxes" },
    { name: "June", color: "#f172b6", speed: 177, lane: 0.05, load: "blanket" },
    { name: "Bo", color: "#a98bff", speed: 165, lane: -0.15, load: "boxes" },
    { name: "Dot", color: "#66d77f", speed: 172, lane: 0.64, load: "fruit" },
  ];
  var TRACK = {
    laps: 3,
    lapLength: 1900,
    viewDistance: 700,
  };

  var width = 390;
  var height = 844;
  var dpr = 1;
  var selectedCart = 0;
  var screen = "menu";
  var lastTime = performance.now();
  var countdownToken = 0;
  var toastTimer = 0;
  var shake = 0;
  var flash = 0;
  var ambientDistance = 230;
  var hazards = [];
  var pickups = [];
  var rivals = [];
  var particles = [];
  var input = { left: false, right: false, boost: false };
  var player = {
    x: 0,
    steer: 0,
    speed: 0,
    distance: 0,
    boost: 72,
    score: 0,
    position: 1,
    raceTime: 0,
    hitCooldown: 0,
    boosting: false,
  };

  function resize() {
    var rect = shell.getBoundingClientRect();
    width = Math.max(280, rect.width);
    height = Math.max(540, rect.height);
    dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
  }

  function SoundEngine() {
    this.context = null;
    this.master = null;
    this.engine = null;
    this.engineGain = null;
    this.enabled = true;
  }

  SoundEngine.prototype.init = function () {
    if (this.context) {
      if (this.context.state === "suspended") this.context.resume();
      return;
    }
    var AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    this.context = new AudioContext();
    this.master = this.context.createGain();
    this.master.gain.value = this.enabled ? 0.42 : 0;
    this.master.connect(this.context.destination);
    this.engine = this.context.createOscillator();
    this.engine.type = "sawtooth";
    this.engineGain = this.context.createGain();
    this.engineGain.gain.value = 0;
    this.engine.connect(this.engineGain);
    this.engineGain.connect(this.master);
    this.engine.start();
  };

  SoundEngine.prototype.setEngine = function (speed, active) {
    if (!this.context || !this.engine) return;
    var now = this.context.currentTime;
    this.engine.frequency.setTargetAtTime(48 + speed * 0.54, now, 0.06);
    this.engineGain.gain.setTargetAtTime(active && this.enabled ? 0.035 : 0, now, 0.08);
  };

  SoundEngine.prototype.beep = function (frequency, duration, type, volume) {
    if (!this.context || !this.enabled) return;
    var now = this.context.currentTime;
    var oscillator = this.context.createOscillator();
    var gain = this.context.createGain();
    oscillator.type = type || "square";
    oscillator.frequency.setValueAtTime(frequency, now);
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, frequency * 1.6), now + duration);
    gain.gain.setValueAtTime(volume || 0.14, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    oscillator.connect(gain);
    gain.connect(this.master);
    oscillator.start(now);
    oscillator.stop(now + duration);
  };

  SoundEngine.prototype.toggle = function () {
    this.init();
    this.enabled = !this.enabled;
    if (this.master) this.master.gain.setTargetAtTime(this.enabled ? 0.42 : 0, this.context.currentTime, 0.05);
    ui.sound.classList.toggle("is-muted", !this.enabled);
    ui.sound.textContent = this.enabled ? "♪" : "×";
  };

  var sound = new SoundEngine();

  function makeCourse() {
    var random = Core.seededRandom(8128);
    hazards = [];
    pickups = [];
    var z = 155;
    var id = 0;
    while (z < TRACK.lapLength - 90) {
      var lane = Core.lerp(-0.75, 0.75, random());
      hazards.push({
        id: id++,
        z: z,
        lane: lane,
        type: random() < 0.36 ? "spill" : random() < 0.66 ? "crate" : "cone",
        hitLap: -1,
      });
      var pickupLane = lane > 0 ? lane - 0.62 : lane + 0.62;
      pickups.push({
        id: id++,
        z: (z + 56 + random() * 28) % TRACK.lapLength,
        lane: Core.clamp(pickupLane + (random() - 0.5) * 0.18, -0.78, 0.78),
        collectedLap: -1,
      });
      z += 145 + random() * 105;
    }
  }

  function resetRace() {
    var cart = CARTS[selectedCart];
    player.x = 0;
    player.steer = 0;
    player.speed = 78;
    player.distance = 0;
    player.boost = 72;
    player.score = 0;
    player.position = 1;
    player.raceTime = 0;
    player.hitCooldown = 0;
    player.boosting = false;
    particles.length = 0;
    makeCourse();
    rivals = RIVALS.map(function (rival, index) {
      return {
        name: rival.name,
        color: rival.color,
        baseSpeed: rival.speed + (cart.maxSpeed - 179) * 0.14,
        lane: rival.lane,
        targetLane: rival.lane,
        distance: -18 - index * 13,
        load: rival.load,
        seed: index * 1.73,
      };
    });
    updateHud();
  }

  function startCountdown() {
    countdownToken += 1;
    var token = countdownToken;
    screen = "countdown";
    ui.menu.classList.add("is-hidden");
    ui.pause.classList.add("is-hidden");
    ui.finish.classList.add("is-hidden");
    ui.hud.classList.remove("is-hidden");
    ui.touch.classList.remove("is-hidden");
    sound.init();
    sound.setEngine(player.speed, true);
    var marks = ["3", "2", "1", "GO!"];
    marks.forEach(function (mark, index) {
      window.setTimeout(function () {
        if (token !== countdownToken) return;
        ui.countdown.textContent = mark;
        ui.countdown.classList.remove("pop");
        void ui.countdown.offsetWidth;
        ui.countdown.classList.add("pop");
        sound.beep(mark === "GO!" ? 660 : 330, mark === "GO!" ? 0.22 : 0.1, "square", 0.12);
        if (mark === "GO!") {
          screen = "racing";
          player.raceTime = 0;
        }
      }, index * 680);
    });
  }

  function beginRace() {
    resetRace();
    startCountdown();
  }

  function pauseRace() {
    if (screen !== "racing" && screen !== "countdown") return;
    countdownToken += 1;
    screen = "paused";
    clearInput();
    ui.pause.classList.remove("is-hidden");
    ui.touch.classList.add("is-hidden");
    sound.setEngine(0, false);
  }

  function resumeRace() {
    if (screen !== "paused") return;
    ui.pause.classList.add("is-hidden");
    ui.touch.classList.remove("is-hidden");
    screen = "racing";
    lastTime = performance.now();
  }

  function restartRace() {
    ui.pause.classList.add("is-hidden");
    ui.finish.classList.add("is-hidden");
    resetRace();
    startCountdown();
  }

  function returnToMenu() {
    countdownToken += 1;
    screen = "menu";
    clearInput();
    ui.finish.classList.add("is-hidden");
    ui.pause.classList.add("is-hidden");
    ui.hud.classList.add("is-hidden");
    ui.touch.classList.add("is-hidden");
    ui.menu.classList.remove("is-hidden");
    sound.setEngine(0, false);
  }

  function finishRace() {
    if (screen === "finished") return;
    screen = "finished";
    clearInput();
    ui.touch.classList.add("is-hidden");
    sound.setEngine(0, false);
    sound.beep(player.position === 1 ? 780 : 520, 0.5, "triangle", 0.2);
    var suffix = Core.ordinal(player.position);
    ui.finishPlace.innerHTML = player.position + "<sup>" + suffix + "</sup>";
    ui.finishTitle.textContent = player.position === 1 ? "AISLE CHAMPION!" : player.position <= 3 ? "PODIUM PARKING!" : "CLEAN RUN!";
    ui.finishTime.textContent = Core.formatTime(player.raceTime);
    ui.finishScore.textContent = player.score;
    window.setTimeout(function () {
      if (screen === "finished") ui.finish.classList.remove("is-hidden");
    }, 500);
  }

  function showToast(message) {
    ui.toast.textContent = message;
    ui.toast.classList.remove("is-visible");
    void ui.toast.offsetWidth;
    ui.toast.classList.add("is-visible");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(function () {
      ui.toast.classList.remove("is-visible");
    }, 900);
  }

  function updateHud() {
    var lap = Core.clamp(Math.floor(Math.max(0, player.distance) / TRACK.lapLength) + 1, 1, TRACK.laps);
    ui.lap.textContent = lap + "/" + TRACK.laps;
    ui.position.textContent = player.position;
    ui.positionSuffix.textContent = Core.ordinal(player.position);
    ui.boost.style.transform = "scaleX(" + Core.clamp(player.boost / 100, 0, 1) + ")";
  }

  function clearInput() {
    input.left = false;
    input.right = false;
    input.boost = false;
    Array.prototype.forEach.call(document.querySelectorAll(".is-pressed"), function (element) {
      element.classList.remove("is-pressed");
    });
  }

  function addParticle(x, y, color, speed) {
    particles.push({
      x: x,
      y: y,
      vx: (Math.random() - 0.5) * speed,
      vy: Math.random() * speed * 0.5 + speed * 0.25,
      life: 0.38 + Math.random() * 0.35,
      maxLife: 0.73,
      size: 2 + Math.random() * 5,
      color: color,
    });
    if (particles.length > 90) particles.shift();
  }

  function hitHazard(hazard, lap) {
    if (player.hitCooldown > 0 || hazard.hitLap === lap) return;
    hazard.hitLap = lap;
    player.hitCooldown = 0.85;
    player.speed *= Math.max(0.42, 0.58 + (CARTS[selectedCart].toughness - 1) * 0.17);
    player.steer += hazard.lane > player.x ? -0.9 : 0.9;
    shake = 11;
    flash = 0.2;
    sound.beep(95, 0.2, "sawtooth", 0.16);
    showToast(hazard.type === "spill" ? "SLIPPERY!" : "CART CLATTER!");
    for (var i = 0; i < 14; i += 1) addParticle(width / 2, height * 0.8, "#ffd552", 110);
  }

  function collectPickup(pickup, lap) {
    if (pickup.collectedLap === lap) return;
    pickup.collectedLap = lap;
    player.boost = Core.clamp(player.boost + 24, 0, 100);
    player.score += 1;
    flash = 0.13;
    sound.beep(470, 0.14, "triangle", 0.14);
    showToast("+ BOOST COUPON");
    for (var i = 0; i < 16; i += 1) addParticle(width / 2, height * 0.72, i % 2 ? "#d9ff43" : "#fff4d6", 130);
  }

  function updateRace(dt) {
    var cart = CARTS[selectedCart];
    var steerTarget = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    player.steer = Core.lerp(player.steer, steerTarget, Math.min(1, dt * 9));
    player.x += player.steer * cart.turn * dt * (0.7 + player.speed / cart.maxSpeed * 0.45);
    player.x = Core.clamp(player.x, -1.06, 1.06);
    player.hitCooldown = Math.max(0, player.hitCooldown - dt);

    var onEdge = Math.abs(player.x) > 0.83;
    player.boosting = input.boost && player.boost > 0.4 && !onEdge;
    var targetSpeed = cart.maxSpeed * (onEdge ? 0.66 : 1);
    if (player.boosting) {
      targetSpeed += 68;
      player.boost = Math.max(0, player.boost - dt * 28);
      if (Math.random() < dt * 35) {
        addParticle(width / 2 + player.x * width * 0.23, height - 128, Math.random() > 0.5 ? "#d9ff43" : "#ff6d38", 105);
      }
    } else {
      player.boost = Math.min(100, player.boost + dt * 2.1);
    }
    var acceleration = player.speed < targetSpeed ? 38 : 74;
    player.speed = Core.lerp(player.speed, targetSpeed, Math.min(1, dt * acceleration / Math.max(80, targetSpeed)));
    player.distance += player.speed * dt;
    player.raceTime += dt;

    var lap = Math.floor(player.distance / TRACK.lapLength);
    var localDistance = ((player.distance % TRACK.lapLength) + TRACK.lapLength) % TRACK.lapLength;
    hazards.forEach(function (hazard) {
      var delta = Core.forwardDistance(localDistance, hazard.z, TRACK.lapLength);
      if (delta < 18 && Math.abs(player.x - hazard.lane) < (hazard.type === "spill" ? 0.27 : 0.2)) hitHazard(hazard, lap);
    });
    pickups.forEach(function (pickup) {
      var delta = Core.forwardDistance(localDistance, pickup.z, TRACK.lapLength);
      if (delta < 20 && Math.abs(player.x - pickup.lane) < 0.24) collectPickup(pickup, lap);
    });

    rivals.forEach(function (rival, index) {
      var gap = player.distance - rival.distance;
      var rubberBand = Core.clamp(gap * 0.015, -12, 15);
      rival.distance += (rival.baseSpeed + rubberBand + Math.sin(player.raceTime * 0.75 + rival.seed) * 4) * dt;
      if (Math.random() < dt * 0.18) {
        rival.targetLane = Core.clamp(rival.targetLane + (Math.random() - 0.5) * 0.8, -0.76, 0.76);
      }
      rival.lane = Core.lerp(rival.lane, rival.targetLane, dt * (0.45 + index * 0.03));
    });

    player.position = Core.racePosition(player.distance, rivals.map(function (rival) { return rival.distance; }));
    sound.setEngine(player.speed, true);
    updateHud();
    if (player.distance >= TRACK.lapLength * TRACK.laps) finishRace();
  }

  function updateParticles(dt) {
    particles.forEach(function (particle) {
      particle.life -= dt;
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= Math.pow(0.12, dt);
    });
    particles = particles.filter(function (particle) { return particle.life > 0; });
  }

  function curveAt(distance) {
    return Math.sin(distance / 235) * width * 0.12 + Math.sin(distance / 77) * width * 0.035;
  }

  function roadGeometry(distance, progress) {
    var depth = TRACK.viewDistance * Math.pow(1 - progress, 1.82);
    var curve = curveAt(distance + depth) - curveAt(distance);
    var center = width / 2 + curve * (0.92 - progress * 0.48);
    var half = Core.lerp(width * 0.105, width * 0.63, Math.pow(progress, 1.03));
    return { depth: depth, center: center, half: half };
  }

  function polygon(points, fill) {
    ctx.beginPath();
    ctx.moveTo(points[0][0], points[0][1]);
    for (var i = 1; i < points.length; i += 1) ctx.lineTo(points[i][0], points[i][1]);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
  }

  function drawStore(distance) {
    var horizon = height * 0.235;
    var ceiling = ctx.createLinearGradient(0, 0, 0, horizon);
    ceiling.addColorStop(0, "#13261d");
    ceiling.addColorStop(1, "#2e4638");
    ctx.fillStyle = ceiling;
    ctx.fillRect(0, 0, width, horizon + 2);

    var glow = ctx.createRadialGradient(width / 2, horizon * 0.65, 2, width / 2, horizon * 0.65, width * 0.72);
    glow.addColorStop(0, "rgba(255,244,204,.3)");
    glow.addColorStop(1, "rgba(255,244,204,0)");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, width, horizon * 1.5);

    for (var lightIndex = -2; lightIndex <= 2; lightIndex += 1) {
      var lightX = width / 2 + lightIndex * width * 0.22 - (distance * 0.035) % (width * 0.22);
      ctx.fillStyle = "rgba(255,250,205,.72)";
      polygon([[lightX - 20, 10], [lightX + 20, 10], [lightX + 9, horizon * 0.72], [lightX - 9, horizon * 0.72]], ctx.fillStyle);
    }

    var floor = ctx.createLinearGradient(0, horizon, 0, height);
    floor.addColorStop(0, "#a9aa91");
    floor.addColorStop(1, "#dad7b4");
    ctx.fillStyle = floor;
    ctx.fillRect(0, horizon, width, height - horizon);

    var step = Math.max(3, Math.floor(height / 170));
    for (var y = Math.floor(horizon); y < height; y += step) {
      var progress = (y - horizon) / (height - horizon);
      var nextProgress = Math.min(1, (y + step - horizon) / (height - horizon));
      var geo = roadGeometry(distance, progress);
      var next = roadGeometry(distance, nextProgress);
      var stripe = Math.floor((distance + geo.depth) / 45);
      var floorColor = stripe % 2 ? "#d8d4b2" : "#cecbae";
      polygon([
        [geo.center - geo.half, y],
        [geo.center + geo.half, y],
        [next.center + next.half, y + step + 1],
        [next.center - next.half, y + step + 1],
      ], floorColor);

      var shelfShade = stripe % 2 ? "#5b4030" : "#634836";
      ctx.fillStyle = shelfShade;
      ctx.fillRect(0, y, Math.max(0, geo.center - geo.half), step + 1);
      ctx.fillRect(Math.min(width, geo.center + geo.half), y, width, step + 1);

      if (stripe % 3 === 0) {
        ctx.fillStyle = stripe % 6 === 0 ? "#e85f3d" : "#d6b948";
        var leftEdge = Math.max(0, geo.center - geo.half);
        var rightEdge = Math.min(width, geo.center + geo.half);
        ctx.fillRect(0, y, leftEdge * 0.68, Math.max(1, step * 0.48));
        ctx.fillRect(rightEdge + (width - rightEdge) * 0.32, y, width, Math.max(1, step * 0.48));
      }
    }

    var near = roadGeometry(distance, 1);
    var far = roadGeometry(distance, 0);
    ctx.strokeStyle = "rgba(92,75,52,.3)";
    ctx.lineWidth = 2;
    [-0.36, 0.36].forEach(function (lane) {
      ctx.beginPath();
      ctx.moveTo(far.center + far.half * lane, horizon);
      for (var py = horizon; py <= height; py += 12) {
        var p = (py - horizon) / (height - horizon);
        var road = roadGeometry(distance, p);
        ctx.lineTo(road.center + road.half * lane, py);
      }
      ctx.stroke();
    });

    ctx.strokeStyle = "#82654b";
    ctx.lineWidth = Math.max(2, width * 0.012);
    ctx.beginPath();
    ctx.moveTo(far.center - far.half, horizon);
    ctx.lineTo(near.center - near.half, height);
    ctx.moveTo(far.center + far.half, horizon);
    ctx.lineTo(near.center + near.half, height);
    ctx.stroke();

    drawOverheadSigns(distance, horizon);
  }

  function drawOverheadSigns(distance, horizon) {
    var segment = Math.floor(distance / 430);
    var offset = 1 - (distance % 430) / 430;
    if (offset < 0.16 || offset > 0.88) return;
    var scale = 0.35 + (1 - offset) * 0.68;
    var y = horizon + (1 - offset) * height * 0.25;
    var labels = ["PRODUCE", "PANTRY", "HOME", "CHECKOUT"];
    var label = labels[Math.abs(segment) % labels.length];
    ctx.save();
    ctx.translate(width / 2, y);
    ctx.scale(scale, scale);
    ctx.fillStyle = "#173b2d";
    ctx.strokeStyle = "#d9ff43";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.roundRect(-66, -20, 132, 40, 7);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#fff4d6";
    ctx.font = "800 16px 'Barlow Condensed', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(label, 0, 1);
    ctx.restore();
  }

  function projectObject(distance, lane, raceDistance) {
    if (distance <= 0 || distance > TRACK.viewDistance) return null;
    var progress = 1 - Math.sqrt(distance / TRACK.viewDistance);
    var geo = roadGeometry(raceDistance, progress);
    return {
      x: geo.center + lane * geo.half * 0.77,
      y: height * 0.235 + progress * height * 0.765,
      scale: 0.2 + progress * 1.42,
      progress: progress,
    };
  }

  function drawHazard(object, projection) {
    var scale = projection.scale;
    ctx.save();
    ctx.translate(projection.x, projection.y);
    ctx.scale(scale, scale * 0.86);
    if (object.type === "spill") {
      ctx.fillStyle = "rgba(64,151,190,.72)";
      ctx.beginPath();
      ctx.ellipse(0, 0, 22, 8, -0.15, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(210,248,255,.65)";
      ctx.beginPath();
      ctx.ellipse(-5, -2, 7, 2, 0, 0, Math.PI * 2);
      ctx.fill();
    } else if (object.type === "crate") {
      ctx.fillStyle = "#86542f";
      ctx.fillRect(-15, -22, 30, 22);
      ctx.strokeStyle = "#d39a59";
      ctx.lineWidth = 3;
      ctx.strokeRect(-15, -22, 30, 22);
      ctx.beginPath();
      ctx.moveTo(-14, -21);
      ctx.lineTo(14, 0);
      ctx.moveTo(14, -21);
      ctx.lineTo(-14, 0);
      ctx.stroke();
    } else {
      ctx.fillStyle = "#ff6d38";
      polygon([[-13, 0], [0, -31], [13, 0]], "#ff6d38");
      ctx.fillStyle = "#fff4d6";
      ctx.fillRect(-8, -12, 16, 5);
    }
    ctx.restore();
  }

  function drawPickup(object, projection, now) {
    var scale = projection.scale;
    var bob = Math.sin(now * 0.006 + object.id) * 4 * scale;
    ctx.save();
    ctx.translate(projection.x, projection.y - 13 * scale + bob);
    ctx.scale(scale, scale);
    ctx.rotate(Math.sin(now * 0.004 + object.id) * 0.17);
    ctx.shadowColor = "#d9ff43";
    ctx.shadowBlur = 15;
    ctx.fillStyle = "#d9ff43";
    ctx.beginPath();
    ctx.roundRect(-15, -12, 30, 24, 5);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.fillStyle = "#173b2d";
    ctx.font = "900 15px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("⚡", 0, 1);
    ctx.restore();
  }

  function drawCart(x, y, scale, color, tilt, load, isPlayer) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(tilt || 0);
    ctx.scale(scale, scale);
    ctx.shadowColor = "rgba(0,0,0,.32)";
    ctx.shadowBlur = 8;
    ctx.shadowOffsetY = 6;

    ctx.fillStyle = "#202b26";
    ctx.beginPath();
    ctx.ellipse(-18, 17, 5, 8, 0, 0, Math.PI * 2);
    ctx.ellipse(18, 17, 5, 8, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.shadowColor = "transparent";
    ctx.fillStyle = color;
    polygon([[-27, -14], [27, -14], [21, 15], [-21, 15]], color);
    ctx.fillStyle = "rgba(255,255,255,.23)";
    for (var line = -16; line <= 16; line += 8) ctx.fillRect(line, -11, 3, 23);
    ctx.fillStyle = "rgba(9,20,15,.28)";
    ctx.fillRect(-25, 6, 50, 4);

    if (load === "boxes") {
      ctx.fillStyle = "#bc7b42";
      ctx.fillRect(-15, -26, 19, 15);
      ctx.fillStyle = "#e0a660";
      ctx.fillRect(4, -22, 14, 11);
    } else if (load === "blanket") {
      ctx.fillStyle = "#577bb6";
      ctx.beginPath();
      ctx.roundRect(-18, -25, 35, 15, 4);
      ctx.fill();
      ctx.strokeStyle = "#f2c65c";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-15, -20);
      ctx.lineTo(15, -15);
      ctx.stroke();
    } else {
      ctx.fillStyle = "#50b864";
      ctx.beginPath();
      ctx.arc(-7, -18, 9, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#f2635c";
      ctx.beginPath();
      ctx.arc(10, -18, 8, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.strokeStyle = "#ecf0de";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-28, -16);
    ctx.lineTo(-33, -31);
    ctx.lineTo(25, -31);
    ctx.stroke();

    ctx.fillStyle = "#d49a72";
    ctx.beginPath();
    ctx.arc(0, -45, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = isPlayer ? CARTS[selectedCart].accent : "#f2da6f";
    ctx.beginPath();
    ctx.arc(0, -48, 10.5, Math.PI, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(-10, -48, 20, 5);

    if (isPlayer) {
      ctx.strokeStyle = CARTS[selectedCart].accent;
      ctx.lineWidth = 2;
      ctx.strokeRect(-27, -14, 54, 29);
    }
    ctx.restore();
  }

  function drawWorldObjects(now, raceDistance) {
    var localDistance = ((raceDistance % TRACK.lapLength) + TRACK.lapLength) % TRACK.lapLength;
    var lap = Math.floor(Math.max(0, raceDistance) / TRACK.lapLength);
    var renderables = [];

    hazards.forEach(function (hazard) {
      var delta = Core.forwardDistance(localDistance, hazard.z, TRACK.lapLength);
      var projection = projectObject(delta, hazard.lane, raceDistance);
      if (projection) renderables.push({ kind: "hazard", value: hazard, projection: projection });
    });
    pickups.forEach(function (pickup) {
      if (pickup.collectedLap === lap) return;
      var delta = Core.forwardDistance(localDistance, pickup.z, TRACK.lapLength);
      var projection = projectObject(delta, pickup.lane, raceDistance);
      if (projection) renderables.push({ kind: "pickup", value: pickup, projection: projection });
    });
    if (screen !== "menu") {
      rivals.forEach(function (rival) {
        var delta = rival.distance - player.distance;
        var projection = projectObject(delta, rival.lane, raceDistance);
        if (projection) renderables.push({ kind: "rival", value: rival, projection: projection });
      });
    }

    renderables.sort(function (a, b) { return a.projection.progress - b.projection.progress; });
    renderables.forEach(function (item) {
      if (item.kind === "hazard") drawHazard(item.value, item.projection);
      if (item.kind === "pickup") drawPickup(item.value, item.projection, now);
      if (item.kind === "rival") {
        drawCart(
          item.projection.x,
          item.projection.y - 10 * item.projection.scale,
          item.projection.scale * 0.72,
          item.value.color,
          Math.sin(now * 0.002 + item.value.seed) * 0.04,
          item.value.load,
          false
        );
      }
    });
  }

  function drawPlayer(now, raceDistance) {
    var near = roadGeometry(raceDistance, 0.94);
    var x = near.center + player.x * near.half * 0.69;
    var y = height - Math.max(125, height * 0.158);
    if (player.boosting) {
      ctx.strokeStyle = "rgba(217,255,67,.5)";
      ctx.lineWidth = 2;
      for (var i = 0; i < 9; i += 1) {
        var speedLineX = (i * 71 + now * 0.42) % width;
        var speedLineY = height * 0.3 + ((i * 103 + now * 0.7) % (height * 0.6));
        ctx.beginPath();
        ctx.moveTo(speedLineX, speedLineY);
        ctx.lineTo(speedLineX + player.steer * -8, speedLineY + 28);
        ctx.stroke();
      }
    }
    drawCart(x, y, Core.clamp(width / 390, 0.9, 1.18), CARTS[selectedCart].color, -player.steer * 0.1, CARTS[selectedCart].load, true);
  }

  function drawParticles() {
    particles.forEach(function (particle) {
      ctx.globalAlpha = Core.clamp(particle.life / particle.maxLife, 0, 1);
      ctx.fillStyle = particle.color;
      ctx.fillRect(particle.x, particle.y, particle.size, particle.size);
    });
    ctx.globalAlpha = 1;
  }

  function draw(now) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);
    var raceDistance = screen === "menu" ? ambientDistance : player.distance;
    var shakeX = shake > 0 ? (Math.random() - 0.5) * shake : 0;
    var shakeY = shake > 0 ? (Math.random() - 0.5) * shake * 0.55 : 0;
    ctx.save();
    ctx.translate(shakeX, shakeY);
    drawStore(raceDistance);
    drawWorldObjects(now, raceDistance);
    drawPlayer(now, raceDistance);
    drawParticles();
    ctx.restore();
    if (flash > 0) {
      ctx.fillStyle = "rgba(255,255,220," + Math.min(0.3, flash) + ")";
      ctx.fillRect(0, 0, width, height);
    }
  }

  function tick(now) {
    var dt = Math.min(0.033, Math.max(0, (now - lastTime) / 1000));
    lastTime = now;
    if (screen === "racing") updateRace(dt);
    if (screen === "menu") {
      ambientDistance += dt * 44;
      player.steer = Math.sin(now * 0.0008) * 0.12;
      player.x = Math.sin(now * 0.00035) * 0.12;
    }
    if (screen !== "paused") updateParticles(dt);
    shake = Math.max(0, shake - dt * 36);
    flash = Math.max(0, flash - dt);
    draw(now);
    requestAnimationFrame(tick);
  }

  function bindHold(buttonId, key) {
    var button = document.getElementById(buttonId);
    function press(event) {
      event.preventDefault();
      input[key] = true;
      button.classList.add("is-pressed");
      if (button.setPointerCapture && event.pointerId !== undefined) button.setPointerCapture(event.pointerId);
    }
    function release(event) {
      if (event) event.preventDefault();
      input[key] = false;
      button.classList.remove("is-pressed");
    }
    button.addEventListener("pointerdown", press);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("lostpointercapture", release);
  }

  document.querySelectorAll(".cart-card").forEach(function (card) {
    card.addEventListener("click", function () {
      selectedCart = Number(card.getAttribute("data-cart"));
      document.querySelectorAll(".cart-card").forEach(function (item) {
        var selected = item === card;
        item.classList.toggle("is-selected", selected);
        item.setAttribute("aria-checked", selected ? "true" : "false");
      });
      sound.init();
      sound.beep(310 + selectedCart * 90, 0.08, "triangle", 0.08);
    });
  });

  document.getElementById("start-button").addEventListener("click", beginRace);
  document.getElementById("pause-button").addEventListener("click", pauseRace);
  document.getElementById("resume-button").addEventListener("click", resumeRace);
  document.getElementById("restart-from-pause").addEventListener("click", restartRace);
  document.getElementById("race-again-button").addEventListener("click", restartRace);
  document.getElementById("change-cart-button").addEventListener("click", returnToMenu);
  ui.sound.addEventListener("click", function (event) {
    event.stopPropagation();
    sound.toggle();
  });

  bindHold("left-button", "left");
  bindHold("right-button", "right");
  bindHold("boost-button", "boost");

  window.addEventListener("keydown", function (event) {
    if (["ArrowLeft", "ArrowRight", "ArrowUp", " ", "a", "d", "A", "D"].indexOf(event.key) !== -1) event.preventDefault();
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") input.left = true;
    if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") input.right = true;
    if (event.key === "ArrowUp" || event.key === " ") input.boost = true;
    if (event.key === "Escape") {
      if (screen === "paused") resumeRace();
      else pauseRace();
    }
    if (event.key === "Enter" && screen === "menu") beginRace();
  });
  window.addEventListener("keyup", function (event) {
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") input.left = false;
    if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") input.right = false;
    if (event.key === "ArrowUp" || event.key === " ") input.boost = false;
  });
  window.addEventListener("blur", clearInput);
  window.addEventListener("resize", resize);
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) pauseRace();
  });
  shell.addEventListener("contextmenu", function (event) { event.preventDefault(); });

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", function () {
      navigator.serviceWorker.register("/service-worker.js").catch(function () {
        // Offline support is optional when previewing locally.
      });
    });
  }

  resize();
  makeCourse();
  requestAnimationFrame(tick);
})();
