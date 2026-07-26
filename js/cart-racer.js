(function () {
  'use strict';

  var canvas = document.getElementById('raceCanvas');
  var ctx = canvas.getContext('2d');
  var ui = {
    position: document.getElementById('positionValue'),
    lap: document.getElementById('lapValue'),
    score: document.getElementById('scoreValue'),
    pickups: document.getElementById('pickupCount'),
    speed: document.getElementById('speedValue'),
    speedProgress: document.getElementById('speedProgress'),
    boost: document.getElementById('boostFill'),
    speedLines: document.getElementById('speedLines'),
    startOverlay: document.getElementById('startOverlay'),
    pauseOverlay: document.getElementById('pauseOverlay'),
    finishOverlay: document.getElementById('finishOverlay'),
    announcer: document.getElementById('announcer'),
    mission: document.getElementById('missionCard'),
    rival: document.getElementById('rivalTag'),
    sound: document.getElementById('soundButton'),
    finishTitle: document.getElementById('finishTitle'),
    finishPlace: document.getElementById('finishPlace'),
    finishScore: document.getElementById('finishScore'),
    finishCombo: document.getElementById('finishCombo')
  };

  var width = 1280;
  var height = 720;
  var dpr = 1;
  var lastTime = 0;
  var animationTime = 0;
  var audioContext = null;
  var soundEnabled = true;
  var countdownToken = 0;

  var state = {
    phase: 'menu',
    speed: 0,
    x: 0,
    visualX: 0,
    steer: 0,
    drifting: false,
    boosting: false,
    boost: 64,
    distance: 0,
    score: 0,
    pickups: 0,
    combo: 1,
    bestCombo: 1,
    position: 8,
    lap: 1,
    scroll: 0,
    spawnTimer: 0,
    hitCooldown: 0,
    objects: []
  };

  var controls = {
    left: false,
    right: false,
    drift: false,
    boost: false
  };

  var palette = {
    cream: '#fff5d6',
    yellow: '#ffcf3f',
    orange: '#f37035',
    red: '#df3d32',
    teal: '#22aaa1',
    blue: '#3b6bc8',
    ink: '#181412'
  };

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(from, to, amount) {
    return from + (to - from) * amount;
  }

  function random(min, max) {
    return min + Math.random() * (max - min);
  }

  function resize() {
    var bounds = canvas.getBoundingClientRect();
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = Math.max(320, bounds.width);
    height = Math.max(240, bounds.height);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function roundedRect(x, y, w, h, radius) {
    var r = Math.min(radius, Math.abs(w) / 2, Math.abs(h) / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function roadPoint(lane, depth) {
    var horizon = height * 0.295;
    var curve = Math.sin(state.distance * 0.0018 + depth * 2.4) * width * 0.025 * depth;
    var roadHalf = width * (0.085 + 0.43 * Math.pow(depth, 1.18));
    return {
      x: width / 2 + curve + lane * roadHalf,
      y: horizon + Math.pow(depth, 1.52) * (height - horizon + 30),
      scale: 0.12 + depth * depth * 1.18,
      half: roadHalf
    };
  }

  function fillQuad(a, b, c, d, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.lineTo(c.x, c.y);
    ctx.lineTo(d.x, d.y);
    ctx.closePath();
    ctx.fill();
  }

  function drawStore() {
    var horizon = height * 0.295;
    var ceiling = ctx.createLinearGradient(0, 0, 0, horizon);
    ceiling.addColorStop(0, '#24201d');
    ceiling.addColorStop(1, '#5d554c');
    ctx.fillStyle = ceiling;
    ctx.fillRect(0, 0, width, horizon + 2);

    ctx.fillStyle = '#898174';
    ctx.fillRect(0, horizon - 20, width, 26);

    var backGlow = ctx.createRadialGradient(width / 2, horizon, 10, width / 2, horizon, width * 0.42);
    backGlow.addColorStop(0, 'rgba(255,246,197,0.72)');
    backGlow.addColorStop(0.5, 'rgba(207,203,173,0.18)');
    backGlow.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = backGlow;
    ctx.fillRect(0, 0, width, horizon + 50);

    drawCeilingLights(horizon);

    var farLeft = roadPoint(-1, 0);
    var farRight = roadPoint(1, 0);
    var nearLeft = roadPoint(-1, 1.05);
    var nearRight = roadPoint(1, 1.05);
    fillQuad(farLeft, farRight, nearRight, nearLeft, '#c6bba3');

    drawFloorTiles(horizon, nearLeft, nearRight);
    drawShelves(-1, horizon, farLeft, nearLeft);
    drawShelves(1, horizon, farRight, nearRight);
    drawAisleSign(horizon);
  }

  function drawCeilingLights(horizon) {
    var offset = (state.scroll * 0.18) % 1;
    for (var i = 0; i < 7; i += 1) {
      var depth = ((i / 7 + offset) % 1);
      var y = horizon - Math.pow(depth, 0.62) * horizon * 0.9;
      var spread = width * (0.08 + depth * 0.62);
      var lightWidth = width * (0.055 + depth * 0.075);
      var alpha = 0.24 + depth * 0.52;
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = '#fffbd8';
      ctx.shadowColor = '#fff5a8';
      ctx.shadowBlur = 14 * depth;
      roundedRect(width / 2 - spread - lightWidth / 2, y, lightWidth, 3 + depth * 6, 4);
      ctx.fill();
      roundedRect(width / 2 + spread - lightWidth / 2, y, lightWidth, 3 + depth * 6, 4);
      ctx.fill();
      ctx.restore();
    }
  }

  function drawFloorTiles(horizon, nearLeft, nearRight) {
    var offset = state.scroll % 1;
    for (var i = 0; i < 15; i += 1) {
      var depth = ((i + offset) / 15);
      var p = roadPoint(0, depth);
      ctx.strokeStyle = 'rgba(70,61,51,' + (0.08 + depth * 0.18) + ')';
      ctx.lineWidth = 0.5 + depth * 1.3;
      ctx.beginPath();
      ctx.moveTo(width / 2 - p.half, p.y);
      ctx.lineTo(width / 2 + p.half, p.y);
      ctx.stroke();
    }

    for (var lane = -4; lane <= 4; lane += 1) {
      var far = roadPoint(lane / 5, 0);
      var near = roadPoint(lane / 5, 1.05);
      ctx.strokeStyle = 'rgba(78,67,57,0.13)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(far.x, horizon);
      ctx.lineTo(near.x, near.y);
      ctx.stroke();
    }

    ctx.strokeStyle = 'rgba(255,207,63,0.2)';
    ctx.lineWidth = Math.max(2, height * 0.006);
    ctx.beginPath();
    ctx.moveTo(nearLeft.x, nearLeft.y);
    ctx.lineTo(roadPoint(-1, 0).x, horizon);
    ctx.moveTo(nearRight.x, nearRight.y);
    ctx.lineTo(roadPoint(1, 0).x, horizon);
    ctx.stroke();
  }

  function drawShelves(side, horizon, farEdge, nearEdge) {
    var outerX = side < 0 ? -width * 0.05 : width * 1.05;
    var innerFar = { x: farEdge.x, y: horizon - 8 };
    var innerNear = { x: nearEdge.x, y: height + 20 };
    var topFar = { x: farEdge.x, y: horizon - height * 0.17 };
    var topNear = { x: nearEdge.x, y: height * 0.35 };
    var outerTop = { x: outerX, y: height * 0.06 };
    var outerBottom = { x: outerX, y: height + 20 };

    fillQuad(outerTop, topFar, innerFar, { x: outerX, y: horizon + 10 }, side < 0 ? '#655847' : '#5a5043');
    fillQuad({ x: outerX, y: horizon + 10 }, innerFar, innerNear, outerBottom, side < 0 ? '#39332d' : '#403830');

    var levels = [0.18, 0.39, 0.61, 0.82];
    levels.forEach(function (level, levelIndex) {
      var nearY = lerp(topNear.y, height, level);
      var farY = lerp(topFar.y, horizon, level);
      ctx.strokeStyle = levelIndex % 2 ? '#e1a940' : '#d45b36';
      ctx.lineWidth = 3 + level * 5;
      ctx.beginPath();
      ctx.moveTo(outerX, nearY);
      ctx.lineTo(side < 0 ? lerp(outerX, innerFar.x, 0.88) : lerp(outerX, innerFar.x, 0.88), farY);
      ctx.stroke();

      var count = 9;
      for (var j = 0; j < count; j += 1) {
        var t = (j + 0.4) / count;
        var x = lerp(outerX, innerFar.x, t);
        var perspective = 1 - t * 0.72;
        var productW = width * 0.025 * perspective;
        var productH = height * 0.045 * perspective;
        if (side > 0) {
          x = lerp(innerFar.x, outerX, t);
          perspective = 0.28 + t * 0.72;
          productW = width * 0.025 * perspective;
          productH = height * 0.045 * perspective;
        }
        var colors = [palette.yellow, palette.teal, palette.orange, '#d9e6dc', palette.red, palette.blue];
        ctx.globalAlpha = 0.68;
        ctx.fillStyle = colors[(j + levelIndex * 2) % colors.length];
        roundedRect(x - productW / 2, lerp(farY, nearY, side < 0 ? 1 - t : t) - productH, productW, productH, 2);
        ctx.fill();
        ctx.globalAlpha = 1;
      }
    });

    ctx.strokeStyle = '#8c8071';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(topFar.x, topFar.y);
    ctx.lineTo(topNear.x, topNear.y);
    ctx.stroke();
  }

  function drawAisleSign(horizon) {
    var sway = Math.sin(animationTime * 1.2) * 2;
    var signW = clamp(width * 0.09, 85, 135);
    var signH = signW * 0.43;
    var x = width * 0.5 - signW / 2 + sway;
    var y = horizon * 0.33;
    ctx.strokeStyle = '#27221e';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(x + signW * 0.2, 0);
    ctx.lineTo(x + signW * 0.2, y);
    ctx.moveTo(x + signW * 0.8, 0);
    ctx.lineTo(x + signW * 0.8, y);
    ctx.stroke();
    ctx.fillStyle = palette.orange;
    roundedRect(x, y, signW, signH, 5);
    ctx.fill();
    ctx.fillStyle = palette.cream;
    ctx.font = '900 ' + Math.round(signH * 0.28) + 'px Arial Narrow, Arial';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText('AISLE', x + signW * 0.12, y + signH * 0.34);
    ctx.font = '900 ' + Math.round(signH * 0.53) + 'px Arial Narrow, Arial';
    ctx.fillText('07', x + signW * 0.56, y + signH * 0.53);
    ctx.font = '700 ' + Math.round(signH * 0.17) + 'px Arial';
    ctx.fillStyle = '#46261d';
    ctx.fillText('SNACKS  •  CHAOS', x + signW * 0.12, y + signH * 0.74);
  }

  function createObject(type, lane, depth) {
    return {
      type: type,
      lane: lane,
      depth: depth === undefined ? 0.02 : depth,
      wobble: random(0, Math.PI * 2),
      color: [palette.red, palette.teal, palette.blue, palette.orange][Math.floor(random(0, 4))],
      active: true,
      hit: false
    };
  }

  function seedObjects() {
    state.objects = [
      createObject('rival', 0.28, 0.34),
      createObject('pickup', -0.28, 0.46),
      createObject('box', 0.72, 0.58),
      createObject('pickup', -0.7, 0.68),
      createObject('spill', 0.12, 0.8)
    ];
  }

  function spawnObject() {
    var roll = Math.random();
    var type = roll < 0.46 ? 'pickup' : roll < 0.68 ? 'box' : roll < 0.86 ? 'spill' : 'rival';
    var lanes = [-0.72, -0.36, 0, 0.36, 0.72];
    var lane = lanes[Math.floor(Math.random() * lanes.length)];
    state.objects.push(createObject(type, lane, 0.015));
  }

  function updateObjects(dt, demo) {
    var travel = (demo ? 0.075 : state.speed / 580) * dt;
    state.spawnTimer -= dt;
    if (!demo && state.spawnTimer <= 0) {
      spawnObject();
      state.spawnTimer = random(0.58, 1.05);
    }

    state.objects.forEach(function (object) {
      object.depth += travel * (object.type === 'rival' ? 0.82 : 1);
      object.wobble += dt * (object.type === 'pickup' ? 5 : 1.7);
      if (!demo && object.active && object.depth > 0.81 && object.depth < 1.02) {
        var objectX = object.lane + Math.sin(object.wobble) * (object.type === 'rival' ? 0.05 : 0);
        var threshold = object.type === 'pickup' ? 0.23 : 0.28;
        if (Math.abs(objectX - state.x) < threshold) {
          collide(object);
        }
      }
    });

    state.objects = state.objects.filter(function (object) {
      return object.depth < 1.17 && object.active;
    });

    if (demo && state.objects.length < 5) {
      seedObjects();
    }
  }

  function collide(object) {
    object.active = false;
    if (object.type === 'pickup') {
      state.pickups += 1;
      state.combo = Math.min(5, state.combo + 1);
      state.bestCombo = Math.max(state.bestCombo, state.combo);
      state.score += 25 * state.combo;
      state.boost = clamp(state.boost + 18, 0, 100);
      pulseMission();
      playTone(740, 0.08, 'sine', 0.06);
      if (state.pickups === 12) {
        state.score += 500;
        announce('Quest done!');
      } else if (state.combo >= 3) {
        announce('Combo x' + state.combo);
      }
    } else {
      state.speed *= object.type === 'spill' ? 0.38 : 0.52;
      state.combo = 1;
      state.hitCooldown = 0.55;
      document.body.classList.remove('shake');
      void document.body.offsetWidth;
      document.body.classList.add('shake');
      if (navigator.vibrate) {
        navigator.vibrate([25, 25, 45]);
      }
      playTone(95, 0.18, 'sawtooth', 0.08);
      announce(object.type === 'rival' ? 'Sideswiped!' : 'Clean up!');
    }
  }

  function pulseMission() {
    ui.mission.classList.remove('bump');
    void ui.mission.offsetWidth;
    ui.mission.classList.add('bump');
    window.setTimeout(function () {
      ui.mission.classList.remove('bump');
    }, 240);
  }

  function drawWorldObjects() {
    state.objects
      .filter(function (object) { return object.active; })
      .sort(function (a, b) { return a.depth - b.depth; })
      .forEach(drawObject);
  }

  function drawObject(object) {
    var lane = object.lane + Math.sin(object.wobble) * (object.type === 'rival' ? 0.045 : 0);
    var point = roadPoint(lane, object.depth);
    var size = Math.max(4, point.scale * Math.min(width, height) * 0.14);
    ctx.save();
    ctx.translate(point.x, point.y);

    if (object.type === 'pickup') {
      drawPickup(size, object.wobble);
    } else if (object.type === 'box') {
      drawBox(size);
    } else if (object.type === 'spill') {
      drawSpill(size);
    } else {
      drawRival(size, object.color);
    }
    ctx.restore();
  }

  function drawPickup(size, rotation) {
    ctx.save();
    ctx.translate(0, -size * 0.55);
    ctx.rotate(Math.sin(rotation) * 0.18);
    ctx.shadowColor = palette.yellow;
    ctx.shadowBlur = size * 0.45;
    ctx.fillStyle = palette.yellow;
    ctx.beginPath();
    ctx.moveTo(0, -size * 0.6);
    ctx.lineTo(size * 0.47, -size * 0.1);
    ctx.lineTo(size * 0.28, size * 0.52);
    ctx.lineTo(-size * 0.28, size * 0.52);
    ctx.lineTo(-size * 0.47, -size * 0.1);
    ctx.closePath();
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.strokeStyle = palette.ink;
    ctx.lineWidth = Math.max(1.5, size * 0.08);
    ctx.stroke();
    ctx.fillStyle = palette.red;
    roundedRect(-size * 0.16, -size * 0.28, size * 0.32, size * 0.55, size * 0.05);
    ctx.fill();
    ctx.fillStyle = palette.cream;
    ctx.font = '900 ' + Math.round(size * 0.24) + 'px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('S', 0, 0);
    ctx.restore();
  }

  function drawBox(size) {
    ctx.fillStyle = 'rgba(25,19,15,0.26)';
    ctx.beginPath();
    ctx.ellipse(0, size * 0.12, size * 0.55, size * 0.18, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.save();
    ctx.translate(0, -size * 0.46);
    ctx.rotate(-0.08);
    ctx.fillStyle = '#b67a3f';
    roundedRect(-size * 0.48, -size * 0.35, size * 0.96, size * 0.72, size * 0.06);
    ctx.fill();
    ctx.strokeStyle = '#6e4228';
    ctx.lineWidth = size * 0.05;
    ctx.stroke();
    ctx.fillStyle = palette.red;
    ctx.fillRect(-size * 0.08, -size * 0.35, size * 0.16, size * 0.72);
    ctx.fillStyle = '#603c25';
    ctx.font = '900 ' + Math.round(size * 0.18) + 'px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('FRAGILE', 0, size * 0.02);
    ctx.restore();
  }

  function drawSpill(size) {
    ctx.fillStyle = 'rgba(44,118,145,0.62)';
    ctx.beginPath();
    ctx.ellipse(0, 0, size * 0.75, size * 0.23, -0.1, 0, Math.PI * 2);
    ctx.fill();
    ctx.save();
    ctx.translate(0, -size * 0.54);
    ctx.fillStyle = palette.yellow;
    ctx.beginPath();
    ctx.moveTo(0, -size * 0.55);
    ctx.lineTo(size * 0.48, size * 0.47);
    ctx.lineTo(-size * 0.48, size * 0.47);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = palette.ink;
    ctx.lineWidth = Math.max(1, size * 0.07);
    ctx.stroke();
    ctx.fillStyle = palette.ink;
    ctx.font = '900 ' + Math.round(size * 0.24) + 'px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('!', 0, size * 0.2);
    ctx.restore();
  }

  function drawRival(size, color) {
    ctx.save();
    ctx.translate(0, -size * 0.52);
    ctx.fillStyle = 'rgba(16,12,10,0.3)';
    ctx.beginPath();
    ctx.ellipse(0, size * 0.63, size * 0.58, size * 0.18, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#26221f';
    ctx.lineWidth = Math.max(2, size * 0.12);
    ctx.beginPath();
    ctx.moveTo(-size * 0.5, size * 0.44);
    ctx.lineTo(-size * 0.38, size * 0.75);
    ctx.moveTo(size * 0.5, size * 0.44);
    ctx.lineTo(size * 0.38, size * 0.75);
    ctx.stroke();
    ctx.fillStyle = '#1a1715';
    ctx.beginPath();
    ctx.arc(-size * 0.38, size * 0.75, size * 0.13, 0, Math.PI * 2);
    ctx.arc(size * 0.38, size * 0.75, size * 0.13, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(-size * 0.68, -size * 0.42);
    ctx.lineTo(size * 0.68, -size * 0.42);
    ctx.lineTo(size * 0.5, size * 0.43);
    ctx.lineTo(-size * 0.5, size * 0.43);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#e4e4dc';
    ctx.lineWidth = Math.max(1.5, size * 0.06);
    ctx.stroke();
    ctx.globalAlpha = 0.55;
    for (var i = -2; i <= 2; i += 1) {
      ctx.beginPath();
      ctx.moveTo(i * size * 0.22, -size * 0.38);
      ctx.lineTo(i * size * 0.16, size * 0.4);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    ctx.fillStyle = palette.yellow;
    roundedRect(-size * 0.48, -size * 0.58, size * 0.96, size * 0.17, size * 0.08);
    ctx.fill();
    ctx.restore();
  }

  function drawPlayer() {
    var baseX = width / 2 + state.visualX * width * 0.29;
    var baseY = height * 0.9;
    var scale = clamp(Math.min(width / 1100, height / 700), 0.55, 1.25);
    var tilt = state.steer * 0.08 + (state.drifting ? state.steer * 0.14 : 0);
    var bounce = Math.sin(animationTime * (4 + state.speed * 0.04)) * Math.min(2.5, state.speed * 0.02);

    ctx.save();
    ctx.translate(baseX, baseY + bounce);
    ctx.rotate(tilt);
    ctx.scale(scale, scale);

    if (state.boosting && state.boost > 0 && state.phase === 'running') {
      drawTurboFlames();
    }

    ctx.fillStyle = 'rgba(15,12,10,0.34)';
    ctx.beginPath();
    ctx.ellipse(0, 22, 116, 27, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#191716';
    [-76, 76].forEach(function (x) {
      ctx.beginPath();
      ctx.arc(x, 20, 17, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = palette.yellow;
      ctx.beginPath();
      ctx.arc(x, 20, 7, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#191716';
    });

    ctx.strokeStyle = '#d5dedb';
    ctx.lineWidth = 7;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(-93, -118);
    ctx.lineTo(-72, -15);
    ctx.lineTo(75, -15);
    ctx.lineTo(98, -105);
    ctx.lineTo(-93, -105);
    ctx.stroke();

    var basket = ctx.createLinearGradient(0, -115, 0, -10);
    basket.addColorStop(0, palette.teal);
    basket.addColorStop(1, '#166a69');
    ctx.fillStyle = basket;
    ctx.beginPath();
    ctx.moveTo(-88, -101);
    ctx.lineTo(90, -101);
    ctx.lineTo(69, -22);
    ctx.lineTo(-69, -22);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#d9e2df';
    ctx.lineWidth = 5;
    ctx.stroke();

    ctx.save();
    ctx.globalAlpha = 0.48;
    ctx.lineWidth = 3;
    for (var x = -55; x <= 55; x += 28) {
      ctx.beginPath();
      ctx.moveTo(x * 1.35, -98);
      ctx.lineTo(x, -24);
      ctx.stroke();
    }
    for (var y = -82; y <= -38; y += 20) {
      ctx.beginPath();
      ctx.moveTo(-80 + (y + 100) * 0.22, y);
      ctx.lineTo(80 - (y + 100) * 0.22, y);
      ctx.stroke();
    }
    ctx.restore();

    ctx.fillStyle = palette.orange;
    ctx.beginPath();
    ctx.moveTo(-56, -98);
    ctx.lineTo(-19, -98);
    ctx.lineTo(-6, -54);
    ctx.lineTo(-68, -54);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = palette.yellow;
    roundedRect(13, -92, 48, 40, 8);
    ctx.fill();
    ctx.fillStyle = palette.red;
    ctx.beginPath();
    ctx.arc(37, -91, 17, Math.PI, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = palette.yellow;
    roundedRect(-107, -130, 214, 18, 9);
    ctx.fill();
    ctx.fillStyle = palette.ink;
    ctx.font = '900 11px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('LOOSE WHEEL EXPRESS', 0, -121);

    ctx.fillStyle = '#f0eee3';
    roundedRect(-52, -16, 104, 15, 5);
    ctx.fill();
    ctx.fillStyle = palette.red;
    roundedRect(-35, -18, 70, 17, 4);
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = '900 10px Arial';
    ctx.fillText('07', 0, -9);
    ctx.restore();
  }

  function drawTurboFlames() {
    var flicker = Math.sin(animationTime * 42) * 8;
    ctx.fillStyle = 'rgba(255,207,63,0.42)';
    ctx.beginPath();
    ctx.moveTo(-48, 2);
    ctx.lineTo(-25, 50 + flicker);
    ctx.lineTo(-7, 1);
    ctx.moveTo(7, 1);
    ctx.lineTo(28, 58 - flicker);
    ctx.lineTo(50, 2);
    ctx.fill();
    ctx.fillStyle = palette.orange;
    ctx.beginPath();
    ctx.moveTo(-38, 2);
    ctx.lineTo(-24, 36 - flicker * 0.4);
    ctx.lineTo(-13, 2);
    ctx.moveTo(16, 2);
    ctx.lineTo(29, 40 + flicker * 0.3);
    ctx.lineTo(41, 2);
    ctx.fill();
  }

  function update(dt) {
    animationTime += dt;
    if (state.phase === 'menu') {
      state.scroll = (state.scroll + dt * 0.9) % 15;
      state.distance += dt * 12;
      state.visualX = Math.sin(animationTime * 0.35) * 0.08;
      updateObjects(dt, true);
      return;
    }

    if (state.phase !== 'running') {
      return;
    }

    state.hitCooldown = Math.max(0, state.hitCooldown - dt);
    var input = (controls.left ? -1 : 0) + (controls.right ? 1 : 0);
    state.steer = lerp(state.steer, input, clamp(dt * 10, 0, 1));
    state.drifting = controls.drift && Math.abs(state.steer) > 0.1;
    state.boosting = controls.boost && state.boost > 0.5;

    var steeringRate = state.drifting ? 1.35 : 0.88;
    state.x = clamp(state.x + state.steer * steeringRate * dt, -0.88, 0.88);
    state.visualX = lerp(state.visualX, state.x, clamp(dt * (state.drifting ? 5 : 9), 0, 1));

    var targetSpeed = state.boosting ? 148 : state.drifting ? 112 : 98;
    if (state.hitCooldown > 0) {
      targetSpeed = 62;
    }
    state.speed = lerp(state.speed, targetSpeed, clamp(dt * (state.speed < targetSpeed ? 1.8 : 4.6), 0, 1));

    if (state.boosting) {
      state.boost = Math.max(0, state.boost - dt * 24);
      state.score += dt * 4;
    } else {
      state.boost = Math.min(100, state.boost + dt * 2.2);
    }

    state.distance += state.speed * dt;
    state.scroll = (state.scroll + state.speed * dt * 0.055) % 15;
    state.score += state.speed * dt * 0.035 * state.combo;
    state.lap = Math.min(3, Math.floor(state.distance / 850) + 1);
    state.position = clamp(8 - Math.floor(state.distance / 355) - Math.floor(state.pickups / 5), 1, 8);

    updateObjects(dt, false);
    updateUI();

    if (state.distance >= 2550) {
      finishRace();
    }
  }

  function draw() {
    ctx.clearRect(0, 0, width, height);
    drawStore();
    drawWorldObjects();
    drawPlayer();

    var rival = state.objects.filter(function (object) {
      return object.active && object.type === 'rival';
    })[0];
    if (rival) {
      var point = roadPoint(rival.lane, rival.depth);
      ui.rival.style.left = (point.x / width * 100) + '%';
      ui.rival.style.top = clamp(point.y / height * 100 - 7, 18, 66) + '%';
      ui.rival.style.opacity = rival.depth > 0.12 && rival.depth < 0.75 ? '0.9' : '0';
    } else {
      ui.rival.style.opacity = '0';
    }
  }

  function frame(timestamp) {
    if (!lastTime) {
      lastTime = timestamp;
    }
    var dt = Math.min((timestamp - lastTime) / 1000, 0.05);
    lastTime = timestamp;
    update(dt);
    draw();
    window.requestAnimationFrame(frame);
  }

  function resetRace() {
    state.speed = 0;
    state.x = 0;
    state.visualX = 0;
    state.steer = 0;
    state.drifting = false;
    state.boosting = false;
    state.boost = 64;
    state.distance = 0;
    state.score = 0;
    state.pickups = 0;
    state.combo = 1;
    state.bestCombo = 1;
    state.position = 8;
    state.lap = 1;
    state.spawnTimer = 0.8;
    state.hitCooldown = 0;
    controls.left = false;
    controls.right = false;
    controls.drift = false;
    controls.boost = false;
    seedObjects();
    updateUI();
  }

  function startRace() {
    countdownToken += 1;
    var token = countdownToken;
    initAudio();
    resetRace();
    ui.startOverlay.classList.add('hidden');
    ui.pauseOverlay.setAttribute('aria-hidden', 'true');
    ui.finishOverlay.setAttribute('aria-hidden', 'true');
    state.phase = 'countdown';
    announce('3');
    playTone(260, 0.12, 'square', 0.04);
    window.setTimeout(function () {
      if (token !== countdownToken) { return; }
      announce('2');
      playTone(320, 0.12, 'square', 0.04);
    }, 800);
    window.setTimeout(function () {
      if (token !== countdownToken) { return; }
      announce('1');
      playTone(390, 0.12, 'square', 0.04);
    }, 1600);
    window.setTimeout(function () {
      if (token !== countdownToken) { return; }
      state.phase = 'running';
      announce('Go!');
      playTone(620, 0.26, 'sawtooth', 0.055);
    }, 2400);
  }

  function pauseRace() {
    if (state.phase !== 'running') {
      return;
    }
    state.phase = 'paused';
    controls.left = controls.right = controls.drift = controls.boost = false;
    ui.pauseOverlay.setAttribute('aria-hidden', 'false');
  }

  function resumeRace() {
    if (state.phase !== 'paused') {
      return;
    }
    ui.pauseOverlay.setAttribute('aria-hidden', 'true');
    state.phase = 'running';
  }

  function finishRace() {
    state.phase = 'finished';
    state.speed = 0;
    controls.left = controls.right = controls.drift = controls.boost = false;
    var place = state.position;
    var suffix = place === 1 ? 'st' : place === 2 ? 'nd' : place === 3 ? 'rd' : 'th';
    ui.finishTitle.textContent = place <= 2 ? 'Aisle legend!' : place <= 5 ? 'Wild ride!' : 'Run it back!';
    ui.finishPlace.textContent = place + suffix;
    ui.finishScore.textContent = Math.floor(state.score).toLocaleString();
    ui.finishCombo.textContent = 'x' + state.bestCombo;
    ui.finishOverlay.setAttribute('aria-hidden', 'false');
    playTone(520, 0.14, 'square', 0.05);
    window.setTimeout(function () { playTone(650, 0.14, 'square', 0.05); }, 160);
    window.setTimeout(function () { playTone(780, 0.3, 'square', 0.05); }, 320);
  }

  function updateUI() {
    ui.position.textContent = state.position;
    ui.lap.textContent = state.lap;
    ui.score.textContent = String(Math.floor(state.score)).padStart(3, '0');
    ui.pickups.textContent = state.pickups;
    ui.speed.textContent = Math.round(state.speed);
    ui.speedProgress.style.strokeDasharray = clamp(state.speed / 165 * 72, 0, 72) + ' 100';
    ui.boost.style.width = state.boost + '%';
    ui.speedLines.classList.toggle('active', state.boosting && state.boost > 0);
  }

  function announce(message) {
    ui.announcer.textContent = message;
    ui.announcer.classList.remove('show');
    void ui.announcer.offsetWidth;
    ui.announcer.classList.add('show');
  }

  function initAudio() {
    if (!audioContext) {
      var AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        audioContext = new AudioCtx();
      }
    }
    if (audioContext && audioContext.state === 'suspended') {
      audioContext.resume();
    }
  }

  function playTone(frequency, duration, type, volume) {
    if (!soundEnabled || !audioContext) {
      return;
    }
    var oscillator = audioContext.createOscillator();
    var gain = audioContext.createGain();
    oscillator.type = type || 'sine';
    oscillator.frequency.setValueAtTime(frequency, audioContext.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, frequency * 0.74), audioContext.currentTime + duration);
    gain.gain.setValueAtTime(volume || 0.04, audioContext.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioContext.currentTime + duration);
    oscillator.connect(gain);
    gain.connect(audioContext.destination);
    oscillator.start();
    oscillator.stop(audioContext.currentTime + duration);
  }

  function bindHold(button, key) {
    function down(event) {
      event.preventDefault();
      controls[key] = true;
      button.classList.add('pressed');
      if (button.setPointerCapture && event.pointerId !== undefined) {
        button.setPointerCapture(event.pointerId);
      }
    }
    function up(event) {
      if (event) {
        event.preventDefault();
      }
      controls[key] = false;
      button.classList.remove('pressed');
    }
    button.addEventListener('pointerdown', down);
    button.addEventListener('pointerup', up);
    button.addEventListener('pointercancel', up);
    button.addEventListener('lostpointercapture', up);
  }

  function bindEvents() {
    document.getElementById('startButton').addEventListener('click', startRace);
    document.getElementById('raceAgainButton').addEventListener('click', startRace);
    document.getElementById('resumeButton').addEventListener('click', resumeRace);
    document.getElementById('restartButton').addEventListener('click', startRace);
    document.getElementById('pauseButton').addEventListener('click', function () {
      if (state.phase === 'paused') {
        resumeRace();
      } else {
        pauseRace();
      }
    });

    ui.sound.addEventListener('click', function () {
      initAudio();
      soundEnabled = !soundEnabled;
      ui.sound.classList.toggle('muted', !soundEnabled);
      ui.sound.setAttribute('aria-pressed', String(soundEnabled));
      if (soundEnabled) {
        playTone(520, 0.08, 'sine', 0.04);
      }
    });

    bindHold(document.getElementById('leftButton'), 'left');
    bindHold(document.getElementById('rightButton'), 'right');
    bindHold(document.getElementById('driftButton'), 'drift');
    bindHold(document.getElementById('boostButton'), 'boost');

    window.addEventListener('keydown', function (event) {
      if (event.code === 'ArrowLeft' || event.code === 'KeyA') { controls.left = true; }
      if (event.code === 'ArrowRight' || event.code === 'KeyD') { controls.right = true; }
      if (event.code === 'ShiftLeft' || event.code === 'ShiftRight') { controls.drift = true; }
      if (event.code === 'Space') {
        controls.boost = true;
        event.preventDefault();
      }
      if (event.code === 'Escape') {
        if (state.phase === 'running') { pauseRace(); }
        else if (state.phase === 'paused') { resumeRace(); }
      }
    });

    window.addEventListener('keyup', function (event) {
      if (event.code === 'ArrowLeft' || event.code === 'KeyA') { controls.left = false; }
      if (event.code === 'ArrowRight' || event.code === 'KeyD') { controls.right = false; }
      if (event.code === 'ShiftLeft' || event.code === 'ShiftRight') { controls.drift = false; }
      if (event.code === 'Space') { controls.boost = false; }
    });

    var dragStart = null;
    canvas.addEventListener('pointerdown', function (event) {
      dragStart = event.clientX;
    });
    canvas.addEventListener('pointermove', function (event) {
      if (dragStart === null || state.phase !== 'running') { return; }
      var delta = event.clientX - dragStart;
      controls.left = delta < -8;
      controls.right = delta > 8;
    });
    function endDrag() {
      dragStart = null;
      controls.left = false;
      controls.right = false;
    }
    canvas.addEventListener('pointerup', endDrag);
    canvas.addEventListener('pointercancel', endDrag);

    document.addEventListener('visibilitychange', function () {
      if (document.hidden && state.phase === 'running') {
        pauseRace();
      }
    });
    window.addEventListener('resize', resize);
  }

  resize();
  seedObjects();
  bindEvents();
  updateUI();
  window.requestAnimationFrame(frame);
}());
