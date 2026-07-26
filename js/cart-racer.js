(function() {
  'use strict';

  var canvas = document.getElementById('cart-racer-canvas');
  var ctx = canvas && canvas.getContext('2d');
  var overlay = document.getElementById('game-overlay');
  var overlayTitle = document.getElementById('overlay-title');
  var overlayText = document.getElementById('overlay-text');
  var startButton = document.getElementById('start-game');
  var leftButton = document.getElementById('steer-left');
  var rightButton = document.getElementById('steer-right');
  var boostButton = document.getElementById('boost-button');
  var hudLap = document.getElementById('hud-lap');
  var hudPlace = document.getElementById('hud-place');
  var hudScore = document.getElementById('hud-score');
  var hudSpeed = document.getElementById('hud-speed');

  if (!canvas || !ctx) {
    return;
  }

  var WIDTH = canvas.width;
  var HEIGHT = canvas.height;
  var LAPS = 3;
  var LAP_LENGTH = 4300;
  var TRACK_LEFT = 0.18;
  var TRACK_RIGHT = 0.82;
  var PLAYER_Y = 0.79;
  var keys = {};
  var pointerDown = false;
  var lastTime = 0;
  var spawnTimer = 0;
  var scrollOffset = 0;
  var gameStarted = false;

  var state = createState();

  function createState() {
    return {
      running: false,
      finished: false,
      score: 0,
      boostReady: true,
      boostTime: 0,
      boostCooldown: 0,
      hitTimer: 0,
      progress: 0,
      player: {
        x: 0.5,
        vx: 0,
        speed: 0,
        targetSpeed: 520
      },
      rivals: [
        { name: 'Blue Cart', progress: 210, speed: 500, color: '#3ddcff' },
        { name: 'Red Cart', progress: 115, speed: 512, color: '#ff5d75' },
        { name: 'Green Cart', progress: -70, speed: 492, color: '#42f5b3' }
      ],
      entities: []
    };
  }

  function startGame() {
    state = createState();
    state.running = true;
    gameStarted = true;
    spawnTimer = 0.25;
    scrollOffset = 0;
    lastTime = performance.now();
    overlay.className = 'game-overlay';
    startButton.textContent = 'Restart race';
    requestAnimationFrame(loop);
  }

  function loop(time) {
    var dt = Math.min((time - lastTime) / 1000, 0.033);
    lastTime = time;

    update(dt);
    draw();

    if (state.running) {
      requestAnimationFrame(loop);
    }
  }

  function update(dt) {
    var steering = 0;

    if (keys.ArrowLeft || keys.a || keys.A || leftButton.className.indexOf('is-pressed') >= 0) {
      steering -= 1;
    }

    if (keys.ArrowRight || keys.d || keys.D || rightButton.className.indexOf('is-pressed') >= 0) {
      steering += 1;
    }

    if ((keys.ArrowUp || keys.w || keys.W || boostButton.className.indexOf('is-pressed') >= 0) && state.boostReady) {
      triggerBoost();
    }

    var drag = steering * 2.8;
    state.player.vx += drag * dt;
    state.player.vx *= Math.pow(0.05, dt);
    state.player.x += state.player.vx * dt;
    state.player.x = clamp(state.player.x, TRACK_LEFT + 0.035, TRACK_RIGHT - 0.035);

    if (state.boostTime > 0) {
      state.boostTime -= dt;
      state.player.targetSpeed = 720;
    } else if (state.hitTimer > 0) {
      state.hitTimer -= dt;
      state.player.targetSpeed = 335;
    } else {
      state.player.targetSpeed = 520 + Math.min(state.score * 1.5, 90);
    }

    if (!state.boostReady) {
      state.boostCooldown -= dt;
      if (state.boostCooldown <= 0) {
        state.boostReady = true;
      }
    }

    state.player.speed += (state.player.targetSpeed - state.player.speed) * Math.min(dt * 5, 1);
    state.progress += state.player.speed * dt;
    scrollOffset += state.player.speed * dt * 0.012;

    updateRivals(dt);
    updateEntities(dt);
    maybeSpawn(dt);
    updateHud();

    if (state.progress >= LAP_LENGTH * LAPS && !state.finished) {
      finishRace();
    }
  }

  function triggerBoost() {
    state.boostReady = false;
    state.boostCooldown = 2.8;
    state.boostTime = 0.95;
  }

  function updateRivals(dt) {
    for (var i = 0; i < state.rivals.length; i++) {
      var rival = state.rivals[i];
      rival.progress += rival.speed * dt;
      rival.speed += (500 + Math.sin((state.progress + i * 700) / 550) * 40 - rival.speed) * dt * 0.8;
    }
  }

  function updateEntities(dt) {
    var speed = state.player.speed / 530;

    for (var i = state.entities.length - 1; i >= 0; i--) {
      var entity = state.entities[i];
      entity.y += dt * speed * entity.scrollSpeed;
      entity.wobble += dt * entity.wobbleSpeed;

      if (entity.y > 1.14) {
        state.entities.splice(i, 1);
        continue;
      }

      if (collides(entity)) {
        handleCollision(entity);
        state.entities.splice(i, 1);
      }
    }
  }

  function maybeSpawn(dt) {
    spawnTimer -= dt;

    if (spawnTimer > 0) {
      return;
    }

    var nextType = chooseType();
    state.entities.push(createEntity(nextType));
    spawnTimer = 0.38 + Math.random() * 0.42;
  }

  function chooseType() {
    var roll = Math.random();

    if (roll < 0.16) {
      return 'pickup';
    }

    if (roll < 0.27) {
      return 'boost';
    }

    if (roll < 0.43) {
      return 'rival';
    }

    return 'hazard';
  }

  function createEntity(type) {
    var lanes = [0.28, 0.39, 0.5, 0.61, 0.72];
    var labels = {
      pickup: ['SOCKS', 'SNACKS', 'BLANKET', 'WATER'],
      hazard: ['MOP', 'CEREAL', 'CRATE', 'CONE'],
      boost: ['BOOST'],
      rival: ['AISLE ACE', 'LOOSE CART', 'NIGHT SHIFT']
    };

    return {
      type: type,
      label: randomItem(labels[type]),
      x: randomItem(lanes) + (Math.random() - 0.5) * 0.035,
      y: -0.1,
      size: type === 'rival' ? 0.095 : 0.072,
      scrollSpeed: type === 'rival' ? 0.34 + Math.random() * 0.12 : 0.42 + Math.random() * 0.15,
      wobble: Math.random() * 10,
      wobbleSpeed: 2 + Math.random() * 2,
      color: randomItem(['#ffd666', '#3ddcff', '#ff7c5c', '#42f5b3'])
    };
  }

  function handleCollision(entity) {
    if (entity.type === 'pickup') {
      state.score += 8;
      state.boostCooldown = Math.max(0, state.boostCooldown - 0.7);
      if (state.boostCooldown === 0) {
        state.boostReady = true;
      }
      return;
    }

    if (entity.type === 'boost') {
      state.score += 3;
      state.boostReady = true;
      triggerBoost();
      return;
    }

    state.hitTimer = entity.type === 'rival' ? 1.05 : 0.8;
    state.score = Math.max(0, state.score - (entity.type === 'rival' ? 3 : 2));
    state.player.vx += (state.player.x < entity.x ? -1 : 1) * 0.9;
  }

  function collides(entity) {
    var dx = Math.abs(entity.x - state.player.x);
    var dy = Math.abs(entity.y - PLAYER_Y);
    return dx < entity.size && dy < entity.size * 1.15;
  }

  function finishRace() {
    state.running = false;
    state.finished = true;
    var place = getPlace();
    overlayTitle.textContent = place === 1 ? 'You won the Store Dash!' : 'Race finished!';
    overlayText.textContent = 'Final place: ' + ordinal(place) + '. Care kits collected: ' + state.score + '. Tap restart to race the carts again.';
    overlay.className = 'game-overlay is-visible';
  }

  function updateHud() {
    var lap = Math.min(LAPS, Math.floor(state.progress / LAP_LENGTH) + 1);
    hudLap.textContent = lap + '/' + LAPS;
    hudPlace.textContent = ordinal(getPlace());
    hudScore.textContent = String(state.score);
    hudSpeed.textContent = String(Math.round(state.player.speed / 8));
  }

  function getPlace() {
    var place = 1;

    for (var i = 0; i < state.rivals.length; i++) {
      if (state.rivals[i].progress > state.progress) {
        place += 1;
      }
    }

    return place;
  }

  function draw() {
    drawStore();
    drawEntities();
    drawRivalGhosts();
    drawPlayer();
    drawEffects();
  }

  function drawStore() {
    var floor = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    floor.addColorStop(0, '#182649');
    floor.addColorStop(1, '#0e1428');
    ctx.fillStyle = floor;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    ctx.fillStyle = '#2a1936';
    ctx.fillRect(0, 0, WIDTH * TRACK_LEFT, HEIGHT);
    ctx.fillRect(WIDTH * TRACK_RIGHT, 0, WIDTH * (1 - TRACK_RIGHT), HEIGHT);

    drawShelves(0, WIDTH * TRACK_LEFT, '#ff7c5c');
    drawShelves(WIDTH * TRACK_RIGHT, WIDTH * (1 - TRACK_RIGHT), '#3ddcff');

    ctx.fillStyle = 'rgba(255, 255, 255, 0.09)';
    for (var i = 0; i < 16; i++) {
      var y = ((i * 62 + scrollOffset * 38) % (HEIGHT + 80)) - 80;
      ctx.fillRect(WIDTH * TRACK_LEFT, y, WIDTH * (TRACK_RIGHT - TRACK_LEFT), 2);
    }

    ctx.strokeStyle = 'rgba(255, 214, 102, 0.4)';
    ctx.lineWidth = 2;
    ctx.setLineDash([20, 22]);

    for (var lane = 1; lane <= 4; lane++) {
      var x = WIDTH * (TRACK_LEFT + (TRACK_RIGHT - TRACK_LEFT) * lane / 5);
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, HEIGHT);
      ctx.stroke();
    }

    ctx.setLineDash([]);

    var lapRatio = (state.progress % LAP_LENGTH) / LAP_LENGTH;
    if (lapRatio > 0.91 || state.progress < 350) {
      drawFinishLine(((scrollOffset * 34) % HEIGHT) - 30);
    }
  }

  function drawShelves(x, width, accent) {
    ctx.fillStyle = 'rgba(255, 255, 255, 0.06)';
    ctx.fillRect(x + 8, 0, Math.max(width - 16, 8), HEIGHT);
    ctx.fillStyle = accent;

    for (var y = -40; y < HEIGHT + 60; y += 78) {
      var movingY = y + (scrollOffset * 21) % 78;
      ctx.globalAlpha = 0.55;
      ctx.fillRect(x + 14, movingY, Math.max(width - 28, 8), 12);
      ctx.globalAlpha = 1;
      ctx.fillStyle = 'rgba(255, 255, 255, 0.18)';
      ctx.fillRect(x + 18, movingY + 18, Math.max(width - 36, 6), 7);
      ctx.fillStyle = accent;
    }
  }

  function drawFinishLine(y) {
    var left = WIDTH * TRACK_LEFT;
    var tile = 18;
    var trackWidth = WIDTH * (TRACK_RIGHT - TRACK_LEFT);

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < Math.ceil(trackWidth / tile); col++) {
        ctx.fillStyle = (row + col) % 2 === 0 ? '#ffffff' : '#151515';
        ctx.fillRect(left + col * tile, y + row * tile, tile, tile);
      }
    }
  }

  function drawEntities() {
    var entities = state.entities.slice().sort(function(a, b) {
      return a.y - b.y;
    });

    for (var i = 0; i < entities.length; i++) {
      var entity = entities[i];
      var x = entity.x + Math.sin(entity.wobble) * 0.008;
      var sx = x * WIDTH;
      var sy = entity.y * HEIGHT;

      if (entity.type === 'pickup') {
        drawCareKit(sx, sy, entity);
      } else if (entity.type === 'boost') {
        drawBoostPad(sx, sy);
      } else if (entity.type === 'rival') {
        drawCart(sx, sy, entity.color, 0.76, entity.label);
      } else {
        drawHazard(sx, sy, entity);
      }
    }
  }

  function drawRivalGhosts() {
    for (var i = 0; i < state.rivals.length; i++) {
      var rival = state.rivals[i];
      var delta = rival.progress - state.progress;

      if (delta < -260 || delta > 720) {
        continue;
      }

      var y = PLAYER_Y * HEIGHT - delta * 0.36;
      var x = WIDTH * (0.28 + i * 0.22 + Math.sin((state.progress + i * 500) / 380) * 0.03);
      drawCart(x, y, rival.color, 0.62, rival.name);
    }
  }

  function drawPlayer() {
    var bounce = Math.sin(scrollOffset * 2.4) * 2;
    drawCart(state.player.x * WIDTH, PLAYER_Y * HEIGHT + bounce, '#ffd666', 1, 'YOU');
  }

  function drawCart(x, y, color, scale, label) {
    var w = 54 * scale;
    var h = 72 * scale;

    ctx.save();
    ctx.translate(x, y);
    ctx.lineWidth = 3 * scale;
    ctx.strokeStyle = '#dce8ff';
    ctx.fillStyle = color;

    ctx.globalAlpha = 0.22;
    ctx.fillStyle = '#000000';
    ctx.beginPath();
    ctx.ellipse(0, h * 0.36, w * 0.58, h * 0.16, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;

    ctx.fillStyle = color;
    roundRect(-w * 0.38, -h * 0.28, w * 0.76, h * 0.48, 8 * scale);
    ctx.fill();
    ctx.stroke();

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.62)';
    for (var i = -2; i <= 2; i++) {
      ctx.beginPath();
      ctx.moveTo(i * w * 0.13, -h * 0.24);
      ctx.lineTo(i * w * 0.09, h * 0.16);
      ctx.stroke();
    }

    ctx.strokeStyle = '#dce8ff';
    ctx.beginPath();
    ctx.moveTo(-w * 0.43, -h * 0.3);
    ctx.lineTo(-w * 0.57, -h * 0.47);
    ctx.moveTo(w * 0.43, -h * 0.3);
    ctx.lineTo(w * 0.57, -h * 0.47);
    ctx.stroke();

    ctx.fillStyle = '#071019';
    ctx.beginPath();
    ctx.arc(-w * 0.28, h * 0.29, 5 * scale, 0, Math.PI * 2);
    ctx.arc(w * 0.28, h * 0.29, 5 * scale, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#ffffff';
    ctx.font = Math.max(8, 10 * scale) + 'px Arial';
    ctx.textAlign = 'center';
    ctx.fillText(label, 0, h * 0.04);
    ctx.restore();
  }

  function drawCareKit(x, y, entity) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.sin(entity.wobble) * 0.12);
    ctx.fillStyle = '#42f5b3';
    roundRect(-20, -16, 40, 32, 7);
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(-4, -12, 8, 24);
    ctx.fillRect(-13, -3, 26, 7);
    ctx.fillStyle = '#071019';
    ctx.font = '8px Arial';
    ctx.textAlign = 'center';
    ctx.fillText(entity.label, 0, 28);
    ctx.restore();
  }

  function drawBoostPad(x, y) {
    ctx.save();
    ctx.translate(x, y);
    ctx.fillStyle = '#ffd666';
    ctx.beginPath();
    ctx.moveTo(-30, 20);
    ctx.lineTo(0, -24);
    ctx.lineTo(30, 20);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#ff7c5c';
    ctx.beginPath();
    ctx.moveTo(-12, 16);
    ctx.lineTo(0, -8);
    ctx.lineTo(12, 16);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawHazard(x, y, entity) {
    ctx.save();
    ctx.translate(x, y);

    if (entity.label === 'MOP') {
      ctx.fillStyle = 'rgba(61, 220, 255, 0.55)';
      ctx.beginPath();
      ctx.ellipse(0, 4, 30, 18, 0.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#dce8ff';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-4, -20);
      ctx.lineTo(22, 22);
      ctx.stroke();
    } else if (entity.label === 'CEREAL') {
      ctx.fillStyle = '#ff7c5c';
      roundRect(-20, -22, 40, 44, 6);
      ctx.fill();
      ctx.fillStyle = '#ffd666';
      for (var i = 0; i < 9; i++) {
        ctx.beginPath();
        ctx.arc(-26 + i * 7, 26 + Math.sin(i) * 4, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    } else {
      ctx.fillStyle = entity.label === 'CRATE' ? '#a46b3f' : '#ff7c5c';
      roundRect(-24, -19, 48, 38, 6);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.65)';
      ctx.lineWidth = 3;
      ctx.stroke();
    }

    ctx.fillStyle = '#ffffff';
    ctx.font = '9px Arial';
    ctx.textAlign = 'center';
    ctx.fillText(entity.label, 0, 34);
    ctx.restore();
  }

  function drawEffects() {
    if (state.boostTime > 0) {
      ctx.strokeStyle = 'rgba(255, 214, 102, 0.7)';
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.moveTo((state.player.x - 0.055) * WIDTH, PLAYER_Y * HEIGHT + 34);
      ctx.lineTo((state.player.x - 0.085) * WIDTH, PLAYER_Y * HEIGHT + 78);
      ctx.moveTo((state.player.x + 0.055) * WIDTH, PLAYER_Y * HEIGHT + 34);
      ctx.lineTo((state.player.x + 0.085) * WIDTH, PLAYER_Y * HEIGHT + 78);
      ctx.stroke();
    }

    if (!gameStarted) {
      updateHud();
    }
  }

  function roundRect(x, y, width, height, radius) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    ctx.lineTo(x + radius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
  }

  function setPressed(button, pressed) {
    if (!button) {
      return;
    }

    if (pressed) {
      button.className = 'is-pressed';
    } else {
      button.className = '';
    }
  }

  function bindHoldButton(button) {
    if (!button) {
      return;
    }

    button.addEventListener('pointerdown', function(event) {
      event.preventDefault();
      setPressed(button, true);
    });
    button.addEventListener('pointerup', function() {
      setPressed(button, false);
    });
    button.addEventListener('pointercancel', function() {
      setPressed(button, false);
    });
    button.addEventListener('pointerleave', function() {
      setPressed(button, false);
    });
  }

  function bindControls() {
    document.addEventListener('keydown', function(event) {
      keys[event.key] = true;

      if ((event.key === ' ' || event.key === 'Enter') && !state.running) {
        startGame();
      }
    });

    document.addEventListener('keyup', function(event) {
      keys[event.key] = false;
    });

    canvas.addEventListener('pointerdown', function(event) {
      pointerDown = true;
      steerToPointer(event);
    });

    canvas.addEventListener('pointermove', function(event) {
      if (pointerDown) {
        steerToPointer(event);
      }
    });

    canvas.addEventListener('pointerup', function() {
      pointerDown = false;
    });

    canvas.addEventListener('pointercancel', function() {
      pointerDown = false;
    });

    bindHoldButton(leftButton);
    bindHoldButton(rightButton);
    bindHoldButton(boostButton);

    startButton.addEventListener('click', startGame);
  }

  function steerToPointer(event) {
    var rect = canvas.getBoundingClientRect();
    var target = (event.clientX - rect.left) / rect.width;
    state.player.x = clamp(target, TRACK_LEFT + 0.035, TRACK_RIGHT - 0.035);
    state.player.vx *= 0.35;
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function randomItem(items) {
    return items[Math.floor(Math.random() * items.length)];
  }

  function ordinal(value) {
    if (value === 1) {
      return '1st';
    }

    if (value === 2) {
      return '2nd';
    }

    if (value === 3) {
      return '3rd';
    }

    return value + 'th';
  }

  bindControls();
  draw();
})();
