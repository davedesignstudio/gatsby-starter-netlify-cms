/** Cart Kart — main race loop */
(function () {
  const TOTAL_LAPS = 3;
  const AI_COUNT = 5;

  const state = {
    selectedCartId: "rusty",
    racing: false,
    paused: false,
    countdown: 0,
    raceTime: 0,
    racers: [],
    player: null,
    world: null,
    input: {
      steer: 0,
      gas: true,
      brake: false,
      fire: false,
    },
    cam: { x: 0, y: 0 },
    keys: {},
    touchSteer: 0,
    finishedOrder: [],
    banner: "",
    bannerTimer: 0,
  };

  const canvas = () => document.getElementById("game");
  const minimap = () => document.getElementById("minimap");

  function pickAiCarts(playerId) {
    const pool = CARTS.filter((c) => c.id !== playerId);
    const shuffled = pool.slice().sort(() => Math.random() - 0.5);
    return shuffled.slice(0, AI_COUNT);
  }

  function startRace() {
    const cart = CARTS.find((c) => c.id === state.selectedCartId) || CARTS[0];
    const starts = Track.startPositions();
    const racers = [];

    racers.push(
      Racer.create({
        id: "player",
        cart,
        name: cart.name,
        isPlayer: true,
        x: starts[0].x,
        y: starts[0].y,
        angle: starts[0].angle,
      })
    );

    const aiCarts = pickAiCarts(cart.id);
    // If fewer unique carts, reuse with name suffixes
    while (aiCarts.length < AI_COUNT) {
      aiCarts.push(CARTS[aiCarts.length % CARTS.length]);
    }
    aiCarts.forEach((ac, i) => {
      const s = starts[i + 1] || starts[starts.length - 1];
      racers.push(
        Racer.create({
          id: "ai-" + i,
          cart: ac,
          name: ac.name,
          isPlayer: false,
          x: s.x + (Math.random() - 0.5) * 8,
          y: s.y + (Math.random() - 0.5) * 8,
          angle: s.angle,
        })
      );
    });

    state.racers = racers;
    state.player = racers[0];
    state.world = Items.createWorld();
    state.racing = true;
    state.paused = false;
    state.countdown = 3.2;
    state.raceTime = 0;
    state.finishedOrder = [];
    state.banner = "";
    state.bannerTimer = 0;
    state.input.gas = true;
    state.cam.x = state.player.x - canvas().width / 2;
    state.cam.y = state.player.y - canvas().height / 2;

    updateHud();
    showBanner("READY", 0.01);
  }

  function showBanner(text, seconds) {
    state.banner = text;
    state.bannerTimer = seconds;
    const el = document.getElementById("race-banner");
    const cd = document.getElementById("countdown");
    if (text === "3" || text === "2" || text === "1" || text === "GO!") {
      cd.textContent = text;
      cd.classList.remove("hidden");
      el.classList.add("hidden");
      // retrigger animation
      cd.style.animation = "none";
      void cd.offsetWidth;
      cd.style.animation = "";
    } else {
      cd.classList.add("hidden");
      el.textContent = text;
      el.classList.toggle("hidden", !text);
    }
  }

  function updateHud() {
    const p = state.player;
    if (!p) return;
    const place = p.finishPlace || p.place;
    document.getElementById("hud-place").textContent = String(place);
    document.getElementById("hud-suffix").textContent = ordinal(place);
    const lap = Math.min(TOTAL_LAPS, Math.max(1, p.lap + 1));
    document.getElementById("hud-lap").textContent = String(
      p.finished ? TOTAL_LAPS : Math.min(lap, TOTAL_LAPS)
    );
    const itemEl = document.getElementById("hud-item");
    if (p.item) {
      itemEl.textContent = ITEM_DEFS[p.item].icon;
      itemEl.classList.add("filled");
      itemEl.classList.remove("empty");
    } else {
      itemEl.textContent = "";
      itemEl.classList.remove("filled");
      itemEl.classList.add("empty");
    }
  }

  function rankRacers() {
    const live = state.racers.slice().sort((a, b) => {
      if (a.finished && b.finished) return a.finishPlace - b.finishPlace;
      if (a.finished) return -1;
      if (b.finished) return 1;
      return b.progress - a.progress;
    });
    live.forEach((r, i) => {
      if (!r.finished) r.place = i + 1;
    });
  }

  function checkFinish() {
    state.racers.forEach((r) => {
      if (r.finished) return;
      if (r.lap >= TOTAL_LAPS) {
        r.finished = true;
        r.finishTime = state.raceTime;
        r.finishPlace = state.finishedOrder.length + 1;
        state.finishedOrder.push(r);
        if (r.isPlayer) {
          showBanner(r.finishPlace === 1 ? "YOU WIN!" : "FINISHED!", 2.5);
        }
      }
    });

    if (state.player.finished) {
      // End after short delay once player done, or all done
      const allDone = state.racers.every((r) => r.finished);
      if (allDone || state.raceTime - state.player.finishTime > 4) {
        // Force remaining finish order
        const rest = state.racers
          .filter((r) => !r.finished)
          .sort((a, b) => b.progress - a.progress);
        rest.forEach((r) => {
          r.finished = true;
          r.finishPlace = state.finishedOrder.length + 1;
          state.finishedOrder.push(r);
        });
        state.racing = false;
        window.CartKartUI && window.CartKartUI.showResults(state.finishedOrder);
      }
    }
  }

  function pollInput() {
    const k = state.keys;
    let steer = 0;
    if (k["ArrowLeft"] || k["a"] || k["A"]) steer -= 1;
    if (k["ArrowRight"] || k["d"] || k["D"]) steer += 1;
    if (Math.abs(state.touchSteer) > 0.05) steer = state.touchSteer;

    state.input.steer = Math.max(-1, Math.min(1, steer));

    // Keyboard gas/brake override auto-gas
    if (k["ArrowDown"] || k["s"] || k["S"]) {
      state.input.brake = true;
      state.input.gas = false;
    } else if (k["ArrowUp"] || k["w"] || k["W"]) {
      state.input.brake = false;
      state.input.gas = true;
    }

    if (k[" "] || k["Space"] || state.input.fire) {
      if (state.player && state.player.item) {
        Items.use(state.player, state.world, state.racers);
      }
      state.input.fire = false;
      k[" "] = false;
      k["Space"] = false;
    }
  }

  function update(dt) {
    if (!state.racing || state.paused) return;

    if (state.countdown > 0) {
      const prev = Math.ceil(state.countdown);
      state.countdown -= dt;
      const next = Math.ceil(state.countdown);
      if (state.countdown <= 0) {
        showBanner("GO!", 0.8);
      } else if (next !== prev && next > 0) {
        showBanner(String(next), 0.9);
      }
      // Still draw / camera follow during countdown but no movement
      followCam(1);
      return;
    }

    if (state.bannerTimer > 0) {
      state.bannerTimer -= dt;
      if (state.bannerTimer <= 0) {
        document.getElementById("countdown").classList.add("hidden");
        document.getElementById("race-banner").classList.add("hidden");
        state.banner = "";
      }
    }

    state.raceTime += dt;
    pollInput();

    const itemQueue = { queueItem: null };
    state.racers.forEach((r) => {
      Racer.update(r, r.isPlayer ? state.input : itemQueue, dt);
    });
    // AI item use
    state.racers.forEach((r) => {
      if (!r.isPlayer && r.item && Math.random() < 0.008) {
        Items.use(r, state.world, state.racers);
      }
    });

    Racer.separate(state.racers);
    Items.update(state.world, state.racers, dt);
    rankRacers();
    checkFinish();
    updateHud();
    followCam(dt);
  }

  function followCam(dt) {
    const c = canvas();
    const p = state.player;
    const lead = 80;
    const tx = p.x - c.width / 2 + Math.cos(p.angle) * lead;
    const ty = p.y - c.height / 2 + Math.sin(p.angle) * lead;
    const lerp = 1 - Math.pow(0.001, dt);
    state.cam.x += (tx - state.cam.x) * Math.min(1, lerp * 8);
    state.cam.y += (ty - state.cam.y) * Math.min(1, lerp * 8);
    state.cam.x = Math.max(0, Math.min(Track.width - c.width, state.cam.x));
    state.cam.y = Math.max(0, Math.min(Track.height - c.height, state.cam.y));
  }

  function draw() {
    const c = canvas();
    if (!c) return;
    const ctx = c.getContext("2d");
    const t = performance.now() / 1000;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, c.width, c.height);

    if (!state.player) return;

    ctx.save();
    ctx.translate(-state.cam.x, -state.cam.y);

    Track.drawFloor(ctx, state.cam.x, state.cam.y, c.width, c.height);
    Track.drawDecor(ctx);
    Items.draw(ctx, state.world, t);

    // Draw racers sorted by y for simple depth
    const sorted = state.racers.slice().sort((a, b) => a.y - b.y);
    sorted.forEach((r) => Racer.draw(ctx, r));

    ctx.restore();

    drawMinimap();
  }

  function drawMinimap() {
    const m = minimap();
    if (!m || !state.racers.length) return;
    const ctx = m.getContext("2d");
    const sx = m.width / Track.width;
    const sy = m.height / Track.height;
    ctx.clearRect(0, 0, m.width, m.height);
    ctx.fillStyle = "#2a4034";
    ctx.fillRect(0, 0, m.width, m.height);

    // Walls
    ctx.fillStyle = "#5c4033";
    for (let y = 0; y < Track.H; y++) {
      for (let x = 0; x < Track.W; x++) {
        if (Track.rows[y][x] === 1) {
          ctx.fillRect(x * Track.TILE * sx, y * Track.TILE * sy, Track.TILE * sx + 0.5, Track.TILE * sy + 0.5);
        }
      }
    }

    state.racers.forEach((r) => {
      ctx.fillStyle = r.isPlayer ? "#f0c419" : r.cart.color;
      ctx.beginPath();
      ctx.arc(r.x * sx, r.y * sy, r.isPlayer ? 3.5 : 2.5, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function resize() {
    const c = canvas();
    if (!c) return;
    const parent = c.parentElement;
    const w = parent.clientWidth || window.innerWidth;
    const h = parent.clientHeight || window.innerHeight;
    c.width = Math.max(320, w);
    c.height = Math.max(240, h);
  }

  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    update(dt);
    draw();
    requestAnimationFrame(frame);
  }

  function bindControls() {
    window.addEventListener("keydown", (e) => {
      state.keys[e.key] = true;
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " "].includes(e.key)) {
        e.preventDefault();
      }
      if (e.key === "p" || e.key === "P" || e.key === "Escape") {
        if (state.racing) window.CartKartUI && window.CartKartUI.togglePause();
      }
    });
    window.addEventListener("keyup", (e) => {
      state.keys[e.key] = false;
      if (e.key === "ArrowDown" || e.key === "s" || e.key === "S") {
        state.input.brake = false;
        state.input.gas = true;
      }
    });

    const steerZone = document.getElementById("steer-zone");
    const setSteerFromEvent = (e) => {
      const rect = steerZone.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const rel = (clientX - rect.left) / rect.width;
      state.touchSteer = (rel - 0.5) * 2;
    };
    const endSteer = () => {
      state.touchSteer = 0;
    };
    ["touchstart", "touchmove", "mousedown", "mousemove"].forEach((ev) => {
      steerZone.addEventListener(ev, (e) => {
        if (ev.startsWith("mouse") && e.buttons === 0 && ev !== "mousedown") return;
        e.preventDefault();
        setSteerFromEvent(e);
      }, { passive: false });
    });
    ["touchend", "touchcancel", "mouseup", "mouseleave"].forEach((ev) => {
      steerZone.addEventListener(ev, endSteer);
    });

    const bindPad = (id, on, off) => {
      const el = document.getElementById(id);
      const start = (e) => {
        e.preventDefault();
        el.classList.add("active");
        on();
      };
      const end = (e) => {
        e.preventDefault();
        el.classList.remove("active");
        off();
      };
      el.addEventListener("touchstart", start, { passive: false });
      el.addEventListener("mousedown", start);
      el.addEventListener("touchend", end);
      el.addEventListener("touchcancel", end);
      el.addEventListener("mouseup", end);
      el.addEventListener("mouseleave", end);
    };

    bindPad(
      "btn-gas",
      () => {
        state.input.gas = true;
        state.input.brake = false;
      },
      () => {
        /* keep auto gas */
        state.input.gas = true;
      }
    );
    bindPad(
      "btn-brake",
      () => {
        state.input.brake = true;
        state.input.gas = false;
      },
      () => {
        state.input.brake = false;
        state.input.gas = true;
      }
    );
    bindPad(
      "btn-fire",
      () => {
        state.input.fire = true;
      },
      () => {}
    );

    window.addEventListener("resize", resize);
    window.addEventListener("orientationchange", () => setTimeout(resize, 100));
  }

  function drawTitleCarts() {
    const c = document.getElementById("title-canvas");
    if (!c) return;
    const ctx = c.getContext("2d");
    let t = 0;
    const carts = [CARTS[0], CARTS[2], CARTS[4]];
    function tick() {
      t += 0.016;
      ctx.clearRect(0, 0, c.width, c.height);
      // Floor stripe
      ctx.fillStyle = "rgba(216, 201, 168, 0.25)";
      ctx.fillRect(0, 140, c.width, 60);
      carts.forEach((cart, i) => {
        const x = 70 + i * 130 + Math.sin(t * 2 + i) * 8;
        const y = 150 + Math.sin(t * 3 + i * 1.2) * 4;
        const fake = {
          x,
          y,
          angle: -0.15 + Math.sin(t + i) * 0.05,
          cart,
          isPlayer: i === 1,
          boost: i === 0 ? 0.5 : 0,
          slip: 0,
          name: cart.name,
        };
        Racer.draw(ctx, fake);
      });
      requestAnimationFrame(tick);
    }
    tick();
  }

  window.CartKart = {
    state,
    startRace,
    resize,
    setPaused(v) {
      state.paused = v;
    },
    isRacing() {
      return state.racing;
    },
    quit() {
      state.racing = false;
      state.paused = false;
    },
    init() {
      bindControls();
      resize();
      drawTitleCarts();
      requestAnimationFrame(frame);
    },
  };
})();
