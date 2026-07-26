(() => {
  "use strict";

  const LAPS = 3;
  const CARTS = [
    {
      id: "rusty",
      name: "Rusty",
      blurb: "Abandoned by produce. Slow start, tough frame.",
      color: "#c45c26",
      accent: "#6b3a1f",
      topSpeed: 280,
      accel: 210,
      turn: 2.55,
      grip: 0.9,
    },
    {
      id: "squeaky",
      name: "Squeaky",
      blurb: "Wheels scream. Turns like a shopping list on fire.",
      color: "#3d7ea6",
      accent: "#1f3f54",
      topSpeed: 265,
      accel: 230,
      turn: 3.2,
      grip: 1.05,
    },
    {
      id: "bent",
      name: "Bent Frame",
      blurb: "Survived the parking lot. Tanky bumper.",
      color: "#5a6b5c",
      accent: "#2d3830",
      topSpeed: 255,
      accel: 200,
      turn: 2.35,
      grip: 1.15,
    },
    {
      id: "express",
      name: "Express Lane",
      blurb: "Stolen from checkout. Pure aisle velocity.",
      color: "#e85d04",
      accent: "#7a2f05",
      topSpeed: 310,
      accel: 250,
      turn: 2.4,
      grip: 0.82,
    },
  ];

  const ITEM_ICONS = {
    banana: "🍌",
    soda: "🥤",
    soap: "🧼",
    can: "🥫",
  };

  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");

  const titleScreen = document.getElementById("titleScreen");
  const selectScreen = document.getElementById("selectScreen");
  const resultsScreen = document.getElementById("resultsScreen");
  const hud = document.getElementById("hud");
  const controls = document.getElementById("controls");
  const countdownEl = document.getElementById("countdown");
  const cartGrid = document.getElementById("cartGrid");
  const posLabel = document.getElementById("posLabel");
  const lapLabel = document.getElementById("lapLabel");
  const speedLabel = document.getElementById("speedLabel");
  const itemSlot = document.getElementById("itemSlot");
  const resultsTitle = document.getElementById("resultsTitle");
  const resultsList = document.getElementById("resultsList");

  let W = 0;
  let H = 0;
  let dpr = 1;
  let selectedCart = 0;
  let state = "title";
  let lastTime = 0;
  let race = null;
  let particles = [];
  let camera = { x: 0, y: 0, shake: 0 };
  let floorPattern = null;

  const input = {
    left: false,
    right: false,
    gas: false,
    brake: false,
    item: false,
  };

  // --- Track: supermarket loop with aisle walls ---
  const track = buildTrack();

  function buildTrack() {
    const pts = [];
    const cx = 0;
    const cy = 0;
    const outer = [
      [-900, -620],
      [900, -620],
      [980, -500],
      [980, 500],
      [900, 620],
      [-900, 620],
      [-980, 500],
      [-980, -500],
    ];
    // Smooth oval-ish path with aisle chicanes
    const path = [];
    const N = 120;
    for (let i = 0; i < N; i++) {
      const t = (i / N) * Math.PI * 2;
      let x = Math.cos(t) * 780;
      let y = Math.sin(t) * 480;
      // Squeeze into aisles
      if (Math.sin(t * 2) > 0.2) x *= 0.78;
      if (Math.cos(t * 3) > 0.35) y *= 0.72;
      // Checkout chicane
      if (t > 0.2 && t < 0.8) x += Math.sin(t * 8) * 40;
      if (t > 3.4 && t < 4.2) y += Math.cos(t * 6) * 35;
      path.push({ x, y });
    }

    const shelves = [];
    // Parallel aisle shelves
    for (let i = -3; i <= 3; i++) {
      if (i === 0) continue;
      shelves.push({
        x: i * 220,
        y: -180,
        w: 48,
        h: 280,
        type: "shelf",
      });
      shelves.push({
        x: i * 220,
        y: 220,
        w: 48,
        h: 260,
        type: "shelf",
      });
    }
    // Produce walls / freezer banks
    shelves.push({ x: -700, y: -420, w: 260, h: 50, type: "freezer" });
    shelves.push({ x: 420, y: -420, w: 320, h: 50, type: "freezer" });
    shelves.push({ x: -520, y: 420, w: 300, h: 50, type: "produce" });
    shelves.push({ x: 480, y: 420, w: 280, h: 50, type: "produce" });
    shelves.push({ x: -860, y: 0, w: 50, h: 220, type: "checkout" });
    shelves.push({ x: 860, y: 40, w: 50, h: 200, type: "checkout" });

    const boostPads = [
      { x: 0, y: -480, r: 55 },
      { x: 720, y: 0, r: 50 },
      { x: -200, y: 460, r: 50 },
    ];

    const itemBoxes = [
      { x: -500, y: -300, taken: 0 },
      { x: 300, y: -250, taken: 0 },
      { x: 600, y: 180, taken: 0 },
      { x: -650, y: 250, taken: 0 },
      { x: 100, y: 380, taken: 0 },
      { x: -100, y: -100, taken: 0 },
    ];

    return {
      path,
      width: 150,
      shelves,
      boostPads,
      itemBoxes,
      startIndex: 0,
      bounds: { minX: -1100, maxX: 1100, minY: -750, maxY: 750 },
    };
  }

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = canvas.clientWidth;
    H = canvas.clientHeight;
    canvas.width = Math.floor(W * dpr);
    canvas.height = Math.floor(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    floorPattern = null;
  }

  function show(el) {
    el.classList.remove("hidden");
  }
  function hide(el) {
    el.classList.add("hidden");
  }

  function renderCartSelect() {
    cartGrid.innerHTML = "";
    CARTS.forEach((c, i) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "cart-card" + (i === selectedCart ? " selected" : "");
      btn.innerHTML = `<h3>${c.name}</h3><p>${c.blurb}</p>`;
      btn.addEventListener("click", () => {
        selectedCart = i;
        renderCartSelect();
      });
      cartGrid.appendChild(btn);
    });
  }

  function pathPoint(i) {
    const p = track.path;
    const idx = ((i % p.length) + p.length) % p.length;
    return p[idx];
  }

  function nearestPathInfo(x, y) {
    let best = 0;
    let bestD = Infinity;
    for (let i = 0; i < track.path.length; i++) {
      const p = track.path[i];
      const d = (p.x - x) ** 2 + (p.y - y) ** 2;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    const a = pathPoint(best);
    const b = pathPoint(best + 1);
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const ang = Math.atan2(dy, dx);
    const dist = Math.hypot(x - a.x, y - a.y);
    return { index: best, dist, ang, onTrack: dist < track.width * 0.95 };
  }

  function progressOf(kart) {
    return kart.lap * track.path.length + kart.pathIndex + kart.pathFrac;
  }

  function createKart(def, isPlayer, lane) {
    const start = pathPoint(track.startIndex);
    const next = pathPoint(track.startIndex + 1);
    const ang = Math.atan2(next.y - start.y, next.x - start.x);
    const nx = Math.cos(ang + Math.PI / 2);
    const ny = Math.sin(ang + Math.PI / 2);
    return {
      ...def,
      isPlayer,
      x: start.x - Math.cos(ang) * (40 + lane * 55) + nx * (lane - 2) * 28,
      y: start.y - Math.sin(ang) * (40 + lane * 55) + ny * (lane - 2) * 28,
      vx: 0,
      vy: 0,
      angle: ang,
      speed: 0,
      lap: 0,
      pathIndex: track.startIndex,
      pathFrac: 0,
      finished: false,
      finishTime: 0,
      item: null,
      stun: 0,
      boost: 0,
      slip: 0,
      invuln: 0,
      aiTarget: track.startIndex + 8,
      aiSkill: 0.72 + Math.random() * 0.22,
    };
  }

  function startRace() {
    const playerDef = CARTS[selectedCart];
    const aliases = ["Lot Ghost", "Parking Pirate", "Coupon Bandit", "Night Stock"];
    const rivals = CARTS.filter((_, i) => i !== selectedCart);
    // Fill to 4 rivals; rename duplicates so the field stays readable
    let n = 0;
    while (rivals.length < 4) {
      const base = CARTS[n % CARTS.length];
      rivals.push({ ...base, name: aliases[n % aliases.length], id: base.id + "_x" + n });
      n += 1;
    }

    const field = [createKart(playerDef, true, 0)];
    rivals.slice(0, 4).forEach((r, i) => {
      const clone = { ...r, id: r.id + "_ai" + i };
      field.push(createKart(clone, false, i + 1));
    });

    track.itemBoxes.forEach((b) => {
      b.taken = 0;
    });
    particles = [];
    race = {
      karts: field,
      hazards: [],
      projectiles: [],
      time: 0,
      countdown: 3.05,
      go: false,
      over: false,
      placeFlash: 0,
    };
    camera.x = field[0].x;
    camera.y = field[0].y;
    state = "race";
    hide(titleScreen);
    hide(selectScreen);
    hide(resultsScreen);
    show(hud);
    show(controls);
    itemSlot.textContent = "—";
  }

  function spawnParticle(x, y, color, life, size, vx = 0, vy = 0) {
    particles.push({ x, y, color, life, max: life, size, vx, vy });
  }

  function rectHit(x, y, r, shelf) {
    const hx = Math.max(shelf.x - shelf.w / 2, Math.min(x, shelf.x + shelf.w / 2));
    const hy = Math.max(shelf.y - shelf.h / 2, Math.min(y, shelf.y + shelf.h / 2));
    const dx = x - hx;
    const dy = y - hy;
    return dx * dx + dy * dy < r * r;
  }

  function resolveShelf(kart) {
    const r = 22;
    for (const s of track.shelves) {
      if (!rectHit(kart.x, kart.y, r, s)) continue;
      const hx = Math.max(s.x - s.w / 2, Math.min(kart.x, s.x + s.w / 2));
      const hy = Math.max(s.y - s.h / 2, Math.min(kart.y, s.y + s.h / 2));
      let dx = kart.x - hx;
      let dy = kart.y - hy;
      let d = Math.hypot(dx, dy) || 0.001;
      const push = (r - d) / d;
      kart.x += dx * push;
      kart.y += dy * push;
      const nx = dx / d;
      const ny = dy / d;
      const dot = kart.vx * nx + kart.vy * ny;
      if (dot < 0) {
        kart.vx -= nx * dot * 1.4;
        kart.vy -= ny * dot * 1.4;
      }
      kart.speed *= 0.55;
      if (kart.isPlayer) camera.shake = 6;
    }
  }

  function updatePathProgress(kart) {
    const info = nearestPathInfo(kart.x, kart.y);
    const prev = kart.pathIndex;
    kart.pathIndex = info.index;
    const a = pathPoint(info.index);
    const b = pathPoint(info.index + 1);
    const segLen = Math.hypot(b.x - a.x, b.y - a.y) || 1;
    const along =
      ((kart.x - a.x) * (b.x - a.x) + (kart.y - a.y) * (b.y - a.y)) / (segLen * segLen);
    kart.pathFrac = Math.max(0, Math.min(0.999, along));

    // Lap detection: crossing start forward
    if (prev > track.path.length * 0.8 && info.index < track.path.length * 0.15) {
      if (!kart.finished) {
        kart.lap += 1;
        if (kart.lap >= LAPS) {
          kart.finished = true;
          kart.finishTime = race.time;
          kart.speed *= 0.4;
        }
      }
    }
    return info;
  }

  function pickItem() {
    const keys = Object.keys(ITEM_ICONS);
    return keys[(Math.random() * keys.length) | 0];
  }

  function useItem(kart) {
    if (!kart.item || kart.stun > 0) return;
    const item = kart.item;
    kart.item = null;
    if (kart.isPlayer) itemSlot.textContent = "—";

    if (item === "soda") {
      kart.boost = Math.max(kart.boost, 1.4);
      for (let i = 0; i < 12; i++) {
        spawnParticle(
          kart.x,
          kart.y,
          "#ffba08",
          0.4 + Math.random() * 0.3,
          3 + Math.random() * 3,
          -Math.cos(kart.angle) * 80 + (Math.random() - 0.5) * 40,
          -Math.sin(kart.angle) * 80 + (Math.random() - 0.5) * 40
        );
      }
    } else if (item === "banana") {
      race.hazards.push({
        type: "banana",
        x: kart.x - Math.cos(kart.angle) * 40,
        y: kart.y - Math.sin(kart.angle) * 40,
        life: 18,
      });
    } else if (item === "soap") {
      race.hazards.push({
        type: "soap",
        x: kart.x - Math.cos(kart.angle) * 50,
        y: kart.y - Math.sin(kart.angle) * 50,
        life: 14,
        r: 48,
      });
    } else if (item === "can") {
      race.projectiles.push({
        x: kart.x + Math.cos(kart.angle) * 30,
        y: kart.y + Math.sin(kart.angle) * 30,
        vx: Math.cos(kart.angle) * 520,
        vy: Math.sin(kart.angle) * 520,
        owner: kart,
        life: 1.6,
      });
    }
  }

  function updateAI(kart, dt) {
    const target = pathPoint(kart.aiTarget);
    const desired = Math.atan2(target.y - kart.y, target.x - kart.x);
    let diff = desired - kart.angle;
    while (diff > Math.PI) diff -= Math.PI * 2;
    while (diff < -Math.PI) diff += Math.PI * 2;
    const turn = Math.max(-1, Math.min(1, diff * 2.2));
    const dist = Math.hypot(target.x - kart.x, target.y - kart.y);
    if (dist < 90) kart.aiTarget = (kart.aiTarget + 3) % track.path.length;

    // Rubber-band: speed up if behind player
    const player = race.karts.find((k) => k.isPlayer);
    const gap = progressOf(player) - progressOf(kart);
    let gas = 0.85 + kart.aiSkill * 0.2;
    if (gap > 8) gas = 1.05;
    if (gap < -12) gas = 0.7;
    if (Math.abs(diff) > 0.9) gas *= 0.65;

    if (kart.item && Math.random() < dt * 0.35) {
      // Use item if someone is near ahead/behind
      useItem(kart);
    }

    return { turn, gas, brake: Math.abs(diff) > 1.3 && kart.speed > 120 };
  }

  function updateKart(kart, dt) {
    if (kart.finished) {
      kart.speed *= 1 - 2 * dt;
      kart.x += Math.cos(kart.angle) * kart.speed * dt;
      kart.y += Math.sin(kart.angle) * kart.speed * dt;
      return;
    }

    kart.stun = Math.max(0, kart.stun - dt);
    kart.boost = Math.max(0, kart.boost - dt);
    kart.slip = Math.max(0, kart.slip - dt);
    kart.invuln = Math.max(0, kart.invuln - dt);

    let turn = 0;
    let gas = false;
    let brake = false;

    if (kart.stun > 0) {
      kart.angle += dt * 8;
      kart.speed *= 1 - 1.5 * dt;
    } else {
      if (kart.isPlayer) {
        turn = (input.right ? 1 : 0) - (input.left ? 1 : 0);
        gas = input.gas;
        brake = input.brake;
        if (input.item) {
          useItem(kart);
          input.item = false;
        }
      } else {
        const ai = updateAI(kart, dt);
        turn = ai.turn;
        gas = ai.gas > 0.5;
        brake = ai.brake;
        // Soft AI throttle
        if (!gas) kart.speed *= 1 - 0.3 * dt;
      }

      const steer =
        turn * kart.turn * (0.35 + 0.65 * Math.min(1, kart.speed / 160)) * (kart.slip > 0 ? 1.8 : 1);
      kart.angle += steer * dt;

      const top = kart.topSpeed * (kart.boost > 0 ? 1.35 : 1) * (kart.slip > 0 ? 0.7 : 1);
      if (gas) kart.speed += kart.accel * dt * (kart.boost > 0 ? 1.4 : 1);
      if (brake) kart.speed -= (kart.accel * 1.4 + kart.speed * 1.2) * dt;
      if (!gas && !brake) kart.speed -= 70 * dt;

      // Off-track friction (into shelves / linoleum edge)
      const info = nearestPathInfo(kart.x, kart.y);
      if (!info.onTrack) {
        kart.speed *= 1 - 1.8 * dt;
        top && (kart.speed = Math.min(kart.speed, top * 0.55));
        if (kart.isPlayer && Math.random() < dt * 8) {
          spawnParticle(kart.x, kart.y, "#b89b6a", 0.35, 2, (Math.random() - 0.5) * 30, (Math.random() - 0.5) * 30);
        }
      }

      kart.speed = Math.max(-90, Math.min(top, kart.speed));

      // Drift feel
      const targetVx = Math.cos(kart.angle) * kart.speed;
      const targetVy = Math.sin(kart.angle) * kart.speed;
      const grip = kart.grip * (kart.slip > 0 ? 0.25 : 1) * (Math.abs(turn) > 0.5 && kart.speed > 180 ? 0.7 : 1);
      kart.vx += (targetVx - kart.vx) * Math.min(1, grip * 4 * dt);
      kart.vy += (targetVy - kart.vy) * Math.min(1, grip * 4 * dt);

      if (Math.abs(turn) > 0.4 && kart.speed > 170 && kart.isPlayer) {
        spawnParticle(
          kart.x - Math.cos(kart.angle) * 16,
          kart.y - Math.sin(kart.angle) * 16,
          "#ffba08",
          0.25,
          2,
          -kart.vx * 0.1,
          -kart.vy * 0.1
        );
      }
    }

    kart.x += kart.vx * dt;
    kart.y += kart.vy * dt;

    // Soft world clamp
    const b = track.bounds;
    kart.x = Math.max(b.minX, Math.min(b.maxX, kart.x));
    kart.y = Math.max(b.minY, Math.min(b.maxY, kart.y));

    resolveShelf(kart);
    updatePathProgress(kart);

    // Boost pads
    for (const pad of track.boostPads) {
      if (Math.hypot(kart.x - pad.x, kart.y - pad.y) < pad.r) {
        kart.boost = Math.max(kart.boost, 0.85);
        if (kart.isPlayer) camera.shake = 3;
      }
    }

    // Item boxes
    for (const box of track.itemBoxes) {
      if (box.taken > 0) continue;
      if (Math.hypot(kart.x - box.x, kart.y - box.y) < 34 && !kart.item) {
        kart.item = pickItem();
        box.taken = 4.5;
        if (kart.isPlayer) itemSlot.textContent = ITEM_ICONS[kart.item];
        for (let i = 0; i < 10; i++) {
          spawnParticle(box.x, box.y, "#ffe08a", 0.5, 3, (Math.random() - 0.5) * 120, (Math.random() - 0.5) * 120);
        }
      }
    }

    // Hazards
    for (let i = race.hazards.length - 1; i >= 0; i--) {
      const h = race.hazards[i];
      const rad = h.type === "soap" ? h.r : 22;
      if (kart.invuln > 0) continue;
      if (Math.hypot(kart.x - h.x, kart.y - h.y) < rad + 16) {
        if (h.type === "banana") {
          kart.stun = 1.1;
          kart.invuln = 1.4;
          race.hazards.splice(i, 1);
          if (kart.isPlayer) camera.shake = 10;
        } else if (h.type === "soap") {
          kart.slip = Math.max(kart.slip, 1.5);
        }
      }
    }
  }

  function kartCollision() {
    const list = race.karts;
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const d = Math.hypot(dx, dy);
        if (d >= 40 || d < 0.01) continue;
        const nx = dx / d;
        const ny = dy / d;
        const overlap = 40 - d;
        a.x -= nx * overlap * 0.5;
        a.y -= ny * overlap * 0.5;
        b.x += nx * overlap * 0.5;
        b.y += ny * overlap * 0.5;
        const dvx = a.vx - b.vx;
        const dvy = a.vy - b.vy;
        const impact = dvx * nx + dvy * ny;
        if (impact > 0) {
          a.vx -= nx * impact * 0.7;
          a.vy -= ny * impact * 0.7;
          b.vx += nx * impact * 0.7;
          b.vy += ny * impact * 0.7;
          a.speed *= 0.92;
          b.speed *= 0.92;
        }
      }
    }
  }

  function updateProjectiles(dt) {
    for (let i = race.projectiles.length - 1; i >= 0; i--) {
      const p = race.projectiles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      let hit = false;
      for (const s of track.shelves) {
        if (rectHit(p.x, p.y, 8, s)) {
          hit = true;
          break;
        }
      }
      for (const k of race.karts) {
        if (k === p.owner || k.invuln > 0 || k.finished) continue;
        if (Math.hypot(k.x - p.x, k.y - p.y) < 28) {
          k.stun = 0.9;
          k.invuln = 1.2;
          k.speed *= 0.4;
          hit = true;
          if (k.isPlayer) camera.shake = 8;
          break;
        }
      }
      if (hit || p.life <= 0) {
        for (let n = 0; n < 8; n++) {
          spawnParticle(p.x, p.y, "#d94a3d", 0.4, 3, (Math.random() - 0.5) * 140, (Math.random() - 0.5) * 140);
        }
        race.projectiles.splice(i, 1);
      }
    }
  }

  function rankedKarts() {
    return [...race.karts].sort((a, b) => {
      if (a.finished && b.finished) return a.finishTime - b.finishTime;
      if (a.finished) return -1;
      if (b.finished) return 1;
      return progressOf(b) - progressOf(a);
    });
  }

  function endRaceIfNeeded() {
    const player = race.karts.find((k) => k.isPlayer);
    if (!player.finished) return;
    // Wait briefly then show results, or when all finished / timeout
    const allDone = race.karts.every((k) => k.finished);
    if (allDone || race.time - player.finishTime > 4) {
      race.over = true;
      state = "results";
      const order = rankedKarts();
      const place = order.findIndex((k) => k.isPlayer) + 1;
      resultsTitle.textContent =
        place === 1 ? "Aisle Champion!" : place === 2 ? "Silver Cart!" : place === 3 ? "Bronze Basket!" : "Back to the lot";
      resultsList.innerHTML = "";
      order.forEach((k, i) => {
        const li = document.createElement("li");
        if (k.isPlayer) li.className = "you";
        li.innerHTML = `<span>${i + 1}. ${k.isPlayer ? k.name + " (You)" : k.name}</span><span>Lap ${Math.min(k.lap + (k.finished ? 0 : 1), LAPS)}</span>`;
        resultsList.appendChild(li);
      });
      hide(hud);
      hide(controls);
      show(resultsScreen);
    }
  }

  function update(dt) {
    if (!race || state !== "race") return;

    race.time += dt;

    if (race.countdown > 0) {
      race.countdown -= dt;
      const n = Math.ceil(race.countdown);
      if (race.countdown > 0) {
        countdownEl.textContent = n > 0 ? String(n) : "GO!";
        countdownEl.classList.add("show");
      }
      if (race.countdown <= 0) {
        race.go = true;
        input.gas = true; // arcade auto-accelerate; brake to scrub speed
        countdownEl.textContent = "GO!";
        setTimeout(() => countdownEl.classList.remove("show"), 500);
      }
      // Still allow slight camera settle
    }

    if (race.go && !race.over) {
      for (const kart of race.karts) updateKart(kart, dt);
      kartCollision();
      updateProjectiles(dt);

      for (const box of track.itemBoxes) {
        if (box.taken > 0) box.taken -= dt;
      }
      for (let i = race.hazards.length - 1; i >= 0; i--) {
        race.hazards[i].life -= dt;
        if (race.hazards[i].life <= 0) race.hazards.splice(i, 1);
      }
      endRaceIfNeeded();
    }

    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.life <= 0) particles.splice(i, 1);
    }

    const player = race.karts.find((k) => k.isPlayer);
    camera.x += (player.x - camera.x) * Math.min(1, 6 * dt);
    camera.y += (player.y - camera.y) * Math.min(1, 6 * dt);
    camera.shake *= 1 - 8 * dt;

    const order = rankedKarts();
    const place = order.findIndex((k) => k.isPlayer) + 1;
    posLabel.textContent = String(place);
    lapLabel.textContent = String(Math.min(player.lap + 1, LAPS));
    speedLabel.textContent = String(Math.max(0, Math.round(player.speed * 0.28)));
  }

  // --- Drawing ---
  function ensureFloor() {
    if (floorPattern) return floorPattern;
    const c = document.createElement("canvas");
    c.width = 64;
    c.height = 64;
    const g = c.getContext("2d");
    g.fillStyle = "#d6c7a4";
    g.fillRect(0, 0, 64, 64);
    g.fillStyle = "#cbb890";
    for (let y = 0; y < 64; y += 16) {
      for (let x = 0; x < 64; x += 16) {
        if (((x + y) / 16) % 2 === 0) g.fillRect(x, y, 16, 16);
      }
    }
    g.strokeStyle = "rgba(120, 100, 70, 0.15)";
    g.strokeRect(0.5, 0.5, 63, 63);
    floorPattern = ctx.createPattern(c, "repeat");
    return floorPattern;
  }

  function worldToScreen(x, y) {
    const zoom = Math.min(W, H) / 520;
    const sx = W / 2 + (x - camera.x) * zoom + (Math.random() - 0.5) * camera.shake;
    const sy = H / 2 + (y - camera.y) * zoom + (Math.random() - 0.5) * camera.shake;
    return { x: sx, y: sy, zoom };
  }

  function drawTrack() {
    const pat = ensureFloor();
    // Big floor
    const z = Math.min(W, H) / 520;
    ctx.save();
    ctx.translate(W / 2, H / 2);
    ctx.scale(z, z);
    ctx.translate(-camera.x + (Math.random() - 0.5) * camera.shake, -camera.y + (Math.random() - 0.5) * camera.shake);

    // Store background
    ctx.fillStyle = "#2a3138";
    ctx.fillRect(-1400, -1000, 2800, 2000);

    // Linoleum race floor under path
    ctx.fillStyle = pat || "#d6c7a4";
    ctx.beginPath();
    for (let i = 0; i < track.path.length; i++) {
      const p = track.path[i];
      const prev = track.path[(i - 1 + track.path.length) % track.path.length];
      const next = track.path[(i + 1) % track.path.length];
      const ang = Math.atan2(next.y - prev.y, next.x - prev.x);
      const nx = Math.cos(ang + Math.PI / 2) * track.width;
      const ny = Math.sin(ang + Math.PI / 2) * track.width;
      if (i === 0) ctx.moveTo(p.x + nx, p.y + ny);
      else ctx.lineTo(p.x + nx, p.y + ny);
    }
    for (let i = track.path.length - 1; i >= 0; i--) {
      const p = track.path[i];
      const prev = track.path[(i - 1 + track.path.length) % track.path.length];
      const next = track.path[(i + 1) % track.path.length];
      const ang = Math.atan2(next.y - prev.y, next.x - prev.x);
      const nx = Math.cos(ang + Math.PI / 2) * track.width;
      const ny = Math.sin(ang + Math.PI / 2) * track.width;
      ctx.lineTo(p.x - nx, p.y - ny);
    }
    ctx.closePath();
    ctx.fill();

    // Lane dashed line
    ctx.strokeStyle = "rgba(255,255,255,0.35)";
    ctx.lineWidth = 3;
    ctx.setLineDash([18, 16]);
    ctx.beginPath();
    track.path.forEach((p, i) => {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.closePath();
    ctx.stroke();
    ctx.setLineDash([]);

    // Start / finish
    const s0 = pathPoint(0);
    const s1 = pathPoint(1);
    const sang = Math.atan2(s1.y - s0.y, s1.x - s0.x);
    ctx.save();
    ctx.translate(s0.x, s0.y);
    ctx.rotate(sang);
    for (let i = -5; i < 5; i++) {
      for (let j = 0; j < 2; j++) {
        ctx.fillStyle = (i + j) % 2 === 0 ? "#111" : "#f7f1e3";
        ctx.fillRect(j * 16 - 8, i * 18, 16, 18);
      }
    }
    ctx.restore();

    // Shelves
    for (const s of track.shelves) {
      drawShelf(s);
    }

    // Boost pads
    for (const pad of track.boostPads) {
      const pulse = 0.7 + Math.sin(performance.now() / 180 + pad.x) * 0.3;
      ctx.beginPath();
      ctx.fillStyle = `rgba(255, 186, 8, ${0.35 * pulse})`;
      ctx.arc(pad.x, pad.y, pad.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#ffba08";
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = "#ffe08a";
      ctx.font = "bold 22px Space Grotesk, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(">>", pad.x, pad.y);
    }

    // Item boxes
    for (const box of track.itemBoxes) {
      if (box.taken > 0) {
        ctx.globalAlpha = 0.25;
      }
      const bob = Math.sin(performance.now() / 200 + box.x) * 4;
      ctx.fillStyle = "#1f3d2c";
      ctx.strokeStyle = "#ffba08";
      ctx.lineWidth = 3;
      roundRect(ctx, box.x - 18, box.y - 18 + bob, 36, 36, 8);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#ffba08";
      ctx.font = "bold 20px Lilita One, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("?", box.x, box.y + bob + 1);
      ctx.globalAlpha = 1;
    }

    // Hazards
    for (const h of race.hazards) {
      if (h.type === "banana") {
        ctx.font = "28px serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText("🍌", h.x, h.y);
      } else if (h.type === "soap") {
        ctx.beginPath();
        ctx.fillStyle = "rgba(120, 200, 255, 0.35)";
        ctx.arc(h.x, h.y, h.r, 0, Math.PI * 2);
        ctx.fill();
        ctx.font = "22px serif";
        ctx.textAlign = "center";
        ctx.fillText("🧼", h.x, h.y);
      }
    }

    // Projectiles
    for (const p of race.projectiles) {
      ctx.font = "22px serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("🥫", p.x, p.y);
    }

    // Particles
    for (const p of particles) {
      ctx.globalAlpha = Math.max(0, p.life / p.max);
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    // Karts (draw back-to-front by y)
    const sorted = [...race.karts].sort((a, b) => a.y - b.y);
    for (const k of sorted) drawCart(k);

    // Fluorescent light streaks
    ctx.globalAlpha = 0.06;
    ctx.fillStyle = "#fff6c8";
    for (let i = -3; i <= 3; i++) {
      ctx.fillRect(i * 280 - 40, -800, 80, 1600);
    }
    ctx.globalAlpha = 1;

    ctx.restore();
  }

  function roundRect(c, x, y, w, h, r) {
    c.beginPath();
    c.moveTo(x + r, y);
    c.arcTo(x + w, y, x + w, y + h, r);
    c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r);
    c.arcTo(x, y, x + w, y, r);
    c.closePath();
  }

  function drawShelf(s) {
    const colors = {
      shelf: ["#2f6f4e", "#245a3f"],
      freezer: ["#4d6d82", "#314858"],
      produce: ["#6a8f3d", "#456328"],
      checkout: ["#8a6a3d", "#5c4526"],
    };
    const [main, dark] = colors[s.type] || colors.shelf;
    ctx.fillStyle = dark;
    ctx.fillRect(s.x - s.w / 2 + 4, s.y - s.h / 2 + 6, s.w, s.h);
    ctx.fillStyle = main;
    ctx.fillRect(s.x - s.w / 2, s.y - s.h / 2, s.w, s.h);
    // Shelf lips / product hints
    ctx.fillStyle = "rgba(255,255,255,0.08)";
    for (let y = s.y - s.h / 2 + 12; y < s.y + s.h / 2 - 8; y += 28) {
      ctx.fillRect(s.x - s.w / 2 + 4, y, s.w - 8, 4);
    }
    if (s.type === "freezer") {
      ctx.fillStyle = "rgba(180, 220, 255, 0.2)";
      ctx.fillRect(s.x - s.w / 2 + 6, s.y - s.h / 2 + 6, s.w - 12, s.h - 12);
    }
  }

  function drawCart(kart) {
    ctx.save();
    ctx.translate(kart.x, kart.y);
    ctx.rotate(kart.angle);
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(4, 8, 22, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    // Basket
    ctx.fillStyle = kart.accent;
    ctx.fillRect(-18, -14, 36, 28);
    ctx.fillStyle = kart.color;
    ctx.fillRect(-16, -12, 32, 24);
    // Wire lines
    ctx.strokeStyle = "rgba(255,255,255,0.25)";
    ctx.lineWidth = 1.5;
    for (let i = -10; i <= 10; i += 5) {
      ctx.beginPath();
      ctx.moveTo(i, -11);
      ctx.lineTo(i, 11);
      ctx.stroke();
    }
    // Handle
    ctx.strokeStyle = "#d9dee3";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-20, -10);
    ctx.lineTo(-28, -16);
    ctx.lineTo(-28, 16);
    ctx.lineTo(-20, 10);
    ctx.stroke();
    // Wheels
    ctx.fillStyle = "#222";
    ctx.beginPath();
    ctx.arc(-12, 16, 5, 0, Math.PI * 2);
    ctx.arc(12, 16, 5, 0, Math.PI * 2);
    ctx.arc(-12, -16, 4, 0, Math.PI * 2);
    ctx.arc(12, -16, 4, 0, Math.PI * 2);
    ctx.fill();

    // Player marker
    if (kart.isPlayer) {
      ctx.fillStyle = "#ffba08";
      ctx.beginPath();
      ctx.moveTo(0, -28);
      ctx.lineTo(6, -20);
      ctx.lineTo(-6, -20);
      ctx.closePath();
      ctx.fill();
    }

    // Boost flame
    if (kart.boost > 0) {
      ctx.fillStyle = `rgba(255, ${150 + Math.random() * 80 | 0}, 40, 0.9)`;
      ctx.beginPath();
      ctx.moveTo(-18, -8);
      ctx.lineTo(-34 - Math.random() * 10, 0);
      ctx.lineTo(-18, 8);
      ctx.closePath();
      ctx.fill();
    }

    ctx.restore();

    // Name plate
    ctx.save();
    ctx.translate(kart.x, kart.y - 36);
    ctx.fillStyle = "rgba(18,22,28,0.7)";
    const label = kart.isPlayer ? "YOU" : kart.name;
    ctx.font = "bold 11px Space Grotesk, sans-serif";
    const tw = ctx.measureText(label).width;
    roundRect(ctx, -tw / 2 - 6, -10, tw + 12, 16, 6);
    ctx.fill();
    ctx.fillStyle = kart.isPlayer ? "#ffba08" : "#f7f1e3";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(label, 0, -1);
    ctx.restore();
  }

  function drawMinimap() {
    const mw = 110;
    const mh = 80;
    const x0 = W - mw - 14;
    const y0 = 14 + (parseInt(getComputedStyle(document.documentElement).getPropertyValue("--safe-top")) || 0);
    ctx.save();
    ctx.globalAlpha = 0.85;
    ctx.fillStyle = "rgba(18,22,28,0.75)";
    roundRect(ctx, x0, y0 + 52, mw, mh, 12);
    ctx.fill();
    ctx.beginPath();
    ctx.strokeStyle = "rgba(255,186,8,0.5)";
    ctx.lineWidth = 2;
    const sx = (x) => x0 + mw / 2 + x * 0.055;
    const sy = (y) => y0 + 52 + mh / 2 + y * 0.055;
    track.path.forEach((p, i) => {
      if (i === 0) ctx.moveTo(sx(p.x), sy(p.y));
      else ctx.lineTo(sx(p.x), sy(p.y));
    });
    ctx.closePath();
    ctx.stroke();
    for (const k of race.karts) {
      ctx.fillStyle = k.isPlayer ? "#ffba08" : k.color;
      ctx.beginPath();
      ctx.arc(sx(k.x), sy(k.y), k.isPlayer ? 3.5 : 2.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawAmbientTitle() {
    // Soft motion behind menus
    ctx.clearRect(0, 0, W, H);
    const t = performance.now() / 1000;
    ctx.fillStyle = "#1c232b";
    ctx.fillRect(0, 0, W, H);
    for (let i = 0; i < 18; i++) {
      const x = ((i * 97 + t * 30) % (W + 80)) - 40;
      const y = (Math.sin(t * 0.7 + i) * 0.35 + 0.55) * H;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(t * 0.4 + i);
      ctx.fillStyle = `hsla(${25 + i * 8}, 80%, 55%, 0.12)`;
      ctx.fillRect(-16, -12, 32, 24);
      ctx.restore();
    }
  }

  function draw() {
    if (state !== "race" || !race) {
      drawAmbientTitle();
      return;
    }
    ctx.clearRect(0, 0, W, H);
    // Ceiling glow
    const g = ctx.createRadialGradient(W / 2, 0, 10, W / 2, H * 0.2, H);
    g.addColorStop(0, "#3a4550");
    g.addColorStop(1, "#12161c");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    drawTrack();
    drawMinimap();
  }

  function frame(ts) {
    if (!lastTime) lastTime = ts;
    let dt = (ts - lastTime) / 1000;
    lastTime = ts;
    dt = Math.min(0.033, dt);
    update(dt);
    draw();
    requestAnimationFrame(frame);
  }

  // --- Input ---
  function bindHold(btn, key) {
    const set = (v) => {
      input[key] = v;
      btn.classList.toggle("active", v);
    };
    btn.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      btn.setPointerCapture(e.pointerId);
      set(true);
    });
    ["pointerup", "pointercancel", "pointerleave"].forEach((ev) =>
      btn.addEventListener(ev, () => set(false))
    );
  }

  bindHold(document.getElementById("leftBtn"), "left");
  bindHold(document.getElementById("rightBtn"), "right");
  bindHold(document.getElementById("gasBtn"), "gas");
  bindHold(document.getElementById("brakeBtn"), "brake");
  document.getElementById("itemBtn").addEventListener("pointerdown", (e) => {
    e.preventDefault();
    input.item = true;
  });

  // Steer by dragging on canvas
  let dragX = null;
  canvas.addEventListener("pointerdown", (e) => {
    if (state !== "race") return;
    dragX = e.clientX;
    if (!input.gas && e.clientY < H * 0.7) input.gas = true;
  });
  canvas.addEventListener("pointermove", (e) => {
    if (dragX == null || state !== "race") return;
    const dx = e.clientX - dragX;
    input.left = dx < -18;
    input.right = dx > 18;
  });
  canvas.addEventListener("pointerup", () => {
    dragX = null;
    // don't force gas off — pedals handle it; release steer
    input.left = false;
    input.right = false;
  });

  window.addEventListener("keydown", (e) => {
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " "].includes(e.key)) e.preventDefault();
    if (e.key === "ArrowLeft" || e.key === "a" || e.key === "A") input.left = true;
    if (e.key === "ArrowRight" || e.key === "d" || e.key === "D") input.right = true;
    if (e.key === "ArrowUp" || e.key === "w" || e.key === "W" || e.key === " ") input.gas = true;
    if (e.key === "ArrowDown" || e.key === "s" || e.key === "S") input.brake = true;
    if (e.key === "e" || e.key === "E" || e.key === "Shift") input.item = true;
  });
  window.addEventListener("keyup", (e) => {
    if (e.key === "ArrowLeft" || e.key === "a" || e.key === "A") input.left = false;
    if (e.key === "ArrowRight" || e.key === "d" || e.key === "D") input.right = false;
    if (e.key === "ArrowUp" || e.key === "w" || e.key === "W" || e.key === " ") input.gas = false;
    if (e.key === "ArrowDown" || e.key === "s" || e.key === "S") input.brake = false;
  });

  document.getElementById("playBtn").addEventListener("click", () => {
    hide(titleScreen);
    show(selectScreen);
    renderCartSelect();
  });
  document.getElementById("backBtn").addEventListener("click", () => {
    hide(selectScreen);
    show(titleScreen);
  });
  document.getElementById("raceBtn").addEventListener("click", startRace);
  document.getElementById("retryBtn").addEventListener("click", startRace);
  document.getElementById("menuBtn").addEventListener("click", () => {
    state = "title";
    race = null;
    hide(resultsScreen);
    hide(hud);
    hide(controls);
    show(titleScreen);
  });

  window.addEventListener("resize", resize);
  resize();
  renderCartSelect();
  // Auto-gas default on mobile feel: hold gas button
  requestAnimationFrame(frame);
})();
