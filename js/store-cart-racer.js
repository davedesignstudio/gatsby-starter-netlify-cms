(function() {
  "use strict";

  var root = document.querySelector("[data-cart-game]");
  var canvas = document.getElementById("cart-racer-canvas");
  if (!root || !canvas || !canvas.getContext) {
    return;
  }

  var ctx = canvas.getContext("2d");
  var WIDTH = 768;
  var HEIGHT = 1024;
  var TRACK_LEFT = 128;
  var TRACK_RIGHT = 640;
  var TRACK_WIDTH = TRACK_RIGHT - TRACK_LEFT;
  var PLAYER_Y = 812;
  var RACE_DISTANCE = 6800;

  var scoreEl = root.querySelector("[data-score]");
  var suppliesEl = root.querySelector("[data-supplies]");
  var boostEl = root.querySelector("[data-boost]");
  var bestEl = root.querySelector("[data-best]");
  var overlay = root.querySelector("[data-overlay]");
  var overlayTitle = root.querySelector("[data-overlay-title]");
  var overlayCopy = root.querySelector("[data-overlay-copy]");
  var startButton = root.querySelector("[data-start]");
  var buttons = root.querySelectorAll("[data-control]");

  var bestScore = Number(window.localStorage && window.localStorage.getItem("cartRacerBest")) || 0;
  var keys = {};
  var touchSteer = 0;
  var lastTime = 0;
  var spawnTimer = 0;
  var collectibleTimer = 0;
  var rivalTimer = 0;
  var animationId = null;

  var state = createState();
  updateHud();
  draw();

  function createState() {
    return {
      running: false,
      finished: false,
      won: false,
      score: 0,
      supplies: 0,
      distance: 0,
      baseSpeed: 435,
      player: {
        x: WIDTH / 2,
        y: PLAYER_Y,
        radius: 34,
        spin: 0
      },
      boostActive: 0,
      boostCooldown: 0,
      hitCooldown: 0,
      obstacles: [],
      collectibles: [],
      rivals: []
    };
  }

  function startGame() {
    state = createState();
    state.running = true;
    hideOverlay();
    lastTime = 0;
    spawnTimer = 0.5;
    collectibleTimer = 0.35;
    rivalTimer = 1.2;
    cancelAnimationFrame(animationId);
    animationId = requestAnimationFrame(loop);
    updateHud();
  }

  function finishGame(won) {
    state.running = false;
    state.finished = true;
    state.won = won;
    state.score += won ? 1500 : 0;

    if (state.score > bestScore) {
      bestScore = state.score;
      if (window.localStorage) {
        window.localStorage.setItem("cartRacerBest", String(bestScore));
      }
    }

    updateHud();
    showOverlay(
      won ? "Checkout victory!" : "Shelves closed!",
      won
        ? "You delivered enough supply packs and beat the rush. Start another run to chase a higher score."
        : "The cart reached checkout before you collected 8 supply packs. Try again and cut tighter lines through the aisles.",
      "Race again"
    );
  }

  function loop(time) {
    if (!lastTime) {
      lastTime = time;
    }

    var dt = Math.min((time - lastTime) / 1000, 0.033);
    lastTime = time;

    if (state.running) {
      update(dt);
    }

    draw();
    animationId = requestAnimationFrame(loop);
  }

  function update(dt) {
    var speed = state.baseSpeed + Math.min(state.distance * 0.025, 155);
    if (state.boostActive > 0) {
      speed += 260;
      state.boostActive = Math.max(0, state.boostActive - dt);
    }

    state.distance += speed * dt;
    state.score += Math.floor((speed * dt) / 5);
    state.boostCooldown = Math.max(0, state.boostCooldown - dt);
    state.hitCooldown = Math.max(0, state.hitCooldown - dt);

    var steer = getSteerInput();
    state.player.x += steer * (390 + speed * 0.18) * dt;
    state.player.x = clamp(state.player.x, TRACK_LEFT + 42, TRACK_RIGHT - 42);
    state.player.spin += (speed / 90) * dt;

    updateSpawns(dt, speed);
    updateEntities(dt, speed);
    checkCollisions();
    updateHud();

    if (state.distance >= RACE_DISTANCE) {
      finishGame(state.supplies >= 8);
    }
  }

  function updateSpawns(dt, speed) {
    spawnTimer -= dt;
    collectibleTimer -= dt;
    rivalTimer -= dt;

    if (spawnTimer <= 0) {
      spawnObstacle();
      spawnTimer = randomBetween(0.56, 0.95) - Math.min(state.distance / 26000, 0.22);
    }

    if (collectibleTimer <= 0) {
      spawnCollectible();
      collectibleTimer = randomBetween(0.45, 0.78);
    }

    if (rivalTimer <= 0) {
      spawnRival();
      rivalTimer = randomBetween(2.3, 3.7) - Math.min(speed / 1800, 0.4);
    }
  }

  function updateEntities(dt, speed) {
    moveList(state.obstacles, dt, speed);
    moveList(state.collectibles, dt, speed);
    moveList(state.rivals, dt, speed);

    state.obstacles = state.obstacles.filter(isVisible);
    state.collectibles = state.collectibles.filter(isVisible);
    state.rivals = state.rivals.filter(isVisible);
  }

  function moveList(list, dt, speed) {
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      item.y += (speed - item.speed) * dt;
      item.wobble += dt * item.wobbleSpeed;
      if (item.kind === "rival") {
        item.x += Math.sin(item.wobble) * item.drift * dt;
        item.x = clamp(item.x, TRACK_LEFT + 46, TRACK_RIGHT - 46);
      }
    }
  }

  function checkCollisions() {
    var player = state.player;

    state.collectibles = state.collectibles.filter(function(item) {
      if (!circlesOverlap(player, item)) {
        return true;
      }

      if (item.kind === "coupon") {
        state.score += 350;
        state.boostCooldown = 0;
        state.boostActive = Math.max(state.boostActive, 0.6);
      } else {
        state.supplies += 1;
        state.score += 500;
      }

      return false;
    });

    if (state.hitCooldown > 0) {
      return;
    }

    for (var i = 0; i < state.obstacles.length; i++) {
      if (circlesOverlap(player, state.obstacles[i])) {
        registerHit(240);
        return;
      }
    }

    for (var j = 0; j < state.rivals.length; j++) {
      if (circlesOverlap(player, state.rivals[j])) {
        registerHit(330);
        return;
      }
    }
  }

  function registerHit(pointsLost) {
    state.score = Math.max(0, state.score - pointsLost);
    state.baseSpeed = Math.max(330, state.baseSpeed - 24);
    state.hitCooldown = 0.9;
    state.boostActive = 0;
  }

  function spawnObstacle() {
    var types = ["spill", "cone", "display"];
    var kind = types[Math.floor(Math.random() * types.length)];
    state.obstacles.push({
      kind: kind,
      x: randomLaneX(),
      y: -90,
      radius: kind === "display" ? 36 : 30,
      speed: randomBetween(12, 44),
      wobble: Math.random() * Math.PI,
      wobbleSpeed: randomBetween(1, 2),
      drift: 0
    });
  }

  function spawnCollectible() {
    var isCoupon = Math.random() < 0.32;
    state.collectibles.push({
      kind: isCoupon ? "coupon" : "supply",
      x: randomLaneX(),
      y: -70,
      radius: isCoupon ? 25 : 29,
      speed: randomBetween(18, 52),
      wobble: Math.random() * Math.PI,
      wobbleSpeed: randomBetween(2, 3.8),
      drift: 0
    });
  }

  function spawnRival() {
    state.rivals.push({
      kind: "rival",
      x: randomLaneX(),
      y: -140,
      radius: 38,
      speed: randomBetween(170, 255),
      wobble: Math.random() * Math.PI,
      wobbleSpeed: randomBetween(1.7, 3.2),
      drift: randomBetween(26, 52)
    });
  }

  function randomLaneX() {
    var lanes = [0.2, 0.4, 0.6, 0.8];
    return TRACK_LEFT + TRACK_WIDTH * lanes[Math.floor(Math.random() * lanes.length)] + randomBetween(-22, 22);
  }

  function draw() {
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    drawStore();
    drawTrackDetails();
    drawCollectibles();
    drawObstacles();
    drawRivals();
    drawPlayer();
    drawProgress();
  }

  function drawStore() {
    ctx.fillStyle = "#ece3d4";
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    var shelfOffset = (state.distance * 0.55) % 150;
    drawShelf(0, shelfOffset, TRACK_LEFT - 18, "#3d465f");
    drawShelf(TRACK_RIGHT + 18, shelfOffset + 40, WIDTH - TRACK_RIGHT - 18, "#384156");

    ctx.fillStyle = "#d6c9b8";
    ctx.fillRect(TRACK_LEFT, 0, TRACK_WIDTH, HEIGHT);
    ctx.fillStyle = "#cbbba7";
    ctx.fillRect(TRACK_LEFT + 16, 0, TRACK_WIDTH - 32, HEIGHT);
  }

  function drawShelf(x, offset, width, baseColor) {
    ctx.fillStyle = baseColor;
    ctx.fillRect(x, 0, width, HEIGHT);

    for (var y = -160 + offset; y < HEIGHT + 160; y += 150) {
      ctx.fillStyle = "rgba(255, 255, 255, 0.12)";
      ctx.fillRect(x + 12, y, Math.max(12, width - 24), 8);
      drawProducts(x + 18, y + 18, width - 36);
    }
  }

  function drawProducts(x, y, width) {
    var colors = ["#edb713", "#70e1f5", "#f36f56", "#8bd17c", "#ffffff"];
    var itemWidth = Math.max(12, Math.min(28, width / 5));
    for (var i = 0; i < 5; i++) {
      ctx.fillStyle = colors[i];
      ctx.fillRect(x + i * (itemWidth + 6), y, itemWidth, 32 + (i % 2) * 12);
    }
  }

  function drawTrackDetails() {
    var stripeOffset = (state.distance * 0.85) % 96;
    ctx.strokeStyle = "rgba(255, 255, 255, 0.45)";
    ctx.lineWidth = 6;
    ctx.setLineDash([38, 58]);
    ctx.lineDashOffset = stripeOffset;
    ctx.beginPath();
    ctx.moveTo(WIDTH / 2, -100);
    ctx.lineTo(WIDTH / 2, HEIGHT + 100);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = "rgba(255, 255, 255, 0.18)";
    for (var y = -90 + stripeOffset; y < HEIGHT; y += 96) {
      ctx.fillRect(TRACK_LEFT + 34, y, 34, 9);
      ctx.fillRect(TRACK_RIGHT - 68, y + 48, 34, 9);
    }
  }

  function drawCollectibles() {
    for (var i = 0; i < state.collectibles.length; i++) {
      var item = state.collectibles[i];
      if (item.kind === "coupon") {
        drawCoupon(item.x, item.y, item.radius, item.wobble);
      } else {
        drawSupplyPack(item.x, item.y, item.radius, item.wobble);
      }
    }
  }

  function drawObstacles() {
    for (var i = 0; i < state.obstacles.length; i++) {
      var item = state.obstacles[i];
      if (item.kind === "spill") {
        drawSpill(item.x, item.y, item.radius, item.wobble);
      } else if (item.kind === "cone") {
        drawCone(item.x, item.y, item.radius);
      } else {
        drawDisplay(item.x, item.y, item.radius);
      }
    }
  }

  function drawRivals() {
    for (var i = 0; i < state.rivals.length; i++) {
      drawCart(state.rivals[i].x, state.rivals[i].y, "#f36f56", "#9d3527", state.rivals[i].wobble, 0.92);
    }
  }

  function drawPlayer() {
    var pulse = state.hitCooldown > 0 ? Math.sin(Date.now() / 45) : 1;
    if (state.hitCooldown > 0 && pulse < 0) {
      return;
    }

    var color = state.boostActive > 0 ? "#70e1f5" : "#edb713";
    drawCart(state.player.x, state.player.y, color, "#202436", state.player.spin, 1);

    if (state.boostActive > 0) {
      ctx.fillStyle = "rgba(112, 225, 245, 0.32)";
      ctx.beginPath();
      ctx.ellipse(state.player.x, state.player.y + 50, 34, 78, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function drawCart(x, y, color, darkColor, spin, scale) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);

    ctx.fillStyle = "rgba(0, 0, 0, 0.18)";
    ctx.beginPath();
    ctx.ellipse(0, 32, 50, 18, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = darkColor;
    ctx.lineWidth = 7;
    ctx.lineJoin = "round";
    ctx.strokeRect(-34, -34, 68, 72);

    ctx.fillStyle = color;
    ctx.fillRect(-28, -28, 56, 18);
    ctx.fillStyle = "rgba(255, 255, 255, 0.58)";
    for (var i = -20; i <= 20; i += 20) {
      ctx.fillRect(i, -5, 5, 32);
    }

    ctx.strokeStyle = darkColor;
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-38, -28);
    ctx.lineTo(-52, -58);
    ctx.moveTo(38, -28);
    ctx.lineTo(52, -58);
    ctx.stroke();

    drawWheel(-28, 43, spin);
    drawWheel(28, 43, spin);
    drawWheel(-28, -40, spin);
    drawWheel(28, -40, spin);

    ctx.restore();
  }

  function drawWheel(x, y, spin) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(spin);
    ctx.fillStyle = "#202436";
    ctx.beginPath();
    ctx.arc(0, 0, 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-7, 0);
    ctx.lineTo(7, 0);
    ctx.moveTo(0, -7);
    ctx.lineTo(0, 7);
    ctx.stroke();
    ctx.restore();
  }

  function drawSupplyPack(x, y, radius, wobble) {
    ctx.save();
    ctx.translate(x, y + Math.sin(wobble) * 5);
    ctx.fillStyle = "rgba(0, 0, 0, 0.18)";
    ctx.beginPath();
    ctx.ellipse(0, radius * 0.9, radius * 0.8, radius * 0.22, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#8bd17c";
    ctx.fillRect(-radius, -radius * 0.75, radius * 2, radius * 1.5);
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(-radius * 0.28, -radius * 0.75, radius * 0.56, radius * 1.5);
    ctx.fillRect(-radius, -radius * 0.18, radius * 2, radius * 0.36);
    ctx.restore();
  }

  function drawCoupon(x, y, radius, wobble) {
    ctx.save();
    ctx.translate(x, y + Math.sin(wobble) * 6);
    ctx.rotate(Math.sin(wobble) * 0.15);
    ctx.fillStyle = "#fff4c3";
    ctx.fillRect(-radius * 1.12, -radius * 0.68, radius * 2.24, radius * 1.36);
    ctx.fillStyle = "#edb713";
    ctx.fillRect(-radius * 0.86, -radius * 0.42, radius * 1.72, radius * 0.3);
    ctx.fillStyle = "#202436";
    ctx.font = "bold 18px Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("BOOST", 0, radius * 0.34);
    ctx.restore();
  }

  function drawSpill(x, y, radius, wobble) {
    ctx.fillStyle = "#70e1f5";
    ctx.beginPath();
    ctx.ellipse(x, y, radius * 1.18, radius * 0.68, Math.sin(wobble) * 0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(255, 255, 255, 0.54)";
    ctx.beginPath();
    ctx.arc(x - radius * 0.24, y - radius * 0.08, radius * 0.18, 0, Math.PI * 2);
    ctx.fill();
  }

  function drawCone(x, y, radius) {
    ctx.fillStyle = "rgba(0, 0, 0, 0.18)";
    ctx.beginPath();
    ctx.ellipse(x, y + radius * 0.82, radius * 0.8, radius * 0.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f36f56";
    ctx.beginPath();
    ctx.moveTo(x, y - radius);
    ctx.lineTo(x - radius * 0.68, y + radius * 0.72);
    ctx.lineTo(x + radius * 0.68, y + radius * 0.72);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.fillRect(x - radius * 0.42, y + radius * 0.05, radius * 0.84, radius * 0.2);
  }

  function drawDisplay(x, y, radius) {
    ctx.fillStyle = "#66472d";
    ctx.fillRect(x - radius, y - radius * 0.8, radius * 2, radius * 1.6);
    ctx.fillStyle = "#edb713";
    ctx.fillRect(x - radius * 0.76, y - radius * 0.54, radius * 1.52, radius * 0.36);
    ctx.fillStyle = "#f36f56";
    ctx.fillRect(x - radius * 0.76, y + radius * 0.08, radius * 1.52, radius * 0.36);
  }

  function drawProgress() {
    var progress = clamp(state.distance / RACE_DISTANCE, 0, 1);
    ctx.fillStyle = "rgba(32, 36, 54, 0.72)";
    ctx.fillRect(34, HEIGHT - 40, WIDTH - 68, 14);
    ctx.fillStyle = state.supplies >= 8 ? "#8bd17c" : "#edb713";
    ctx.fillRect(34, HEIGHT - 40, (WIDTH - 68) * progress, 14);
    ctx.fillStyle = "#202436";
    ctx.font = "bold 17px Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Checkout", WIDTH - 72, HEIGHT - 52);
  }

  function getSteerInput() {
    var steer = 0;
    if (keys.ArrowLeft || keys.a || keys.A) {
      steer -= 1;
    }
    if (keys.ArrowRight || keys.d || keys.D) {
      steer += 1;
    }
    return clamp(steer + touchSteer, -1, 1);
  }

  function useBoost() {
    if (!state.running || state.boostCooldown > 0) {
      return;
    }
    state.boostActive = 1.05;
    state.boostCooldown = 5.5;
    updateHud();
  }

  function updateHud() {
    scoreEl.textContent = String(state.score);
    suppliesEl.textContent = String(state.supplies);
    bestEl.textContent = String(bestScore);
    boostEl.textContent = state.boostCooldown <= 0 ? "Ready" : Math.ceil(state.boostCooldown) + "s";
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

  function circlesOverlap(a, b) {
    var dx = a.x - b.x;
    var dy = a.y - b.y;
    var combined = a.radius + b.radius;
    return dx * dx + dy * dy < combined * combined;
  }

  function isVisible(item) {
    return item.y < HEIGHT + 140;
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function randomBetween(min, max) {
    return min + Math.random() * (max - min);
  }

  function pointerToSteer(event) {
    var rect = canvas.getBoundingClientRect();
    var x = ((event.clientX - rect.left) / rect.width) * WIDTH;
    var difference = x - state.player.x;
    touchSteer = Math.abs(difference) < 18 ? 0 : clamp(difference / 150, -1, 1);
  }

  startButton.addEventListener("click", startGame);

  window.addEventListener("keydown", function(event) {
    keys[event.key] = true;
    if (event.key === " " || event.key === "Spacebar") {
      event.preventDefault();
      useBoost();
    }
  });

  window.addEventListener("keyup", function(event) {
    keys[event.key] = false;
  });

  canvas.addEventListener("pointerdown", function(event) {
    if (!state.running) {
      return;
    }
    canvas.setPointerCapture(event.pointerId);
    pointerToSteer(event);
  });

  canvas.addEventListener("pointermove", function(event) {
    if (state.running) {
      pointerToSteer(event);
    }
  });

  canvas.addEventListener("pointerup", function(event) {
    touchSteer = 0;
    try {
      canvas.releasePointerCapture(event.pointerId);
    } catch (error) {
      // Safari can release pointer capture automatically when touch ends.
    }
  });

  canvas.addEventListener("pointercancel", function() {
    touchSteer = 0;
  });

  buttons.forEach(function(button) {
    var control = button.getAttribute("data-control");

    button.addEventListener("pointerdown", function(event) {
      event.preventDefault();
      button.classList.add("is-pressed");
      if (control === "left") {
        touchSteer = -1;
      } else if (control === "right") {
        touchSteer = 1;
      } else {
        useBoost();
      }
    });

    button.addEventListener("pointerup", function() {
      button.classList.remove("is-pressed");
      if (control !== "boost") {
        touchSteer = 0;
      }
    });

    button.addEventListener("pointerleave", function() {
      button.classList.remove("is-pressed");
      if (control !== "boost") {
        touchSteer = 0;
      }
    });
  });
})();
