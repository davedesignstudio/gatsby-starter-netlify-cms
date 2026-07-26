(function () {
  'use strict';

  var canvas = document.getElementById('store-racer-canvas');
  if (!canvas) {
    return;
  }

  var ctx = canvas.getContext('2d');
  var overlay = document.getElementById('store-racer-overlay');
  var overlayTitle = document.getElementById('store-racer-overlay-title');
  var overlayCopy = document.getElementById('store-racer-overlay-copy');
  var startButton = document.getElementById('store-racer-start');
  var statRank = document.getElementById('store-racer-rank');
  var statLap = document.getElementById('store-racer-lap');
  var statBoost = document.getElementById('store-racer-boost');
  var statTimer = document.getElementById('store-racer-timer');
  var controlButtons = document.querySelectorAll('[data-control]');

  var logicalSize = { width: 560, height: 720 };
  var totalLaps = 3;
  var lapDistance = 940;
  var totalDistance = totalLaps * lapDistance;
  var rivalNames = ['Flash Freeze', 'Aisle Ace', 'Turbo Tote', 'Mint Cart', 'Midnight Run'];
  var rivalColors = ['#8ff7ff', '#ff92db', '#ffd65b', '#82f69d', '#9fa8ff'];
  var itemTypes = {
    display: { kind: 'hazard', color: '#ff7f50', label: 'Display' },
    sign: { kind: 'hazard', color: '#ffd65b', label: 'Sign' },
    spill: { kind: 'hazard', color: '#9b59b6', label: 'Spill' },
    battery: { kind: 'pickup', color: '#82f69d', label: 'Battery' },
    snack: { kind: 'pickup', color: '#8ff7ff', label: 'Snack' }
  };

  var keys = {
    left: false,
    right: false,
    boost: false
  };

  var state = {
    running: false,
    finished: false,
    finishHandled: false,
    playerLaneTarget: 1,
    playerLaneVisual: 1,
    playerSpeed: 280,
    slowdown: 0,
    boostMeter: 68,
    boostActive: false,
    raceClock: 0,
    timeLimit: 75,
    progress: 0,
    scroll: 0,
    lap: 1,
    rank: 6,
    flashTimer: 0,
    spawnTimer: 0,
    itemPulse: 0,
    drift: 0,
    items: [],
    rivals: [],
    countdown: 0,
    bannerText: 'Tap start to race.',
    lastTimestamp: 0,
    bestFinish: null
  };

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function ordinal(value) {
    var mod10 = value % 10;
    var mod100 = value % 100;

    if (mod10 === 1 && mod100 !== 11) {
      return value + 'st';
    }
    if (mod10 === 2 && mod100 !== 12) {
      return value + 'nd';
    }
    if (mod10 === 3 && mod100 !== 13) {
      return value + 'rd';
    }
    return value + 'th';
  }

  function randomBetween(min, max) {
    return min + Math.random() * (max - min);
  }

  function pick(array) {
    return array[Math.floor(Math.random() * array.length)];
  }

  function laneCenter(lane, y) {
    var t = y / logicalSize.height;
    var width = roadWidthAt(y);
    var center =
      logicalSize.width / 2 +
      Math.sin(state.progress * 0.012 + t * 4.6) * 28 +
      Math.cos(state.progress * 0.008 - t * 3.1) * 18;

    return center - width / 2 + width * ((lane + 0.5) / 4);
  }

  function roadWidthAt(y) {
    var t = y / logicalSize.height;
    return 176 + t * 208;
  }

  function createRivals() {
    state.rivals = rivalNames.map(function (name, index) {
      return {
        name: name,
        color: rivalColors[index],
        lane: index % 4,
        laneVisual: index % 4,
        laneChangeTimer: randomBetween(0.6, 1.8),
        pace: randomBetween(37.5, 41.5),
        progress: randomBetween(-30, 60)
      };
    });
  }

  function resetRace() {
    state.running = false;
    state.finished = false;
    state.finishHandled = false;
    state.playerLaneTarget = 1;
    state.playerLaneVisual = 1;
    state.playerSpeed = 280;
    state.slowdown = 0;
    state.boostMeter = 68;
    state.boostActive = false;
    state.raceClock = 0;
    state.progress = 0;
    state.scroll = 0;
    state.lap = 1;
    state.rank = 6;
    state.flashTimer = 0;
    state.spawnTimer = 0.5;
    state.itemPulse = 0;
    state.drift = 0;
    state.items = [];
    state.countdown = 3;
    state.bannerText = '3';
    createRivals();
    syncHud();
    showOverlay(false);
  }

  function moveLane(delta) {
    state.playerLaneTarget = clamp(state.playerLaneTarget + delta, 0, 3);
  }

  function startRace() {
    resetRace();
    state.running = true;
  }

  function endRace() {
    state.running = false;
    state.finished = true;
    state.finishHandled = true;
    showOverlay(true);

    if (!state.bestFinish || state.rank < state.bestFinish.rank) {
      state.bestFinish = {
        rank: state.rank,
        time: state.raceClock
      };
      try {
        window.localStorage.setItem('storeCartSprintBest', JSON.stringify(state.bestFinish));
      } catch (error) {
        // Local storage is optional for this prototype.
      }
    }

    overlayTitle.textContent = state.rank === 1 ? 'Store champion!' : ordinal(state.rank) + ' place finish';
    overlayCopy.textContent =
      'You cleared ' +
      totalLaps +
      ' laps in ' +
      state.raceClock.toFixed(1) +
      's. Recharge, tighten your lines, and race again for a better finish.';
    startButton.textContent = 'Restart race';
  }

  function showOverlay(visible) {
    overlay.classList.toggle('hidden', !visible);
  }

  function spawnItem() {
    var itemKeys = Object.keys(itemTypes);
    var key = itemKeys[Math.floor(Math.random() * itemKeys.length)];
    var item = itemTypes[key];
    state.items.push({
      type: key,
      lane: Math.floor(Math.random() * 4),
      y: -60,
      speed: randomBetween(16, 40),
      rotation: randomBetween(-0.08, 0.08),
      wobble: randomBetween(0, Math.PI * 2),
      kind: item.kind,
      color: item.color,
      label: item.label
    });
  }

  function updatePlayer(dt) {
    if (keys.left) {
      moveLane(-1);
      keys.left = false;
    }
    if (keys.right) {
      moveLane(1);
      keys.right = false;
    }

    state.playerLaneVisual += (state.playerLaneTarget - state.playerLaneVisual) * Math.min(1, dt * 10);
    state.boostActive = keys.boost && state.boostMeter > 4 && state.countdown <= 0;

    var targetSpeed = 286;
    if (state.boostActive) {
      targetSpeed += 132;
      state.boostMeter -= 32 * dt;
      state.bannerText = 'Boosting through produce row!';
    } else {
      state.boostMeter += 11 * dt;
    }

    state.boostMeter = clamp(state.boostMeter, 0, 100);
    state.slowdown = Math.max(0, state.slowdown - 120 * dt);
    targetSpeed -= state.slowdown;
    state.playerSpeed += (targetSpeed - state.playerSpeed) * Math.min(1, dt * 2.8);

    if (state.countdown > 0) {
      state.countdown = Math.max(0, state.countdown - dt);
      state.playerSpeed = 0;
      if (state.countdown > 2) {
        state.bannerText = '3';
      } else if (state.countdown > 1) {
        state.bannerText = '2';
      } else if (state.countdown > 0) {
        state.bannerText = '1';
      } else {
        state.bannerText = 'Go!';
      }
      return;
    }

    state.raceClock += dt;
    state.progress += state.playerSpeed * 0.14 * dt;
    state.scroll += state.playerSpeed * dt;
    state.itemPulse += dt * 3;
    state.flashTimer = Math.max(0, state.flashTimer - dt);
    state.lap = clamp(Math.floor(state.progress / lapDistance) + 1, 1, totalLaps);
  }

  function updateRivals(dt) {
    state.rivals.forEach(function (rival) {
      rival.laneChangeTimer -= dt;
      if (rival.laneChangeTimer <= 0) {
        rival.lane = clamp(rival.lane + pick([-1, 1]), 0, 3);
        rival.laneChangeTimer = randomBetween(0.9, 2.4);
      }

      rival.laneVisual += (rival.lane - rival.laneVisual) * Math.min(1, dt * 4);
      rival.pace += randomBetween(-0.55, 0.55) * dt;
      rival.pace = clamp(rival.pace, 36.5, 43.5);
      rival.progress += rival.pace * dt;
    });

    state.rank = 1;
    state.rivals.forEach(function (rival) {
      if (rival.progress > state.progress) {
        state.rank += 1;
      }
    });
  }

  function handleItemCollision(item) {
    if (item.kind === 'pickup') {
      state.boostMeter = clamp(state.boostMeter + 24, 0, 100);
      state.bannerText = item.label + ' boost grabbed!';
      return;
    }

    state.slowdown = clamp(state.slowdown + 90, 0, 160);
    state.flashTimer = 0.3;
    state.boostMeter = clamp(state.boostMeter - 12, 0, 100);
    state.bannerText = 'Watch the ' + item.label.toLowerCase() + '!';
  }

  function updateItems(dt) {
    if (state.countdown <= 0) {
      state.spawnTimer -= dt;
      if (state.spawnTimer <= 0) {
        spawnItem();
        state.spawnTimer = randomBetween(0.45, 0.95);
      }
    }

    var playerLane = Math.round(state.playerLaneVisual);
    var playerY = logicalSize.height - 150;

    state.items = state.items.filter(function (item) {
      item.y += (state.playerSpeed + item.speed) * dt;
      item.wobble += dt * 3;

      if (Math.abs(item.y - playerY) < 54 && Math.abs(item.lane - playerLane) < 0.45 && state.countdown <= 0) {
        handleItemCollision(item);
        return false;
      }

      return item.y < logicalSize.height + 80;
    });
  }

  function updateGame(dt) {
    updatePlayer(dt);
    if (state.countdown > 0) {
      syncHud();
      return;
    }

    updateRivals(dt);
    updateItems(dt);

    if ((state.progress >= totalDistance || state.raceClock >= state.timeLimit) && !state.finishHandled) {
      endRace();
    }

    syncHud();
  }

  function syncHud() {
    statRank.textContent = ordinal(state.rank);
    statLap.textContent = state.lap + ' / ' + totalLaps;
    statBoost.textContent = Math.round(state.boostMeter) + '%';
    statTimer.textContent = Math.max(0, state.timeLimit - state.raceClock).toFixed(1) + 's';
  }

  function drawBackground() {
    var gradient = ctx.createLinearGradient(0, 0, 0, logicalSize.height);
    gradient.addColorStop(0, '#16305d');
    gradient.addColorStop(0.45, '#12264a');
    gradient.addColorStop(1, '#0a1426');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, logicalSize.width, logicalSize.height);

    for (var i = 0; i < 40; i += 1) {
      var y = (i * 24 + (state.scroll * 0.6) % 24) % (logicalSize.height + 24) - 24;
      ctx.fillStyle = i % 2 === 0 ? 'rgba(255,255,255,0.02)' : 'rgba(255,255,255,0.01)';
      ctx.fillRect(0, y, logicalSize.width, 14);
    }
  }

  function drawShelves() {
    for (var i = 0; i < 13; i += 1) {
      var y = (i * 64 + state.scroll * 0.8) % (logicalSize.height + 80) - 80;
      var roadWidth = roadWidthAt(y);
      var roadCenter = laneCenter(1.5, y);
      var shelfWidth = 72 + (y / logicalSize.height) * 36;
      var shelfHeight = 44 + (y / logicalSize.height) * 18;
      var leftX = roadCenter - roadWidth / 2 - shelfWidth - 18;
      var rightX = roadCenter + roadWidth / 2 + 18;

      ctx.fillStyle = i % 2 === 0 ? '#1c2c49' : '#22385d';
      ctx.fillRect(leftX, y, shelfWidth, shelfHeight);
      ctx.fillRect(rightX, y, shelfWidth, shelfHeight);

      ctx.fillStyle = i % 2 === 0 ? '#ffd65b' : '#8ff7ff';
      ctx.fillRect(leftX + 8, y + 8, shelfWidth - 16, 7);
      ctx.fillRect(rightX + 8, y + 8, shelfWidth - 16, 7);
    }
  }

  function drawRoad() {
    for (var y = 0; y < logicalSize.height; y += 12) {
      var roadWidth = roadWidthAt(y);
      var roadCenter = laneCenter(1.5, y);
      var stripeTone = (Math.floor((y + state.scroll * 0.45) / 24) % 2 === 0)
        ? 'rgba(42, 54, 84, 0.96)'
        : 'rgba(34, 45, 70, 0.96)';

      ctx.fillStyle = stripeTone;
      ctx.fillRect(roadCenter - roadWidth / 2, y, roadWidth, 14);
    }

    for (var laneIndex = 1; laneIndex < 4; laneIndex += 1) {
      for (var markerY = -24; markerY < logicalSize.height; markerY += 42) {
        var animatedY = markerY + (state.scroll * 1.2) % 42;
        var x = laneCenter(laneIndex - 0.5, animatedY);
        var lineHeight = 22 + (animatedY / logicalSize.height) * 8;
        ctx.fillStyle = 'rgba(244, 247, 255, 0.26)';
        ctx.fillRect(x - 3, animatedY, 6, lineHeight);
      }
    }

    for (var edgeY = 0; edgeY < logicalSize.height; edgeY += 22) {
      var edgeWidth = roadWidthAt(edgeY);
      var edgeCenter = laneCenter(1.5, edgeY);
      ctx.fillStyle = edgeY % 44 === 0 ? '#ff9f43' : '#ffd65b';
      ctx.fillRect(edgeCenter - edgeWidth / 2 - 8, edgeY, 8, 18);
      ctx.fillRect(edgeCenter + edgeWidth / 2, edgeY, 8, 18);
    }
  }

  function drawCart(x, y, scale, color, tilt) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(tilt);
    ctx.scale(scale, scale);

    ctx.fillStyle = 'rgba(0, 0, 0, 0.28)';
    ctx.fillRect(-18, 20, 36, 10);

    ctx.fillStyle = '#111827';
    ctx.fillRect(-20, -6, 8, 14);
    ctx.fillRect(12, -6, 8, 14);
    ctx.fillRect(-20, 24, 8, 14);
    ctx.fillRect(12, 24, 8, 14);

    ctx.fillStyle = color;
    ctx.fillRect(-22, 0, 44, 28);
    ctx.fillStyle = 'rgba(255,255,255,0.18)';
    ctx.fillRect(-16, 4, 32, 7);
    ctx.fillStyle = '#dbeafe';
    ctx.fillRect(-10, -12, 20, 12);
    ctx.strokeStyle = '#dbeafe';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-14, -6);
    ctx.lineTo(0, -20);
    ctx.lineTo(14, -6);
    ctx.stroke();

    ctx.restore();
  }

  function drawItem(item) {
    var x = laneCenter(item.lane, item.y) + Math.sin(item.wobble) * 8;
    var scale = 0.55 + (item.y / logicalSize.height) * 0.72;

    ctx.save();
    ctx.translate(x, item.y);
    ctx.rotate(item.rotation + Math.sin(item.wobble) * 0.07);
    ctx.scale(scale, scale);

    if (item.type === 'display') {
      ctx.fillStyle = '#8d4e2c';
      ctx.fillRect(-18, -18, 36, 30);
      ctx.fillStyle = '#ff7f50';
      ctx.fillRect(-22, 12, 44, 10);
    } else if (item.type === 'sign') {
      ctx.fillStyle = '#2c3e50';
      ctx.fillRect(-4, -22, 8, 30);
      ctx.fillStyle = '#ffd65b';
      ctx.fillRect(-20, -16, 40, 20);
      ctx.fillStyle = '#1f2937';
      ctx.fillRect(-8, 8, 16, 10);
    } else if (item.type === 'spill') {
      ctx.fillStyle = '#9b59b6';
      ctx.beginPath();
      ctx.moveTo(-22, 6);
      ctx.bezierCurveTo(-8, -18, 12, -18, 24, 2);
      ctx.bezierCurveTo(12, 22, -10, 22, -22, 6);
      ctx.fill();
    } else {
      ctx.fillStyle = item.color;
      ctx.beginPath();
      ctx.arc(0, 0, 18, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#10213d';
      ctx.fillRect(-4, -16, 8, 32);
      ctx.fillRect(-16, -4, 32, 8);
    }

    ctx.restore();
  }

  function drawRivals() {
    state.rivals.forEach(function (rival) {
      var relativeProgress = rival.progress - state.progress;
      if (relativeProgress < -140 || relativeProgress > 460) {
        return;
      }

      var y = logicalSize.height - 160 - relativeProgress * 1.3;
      var scale = 0.56 + (y / logicalSize.height) * 0.4;
      var x = laneCenter(rival.laneVisual, y);
      drawCart(x, y, scale, rival.color, (rival.laneVisual - 1.5) * 0.08);
    });
  }

  function drawPlayer() {
    var y = logicalSize.height - 150;
    var x = laneCenter(state.playerLaneVisual, y);
    var shake = state.flashTimer > 0 ? Math.sin(state.flashTimer * 55) * 7 : 0;

    if (state.boostActive) {
      ctx.fillStyle = 'rgba(255, 214, 91, 0.38)';
      ctx.beginPath();
      ctx.moveTo(x - 18, y + 28);
      ctx.lineTo(x, y + 86 + Math.sin(state.itemPulse * 2) * 8);
      ctx.lineTo(x + 18, y + 28);
      ctx.closePath();
      ctx.fill();
    }

    drawCart(x + shake, y, 1.08, '#ff6f91', (state.playerLaneTarget - state.playerLaneVisual) * 0.24);
  }

  function drawHud() {
    ctx.save();
    ctx.fillStyle = 'rgba(8, 16, 30, 0.72)';
    ctx.fillRect(18, 16, 188, 92);
    ctx.fillRect(logicalSize.width - 174, 16, 156, 92);

    ctx.fillStyle = '#edf2ff';
    ctx.font = '700 18px Arial';
    ctx.fillText('Lap ' + state.lap + ' / ' + totalLaps, 34, 44);
    ctx.fillText(ordinal(state.rank), 34, 72);
    ctx.font = '12px Arial';
    ctx.fillStyle = 'rgba(237, 242, 255, 0.75)';
    ctx.fillText('Place', 82, 72);
    ctx.fillText('Clock', logicalSize.width - 150, 44);
    ctx.fillText(Math.max(0, state.timeLimit - state.raceClock).toFixed(1) + 's', logicalSize.width - 150, 72);

    ctx.fillStyle = 'rgba(255,255,255,0.14)';
    ctx.fillRect(18, logicalSize.height - 62, logicalSize.width - 36, 24);
    ctx.fillStyle = state.boostActive ? '#ffd65b' : '#82f69d';
    ctx.fillRect(18, logicalSize.height - 62, (logicalSize.width - 36) * (state.boostMeter / 100), 24);
    ctx.fillStyle = '#0a1223';
    ctx.font = '700 12px Arial';
    ctx.fillText('Boost', 28, logicalSize.height - 46);

    if (state.bannerText) {
      ctx.fillStyle = state.countdown > 0 ? '#ffd65b' : '#edf2ff';
      ctx.font = state.countdown > 0 ? '700 42px Arial' : '700 16px Arial';
      var measured = ctx.measureText(state.bannerText).width;
      ctx.fillText(state.bannerText, logicalSize.width / 2 - measured / 2, 118);
    }

    ctx.restore();
  }

  function drawFinishRibbon() {
    if (!state.finished) {
      return;
    }

    ctx.save();
    ctx.fillStyle = 'rgba(8, 16, 30, 0.56)';
    ctx.fillRect(90, logicalSize.height / 2 - 36, logicalSize.width - 180, 72);
    ctx.fillStyle = '#ffd65b';
    ctx.font = '700 28px Arial';
    var label = 'Finish - ' + ordinal(state.rank);
    var measured = ctx.measureText(label).width;
    ctx.fillText(label, logicalSize.width / 2 - measured / 2, logicalSize.height / 2 + 10);
    ctx.restore();
  }

  function drawFrame() {
    drawBackground();
    drawShelves();
    drawRoad();
    state.items.forEach(drawItem);
    drawRivals();
    drawPlayer();
    drawHud();
    drawFinishRibbon();
  }

  function resizeCanvas() {
    var container = canvas.parentElement;
    var width = container.clientWidth;
    var height = Math.round(width * (logicalSize.height / logicalSize.width));
    var dpr = window.devicePixelRatio || 1;

    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.height = height + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.scale(width / logicalSize.width, height / logicalSize.height);
  }

  function loop(timestamp) {
    if (!state.lastTimestamp) {
      state.lastTimestamp = timestamp;
    }

    var dt = Math.min(0.033, (timestamp - state.lastTimestamp) / 1000);
    state.lastTimestamp = timestamp;

    if (state.running) {
      updateGame(dt);
    }
    drawFrame();
    window.requestAnimationFrame(loop);
  }

  function onKeyChange(event, isPressed) {
    if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
      if (isPressed) {
        keys.left = true;
      }
      event.preventDefault();
    } else if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
      if (isPressed) {
        keys.right = true;
      }
      event.preventDefault();
    } else if (event.key === ' ' || event.code === 'Space') {
      keys.boost = isPressed;
      event.preventDefault();
    }
  }

  var pointerStartX = null;

  canvas.addEventListener('pointerdown', function (event) {
    pointerStartX = event.clientX;
    canvas.setPointerCapture(event.pointerId);
  });

  canvas.addEventListener('pointerup', function (event) {
    if (pointerStartX === null) {
      return;
    }

    var delta = event.clientX - pointerStartX;
    if (delta < -24) {
      moveLane(-1);
    } else if (delta > 24) {
      moveLane(1);
    } else {
      keys.boost = true;
      window.setTimeout(function () {
        keys.boost = false;
      }, 180);
    }

    pointerStartX = null;
  });

  controlButtons.forEach(function (button) {
    var control = button.getAttribute('data-control');

    button.addEventListener('pointerdown', function (event) {
      event.preventDefault();
      if (control === 'left') {
        moveLane(-1);
      } else if (control === 'right') {
        moveLane(1);
      } else if (control === 'boost') {
        keys.boost = true;
      }
    });

    button.addEventListener('pointerup', function (event) {
      event.preventDefault();
      if (control === 'boost') {
        keys.boost = false;
      }
    });

    button.addEventListener('pointerleave', function () {
      if (control === 'boost') {
        keys.boost = false;
      }
    });
  });

  startButton.addEventListener('click', function () {
    startRace();
    startButton.blur();
  });

  window.addEventListener('keydown', function (event) {
    onKeyChange(event, true);
  });

  window.addEventListener('keyup', function (event) {
    onKeyChange(event, false);
  });

  window.addEventListener('resize', resizeCanvas);

  try {
    state.bestFinish = JSON.parse(window.localStorage.getItem('storeCartSprintBest'));
  } catch (error) {
    state.bestFinish = null;
  }

  resizeCanvas();
  syncHud();
  drawFrame();
  window.requestAnimationFrame(loop);
})();
