(function() {
  'use strict';

  var canvas = document.getElementById('cart-racer-canvas');
  if (!canvas || !canvas.getContext) {
    return;
  }

  var ctx = canvas.getContext('2d');
  var WIDTH = 960;
  var HEIGHT = 540;
  var TRACK_LENGTH = 4200;
  var TOTAL_LAPS = 3;
  var TOTAL_DISTANCE = TRACK_LENGTH * TOTAL_LAPS;
  var LANES = [-0.68, -0.38, -0.12, 0.16, 0.46, 0.72];
  var ITEM_NAMES = {
    sprint: 'Sprint Cart',
    shield: 'Coupon Shield',
    burst: 'Snack Burst'
  };

  var elements = {
    lap: document.getElementById('cart-racer-lap'),
    place: document.getElementById('cart-racer-place'),
    speed: document.getElementById('cart-racer-speed'),
    item: document.getElementById('cart-racer-item'),
    score: document.getElementById('cart-racer-score'),
    overlay: document.getElementById('cart-racer-overlay'),
    overlayTitle: document.getElementById('cart-racer-overlay-title'),
    overlayCopy: document.getElementById('cart-racer-overlay-copy'),
    start: document.getElementById('cart-racer-start')
  };

  var controls = {
    left: false,
    right: false,
    boost: false,
    brake: false
  };

  var player;
  var rivals;
  var entities;
  var message;
  var lastTime = 0;
  var raceRunning = false;
  var raceFinished = false;
  var finishPlace = 1;
  var dpr = 1;

  function seededRandom(seed) {
    var value = seed >>> 0;
    return function() {
      value += 0x6D2B79F5;
      var t = value;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function resetRace() {
    player = {
      name: 'You',
      color: '#edb713',
      x: -0.1,
      vx: 0,
      speed: 0,
      distance: 0,
      score: 0,
      item: null,
      boostTimer: 0,
      shieldTimer: 0,
      hitCooldown: 0
    };

    rivals = [
      createRival('Mika', '#44d7b6', 28, 408, -0.48),
      createRival('Rico', '#ff6b86', -20, 430, 0.22),
      createRival('Jun', '#8f7bff', -62, 398, 0.58)
    ];

    entities = buildTrack();
    message = {
      text: 'Three laps to checkout!',
      timer: 2.4
    };
    finishPlace = 1;
    updateHud();
  }

  function createRival(name, color, distance, baseSpeed, lane) {
    return {
      name: name,
      color: color,
      x: lane,
      targetX: lane,
      vx: 0,
      distance: distance,
      baseSpeed: baseSpeed,
      speed: baseSpeed,
      decisionTimer: 0.6 + Math.random() * 0.8
    };
  }

  function buildTrack() {
    var random = seededRandom(26072026);
    var trackEntities = [];
    var id = 0;

    for (var lap = 0; lap < TOTAL_LAPS; lap += 1) {
      var base = lap * TRACK_LENGTH;

      for (var d = 260; d < TRACK_LENGTH - 120; d += 230) {
        var roll = random();
        var lane = LANES[Math.floor(random() * LANES.length)];
        var type = 'grocery';

        if (roll > 0.82) {
          type = 'mystery';
        } else if (roll > 0.64) {
          type = 'coupon';
        }

        trackEntities.push({
          id: id,
          type: type,
          distance: base + d,
          x: lane,
          active: true
        });
        id += 1;
      }

      for (var hazard = 520; hazard < TRACK_LENGTH - 160; hazard += 410) {
        var hazardLane = LANES[Math.floor(random() * LANES.length)];
        trackEntities.push({
          id: id,
          type: random() > 0.48 ? 'spill' : 'stack',
          distance: base + hazard + random() * 150,
          x: hazardLane,
          active: true
        });
        id += 1;
      }
    }

    return trackEntities;
  }

  function setCanvasScale() {
    dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    canvas.width = WIDTH * dpr;
    canvas.height = HEIGHT * dpr;
    canvas.style.width = '100%';
    canvas.style.height = 'auto';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function startRace() {
    resetRace();
    raceRunning = true;
    raceFinished = false;
    lastTime = performance.now();
    hideOverlay();
  }

  function hideOverlay() {
    if (elements.overlay) {
      elements.overlay.classList.add('is-hidden');
    }
  }

  function showOverlay(title, copy, buttonLabel) {
    if (!elements.overlay) {
      return;
    }

    elements.overlay.classList.remove('is-hidden');
    elements.overlayTitle.textContent = title;
    elements.overlayCopy.textContent = copy;
    elements.start.textContent = buttonLabel;
  }

  function gameLoop(now) {
    if (!lastTime) {
      lastTime = now;
    }

    var dt = Math.min(0.05, (now - lastTime) / 1000);
    lastTime = now;

    if (raceRunning) {
      updateGame(dt);
    }

    drawGame();
    requestAnimationFrame(gameLoop);
  }

  function updateGame(dt) {
    var steering = 0;
    if (controls.left) {
      steering -= 1;
    }
    if (controls.right) {
      steering += 1;
    }

    var targetMax = player.boostTimer > 0 ? 760 : 560;
    var throttle = controls.boost ? 390 : 245;
    player.speed += throttle * dt;

    if (controls.brake) {
      player.speed -= 520 * dt;
      player.vx *= 0.86;
    }

    if (player.boostTimer > 0) {
      player.speed += 520 * dt;
      player.boostTimer -= dt;
    }

    if (player.shieldTimer > 0) {
      player.shieldTimer -= dt;
    }

    if (player.hitCooldown > 0) {
      player.hitCooldown -= dt;
    }

    player.speed -= 92 * dt;
    player.speed = clamp(player.speed, 0, targetMax);
    player.vx += steering * (1.55 + player.speed / 520) * dt;
    player.vx *= controls.brake ? 0.87 : 0.92;
    player.x += player.vx * dt * 3.8;

    if (player.x < -0.86 || player.x > 0.86) {
      player.x = clamp(player.x, -0.86, 0.86);
      player.vx *= -0.35;
      player.speed *= 0.96;
    }

    player.distance += player.speed * dt;

    updateRivals(dt);
    checkEntityCollisions();
    updateMessage(dt);

    if (player.distance >= TOTAL_DISTANCE) {
      player.distance = TOTAL_DISTANCE;
      raceRunning = false;
      raceFinished = true;
      finishPlace = getPlayerPlace();
      showOverlay(
        'Checkout finish!',
        'You finished ' + ordinal(finishPlace) + ' with ' + player.score + ' donation groceries collected. Start again to chase a cleaner line.',
        'Race again'
      );
    }

    updateHud();
  }

  function updateRivals(dt) {
    var random = Math.random;

    for (var i = 0; i < rivals.length; i += 1) {
      var rival = rivals[i];
      rival.decisionTimer -= dt;
      if (rival.decisionTimer <= 0) {
        rival.targetX = LANES[Math.floor(random() * LANES.length)];
        rival.decisionTimer = 0.75 + random() * 1.4;
      }

      var catchUp = rival.distance < player.distance - 240 ? 34 : 0;
      var confidence = Math.sin((rival.distance + i * 170) / 380) * 18;
      rival.speed = rival.baseSpeed + catchUp + confidence;
      rival.distance += rival.speed * dt;

      if (rival.distance > TOTAL_DISTANCE + 150) {
        rival.distance = TOTAL_DISTANCE + 150;
      }

      var laneDelta = rival.targetX - rival.x;
      rival.vx += laneDelta * dt * 1.7;
      rival.vx *= 0.9;
      rival.x = clamp(rival.x + rival.vx * dt * 3.2, -0.82, 0.82);
    }
  }

  function checkEntityCollisions() {
    for (var i = 0; i < entities.length; i += 1) {
      var entity = entities[i];
      if (!entity.active) {
        continue;
      }

      var distanceDelta = Math.abs(entity.distance - player.distance);
      var laneDelta = Math.abs(entity.x - player.x);
      if (distanceDelta > 34 || laneDelta > 0.17) {
        continue;
      }

      if (entity.type === 'grocery') {
        entity.active = false;
        player.score += 1;
        setMessage('Donation groceries collected!');
      } else if (entity.type === 'coupon') {
        entity.active = false;
        player.score += 1;
        player.boostTimer = Math.max(player.boostTimer, 0.9);
        setMessage('Coupon boost!');
      } else if (entity.type === 'mystery') {
        entity.active = false;
        giveMysteryItem();
      } else if (player.hitCooldown <= 0) {
        handleHazard(entity);
      }
    }
  }

  function giveMysteryItem() {
    var items = ['sprint', 'shield', 'burst'];
    var item = items[Math.floor(Math.random() * items.length)];

    if (player.item) {
      player.score += 2;
      setMessage('Extra tote traded for groceries!');
    } else {
      player.item = item;
      setMessage(ITEM_NAMES[item] + ' ready!');
    }
  }

  function handleHazard(entity) {
    entity.active = false;
    player.hitCooldown = 0.8;

    if (player.shieldTimer > 0) {
      player.score += 1;
      setMessage('Shield shrugged off the mess!');
      return;
    }

    player.speed *= entity.type === 'spill' ? 0.46 : 0.58;
    player.vx *= -0.55;
    setMessage(entity.type === 'spill' ? 'Mop spill! Regain traction.' : 'Display stack! Back in the lane.');
  }

  function useItem() {
    if (!raceRunning || !player.item) {
      if (raceRunning) {
        setMessage('Find a mystery tote first.');
      }
      return;
    }

    if (player.item === 'sprint') {
      player.boostTimer = Math.max(player.boostTimer, 1.8);
      setMessage('Sprint Cart engaged!');
    } else if (player.item === 'shield') {
      player.shieldTimer = Math.max(player.shieldTimer, 5);
      setMessage('Coupon Shield active!');
    } else if (player.item === 'burst') {
      player.distance += 95;
      player.speed = Math.max(player.speed, 610);
      slowNearbyRivals();
      setMessage('Snack Burst slingshot!');
    }

    player.item = null;
    updateHud();
  }

  function slowNearbyRivals() {
    for (var i = 0; i < rivals.length; i += 1) {
      var rival = rivals[i];
      var delta = rival.distance - player.distance;
      if (delta > -120 && delta < 360) {
        rival.distance -= 42;
      }
    }
  }

  function updateMessage(dt) {
    if (message.timer > 0) {
      message.timer -= dt;
    }
  }

  function setMessage(text) {
    message.text = text;
    message.timer = 1.8;
  }

  function updateHud() {
    var lap = Math.min(TOTAL_LAPS, Math.floor(player.distance / TRACK_LENGTH) + 1);
    elements.lap.textContent = lap + '/' + TOTAL_LAPS;
    elements.place.textContent = ordinal(getPlayerPlace());
    elements.speed.textContent = Math.round(player.speed / 7.5);
    elements.item.textContent = player.item ? ITEM_NAMES[player.item] : 'None';
    elements.score.textContent = player.score;
  }

  function getPlayerPlace() {
    var racers = [{ name: 'You', distance: player.distance }];
    for (var i = 0; i < rivals.length; i += 1) {
      racers.push({
        name: rivals[i].name,
        distance: rivals[i].distance
      });
    }

    racers.sort(function(a, b) {
      return b.distance - a.distance;
    });

    for (var place = 0; place < racers.length; place += 1) {
      if (racers[place].name === 'You') {
        return place + 1;
      }
    }

    return racers.length;
  }

  function drawGame() {
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    drawStoreBackdrop();
    drawAisle();
    drawFinishLines();
    drawEntities();
    drawRivals();
    drawPlayer();
    drawRaceText();
  }

  function drawStoreBackdrop() {
    var gradient = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    gradient.addColorStop(0, '#15182b');
    gradient.addColorStop(0.55, '#243047');
    gradient.addColorStop(1, '#10131f');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    ctx.fillStyle = '#17261f';
    ctx.fillRect(0, 0, 160, HEIGHT);
    ctx.fillRect(WIDTH - 160, 0, 160, HEIGHT);

    var shelfOffset = Math.floor(player.distance * 0.28) % 86;
    for (var y = -100 + shelfOffset; y < HEIGHT + 80; y += 86) {
      drawShelf(22, y, false);
      drawShelf(WIDTH - 142, y + 26, true);
    }
  }

  function drawShelf(x, y, flip) {
    ctx.save();
    ctx.translate(x, y);
    if (flip) {
      ctx.translate(120, 0);
      ctx.scale(-1, 1);
    }

    ctx.fillStyle = 'rgba(0, 0, 0, 0.28)';
    ctx.fillRect(0, 7, 112, 48);
    ctx.fillStyle = '#2d5a36';
    ctx.fillRect(0, 0, 112, 46);
    ctx.fillStyle = '#edb713';
    ctx.fillRect(8, 8, 24, 30);
    ctx.fillStyle = '#ff6b86';
    ctx.fillRect(40, 10, 22, 28);
    ctx.fillStyle = '#44d7b6';
    ctx.fillRect(70, 6, 32, 34);
    ctx.restore();
  }

  function drawAisle() {
    var leftPoints = [];
    var rightPoints = [];
    var y;

    for (y = -30; y <= HEIGHT + 40; y += 18) {
      var delta = (HEIGHT - 105 - y) / 0.58;
      leftPoints.push(project(delta, -0.98));
      rightPoints.push(project(delta, 0.98));
    }

    ctx.beginPath();
    ctx.moveTo(leftPoints[0].x, leftPoints[0].y);
    for (var i = 1; i < leftPoints.length; i += 1) {
      ctx.lineTo(leftPoints[i].x, leftPoints[i].y);
    }
    for (var r = rightPoints.length - 1; r >= 0; r -= 1) {
      ctx.lineTo(rightPoints[r].x, rightPoints[r].y);
    }
    ctx.closePath();

    var floorGradient = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    floorGradient.addColorStop(0, '#506171');
    floorGradient.addColorStop(1, '#85919a');
    ctx.fillStyle = floorGradient;
    ctx.fill();

    drawPathLine(-0.98, 'rgba(255, 255, 255, 0.32)', 6);
    drawPathLine(0.98, 'rgba(255, 255, 255, 0.32)', 6);
    drawPathLine(-0.33, 'rgba(255, 255, 255, 0.22)', 2);
    drawPathLine(0.33, 'rgba(255, 255, 255, 0.22)', 2);

    var firstTile = Math.floor(player.distance / 160) * 160;
    for (var d = firstTile; d < player.distance + 950; d += 160) {
      var tileDelta = d - player.distance;
      var left = project(tileDelta, -0.92);
      var right = project(tileDelta, 0.92);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.16)';
      ctx.lineWidth = 2 * left.scale;
      ctx.beginPath();
      ctx.moveTo(left.x, left.y);
      ctx.lineTo(right.x, right.y);
      ctx.stroke();
    }
  }

  function drawPathLine(lane, color, width) {
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.beginPath();
    for (var y = -20; y <= HEIGHT + 20; y += 18) {
      var delta = (HEIGHT - 105 - y) / 0.58;
      var point = project(delta, lane);
      if (y === -20) {
        ctx.moveTo(point.x, point.y);
      } else {
        ctx.lineTo(point.x, point.y);
      }
    }
    ctx.stroke();
  }

  function drawFinishLines() {
    for (var lap = 1; lap <= TOTAL_LAPS; lap += 1) {
      var lineDistance = lap * TRACK_LENGTH;
      var delta = lineDistance - player.distance;
      if (delta < -60 || delta > 900) {
        continue;
      }

      var left = project(delta, -0.9);
      var right = project(delta, 0.9);
      var squares = 14;
      for (var i = 0; i < squares; i += 1) {
        var t1 = i / squares;
        var t2 = (i + 1) / squares;
        ctx.fillStyle = i % 2 === 0 ? '#ffffff' : '#11131b';
        ctx.beginPath();
        ctx.moveTo(lerp(left.x, right.x, t1), left.y - 8 * left.scale);
        ctx.lineTo(lerp(left.x, right.x, t2), left.y - 8 * left.scale);
        ctx.lineTo(lerp(left.x, right.x, t2), left.y + 8 * left.scale);
        ctx.lineTo(lerp(left.x, right.x, t1), left.y + 8 * left.scale);
        ctx.closePath();
        ctx.fill();
      }
    }
  }

  function drawEntities() {
    var visible = [];
    for (var i = 0; i < entities.length; i += 1) {
      var entity = entities[i];
      if (!entity.active) {
        continue;
      }

      var delta = entity.distance - player.distance;
      if (delta > -70 && delta < 900) {
        visible.push({
          entity: entity,
          delta: delta
        });
      }
    }

    visible.sort(function(a, b) {
      return b.delta - a.delta;
    });

    for (var v = 0; v < visible.length; v += 1) {
      var item = visible[v].entity;
      var point = project(visible[v].delta, item.x);
      drawEntity(item.type, point.x, point.y, point.scale);
    }
  }

  function drawEntity(type, x, y, scale) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);

    if (type === 'coupon') {
      ctx.fillStyle = '#edb713';
      roundedRect(-30, -12, 60, 24, 8);
      ctx.fill();
      ctx.fillStyle = '#1c160b';
      ctx.beginPath();
      ctx.moveTo(-10, -7);
      ctx.lineTo(18, 0);
      ctx.lineTo(-10, 7);
      ctx.closePath();
      ctx.fill();
    } else if (type === 'mystery') {
      ctx.fillStyle = '#8f7bff';
      roundedRect(-22, -22, 44, 44, 8);
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = 'bold 28px Arial';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('?', 0, 2);
    } else if (type === 'spill') {
      ctx.fillStyle = 'rgba(80, 200, 255, 0.78)';
      ctx.beginPath();
      ctx.ellipse(0, 0, 34, 15, -0.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = 'rgba(255, 255, 255, 0.45)';
      ctx.beginPath();
      ctx.ellipse(-9, -3, 9, 4, -0.2, 0, Math.PI * 2);
      ctx.fill();
    } else if (type === 'stack') {
      ctx.fillStyle = '#d86a32';
      ctx.fillRect(-22, -20, 24, 22);
      ctx.fillStyle = '#efb24b';
      ctx.fillRect(1, -18, 23, 20);
      ctx.fillStyle = '#b84135';
      ctx.fillRect(-12, 2, 28, 21);
    } else {
      ctx.fillStyle = '#c98b4a';
      roundedRect(-22, -17, 44, 34, 5);
      ctx.fill();
      ctx.strokeStyle = '#7c4f26';
      ctx.lineWidth = 3;
      ctx.strokeRect(-18, -13, 36, 26);
      ctx.strokeStyle = '#f2d29b';
      ctx.beginPath();
      ctx.moveTo(-18, -2);
      ctx.lineTo(18, -2);
      ctx.stroke();
    }

    ctx.restore();
  }

  function drawRivals() {
    var visible = [];
    for (var i = 0; i < rivals.length; i += 1) {
      var rival = rivals[i];
      var delta = rival.distance - player.distance;
      if (delta > -120 && delta < 940) {
        visible.push({
          rival: rival,
          delta: delta
        });
      }
    }

    visible.sort(function(a, b) {
      return b.delta - a.delta;
    });

    for (var v = 0; v < visible.length; v += 1) {
      var point = project(visible[v].delta, visible[v].rival.x);
      drawCart(point.x, point.y, point.scale * 0.72, visible[v].rival.color, visible[v].rival.name, false);
    }
  }

  function drawPlayer() {
    var point = project(0, player.x);
    var bob = Math.sin(performance.now() / 90) * Math.min(3, player.speed / 180);
    drawCart(point.x, point.y + bob, 1.04, player.color, 'You', true);

    if (player.shieldTimer > 0) {
      ctx.strokeStyle = 'rgba(237, 183, 19, 0.78)';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(point.x, point.y, 46, 0, Math.PI * 2);
      ctx.stroke();
    }
  }

  function drawCart(x, y, scale, color, label, isPlayer) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.shadowColor = 'rgba(0, 0, 0, 0.35)';
    ctx.shadowBlur = 12;
    ctx.shadowOffsetY = 7;

    ctx.fillStyle = color;
    ctx.strokeStyle = '#171717';
    ctx.lineWidth = 4;

    ctx.beginPath();
    ctx.moveTo(-26, -20);
    ctx.lineTo(26, -20);
    ctx.lineTo(18, 26);
    ctx.lineTo(-18, 26);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.shadowColor = 'transparent';
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.46)';
    ctx.lineWidth = 2;
    for (var i = -12; i <= 12; i += 12) {
      ctx.beginPath();
      ctx.moveTo(i, -15);
      ctx.lineTo(i * 0.65, 20);
      ctx.stroke();
    }

    ctx.strokeStyle = '#171717';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-18, -20);
    ctx.quadraticCurveTo(0, -42, 18, -20);
    ctx.stroke();

    ctx.fillStyle = '#101010';
    ctx.beginPath();
    ctx.arc(-17, 31, 7, 0, Math.PI * 2);
    ctx.arc(17, 31, 7, 0, Math.PI * 2);
    ctx.fill();

    if (label) {
      ctx.fillStyle = '#ffffff';
      ctx.font = isPlayer ? 'bold 16px Arial' : 'bold 14px Arial';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'bottom';
      ctx.fillText(label, 0, -49);
    }

    ctx.restore();
  }

  function drawRaceText() {
    var lapProgress = (player.distance % TRACK_LENGTH) / TRACK_LENGTH;
    var barWidth = 240;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.38)';
    roundedRect(24, 24, barWidth, 16, 8);
    ctx.fill();
    ctx.fillStyle = '#edb713';
    roundedRect(24, 24, barWidth * lapProgress, 16, 8);
    ctx.fill();

    if (message.timer > 0) {
      ctx.save();
      ctx.globalAlpha = Math.min(1, message.timer);
      ctx.fillStyle = 'rgba(16, 19, 31, 0.78)';
      roundedRect(WIDTH / 2 - 210, 34, 420, 48, 24);
      ctx.fill();
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 20px Arial';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(message.text, WIDTH / 2, 58);
      ctx.restore();
    }

    if (!raceRunning && !raceFinished) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.72)';
      ctx.font = 'bold 19px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('Tap Start Race to roll through the supermarket aisles.', WIDTH / 2, HEIGHT - 34);
    }
  }

  function project(delta, lane) {
    var y = HEIGHT - 105 - delta * 0.58;
    var t = clamp(y / HEIGHT, 0, 1);
    var perspective = 0.36 + 0.7 * t;
    var center = WIDTH / 2 + curveAt(player.distance + delta) * WIDTH * 0.22 * perspective;
    return {
      x: center + lane * WIDTH * 0.34 * perspective,
      y: y,
      scale: 0.32 + 0.86 * t,
      perspective: perspective
    };
  }

  function curveAt(distance) {
    return Math.sin(distance / 640) * 0.18 + Math.sin(distance / 1250) * 0.1;
  }

  function roundedRect(x, y, width, height, radius) {
    var safeRadius = Math.min(radius, width / 2, height / 2);
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
    ctx.closePath();
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function ordinal(number) {
    if (number === 1) {
      return '1st';
    }
    if (number === 2) {
      return '2nd';
    }
    if (number === 3) {
      return '3rd';
    }
    return number + 'th';
  }

  function bindControls() {
    document.addEventListener('keydown', function(event) {
      if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
        controls.left = true;
      } else if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
        controls.right = true;
      } else if (event.key === 'ArrowUp' || event.key === 'w' || event.key === 'W') {
        controls.boost = true;
      } else if (event.key === 'ArrowDown' || event.key === 's' || event.key === 'S') {
        controls.brake = true;
      } else if (event.key === ' ' || event.key === 'e' || event.key === 'E') {
        event.preventDefault();
        useItem();
      }
    });

    document.addEventListener('keyup', function(event) {
      if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
        controls.left = false;
      } else if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
        controls.right = false;
      } else if (event.key === 'ArrowUp' || event.key === 'w' || event.key === 'W') {
        controls.boost = false;
      } else if (event.key === 'ArrowDown' || event.key === 's' || event.key === 'S') {
        controls.brake = false;
      }
    });

    var buttons = document.querySelectorAll('[data-action]');
    for (var i = 0; i < buttons.length; i += 1) {
      bindTouchButton(buttons[i]);
    }

    if (elements.start) {
      elements.start.addEventListener('click', startRace);
    }
  }

  function bindTouchButton(button) {
    var action = button.getAttribute('data-action');

    function setActive(active, event) {
      if (event) {
        event.preventDefault();
      }

      if (action === 'item') {
        if (active) {
          useItem();
          button.classList.add('is-active');
          window.setTimeout(function() {
            button.classList.remove('is-active');
          }, 120);
        }
        return;
      }

      controls[action] = active;
      button.classList.toggle('is-active', active);
    }

    button.addEventListener('touchstart', function(event) {
      setActive(true, event);
    }, { passive: false });
    button.addEventListener('touchend', function(event) {
      setActive(false, event);
    }, { passive: false });
    button.addEventListener('touchcancel', function(event) {
      setActive(false, event);
    }, { passive: false });
    button.addEventListener('mousedown', function(event) {
      setActive(true, event);
    });
    button.addEventListener('mouseup', function(event) {
      setActive(false, event);
    });
    button.addEventListener('mouseleave', function(event) {
      setActive(false, event);
    });
  }

  setCanvasScale();
  resetRace();
  bindControls();
  window.addEventListener('resize', setCanvasScale);
  requestAnimationFrame(gameLoop);
})();
