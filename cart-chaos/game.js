(() => {
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");

  const TOTAL_LAPS = 3;
  const RACER_COUNT = 4;

  const ROSTER = [
    { id: "rusty", name: "Rusty Rex", motto: "Squeaky but speedy", color: "#8c949e", accent: "#d97333", speed: 1.05, handling: 0.95, weight: 1 },
    { id: "coupon", name: "Coupon Queen", motto: "Cuts every corner", color: "#e6598c", accent: "#ffd933", speed: 0.95, handling: 1.15, weight: 0.9 },
    { id: "dumpster", name: "Dumpster Dan", motto: "Built like a brick", color: "#598c66", accent: "#b28c4d", speed: 0.9, handling: 0.85, weight: 1.25 },
    { id: "aisle", name: "Aisle Ace", motto: "Knows every shortcut", color: "#4073d9", accent: "#66e6f2", speed: 1, handling: 1.05, weight: 1 },
    { id: "midnight", name: "Midnight Mick", motto: "Races after closing", color: "#2e2e38", accent: "#f2bf40", speed: 1.1, handling: 0.9, weight: 0.95 },
    { id: "bag", name: "Bag Lady", motto: "Plastic and proud", color: "#f2ebe0", accent: "#33a68c", speed: 1, handling: 1.1, weight: 0.85 },
  ];

  const ITEMS = {
    banana: { label: "BANANA", color: "#f2d133" },
    soda: { label: "SODA", color: "#26b873" },
    soup: { label: "SOUP", color: "#d95933" },
    coupon: { label: "COUPON", color: "#4d8cf2" },
  };

  const CENTERLINE = [
    [400, 350], [900, 280], [1400, 320], [1900, 400],
    [2100, 700], [2050, 1100], [1800, 1400], [1300, 1550],
    [800, 1500], [400, 1300], [280, 900], [320, 550],
  ];
  const WORLD = { w: 2400, h: 1800 };
  const TRACK_HALF = 95;

  const state = {
    screen: "menu",
    selected: 0,
    carts: [],
    player: null,
    boxes: [],
    hazards: [],
    projectiles: [],
    cam: { x: 0, y: 0 },
    input: { left: false, right: false, gas: false, brake: false },
    racing: false,
    raceOver: false,
    countdown: 3,
    last: 0,
    tiltSteer: 0,
    finishCount: 0,
    order: [],
  };

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.floor(innerWidth * dpr);
    canvas.height = Math.floor(innerHeight * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  addEventListener("resize", resize);
  resize();

  // UI wiring
  const $ = (id) => document.getElementById(id);
  const show = (id) => { $(id).classList.remove("hidden"); };
  const hide = (id) => { $(id).classList.add("hidden"); };

  function renderRoster() {
    const root = $("roster");
    root.innerHTML = "";
    ROSTER.forEach((c, i) => {
      const el = document.createElement("button");
      el.type = "button";
      el.className = "cart-card" + (i === state.selected ? " selected" : "");
      el.innerHTML = `
        <span class="swatch" style="background:${c.color};box-shadow:inset 0 0 0 3px ${c.accent}"></span>
        <span><strong>${c.name}</strong><small>${c.motto}</small></span>
        <span class="stats">SPD ${Math.round(c.speed * 100)}<br/>HND ${Math.round(c.handling * 100)}</span>`;
      el.onclick = () => { state.selected = i; renderRoster(); };
      root.appendChild(el);
    });
  }
  renderRoster();

  $("btnPlay").onclick = () => { hide("menu"); show("select"); };
  $("btnHow").onclick = () => { hide("menu"); show("howto"); };
  $("btnHowClose").onclick = () => { hide("howto"); show("menu"); };
  $("btnBack").onclick = () => { hide("select"); show("menu"); };
  $("btnStart").onclick = () => startRace();
  $("btnAgain").onclick = () => { hide("results"); show("select"); };
  $("btnMenu").onclick = () => { hide("results"); show("menu"); };

  function bindCtl(btn) {
    const act = btn.dataset.act;
    const set = (v) => {
      if (act === "left") state.input.left = v;
      if (act === "right") state.input.right = v;
      if (act === "gas") state.input.gas = v;
      if (act === "brake") state.input.brake = v;
      if (act === "item" && v) useItem(state.player);
    };
    btn.addEventListener("pointerdown", (e) => { e.preventDefault(); btn.setPointerCapture(e.pointerId); set(true); });
    btn.addEventListener("pointerup", (e) => { e.preventDefault(); set(false); });
    btn.addEventListener("pointercancel", () => set(false));
  }
  document.querySelectorAll(".ctl").forEach(bindCtl);

  addEventListener("keydown", (e) => {
    if (e.code === "ArrowLeft" || e.code === "KeyA") state.input.left = true;
    if (e.code === "ArrowRight" || e.code === "KeyD") state.input.right = true;
    if (e.code === "ArrowUp" || e.code === "KeyW" || e.code === "Space") state.input.gas = true;
    if (e.code === "ArrowDown" || e.code === "KeyS") state.input.brake = true;
    if (e.code === "KeyE" || e.code === "ShiftLeft") useItem(state.player);
  });
  addEventListener("keyup", (e) => {
    if (e.code === "ArrowLeft" || e.code === "KeyA") state.input.left = false;
    if (e.code === "ArrowRight" || e.code === "KeyD") state.input.right = false;
    if (e.code === "ArrowUp" || e.code === "KeyW" || e.code === "Space") state.input.gas = false;
    if (e.code === "ArrowDown" || e.code === "KeyS") state.input.brake = false;
  });

  if (window.DeviceOrientationEvent) {
    addEventListener("deviceorientation", (e) => {
      const g = e.gamma ?? 0;
      state.tiltSteer = Math.max(-1, Math.min(1, g / 25));
    });
  }

  function distPointSeg(px, py, ax, ay, bx, by) {
    const abx = bx - ax, aby = by - ay;
    const apx = px - ax, apy = py - ay;
    const ab2 = abx * abx + aby * aby || 1;
    const t = Math.max(0, Math.min(1, (apx * abx + apy * aby) / ab2));
    const cx = ax + abx * t, cy = ay + aby * t;
    return Math.hypot(px - cx, py - cy);
  }

  function onTrack(x, y) {
    let min = Infinity;
    for (let i = 0; i < CENTERLINE.length; i++) {
      const a = CENTERLINE[i];
      const b = CENTERLINE[(i + 1) % CENTERLINE.length];
      min = Math.min(min, distPointSeg(x, y, a[0], a[1], b[0], b[1]));
    }
    return min <= TRACK_HALF + 8;
  }

  function makeCart(profile, isPlayer, x, y, heading) {
    return {
      profile, isPlayer, x, y, heading,
      vx: 0, vy: 0,
      lap: 0, cp: 0, progress: 0,
      item: null, spinning: 0, shield: 0, boost: 0,
      finished: false, place: 0,
    };
  }

  function startPositions(heading) {
    const start = CENTERLINE[0];
    const nx = Math.cos(heading + Math.PI / 2);
    const ny = Math.sin(heading + Math.PI / 2);
    const out = [];
    for (let i = 0; i < RACER_COUNT; i++) {
      const lane = (i % 2 === 0 ? -1 : 1) * 28;
      const row = Math.floor(i / 2) * -55;
      out.push([
        start[0] + nx * lane + Math.cos(heading) * row,
        start[1] + ny * lane + Math.sin(heading) * row,
      ]);
    }
    return out;
  }

  function startRace() {
    hide("select");
    hide("menu");
    show("hud");
    show("controls");
    show("countdown");

    const playerProfile = ROSTER[state.selected];
    const aiPool = ROSTER.filter((c) => c.id !== playerProfile.id).sort(() => Math.random() - 0.5);
    const a = CENTERLINE[0], b = CENTERLINE[1];
    const heading = Math.atan2(b[1] - a[1], b[0] - a[0]);
    const starts = startPositions(heading);

    state.carts = [];
    state.player = makeCart(playerProfile, true, starts[0][0], starts[0][1], heading);
    state.carts.push(state.player);
    for (let i = 1; i < RACER_COUNT; i++) {
      state.carts.push(makeCart(aiPool[i - 1], false, starts[i][0], starts[i][1], heading));
    }

    state.boxes = [
      [900, 280], [1900, 400], [2050, 1100], [1300, 1550],
      [400, 1300], [320, 550], [1400, 320], [1800, 1400],
    ].map(([x, y]) => ({ x, y, ready: true, t: 0 }));
    state.hazards = [];
    state.projectiles = [];
    state.racing = false;
    state.raceOver = false;
    state.finishCount = 0;
    state.order = [];
    state.cam.x = state.player.x - innerWidth / 2;
    state.cam.y = state.player.y - innerHeight / 2;
    state.screen = "race";

    let n = 3;
    $("countdown").textContent = "3";
    $("countdown").style.color = "#f2c94c";
    const tick = () => {
      n -= 1;
      if (n > 0) {
        $("countdown").textContent = String(n);
        setTimeout(tick, 900);
      } else if (n === 0) {
        $("countdown").textContent = "GO!";
        $("countdown").style.color = "#3aa76d";
        state.racing = true;
        setTimeout(() => hide("countdown"), 500);
      }
    };
    setTimeout(tick, 900);
  }

  function maxSpeed(c) {
    return 420 * c.profile.speed * (c.boost > 0 ? 1.45 : 1);
  }

  function applyInput(c, throttle, steer, dt) {
    if (c.finished) {
      c.vx *= 0.9; c.vy *= 0.9;
      c.x += c.vx * dt; c.y += c.vy * dt;
      return;
    }
    if (c.spinning > 0) {
      c.spinning -= dt;
      c.heading += dt * 12;
      c.vx *= 0.92; c.vy *= 0.92;
      c.x += c.vx * dt; c.y += c.vy * dt;
      return;
    }

    const turn = 2.8 * c.profile.handling;
    c.heading += steer * turn * dt;
    const accel = throttle * 780 * c.profile.speed;
    const drag = throttle > 0.1 ? 0.985 : 0.94;
    c.vx += Math.cos(c.heading) * accel * dt;
    c.vy += Math.sin(c.heading) * accel * dt;
    c.vx *= drag; c.vy *= drag;
    const sp = Math.hypot(c.vx, c.vy);
    const mx = maxSpeed(c);
    if (sp > mx) { c.vx *= mx / sp; c.vy *= mx / sp; }
    c.x += c.vx * dt; c.y += c.vy * dt;

    if (c.boost > 0) c.boost -= dt;
    if (c.shield > 0) c.shield -= dt;

    c.x = Math.max(40, Math.min(WORLD.w - 40, c.x));
    c.y = Math.max(40, Math.min(WORLD.h - 40, c.y));
    if (!onTrack(c.x, c.y)) { c.vx *= 0.9; c.vy *= 0.9; }
  }

  function aiSteer(c) {
    const look = 2;
    const idx = (c.cp + look) % CENTERLINE.length;
    const t = CENTERLINE[idx];
    const hash = (c.profile.id.charCodeAt(0) % 7) - 3;
    const desired = Math.atan2(t[1] + hash * 5 - c.y, t[0] + hash * 8 - c.x);
    let delta = desired - c.heading;
    while (delta > Math.PI) delta -= Math.PI * 2;
    while (delta < -Math.PI) delta += Math.PI * 2;
    let steer = Math.max(-1, Math.min(1, delta * 1.8));
    let throttle = 0.95;
    if (Math.abs(delta) > 0.7) throttle *= 0.65;
    if (!onTrack(c.x, c.y)) throttle = 0.4;
    let use = false;
    if (c.item) {
      if ((c.item === "soda" || c.item === "coupon") && Math.random() < 0.01) use = true;
      if (c.item === "banana" && Math.random() < 0.008) use = true;
      if (c.item === "soup" && Math.abs(delta) < 0.35 && Math.random() < 0.015) use = true;
    }
    return { throttle, steer, use };
  }

  function useItem(c) {
    if (!c || !c.item) return;
    const kind = c.item;
    c.item = null;
    if (kind === "banana") {
      state.hazards.push({
        x: c.x - Math.cos(c.heading) * 40,
        y: c.y - Math.sin(c.heading) * 40,
        kind: "banana",
      });
    } else if (kind === "soda") {
      c.boost = 1.6;
    } else if (kind === "coupon") {
      c.shield = 2.5;
    } else if (kind === "soup") {
      state.projectiles.push({
        x: c.x + Math.cos(c.heading) * 36,
        y: c.y + Math.sin(c.heading) * 36,
        vx: Math.cos(c.heading) * 520,
        vy: Math.sin(c.heading) * 520,
        life: 2.2,
        owner: c,
      });
    }
  }

  function hit(c) {
    if (c.shield > 0) { c.shield = 0; return; }
    c.spinning = 1.2;
    c.vx *= 0.2; c.vy *= 0.2;
  }

  function updateCheckpoints(c) {
    if (c.finished) return;
    const next = c.cp % CENTERLINE.length;
    const [px, py] = CENTERLINE[next];
    if (Math.hypot(c.x - px, c.y - py) < 110) {
      c.cp += 1;
      if (c.cp > 0 && c.cp % CENTERLINE.length === 0) {
        c.lap += 1;
        if (c.lap >= TOTAL_LAPS) {
          state.finishCount += 1;
          c.finished = true;
          c.place = state.finishCount;
          c.vx = 0; c.vy = 0;
          state.order.push(c);
        }
      }
    }
    const i = c.cp % CENTERLINE.length;
    const a = CENTERLINE[i], b = CENTERLINE[(i + 1) % CENTERLINE.length];
    const seg = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    const t = Math.max(0, Math.min(1, ((c.x - a[0]) * (b[0] - a[0]) + (c.y - a[1]) * (b[1] - a[1])) / (seg * seg)));
    c.progress = c.lap * CENTERLINE.length + c.cp + t;
  }

  function updatePowerups(dt) {
    for (const c of state.carts) {
      if (c.finished) continue;
      if (!c.item) {
        for (const box of state.boxes) {
          if (!box.ready) continue;
          if (Math.hypot(c.x - box.x, c.y - box.y) < 30) {
            c.item = Object.keys(ITEMS)[Math.floor(Math.random() * 4)];
            box.ready = false;
            box.t = 4.5;
          }
        }
      }
      for (let i = state.hazards.length - 1; i >= 0; i--) {
        const h = state.hazards[i];
        if (Math.hypot(c.x - h.x, c.y - h.y) < 26) {
          hit(c);
          state.hazards.splice(i, 1);
        }
      }
      for (let i = state.projectiles.length - 1; i >= 0; i--) {
        const p = state.projectiles[i];
        if (p.owner === c) continue;
        if (Math.hypot(c.x - p.x, c.y - p.y) < 28) {
          hit(c);
          state.projectiles.splice(i, 1);
        }
      }
    }
    for (const box of state.boxes) {
      if (!box.ready) {
        box.t -= dt;
        if (box.t <= 0) box.ready = true;
      }
    }
    for (let i = state.projectiles.length - 1; i >= 0; i--) {
      const p = state.projectiles[i];
      p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt;
      if (p.life <= 0) state.projectiles.splice(i, 1);
    }
  }

  function collideCarts() {
    for (let i = 0; i < state.carts.length; i++) {
      for (let j = i + 1; j < state.carts.length; j++) {
        const a = state.carts[i], b = state.carts[j];
        const dx = b.x - a.x, dy = b.y - a.y;
        const d = Math.hypot(dx, dy);
        const min = 44;
        if (d < min && d > 0.1) {
          const nx = dx / d, ny = dy / d;
          const overlap = (min - d) / 2;
          a.x -= nx * overlap; a.y -= ny * overlap;
          b.x += nx * overlap; b.y += ny * overlap;
          const wa = a.profile.weight, wb = b.profile.weight;
          const impact = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
          if (impact > 0) continue;
          const imp = 1.6 * impact / (wa + wb);
          a.vx -= imp * wb * nx; a.vy -= imp * wb * ny;
          b.vx += imp * wa * nx; b.vy += imp * wa * ny;
        }
      }
    }
  }

  function endRace() {
    if (state.raceOver) return;
    state.raceOver = true;
    const unfinished = state.carts.filter((c) => !c.finished).sort((a, b) => b.progress - a.progress);
    const order = [...state.order, ...unfinished];
    hide("controls");
    hide("hud");
    setTimeout(() => {
      const place = state.player.place || (order.indexOf(state.player) + 1);
      $("placeTitle").textContent = place === 1 ? "YOU WON THE LOT!" : `FINISHED #${place}`;
      $("placeSub").textContent = place === 1 ? "MegaMart belongs to the carts tonight." : "The aisles remember.";
      const ol = $("standings");
      ol.innerHTML = "";
      order.forEach((c, i) => {
        const li = document.createElement("li");
        li.textContent = `${i + 1}. ${c.profile.name}${c.isPlayer ? "  (YOU)" : ""}`;
        if (c.isPlayer) li.classList.add("you");
        ol.appendChild(li);
      });
      show("results");
      state.screen = "results";
    }, 1200);
  }

  function update(dt) {
    if (state.screen !== "race") return;
    const p = state.player;
    let throttle = 0;
    if (state.input.gas) throttle = 1;
    if (state.input.brake) throttle = -0.35;
    let steer = 0;
    if (state.input.left) steer = -1;
    else if (state.input.right) steer = 1;
    else steer = state.tiltSteer;
    if (!state.racing) { throttle = 0; steer = 0; }

    applyInput(p, throttle, steer, dt);
    if (state.racing) {
      for (const c of state.carts) {
        if (c.isPlayer || c.finished) continue;
        const ai = aiSteer(c);
        applyInput(c, ai.throttle, ai.steer, dt);
        if (ai.use) useItem(c);
      }
    }
    for (const c of state.carts) updateCheckpoints(c);
    updatePowerups(dt);
    collideCarts();

    state.cam.x += (p.x - innerWidth / 2 - state.cam.x) * 0.12;
    state.cam.y += (p.y - innerHeight / 2 - state.cam.y) * 0.12;

    const lap = Math.min(p.lap + 1, TOTAL_LAPS);
    $("lap").textContent = `LAP ${lap}/${TOTAL_LAPS}`;
    const sorted = [...state.carts].sort((a, b) => b.progress - a.progress);
    $("pos").textContent = `POS ${sorted.indexOf(p) + 1}/${state.carts.length}`;
    if (p.item) {
      $("item").textContent = `ITEM ${ITEMS[p.item].label}`;
      $("item").style.color = ITEMS[p.item].color;
    } else {
      $("item").textContent = "ITEM —";
      $("item").style.color = "#f2c94c";
    }

    if (p.finished) endRace();
  }

  // Drawing
  function drawFloor() {
    ctx.fillStyle = "#ebe4d4";
    ctx.fillRect(0, 0, WORLD.w, WORLD.h);
    ctx.strokeStyle = "rgba(0,0,0,0.06)";
    ctx.lineWidth = 1;
    for (let x = 0; x <= WORLD.w; x += 80) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, WORLD.h); ctx.stroke();
    }
    for (let y = 0; y <= WORLD.h; y += 80) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(WORLD.w, y); ctx.stroke();
    }
  }

  function strokeCenter(width, color, dash) {
    ctx.beginPath();
    CENTERLINE.forEach((p, i) => (i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])));
    ctx.closePath();
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.setLineDash(dash || []);
    ctx.stroke();
    ctx.setLineDash([]);
  }

  function drawTrack() {
    strokeCenter(TRACK_HALF * 2, "#8a8f98");
    strokeCenter(TRACK_HALF * 2 - 10, "rgba(242, 201, 76, 0.55)");
    strokeCenter(TRACK_HALF * 2 - 18, "#8a8f98");
    strokeCenter(3, "rgba(255,255,255,0.4)", [18, 14]);
  }

  function drawShelves() {
    const shelves = [
      [700, 700, 280, 70, "#bf403f"],
      [1100, 750, 260, 70, "#4073bf"],
      [900, 1050, 300, 70, "#4d994d"],
      [1500, 900, 80, 240, "#d98c26"],
      [550, 950, 80, 200, "#8c4da6"],
      [1700, 600, 200, 60, "#338c8c"],
    ];
    for (const [x, y, w, h, color] of shelves) {
      ctx.fillStyle = color;
      roundRect(x, y, w, h, 6);
      ctx.fill();
      for (let i = 0; i < 6; i++) {
        ctx.beginPath();
        ctx.fillStyle = `hsl(${i * 60},55%,60%)`;
        ctx.arc(x + w * 0.2 + (i % 3) * (w * 0.3), y + h * 0.35 + Math.floor(i / 3) * 18, 6, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.fillStyle = "rgba(60,60,60,0.35)";
    ctx.font = "bold 28px Bebas Neue, Impact, sans-serif";
    [["PRODUCE", 560, 520], ["FROZEN", 1660, 520], ["CEREAL", 1140, 1220], ["CHECKOUT", 430, 1520]].forEach(([t, x, y]) => {
      ctx.fillText(t, x, y);
    });
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function drawCart(c) {
    ctx.save();
    ctx.translate(c.x, c.y);
    ctx.rotate(c.heading + Math.PI / 2);

    if (c.boost > 0 || c.shield > 0 || c.isPlayer) {
      ctx.beginPath();
      ctx.fillStyle = c.shield > 0 ? "rgba(77,140,242,0.35)" : c.boost > 0 ? "rgba(38,184,115,0.35)" : `${c.profile.accent}33`;
      ctx.arc(0, 0, 28, 0, Math.PI * 2);
      ctx.fill();
    }

    // wheels
    ctx.fillStyle = "#222";
    [[-16, 18], [16, 18], [-16, -20], [16, -20]].forEach(([x, y]) => {
      ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2); ctx.fill();
    });

    // body
    ctx.fillStyle = c.profile.color;
    ctx.strokeStyle = c.profile.accent;
    ctx.lineWidth = 2.5;
    roundRect(-18, -26, 36, 52, 6);
    ctx.fill(); ctx.stroke();

    // basket wires
    ctx.strokeStyle = "rgba(255,255,255,0.45)";
    ctx.lineWidth = 1.2;
    for (let i = -1; i <= 1; i++) {
      ctx.beginPath();
      ctx.moveTo(-11, i * 6 + 4);
      ctx.lineTo(11, i * 6 + 4);
      ctx.stroke();
    }

    ctx.fillStyle = "#fff";
    ctx.font = "bold 11px DM Sans, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(c.isPlayer ? "YOU" : c.profile.name.split(" ").pop(), 0, -34);
    ctx.restore();
  }

  function drawWorld() {
    ctx.save();
    ctx.translate(-state.cam.x, -state.cam.y);
    drawFloor();
    drawTrack();
    drawShelves();

    // start banner
    const s = CENTERLINE[0];
    ctx.fillStyle = "#1a1a1a";
    ctx.fillRect(s[0] - 80, s[1] + 60, 160, 18);
    ctx.fillStyle = "#fff";
    ctx.font = "bold 12px DM Sans, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("FINISH", s[0], s[1] + 73);

    for (const box of state.boxes) {
      ctx.globalAlpha = box.ready ? 1 : 0.2;
      ctx.fillStyle = "#f2c94c";
      ctx.strokeStyle = "#8c591a";
      ctx.lineWidth = 2;
      roundRect(box.x - 14, box.y - 14, 28, 28, 4);
      ctx.fill(); ctx.stroke();
      ctx.fillStyle = "#59330d";
      ctx.font = "bold 18px Bebas Neue, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("?", box.x, box.y + 6);
      ctx.globalAlpha = 1;
    }

    for (const h of state.hazards) {
      ctx.fillStyle = "#f2d133";
      ctx.beginPath();
      ctx.ellipse(h.x, h.y, 11, 7, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    for (const p of state.projectiles) {
      ctx.fillStyle = "#d95933";
      ctx.fillRect(p.x - 7, p.y - 9, 14, 18);
    }

    // draw carts back-to-front by y
    [...state.carts].sort((a, b) => a.y - b.y).forEach(drawCart);

    // minimap
    ctx.restore();
    drawMinimap();
  }

  function drawMinimap() {
    const mw = 120, mh = 90;
    const x = innerWidth - mw - 16;
    const y = 56 + (parseInt(getComputedStyle(document.documentElement).getPropertyValue("env(safe-area-inset-top)")) || 0);
    ctx.fillStyle = "rgba(18,21,28,0.55)";
    ctx.strokeStyle = "rgba(255,255,255,0.3)";
    ctx.lineWidth = 1.5;
    roundRect(x, y, mw, mh, 8);
    ctx.fill(); ctx.stroke();
    for (const c of state.carts) {
      ctx.beginPath();
      ctx.fillStyle = c.isPlayer ? "#f2c94c" : c.profile.color;
      ctx.arc(x + (c.x / WORLD.w) * mw, y + (c.y / WORLD.h) * mh, c.isPlayer ? 4 : 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function frame(t) {
    const dt = Math.min(1 / 30, state.last ? (t - state.last) / 1000 : 1 / 60);
    state.last = t;
    update(dt);

    ctx.clearRect(0, 0, innerWidth, innerHeight);
    if (state.screen === "race" || state.screen === "results") {
      // keep drawing world under results briefly
      if (state.screen === "race" || state.raceOver) drawWorld();
    } else {
      // idle preview swirl on canvas under menus
      ctx.fillStyle = "#8a8f98";
      ctx.fillRect(0, 0, innerWidth, innerHeight);
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
