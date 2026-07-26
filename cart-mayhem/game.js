(() => {
  "use strict";

  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const minimap = document.getElementById("minimap");
  const mctx = minimap.getContext("2d");

  const TOTAL_LAPS = 3;
  const CART_COUNT = 4;

  const RACERS = [
    { id: "rusty", name: "Rusty Rick", color: "#c45c26", accent: "#f0c27a", speed: 1.0, accel: 1.05, handling: 0.95, blurb: "Beater cart, sticky wheels" },
    { id: "dana", name: "Dumpster Dana", color: "#2d6a4f", accent: "#95d5b2", speed: 0.95, accel: 1.1, handling: 1.1, blurb: "Tight turns, alley-trained" },
    { id: "ace", name: "Alley Ace", color: "#1d3557", accent: "#a8dadc", speed: 1.1, accel: 0.95, handling: 0.9, blurb: "Built for straightaways" },
    { id: "king", name: "Cart King", color: "#6a0572", accent: "#e0aaff", speed: 1.02, accel: 1.0, handling: 1.0, blurb: "Balanced aisle legend" },
  ];

  const ITEMS = {
    boost: { icon: "⚡", name: "Soda Rush" },
    banana: { icon: "🍌", name: "Banana Peel" },
    soup: { icon: "🥫", name: "Soup Can" },
    gum: { icon: "🫧", name: "Sticky Gum" },
  };
  const ITEM_KEYS = Object.keys(ITEMS);

  // Track: closed loop of waypoints in world units
  const TRACK = [
    { x: 0, y: -420 },
    { x: 180, y: -400 },
    { x: 320, y: -280 },
    { x: 360, y: -80 },
    { x: 300, y: 120 },
    { x: 180, y: 260 },
    { x: 40, y: 340 },
    { x: -140, y: 360 },
    { x: -300, y: 260 },
    { x: -360, y: 80 },
    { x: -340, y: -120 },
    { x: -260, y: -300 },
    { x: -100, y: -400 },
  ];

  const TRACK_WIDTH = 92;
  const SHELF_MARGIN = 55;

  let W = 0;
  let H = 0;
  let dpr = 1;
  let selectedRacer = 0;
  let state = "title"; // title | select | how | countdown | racing | results
  let carts = [];
  let hazards = [];
  let projectiles = [];
  let itemBoxes = [];
  let particles = [];
  let raceTime = 0;
  let countdownValue = 3;
  let countdownTimer = 0;
  let camera = { x: 0, y: 0, zoom: 1 };
  let keys = {};
  let touch = { left: false, right: false, drift: false, item: false };
  let lastTs = 0;
  let isTouchDevice = matchMedia("(pointer: coarse)").matches;

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth;
    H = window.innerHeight;
    canvas.width = Math.floor(W * dpr);
    canvas.height = Math.floor(H * dpr);
    canvas.style.width = W + "px";
    canvas.style.height = H + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    camera.zoom = Math.max(0.85, Math.min(1.25, Math.min(W, H) / 700));
  }

  function showScreen(id) {
    document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
    const el = document.getElementById(id);
    if (el) el.classList.add("active");
  }

  function setHudVisible(v) {
    document.getElementById("hud").classList.toggle("hidden", !v);
    const tc = document.getElementById("touchControls");
    tc.classList.toggle("hidden", !v || !isTouchDevice);
  }

  function dist(a, b) {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return Math.hypot(dx, dy);
  }

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  function angleDiff(a, b) {
    let d = b - a;
    while (d > Math.PI) d -= Math.PI * 2;
    while (d < -Math.PI) d += Math.PI * 2;
    return d;
  }

  function trackLength() {
    let len = 0;
    for (let i = 0; i < TRACK.length; i++) {
      len += dist(TRACK[i], TRACK[(i + 1) % TRACK.length]);
    }
    return len;
  }

  const TRACK_LEN = trackLength();

  function nearestTrackPoint(x, y) {
    let best = { dist: Infinity, t: 0, nx: 0, ny: 0, tx: 0, ty: 0, seg: 0, along: 0 };
    let alongAcc = 0;
    for (let i = 0; i < TRACK.length; i++) {
      const a = TRACK[i];
      const b = TRACK[(i + 1) % TRACK.length];
      const abx = b.x - a.x;
      const aby = b.y - a.y;
      const segLen = Math.hypot(abx, aby) || 1;
      const apx = x - a.x;
      const apy = y - a.y;
      const t = clamp((apx * abx + apy * aby) / (segLen * segLen), 0, 1);
      const px = a.x + abx * t;
      const py = a.y + aby * t;
      const d = Math.hypot(x - px, y - py);
      if (d < best.dist) {
        const tx = abx / segLen;
        const ty = aby / segLen;
        best = {
          dist: d,
          t,
          nx: -ty,
          ny: tx,
          tx,
          ty,
          px,
          py,
          seg: i,
          along: alongAcc + segLen * t,
          side: (x - px) * (-ty) + (y - py) * tx,
        };
      }
      alongAcc += segLen;
    }
    return best;
  }

  function pointOnTrack(progress) {
    let p = ((progress % TRACK_LEN) + TRACK_LEN) % TRACK_LEN;
    let acc = 0;
    for (let i = 0; i < TRACK.length; i++) {
      const a = TRACK[i];
      const b = TRACK[(i + 1) % TRACK.length];
      const segLen = dist(a, b);
      if (acc + segLen >= p) {
        const t = (p - acc) / segLen;
        const x = a.x + (b.x - a.x) * t;
        const y = a.y + (b.y - a.y) * t;
        const ang = Math.atan2(b.y - a.y, b.x - a.x);
        return { x, y, ang };
      }
      acc += segLen;
    }
    return { x: TRACK[0].x, y: TRACK[0].y, ang: 0 };
  }

  function createCart(racerIndex, isPlayer, startOffset) {
    const r = RACERS[racerIndex];
    const start = pointOnTrack(TRACK_LEN - 40 - startOffset * 28);
    return {
      racerIndex,
      name: r.name,
      color: r.color,
      accent: r.accent,
      isPlayer,
      x: start.x + Math.cos(start.ang + Math.PI / 2) * (startOffset % 2 === 0 ? -18 : 18),
      y: start.y + Math.sin(start.ang + Math.PI / 2) * (startOffset % 2 === 0 ? -18 : 18),
      angle: start.ang,
      vx: 0,
      vy: 0,
      speed: 0,
      maxSpeed: 210 * r.speed,
      accel: 160 * r.accel,
      turnRate: 2.8 * r.handling,
      lap: 0,
      checkpoint: 0,
      progress: TRACK_LEN - 40 - startOffset * 28,
      finished: false,
      finishTime: 0,
      place: 0,
      item: null,
      boostTimer: 0,
      stunTimer: 0,
      shieldTimer: 0,
      driftTimer: 0,
      driftBoostReady: false,
      aiTargetOff: (Math.random() - 0.5) * 30,
      aiAggro: 0.7 + Math.random() * 0.5,
      sparks: 0,
      armedForLap: false,
    };
  }

  function spawnItemBoxes() {
    itemBoxes = [];
    const spots = [0.12, 0.28, 0.45, 0.62, 0.78, 0.9];
    for (const s of spots) {
      const p = pointOnTrack(TRACK_LEN * s);
      const side = (itemBoxes.length % 2 === 0 ? 1 : -1) * 28;
      itemBoxes.push({
        x: p.x + Math.cos(p.ang + Math.PI / 2) * side,
        y: p.y + Math.sin(p.ang + Math.PI / 2) * side,
        cooldown: 0,
        pulse: Math.random() * Math.PI * 2,
      });
    }
  }

  function initRace() {
    carts = [];
    hazards = [];
    projectiles = [];
    particles = [];
    raceTime = 0;
    const playerIdx = selectedRacer;
    let order = [playerIdx];
    for (let i = 0; i < RACERS.length; i++) {
      if (i !== playerIdx) order.push(i);
    }
    order = order.slice(0, CART_COUNT);
    order.forEach((ri, i) => {
      carts.push(createCart(ri, i === 0, i));
    });
    // shuffle grid positions a bit but keep player first visually? Keep startOffset by index.
    spawnItemBoxes();
    countdownValue = 3;
    countdownTimer = 0;
    state = "countdown";
    showScreen("countdownScreen");
    document.getElementById("countdownNum").textContent = "3";
    setHudVisible(false);
  }

  function placeOrdinal(n) {
    if (n === 1) return "1st";
    if (n === 2) return "2nd";
    if (n === 3) return "3rd";
    return n + "th";
  }

  function updatePlaces() {
    const ranked = [...carts].sort((a, b) => {
      const ap = a.lap * TRACK_LEN + a.progress;
      const bp = b.lap * TRACK_LEN + b.progress;
      if (b.finished !== a.finished) return a.finished ? -1 : 1;
      if (a.finished && b.finished) return a.finishTime - b.finishTime;
      return bp - ap;
    });
    ranked.forEach((c, i) => {
      c.place = i + 1;
    });
  }

  function spawnParticle(x, y, color, life = 0.4) {
    particles.push({
      x,
      y,
      vx: (Math.random() - 0.5) * 80,
      vy: (Math.random() - 0.5) * 80,
      life,
      max: life,
      color,
      size: 2 + Math.random() * 3,
    });
  }

  function useItem(cart) {
    if (!cart.item || cart.stunTimer > 0) return;
    const type = cart.item;
    cart.item = null;
    if (type === "boost") {
      cart.boostTimer = 1.35;
      for (let i = 0; i < 8; i++) spawnParticle(cart.x, cart.y, "#c8f542", 0.5);
    } else if (type === "banana") {
      const behind = cart.angle + Math.PI;
      hazards.push({
        type: "banana",
        x: cart.x + Math.cos(behind) * 36,
        y: cart.y + Math.sin(behind) * 36,
        life: 18,
        owner: cart,
      });
    } else if (type === "soup") {
      projectiles.push({
        type: "soup",
        x: cart.x + Math.cos(cart.angle) * 28,
        y: cart.y + Math.sin(cart.angle) * 28,
        vx: Math.cos(cart.angle) * 340,
        vy: Math.sin(cart.angle) * 340,
        life: 1.6,
        owner: cart,
      });
    } else if (type === "gum") {
      cart.shieldTimer = 0.05;
      hazards.push({
        type: "gum",
        x: cart.x + Math.cos(cart.angle + Math.PI) * 40,
        y: cart.y + Math.sin(cart.angle + Math.PI) * 40,
        life: 14,
        owner: cart,
      });
    }
  }

  function hitCart(cart, kind) {
    if (cart.shieldTimer > 0) {
      cart.shieldTimer = 0;
      return;
    }
    if (kind === "banana" || kind === "soup") {
      cart.stunTimer = 1.1;
      cart.speed *= 0.2;
      for (let i = 0; i < 12; i++) spawnParticle(cart.x, cart.y, cart.accent, 0.55);
    } else if (kind === "gum") {
      cart.stunTimer = 0.7;
      cart.speed *= 0.35;
      for (let i = 0; i < 8; i++) spawnParticle(cart.x, cart.y, "#ff8fab", 0.45);
    }
  }

  function steerInput(cart, dt) {
    if (cart.isPlayer) {
      let steer = 0;
      if (keys["ArrowLeft"] || keys["a"] || keys["A"] || touch.left) steer -= 1;
      if (keys["ArrowRight"] || keys["d"] || keys["D"] || touch.right) steer += 1;
      const drifting = keys[" "] || keys["Shift"] || touch.drift;
      if (keys["f"] || keys["F"] || touch.item) {
        if (!cart._itemLatch) {
          useItem(cart);
          cart._itemLatch = true;
        }
      } else {
        cart._itemLatch = false;
      }
      return { steer, drifting, throttle: 1 };
    }

    // AI
    const lookAhead = 70 + cart.speed * 0.25;
    const targetProg = cart.progress + lookAhead;
    const target = pointOnTrack(targetProg);
    const off = cart.aiTargetOff;
    const tx = target.x + Math.cos(target.ang + Math.PI / 2) * off;
    const ty = target.y + Math.sin(target.ang + Math.PI / 2) * off;
    const desired = Math.atan2(ty - cart.y, tx - cart.x);
    const diff = angleDiff(cart.angle, desired);
    let steer = clamp(diff * 1.8, -1, 1);
    const drifting = Math.abs(diff) > 0.55 && cart.speed > 90;
    if (cart.item && (cart.place > 1 || Math.random() < 0.01 * cart.aiAggro)) {
      if (cart.item === "boost" || cart.place > 1) useItem(cart);
    }
    return { steer, drifting, throttle: cart.stunTimer > 0 ? 0.2 : 1 };
  }

  function updateCart(cart, dt) {
    if (cart.finished) return;

    cart.boostTimer = Math.max(0, cart.boostTimer - dt);
    cart.stunTimer = Math.max(0, cart.stunTimer - dt);
    cart.shieldTimer = Math.max(0, cart.shieldTimer - dt);

    const input = steerInput(cart, dt);
    const maxSp = cart.maxSpeed * (cart.boostTimer > 0 ? 1.45 : 1) * (cart.stunTimer > 0 ? 0.35 : 1);
    const turnMul = input.drifting ? 1.55 : 1;
    const grip = input.drifting ? 0.92 : 0.98;

    if (cart.stunTimer <= 0) {
      cart.angle += input.steer * cart.turnRate * turnMul * (0.55 + 0.45 * (cart.speed / cart.maxSpeed)) * dt;
      cart.speed += cart.accel * input.throttle * dt;
      if (input.drifting && cart.speed > 60) {
        cart.speed -= 35 * dt;
        cart.driftTimer += dt;
        cart.sparks += dt;
        if (cart.driftTimer > 0.55) cart.driftBoostReady = true;
        if (cart.sparks > 0.05) {
          cart.sparks = 0;
          spawnParticle(
            cart.x - Math.cos(cart.angle) * 16,
            cart.y - Math.sin(cart.angle) * 16,
            "#ffb347",
            0.3
          );
        }
      } else {
        if (cart.driftBoostReady && cart.driftTimer > 0.55) {
          cart.boostTimer = Math.max(cart.boostTimer, 0.55);
          for (let i = 0; i < 6; i++) spawnParticle(cart.x, cart.y, "#7ec8e3", 0.4);
        }
        cart.driftTimer = 0;
        cart.driftBoostReady = false;
      }
    } else {
      cart.angle += Math.sin(raceTime * 20) * 0.8 * dt;
      cart.speed *= 1 - 1.5 * dt;
    }

    cart.speed = clamp(cart.speed, 0, maxSp);
    // velocity blend for slight slide
    const tx = Math.cos(cart.angle) * cart.speed;
    const ty = Math.sin(cart.angle) * cart.speed;
    cart.vx = cart.vx * (1 - grip) + tx * grip;
    cart.vy = cart.vy * (1 - grip) + ty * grip;
    cart.x += cart.vx * dt;
    cart.y += cart.vy * dt;

    // track collision / walls
    const np = nearestTrackPoint(cart.x, cart.y);
    const half = TRACK_WIDTH * 0.5;
    if (np.dist > half) {
      const push = np.dist - half;
      const sx = (cart.x - np.px) / (np.dist || 1);
      const sy = (cart.y - np.py) / (np.dist || 1);
      cart.x -= sx * push;
      cart.y -= sy * push;
      cart.vx *= 0.55;
      cart.vy *= 0.55;
      cart.speed *= 0.7;
      if (Math.random() < 0.3) spawnParticle(cart.x, cart.y, "#8d99ae", 0.25);
    }

    // progress / laps — must pass mid-track before a start/finish crossing counts
    let progDelta = np.along - (cart.progress % TRACK_LEN);
    if (progDelta > TRACK_LEN * 0.5) progDelta -= TRACK_LEN;
    if (progDelta < -TRACK_LEN * 0.5) progDelta += TRACK_LEN;
    if (progDelta > -40) {
      cart.progress = np.along;
      if (np.along > TRACK_LEN * 0.45 && np.along < TRACK_LEN * 0.9) {
        cart.armedForLap = true;
      }
      if (cart._lastAlong !== undefined && cart.armedForLap) {
        if (cart._lastAlong > TRACK_LEN * 0.85 && np.along < TRACK_LEN * 0.15) {
          cart.lap += 1;
          cart.armedForLap = false;
          if (cart.lap >= TOTAL_LAPS) {
            cart.finished = true;
            cart.finishTime = raceTime;
            cart.speed *= 0.3;
          }
        }
      }
      cart._lastAlong = np.along;
    }

    // item boxes
    for (const box of itemBoxes) {
      if (box.cooldown > 0) continue;
      if (dist(cart, box) < 28 && !cart.item) {
        cart.item = ITEM_KEYS[Math.floor(Math.random() * ITEM_KEYS.length)];
        box.cooldown = 3.5;
        for (let i = 0; i < 6; i++) spawnParticle(box.x, box.y, "#c8f542", 0.4);
      }
    }

    // hazards
    for (let i = hazards.length - 1; i >= 0; i--) {
      const h = hazards[i];
      if (h.owner === cart && h.life > 17) continue;
      if (dist(cart, h) < 22) {
        hitCart(cart, h.type);
        hazards.splice(i, 1);
      }
    }
  }

  function updateProjectiles(dt) {
    for (let i = projectiles.length - 1; i >= 0; i--) {
      const p = projectiles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      const np = nearestTrackPoint(p.x, p.y);
      if (p.life <= 0 || np.dist > TRACK_WIDTH * 0.55) {
        projectiles.splice(i, 1);
        continue;
      }
      for (const cart of carts) {
        if (cart === p.owner) continue;
        if (dist(cart, p) < 24) {
          hitCart(cart, "soup");
          projectiles.splice(i, 1);
          break;
        }
      }
    }
  }

  function updateHazards(dt) {
    for (let i = hazards.length - 1; i >= 0; i--) {
      hazards[i].life -= dt;
      if (hazards[i].life <= 0) hazards.splice(i, 1);
    }
  }

  function updateItems(dt) {
    for (const box of itemBoxes) {
      box.cooldown = Math.max(0, box.cooldown - dt);
      box.pulse += dt * 4;
    }
  }

  function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) particles.splice(i, 1);
    }
  }

  function cartCartCollision() {
    for (let i = 0; i < carts.length; i++) {
      for (let j = i + 1; j < carts.length; j++) {
        const a = carts[i];
        const b = carts[j];
        const d = dist(a, b);
        if (d < 34 && d > 0.01) {
          const nx = (b.x - a.x) / d;
          const ny = (b.y - a.y) / d;
          const overlap = 34 - d;
          a.x -= nx * overlap * 0.5;
          a.y -= ny * overlap * 0.5;
          b.x += nx * overlap * 0.5;
          b.y += ny * overlap * 0.5;
          const dvx = b.vx - a.vx;
          const dvy = b.vy - a.vy;
          const impact = dvx * nx + dvy * ny;
          if (impact < 0) {
            a.vx += nx * impact;
            a.vy += ny * impact;
            b.vx -= nx * impact;
            b.vy -= ny * impact;
            a.speed *= 0.92;
            b.speed *= 0.92;
          }
        }
      }
    }
  }

  function formatTime(t) {
    const m = Math.floor(t / 60);
    const s = Math.floor(t % 60);
    const d = Math.floor((t % 1) * 10);
    return m + ":" + String(s).padStart(2, "0") + "." + d;
  }

  function updateHud() {
    const player = carts.find((c) => c.isPlayer);
    if (!player) return;
    document.getElementById("lapInfo").textContent =
      "LAP " + Math.min(player.lap + 1, TOTAL_LAPS) + "/" + TOTAL_LAPS;
    document.getElementById("placeInfo").textContent = placeOrdinal(player.place);
    document.getElementById("timeInfo").textContent = formatTime(raceTime);
    document.getElementById("itemIcon").textContent = player.item ? ITEMS[player.item].icon : "·";
  }

  function endRaceIfNeeded() {
    const player = carts.find((c) => c.isPlayer);
    const allDone = carts.every((c) => c.finished);
    if (player.finished || allDone) {
      // wait a beat if player finished
      if (player.finished) {
        // finish AI quickly for standings if needed
        carts.forEach((c) => {
          if (!c.finished) {
            c.finished = true;
            c.finishTime = raceTime + (c.place - player.place) * 0.01 + Math.random();
          }
        });
        updatePlaces();
        state = "results";
        setHudVisible(false);
        showScreen("resultScreen");
        const title = player.place === 1 ? "AISLE CHAMP!" : player.place === 2 ? "SOLID HAUL" : "CART WIPED";
        document.getElementById("resultTitle").textContent = title;
        document.getElementById("resultPlace").textContent = placeOrdinal(player.place);
        document.getElementById("resultTime").textContent = "Time " + formatTime(player.finishTime || raceTime);
        const list = document.getElementById("resultStandings");
        list.innerHTML = "";
        [...carts]
          .sort((a, b) => a.place - b.place)
          .forEach((c) => {
            const li = document.createElement("li");
            if (c.isPlayer) li.className = "you";
            li.innerHTML = `<span>${placeOrdinal(c.place)} ${c.name}${c.isPlayer ? " (YOU)" : ""}</span><span>${formatTime(c.finishTime || raceTime)}</span>`;
            list.appendChild(li);
          });
      }
    }
  }

  // —— Rendering ——
  function trackPath() {
    ctx.beginPath();
    TRACK.forEach((p, i) => {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.closePath();
  }

  function drawTrack() {
    ctx.lineJoin = "round";
    ctx.lineCap = "round";

    // supermarket shelf blocks framing the aisle
    trackPath();
    ctx.strokeStyle = "#2a3528";
    ctx.lineWidth = TRACK_WIDTH + SHELF_MARGIN * 2 + 24;
    ctx.stroke();

    trackPath();
    ctx.strokeStyle = "#3d4f3a";
    ctx.lineWidth = TRACK_WIDTH + SHELF_MARGIN * 2;
    ctx.stroke();

    // shelf lip
    trackPath();
    ctx.strokeStyle = "#5a6e54";
    ctx.lineWidth = TRACK_WIDTH + 18;
    ctx.stroke();

    // linoleum aisle only (not the whole store)
    trackPath();
    ctx.strokeStyle = "#e2d6b4";
    ctx.lineWidth = TRACK_WIDTH;
    ctx.stroke();

    // subtle tile seams along aisle
    trackPath();
    ctx.save();
    ctx.setLineDash([6, 10]);
    ctx.strokeStyle = "rgba(120, 100, 70, 0.18)";
    ctx.lineWidth = TRACK_WIDTH - 8;
    ctx.stroke();
    ctx.restore();

    // lane dashes
    trackPath();
    ctx.save();
    ctx.setLineDash([18, 16]);
    ctx.strokeStyle = "rgba(255,255,255,0.4)";
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.restore();

    // start/finish
    const a = TRACK[0];
    const b = TRACK[1];
    const ang = Math.atan2(b.y - a.y, b.x - a.x);
    ctx.save();
    ctx.translate(a.x, a.y);
    ctx.rotate(ang);
    for (let i = -4; i < 4; i++) {
      ctx.fillStyle = i % 2 === 0 ? "#111" : "#f3efe4";
      ctx.fillRect(-6, i * (TRACK_WIDTH / 8), 12, TRACK_WIDTH / 8);
    }
    ctx.restore();

    // grocery products stacked on shelf edges
    for (let i = 0; i < TRACK.length; i++) {
      const p = TRACK[i];
      const q = TRACK[(i + 1) % TRACK.length];
      const segLen = dist(p, q);
      const steps = Math.floor(segLen / 42);
      const ang2 = Math.atan2(q.y - p.y, q.x - p.x);
      const nx = -Math.sin(ang2);
      const ny = Math.cos(ang2);
      for (let s = 0; s < steps; s++) {
        const t = (s + 0.5) / steps;
        const x = p.x + (q.x - p.x) * t;
        const y = p.y + (q.y - p.y) * t;
        const colors = ["#e63946", "#457b9d", "#f4a261", "#2a9d8f", "#e9c46a", "#ff6b4a"];
        for (const side of [1, -1]) {
          ctx.fillStyle = colors[(i + s + (side > 0 ? 0 : 2)) % colors.length];
          const ox = x + nx * side * (TRACK_WIDTH * 0.5 + 22);
          const oy = y + ny * side * (TRACK_WIDTH * 0.5 + 22);
          ctx.fillRect(ox - 6, oy - 8, 12, 16);
          ctx.fillStyle = "rgba(255,255,255,0.15)";
          ctx.fillRect(ox - 6, oy - 8, 12, 4);
        }
      }
    }
  }

  function drawItemBox(box) {
    if (box.cooldown > 0) {
      ctx.globalAlpha = 0.25;
    }
    const bob = Math.sin(box.pulse) * 3;
    ctx.save();
    ctx.translate(box.x, box.y + bob);
    ctx.rotate(box.pulse * 0.25);
    ctx.fillStyle = "#c8f542";
    ctx.strokeStyle = "#0e1610";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.rect(-12, -12, 24, 24);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#0e1610";
    ctx.font = "bold 14px Space Grotesk";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("?", 0, 1);
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  function drawHazard(h) {
    ctx.save();
    ctx.translate(h.x, h.y);
    if (h.type === "banana") {
      ctx.fillStyle = "#ffe566";
      ctx.beginPath();
      ctx.ellipse(0, 0, 12, 7, 0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#c9a227";
      ctx.stroke();
    } else {
      ctx.fillStyle = "#ff8fab";
      ctx.beginPath();
      ctx.arc(0, 0, 11, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.35)";
      ctx.beginPath();
      ctx.arc(-3, -3, 4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawProjectile(p) {
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(Math.atan2(p.vy, p.vx));
    ctx.fillStyle = "#e76f51";
    ctx.fillRect(-8, -6, 16, 12);
    ctx.fillStyle = "#fff";
    ctx.font = "10px sans-serif";
    ctx.fillText("SOUP", -10, 3);
    ctx.restore();
  }

  function drawCart(cart) {
    ctx.save();
    ctx.translate(cart.x, cart.y);
    ctx.rotate(cart.angle);

    // shadow
    ctx.fillStyle = "rgba(0,0,0,0.3)";
    ctx.beginPath();
    ctx.ellipse(1, 4, 20, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    if (cart.boostTimer > 0) {
      ctx.fillStyle = "#c8f542";
      ctx.globalAlpha = 0.75;
      ctx.beginPath();
      ctx.moveTo(-20, -7);
      ctx.lineTo(-34 - Math.random() * 10, 0);
      ctx.lineTo(-20, 7);
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    // metal basket body
    ctx.fillStyle = cart.color;
    ctx.strokeStyle = cart.accent;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(-14, -13);
    ctx.lineTo(12, -12);
    ctx.lineTo(16, -8);
    ctx.lineTo(16, 8);
    ctx.lineTo(12, 12);
    ctx.lineTo(-14, 13);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // wire mesh
    ctx.strokeStyle = "rgba(255,255,255,0.35)";
    ctx.lineWidth = 1.2;
    for (let i = -9; i <= 9; i += 4.5) {
      ctx.beginPath();
      ctx.moveTo(-12, i);
      ctx.lineTo(13, i * 0.92);
      ctx.stroke();
    }
    for (let i = -10; i <= 12; i += 5) {
      ctx.beginPath();
      ctx.moveTo(i, -11);
      ctx.lineTo(i + 2, 11);
      ctx.stroke();
    }

    // child seat / front flap
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.fillRect(8, -9, 6, 18);

    // push handle at back
    ctx.strokeStyle = cart.accent;
    ctx.lineWidth = 3.5;
    ctx.beginPath();
    ctx.moveTo(-14, -12);
    ctx.lineTo(-24, -15);
    ctx.lineTo(-24, 15);
    ctx.lineTo(-14, 12);
    ctx.stroke();
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-26, -15);
    ctx.lineTo(-26, 15);
    ctx.stroke();

    // wheels
    ctx.fillStyle = "#1a1a1a";
    [[-6, -14], [10, -13], [-6, 14], [10, 13]].forEach(([wx, wy]) => {
      ctx.beginPath();
      ctx.arc(wx, wy, 3.8, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#555";
      ctx.beginPath();
      ctx.arc(wx, wy, 1.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#1a1a1a";
    });

    // driver
    ctx.fillStyle = cart.accent;
    ctx.beginPath();
    ctx.arc(-4, 0, 7, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = cart.color;
    ctx.beginPath();
    ctx.arc(-4, 0, 4.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#0e1610";
    ctx.beginPath();
    ctx.arc(-3, -1.5, 1.6, 0, Math.PI * 2);
    ctx.fill();

    // junk in cart
    ctx.fillStyle = cart.accent;
    ctx.globalAlpha = 0.85;
    ctx.fillRect(0, -5, 5, 4);
    ctx.fillStyle = "#f3efe4";
    ctx.fillRect(2, 2, 4, 5);
    ctx.globalAlpha = 1;

    if (cart.isPlayer) {
      ctx.fillStyle = "#c8f542";
      ctx.beginPath();
      ctx.moveTo(20, 0);
      ctx.lineTo(12, -5);
      ctx.lineTo(12, 5);
      ctx.fill();
    }

    ctx.restore();

    // name tag
    ctx.save();
    ctx.font = "600 11px Space Grotesk";
    ctx.textAlign = "center";
    ctx.fillStyle = "rgba(14,22,16,0.7)";
    ctx.fillRect(cart.x - 28, cart.y - 38, 56, 14);
    ctx.fillStyle = cart.isPlayer ? "#c8f542" : "#f3efe4";
    ctx.fillText(cart.isPlayer ? "YOU" : cart.name.split(" ").pop(), cart.x, cart.y - 28);
    ctx.restore();
  }

  function drawParticles() {
    for (const p of particles) {
      ctx.globalAlpha = clamp(p.life / p.max, 0, 1);
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  function drawMinimap() {
    mctx.clearRect(0, 0, minimap.width, minimap.height);
    const scale = 0.12;
    const cx = minimap.width / 2;
    const cy = minimap.height / 2;
    mctx.save();
    mctx.translate(cx, cy);
    mctx.strokeStyle = "#4a5c45";
    mctx.lineWidth = 8;
    mctx.beginPath();
    TRACK.forEach((p, i) => {
      if (i === 0) mctx.moveTo(p.x * scale, p.y * scale);
      else mctx.lineTo(p.x * scale, p.y * scale);
    });
    mctx.closePath();
    mctx.stroke();
    mctx.strokeStyle = "#d5c9a6";
    mctx.lineWidth = 4;
    mctx.stroke();
    for (const c of carts) {
      mctx.fillStyle = c.isPlayer ? "#c8f542" : c.color;
      mctx.beginPath();
      mctx.arc(c.x * scale, c.y * scale, c.isPlayer ? 3.5 : 2.5, 0, Math.PI * 2);
      mctx.fill();
    }
    mctx.restore();
  }

  function drawStoreDecor() {
    // overhead fluorescent vibe — vignette
    // drawn in screen space after world
  }

  function render() {
    ctx.clearRect(0, 0, W, H);

    const player = carts.find((c) => c.isPlayer) || { x: 0, y: 0 };
    camera.x += (player.x - camera.x) * 0.12;
    camera.y += (player.y - camera.y) * 0.12;

    ctx.save();
    ctx.translate(W / 2, H / 2);
    ctx.scale(camera.zoom, camera.zoom);
    ctx.translate(-camera.x, -camera.y);

    // dark closed-store floor beyond aisles
    ctx.fillStyle = "#121a14";
    ctx.fillRect(camera.x - 2000, camera.y - 2000, 4000, 4000);

    drawTrack();

    for (const box of itemBoxes) drawItemBox(box);
    for (const h of hazards) drawHazard(h);
    for (const p of projectiles) drawProjectile(p);
    drawParticles();

    // draw carts back-to-front by y
    [...carts].sort((a, b) => a.y - b.y).forEach(drawCart);

    ctx.restore();

    // screen vignette / fluorescents
    const g = ctx.createRadialGradient(W / 2, H * 0.35, 40, W / 2, H / 2, Math.max(W, H) * 0.7);
    g.addColorStop(0, "rgba(255,255,220,0.05)");
    g.addColorStop(0.55, "rgba(0,0,0,0)");
    g.addColorStop(1, "rgba(0,0,0,0.45)");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    // scanline-ish fluorescent bars
    ctx.fillStyle = "rgba(255,255,230,0.03)";
    for (let y = 0; y < H; y += 46) {
      ctx.fillRect(0, y, W, 2);
    }

    if (state === "racing" || state === "countdown") drawMinimap();
  }

  function update(dt) {
    if (state === "countdown") {
      countdownTimer += dt;
      const next = 3 - Math.floor(countdownTimer);
      if (next !== countdownValue && next > 0) {
        countdownValue = next;
        const el = document.getElementById("countdownNum");
        el.textContent = String(countdownValue);
        el.style.animation = "none";
        void el.offsetWidth;
        el.style.animation = "";
      }
      if (countdownTimer >= 3) {
        document.getElementById("countdownNum").textContent = "GO!";
      }
      if (countdownTimer >= 3.55) {
        state = "racing";
        showScreen(""); // hide all
        document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
        setHudVisible(true);
      }
      // still render carts frozen
      return;
    }

    if (state !== "racing") return;

    raceTime += dt;
    for (const c of carts) updateCart(c, dt);
    cartCartCollision();
    updateProjectiles(dt);
    updateHazards(dt);
    updateItems(dt);
    updateParticles(dt);
    updatePlaces();
    updateHud();
    endRaceIfNeeded();
  }

  function frame(ts) {
    if (!lastTs) lastTs = ts;
    let dt = (ts - lastTs) / 1000;
    lastTs = ts;
    dt = Math.min(dt, 0.05);
    update(dt);
    if (state === "racing" || state === "countdown" || state === "results") {
      if (carts.length) render();
    } else {
      // idle backdrop
      ctx.fillStyle = "#142018";
      ctx.fillRect(0, 0, W, H);
    }
    requestAnimationFrame(frame);
  }

  // —— UI wiring ——
  function buildRacerGrid() {
    const grid = document.getElementById("racerGrid");
    grid.innerHTML = "";
    RACERS.forEach((r, i) => {
      const card = document.createElement("button");
      card.type = "button";
      card.className = "racer-card" + (i === selectedRacer ? " selected" : "");
      card.innerHTML = `
        <div class="swatch" style="background:linear-gradient(135deg,${r.color},${r.accent})"></div>
        <div class="name">${r.name}</div>
        <div class="stat">${r.blurb}</div>
      `;
      card.addEventListener("click", () => {
        selectedRacer = i;
        buildRacerGrid();
      });
      grid.appendChild(card);
    });
  }

  document.getElementById("btnPlay").addEventListener("click", () => {
    state = "select";
    showScreen("selectScreen");
    buildRacerGrid();
  });
  document.getElementById("btnHow").addEventListener("click", () => {
    state = "how";
    showScreen("howScreen");
  });
  document.getElementById("btnBackHow").addEventListener("click", () => {
    state = "title";
    showScreen("titleScreen");
  });
  document.getElementById("btnBackSelect").addEventListener("click", () => {
    state = "title";
    showScreen("titleScreen");
  });
  document.getElementById("btnStartRace").addEventListener("click", initRace);
  document.getElementById("btnRetry").addEventListener("click", initRace);
  document.getElementById("btnMenu").addEventListener("click", () => {
    state = "title";
    carts = [];
    setHudVisible(false);
    showScreen("titleScreen");
  });

  window.addEventListener("keydown", (e) => {
    keys[e.key] = true;
    if (["ArrowLeft", "ArrowRight", " ", "Spacebar"].includes(e.key)) e.preventDefault();
  });
  window.addEventListener("keyup", (e) => {
    keys[e.key] = false;
  });

  function bindTouch(id, prop) {
    const el = document.getElementById(id);
    const on = (e) => {
      e.preventDefault();
      touch[prop] = true;
    };
    const off = (e) => {
      e.preventDefault();
      touch[prop] = false;
    };
    el.addEventListener("touchstart", on, { passive: false });
    el.addEventListener("touchend", off, { passive: false });
    el.addEventListener("touchcancel", off, { passive: false });
    el.addEventListener("mousedown", on);
    el.addEventListener("mouseup", off);
    el.addEventListener("mouseleave", off);
  }
  bindTouch("btnLeft", "left");
  bindTouch("btnRight", "right");
  bindTouch("btnDrift", "drift");
  bindTouch("btnItem", "item");

  window.addEventListener("resize", resize);
  resize();
  buildRacerGrid();
  requestAnimationFrame(frame);
})();
