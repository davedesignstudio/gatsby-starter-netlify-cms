/* Cart Kart — gameplay: kart physics, drifting, items, AI, race flow */
"use strict";

CK.game = (function () {
  var LAPS = 3;
  var KART_R = 9;
  var CAMD = 60;

  var state = "idle";        /* countdown | racing | finished */
  var countdownT = 0;
  var raceTime = 0;
  var finishTime = 0;
  var karts = [];
  var player = null;
  var cam = { x: 0, y: 0, yaw: 0 };
  var boxes = [];            /* item boxes {x,y,respawnT} */
  var worldItems = [];       /* bananas / cans / puddles */
  var particles = [];
  var boxAnim = 0;
  var results = null;
  var autopilot = false;   /* demo/testing: AI drives the player */

  /* ---------------- kart factory ---------------- */

  function makeKart(charIdx, isPlayer, slot, startPos) {
    var st = CK.CHARS[charIdx].stats;
    return {
      charIdx: charIdx,
      isPlayer: isPlayer,
      name: CK.CHARS[charIdx].name,
      x: startPos.x, y: startPos.y,
      heading: startPos.heading,
      moveAngle: startPos.heading,
      speed: 0,
      topSpeed: 290 * (0.88 + st.top * 0.24),
      accel: 150 * (0.75 + st.accel * 0.5),
      turnRate: 1.85 * (0.8 + st.handling * 0.4),
      weight: 0.6 + st.weight * 0.8,
      /* drift */
      drifting: false, driftDir: 0, driftCharge: 0,
      boostT: 0,
      /* status */
      spinT: 0, slickWobble: 0, wallT: 0, solidT: 0,
      item: null, rouletteT: 0,
      /* progress */
      prog: startPos.prog, lap: 0, rank: slot + 1,
      finished: false, finishT: 0,
      wrongWayT: 0,
      /* ai */
      aiBias: (Math.random() - 0.5) * 36,
      aiItemT: 0,
      aiSkill: 0.9 + Math.random() * 0.15
    };
  }

  function startRace(playerCharIdx) {
    var T = CK.track;
    karts = [];
    worldItems = [];
    particles = [];
    results = null;
    raceTime = 0;
    finishTime = 0;

    /* fill roster: remaining characters become AI */
    var order = [playerCharIdx];
    for (var i = 0; i < CK.CHARS.length; i++) {
      if (i !== playerCharIdx) { order.push(i); }
    }
    var grid = T.startPositions(order.length);
    /* player starts mid-pack (slot 3) */
    var slots = [3, 0, 1, 2, 4, 5];
    for (i = 0; i < order.length; i++) {
      var k = makeKart(order[i], i === 0, slots[i], grid[slots[i]]);
      karts.push(k);
      if (i === 0) { player = k; }
    }

    boxes = T.itemBoxSpots.map(function (s) {
      return { x: s.x, y: s.y, respawnT: 0 };
    });

    cam.yaw = player.heading;
    cam.x = player.x - Math.cos(cam.yaw) * CAMD;
    cam.y = player.y - Math.sin(cam.yaw) * CAMD;

    state = "countdown";
    countdownT = 3.6;
    CK.audio.startEngine();
    CK.audio.startMusic();
  }

  /* ---------------- items ---------------- */

  function pickItemFor(rank, count) {
    /* behind = better loot */
    var t = (rank - 1) / Math.max(1, count - 1);
    var w = {
      banana: CK.lerp(0.45, 0.12, t),
      can: CK.lerp(0.30, 0.23, t),
      milk: CK.lerp(0.18, 0.15, t),
      drink: CK.lerp(0.07, 0.50, t)
    };
    var sum = w.banana + w.can + w.milk + w.drink;
    var r = Math.random() * sum;
    if ((r -= w.banana) < 0) { return "banana"; }
    if ((r -= w.can) < 0) { return "can"; }
    if ((r -= w.milk) < 0) { return "milk"; }
    return "drink";
  }

  function useItem(k) {
    if (!k.item) { return; }
    var it = k.item;
    k.item = null;
    var cs = Math.cos(k.heading), sn = Math.sin(k.heading);
    if (it === "banana") {
      worldItems.push({ type: "banana", x: k.x - cs * 20, y: k.y - sn * 20 });
      if (k.isPlayer) { CK.audio.sfx.throwItem(); }
    } else if (it === "can") {
      worldItems.push({
        type: "can", x: k.x + cs * 18, y: k.y + sn * 18,
        vx: cs * 460, vy: sn * 460, ttl: 3.5, owner: k, age: 0
      });
      if (k.isPlayer) { CK.audio.sfx.throwItem(); }
    } else if (it === "milk") {
      var lx = k.x + cs * 150, ly = k.y + sn * 150;
      worldItems.push({ type: "milkAir", x: k.x, y: k.y, tx: lx, ty: ly, t: 0 });
      if (k.isPlayer) { CK.audio.sfx.throwItem(); }
    } else if (it === "drink") {
      k.boostT = Math.max(k.boostT, 1.35);
      if (k.isPlayer) { CK.audio.sfx.boost(); }
    }
  }

  function spinOut(k) {
    if (k.spinT > 0) { return; }
    k.spinT = 1.0;
    k.drifting = false;
    k.driftCharge = 0;
    if (k.isPlayer) { CK.audio.sfx.spin(); }
    spawnBurst(k.x, k.y, "#e8c83a", 8);
  }

  function spawnBurst(x, y, color, n) {
    for (var i = 0; i < n; i++) {
      var a = Math.random() * CK.TAU;
      var sp = 30 + Math.random() * 60;
      particles.push({
        x: x, y: y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
        ttl: 0.5 + Math.random() * 0.3, size: 2.5 + Math.random() * 2.5, color: color
      });
    }
  }

  /* ---------------- physics step ---------------- */

  function steerKart(k, dt, steer, wantDrift) {
    var T = CK.track;
    var surf = T.surfaceAt(k.x, k.y);
    var offtrack = surf.dist > T.HALF_W + 6;
    var slick = surf.slick;

    /* dynamic milk puddles */
    for (var i = 0; i < worldItems.length; i++) {
      var wi = worldItems[i];
      if (wi.type === "puddle" &&
          CK.dist2(k.x, k.y, wi.x, wi.y) < wi.r * wi.r) { slick = true; }
    }

    var spinning = k.spinT > 0;
    if (spinning) {
      k.spinT -= dt;
      steer = 0;
      wantDrift = false;
    }

    /* drift state */
    if (wantDrift && !k.drifting && Math.abs(steer) > 0.2 && k.speed > 120) {
      k.drifting = true;
      k.driftDir = steer > 0 ? 1 : -1;
      k.driftCharge = 0;
    }
    if (k.drifting) {
      if (!wantDrift || k.speed < 80) {
        /* release: mini-turbo */
        if (k.driftCharge > 2.0) { k.boostT = Math.max(k.boostT, 0.9); if (k.isPlayer) { CK.audio.sfx.boost(); } }
        else if (k.driftCharge > 1.0) { k.boostT = Math.max(k.boostT, 0.5); if (k.isPlayer) { CK.audio.sfx.boost(); } }
        k.drifting = false;
        k.driftCharge = 0;
      } else {
        k.driftCharge += dt;
      }
    }

    /* turning */
    var turn = k.turnRate;
    if (k.drifting) {
      /* biased steering while drifting */
      steer = CK.clamp(steer * 0.8 + k.driftDir * 0.7, -1.5, 1.5);
      turn *= 1.25;
    }
    var speedFac = CK.clamp(k.speed / 90, 0, 1);
    k.heading += steer * turn * speedFac * dt;

    /* slick wobble */
    if (slick && !spinning) {
      k.slickWobble += dt * 14;
      k.heading += Math.sin(k.slickWobble) * 0.5 * dt;
    }

    /* movement direction eases toward heading (drifting = slide) */
    var ease = k.drifting ? 4.0 : 10.0;
    if (slick) { ease = 1.6; }
    if (spinning) { ease = 6.0; }
    var d = CK.angDiff(k.moveAngle, k.heading);
    k.moveAngle += d * Math.min(1, ease * dt);

    /* target speed */
    var maxS = k.topSpeed;
    if (k.boostT > 0) { k.boostT -= dt; maxS += 95; }
    if (offtrack && k.boostT <= 0) { maxS *= 0.55; }
    if (spinning) { maxS = 26; }
    if (k.drifting) { maxS *= 0.96; }

    if (k.speed < maxS) {
      k.speed += (k.boostT > 0 ? k.accel * 2.2 : k.accel) * dt;
      if (k.speed > maxS) { k.speed = maxS; }
    } else {
      k.speed -= 220 * dt;
      if (k.speed < maxS) { k.speed = maxS; }
    }

    /* integrate */
    k.x += Math.cos(k.moveAngle) * k.speed * dt;
    k.y += Math.sin(k.moveAngle) * k.speed * dt;

    /* wall clamp (shelving corridor) */
    var wall = T.clampToCorridor(k.x, k.y, T.WALL_D);
    if (wall) {
      k.x = wall.x;
      k.y = wall.y;
      if (k.wallT <= 0) {
        /* fresh contact: real bump */
        if (k.speed > 100) {
          if (k.isPlayer) { CK.audio.sfx.bump(); }
          spawnBurst(k.x, k.y, "#c8d2dc", 4);
        }
        k.speed *= 0.7;
      } else {
        /* grinding along the shelves: mild scrub */
        k.speed *= Math.max(0, 1 - 0.9 * dt);
      }
      k.wallT = 0.35;
      /* steer heading to slide along the wall in the direction of travel */
      var wallDir = wall.wallDir;
      if (Math.abs(CK.angDiff(k.heading, wallDir)) > Math.PI / 2) {
        wallDir += Math.PI;  /* kart is travelling against waypoint order */
      }
      var hd = CK.angDiff(k.heading, wallDir);
      k.heading += CK.clamp(hd, -1.2, 1.2) * 5.0 * dt;
      k.moveAngle += CK.angDiff(k.moveAngle, k.heading) * Math.min(1, 8 * dt);
    }
    k.wallT = (k.wallT || 0) - dt;

    /* solid props */
    var solids = T.solids;
    var touchedSolid = false;
    for (i = 0; i < solids.length; i++) {
      var s = solids[i];
      var dx = k.x - s.x, dy = k.y - s.y;
      var rr = s.r + KART_R;
      var d2 = dx * dx + dy * dy;
      if (d2 < rr * rr && d2 > 0.01) {
        var dd = Math.sqrt(d2);
        k.x = s.x + dx / dd * rr;
        k.y = s.y + dy / dd * rr;
        touchedSolid = true;
        if (k.solidT <= 0) {
          k.speed *= 0.55;
          if (k.isPlayer) { CK.audio.sfx.bump(); }
          spawnBurst(k.x, k.y, "#c8d2dc", 4);
        } else {
          k.speed *= Math.max(0, 1 - 1.2 * dt);
        }
        /* deflect heading tangentially so karts roll around the prop */
        var tang = Math.atan2(dy, dx) + Math.PI / 2;
        if (Math.abs(CK.angDiff(k.heading, tang)) > Math.PI / 2) { tang += Math.PI; }
        k.heading += CK.angDiff(k.heading, tang) * Math.min(1, 6 * dt);
      }
    }
    k.solidT = touchedSolid ? 0.35 : (k.solidT || 0) - dt;

    /* progress + lap counting */
    var newProg = surf.prog;
    var N = T.N_WP;
    if (k.prog > N - 30 && newProg < 30) {
      k.lap++;
      if (k.isPlayer && state === "racing") {
        if (k.lap > LAPS) { /* handled in update */ }
        else if (k.lap > 1) { CK.audio.sfx.lap(); }
      }
    } else if (k.prog < 30 && newProg > N - 30) {
      k.lap--;
    }
    /* wrong way: progress decreasing */
    var dprog = newProg - k.prog;
    if (dprog > N / 2) { dprog -= N; }
    if (dprog < -N / 2) { dprog += N; }
    if (dprog < -0.05 && k.speed > 60) { k.wrongWayT += dt; }
    else { k.wrongWayT = 0; }
    k.prog = newProg;
  }

  /* ---------------- AI ---------------- */

  function aiControl(k, dt) {
    var T = CK.track;
    var look = 12 + k.speed * 0.045;
    var target = T.lateral(Math.floor(k.prog + look) % T.N_WP, k.aiBias * 0.5);

    /* dodge hazards & items ahead */
    var cs = Math.cos(k.heading), sn = Math.sin(k.heading);
    var dodge = 0;
    function checkAvoid(x, y, r) {
      var rx = x - k.x, ry = y - k.y;
      var fwd = rx * cs + ry * sn;
      if (fwd > 8 && fwd < 90) {
        var lat = -rx * sn + ry * cs;
        if (Math.abs(lat) < r + 14) { dodge += (lat >= 0 ? -1 : 1) * (1 - fwd / 90); }
      }
    }
    var i;
    for (i = 0; i < worldItems.length; i++) {
      var wi = worldItems[i];
      if (wi.type === "banana") { checkAvoid(wi.x, wi.y, 8); }
      else if (wi.type === "puddle") { checkAvoid(wi.x, wi.y, wi.r); }
    }
    for (i = 0; i < T.solids.length; i++) {
      checkAvoid(T.solids[i].x, T.solids[i].y, T.solids[i].r + 6);
    }
    for (i = 0; i < T.hazards.length; i++) {
      checkAvoid(T.hazards[i].x, T.hazards[i].y, T.hazards[i].r * 0.8);
    }
    /* steer around other karts to overtake instead of tailgating */
    for (i = 0; i < karts.length; i++) {
      if (karts[i] !== k) { checkAvoid(karts[i].x, karts[i].y, 6); }
    }

    var want = Math.atan2(target.y - k.y, target.x - k.x);
    var steer = CK.clamp(CK.angDiff(k.heading, want) * 2.4, -1, 1) + dodge * 1.2;
    steer = CK.clamp(steer, -1.3, 1.3);

    /* rubber-banding vs player */
    var myTotal = k.lap * T.N_WP + k.prog;
    var plTotal = player.lap * T.N_WP + player.prog;
    var gap = plTotal - myTotal;                 /* >0: AI is behind */
    var band = CK.clamp(1 + gap * 0.0009, 0.9, 1.12);
    var effTop = k.topSpeed;
    k.topSpeed = effTop * band * k.aiSkill;

    /* use held item */
    if (k.item) {
      k.aiItemT -= dt;
      if (k.aiItemT <= 0) { useItem(k); }
    }

    steerKart(k, dt, steer, false);
    k.topSpeed = effTop;
  }

  /* ---------------- collisions between karts ---------------- */

  function kartCollisions(dt) {
    for (var i = 0; i < karts.length; i++) {
      for (var j = i + 1; j < karts.length; j++) {
        var a = karts[i], b = karts[j];
        var dx = b.x - a.x, dy = b.y - a.y;
        var d2 = dx * dx + dy * dy;
        var rr = KART_R * 2;
        if (d2 < rr * rr && d2 > 0.01) {
          var d = Math.sqrt(d2);
          var overlap = (rr - d) + 0.6;
          var nx = dx / d, ny = dy / d;
          var wsum = a.weight + b.weight;
          a.x -= nx * overlap * (b.weight / wsum);
          a.y -= ny * overlap * (b.weight / wsum);
          b.x += nx * overlap * (a.weight / wsum);
          b.y += ny * overlap * (a.weight / wsum);
          /* gentle, framerate-independent scrub so pace cars don't stall */
          var scrub = Math.max(0, 1 - 1.4 * dt);
          a.speed *= scrub; b.speed *= scrub;
          if ((a.isPlayer || b.isPlayer) && Math.abs(a.speed - b.speed) > 60) {
            CK.audio.sfx.bump();
          }
        }
      }
    }
  }

  /* ---------------- update ---------------- */

  function update(dt, edges) {
    if (state === "idle") { return; }
    var T = CK.track;
    var inp = CK.input;
    boxAnim += dt;

    if (state === "countdown") {
      var pre = Math.ceil(countdownT);
      countdownT -= dt;
      if (Math.ceil(countdownT) < pre && countdownT > 0) { CK.audio.sfx.countBeep(); }
      if (countdownT <= 0) {
        state = "racing";
        CK.audio.sfx.countGo();
      }
    } else {
      raceTime += dt;
    }

    var racing = state !== "countdown";

    /* player control */
    if (racing && !player.finished && !autopilot) {
      var steer = (inp.left ? -1 : 0) + (inp.right ? 1 : 0);
      if (edges.item && player.item && player.rouletteT <= 0) { useItem(player); }
      if (inp.brake) { player.speed = Math.max(0, player.speed - 320 * dt); }
      steerKart(player, dt, steer, inp.drift);
    } else if (!racing) {
      player.speed = 0;
    } else {
      aiControl(player, dt);  /* demo mode, or auto-drive after finishing */
    }

    /* AI */
    for (var i = 0; i < karts.length; i++) {
      var k = karts[i];
      if (k === player) { continue; }
      if (racing) { aiControl(k, dt); }
    }

    kartCollisions(dt);

    /* roulette */
    if (player.rouletteT > 0) {
      player.rouletteT -= dt;
      if (Math.floor(player.rouletteT * 10) % 2 === 0) { /* tick sparsely */ }
      if (player.rouletteT <= 0) {
        player.item = pickItemFor(player.rank, karts.length);
        CK.audio.sfx.pickup();
      }
    }

    /* item boxes */
    for (i = 0; i < boxes.length; i++) {
      var bx = boxes[i];
      if (bx.respawnT > 0) { bx.respawnT -= dt; continue; }
      for (var kk = 0; kk < karts.length; kk++) {
        var kt = karts[kk];
        if (CK.dist2(kt.x, kt.y, bx.x, bx.y) < 15 * 15) {
          bx.respawnT = 3;
          spawnBurst(bx.x, bx.y, "#e8b83a", 6);
          if (kt.isPlayer) {
            if (!kt.item && kt.rouletteT <= 0) {
              kt.rouletteT = 1.1;
              CK.audio.sfx.roulette();
            }
          } else if (!kt.item) {
            kt.item = pickItemFor(kt.rank, karts.length);
            kt.aiItemT = 0.8 + Math.random() * 2.4;
          }
          break;
        }
      }
    }

    /* world items */
    for (i = worldItems.length - 1; i >= 0; i--) {
      var wi = worldItems[i];
      if (wi.type === "can") {
        wi.age += dt;
        wi.ttl -= dt;
        wi.x += wi.vx * dt; wi.y += wi.vy * dt;
        var surf = T.surfaceAt(wi.x, wi.y);
        if (wi.ttl <= 0 || surf.dist > T.WALL_D) {
          spawnBurst(wi.x, wi.y, "#c93a30", 5);
          worldItems.splice(i, 1);
          continue;
        }
        for (kk = 0; kk < karts.length; kk++) {
          var vk = karts[kk];
          if (vk === wi.owner && wi.age < 0.25) { continue; }
          if (CK.dist2(vk.x, vk.y, wi.x, wi.y) < 12 * 12) {
            spinOut(vk);
            spawnBurst(wi.x, wi.y, "#c93a30", 8);
            worldItems.splice(i, 1);
            break;
          }
        }
      } else if (wi.type === "banana") {
        for (kk = 0; kk < karts.length; kk++) {
          if (CK.dist2(karts[kk].x, karts[kk].y, wi.x, wi.y) < 11 * 11) {
            spinOut(karts[kk]);
            worldItems.splice(i, 1);
            break;
          }
        }
      } else if (wi.type === "milkAir") {
        wi.t += dt * 2.2;
        if (wi.t >= 1) {
          worldItems.splice(i, 1);
          worldItems.push({ type: "puddle", x: wi.tx, y: wi.ty, r: 26, ttl: 13 });
          CK.audio.sfx.splash();
        }
      } else if (wi.type === "puddle") {
        wi.ttl -= dt;
        if (wi.ttl <= 0) { worldItems.splice(i, 1); }
      }
    }

    /* particles */
    for (i = particles.length - 1; i >= 0; i--) {
      var p = particles[i];
      p.ttl -= dt;
      p.x += p.vx * dt; p.y += p.vy * dt;
      if (p.ttl <= 0) { particles.splice(i, 1); }
    }

    /* boost trail puffs */
    for (i = 0; i < karts.length; i++) {
      var kb = karts[i];
      if (kb.boostT > 0 && Math.random() < 0.5) {
        particles.push({
          x: kb.x - Math.cos(kb.moveAngle) * 12 + (Math.random() - 0.5) * 6,
          y: kb.y - Math.sin(kb.moveAngle) * 12 + (Math.random() - 0.5) * 6,
          vx: 0, vy: 0, ttl: 0.35, size: 4, color: "#ffb040"
        });
      }
    }

    /* ranking */
    var sorted = karts.slice().sort(function (a, b) {
      var ta = a.finished ? 1e9 - a.finishT : a.lap * T.N_WP + a.prog;
      var tb = b.finished ? 1e9 - b.finishT : b.lap * T.N_WP + b.prog;
      return tb - ta;
    });
    for (i = 0; i < sorted.length; i++) { sorted[i].rank = i + 1; }

    /* finishing */
    for (i = 0; i < karts.length; i++) {
      var kf = karts[i];
      if (!kf.finished && kf.lap > LAPS) {
        kf.finished = true;
        kf.finishT = raceTime;
        if (kf.isPlayer) {
          state = "finished";
          finishTime = raceTime;
          CK.audio.sfx.finish();
        }
      }
    }

    /* engine audio follows player */
    CK.audio.engine(CK.clamp(player.speed / (player.topSpeed + 95), 0, 1), player.boostT > 0);

    /* camera follows player's motion, kept inside the corridor */
    var targetYaw = player.moveAngle;
    cam.yaw += CK.angDiff(cam.yaw, targetYaw) * Math.min(1, 6 * dt);
    cam.x = player.x - Math.cos(cam.yaw) * CAMD;
    cam.y = player.y - Math.sin(cam.yaw) * CAMD;
    var camWall = T.clampToCorridor(cam.x, cam.y, T.WALL_D + 8);
    if (camWall) { cam.x = camWall.x; cam.y = camWall.y; }
  }

  /* ---------------- drawables for renderer ---------------- */

  function getDrawables() {
    var T = CK.track;
    var S = CK.sprites;
    var out = [];
    var i;

    for (i = 0; i < T.decor.length; i++) { out.push(T.decor[i]); }

    var bf = S.items.boxFrames[Math.floor(boxAnim * 10) % 8];
    for (i = 0; i < boxes.length; i++) {
      if (boxes[i].respawnT > 0) { continue; }
      out.push({
        x: boxes[i].x, y: boxes[i].y, img: bf, w: 11, h: 11,
        yOff: 3 + Math.sin(boxAnim * 3 + i) * 1.5
      });
    }

    for (i = 0; i < worldItems.length; i++) {
      var wi = worldItems[i];
      if (wi.type === "banana") {
        out.push({ x: wi.x, y: wi.y, img: S.items.banana, w: 8, h: 8 });
      } else if (wi.type === "can") {
        out.push({ x: wi.x, y: wi.y, img: S.items.can, w: 7, h: 7, yOff: 2 });
      } else if (wi.type === "puddle") {
        out.push({ x: wi.x, y: wi.y, img: S.items.puddle, w: wi.r * 2.1, h: wi.r * 0.6 });
      } else if (wi.type === "milkAir") {
        var t = wi.t;
        var mx = CK.lerp(wi.x, wi.tx, t);
        var my = CK.lerp(wi.y, wi.ty, t);
        out.push({ x: mx, y: my, img: S.items.milk, w: 8, h: 8, yOff: Math.sin(t * Math.PI) * 26 });
      }
    }

    for (i = 0; i < karts.length; i++) {
      var k = karts[i];
      var visHeading = k.heading + (k.drifting ? k.driftDir * 0.22 : 0);
      out.push({
        x: k.x, y: k.y, kart: k.charIdx, heading: visHeading,
        w: 17, h: 17, spinT: k.spinT > 0 ? (1 - k.spinT) : 0,
        topmost: k.isPlayer
      });

      /* drift sparks / boost flames as custom shapes at kart base */
      if (k.drifting && k.driftCharge > 1.0) {
        (function (kk2) {
          var col = kk2.driftCharge > 2.0 ? "#ff9030" : "#50b0ff";
          out.push({
            x: kk2.x - Math.cos(kk2.moveAngle) * 8,
            y: kk2.y - Math.sin(kk2.moveAngle) * 8,
            size: 8,
            draw: function (g, sx, sy, scale) {
              g.fillStyle = col;
              for (var s = 0; s < 3; s++) {
                var a = Math.random() * CK.TAU;
                g.fillRect(sx + Math.cos(a) * 5 * scale - 1, sy - Math.random() * 3 * scale, Math.max(1.5, scale), Math.max(1.5, scale));
              }
            }
          });
        })(k);
      }
      if (k.boostT > 0) {
        (function (kk3) {
          out.push({
            x: kk3.x - Math.cos(kk3.moveAngle) * 11,
            y: kk3.y - Math.sin(kk3.moveAngle) * 11,
            size: 8,
            draw: function (g, sx, sy, scale) {
              var fl = 6 * scale * (0.7 + Math.random() * 0.5);
              g.fillStyle = "#ff8020";
              g.beginPath();
              g.moveTo(sx - 2.4 * scale, sy - 3 * scale);
              g.lineTo(sx + 2.4 * scale, sy - 3 * scale);
              g.lineTo(sx, sy - 3 * scale + fl);
              g.closePath(); g.fill();
              g.fillStyle = "#ffd040";
              g.beginPath();
              g.moveTo(sx - 1.2 * scale, sy - 3 * scale);
              g.lineTo(sx + 1.2 * scale, sy - 3 * scale);
              g.lineTo(sx, sy - 3 * scale + fl * 0.6);
              g.closePath(); g.fill();
            }
          });
        })(k);
      }
    }

    for (i = 0; i < particles.length; i++) {
      (function (p) {
        out.push({
          x: p.x, y: p.y, size: p.size,
          draw: function (g, sx, sy, scale) {
            g.globalAlpha = Math.min(1, p.ttl * 3);
            g.fillStyle = p.color;
            var s = Math.max(1.5, p.size * scale * 0.5);
            g.fillRect(sx - s / 2, sy - s / 2 - 2 * scale, s, s);
            g.globalAlpha = 1;
          }
        });
      })(particles[i]);
    }

    return out;
  }

  return {
    LAPS: LAPS,
    startRace: startRace,
    update: update,
    getDrawables: getDrawables,
    getCam: function () { return cam; },
    getState: function () { return state; },
    setIdle: function () { state = "idle"; CK.audio.stopEngine(); },
    getCountdown: function () { return countdownT; },
    getTime: function () { return raceTime; },
    getFinishTime: function () { return finishTime; },
    getKarts: function () { return karts; },
    getPlayer: function () { return player; },
    setAutopilot: function (v) { autopilot = v; }
  };
})();
