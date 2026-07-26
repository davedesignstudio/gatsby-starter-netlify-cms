(function () {
  "use strict";

  var $ = function (selector) { return document.querySelector(selector); };
  var $$ = function (selector) { return Array.prototype.slice.call(document.querySelectorAll(selector)); };

  var screens = {
    menu: $("#menuScreen"),
    select: $("#selectScreen"),
    game: $("#gameScreen"),
    result: $("#resultScreen")
  };

  var canvas = $("#gameCanvas");
  var ctx = canvas.getContext("2d");
  var racerCards = $$(".racer-card");
  var raceMessage = $("#raceMessage");
  var positionValue = $("#positionValue");
  var lapValue = $("#lapValue");
  var timeValue = $("#timeValue");
  var boostFill = $("#boostFill");
  var howModal = $("#howModal");

  var racerConfig = {
    mina: { name: "Mina", color: "#ff5c35", accent: "#efff38", skin: "#b66f48", speed: 420, grip: 1.34 },
    gus: { name: "Gus", color: "#2f5cff", accent: "#ff5c35", skin: "#704a36", speed: 397, grip: 1.66 },
    tori: { name: "Tori", color: "#292824", accent: "#efff38", skin: "#d7956a", speed: 408, grip: 1.5 }
  };

  var state = {
    selectedRacer: "mina",
    muted: false,
    audio: null,
    width: 0,
    height: 0,
    dpr: 1,
    running: false,
    paused: false,
    countdown: 0,
    countdownTone: 4,
    lastTime: 0,
    startTime: 0,
    elapsed: 0,
    playerDistance: 0,
    trackLength: 2600,
    totalDistance: 7800,
    currentLap: 1,
    lapStartedAt: 0,
    lapTimes: [],
    playerX: 0,
    steerVelocity: 0,
    speed: 0,
    boost: 68,
    hitTimer: 0,
    items: 0,
    opponents: [],
    objects: [],
    controls: { left: false, right: false, boost: false },
    animationFrame: 0,
    finishTimer: 0
  };

  function showScreen(name) {
    Object.keys(screens).forEach(function (key) {
      screens[key].classList.toggle("hidden", key !== name);
    });
  }

  function openHow() {
    howModal.classList.remove("hidden");
    $("#closeHowButton").focus();
  }

  function closeHow() {
    howModal.classList.add("hidden");
    $("#howButton").focus();
  }

  function selectRacer(name) {
    if (!racerConfig[name]) return;
    state.selectedRacer = name;
    racerCards.forEach(function (card) {
      var selected = card.dataset.racer === name;
      card.classList.toggle("selected", selected);
      card.setAttribute("aria-checked", selected ? "true" : "false");
    });
  }

  function selectByOffset(offset) {
    var names = racerCards.map(function (card) { return card.dataset.racer; });
    var index = names.indexOf(state.selectedRacer);
    selectRacer(names[(index + offset + names.length) % names.length]);
  }

  function prepareSelect() {
    showScreen("select");
    window.setTimeout(function () {
      var selected = $(".racer-card.selected");
      if (selected) selected.focus();
    }, 20);
  }

  function initAudio() {
    if (state.muted || state.audio) return;
    var AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    state.audio = new AudioContext();
  }

  function tone(frequency, duration, type, volume) {
    if (state.muted) return;
    initAudio();
    if (!state.audio) return;
    if (state.audio.state === "suspended") state.audio.resume();
    var oscillator = state.audio.createOscillator();
    var gain = state.audio.createGain();
    oscillator.type = type || "square";
    oscillator.frequency.setValueAtTime(frequency, state.audio.currentTime);
    gain.gain.setValueAtTime(volume || 0.035, state.audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, state.audio.currentTime + duration);
    oscillator.connect(gain);
    gain.connect(state.audio.destination);
    oscillator.start();
    oscillator.stop(state.audio.currentTime + duration);
  }

  function resizeCanvas() {
    var rect = canvas.getBoundingClientRect();
    state.dpr = Math.min(window.devicePixelRatio || 1, 2);
    state.width = Math.max(320, rect.width);
    state.height = Math.max(260, rect.height);
    canvas.width = Math.floor(state.width * state.dpr);
    canvas.height = Math.floor(state.height * state.dpr);
    ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0);
  }

  function seededLane(index) {
    var lanes = [-0.72, -0.38, 0, 0.38, 0.72];
    return lanes[(index * 7 + 2) % lanes.length];
  }

  function resetRace() {
    var opponents = Object.keys(racerConfig).filter(function (name) {
      return name !== state.selectedRacer;
    });

    state.running = true;
    state.paused = false;
    state.countdown = 3.45;
    state.countdownTone = 4;
    state.lastTime = performance.now();
    state.startTime = 0;
    state.elapsed = 0;
    state.playerDistance = 0;
    state.currentLap = 1;
    state.lapStartedAt = 0;
    state.lapTimes = [];
    state.playerX = 0;
    state.steerVelocity = 0;
    state.speed = 0;
    state.boost = 68;
    state.hitTimer = 0;
    state.items = 0;
    state.controls.left = false;
    state.controls.right = false;
    state.controls.boost = false;
    state.opponents = opponents.map(function (name, index) {
      return {
        name: name,
        distance: 38 + index * 38,
        baseSpeed: index === 0 ? 398 : 407,
        x: index === 0 ? -0.38 : 0.42,
        seed: index * 2.4 + 1
      };
    });
    state.objects = Array.from({ length: 17 }, function (_, index) {
      return {
        type: index % 4 === 1 || index % 7 === 0 ? "pickup" : (index % 3 === 0 ? "spill" : "crate"),
        x: seededLane(index),
        distance: 520 + index * 410 + (index % 3) * 75,
        hit: false,
        spin: index * 0.8
      };
    });

    raceMessage.textContent = "3";
    raceMessage.classList.remove("out");
    $("#pauseButton").classList.remove("paused");
    $("#pauseButton").setAttribute("aria-label", "Pause race");
    updateHud();
  }

  function startRace() {
    initAudio();
    showScreen("game");
    resizeCanvas();
    resetRace();
    cancelAnimationFrame(state.animationFrame);
    state.animationFrame = requestAnimationFrame(gameLoop);
  }

  function formatTime(seconds) {
    var safe = Math.max(0, seconds || 0);
    var minutes = Math.floor(safe / 60);
    var remaining = safe - minutes * 60;
    return String(minutes).padStart(2, "0") + ":" + remaining.toFixed(1).padStart(4, "0");
  }

  function ordinal(value) {
    if (value === 1) return "st";
    if (value === 2) return "nd";
    if (value === 3) return "rd";
    return "th";
  }

  function getPosition() {
    return 1 + state.opponents.filter(function (opponent) {
      return opponent.distance > state.playerDistance;
    }).length;
  }

  function updateHud() {
    var position = getPosition();
    positionValue.innerHTML = position + "<sup>" + ordinal(position) + "</sup>";
    lapValue.textContent = String(Math.min(state.currentLap, 3));
    timeValue.textContent = formatTime(state.elapsed);
    boostFill.style.width = Math.max(0, Math.min(100, state.boost)) + "%";
  }

  function togglePause(forcePause) {
    if (!state.running || state.countdown > 0) return;
    state.paused = typeof forcePause === "boolean" ? forcePause : !state.paused;
    $("#pauseButton").classList.toggle("paused", state.paused);
    $("#pauseButton").setAttribute("aria-label", state.paused ? "Resume race" : "Pause race");
    if (state.paused) {
      raceMessage.textContent = "PAUSED";
      raceMessage.classList.remove("out");
    } else {
      raceMessage.classList.add("out");
      state.lastTime = performance.now();
    }
  }

  function updateCountdown(dt) {
    state.countdown -= dt;
    var number = Math.ceil(state.countdown);
    if (number > 0) {
      raceMessage.textContent = String(number);
      if (number < state.countdownTone) {
        state.countdownTone = number;
        tone(320 + (3 - number) * 80, 0.11, "square", 0.04);
      }
      return;
    }

    if (!state.startTime) {
      state.startTime = performance.now();
      raceMessage.textContent = "GO!";
      tone(660, 0.3, "sawtooth", 0.045);
      window.setTimeout(function () {
        if (state.running && !state.paused) raceMessage.classList.add("out");
      }, 520);
    }
  }

  function updateRace(dt, timestamp) {
    var racer = racerConfig[state.selectedRacer];
    var direction = (state.controls.left ? -1 : 0) + (state.controls.right ? 1 : 0);
    var targetSteer = direction * racer.grip;
    state.steerVelocity += (targetSteer - state.steerVelocity) * Math.min(1, dt * 8);
    state.playerX += state.steerVelocity * dt;
    state.playerX = Math.max(-0.88, Math.min(0.88, state.playerX));

    var boosting = state.controls.boost && state.boost > 0;
    var targetSpeed = racer.speed;
    if (boosting) {
      targetSpeed += 175;
      state.boost = Math.max(0, state.boost - 30 * dt);
    } else {
      state.boost = Math.min(100, state.boost + 2.3 * dt);
    }

    if (state.hitTimer > 0) {
      state.hitTimer -= dt;
      targetSpeed *= 0.48;
    }

    var edgePenalty = Math.max(0, Math.abs(state.playerX) - 0.75) * 1.4;
    targetSpeed *= 1 - edgePenalty;
    state.speed += (targetSpeed - state.speed) * Math.min(1, dt * (state.hitTimer > 0 ? 13 : 2.7));
    state.playerDistance += state.speed * dt;
    state.elapsed = (timestamp - state.startTime) / 1000;

    state.opponents.forEach(function (opponent, index) {
      var variation = Math.sin(state.elapsed * 0.7 + opponent.seed) * 12;
      var catchup = Math.max(-12, Math.min(18, (state.playerDistance - opponent.distance) * 0.012));
      opponent.distance += (opponent.baseSpeed + variation + catchup) * dt;
      opponent.x = Math.sin(state.elapsed * (0.42 + index * 0.08) + opponent.seed) * 0.58;
    });

    checkObjects();
    checkLap();
    updateHud();

    if (state.playerDistance >= state.totalDistance) finishRace();
  }

  function checkObjects() {
    var viewDistance = 3100;
    state.objects.forEach(function (object) {
      var relative = object.distance - state.playerDistance;
      if (relative < -120) {
        object.distance += viewDistance + 250 + Math.random() * 900;
        object.x = seededLane(Math.floor(object.distance / 117));
        object.hit = false;
      }

      if (!object.hit && relative > 0 && relative < 110 && Math.abs(object.x - state.playerX) < 0.2) {
        object.hit = true;
        if (object.type === "pickup") {
          state.boost = Math.min(100, state.boost + 27);
          state.items += 1;
          tone(750, 0.12, "sine", 0.045);
          window.setTimeout(function () { tone(980, 0.09, "sine", 0.025); }, 70);
        } else {
          state.hitTimer = 0.72;
          state.steerVelocity += object.x > state.playerX ? -0.48 : 0.48;
          tone(92, 0.22, "sawtooth", 0.055);
          if (navigator.vibrate) navigator.vibrate(45);
        }
      }
    });
  }

  function checkLap() {
    var lap = Math.min(3, Math.floor(state.playerDistance / state.trackLength) + 1);
    if (lap !== state.currentLap) {
      var lapTime = state.elapsed - state.lapStartedAt;
      state.lapTimes.push(lapTime);
      state.lapStartedAt = state.elapsed;
      state.currentLap = lap;
      tone(590, 0.2, "square", 0.035);
      raceMessage.textContent = "LAP " + lap;
      raceMessage.classList.remove("out");
      window.setTimeout(function () {
        if (state.running && !state.paused) raceMessage.classList.add("out");
      }, 650);
    }
  }

  function finishRace() {
    if (!state.running) return;
    state.running = false;
    state.controls.boost = false;
    state.lapTimes.push(state.elapsed - state.lapStartedAt);
    cancelAnimationFrame(state.animationFrame);
    tone(720, 0.55, "square", 0.04);
    state.finishTimer = window.setTimeout(showResults, 700);
  }

  function showResults() {
    var place = getPosition();
    $("#resultPlace").textContent = String(place);
    $("#finalTime").textContent = formatTime(state.elapsed);
    $("#bestLap").textContent = formatTime(Math.min.apply(Math, state.lapTimes));
    $("#itemsValue").textContent = String(state.items);
    if (place === 1) {
      $("#resultTitle").textContent = "Clean run!";
      $("#resultCopy").textContent = "You owned every corner and took the night shift crown.";
    } else if (place === 2) {
      $("#resultTitle").textContent = "So close!";
      $("#resultCopy").textContent = "One cart got through. The next run is yours to take.";
    } else {
      $("#resultTitle").textContent = "Wild ride!";
      $("#resultCopy").textContent = "You crossed the line with all four wheels. Run it back.";
    }
    showScreen("result");
  }

  function gameLoop(timestamp) {
    var dt = Math.min(0.034, Math.max(0, (timestamp - state.lastTime) / 1000));
    state.lastTime = timestamp;

    if (!state.paused) {
      if (state.countdown > 0) updateCountdown(dt);
      else updateRace(dt, timestamp);
    }

    drawGame(timestamp / 1000);
    if (state.running) state.animationFrame = requestAnimationFrame(gameLoop);
  }

  function lerp(a, b, amount) {
    return a + (b - a) * amount;
  }

  function polygon(points, fill, stroke, lineWidth) {
    ctx.beginPath();
    ctx.moveTo(points[0][0], points[0][1]);
    for (var i = 1; i < points.length; i += 1) ctx.lineTo(points[i][0], points[i][1]);
    ctx.closePath();
    if (fill) {
      ctx.fillStyle = fill;
      ctx.fill();
    }
    if (stroke) {
      ctx.strokeStyle = stroke;
      ctx.lineWidth = lineWidth || 1;
      ctx.stroke();
    }
  }

  function project(relativeDistance, lane) {
    var viewDistance = 3100;
    var progress = 1 - relativeDistance / viewDistance;
    if (progress < 0 || progress > 1.05) return null;
    var eased = progress * progress;
    var horizon = state.height * 0.285;
    var y = horizon + eased * state.height * 0.64;
    var halfWidth = lerp(state.width * 0.075, state.width * 0.425, eased);
    return {
      x: state.width / 2 + lane * halfWidth,
      y: y,
      scale: 0.12 + eased * 1.22,
      progress: progress
    };
  }

  function drawGame(time) {
    ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0);
    ctx.clearRect(0, 0, state.width, state.height);
    drawStore();
    drawTrackDetails();
    drawWorldObjects(time);
    drawSpeedEffect();
    drawPlayer(time);
  }

  function drawStore() {
    var w = state.width;
    var h = state.height;
    var horizon = h * 0.285;
    var leftH = w * 0.425;
    var rightH = w * 0.575;
    var scroll = state.playerDistance;

    var ceiling = ctx.createLinearGradient(0, 0, 0, horizon);
    ceiling.addColorStop(0, "#c8d1ce");
    ceiling.addColorStop(1, "#e2e4dd");
    ctx.fillStyle = ceiling;
    ctx.fillRect(0, 0, w, horizon + 2);

    for (var lightIndex = 0; lightIndex < 7; lightIndex += 1) {
      var lightP = (lightIndex / 7 + (scroll % 1500) / 1500) % 1;
      var lightY = lightP * horizon * 0.9;
      var lightWidth = 28 + lightP * w * 0.13;
      ctx.save();
      ctx.shadowColor = "rgba(255,255,220,.95)";
      ctx.shadowBlur = 18;
      ctx.fillStyle = "#ffffed";
      ctx.fillRect(w / 2 - lightWidth / 2, lightY, lightWidth, 3 + lightP * 7);
      ctx.restore();
    }

    var floor = ctx.createLinearGradient(0, horizon, 0, h);
    floor.addColorStop(0, "#b8bdb7");
    floor.addColorStop(1, "#686e6b");
    polygon([[leftH, horizon], [rightH, horizon], [w * 0.97, h], [w * 0.03, h]], floor);

    polygon([[0, h * 0.08], [leftH, horizon], [w * 0.03, h], [0, h]], "#59615e");
    polygon([[w, h * 0.08], [rightH, horizon], [w * 0.97, h], [w, h]], "#59615e");

    drawShelfSide("left", leftH, horizon, scroll);
    drawShelfSide("right", rightH, horizon, scroll);

    ctx.strokeStyle = "rgba(255,255,255,.12)";
    ctx.lineWidth = 1;
    for (var tile = 1; tile < 9; tile += 1) {
      var tileP = (tile / 9 + (scroll % 700) / 700) % 1;
      var tileEase = tileP * tileP;
      var tileY = horizon + tileEase * (h - horizon);
      var half = lerp(w * 0.075, w * 0.46, tileEase);
      ctx.beginPath();
      ctx.moveTo(w / 2 - half, tileY);
      ctx.lineTo(w / 2 + half, tileY);
      ctx.stroke();
    }

    ctx.strokeStyle = "rgba(255,255,255,.09)";
    [-0.66, -0.33, 0, 0.33, 0.66].forEach(function (lane) {
      ctx.beginPath();
      ctx.moveTo(w / 2 + lane * w * 0.075, horizon);
      ctx.lineTo(w / 2 + lane * w * 0.46, h);
      ctx.stroke();
    });

    drawAisleSign();
  }

  function drawShelfSide(side, horizonX, horizonY, scroll) {
    var w = state.width;
    var h = state.height;
    var isLeft = side === "left";
    var edge = isLeft ? 0 : w;
    var innerBottom = isLeft ? w * 0.03 : w * 0.97;
    var sign = isLeft ? 1 : -1;

    ctx.strokeStyle = "rgba(19,20,18,.58)";
    ctx.lineWidth = 3;
    for (var row = 0; row < 5; row += 1) {
      var rowP = row / 4;
      var rowYEdge = lerp(h * 0.15, h * 0.91, rowP);
      var rowYInner = lerp(horizonY, h * 0.91, rowP);
      ctx.beginPath();
      ctx.moveTo(edge, rowYEdge);
      ctx.lineTo(lerp(horizonX, innerBottom, rowP), rowYInner);
      ctx.stroke();
    }

    var palette = ["#efff38", "#ff5c35", "#2f5cff", "#e9e4d7", "#242522"];
    for (var shelfIndex = 0; shelfIndex < 11; shelfIndex += 1) {
      var p = (shelfIndex / 11 + (scroll % 950) / 950) % 1;
      var eased = p * p;
      var x = lerp(horizonX, innerBottom, eased);
      var outerX = lerp(isLeft ? w * 0.25 : w * 0.75, edge, eased);
      var y = horizonY + eased * h * 0.62;
      var boxW = 6 + eased * 44;
      var boxH = 8 + eased * 65;
      var center = lerp(x, outerX, 0.46);
      ctx.fillStyle = palette[(shelfIndex * 3) % palette.length];
      ctx.fillRect(center - (isLeft ? boxW : 0), y - boxH, boxW, boxH);
      ctx.fillStyle = "rgba(0,0,0,.17)";
      ctx.fillRect(center - (isLeft ? boxW : 0), y - boxH * 0.5, boxW, Math.max(1, boxH * 0.08));
      ctx.strokeStyle = "rgba(15,15,13,.45)";
      ctx.lineWidth = Math.max(0.5, eased * 2);
      ctx.strokeRect(center - (isLeft ? boxW : 0), y - boxH, boxW, boxH);
    }

    ctx.strokeStyle = "#252824";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(horizonX, horizonY);
    ctx.lineTo(innerBottom, h);
    ctx.stroke();

    ctx.fillStyle = "#242623";
    ctx.fillRect(isLeft ? 0 : w - 7, h * 0.1, 7, h * 0.9);
    ctx.translate(0, sign * 0);
  }

  function drawAisleSign() {
    var w = state.width;
    var h = state.height;
    var signW = Math.max(38, Math.min(70, w * 0.055));
    var signH = signW * 0.85;
    var x = w * 0.67;
    var y = h * 0.115;
    ctx.fillStyle = "#282b27";
    ctx.fillRect(x + signW / 2 - 1, 0, 2, y);
    ctx.fillStyle = "#2f5cff";
    ctx.fillRect(x, y, signW, signH);
    ctx.fillStyle = "white";
    ctx.textAlign = "center";
    ctx.font = "800 " + Math.max(6, signW * 0.1) + "px Arial";
    ctx.fillText("AISLE", x + signW / 2, y + signH * 0.25);
    ctx.font = "900 " + signW * 0.48 + "px Impact, sans-serif";
    ctx.fillText("07", x + signW / 2, y + signH * 0.78);
  }

  function drawTrackDetails() {
    var w = state.width;
    var distanceToLine = state.trackLength - (state.playerDistance % state.trackLength);
    if (distanceToLine < 3100) {
      var line = project(distanceToLine, 0);
      if (line) {
        var roadHalf = lerp(w * 0.075, w * 0.425, line.progress * line.progress);
        var tileWidth = roadHalf * 2 / 10;
        for (var i = 0; i < 10; i += 1) {
          ctx.fillStyle = i % 2 ? "#f0ede3" : "#171715";
          ctx.fillRect(w / 2 - roadHalf + i * tileWidth, line.y, tileWidth + 1, Math.max(2, 16 * line.scale));
        }
      }
    }

    for (var markerIndex = 0; markerIndex < 7; markerIndex += 1) {
      var markerDistance = ((markerIndex * 520 - state.playerDistance) % 3500 + 3500) % 3500;
      var marker = project(markerDistance, 0);
      if (!marker) continue;
      ctx.save();
      ctx.globalAlpha = 0.24 + marker.progress * 0.4;
      ctx.fillStyle = markerIndex % 2 ? "#efff38" : "#f2eee4";
      var mw = 8 * marker.scale;
      var mh = 35 * marker.scale;
      ctx.translate(marker.x, marker.y);
      ctx.transform(1, 0, -0.16, 1, 0, 0);
      ctx.fillRect(-mw / 2, -mh, mw, mh);
      ctx.restore();
    }
  }

  function drawWorldObjects(time) {
    var drawables = [];
    state.objects.forEach(function (object) {
      if (object.hit) return;
      var relative = object.distance - state.playerDistance;
      if (relative > 20 && relative < 3100) drawables.push({ kind: object.type, data: object, z: relative });
    });
    state.opponents.forEach(function (opponent) {
      var relative = opponent.distance - state.playerDistance;
      if (relative > 45 && relative < 3100) drawables.push({ kind: "opponent", data: opponent, z: relative });
    });
    drawables.sort(function (a, b) { return b.z - a.z; });

    drawables.forEach(function (drawable) {
      var point = project(drawable.z, drawable.data.x);
      if (!point) return;
      if (drawable.kind === "pickup") drawPickup(point, drawable.data.spin + time);
      else if (drawable.kind === "spill") drawSpill(point);
      else if (drawable.kind === "crate") drawCrate(point);
      else drawCart(point.x, point.y, point.scale * 0.72, racerConfig[drawable.data.name], Math.sin(time * 2 + drawable.data.seed) * 0.03, false);
    });
  }

  function drawPickup(point, spin) {
    var size = 31 * point.scale;
    ctx.save();
    ctx.translate(point.x, point.y - size * 0.8);
    ctx.rotate(Math.sin(spin * 2.2) * 0.17);
    ctx.shadowColor = "#efff38";
    ctx.shadowBlur = 18 * point.scale;
    ctx.fillStyle = "#efff38";
    ctx.fillRect(-size * 0.55, -size * 0.8, size * 1.1, size * 1.25);
    ctx.strokeStyle = "#11110f";
    ctx.lineWidth = Math.max(1, 2.5 * point.scale);
    ctx.strokeRect(-size * 0.55, -size * 0.8, size * 1.1, size * 1.25);
    ctx.fillStyle = "#11110f";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = "900 " + Math.max(7, size * 0.58) + "px Arial";
    ctx.fillText("★", 0, -size * 0.15);
    ctx.restore();
  }

  function drawSpill(point) {
    var size = 45 * point.scale;
    ctx.save();
    ctx.translate(point.x, point.y);
    ctx.scale(1.55, 0.45);
    ctx.fillStyle = "rgba(239,255,56,.82)";
    ctx.beginPath();
    for (var i = 0; i < 12; i += 1) {
      var radius = i % 2 ? size * 0.58 : size;
      var angle = i / 12 * Math.PI * 2;
      var x = Math.cos(angle) * radius;
      var y = Math.sin(angle) * radius;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawCrate(point) {
    var size = 39 * point.scale;
    ctx.save();
    ctx.translate(point.x, point.y - size * 0.7);
    ctx.fillStyle = "#ff5c35";
    ctx.fillRect(-size, -size, size * 2, size * 1.35);
    ctx.strokeStyle = "#161613";
    ctx.lineWidth = Math.max(1, 3 * point.scale);
    ctx.strokeRect(-size, -size, size * 2, size * 1.35);
    ctx.beginPath();
    ctx.moveTo(-size, -size);
    ctx.lineTo(size, size * 0.35);
    ctx.moveTo(size, -size);
    ctx.lineTo(-size, size * 0.35);
    ctx.stroke();
    ctx.restore();
  }

  function drawSpeedEffect() {
    if (!(state.controls.boost && state.boost > 0 && state.countdown <= 0)) return;
    var w = state.width;
    var h = state.height;
    ctx.save();
    ctx.strokeStyle = "rgba(239,255,56,.65)";
    ctx.lineWidth = 2;
    for (var i = 0; i < 16; i += 1) {
      var side = i % 2 ? 1 : -1;
      var y = ((i * 83 + state.playerDistance * 2) % h);
      var x = w / 2 + side * (w * 0.18 + (i % 5) * w * 0.055);
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + side * 35, y + 85);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawPlayer(time) {
    var x = state.width / 2 + state.playerX * state.width * 0.31;
    var y = state.height * 0.88;
    var baseScale = Math.max(0.78, Math.min(1.28, state.width / 950));
    var bounce = Math.sin(time * Math.max(7, state.speed * 0.035)) * 1.6;
    var tilt = -state.steerVelocity * 0.13;
    drawCart(x, y + bounce, baseScale, racerConfig[state.selectedRacer], tilt, true);
  }

  function drawCart(x, y, scale, config, tilt, isPlayer) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(tilt);
    ctx.scale(scale, scale);

    ctx.fillStyle = "rgba(0,0,0,.28)";
    ctx.beginPath();
    ctx.ellipse(0, 20, 88, 19, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#1b1c19";
    ctx.beginPath();
    ctx.arc(-56, 12, 16, 0, Math.PI * 2);
    ctx.arc(57, 12, 16, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#a7aba5";
    ctx.beginPath();
    ctx.arc(-56, 12, 7, 0, Math.PI * 2);
    ctx.arc(57, 12, 7, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = config.color;
    polygon([[-83, -65], [84, -65], [69, 2], [-67, 2]], config.color, "#171714", 5);
    ctx.strokeStyle = "rgba(255,255,255,.55)";
    ctx.lineWidth = 2;
    for (var line = -50; line <= 50; line += 25) {
      ctx.beginPath();
      ctx.moveTo(line, -60);
      ctx.lineTo(line * 0.82, -2);
      ctx.stroke();
    }
    for (var row = -46; row <= -12; row += 17) {
      ctx.beginPath();
      ctx.moveTo(-75, row);
      ctx.lineTo(76, row);
      ctx.stroke();
    }

    ctx.strokeStyle = "#171714";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(-81, -60);
    ctx.lineTo(-106, -105);
    ctx.lineTo(-145, -105);
    ctx.stroke();
    ctx.strokeStyle = config.accent;
    ctx.lineWidth = 10;
    ctx.beginPath();
    ctx.moveTo(-145, -105);
    ctx.lineTo(-102, -105);
    ctx.stroke();

    ctx.fillStyle = config.color;
    ctx.beginPath();
    ctx.ellipse(0, -89, 47, 44, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#171714";
    ctx.lineWidth = 5;
    ctx.stroke();

    ctx.fillStyle = config.skin;
    ctx.beginPath();
    ctx.ellipse(0, -133, 29, 34, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = config.accent;
    ctx.beginPath();
    ctx.ellipse(-2, -156, 31, 13, -0.08, Math.PI, Math.PI * 2);
    ctx.lineTo(32, -148);
    ctx.lineTo(7, -144);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = "#171714";
    ctx.beginPath();
    ctx.arc(-10, -135, 2.8, 0, Math.PI * 2);
    ctx.arc(10, -135, 2.8, 0, Math.PI * 2);
    ctx.fill();

    if (isPlayer) {
      ctx.fillStyle = config.accent;
      ctx.fillRect(55, -57, 29, 29);
      ctx.fillStyle = "#171714";
      ctx.textAlign = "center";
      ctx.font = "18px Impact, sans-serif";
      ctx.fillText("07", 69, -35);
    }
    ctx.restore();
  }

  function setControl(control, active, button) {
    state.controls[control] = active;
    if (button) button.classList.toggle("pressed", active);
  }

  function bindHold(button, control) {
    var release = function (event) {
      if (event) event.preventDefault();
      setControl(control, false, button);
    };
    button.addEventListener("pointerdown", function (event) {
      event.preventDefault();
      button.setPointerCapture(event.pointerId);
      setControl(control, true, button);
      if (control === "boost" && state.boost > 3) tone(145, 0.12, "sawtooth", 0.02);
    });
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("lostpointercapture", release);
  }

  $("#raceButton").addEventListener("click", prepareSelect);
  $("#selectBackButton").addEventListener("click", function () { showScreen("menu"); });
  $("#startButton").addEventListener("click", startRace);
  $("#retryButton").addEventListener("click", startRace);
  $("#changeButton").addEventListener("click", prepareSelect);
  $("#pauseButton").addEventListener("click", function () { togglePause(); });
  $("#howButton").addEventListener("click", openHow);
  $("#closeHowButton").addEventListener("click", closeHow);
  $("#gotItButton").addEventListener("click", closeHow);

  $("#soundButton").addEventListener("click", function () {
    state.muted = !state.muted;
    this.setAttribute("aria-pressed", state.muted ? "true" : "false");
    this.setAttribute("aria-label", state.muted ? "Turn sound on" : "Mute sound");
    if (!state.muted) tone(520, 0.08, "sine", 0.03);
  });

  racerCards.forEach(function (card) {
    card.addEventListener("click", function () { selectRacer(card.dataset.racer); });
    card.addEventListener("dblclick", startRace);
  });

  bindHold($("#leftButton"), "left");
  bindHold($("#rightButton"), "right");
  bindHold($("#boostButton"), "boost");

  document.addEventListener("keydown", function (event) {
    if (!howModal.classList.contains("hidden")) {
      if (event.key === "Escape") closeHow();
      return;
    }

    if (!screens.select.classList.contains("hidden")) {
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        selectByOffset(-1);
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        selectByOffset(1);
      } else if (event.key === "Enter") {
        event.preventDefault();
        startRace();
      }
      return;
    }

    if (screens.game.classList.contains("hidden")) return;
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") {
      event.preventDefault();
      setControl("left", true, $("#leftButton"));
    }
    if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") {
      event.preventDefault();
      setControl("right", true, $("#rightButton"));
    }
    if (event.code === "Space" || event.key === "ArrowUp") {
      event.preventDefault();
      setControl("boost", true, $("#boostButton"));
    }
    if (event.key === "Escape" || event.key.toLowerCase() === "p") togglePause();
  });

  document.addEventListener("keyup", function (event) {
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") setControl("left", false, $("#leftButton"));
    if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") setControl("right", false, $("#rightButton"));
    if (event.code === "Space" || event.key === "ArrowUp") setControl("boost", false, $("#boostButton"));
  });

  document.addEventListener("visibilitychange", function () {
    if (document.hidden && state.running && !state.paused && state.countdown <= 0) togglePause(true);
  });

  window.addEventListener("resize", function () {
    if (!screens.game.classList.contains("hidden")) resizeCanvas();
  });

  document.addEventListener("contextmenu", function (event) {
    if (!screens.game.classList.contains("hidden")) event.preventDefault();
  });

  if ("serviceWorker" in navigator && window.location.protocol !== "file:") {
    window.addEventListener("load", function () {
      navigator.serviceWorker.register("sw.js").catch(function () {
        // The game remains fully playable when service workers are unavailable.
      });
    });
  }
}());
