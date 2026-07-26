(function () {
  var root = document.querySelector('[data-cart-racer]');
  if (!root) {
    return;
  }

  var canvas = document.getElementById('cart-racer-canvas');
  var ctx = canvas.getContext('2d');
  var startPanel = root.querySelector('[data-panel="start"]');
  var finishPanel = root.querySelector('[data-panel="finish"]');
  var finishTitle = root.querySelector('[data-finish="title"]');
  var finishSummary = root.querySelector('[data-finish="summary"]');
  var hud = {
    lap: root.querySelector('[data-hud="lap"]'),
    speed: root.querySelector('[data-hud="speed"]'),
    place: root.querySelector('[data-hud="place"]'),
    boost: root.querySelector('[data-hud="boost"]')
  };

  var COURSE = {
    width: 480,
    height: 720,
    leftEdge: 66,
    rightEdge: 414,
    lapLength: 3600,
    totalLaps: 3,
    playerY: 552
  };
  var TOTAL_DISTANCE = COURSE.lapLength * COURSE.totalLaps;

  var controls = {
    left: false,
    right: false,
    boost: false
  };
  var state;
  var pickups = [];
  var hazards = [];
  var rivals = [];
  var lastTime = performance.now();

  function createState() {
    return {
      running: false,
      finished: false,
      x: 240,
      distance: 0,
      speed: 0,
      boost: 1,
      boostTime: 0,
      bumpTimer: 0,
      shake: 0,
      elapsed: 0,
      finishPlace: 4
    };
  }

  function resetRace() {
    state = createState();
    pickups = buildPickups();
    hazards = buildHazards();
    rivals = [
      { name: 'Blue', color: '#28b7ff', distance: -110, speed: 350, lane: 137, sway: 0.0042 },
      { name: 'Lime', color: '#8ff05a', distance: -40, speed: 338, lane: 240, sway: 0.0036 },
      { name: 'Pink', color: '#ff68ad', distance: -165, speed: 362, lane: 340, sway: 0.0049 }
    ];
    updateHud();
  }

  function buildPickups() {
    var laneXs = [122, 180, 240, 300, 358];
    var result = [];
    var index = 0;
    for (var d = 260; d < TOTAL_DISTANCE - 160; d += 300) {
      result.push({
        distance: d + ((index * 47) % 90),
        x: laneXs[(index * 2 + 1) % laneXs.length],
        taken: false
      });
      index += 1;
    }
    return result;
  }

  function buildHazards() {
    var laneXs = [112, 168, 226, 282, 344, 374];
    var types = ['puddle', 'cereal', 'display'];
    var result = [];
    var index = 0;
    for (var d = 430; d < TOTAL_DISTANCE - 100; d += 235) {
      result.push({
        distance: d + ((index * 83) % 120),
        x: laneXs[(index * 3 + 2) % laneXs.length],
        type: types[index % types.length],
        hit: false
      });
      index += 1;
    }
    return result;
  }

  function startRace() {
    resetRace();
    state.running = true;
    state.elapsed = 0;
    startPanel.classList.add('is-hidden');
    finishPanel.classList.add('is-hidden');
    lastTime = performance.now();
  }

  function finishRace() {
    state.running = false;
    state.finished = true;
    state.finishPlace = getPlace();
    finishTitle.textContent = state.finishPlace === 1 ? 'Checkout champion!' : 'Race complete';
    finishSummary.textContent = 'You finished ' + rankLabel(state.finishPlace) +
      ' in ' + formatTime(state.elapsed) + '. Grab more coupons and try for first place.';
    finishPanel.classList.remove('is-hidden');
  }

  function update(dt) {
    if (!state.running || state.finished) {
      return;
    }

    state.elapsed += dt;
    state.bumpTimer = Math.max(0, state.bumpTimer - dt);
    state.shake = Math.max(0, state.shake - dt * 18);

    var steering = 0;
    if (controls.left) {
      steering -= 1;
    }
    if (controls.right) {
      steering += 1;
    }

    var targetMax = state.boostTime > 0 ? 560 : 410;
    var acceleration = state.boostTime > 0 ? 260 : 118;
    state.speed += acceleration * dt;
    if (state.speed > targetMax) {
      state.speed -= 130 * dt;
    }
    state.speed = clamp(state.speed, 0, targetMax);

    if (controls.boost && state.boost >= 1 && state.boostTime <= 0) {
      state.boost = 0;
      state.boostTime = 1.35;
      state.speed = Math.max(state.speed, 455);
    }

    state.boostTime = Math.max(0, state.boostTime - dt);
    if (state.boostTime <= 0) {
      state.boost = clamp(state.boost + dt * 0.045, 0, 1);
    }

    state.x += steering * (175 + state.speed * 0.22) * dt;
    state.x = clamp(state.x, COURSE.leftEdge + 22, COURSE.rightEdge - 22);
    state.distance += state.speed * dt;

    updateRivals(dt);
    checkPickupCollisions();
    checkHazardCollisions();
    checkRivalCollisions();

    if (state.distance >= TOTAL_DISTANCE) {
      state.distance = TOTAL_DISTANCE;
      finishRace();
    }

    updateHud();
  }

  function updateRivals(dt) {
    for (var i = 0; i < rivals.length; i += 1) {
      var rival = rivals[i];
      var rubberBand = 0;
      var gap = state.distance - rival.distance;
      if (gap > 540) {
        rubberBand = 72;
      } else if (gap < -540) {
        rubberBand = -44;
      }
      rival.distance += (rival.speed + rubberBand + Math.sin(state.elapsed * 2 + i) * 12) * dt;
      rival.distance = Math.min(rival.distance, TOTAL_DISTANCE + 220);
    }
  }

  function checkPickupCollisions() {
    for (var i = 0; i < pickups.length; i += 1) {
      var pickup = pickups[i];
      if (pickup.taken) {
        continue;
      }
      var dy = pickup.distance - state.distance;
      if (Math.abs(dy) < 46 && Math.abs(pickup.x - state.x) < 34) {
        pickup.taken = true;
        state.boost = clamp(state.boost + 0.55, 0, 1);
        state.speed = Math.min(state.speed + 48, 500);
      }
    }
  }

  function checkHazardCollisions() {
    for (var i = 0; i < hazards.length; i += 1) {
      var hazard = hazards[i];
      if (hazard.hit) {
        continue;
      }
      var dy = hazard.distance - state.distance;
      if (Math.abs(dy) < 44 && Math.abs(hazard.x - state.x) < 36) {
        hazard.hit = true;
        state.speed *= hazard.type === 'puddle' ? 0.56 : 0.66;
        state.shake = 9;
      }
    }
  }

  function checkRivalCollisions() {
    if (state.bumpTimer > 0) {
      return;
    }
    for (var i = 0; i < rivals.length; i += 1) {
      var rival = rivals[i];
      var rivalX = rival.lane + Math.sin(rival.distance * rival.sway) * 28;
      var dy = rival.distance - state.distance;
      if (Math.abs(dy) < 54 && Math.abs(rivalX - state.x) < 42) {
        state.bumpTimer = 0.55;
        state.speed *= 0.76;
        state.x += state.x < rivalX ? -24 : 24;
        state.x = clamp(state.x, COURSE.leftEdge + 22, COURSE.rightEdge - 22);
        state.shake = 7;
        break;
      }
    }
  }

  function render() {
    ctx.clearRect(0, 0, COURSE.width, COURSE.height);
    ctx.save();
    if (state.shake > 0) {
      ctx.translate((Math.random() - 0.5) * state.shake, (Math.random() - 0.5) * state.shake);
    }

    drawStoreFloor();
    drawTrackLines();
    drawFinishLines();
    drawCourseObjects();
    drawRivals();
    drawPlayer();
    drawProgressMeter();
    drawSpeedGlow();

    ctx.restore();
  }

  function drawStoreFloor() {
    var scroll = (state.distance * 0.42) % 96;
    var aisleGradient = ctx.createLinearGradient(COURSE.leftEdge, 0, COURSE.rightEdge, 0);
    aisleGradient.addColorStop(0, '#26394b');
    aisleGradient.addColorStop(0.5, '#344b60');
    aisleGradient.addColorStop(1, '#26394b');

    ctx.fillStyle = '#101923';
    ctx.fillRect(0, 0, COURSE.width, COURSE.height);
    ctx.fillStyle = aisleGradient;
    ctx.fillRect(COURSE.leftEdge, 0, COURSE.rightEdge - COURSE.leftEdge, COURSE.height);

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
    ctx.lineWidth = 1;
    for (var y = -96 + scroll; y < COURSE.height + 96; y += 48) {
      ctx.beginPath();
      ctx.moveTo(COURSE.leftEdge, y);
      ctx.lineTo(COURSE.rightEdge, y);
      ctx.stroke();
    }
    for (var x = COURSE.leftEdge + 58; x < COURSE.rightEdge; x += 58) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, COURSE.height);
      ctx.stroke();
    }

    drawShelves(0, COURSE.leftEdge - 14, scroll, true);
    drawShelves(COURSE.rightEdge + 14, COURSE.width - COURSE.rightEdge - 14, scroll, false);
  }

  function drawShelves(x, width, scroll, leftSide) {
    ctx.fillStyle = '#1a2632';
    ctx.fillRect(x, 0, width, COURSE.height);
    ctx.fillStyle = '#0b121a';
    ctx.fillRect(leftSide ? width - 10 : x, 0, 10, COURSE.height);

    for (var y = -120 + scroll; y < COURSE.height + 120; y += 118) {
      ctx.fillStyle = '#334252';
      ctx.fillRect(x + 8, y, Math.max(22, width - 18), 68);
      for (var i = 0; i < 4; i += 1) {
        var boxX = x + 14 + i * 16;
        var hue = ['#ff6b64', '#ffc94a', '#68d8ff', '#90f05f'][i % 4];
        ctx.fillStyle = hue;
        ctx.fillRect(boxX, y + 12 + (i % 2) * 12, 11, 28);
      }
    }
  }

  function drawTrackLines() {
    ctx.strokeStyle = '#ffc94a';
    ctx.lineWidth = 4;
    ctx.setLineDash([26, 18]);
    ctx.beginPath();
    ctx.moveTo(COURSE.leftEdge + 5, 0);
    ctx.lineTo(COURSE.leftEdge + 5, COURSE.height);
    ctx.moveTo(COURSE.rightEdge - 5, 0);
    ctx.lineTo(COURSE.rightEdge - 5, COURSE.height);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.18)';
    ctx.lineWidth = 2;
    ctx.setLineDash([16, 20]);
    for (var x = COURSE.leftEdge + 87; x < COURSE.rightEdge - 30; x += 87) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, COURSE.height);
      ctx.stroke();
    }
    ctx.setLineDash([]);
  }

  function drawFinishLines() {
    var firstBoundary = Math.ceil((state.distance - 900) / COURSE.lapLength) * COURSE.lapLength;
    for (var d = firstBoundary; d <= state.distance + 1500; d += COURSE.lapLength) {
      if (d < 0 || d > TOTAL_DISTANCE) {
        continue;
      }
      var y = screenY(d);
      if (y < -60 || y > COURSE.height + 80) {
        continue;
      }
      drawFinishLine(y);
    }
  }

  function drawFinishLine(y) {
    var squareSize = 18;
    for (var row = 0; row < 3; row += 1) {
      for (var col = 0; col < 20; col += 1) {
        ctx.fillStyle = (row + col) % 2 === 0 ? '#fff' : '#111';
        ctx.fillRect(COURSE.leftEdge + col * squareSize, y + row * squareSize, squareSize, squareSize);
      }
    }
    ctx.fillStyle = '#ffc94a';
    ctx.font = '700 14px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('CHECKOUT', COURSE.width / 2, y - 8);
  }

  function drawCourseObjects() {
    for (var i = 0; i < pickups.length; i += 1) {
      var pickup = pickups[i];
      var pickupY = screenY(pickup.distance);
      if (!pickup.taken && pickupY > -40 && pickupY < COURSE.height + 50) {
        drawCoupon(pickup.x, pickupY);
      }
    }

    for (var j = 0; j < hazards.length; j += 1) {
      var hazard = hazards[j];
      var hazardY = screenY(hazard.distance);
      if (!hazard.hit && hazardY > -50 && hazardY < COURSE.height + 60) {
        drawHazard(hazard, hazardY);
      }
    }
  }

  function drawCoupon(x, y) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.sin(state.elapsed * 6 + x) * 0.12);
    ctx.fillStyle = '#ffc94a';
    roundRect(-20, -12, 40, 24, 6);
    ctx.fill();
    ctx.fillStyle = '#17202a';
    ctx.font = '800 12px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('50%', 0, 5);
    ctx.restore();
  }

  function drawHazard(hazard, y) {
    ctx.save();
    ctx.translate(hazard.x, y);
    if (hazard.type === 'puddle') {
      ctx.fillStyle = 'rgba(73, 196, 255, 0.7)';
      ctx.beginPath();
      ctx.ellipse(0, 0, 30, 16, -0.1, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)';
      ctx.stroke();
    } else if (hazard.type === 'cereal') {
      ctx.fillStyle = '#f0714f';
      roundRect(-24, -21, 48, 42, 7);
      ctx.fill();
      ctx.fillStyle = '#fff3c0';
      ctx.font = '800 10px Arial, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('OATS', 0, 3);
    } else {
      ctx.fillStyle = '#8b5a2b';
      roundRect(-28, -18, 56, 36, 5);
      ctx.fill();
      ctx.fillStyle = '#ffdf8a';
      ctx.fillRect(-21, -10, 42, 7);
      ctx.fillRect(-21, 5, 42, 7);
    }
    ctx.restore();
  }

  function drawRivals() {
    var visible = rivals.slice().sort(function (a, b) {
      return a.distance - b.distance;
    });
    for (var i = 0; i < visible.length; i += 1) {
      var rival = visible[i];
      var y = screenY(rival.distance);
      if (y < -80 || y > COURSE.height + 90) {
        continue;
      }
      var x = rival.lane + Math.sin(rival.distance * rival.sway) * 28;
      drawCart(x, y, rival.color, rival.name, false);
    }
  }

  function drawPlayer() {
    drawCart(state.x, COURSE.playerY, '#ffc94a', 'You', true);
  }

  function drawCart(x, y, color, label, player) {
    ctx.save();
    ctx.translate(x, y);
    if (player && state.boostTime > 0) {
      ctx.fillStyle = 'rgba(255, 201, 74, 0.42)';
      ctx.beginPath();
      ctx.moveTo(-24, 29);
      ctx.lineTo(0, 70 + Math.sin(state.elapsed * 24) * 10);
      ctx.lineTo(24, 29);
      ctx.closePath();
      ctx.fill();
    }

    ctx.fillStyle = 'rgba(0, 0, 0, 0.24)';
    ctx.beginPath();
    ctx.ellipse(0, 31, 34, 10, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = '#d7e6f2';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-30, -10);
    ctx.lineTo(-20, 24);
    ctx.lineTo(20, 24);
    ctx.lineTo(30, -10);
    ctx.stroke();

    ctx.fillStyle = color;
    ctx.globalAlpha = player ? 1 : 0.94;
    roundRect(-24, -24, 48, 35, 8);
    ctx.fill();
    ctx.globalAlpha = 1;

    ctx.strokeStyle = 'rgba(20, 32, 42, 0.55)';
    ctx.lineWidth = 2;
    for (var gx = -14; gx <= 14; gx += 14) {
      ctx.beginPath();
      ctx.moveTo(gx, -20);
      ctx.lineTo(gx, 6);
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.moveTo(-22, -8);
    ctx.lineTo(22, -8);
    ctx.moveTo(-20, 5);
    ctx.lineTo(20, 5);
    ctx.stroke();

    ctx.fillStyle = '#0c141c';
    ctx.beginPath();
    ctx.arc(-18, 25, 6, 0, Math.PI * 2);
    ctx.arc(18, 25, 6, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#fff';
    ctx.font = '700 11px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(label, 0, -32);
    ctx.restore();
  }

  function drawProgressMeter() {
    var x = COURSE.width - 24;
    var y = 96;
    var height = 180;
    var progress = state.distance / TOTAL_DISTANCE;
    ctx.fillStyle = 'rgba(255, 255, 255, 0.16)';
    roundRect(x - 6, y, 12, height, 6);
    ctx.fill();
    ctx.fillStyle = '#ffc94a';
    roundRect(x - 6, y + height - height * progress, 12, height * progress, 6);
    ctx.fill();
  }

  function drawSpeedGlow() {
    if (!state.running || state.speed < 360) {
      return;
    }
    var alpha = clamp((state.speed - 360) / 240, 0, 0.35);
    var gradient = ctx.createLinearGradient(0, 0, 0, COURSE.height);
    gradient.addColorStop(0, 'rgba(255, 255, 255, 0)');
    gradient.addColorStop(1, 'rgba(255, 201, 74, ' + alpha + ')');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, COURSE.width, COURSE.height);
  }

  function screenY(distance) {
    return COURSE.playerY - (distance - state.distance) * 0.34;
  }

  function updateHud() {
    var lap = Math.min(COURSE.totalLaps, Math.floor(state.distance / COURSE.lapLength) + 1);
    hud.lap.textContent = lap + '/' + COURSE.totalLaps;
    hud.speed.textContent = Math.round(state.speed / 5.2);
    hud.place.textContent = rankLabel(getPlace());
    if (state.boostTime > 0) {
      hud.boost.textContent = 'Active';
    } else if (state.boost >= 1) {
      hud.boost.textContent = 'Ready';
    } else {
      hud.boost.textContent = Math.round(state.boost * 100) + '%';
    }
  }

  function getPlace() {
    var place = 1;
    for (var i = 0; i < rivals.length; i += 1) {
      if (rivals[i].distance > state.distance) {
        place += 1;
      }
    }
    return place;
  }

  function rankLabel(place) {
    if (place === 1) {
      return '1st';
    }
    if (place === 2) {
      return '2nd';
    }
    if (place === 3) {
      return '3rd';
    }
    return place + 'th';
  }

  function formatTime(seconds) {
    var mins = Math.floor(seconds / 60);
    var secs = Math.floor(seconds % 60);
    var tenths = Math.floor((seconds % 1) * 10);
    return mins + ':' + (secs < 10 ? '0' : '') + secs + '.' + tenths;
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function roundRect(x, y, width, height, radius) {
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
    ctx.closePath();
  }

  function loop(now) {
    var dt = Math.min(0.034, (now - lastTime) / 1000);
    lastTime = now;
    update(dt);
    render();
    requestAnimationFrame(loop);
  }

  function bindControls() {
    root.querySelector('[data-action="start"]').addEventListener('click', startRace);
    root.querySelector('[data-action="restart"]').addEventListener('click', startRace);

    window.addEventListener('keydown', function (event) {
      if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
        controls.left = true;
        event.preventDefault();
      }
      if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
        controls.right = true;
        event.preventDefault();
      }
      if (event.key === ' ' || event.key === 'ArrowUp' || event.key === 'w' || event.key === 'W') {
        controls.boost = true;
        event.preventDefault();
      }
    });

    window.addEventListener('keyup', function (event) {
      if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
        controls.left = false;
      }
      if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
        controls.right = false;
      }
      if (event.key === ' ' || event.key === 'ArrowUp' || event.key === 'w' || event.key === 'W') {
        controls.boost = false;
      }
    });

    var touchButtons = root.querySelectorAll('[data-control]');
    for (var i = 0; i < touchButtons.length; i += 1) {
      bindTouchButton(touchButtons[i]);
    }
  }

  function bindTouchButton(button) {
    var control = button.getAttribute('data-control');
    var press = function (event) {
      controls[control] = true;
      button.classList.add('is-pressed');
      event.preventDefault();
    };
    var release = function (event) {
      controls[control] = false;
      button.classList.remove('is-pressed');
      event.preventDefault();
    };

    button.addEventListener('pointerdown', press);
    button.addEventListener('pointerup', release);
    button.addEventListener('pointercancel', release);
    button.addEventListener('pointerleave', release);
    button.addEventListener('touchstart', press, { passive: false });
    button.addEventListener('touchend', release, { passive: false });
  }

  resetRace();
  bindControls();
  requestAnimationFrame(loop);
}());
