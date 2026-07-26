(function() {
  "use strict";

  var canvas = document.getElementById("cart-racer");
  if (!canvas) {
    return;
  }

  var ctx = canvas.getContext("2d");
  var startOverlay = document.getElementById("cart-game-start");
  var initialOverlayHtml = startOverlay ? startOverlay.innerHTML : "";
  var resetButton = document.getElementById("cart-game-reset");
  var controlButtons = document.querySelectorAll("[data-control]");
  var WIDTH = 960;
  var HEIGHT = 540;
  var ROAD_LEFT = 155;
  var ROAD_RIGHT = 805;
  var PLAYER_Y = 425;
  var departments = [
    { name: "Produce", at: 4200 },
    { name: "Bakery", at: 9300 },
    { name: "Frozen", at: 15000 }
  ];
  var keys = {};
  var touchControls = { left: false, right: false, boost: false };
  var pointerTarget = null;
  var lastFrame = 0;
  var game;

  function resetGame() {
    game = {
      state: "ready",
      distance: 0,
      score: 0,
      combo: 1,
      comboTimer: 0,
      boost: 42,
      boostActive: 0,
      timeLeft: 88,
      departmentIndex: 0,
      spawnObstacleIn: 0.45,
      spawnCouponIn: 1.1,
      spawnRivalIn: 2.4,
      message: "Tap Start Race",
      messageTimer: 0,
      cameraShake: 0,
      player: {
        x: WIDTH / 2,
        y: PLAYER_Y,
        vx: 0,
        width: 48,
        height: 74,
        hitCooldown: 0
      },
      obstacles: [],
      coupons: [],
      rivals: [],
      particles: []
    };
    if (startOverlay) {
      startOverlay.innerHTML = initialOverlayHtml;
      startOverlay.classList.remove("is-hidden");
      bindStartButton();
    }
  }

  function startGame() {
    resetGame();
    game.state = "running";
    game.message = "Go!";
    game.messageTimer = 1.1;
    if (startOverlay) {
      startOverlay.classList.add("is-hidden");
    }
  }

  function finishGame(won) {
    game.state = "finished";
    game.message = won ? "Checklist complete!" : "Store closed!";
    game.messageTimer = 999;
    if (startOverlay) {
      startOverlay.classList.remove("is-hidden");
      startOverlay.innerHTML =
        "<div><h2>" + (won ? "Run complete!" : "Race over") + "</h2>" +
        "<p>Score: " + Math.floor(game.score) + " - Distance: " +
        Math.floor(game.distance) + " ft - Combo: x" + game.combo.toFixed(1) +
        "</p><button class=\"cart-game-button\" id=\"cart-game-start-button\" type=\"button\">Race again</button></div>";
      bindStartButton();
    }
  }

  function bindStartButton() {
    var button = document.getElementById("cart-game-start-button");
    if (button) {
      button.addEventListener("click", startGame);
    }
  }

  function resizeCanvas() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = WIDTH * dpr;
    canvas.height = HEIGHT * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function rand(min, max) {
    return min + Math.random() * (max - min);
  }

  function choose(items) {
    return items[Math.floor(Math.random() * items.length)];
  }

  function baseSpeed() {
    var progressSpeed = 250 + Math.min(game.distance / 10, 115);
    return game.boostActive > 0 ? progressSpeed * 1.42 : progressSpeed;
  }

  function spawnObstacle() {
    var kind = choose(["spill", "display", "cones", "mop"]);
    var width = kind === "display" ? 76 : 58;
    var height = kind === "mop" ? 92 : 44;
    game.obstacles.push({
      kind: kind,
      x: rand(ROAD_LEFT + 55, ROAD_RIGHT - 55),
      y: -height,
      width: width,
      height: height,
      sway: rand(-1.5, 1.5)
    });
  }

  function spawnCoupon() {
    game.coupons.push({
      x: rand(ROAD_LEFT + 45, ROAD_RIGHT - 45),
      y: -34,
      width: 34,
      height: 24,
      spin: rand(0, Math.PI * 2)
    });
  }

  function spawnRival() {
    game.rivals.push({
      x: rand(ROAD_LEFT + 55, ROAD_RIGHT - 55),
      y: -82,
      width: 48,
      height: 72,
      color: choose(["#d95a45", "#5bb4ff", "#78d66f"]),
      wobble: rand(0, Math.PI * 2)
    });
  }

  function rectsOverlap(a, b) {
    return Math.abs(a.x - b.x) * 2 < (a.width + b.width) &&
      Math.abs(a.y - b.y) * 2 < (a.height + b.height);
  }

  function playerRect() {
    return {
      x: game.player.x,
      y: game.player.y,
      width: game.player.width * 0.72,
      height: game.player.height * 0.72
    };
  }

  function addParticles(x, y, color, count) {
    for (var i = 0; i < count; i += 1) {
      game.particles.push({
        x: x,
        y: y,
        vx: rand(-135, 135),
        vy: rand(-160, 60),
        life: rand(0.28, 0.75),
        color: color
      });
    }
  }

  function hitHazard() {
    if (game.player.hitCooldown > 0) {
      return;
    }

    game.player.hitCooldown = 1.15;
    game.combo = 1;
    game.boost = Math.max(0, game.boost - 18);
    game.score = Math.max(0, game.score - 75);
    game.cameraShake = 0.35;
    game.message = "Cleanup in aisle " + Math.floor(rand(2, 14)) + "!";
    game.messageTimer = 1.25;
    game.player.vx += game.player.x < WIDTH / 2 ? 260 : -260;
    addParticles(game.player.x, game.player.y, "#ff6b57", 16);
  }

  function collectCoupon(coupon) {
    coupon.collected = true;
    game.boost = Math.min(100, game.boost + 22);
    game.combo = Math.min(5, game.combo + 0.25);
    game.comboTimer = 3.2;
    game.score += 120 * game.combo;
    game.message = "Coupon boost!";
    game.messageTimer = 0.75;
    addParticles(coupon.x, coupon.y, "#edb713", 14);
  }

  function update(dt) {
    if (game.state !== "running") {
      return;
    }

    var speed = baseSpeed();
    var steering = 0;
    var player = game.player;

    if (keys.ArrowLeft || keys.a || touchControls.left) {
      steering -= 1;
    }
    if (keys.ArrowRight || keys.d || touchControls.right) {
      steering += 1;
    }

    if (pointerTarget !== null) {
      player.vx += (pointerTarget - player.x) * 7.5 * dt;
    } else {
      player.vx += steering * 1180 * dt;
    }

    if ((keys[" "] || touchControls.boost) && game.boost > 0) {
      game.boostActive = 0.18;
      game.boost = Math.max(0, game.boost - 34 * dt);
    }

    player.vx *= Math.pow(0.02, dt);
    player.x += player.vx * dt;
    if (player.x < ROAD_LEFT + 35) {
      player.x = ROAD_LEFT + 35;
      player.vx *= -0.2;
    }
    if (player.x > ROAD_RIGHT - 35) {
      player.x = ROAD_RIGHT - 35;
      player.vx *= -0.2;
    }

    game.boostActive = Math.max(0, game.boostActive - dt);
    player.hitCooldown = Math.max(0, player.hitCooldown - dt);
    game.cameraShake = Math.max(0, game.cameraShake - dt);
    game.timeLeft -= dt;
    game.distance += speed * dt;
    game.score += (speed * dt * 0.18) * game.combo;

    if (game.comboTimer > 0) {
      game.comboTimer -= dt;
    } else {
      game.combo = Math.max(1, game.combo - dt * 0.2);
    }

    if (game.messageTimer > 0) {
      game.messageTimer -= dt;
    }

    while (
      game.departmentIndex < departments.length &&
      game.distance >= departments[game.departmentIndex].at
    ) {
      game.message = departments[game.departmentIndex].name + " cleared!";
      game.messageTimer = 1.5;
      game.score += 500 * game.combo;
      game.boost = Math.min(100, game.boost + 30);
      game.departmentIndex += 1;
    }

    game.spawnObstacleIn -= dt;
    game.spawnCouponIn -= dt;
    game.spawnRivalIn -= dt;

    if (game.spawnObstacleIn <= 0) {
      spawnObstacle();
      game.spawnObstacleIn = rand(0.38, Math.max(0.82, 1.25 - game.distance / 3200));
    }
    if (game.spawnCouponIn <= 0) {
      spawnCoupon();
      game.spawnCouponIn = rand(0.85, 1.7);
    }
    if (game.spawnRivalIn <= 0) {
      spawnRival();
      game.spawnRivalIn = rand(1.8, 3.4);
    }

    moveObjects(game.obstacles, speed, dt, function(item) {
      item.x += Math.sin((game.distance / 90) + item.sway) * 18 * dt;
    });
    moveObjects(game.coupons, speed, dt, function(item) {
      item.spin += dt * 8;
    });
    moveObjects(game.rivals, speed * 0.88, dt, function(item) {
      item.wobble += dt * 3.4;
      item.x += Math.sin(item.wobble) * 36 * dt;
    });

    var pRect = playerRect();
    game.obstacles.forEach(function(obstacle) {
      if (!obstacle.hit && rectsOverlap(pRect, obstacle)) {
        obstacle.hit = true;
        hitHazard();
      }
    });
    game.rivals.forEach(function(rival) {
      if (!rival.hit && rectsOverlap(pRect, rival)) {
        rival.hit = true;
        hitHazard();
      }
    });
    game.coupons.forEach(function(coupon) {
      if (!coupon.collected && rectsOverlap(pRect, coupon)) {
        collectCoupon(coupon);
      }
    });

    game.obstacles = game.obstacles.filter(isVisible);
    game.rivals = game.rivals.filter(isVisible);
    game.coupons = game.coupons.filter(function(item) {
      return !item.collected && isVisible(item);
    });

    game.particles.forEach(function(particle) {
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vy += 420 * dt;
      particle.life -= dt;
    });
    game.particles = game.particles.filter(function(particle) {
      return particle.life > 0;
    });

    if (game.departmentIndex >= departments.length) {
      finishGame(true);
    } else if (game.timeLeft <= 0) {
      finishGame(false);
    }
  }

  function moveObjects(items, speed, dt, extraUpdate) {
    items.forEach(function(item) {
      item.y += speed * dt;
      extraUpdate(item);
    });
  }

  function isVisible(item) {
    return item.y < HEIGHT + 100;
  }

  function draw() {
    var shakeX = game.cameraShake > 0 ? rand(-5, 5) : 0;
    var shakeY = game.cameraShake > 0 ? rand(-3, 3) : 0;

    ctx.save();
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    ctx.translate(shakeX, shakeY);
    drawStore();
    drawTrack();
    game.coupons.forEach(drawCoupon);
    game.obstacles.forEach(drawObstacle);
    game.rivals.forEach(drawRival);
    drawPlayer();
    game.particles.forEach(drawParticle);
    drawHud();
    ctx.restore();
  }

  function drawStore() {
    var shelfWidth = 112;
    var scroll = game ? game.distance % 90 : 0;
    ctx.fillStyle = "#14202a";
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    ctx.fillStyle = "#1d2d39";
    ctx.fillRect(0, 0, shelfWidth, HEIGHT);
    ctx.fillRect(WIDTH - shelfWidth, 0, shelfWidth, HEIGHT);

    for (var y = -90 + scroll; y < HEIGHT + 90; y += 90) {
      drawShelfBox(20, y, "#6dc27a", "Veg");
      drawShelfBox(WIDTH - 92, y + 18, "#8bd7ff", "Milk");
      drawShelfBox(48, y + 45, "#edb713", "Soup");
      drawShelfBox(WIDTH - 118, y + 62, "#ff835c", "Chips");
    }
  }

  function drawShelfBox(x, y, color, label) {
    ctx.fillStyle = color;
    ctx.fillRect(x, y, 58, 28);
    ctx.fillStyle = "rgba(0, 0, 0, 0.22)";
    ctx.fillRect(x, y + 20, 58, 8);
    ctx.fillStyle = "#ffffff";
    ctx.font = "10px Arial";
    ctx.fillText(label, x + 7, y + 17);
  }

  function drawTrack() {
    var scroll = game.distance % 74;
    var gradient = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    gradient.addColorStop(0, "#33414b");
    gradient.addColorStop(1, "#202b33");
    ctx.fillStyle = gradient;
    roundedRect(ROAD_LEFT, -20, ROAD_RIGHT - ROAD_LEFT, HEIGHT + 40, 26);
    ctx.fill();

    ctx.strokeStyle = "rgba(255, 255, 255, 0.14)";
    ctx.lineWidth = 3;
    for (var lane = ROAD_LEFT + 130; lane < ROAD_RIGHT; lane += 130) {
      ctx.setLineDash([28, 26]);
      ctx.lineDashOffset = scroll;
      ctx.beginPath();
      ctx.moveTo(lane, -20);
      ctx.lineTo(lane, HEIGHT + 20);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    ctx.fillStyle = "rgba(237, 183, 19, 0.16)";
    for (var y = -74 + scroll; y < HEIGHT + 80; y += 74) {
      ctx.fillRect(ROAD_LEFT + 14, y, 10, 38);
      ctx.fillRect(ROAD_RIGHT - 24, y + 18, 10, 38);
    }
  }

  function drawPlayer() {
    var p = game.player;
    var tilt = Math.max(-0.25, Math.min(0.25, p.vx / 900));
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(tilt);
    if (game.boostActive > 0) {
      ctx.fillStyle = "rgba(237, 183, 19, 0.45)";
      ctx.beginPath();
      ctx.moveTo(-22, 38);
      ctx.lineTo(0, 85 + Math.sin(game.distance / 12) * 9);
      ctx.lineTo(22, 38);
      ctx.fill();
    }
    drawCartBody("#f6f8fb", "#edb713", p.hitCooldown > 0);
    ctx.restore();
  }

  function drawRival(rival) {
    ctx.save();
    ctx.translate(rival.x, rival.y);
    ctx.rotate(Math.sin(rival.wobble) * 0.08);
    drawCartBody("#dfe7ec", rival.color, false);
    ctx.restore();
  }

  function drawCartBody(frameColor, basketColor, flicker) {
    ctx.globalAlpha = flicker ? 0.58 + Math.sin(Date.now() / 45) * 0.28 : 1;
    ctx.strokeStyle = frameColor;
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-24, -24);
    ctx.lineTo(22, -16);
    ctx.lineTo(16, 24);
    ctx.lineTo(-18, 28);
    ctx.closePath();
    ctx.stroke();

    ctx.fillStyle = basketColor;
    roundedRect(-21, -30, 42, 48, 7);
    ctx.fill();
    ctx.strokeStyle = "rgba(0, 0, 0, 0.26)";
    ctx.lineWidth = 2;
    for (var x = -12; x <= 12; x += 12) {
      ctx.beginPath();
      ctx.moveTo(x, -27);
      ctx.lineTo(x - 2, 14);
      ctx.stroke();
    }

    ctx.fillStyle = "#101820";
    ctx.beginPath();
    ctx.arc(-21, 30, 6, 0, Math.PI * 2);
    ctx.arc(20, 28, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawObstacle(obstacle) {
    ctx.save();
    ctx.translate(obstacle.x, obstacle.y);
    if (obstacle.kind === "spill") {
      ctx.fillStyle = "#60d5ff";
      ctx.beginPath();
      ctx.ellipse(0, 0, obstacle.width / 2, obstacle.height / 2, -0.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.55)";
      ctx.beginPath();
      ctx.arc(13, -6, 5, 0, Math.PI * 2);
      ctx.fill();
    } else if (obstacle.kind === "display") {
      ctx.fillStyle = "#b5563b";
      roundedRect(-38, -24, 76, 48, 5);
      ctx.fill();
      ctx.fillStyle = "#ffd363";
      ctx.fillRect(-28, -13, 56, 10);
      ctx.fillRect(-28, 6, 56, 10);
    } else if (obstacle.kind === "mop") {
      ctx.strokeStyle = "#d8c6a3";
      ctx.lineWidth = 8;
      ctx.beginPath();
      ctx.moveTo(-28, -42);
      ctx.lineTo(24, 42);
      ctx.stroke();
      ctx.fillStyle = "#94d5ff";
      ctx.fillRect(12, 26, 28, 16);
    } else {
      ctx.fillStyle = "#ff8a2a";
      drawCone(-18, 5);
      drawCone(18, -4);
    }
    ctx.restore();
  }

  function drawCone(x, y) {
    ctx.fillStyle = "#ff8a2a";
    ctx.beginPath();
    ctx.moveTo(x, y - 20);
    ctx.lineTo(x - 16, y + 18);
    ctx.lineTo(x + 16, y + 18);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,0.7)";
    ctx.fillRect(x - 10, y + 2, 20, 5);
  }

  function drawCoupon(coupon) {
    var pulse = Math.sin(coupon.spin) * 0.18 + 1;
    ctx.save();
    ctx.translate(coupon.x, coupon.y);
    ctx.scale(pulse, 1);
    ctx.fillStyle = "#edb713";
    roundedRect(-19, -13, 38, 26, 5);
    ctx.fill();
    ctx.fillStyle = "#101820";
    ctx.font = "bold 12px Arial";
    ctx.textAlign = "center";
    ctx.fillText("$", 0, 5);
    ctx.textAlign = "left";
    ctx.restore();
  }

  function drawParticle(particle) {
    ctx.globalAlpha = Math.max(0, particle.life);
    ctx.fillStyle = particle.color;
    ctx.beginPath();
    ctx.arc(particle.x, particle.y, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawHud() {
    var nextDept = departments[game.departmentIndex];
    var previousDeptAt = game.departmentIndex === 0 ? 0 : departments[game.departmentIndex - 1].at;
    var progress = nextDept ?
      Math.min(1, (game.distance - previousDeptAt) / (nextDept.at - previousDeptAt)) :
      1;

    ctx.fillStyle = "rgba(5, 11, 17, 0.72)";
    roundedRect(22, 18, 310, 112, 16);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 22px Arial";
    ctx.fillText("Cart Dash", 42, 51);
    ctx.font = "15px Arial";
    ctx.fillStyle = "#dce8ef";
    ctx.fillText("Score " + Math.floor(game.score), 42, 79);
    ctx.fillText("Time " + Math.max(0, Math.ceil(game.timeLeft)) + "s", 42, 104);

    ctx.fillStyle = "rgba(255,255,255,0.16)";
    roundedRect(168, 91, 128, 14, 7);
    ctx.fill();
    ctx.fillStyle = "#edb713";
    roundedRect(168, 91, 128 * game.boost / 100, 14, 7);
    ctx.fill();

    ctx.fillStyle = "rgba(5, 11, 17, 0.72)";
    roundedRect(WIDTH - 335, 18, 310, 112, 16);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 18px Arial";
    ctx.fillText(nextDept ? "Next: " + nextDept.name : "All departments clear", WIDTH - 310, 53);
    ctx.fillStyle = "rgba(255,255,255,0.16)";
    roundedRect(WIDTH - 310, 72, 250, 14, 7);
    ctx.fill();
    ctx.fillStyle = "#64d181";
    roundedRect(WIDTH - 310, 72, 250 * progress, 14, 7);
    ctx.fill();
    ctx.fillStyle = "#dce8ef";
    ctx.font = "15px Arial";
    ctx.fillText("Combo x" + game.combo.toFixed(1), WIDTH - 310, 109);

    if (game.messageTimer > 0) {
      ctx.fillStyle = "rgba(5, 11, 17, 0.78)";
      roundedRect(WIDTH / 2 - 170, 145, 340, 48, 18);
      ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.font = "bold 21px Arial";
      ctx.textAlign = "center";
      ctx.fillText(game.message, WIDTH / 2, 176);
      ctx.textAlign = "left";
    }
  }

  function roundedRect(x, y, width, height, radius) {
    var r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
  }

  function gameLoop(timestamp) {
    if (!lastFrame) {
      lastFrame = timestamp;
    }
    var dt = Math.min(0.033, (timestamp - lastFrame) / 1000);
    lastFrame = timestamp;
    update(dt);
    draw();
    window.requestAnimationFrame(gameLoop);
  }

  function canvasXFromEvent(event) {
    var rect = canvas.getBoundingClientRect();
    var touch = event.touches && event.touches[0] ? event.touches[0] : event;
    return ((touch.clientX - rect.left) / rect.width) * WIDTH;
  }

  window.addEventListener("keydown", function(event) {
    keys[event.key] = true;
    if (event.key === " " || event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
    }
    if (event.key === "Enter" && game.state !== "running") {
      startGame();
    }
  });

  window.addEventListener("keyup", function(event) {
    keys[event.key] = false;
  });

  canvas.addEventListener("pointerdown", function(event) {
    pointerTarget = canvasXFromEvent(event);
    canvas.setPointerCapture(event.pointerId);
  });

  canvas.addEventListener("pointermove", function(event) {
    if (event.buttons || event.pointerType === "touch") {
      pointerTarget = canvasXFromEvent(event);
    }
  });

  canvas.addEventListener("pointerup", function(event) {
    pointerTarget = null;
    canvas.releasePointerCapture(event.pointerId);
  });

  controlButtons.forEach(function(button) {
    var control = button.getAttribute("data-control");
    var setPressed = function(pressed) {
      touchControls[control] = pressed;
      button.classList.toggle("is-pressed", pressed);
    };
    button.addEventListener("pointerdown", function(event) {
      event.preventDefault();
      setPressed(true);
      button.setPointerCapture(event.pointerId);
    });
    button.addEventListener("pointerup", function(event) {
      event.preventDefault();
      setPressed(false);
      button.releasePointerCapture(event.pointerId);
    });
    button.addEventListener("pointercancel", function() {
      setPressed(false);
    });
    button.addEventListener("pointerleave", function() {
      setPressed(false);
    });
  });

  if (resetButton) {
    resetButton.addEventListener("click", startGame);
  }

  window.addEventListener("resize", resizeCanvas);
  resizeCanvas();
  resetGame();
  draw();
  window.requestAnimationFrame(gameLoop);
})();
