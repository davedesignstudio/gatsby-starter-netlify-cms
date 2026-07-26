(() => {
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");

  const COLORS = {
    floor: "#dde2d6",
    tile: "#c7cec0",
    shelf: "#9e6238",
    shelfFace: "#b87345",
    produce: "#478e52",
    frozen: "#598cb8",
    yellow: "#ebc738",
    orange: "#eb732e",
    ink: "#1a201c",
    carts: ["#d9382e", "#2e73c7", "#349e60", "#c78c26"],
    names: ["Rusty", "Blue Basket", "Green Grocer", "Goldie"],
  };

  const WORLD = { w: 2200, h: 1600 };
  const TOTAL_LAPS = 3;

  const PATH = [
    [300, 280], [700, 220], [1100, 220], [1500, 220], [1900, 280],
    [1980, 500], [1980, 800], [1980, 1100], [1900, 1350],
    [1500, 1420], [1100, 1420], [700, 1420], [300, 1350],
    [220, 1100], [220, 800], [220, 500], [300, 280],
  ];

  const SHELVES = [
    { x: 0, y: 0, w: WORLD.w, h: 40, c: COLORS.shelf },
    { x: 0, y: WORLD.h - 40, w: WORLD.w, h: 40, c: COLORS.shelf },
    { x: 0, y: 0, w: 40, h: WORLD.h, c: COLORS.shelf },
    { x: WORLD.w - 40, y: 0, w: 40, h: WORLD.h, c: COLORS.shelf },
    { x: 520, y: 420, w: 1160, h: 160, c: COLORS.shelfFace, label: "CEREAL" },
    { x: 520, y: 1020, w: 1160, h: 160, c: COLORS.produce, label: "PRODUCE" },
    { x: 520, y: 620, w: 180, h: 360, c: COLORS.frozen, label: "FROZEN" },
    { x: 1500, y: 620, w: 180, h: 360, c: COLORS.shelfFace, label: "SNACKS" },
    { x: 900, y: 720, w: 120, h: 120, c: COLORS.orange, label: "SALE" },
    { x: 1180, y: 720, w: 120, h: 120, c: COLORS.yellow, label: "DEAL" },
    { x: 180, y: 180, w: 140, h: 100, c: COLORS.produce, label: "FRUIT" },
    { x: 1880, y: 180, w: 140, h: 100, c: COLORS.frozen, label: "ICE" },
    { x: 180, y: 1320, w: 140, h: 100, c: COLORS.shelfFace, label: "SOAP" },
    { x: 1880, y: 1320, w: 140, h: 100, c: COLORS.orange, label: "TOYS" },
  ];

  const ITEM_SPAWNS = [
    [900, 300], [1600, 300], [1900, 800], [1600, 1300],
    [900, 1300], [320, 800], [1100, 560], [1100, 980],
  ];

  const STARTS = [
    [280, 360], [340, 420], [280, 480], [340, 540],
  ];

  const ITEMS = ["banana", "soda", "shield", "boost", "turkey"];
  const ITEM_EMOJI = { banana: "🍌", soda: "🥫", shield: "🛡️", boost: "⚡", turkey: "🦃" };
  const ITEM_LABEL = { banana: "BANANA", soda: "SODA SPRAY", shield: "SHIELD", boost: "EXPRESS", turkey: "TURKEY" };

  function randItem() {
    const r = Math.random();
    if (r < 0.28) return "banana";
    if (r < 0.5) return "soda";
    if (r < 0.68) return "boost";
    if (r < 0.84) return "shield";
    return "turkey";
  }

  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
  function hypot(x, y) { return Math.sqrt(x * x + y * y); }
  function ordinal(n) { return n === 1 ? "1st" : n === 2 ? "2nd" : n === 3 ? "3rd" : `${n}th`; }

  let W = 0, H = 0, dpr = 1;
  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth;
    H = window.innerHeight;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    canvas.style.width = W + "px";
    canvas.style.height = H + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  window.addEventListener("resize", resize);
  resize();

  // ---------- State ----------
  let mode = "menu"; // menu | race | results
  let carts = [];
  let boxes = [];
  let hazards = [];
  let projectiles = [];
  let cam = { x: WORLD.w / 2, y: WORLD.h / 2 };
  let raceStarted = false;
  let raceOver = false;
  let finishCount = 0;
  let boostCharge = 0.4;
  let leftDown = false, rightDown = false;
  let keys = {};
  let lastT = 0;
  let msgTimer = 0;
  let msgText = "";
  let playerPlace = 1;

  function showMsg(text, dur = 1) {
    msgText = text;
    msgTimer = dur;
    const el = document.getElementById("msg");
    el.textContent = text;
    el.classList.add("show");
    clearTimeout(showMsg._t);
    showMsg._t = setTimeout(() => el.classList.remove("show"), dur * 1000);
  }

  function makeCart(i, isPlayer) {
    return {
      i, isPlayer,
      x: STARTS[i][0], y: STARTS[i][1],
      rot: Math.PI / 2,
      speed: 0,
      maxSpeed: 280 * (isPlayer ? 1 : 0.88 + Math.random() * 0.14),
      accel: 220 * (isPlayer ? 1 : 0.9 + Math.random() * 0.15),
      turn: 2.8,
      steer: 0,
      throttle: false,
      lap: 0,
      nextCp: 0,
      progress: 0,
      finished: false,
      place: null,
      item: null,
      shield: false,
      boostT: 0,
      spinT: 0,
      slowT: 0,
      invuln: 0,
      wp: 0,
      itemCd: 1.5 + Math.random(),
      aggression: 0.75 + Math.random() * 0.4,
    };
  }

  function resetRace() {
    carts = [0, 1, 2, 3].map((i) => makeCart(i, i === 0));
    boxes = ITEM_SPAWNS.map(([x, y]) => ({ x, y, available: true, respawn: 0 }));
    hazards = [];
    projectiles = [];
    cam = { x: carts[0].x, y: carts[0].y };
    raceStarted = false;
    raceOver = false;
    finishCount = 0;
    boostCharge = 0.4;
    leftDown = rightDown = false;
    mode = "race";

    document.getElementById("menu").classList.add("hidden");
    document.getElementById("results").classList.add("hidden");
    document.getElementById("howto").classList.add("hidden");
    document.getElementById("hud").classList.remove("hidden");

    showMsg("READY?", 0.8);
    setTimeout(() => showMsg("3"), 900);
    setTimeout(() => showMsg("2"), 1600);
    setTimeout(() => showMsg("1"), 2300);
    setTimeout(() => {
      showMsg("GO!", 0.6);
      raceStarted = true;
      carts.forEach((c) => { c.throttle = true; });
    }, 3000);
  }

  function player() { return carts[0]; }

  function updateCart(c, dt) {
    c.invuln = Math.max(0, c.invuln - dt);
    c.boostT = Math.max(0, c.boostT - dt);
    c.spinT = Math.max(0, c.spinT - dt);
    c.slowT = Math.max(0, c.slowT - dt);

    if (c.spinT > 0) {
      c.rot += dt * 10;
      c.speed *= 0.92;
      return;
    }

    let maxSp = c.maxSpeed;
    if (c.boostT > 0) maxSp *= 1.45;
    if (c.slowT > 0) maxSp *= 0.55;

    if (c.throttle) c.speed = Math.min(maxSp, c.speed + c.accel * dt);
    else c.speed = Math.max(0, c.speed - c.accel * 1.4 * dt);

    if (Math.abs(c.steer) > 0.05) {
      const turnScale = 0.35 + 0.65 * Math.min(1, c.speed / Math.max(1, c.maxSpeed * 0.5));
      c.rot += c.steer * c.turn * turnScale * dt;
    }

    let nx = c.x + Math.sin(c.rot) * c.speed * dt;
    let ny = c.y + Math.cos(c.rot) * c.speed * dt;

    // Wall collisions (AABB vs cart circle)
    const r = 20;
    for (const s of SHELVES) {
      const nearestX = clamp(nx, s.x, s.x + s.w);
      const nearestY = clamp(ny, s.y, s.y + s.h);
      const dx = nx - nearestX;
      const dy = ny - nearestY;
      const d = hypot(dx, dy);
      if (d < r && d > 0.001) {
        const push = (r - d) / d;
        nx += dx * push;
        ny += dy * push;
        c.speed *= 0.7;
      } else if (d < r) {
        // center inside — push out by shortest axis
        const left = nx - s.x, right = s.x + s.w - nx;
        const bottom = ny - s.y, top = s.y + s.h - ny;
        const m = Math.min(left, right, bottom, top);
        if (m === left) nx = s.x - r;
        else if (m === right) nx = s.x + s.w + r;
        else if (m === bottom) ny = s.y - r;
        else ny = s.y + s.h + r;
        c.speed *= 0.5;
      }
    }

    c.x = nx;
    c.y = ny;
  }

  function updateProgress(c) {
    const cp = PATH[c.nextCp % PATH.length];
    const d = hypot(c.x - cp[0], c.y - cp[1]);
    if (d < 90) {
      const prev = c.nextCp;
      c.nextCp = (c.nextCp + 1) % PATH.length;
      if (prev === PATH.length - 1) {
        c.lap += 1;
        if (c.isPlayer) showMsg(`LAP ${Math.min(c.lap, TOTAL_LAPS)}`, 0.8);
        if (c.lap >= TOTAL_LAPS) finishCart(c);
      }
    }
    const base = c.lap * PATH.length + c.nextCp;
    const next = PATH[c.nextCp % PATH.length];
    const dn = hypot(c.x - next[0], c.y - next[1]);
    c.progress = base + Math.max(0, 1 - dn / 400);
  }

  function finishCart(c) {
    if (c.finished) return;
    c.finished = true;
    finishCount += 1;
    c.place = finishCount;
    c.throttle = false;
    c.speed = 0;
    if (c.isPlayer) {
      raceOver = true;
      setTimeout(() => showResults(c.place), 600);
    }
  }

  function showResults(place) {
    mode = "results";
    document.getElementById("hud").classList.add("hidden");
    document.getElementById("results").classList.remove("hidden");
    document.getElementById("result-title").textContent =
      place === 1 ? "CHECKOUT CHAMP!" : ordinal(place).toUpperCase() + " PLACE";
    document.getElementById("result-sub").textContent =
      place === 1 ? "The aisles are yours." : "Wheel back for another run.";
  }

  function placeOf(c) {
    if (c.place) return c.place;
    const ordered = [...carts].sort((a, b) => {
      if (a.finished !== b.finished) return a.finished ? -1 : 1;
      return b.progress - a.progress;
    });
    return ordered.indexOf(c) + 1;
  }

  function updateAI(c, dt) {
    if (c.finished || c.spinT > 0) return;
    const target = PATH[c.wp % PATH.length];
    const dx = target[0] - c.x;
    const dy = target[1] - c.y;
    const dist = hypot(dx, dy);
    if (dist < 100) c.wp = (c.wp + 1) % PATH.length;

    let desired = Math.atan2(dx, dy);
    let diff = desired - c.rot;
    while (diff > Math.PI) diff -= Math.PI * 2;
    while (diff < -Math.PI) diff += Math.PI * 2;
    c.steer = clamp(diff * 1.8, -1, 1) * c.aggression;
    c.throttle = Math.abs(diff) < 1.2;

    c.itemCd -= dt;
    if (c.itemCd <= 0 && c.item) {
      const use = Math.random() < 0.4;
      if (use) {
        useItem(c);
        c.itemCd = 2.5 + Math.random() * 2.5;
      } else {
        c.itemCd = 0.4;
      }
    }
  }

  function cartAhead(c) {
    return carts
      .filter((o) => o !== c && !o.finished && o.progress >= c.progress - 0.2)
      .sort((a, b) => a.progress - b.progress)[0];
  }

  function useItem(c) {
    if (!c.item || !raceStarted || c.finished) return;
    const item = c.item;
    c.item = null;

    if (item === "banana") {
      hazards.push({
        type: "banana",
        x: c.x - Math.sin(c.rot) * 50,
        y: c.y - Math.cos(c.rot) * 50,
        owner: c.i,
        life: 12,
      });
    } else if (item === "soda") {
      const t = cartAhead(c);
      if (t) {
        hitSlow(t);
        if (c.isPlayer) showMsg("SODA SPRAY!", 0.5);
      }
    } else if (item === "shield") {
      c.shield = true;
      if (c.isPlayer) showMsg("SHIELDED", 0.5);
    } else if (item === "boost") {
      c.boostT = 1.4;
      c.speed = Math.max(c.speed, c.maxSpeed * 1.1);
      if (c.isPlayer) showMsg("BOOST!", 0.45);
    } else if (item === "turkey") {
      const t = cartAhead(c);
      projectiles.push({
        x: c.x + Math.sin(c.rot) * 40,
        y: c.y + Math.cos(c.rot) * 40,
        owner: c.i,
        target: t,
        life: 4,
      });
      if (c.isPlayer) showMsg("TURKEY AWAY!", 0.5);
    }
  }

  function hitSpin(c) {
    if (c.invuln > 0) return;
    if (c.shield) { c.shield = false; c.invuln = 0.6; return; }
    c.spinT = 1.1;
    c.speed = 0;
    c.invuln = 1.2;
    if (c.isPlayer) showMsg("SLIPPED!", 0.5);
  }

  function hitSlow(c) {
    if (c.invuln > 0) return;
    if (c.shield) { c.shield = false; c.invuln = 0.5; return; }
    c.slowT = 2;
    c.invuln = 0.4;
  }

  function tryBoost() {
    const p = player();
    if (!raceStarted || boostCharge < 1 || p.boostT > 0) return;
    boostCharge = 0;
    p.boostT = 1.2;
    p.speed = Math.max(p.speed, p.maxSpeed * 1.1);
    showMsg("EXPRESS!", 0.5);
  }

  function update(dt) {
    if (mode !== "race") return;

    const p = player();
    let steer = 0;
    if (leftDown || keys.ArrowLeft || keys.a || keys.A) steer -= 1;
    if (rightDown || keys.ArrowRight || keys.d || keys.D) steer += 1;
    p.steer = steer;

    if (raceStarted && !raceOver) {
      for (const c of carts) {
        if (!c.finished) {
          updateCart(c, dt);
          updateProgress(c);
        }
      }
      for (const c of carts) if (!c.isPlayer) updateAI(c, dt);
      boostCharge = Math.min(1, boostCharge + dt * 0.08);
    }

    // Item boxes
    for (const b of boxes) {
      if (!b.available) {
        b.respawn -= dt;
        if (b.respawn <= 0) b.available = true;
      } else {
        for (const c of carts) {
          if (c.item || c.finished) continue;
          if (hypot(c.x - b.x, c.y - b.y) < 28) {
            b.available = false;
            b.respawn = 5;
            c.item = randItem();
            if (c.isPlayer) showMsg(ITEM_LABEL[c.item], 0.6);
          }
        }
      }
    }

    // Hazards
    hazards = hazards.filter((h) => {
      h.life -= dt;
      if (h.life <= 0) return false;
      for (const c of carts) {
        if (c.i === h.owner || c.finished) continue;
        if (hypot(c.x - h.x, c.y - h.y) < 22) {
          hitSpin(c);
          return false;
        }
      }
      return true;
    });

    // Turkeys
    projectiles = projectiles.filter((t) => {
      t.life -= dt;
      if (t.life <= 0) return false;
      if (t.target && !t.target.finished) {
        const dx = t.target.x - t.x;
        const dy = t.target.y - t.y;
        const d = Math.max(1, hypot(dx, dy));
        t.x += (dx / d) * 320 * dt;
        t.y += (dy / d) * 320 * dt;
      } else {
        t.y += 200 * dt;
      }
      for (const c of carts) {
        if (c.i === t.owner || c.finished) continue;
        if (hypot(c.x - t.x, c.y - t.y) < 24) {
          hitSpin(c);
          if (c.isPlayer) showMsg("HIT BY TURKEY!", 0.6);
          return false;
        }
      }
      return true;
    });

    // Cart vs cart soft push
    for (let i = 0; i < carts.length; i++) {
      for (let j = i + 1; j < carts.length; j++) {
        const a = carts[i], b = carts[j];
        const dx = b.x - a.x, dy = b.y - a.y;
        const d = hypot(dx, dy);
        if (d < 38 && d > 0.01) {
          const push = (38 - d) / 2;
          const nx = dx / d, ny = dy / d;
          a.x -= nx * push; a.y -= ny * push;
          b.x += nx * push; b.y += ny * push;
          a.speed *= 0.95; b.speed *= 0.95;
        }
      }
    }

    // Camera
    const look = 80;
    const tx = p.x + Math.sin(p.rot) * look;
    const ty = p.y + Math.cos(p.rot) * look;
    cam.x += (tx - cam.x) * 0.12;
    cam.y += (ty - cam.y) * 0.12;

    playerPlace = placeOf(p);
    updateHUD();
  }

  function updateHUD() {
    const p = player();
    document.getElementById("place").textContent = ordinal(playerPlace);
    document.getElementById("lap").textContent = `Lap ${Math.min(p.lap + 1, TOTAL_LAPS)}/${TOTAL_LAPS}`;
    document.getElementById("item-emoji").textContent = p.item ? ITEM_EMOJI[p.item] : "";
    const fill = document.getElementById("boost-fill");
    fill.style.width = `${boostCharge * 100}%`;
    document.getElementById("boost-btn").classList.toggle("ready", boostCharge >= 1);
  }

  // ---------- Draw ----------
  function draw() {
    ctx.clearRect(0, 0, W, H);

    if (mode === "menu") {
      // subtle animated floor behind menu (menu CSS covers most)
      ctx.fillStyle = "#1a2921";
      ctx.fillRect(0, 0, W, H);
      return;
    }

    ctx.save();
    ctx.translate(W / 2 - cam.x, H / 2 - cam.y);

    // Floor
    ctx.fillStyle = COLORS.floor;
    ctx.fillRect(0, 0, WORLD.w, WORLD.h);
    const tile = 64;
    ctx.fillStyle = COLORS.tile;
    for (let x = 0; x < WORLD.w; x += tile) {
      for (let y = 0; y < WORLD.h; y += tile) {
        if (((x / tile) + (y / tile)) % 2 === 0) {
          ctx.globalAlpha = 0.55;
          ctx.fillRect(x, y, tile, tile);
        }
      }
    }
    ctx.globalAlpha = 1;

    // Checkout stripe
    ctx.fillStyle = COLORS.yellow;
    ctx.fillRect(200, 292, 200, 16);
    ctx.fillStyle = COLORS.ink;
    ctx.font = "bold 16px DM Sans, sans-serif";
    ctx.fillText("CHECKOUT →", 230, 330);

    // Aisle labels
    ctx.fillStyle = "rgba(0,0,0,0.08)";
    ctx.font = "bold 22px Archivo Black, sans-serif";
    ctx.fillText("AISLE 1", 660, 810);
    ctx.fillText("AISLE 4", 1360, 810);

    // Shelves
    for (const s of SHELVES) {
      ctx.fillStyle = s.c;
      roundRect(ctx, s.x, s.y, s.w, s.h, 4);
      ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,0.25)";
      ctx.lineWidth = 2;
      ctx.stroke();
      if (s.label) {
        ctx.fillStyle = "rgba(255,255,255,0.5)";
        ctx.font = "bold 14px DM Sans, sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.save();
        ctx.translate(s.x + s.w / 2, s.y + s.h / 2);
        if (s.h > s.w) ctx.rotate(-Math.PI / 2);
        ctx.fillText(s.label, 0, 0);
        ctx.restore();
        ctx.textAlign = "left";
        ctx.textBaseline = "alphabetic";
      }
    }

    // Item boxes
    for (const b of boxes) {
      ctx.globalAlpha = b.available ? 1 : 0.15;
      const pulse = 1 + Math.sin(performance.now() / 200) * 0.05;
      const bw = 28 * pulse, bh = 32 * pulse;
      ctx.fillStyle = "#348a59";
      roundRect(ctx, b.x - bw / 2, b.y - bh / 2, bw, bh, 4);
      ctx.fill();
      ctx.strokeStyle = COLORS.yellow;
      ctx.lineWidth = 2.5;
      ctx.stroke();
      ctx.fillStyle = "#fff";
      ctx.font = "bold 18px Archivo Black, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("?", b.x, b.y + 1);
      ctx.globalAlpha = 1;
    }

    // Hazards
    for (const h of hazards) {
      ctx.fillStyle = COLORS.yellow;
      ctx.beginPath();
      ctx.ellipse(h.x, h.y, 11, 7, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#b89418";
      ctx.stroke();
    }

    // Projectiles
    for (const t of projectiles) {
      ctx.font = "22px serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("🦃", t.x, t.y);
    }

    // Carts
    const drawOrder = [...carts].sort((a, b) => a.y - b.y);
    for (const c of drawOrder) drawCart(c);

    ctx.restore();
  }

  function drawCart(c) {
    ctx.save();
    ctx.translate(c.x, c.y);
    ctx.rotate(c.rot);

    // wheels
    ctx.fillStyle = COLORS.ink;
    for (const [wx, wy] of [[-16, 16], [16, 16], [-16, -18], [16, -18]]) {
      ctx.beginPath();
      ctx.arc(wx, wy, 5, 0, Math.PI * 2);
      ctx.fill();
    }

    // body
    ctx.fillStyle = COLORS.carts[c.i];
    roundRect(ctx, -18, -26, 36, 52, 6);
    ctx.fill();
    ctx.strokeStyle = "rgba(0,0,0,0.3)";
    ctx.lineWidth = 2;
    ctx.stroke();

    // basket mesh
    ctx.strokeStyle = "rgba(255,255,255,0.35)";
    ctx.lineWidth = 1.2;
    for (let i = -1; i <= 1; i++) {
      ctx.beginPath();
      ctx.moveTo(i * 8, -14);
      ctx.lineTo(i * 8, 16);
      ctx.stroke();
    }

    // handle
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    roundRect(ctx, -20, -30, 40, 5, 2);
    ctx.fill();

    if (c.shield) {
      ctx.strokeStyle = "rgba(100, 210, 255, 0.9)";
      ctx.fillStyle = "rgba(100, 210, 255, 0.12)";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(0, 0, 34, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }

    if (c.boostT > 0) {
      ctx.fillStyle = "rgba(235, 199, 56, 0.7)";
      for (let i = 0; i < 3; i++) {
        ctx.beginPath();
        ctx.arc((Math.random() - 0.5) * 16, -30 - Math.random() * 10, 2 + Math.random() * 2, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    ctx.restore();

    // name
    ctx.fillStyle = "#f5f0e1";
    ctx.font = "bold 11px DM Sans, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(c.isPlayer ? "YOU" : COLORS.names[c.i], c.x, c.y - 40);

    if (c.isPlayer) {
      ctx.fillStyle = COLORS.yellow;
      ctx.beginPath();
      ctx.moveTo(c.x, c.y - 52);
      ctx.lineTo(c.x - 7, c.y - 40);
      ctx.lineTo(c.x + 7, c.y - 40);
      ctx.closePath();
      ctx.fill();
    }
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function loop(t) {
    const dt = lastT ? Math.min(1 / 20, (t - lastT) / 1000) : 1 / 60;
    lastT = t;
    if (msgTimer > 0) msgTimer -= dt;
    update(dt);
    draw();
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  // ---------- Input ----------
  function setSteerFromPoint(clientX) {
    const ratio = clientX / W;
    leftDown = ratio < 0.4;
    rightDown = ratio > 0.6;
  }

  canvas.addEventListener("pointerdown", (e) => {
    if (mode !== "race") return;
    canvas.setPointerCapture(e.pointerId);
    setSteerFromPoint(e.clientX);
  });
  canvas.addEventListener("pointermove", (e) => {
    if (mode !== "race" || e.buttons === 0 && e.pointerType === "mouse") return;
    if (e.pointerType === "mouse" && !e.buttons) return;
    setSteerFromPoint(e.clientX);
  });
  canvas.addEventListener("pointerup", () => { leftDown = rightDown = false; });
  canvas.addEventListener("pointercancel", () => { leftDown = rightDown = false; });

  // Also track on HUD overlays
  window.addEventListener("pointerdown", (e) => {
    if (mode !== "race") return;
    if (e.target.closest("#item-btn") || e.target.closest("#boost-btn")) return;
    if (e.target.closest(".panel")) return;
    setSteerFromPoint(e.clientX);
  });
  window.addEventListener("pointerup", () => { leftDown = rightDown = false; });

  window.addEventListener("keydown", (e) => {
    keys[e.key] = true;
    if (e.key === " " || e.code === "Space") {
      e.preventDefault();
      if (mode === "race") useItem(player());
    }
    if (e.key === "Shift") tryBoost();
  });
  window.addEventListener("keyup", (e) => { keys[e.key] = false; });

  document.getElementById("btn-race").onclick = () => resetRace();
  document.getElementById("btn-how").onclick = () => {
    document.getElementById("howto").classList.remove("hidden");
  };
  document.getElementById("btn-close-how").onclick = () => {
    document.getElementById("howto").classList.add("hidden");
  };
  document.getElementById("btn-retry").onclick = () => resetRace();
  document.getElementById("btn-menu").onclick = () => {
    mode = "menu";
    document.getElementById("results").classList.add("hidden");
    document.getElementById("hud").classList.add("hidden");
    document.getElementById("menu").classList.remove("hidden");
  };
  document.getElementById("item-btn").onclick = () => useItem(player());
  document.getElementById("boost-btn").onclick = () => tryBoost();
})();
