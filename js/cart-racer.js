(function () {
  "use strict";

  var VIEW_WIDTH = 960;
  var VIEW_HEIGHT = 600;
  var TRACK_LEFT = 210;
  var TRACK_WIDTH = 540;
  var TRACK_RIGHT = TRACK_LEFT + TRACK_WIDTH;
  var LANES = 4;
  var LANE_WIDTH = TRACK_WIDTH / LANES;
  var PLAYER_Y = 500;
  var TOTAL_LAPS = 3;
  var LAP_DISTANCE = 5200;

  var canvas = document.getElementById("cart-racer-canvas");
  if (!canvas) {
    return;
  }

  var ctx = canvas.getContext("2d");
  var overlay = document.getElementById("cart-racer-overlay");
  var overlayTitle = document.getElementById("cart-racer-overlay-title");
  var overlayCopy = document.getElementById("cart-racer-overlay-copy");
  var startButton = document.getElementById("cart-racer-start");
  var lapEl = document.getElementById("cart-racer-lap");
  var placeEl = document.getElementById("cart-racer-place");
  var scoreEl = document.getElementById("cart-racer-score");
  var itemEl = document.getElementById("cart-racer-item");
  var leftButton = document.getElementById("cart-racer-left");
  var rightButton = document.getElementById("cart-racer-right");
  var boostButton = document.getElementById("cart-racer-boost");

  var input = {
    left: false,
    right: false,
    boost: false
  };

  var scaleX = 1;
  var scaleY = 1;
  var lastTime = 0;
  var animationFrame = 0;
  var touchStartX = 0;
  var touchStartY = 0;

  var state = createInitialState();

  function createInitialState() {
    return {
      status: "ready",
      distance: 0,
      score: 0,
      collected: 0,
      player: {
        lane: 1,
        x: laneCenter(1),
        targetX: laneCenter(1),
        boostTimer: 0,
        shieldTimer: 0,
        penaltyTimer: 0,
        laneCooldown: 0,
        sparks: 0
      },
      rivals: [
        makeRival("Mint", 0, -180, 0.98, "#22d3ee"),
        makeRival("Grit", 2, -40, 1.02, "#f97316"),
        makeRival("Bolt", 3, -300, 1.05, "#a78bfa")
      ],
      entities: [],
      nextObstacleDistance: 420,
      nextPickupDistance: 760,
      nextDecorDistance: 240
    };
  }

  function makeRival(name, lane, distance, speedFactor, color) {
    return {
      name: name,
      lane: lane,
      x: laneCenter(lane),
      targetX: laneCenter(lane),
      distance: distance,
      speedFactor: speedFactor,
      color: color,
      laneChangeAt: 700 + Math.random() * 900
    };
  }

  function laneCenter(lane) {
    return TRACK_LEFT + LANE_WIDTH * (lane + 0.5);
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function ordinal(value) {
    var suffix = "th";
    if (value % 10 === 1 && value % 100 !== 11) {
      suffix = "st";
    } else if (value % 10 === 2 && value % 100 !== 12) {
      suffix = "nd";
    } else if (value % 10 === 3 && value % 100 !== 13) {
      suffix = "rd";
    }
    return value + suffix;
  }

  function randomLane() {
    return Math.floor(Math.random() * LANES);
  }

  function resizeCanvas() {
    var rect = canvas.getBoundingClientRect();
    var pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    var width = Math.max(320, rect.width || VIEW_WIDTH);
    var height = Math.max(320, rect.height || VIEW_HEIGHT);

    canvas.width = Math.round(width * pixelRatio);
    canvas.height = Math.round(height * pixelRatio);
    scaleX = canvas.width / VIEW_WIDTH;
    scaleY = canvas.height / VIEW_HEIGHT;
  }

  function showOverlay(title, copy, buttonText) {
    overlayTitle.textContent = title;
    overlayCopy.textContent = copy;
    startButton.textContent = buttonText;
    overlay.classList.add("is-visible");
  }

  function hideOverlay() {
    overlay.classList.remove("is-visible");
  }

  function startRace() {
    state = createInitialState();
    state.status = "running";
    lastTime = performance.now();
    hideOverlay();
    updateHud();
    cancelAnimationFrame(animationFrame);
    animationFrame = requestAnimationFrame(loop);
  }

  function finishRace() {
    state.status = "finished";
    var place = getPlace();
    var placeBonus = Math.max(0, (5 - place) * 1200);
    state.score += placeBonus;
    updateHud();
    showOverlay(
      place === 1 ? "Checkout champion!" : "Race complete",
      "You finished " + ordinal(place) + " with " + Math.round(state.score) + " points. Collect more coupons and avoid aisle hazards to climb the cart league.",
      "Race again"
    );
  }

  function loop(time) {
    var dt = Math.min(0.033, (time - lastTime) / 1000 || 0);
    lastTime = time;

    if (state.status === "running") {
      update(dt);
    }

    render();

    if (state.status === "running") {
      animationFrame = requestAnimationFrame(loop);
    }
  }

  function update(dt) {
    var player = state.player;
    var boostActive = player.boostTimer > 0;
    var penaltyActive = player.penaltyTimer > 0;
    var speed = 630;

    if (boostActive) {
      speed += 280;
    }

    if (penaltyActive) {
      speed -= 250;
    }

    player.boostTimer = Math.max(0, player.boostTimer - dt);
    player.shieldTimer = Math.max(0, player.shieldTimer - dt);
    player.penaltyTimer = Math.max(0, player.penaltyTimer - dt);
    player.laneCooldown = Math.max(0, player.laneCooldown - dt);
    player.sparks = Math.max(0, player.sparks - dt);

    handleLaneInput(player);
    player.targetX = laneCenter(player.lane);
    player.x += (player.targetX - player.x) * Math.min(1, dt * 12);

    state.distance += Math.max(240, speed) * dt;
    state.score += Math.max(0, speed * dt * 0.08);

    updateRivals(dt, speed);
    spawnEntities();
    updateEntities();
    checkEntityCollisions();
    checkRivalCollisions();

    if (state.distance >= TOTAL_LAPS * LAP_DISTANCE) {
      finishRace();
    } else {
      updateHud();
    }
  }

  function handleLaneInput(player) {
    if (player.laneCooldown > 0) {
      return;
    }

    if (input.left) {
      changeLane(-1);
    } else if (input.right) {
      changeLane(1);
    }
  }

  function changeLane(direction) {
    var player = state.player;
    var nextLane = clamp(player.lane + direction, 0, LANES - 1);

    if (nextLane !== player.lane) {
      player.lane = nextLane;
      player.laneCooldown = 0.14;
      player.sparks = 0.22;
    }
  }

  function useBoost() {
    if (state.status !== "running") {
      return;
    }

    if (state.player.item === "Coupon Boost") {
      state.player.item = "";
      state.player.boostTimer = 2.25;
      state.score += 250;
      updateHud();
    }
  }

  function updateRivals(dt, playerSpeed) {
    state.rivals.forEach(function (rival, index) {
      var catchUp = rival.distance < state.distance - 260 ? 1.08 : 1;
      var leaderDrag = rival.distance > state.distance + 520 ? 0.94 : 1;
      rival.distance += playerSpeed * rival.speedFactor * catchUp * leaderDrag * dt;
      rival.laneChangeAt -= playerSpeed * dt;

      if (rival.laneChangeAt <= 0) {
        rival.lane = clamp(rival.lane + (Math.random() > 0.5 ? 1 : -1), 0, LANES - 1);
        rival.targetX = laneCenter(rival.lane);
        rival.laneChangeAt = 600 + Math.random() * 1000 + index * 150;
      }

      rival.x += (rival.targetX - rival.x) * Math.min(1, dt * 6);
    });
  }

  function spawnEntities() {
    while (state.nextObstacleDistance < state.distance + 1250) {
      state.entities.push(makeObstacle(state.nextObstacleDistance));
      state.nextObstacleDistance += 360 + Math.random() * 440;
    }

    while (state.nextPickupDistance < state.distance + 1250) {
      state.entities.push(makePickup(state.nextPickupDistance));
      state.nextPickupDistance += 700 + Math.random() * 760;
    }

    while (state.nextDecorDistance < state.distance + 1350) {
      state.entities.push(makeDecor(state.nextDecorDistance));
      state.nextDecorDistance += 210 + Math.random() * 260;
    }
  }

  function makeObstacle(distance) {
    var types = ["spill", "display", "boxes"];
    return {
      kind: "obstacle",
      type: types[Math.floor(Math.random() * types.length)],
      lane: randomLane(),
      distance: distance,
      hit: false
    };
  }

  function makePickup(distance) {
    return {
      kind: "pickup",
      type: Math.random() > 0.72 ? "shield" : "coupon",
      lane: randomLane(),
      distance: distance,
      hit: false
    };
  }

  function makeDecor(distance) {
    var side = Math.random() > 0.5 ? "left" : "right";
    return {
      kind: "decor",
      type: Math.random() > 0.5 ? "freezer" : "shelf",
      side: side,
      x: side === "left" ? 92 + Math.random() * 56 : 812 + Math.random() * 56,
      distance: distance
    };
  }

  function updateEntities() {
    state.entities = state.entities.filter(function (entity) {
      return entity.distance > state.distance - 260;
    });
  }

  function checkEntityCollisions() {
    state.entities.forEach(function (entity) {
      if (entity.hit || entity.kind === "decor") {
        return;
      }

      var distanceDelta = entity.distance - state.distance;
      if (Math.abs(distanceDelta) > 60) {
        return;
      }

      var entityX = laneCenter(entity.lane);
      if (Math.abs(entityX - state.player.x) > LANE_WIDTH * 0.42) {
        return;
      }

      entity.hit = true;

      if (entity.kind === "pickup") {
        collectPickup(entity);
      } else {
        hitObstacle();
      }
    });
  }

  function collectPickup(entity) {
    state.collected += 1;
    state.score += entity.type === "shield" ? 600 : 450;

    if (entity.type === "shield") {
      state.player.shieldTimer = 4.5;
    } else {
      state.player.item = "Coupon Boost";
    }
  }

  function hitObstacle() {
    if (state.player.shieldTimer > 0) {
      state.player.shieldTimer = Math.max(0, state.player.shieldTimer - 1.25);
      state.score += 100;
      return;
    }

    state.player.penaltyTimer = 1.1;
    state.player.sparks = 0.45;
    state.score = Math.max(0, state.score - 350);
  }

  function checkRivalCollisions() {
    state.rivals.forEach(function (rival) {
      var distanceDelta = rival.distance - state.distance;
      if (Math.abs(distanceDelta) < 56 && Math.abs(rival.x - state.player.x) < 48) {
        state.player.penaltyTimer = Math.max(state.player.penaltyTimer, 0.45);
        state.player.sparks = 0.32;
        rival.distance += 80;
      }
    });
  }

  function getPlace() {
    var ahead = state.rivals.filter(function (rival) {
      return rival.distance > state.distance + 40;
    }).length;
    return ahead + 1;
  }

  function updateHud() {
    var lap = clamp(Math.floor(state.distance / LAP_DISTANCE) + 1, 1, TOTAL_LAPS);
    lapEl.textContent = lap + " / " + TOTAL_LAPS;
    placeEl.textContent = ordinal(getPlace());
    scoreEl.textContent = Math.round(state.score).toLocaleString();

    if (state.player.item) {
      itemEl.textContent = state.player.item;
    } else if (state.player.shieldTimer > 0) {
      itemEl.textContent = "Cart Shield";
    } else {
      itemEl.textContent = "None";
    }
  }

  function render() {
    ctx.setTransform(scaleX, 0, 0, scaleY, 0, 0);
    ctx.clearRect(0, 0, VIEW_WIDTH, VIEW_HEIGHT);
    drawStore();
    drawTrack();
    drawEntities();
    drawRivals();
    drawPlayer();
    drawForeground();
  }

  function drawStore() {
    var gradient = ctx.createLinearGradient(0, 0, 0, VIEW_HEIGHT);
    gradient.addColorStop(0, "#172033");
    gradient.addColorStop(1, "#0f172a");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, VIEW_WIDTH, VIEW_HEIGHT);

    drawShelfWall(0, 0, TRACK_LEFT - 26);
    drawShelfWall(TRACK_RIGHT + 26, 0, VIEW_WIDTH - TRACK_RIGHT - 26);
  }

  function drawShelfWall(x, y, width) {
    ctx.fillStyle = "#1e293b";
    ctx.fillRect(x, y, width, VIEW_HEIGHT);

    var offset = (state.distance * 0.28) % 96;
    for (var row = -1; row < 8; row += 1) {
      var shelfY = row * 96 + offset;
      ctx.fillStyle = "#334155";
      ctx.fillRect(x + 12, shelfY, width - 24, 12);

      for (var i = 0; i < 5; i += 1) {
        var boxX = x + 22 + i * Math.max(28, (width - 52) / 5);
        var hue = ["#ef4444", "#facc15", "#22c55e", "#38bdf8", "#a78bfa"][i % 5];
        ctx.fillStyle = hue;
        ctx.fillRect(boxX, shelfY + 18, 20, 34);
      }
    }
  }

  function drawTrack() {
    var trackGradient = ctx.createLinearGradient(TRACK_LEFT, 0, TRACK_RIGHT, 0);
    trackGradient.addColorStop(0, "#334155");
    trackGradient.addColorStop(0.5, "#475569");
    trackGradient.addColorStop(1, "#334155");
    ctx.fillStyle = trackGradient;
    roundRect(TRACK_LEFT, -20, TRACK_WIDTH, VIEW_HEIGHT + 40, 28);
    ctx.fill();

    ctx.strokeStyle = "rgba(255, 255, 255, 0.14)";
    ctx.lineWidth = 4;
    for (var lane = 1; lane < LANES; lane += 1) {
      var x = TRACK_LEFT + lane * LANE_WIDTH;
      drawDashedLine(x, (state.distance * 0.5) % 50);
    }

    ctx.fillStyle = "rgba(250, 204, 21, 0.22)";
    var finishY = PLAYER_Y - ((TOTAL_LAPS * LAP_DISTANCE - state.distance) * 0.42);
    if (finishY > -80 && finishY < VIEW_HEIGHT + 120) {
      for (var tile = 0; tile < 12; tile += 1) {
        ctx.fillStyle = tile % 2 === 0 ? "#f8fafc" : "#111827";
        ctx.fillRect(TRACK_LEFT + tile * 45, finishY, 45, 28);
        ctx.fillStyle = tile % 2 === 0 ? "#111827" : "#f8fafc";
        ctx.fillRect(TRACK_LEFT + tile * 45, finishY + 28, 45, 28);
      }
    }
  }

  function drawDashedLine(x, offset) {
    ctx.beginPath();
    ctx.setLineDash([28, 22]);
    ctx.lineDashOffset = -offset;
    ctx.moveTo(x, -40);
    ctx.lineTo(x, VIEW_HEIGHT + 40);
    ctx.stroke();
    ctx.setLineDash([]);
  }

  function drawEntities() {
    state.entities.forEach(function (entity) {
      var y = worldToScreenY(entity.distance);

      if (y < -100 || y > VIEW_HEIGHT + 120 || entity.hit) {
        return;
      }

      if (entity.kind === "decor") {
        drawDecor(entity, y);
      } else if (entity.kind === "pickup") {
        drawPickup(entity, y);
      } else {
        drawObstacle(entity, y);
      }
    });
  }

  function worldToScreenY(distance) {
    return PLAYER_Y - (distance - state.distance) * 0.42;
  }

  function drawDecor(entity, y) {
    ctx.save();
    ctx.translate(entity.x, y);
    ctx.fillStyle = entity.type === "freezer" ? "#0e7490" : "#7c2d12";
    roundRect(-42, -24, 84, 48, 10);
    ctx.fill();
    ctx.fillStyle = "rgba(255, 255, 255, 0.22)";
    ctx.fillRect(-30, -12, 60, 8);
    ctx.fillRect(-30, 8, 60, 8);
    ctx.restore();
  }

  function drawPickup(entity, y) {
    var x = laneCenter(entity.lane);
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.sin((state.distance + entity.distance) * 0.02) * 0.12);

    if (entity.type === "shield") {
      ctx.fillStyle = "#22d3ee";
      ctx.strokeStyle = "#ecfeff";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(0, -34);
      ctx.lineTo(30, -18);
      ctx.lineTo(22, 28);
      ctx.lineTo(0, 42);
      ctx.lineTo(-22, 28);
      ctx.lineTo(-30, -18);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
    } else {
      ctx.fillStyle = "#facc15";
      ctx.strokeStyle = "#fff7ad";
      ctx.lineWidth = 4;
      roundRect(-34, -22, 68, 44, 10);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#713f12";
      ctx.font = "700 14px Arial";
      ctx.textAlign = "center";
      ctx.fillText("COUPON", 0, 5);
    }

    ctx.restore();
  }

  function drawObstacle(entity, y) {
    var x = laneCenter(entity.lane);
    ctx.save();
    ctx.translate(x, y);

    if (entity.type === "spill") {
      ctx.fillStyle = "#38bdf8";
      ctx.globalAlpha = 0.88;
      ctx.beginPath();
      ctx.ellipse(0, 0, 52, 24, -0.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.fillStyle = "#e0f2fe";
      ctx.beginPath();
      ctx.arc(-12, -4, 5, 0, Math.PI * 2);
      ctx.arc(16, 6, 4, 0, Math.PI * 2);
      ctx.fill();
    } else if (entity.type === "display") {
      ctx.fillStyle = "#dc2626";
      for (var row = 0; row < 3; row += 1) {
        for (var col = 0; col < 3 - row; col += 1) {
          ctx.fillRect((col - (2 - row) / 2) * 25 - 11, row * 21 - 34, 22, 18);
        }
      }
      ctx.fillStyle = "#facc15";
      ctx.fillRect(-44, 30, 88, 12);
    } else {
      ctx.fillStyle = "#a16207";
      roundRect(-38, -30, 76, 60, 8);
      ctx.fill();
      ctx.strokeStyle = "#facc15";
      ctx.lineWidth = 3;
      ctx.strokeRect(-28, -20, 56, 40);
    }

    ctx.restore();
  }

  function drawRivals() {
    state.rivals.forEach(function (rival) {
      var y = worldToScreenY(rival.distance);
      if (y < -90 || y > VIEW_HEIGHT + 115) {
        return;
      }

      drawCart(rival.x, y, rival.color, 0.82, rival.name, false);
    });
  }

  function drawPlayer() {
    var player = state.player;
    var wobble = player.penaltyTimer > 0 ? Math.sin(performance.now() * 0.035) * 7 : 0;
    drawCart(player.x + wobble, PLAYER_Y, "#facc15", 1, "YOU", player.shieldTimer > 0);

    if (player.boostTimer > 0) {
      ctx.fillStyle = "rgba(249, 115, 22, 0.75)";
      ctx.beginPath();
      ctx.moveTo(player.x - 26, PLAYER_Y + 48);
      ctx.lineTo(player.x, PLAYER_Y + 108);
      ctx.lineTo(player.x + 26, PLAYER_Y + 48);
      ctx.fill();
    }

    if (player.sparks > 0) {
      ctx.strokeStyle = "#f97316";
      ctx.lineWidth = 4;
      for (var i = 0; i < 4; i += 1) {
        ctx.beginPath();
        ctx.moveTo(player.x + (i - 1.5) * 16, PLAYER_Y + 34);
        ctx.lineTo(player.x + (i - 1.5) * 26, PLAYER_Y + 58 + i * 3);
        ctx.stroke();
      }
    }
  }

  function drawCart(x, y, color, size, label, shielded) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(size, size);

    if (shielded) {
      ctx.strokeStyle = "rgba(34, 211, 238, 0.82)";
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.ellipse(0, 0, 54, 70, 0, 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.fillStyle = "#0f172a";
    ctx.strokeStyle = "#e2e8f0";
    ctx.lineWidth = 4;
    roundRect(-34, -42, 68, 84, 12);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = color;
    roundRect(-25, -31, 50, 42, 8);
    ctx.fill();

    ctx.strokeStyle = "#94a3b8";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-42, -34);
    ctx.lineTo(-28, -46);
    ctx.lineTo(28, -46);
    ctx.lineTo(42, -34);
    ctx.stroke();

    ctx.fillStyle = "#020617";
    ctx.beginPath();
    ctx.arc(-26, 44, 10, 0, Math.PI * 2);
    ctx.arc(26, 44, 10, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#ffffff";
    ctx.font = "700 13px Arial";
    ctx.textAlign = "center";
    ctx.fillText(label, 0, 4);
    ctx.restore();
  }

  function drawForeground() {
    var lapProgress = (state.distance % LAP_DISTANCE) / LAP_DISTANCE;
    ctx.fillStyle = "rgba(2, 6, 23, 0.55)";
    roundRect(24, 24, 148, 16, 999);
    ctx.fill();
    ctx.fillStyle = "#22d3ee";
    roundRect(24, 24, 148 * lapProgress, 16, 999);
    ctx.fill();

    ctx.fillStyle = "#cbd5e1";
    ctx.font = "700 12px Arial";
    ctx.textAlign = "left";
    ctx.fillText("LAP PROGRESS", 24, 58);

    if (state.status !== "running") {
      return;
    }

    ctx.fillStyle = "rgba(255, 255, 255, 0.12)";
    ctx.fillRect(0, 0, VIEW_WIDTH, 3);
  }

  function roundRect(x, y, width, height, radius) {
    var safeRadius = Math.min(radius, Math.abs(width) / 2, Math.abs(height) / 2);
    ctx.beginPath();
    ctx.moveTo(x + safeRadius, y);
    ctx.lineTo(x + width - safeRadius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + safeRadius);
    ctx.lineTo(x + width, y + height - safeRadius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - safeRadius, y + height);
    ctx.lineTo(x + safeRadius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - safeRadius);
    ctx.lineTo(x, y + safeRadius);
    ctx.quadraticCurveTo(x, y, x + safeRadius, y);
  }

  function bindHoldButton(button, key) {
    if (!button) {
      return;
    }

    button.addEventListener("pointerdown", function (event) {
      event.preventDefault();
      input[key] = true;
      if (key === "left") {
        changeLane(-1);
      } else if (key === "right") {
        changeLane(1);
      }
    });

    ["pointerup", "pointercancel", "pointerleave"].forEach(function (eventName) {
      button.addEventListener(eventName, function () {
        input[key] = false;
      });
    });
  }

  function bindControls() {
    startButton.addEventListener("click", startRace);

    bindHoldButton(leftButton, "left");
    bindHoldButton(rightButton, "right");

    boostButton.addEventListener("click", function (event) {
      event.preventDefault();
      useBoost();
    });

    window.addEventListener("keydown", function (event) {
      if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") {
        input.left = true;
        changeLane(-1);
      } else if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") {
        input.right = true;
        changeLane(1);
      } else if (event.key === " ") {
        event.preventDefault();
        useBoost();
      }
    });

    window.addEventListener("keyup", function (event) {
      if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") {
        input.left = false;
      } else if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") {
        input.right = false;
      }
    });

    canvas.addEventListener("pointerdown", function (event) {
      var point = canvasPoint(event);
      touchStartX = point.x;
      touchStartY = point.y;
    });

    canvas.addEventListener("pointerup", function (event) {
      var point = canvasPoint(event);
      var deltaX = point.x - touchStartX;
      var deltaY = point.y - touchStartY;

      if (Math.abs(deltaX) > Math.max(26, Math.abs(deltaY))) {
        changeLane(deltaX > 0 ? 1 : -1);
      } else if (point.y > VIEW_HEIGHT * 0.55) {
        changeLane(point.x < VIEW_WIDTH / 2 ? -1 : 1);
      } else {
        useBoost();
      }
    });

    window.addEventListener("resize", function () {
      resizeCanvas();
      render();
    });
  }

  function canvasPoint(event) {
    var rect = canvas.getBoundingClientRect();
    return {
      x: ((event.clientX - rect.left) / rect.width) * VIEW_WIDTH,
      y: ((event.clientY - rect.top) / rect.height) * VIEW_HEIGHT
    };
  }

  resizeCanvas();
  bindControls();
  updateHud();
  render();
}());
