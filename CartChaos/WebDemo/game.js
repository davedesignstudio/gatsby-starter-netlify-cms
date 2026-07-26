(() => {
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");

  const CARTS = [
    { id: "rusty", name: "Rusty", tagline: "Squeaky wheels, big heart", color: "#b8612e", top: 4.6, accel: 0.055, handling: 0.065 },
    { id: "speedy", name: "Speedy", tagline: "Stolen from express lane", color: "#268cc9", top: 5.4, accel: 0.08, handling: 0.05 },
    { id: "jumbo", name: "Jumbo", tagline: "Built for bulk hauls", color: "#409e47", top: 4.2, accel: 0.04, handling: 0.045 },
    { id: "zigzag", name: "Zigzag", tagline: "Never walks a straight aisle", color: "#d98c1f", top: 4.9, accel: 0.065, handling: 0.09 },
    { id: "glitter", name: "Glitter", tagline: "Cart with main-character energy", color: "#c7386b", top: 5.0, accel: 0.07, handling: 0.06 },
  ];

  const POWERUPS = [
    { id: "banana", label: "BANANA", color: "#f5d031" },
    { id: "soda", label: "SODA", color: "#e23b3b" },
    { id: "soup", label: "SOUP", color: "#e7892d" },
    { id: "coupon", label: "COUPON", color: "#2db8a8" },
    { id: "spill", label: "SPILL", color: "#8b3d8f" },
  ];

  const LAP_LENGTH = 1000;
  const TOTAL_LAPS = 3;
  const TRACK_HALF = 0.92;

  const TRACK = [
    { p: 0, c: 0.0, aisle: "ENTRANCE", floor: [200, 184, 158] },
    { p: 80, c: 0.15, aisle: "PRODUCE", floor: [184, 199, 140] },
    { p: 160, c: 0.45, aisle: "PRODUCE", floor: [178, 194, 132] },
    { p: 240, c: -0.1, aisle: "BAKERY", floor: [209, 178, 132] },
    { p: 320, c: -0.55, aisle: "DAIRY", floor: [184, 199, 214] },
    { p: 400, c: -0.2, aisle: "DAIRY", floor: [178, 194, 209] },
    { p: 480, c: 0.35, aisle: "FROZEN", floor: [173, 204, 224] },
    { p: 560, c: 0.6, aisle: "FROZEN", floor: [168, 199, 219] },
    { p: 640, c: 0.1, aisle: "SNACKS", floor: [214, 173, 122] },
    { p: 720, c: -0.4, aisle: "CEREAL", floor: [204, 184, 140] },
    { p: 800, c: -0.15, aisle: "CHECKOUT", floor: [191, 191, 199] },
    { p: 880, c: 0.25, aisle: "CHECKOUT", floor: [189, 189, 196] },
    { p: 960, c: 0.05, aisle: "EXIT RAMP", floor: [200, 184, 158] },
    { p: 1000, c: 0.0, aisle: "ENTRANCE", floor: [200, 184, 158] },
  ];

  let selectedCart = CARTS[1];
  let mode = "menu"; // menu | countdown | race | results
  let racers = [];
  let hazards = [];
  let projectiles = [];
  let pickups = [];
  let countdown = 3.2;
  let raceFinished = false;
  let finishOrder = 0;
  let shake = 0;
  let leftPressed = false;
  let rightPressed = false;
  let accelerating = false;
  let lastTs = 0;
  let toastTimer = 0;
  let toastText = "";

  const menuEl = document.getElementById("menu");
  const resultsEl = document.getElementById("results");
  const hudEl = document.getElementById("hud");
  const controlsEl = document.getElementById("controls");
  const countdownEl = document.getElementById("countdown");
  const toastEl = document.getElementById("toast");
  const picker = document.getElementById("cartPicker");
  const tagline = document.getElementById("tagline");

  function buildPicker() {
    picker.innerHTML = "";
    CARTS.forEach((cart) => {
      const btn = document.createElement("button");
      btn.className = "cart-btn" + (cart.id === selectedCart.id ? " active" : "");
      btn.textContent = cart.name.toUpperCase();
      btn.style.borderColor = cart.id === selectedCart.id ? cart.color : "transparent";
      btn.onclick = () => {
        selectedCart = cart;
        tagline.textContent = cart.tagline;
        buildPicker();
      };
      picker.appendChild(btn);
    });
    tagline.textContent = selectedCart.tagline;
  }
  buildPicker();

  document.getElementById("startBtn").onclick = startRace;
  document.getElementById("retryBtn").onclick = startRace;
  document.getElementById("menuBtn").onclick = () => {
    mode = "menu";
    showMenu();
  };

  function showMenu() {
    menuEl.classList.remove("hidden");
    resultsEl.classList.add("hidden");
    hudEl.classList.add("hidden");
    controlsEl.classList.add("hidden");
    countdownEl.classList.add("hidden");
  }

  function startRace() {
    menuEl.classList.add("hidden");
    resultsEl.classList.add("hidden");
    hudEl.classList.remove("hidden");
    controlsEl.classList.remove("hidden");
    countdownEl.classList.remove("hidden");
    mode = "countdown";
    countdown = 3.2;
    raceFinished = false;
    finishOrder = 0;
    shake = 0;
    hazards = [];
    projectiles = [];
    pickups = [];
    racers = [];

    racers.push(makeRacer(0, selectedCart, true, 0));
    const rivals = CARTS.filter((c) => c.id !== selectedCart.id).slice(0, 4);
    rivals.forEach((c, i) => racers.push(makeRacer(i + 1, c, false, -(i + 1) * 18)));

    for (let i = 0; i < 12; i++) {
      pickups.push({
        progress: i * (LAP_LENGTH / 12) + 40,
        lateral: i % 2 === 0 ? -0.35 : 0.35,
        kind: POWERUPS[i % POWERUPS.length],
        collected: false,
        respawnIn: 0,
      });
    }
  }

  function makeRacer(id, arch, isPlayer, start) {
    return {
      id,
      arch,
      isPlayer,
      progress: start,
      lateral: (Math.random() - 0.5) * 0.5,
      speed: 0,
      lap: 1,
      finished: false,
      finishPlace: null,
      stun: 0,
      boost: 0,
      shield: 0,
      held: null,
      aiBias: (Math.random() - 0.5) * 0.6,
      aiTimer: 0,
    };
  }

  function sampleTrack(progress) {
    const p = ((progress % LAP_LENGTH) + LAP_LENGTH) % LAP_LENGTH;
    for (let i = 0; i < TRACK.length - 1; i++) {
      const a = TRACK[i];
      const b = TRACK[i + 1];
      if (p >= a.p && p <= b.p) {
        const t = (p - a.p) / Math.max(0.001, b.p - a.p);
        return {
          curvature: a.c + (b.c - a.c) * t,
          aisle: t < 0.5 ? a.aisle : b.aisle,
          floor: a.floor.map((v, idx) => v + (b.floor[idx] - v) * t),
        };
      }
    }
    return { curvature: 0, aisle: "ENTRANCE", floor: TRACK[0].floor };
  }

  function curvature(progress) {
    return sampleTrack(progress).curvature;
  }

  function wrapDelta(a, b) {
    let d = a - b;
    const half = LAP_LENGTH / 2;
    while (d > half) d -= LAP_LENGTH;
    while (d < -half) d += LAP_LENGTH;
    return d;
  }

  function nearestLapProgress(local, reference) {
    const lap = Math.floor(reference / LAP_LENGTH);
    const candidates = [local + lap * LAP_LENGTH, local + (lap - 1) * LAP_LENGTH, local + (lap + 1) * LAP_LENGTH];
    return candidates.reduce((best, c) => (Math.abs(c - reference) < Math.abs(best - reference) ? c : best));
  }

  function toast(msg) {
    toastText = msg;
    toastTimer = 1.2;
    toastEl.textContent = msg;
    toastEl.style.opacity = "1";
  }

  function topSpeed(r) {
    return r.arch.top * (r.boost > 0 ? 1.45 : 1);
  }
  function accel(r) {
    return r.arch.accel * (r.boost > 0 ? 1.6 : 1);
  }

  function tickTimers(r, dt) {
    if (r.stun > 0) r.stun -= dt;
    if (r.boost > 0) r.boost -= dt;
    if (r.shield > 0) r.shield -= dt;
  }

  function handleLap(r, prev) {
    if (prev < LAP_LENGTH * r.lap && r.progress >= LAP_LENGTH * r.lap) {
      r.lap += 1;
      if (r.lap > TOTAL_LAPS) {
        r.finished = true;
        finishOrder += 1;
        r.finishPlace = finishOrder;
        r.speed = 0;
      }
    }
  }

  function usePower(r) {
    if (!r.held) return;
    const kind = r.held.id;
    r.held = null;
    if (kind === "banana") {
      hazards.push({ progress: r.progress - 18, lateral: r.lateral, kind: "banana", life: 12 });
    } else if (kind === "spill") {
      hazards.push({ progress: r.progress - 14, lateral: r.lateral + 0.1, kind: "spill", life: 12 });
      hazards.push({ progress: r.progress - 20, lateral: r.lateral - 0.15, kind: "spill", life: 12 });
    } else if (kind === "soda") {
      r.boost = 1.6;
      if (r.isPlayer) toast("SODA BOOST!");
    } else if (kind === "soup") {
      projectiles.push({ progress: r.progress + 20, lateral: r.lateral, ownerId: r.id, life: 2.2 });
    } else if (kind === "coupon") {
      r.shield = 3.5;
      if (r.isPlayer) toast("COUPON SHIELD!");
    }
  }

  function updatePlayer(dt) {
    const p = racers.find((r) => r.isPlayer);
    if (!p || p.finished) return;
    tickTimers(p, dt);
    if (p.stun > 0) {
      p.speed *= 0.92;
      return;
    }
    let steering = 0;
    if (leftPressed) steering -= 1;
    if (rightPressed) steering += 1;
    const curve = curvature(p.progress);
    p.lateral += (steering * p.arch.handling - curve * 0.012) * p.speed * 0.35;
    p.lateral = Math.max(-TRACK_HALF, Math.min(TRACK_HALF, p.lateral));
    if (Math.abs(p.lateral) > TRACK_HALF * 0.92) {
      p.speed *= 0.94;
      shake = Math.max(shake, 3);
    }
    if (accelerating) p.speed = Math.min(topSpeed(p), p.speed + accel(p));
    else p.speed = Math.max(0, p.speed - 0.04);
    const prev = p.progress;
    p.progress += p.speed;
    handleLap(p, prev);
  }

  function updateAI(dt) {
    const player = racers.find((r) => r.isPlayer);
    racers.filter((r) => !r.isPlayer && !r.finished).forEach((r) => {
      tickTimers(r, dt);
      if (r.stun > 0) {
        r.speed *= 0.9;
        return;
      }
      r.aiTimer -= dt;
      if (r.aiTimer <= 0) {
        r.aiTimer = 0.4 + Math.random() * 0.7;
        r.aiBias = (Math.random() - 0.5) * 1.1;
        if (r.held && Math.random() < 0.35) usePower(r);
      }
      const curve = curvature(r.progress);
      const target = r.aiBias * 0.55;
      r.lateral += (target - r.lateral) * r.arch.handling * 1.4;
      r.lateral -= curve * 0.01 * r.speed;
      r.lateral = Math.max(-TRACK_HALF, Math.min(TRACK_HALF, r.lateral));
      const gap = player.progress - r.progress;
      let rubber = 1;
      if (gap > 80) rubber = 1.18;
      else if (gap < -100) rubber = 0.88;
      const targetSpeed = topSpeed(r) * rubber * (0.92 + Math.random() * 0.13);
      if (r.speed < targetSpeed) r.speed += accel(r) * rubber;
      else r.speed -= 0.03;
      r.speed = Math.max(0, Math.min(topSpeed(r) * 1.25, r.speed));
      const prev = r.progress;
      r.progress += r.speed;
      handleLap(r, prev);
    });
  }

  function updateSystems(dt) {
    pickups.forEach((pu) => {
      if (pu.collected) {
        pu.respawnIn -= dt;
        if (pu.respawnIn <= 0) pu.collected = false;
      }
    });
    racers.forEach((r) => {
      if (r.finished || r.held) return;
      pickups.forEach((pu) => {
        if (pu.collected) return;
        if (Math.abs(wrapDelta(r.progress, pu.progress)) < 12 && Math.abs(r.lateral - pu.lateral) < 0.28) {
          r.held = pu.kind;
          pu.collected = true;
          pu.respawnIn = 7;
          if (r.isPlayer) toast(`Got ${pu.kind.label}!`);
        }
      });
    });

    for (let i = hazards.length - 1; i >= 0; i--) {
      hazards[i].life -= dt;
      if (hazards[i].life <= 0) {
        hazards.splice(i, 1);
        continue;
      }
      for (const r of racers) {
        if (r.finished) continue;
        if (Math.abs(wrapDelta(r.progress, hazards[i].progress)) < 10 && Math.abs(r.lateral - hazards[i].lateral) < 0.22) {
          if (r.shield > 0) r.shield = 0;
          else {
            r.stun = hazards[i].kind === "spill" ? 1.1 : 0.85;
            r.speed *= 0.35;
            if (r.isPlayer) shake = 8;
          }
          hazards.splice(i, 1);
          break;
        }
      }
    }

    for (let i = projectiles.length - 1; i >= 0; i--) {
      projectiles[i].progress += 9.5;
      projectiles[i].life -= dt;
      if (projectiles[i].life <= 0) {
        projectiles.splice(i, 1);
        continue;
      }
      for (const r of racers) {
        if (r.id === projectiles[i].ownerId || r.finished) continue;
        if (Math.abs(wrapDelta(r.progress, projectiles[i].progress)) < 14 && Math.abs(r.lateral - projectiles[i].lateral) < 0.3) {
          if (r.shield > 0) r.shield = 0;
          else {
            r.stun = 1.0;
            r.speed *= 0.3;
            if (r.isPlayer) shake = 10;
          }
          projectiles.splice(i, 1);
          break;
        }
      }
    }

    for (let i = 0; i < racers.length; i++) {
      for (let j = i + 1; j < racers.length; j++) {
        const a = racers[i];
        const b = racers[j];
        if (a.finished || b.finished) continue;
        if (Math.abs(wrapDelta(a.progress, b.progress)) < 10 && Math.abs(a.lateral - b.lateral) < 0.24) {
          const push = 0.08;
          if (a.lateral < b.lateral) {
            a.lateral -= push;
            b.lateral += push;
          } else {
            a.lateral += push;
            b.lateral -= push;
          }
          a.speed *= 0.96;
          b.speed *= 0.96;
        }
      }
    }
  }

  function placeOf(r) {
    if (r.finishPlace) return r.finishPlace;
    return racers.filter((o) => o.id !== r.id && (o.finished || o.progress > r.progress)).length + 1;
  }

  function ordinal(n) {
    return n === 1 ? "1st" : n === 2 ? "2nd" : n === 3 ? "3rd" : `${n}th`;
  }

  function checkFinish() {
    const p = racers.find((r) => r.isPlayer);
    if (!p || !p.finished || raceFinished) return;
    raceFinished = true;
    mode = "results";
    const place = p.finishPlace || placeOf(p);
    document.getElementById("resultsTitle").textContent = place === 1 ? "AISLE CHAMPION!" : "RACE OVER";
    document.getElementById("resultsBlurb").textContent = `${p.arch.name} finished ${ordinal(place)}`;
    const list = [...racers]
      .map((r) => ({ name: r.arch.name, place: r.finishPlace || placeOf(r), color: r.arch.color }))
      .sort((a, b) => a.place - b.place);
    document.getElementById("standings").innerHTML = list
      .map((row) => `<div style="color:${row.color};margin:.25rem 0">${ordinal(row.place)}  ${row.name}</div>`)
      .join("");
    setTimeout(() => {
      resultsEl.classList.remove("hidden");
      hudEl.classList.add("hidden");
      controlsEl.classList.add("hidden");
      countdownEl.classList.add("hidden");
    }, 900);
  }

  function project(progress, lateral, playerProgress, playerLateral, w, h) {
    const delta = progress - playerProgress;
    if (delta < -20 || delta > 160) return null;
    const t = Math.max(0, Math.min(1, delta / 160));
    const horizonY = h * 0.62;
    const y = horizonY * (1 - Math.pow(1 - t, 1.65));
    const perspective = 0.08 + 0.92 * Math.pow(1 - t, 1.35);
    const halfW = w * 0.48 * perspective;
    const centerX = w / 2 - playerLateral * w * 0.28 * (1 - t);
    return { x: centerX + lateral * halfW, y, scale: 0.25 + 1.1 * perspective, t };
  }

  function drawCart(x, y, scale, color, steer = 0) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(steer);
    ctx.scale(scale, scale);
    // wheels
    ctx.fillStyle = "#1a1a1a";
    ctx.beginPath();
    ctx.arc(-22, 18, 10, 0, Math.PI * 2);
    ctx.arc(22, 18, 10, 0, Math.PI * 2);
    ctx.fill();
    // basket
    ctx.fillStyle = color;
    ctx.strokeStyle = "#1a1a1a";
    ctx.lineWidth = 2;
    roundRect(-35, -20, 70, 42, 4);
    ctx.fill();
    ctx.stroke();
    // mesh
    ctx.strokeStyle = "rgba(255,255,255,.45)";
    ctx.lineWidth = 1.5;
    for (let i = -2; i <= 2; i++) {
      ctx.beginPath();
      ctx.moveTo(i * 12, -16);
      ctx.lineTo(i * 12, 18);
      ctx.stroke();
    }
    // handle
    ctx.fillStyle = "#222";
    roundRect(-27, -34, 54, 6, 3);
    ctx.fill();
    // rider
    ctx.fillStyle = "#ffdbb3";
    ctx.beginPath();
    ctx.arc(0, -22, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#184868";
    roundRect(-9, -32, 18, 8, 2);
    ctx.fill();
    ctx.restore();
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

  function drawWorld() {
    const w = canvas.width;
    const h = canvas.height;
    const player = racers.find((r) => r.isPlayer) || { progress: 0, lateral: 0, arch: selectedCart, speed: 0 };
    const sample = sampleTrack(player.progress);
    const shakeX = shake > 0 ? (Math.random() - 0.5) * shake * 2 : 0;

    // ceiling / horizon
    const grad = ctx.createLinearGradient(0, 0, 0, h * 0.55);
    grad.addColorStop(0, "#7a8c98");
    grad.addColorStop(1, "#5d6c76");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    // lights
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = "rgba(255,255,255,.14)";
      ctx.fillRect(w * (0.12 + i * 0.14), h * 0.04, w * 0.1, 10);
    }

    const rows = 72;
    const horizonY = h * 0.62;
    const left = [];
    const right = [];
    let curveAccum = 0;
    const playerCurve = sample.curvature;

    for (let i = 0; i < rows; i++) {
      const t = i / (rows - 1);
      const y = horizonY * (1 - Math.pow(1 - t, 1.65));
      const perspective = 0.08 + 0.92 * Math.pow(1 - t, 1.35);
      const halfW = w * 0.48 * perspective;
      const lookAhead = player.progress + t * 140;
      const localCurve = curvature(lookAhead);
      curveAccum += (localCurve - playerCurve) * (1 - t) * 2.2;
      const centerX = w / 2 - player.lateral * w * 0.28 * (1 - t) + curveAccum * w * 0.12 + shakeX;
      left.push({ x: centerX - halfW, y });
      right.push({ x: centerX + halfW, y });
    }

    // shelves
    ctx.fillStyle = "#6b5338";
    ctx.beginPath();
    ctx.moveTo(0, h);
    ctx.lineTo(left[0].x, left[0].y);
    left.forEach((p) => ctx.lineTo(p.x, p.y));
    ctx.lineTo(0, horizonY);
    ctx.closePath();
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(w, h);
    ctx.lineTo(right[0].x, right[0].y);
    right.forEach((p) => ctx.lineTo(p.x, p.y));
    ctx.lineTo(w, horizonY);
    ctx.closePath();
    ctx.fill();

    // shelf products hints
    for (let i = 8; i < rows; i += 7) {
      const t = i / (rows - 1);
      const colors = ["#d94c4c", "#e7a12d", "#4caf6a", "#4aa3d9", "#c9c23a"];
      ctx.fillStyle = colors[i % colors.length];
      const lx = left[i].x - 18 * (1 - t);
      const rx = right[i].x + 8 * (1 - t);
      const s = 10 + 16 * (1 - t);
      ctx.fillRect(lx - s, left[i].y - s, s, s * 1.2);
      ctx.fillRect(rx, right[i].y - s, s, s * 1.2);
    }

    // floor
    const [fr, fg, fb] = sample.floor;
    ctx.fillStyle = `rgb(${fr | 0},${fg | 0},${fb | 0})`;
    ctx.beginPath();
    ctx.moveTo(left[0].x, h);
    left.forEach((p) => ctx.lineTo(p.x, p.y));
    for (let i = right.length - 1; i >= 0; i--) ctx.lineTo(right[i].x, right[i].y);
    ctx.lineTo(right[0].x, h);
    ctx.closePath();
    ctx.fill();

    // aisle dashes
    for (let i = 0; i < rows - 1; i += 5) {
      const t = i / (rows - 1);
      const y = horizonY * (1 - Math.pow(1 - t, 1.65));
      const perspective = 0.08 + 0.92 * Math.pow(1 - t, 1.35);
      const centerX = (left[i].x + right[i].x) / 2;
      ctx.fillStyle = `rgba(255,255,255,${0.25 + 0.3 * (1 - t)})`;
      ctx.fillRect(centerX - 3 * perspective, y, 6 * perspective, 16 * perspective);
    }

    // aisle label
    ctx.fillStyle = "rgba(0,0,0,.35)";
    ctx.fillRect(w / 2 - 120, h * 0.08, 240, 34);
    ctx.fillStyle = "#fff";
    ctx.font = "700 18px Space Grotesk, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(`AISLE • ${sample.aisle}`, w / 2, h * 0.08 + 23);

    // pickups / hazards / projectiles / rivals (far to near)
    const sprites = [];
    pickups.forEach((pu) => {
      if (pu.collected) return;
      const abs = nearestLapProgress(pu.progress, player.progress);
      const pr = project(abs, pu.lateral, player.progress, player.lateral, w, h);
      if (pr) sprites.push({ z: pr.t, draw: () => {
        ctx.fillStyle = pu.kind.color;
        ctx.strokeStyle = "#fff";
        ctx.lineWidth = 2;
        const s = 18 * pr.scale;
        roundRect(pr.x - s / 2, pr.y - s / 2, s, s, 4);
        ctx.fill();
        ctx.stroke();
      }});
    });
    hazards.forEach((hz) => {
      const abs = nearestLapProgress(hz.progress, player.progress);
      const pr = project(abs, hz.lateral, player.progress, player.lateral, w, h);
      if (pr) sprites.push({ z: pr.t, draw: () => {
        ctx.fillStyle = hz.kind === "banana" ? "#f5d031" : "rgba(120,40,140,.85)";
        ctx.beginPath();
        ctx.arc(pr.x, pr.y, 10 * pr.scale, 0, Math.PI * 2);
        ctx.fill();
      }});
    });
    projectiles.forEach((pj) => {
      const pr = project(pj.progress, pj.lateral, player.progress, player.lateral, w, h);
      if (pr) sprites.push({ z: pr.t, draw: () => {
        ctx.fillStyle = "#e7892d";
        ctx.strokeStyle = "#fff";
        ctx.beginPath();
        ctx.arc(pr.x, pr.y, 8 * pr.scale, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      }});
    });
    racers.filter((r) => !r.isPlayer && !r.finished).forEach((r) => {
      const pr = project(r.progress, r.lateral, player.progress, player.lateral, w, h);
      if (pr) sprites.push({ z: pr.t, draw: () => drawCart(pr.x, pr.y, pr.scale * 1.05, r.arch.color) });
    });
    sprites.sort((a, b) => a.z - b.z).forEach((s) => s.draw());

    // player cart
    let steering = 0;
    if (leftPressed) steering -= 1;
    if (rightPressed) steering += 1;
    const px = w / 2 + player.lateral * w * 0.28 + shakeX;
    const py = h * 0.78;
    if (player.shield > 0) {
      ctx.strokeStyle = "rgba(45,184,168,.7)";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(px, py - 10, 55, 0, Math.PI * 2);
      ctx.stroke();
    }
    drawCart(px, py, 1.45, player.arch.color, -steering * 0.18 - sample.curvature * 0.08);

    // minimap
    const mx = w - 70;
    const my = h - 90;
    ctx.fillStyle = "rgba(0,0,0,.45)";
    ctx.beginPath();
    ctx.arc(mx, my, 48, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.35)";
    ctx.lineWidth = 2;
    ctx.stroke();
    racers.forEach((r) => {
      const ang = (r.progress / LAP_LENGTH) * Math.PI * 2 - Math.PI / 2;
      ctx.fillStyle = r.isPlayer ? "#ffd84a" : r.arch.color;
      ctx.beginPath();
      ctx.arc(mx + Math.cos(ang) * 36, my + Math.sin(ang) * 36, r.isPlayer ? 5 : 3.5, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function updateHUD() {
    const p = racers.find((r) => r.isPlayer);
    if (!p) return;
    document.getElementById("place").textContent = ordinal(placeOf(p));
    document.getElementById("lap").textContent = `LAP ${Math.min(p.lap, TOTAL_LAPS)}/${TOTAL_LAPS}`;
    document.getElementById("speed").textContent = `${Math.round(p.speed * 28)} mph`;
    const item = document.getElementById("item");
    if (p.held) {
      item.textContent = `ITEM: ${p.held.label}`;
      item.style.color = p.held.color;
    } else if (p.shield > 0) {
      item.textContent = "SHIELD";
      item.style.color = "#2db8a8";
    } else if (p.boost > 0) {
      item.textContent = "BOOST";
      item.style.color = "#e23b3b";
    } else {
      item.textContent = "ITEM: —";
      item.style.color = "#ddd";
    }
  }

  function frame(ts) {
    const dt = Math.min(0.033, (ts - lastTs) / 1000 || 0.016);
    lastTs = ts;

    if (mode === "menu") {
      // idle preview world
      if (!racers.length) {
        racers = [makeRacer(0, selectedCart, true, 0)];
      }
      racers[0].arch = selectedCart;
      racers[0].progress += 1.2;
      drawWorld();
    } else if (mode === "countdown") {
      countdown -= dt;
      if (countdown > 2) countdownEl.textContent = "3";
      else if (countdown > 1) countdownEl.textContent = "2";
      else if (countdown > 0) countdownEl.textContent = "1";
      else {
        countdownEl.textContent = "GO!";
        countdownEl.style.color = "#4ae06a";
        mode = "race";
        setTimeout(() => countdownEl.classList.add("hidden"), 500);
      }
      drawWorld();
      updateHUD();
    } else if (mode === "race") {
      updatePlayer(dt);
      updateAI(dt);
      updateSystems(dt);
      if (shake > 0) shake = Math.max(0, shake - dt * 8);
      if (toastTimer > 0) {
        toastTimer -= dt;
        if (toastTimer <= 0) toastEl.style.opacity = "0";
      }
      drawWorld();
      updateHUD();
      checkFinish();
    } else if (mode === "results") {
      drawWorld();
    }

    requestAnimationFrame(frame);
  }

  // controls
  function bindHold(el, on, off) {
    const start = (e) => { e.preventDefault(); on(); };
    const end = (e) => { e.preventDefault(); off(); };
    el.addEventListener("mousedown", start);
    el.addEventListener("mouseup", end);
    el.addEventListener("mouseleave", end);
    el.addEventListener("touchstart", start, { passive: false });
    el.addEventListener("touchend", end);
    el.addEventListener("touchcancel", end);
  }
  bindHold(document.getElementById("leftBtn"), () => (leftPressed = true), () => (leftPressed = false));
  bindHold(document.getElementById("rightBtn"), () => (rightPressed = true), () => (rightPressed = false));
  bindHold(document.getElementById("gasBtn"), () => (accelerating = true), () => (accelerating = false));
  document.getElementById("useBtn").addEventListener("click", () => {
    const p = racers.find((r) => r.isPlayer);
    if (p && mode === "race") usePower(p);
  });

  window.addEventListener("keydown", (e) => {
    if (e.code === "ArrowLeft" || e.code === "KeyA") leftPressed = true;
    if (e.code === "ArrowRight" || e.code === "KeyD") rightPressed = true;
    if (e.code === "Space" || e.code === "ArrowUp" || e.code === "KeyW") {
      e.preventDefault();
      accelerating = true;
    }
    if (e.code === "ShiftLeft" || e.code === "ShiftRight" || e.code === "KeyE") {
      const p = racers.find((r) => r.isPlayer);
      if (p && mode === "race") usePower(p);
    }
    if (e.code === "Enter" && mode === "menu") startRace();
  });
  window.addEventListener("keyup", (e) => {
    if (e.code === "ArrowLeft" || e.code === "KeyA") leftPressed = false;
    if (e.code === "ArrowRight" || e.code === "KeyD") rightPressed = false;
    if (e.code === "Space" || e.code === "ArrowUp" || e.code === "KeyW") accelerating = false;
  });

  requestAnimationFrame(frame);
})();
