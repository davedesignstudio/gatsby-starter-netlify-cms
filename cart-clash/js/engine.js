(() => {
  const TOTAL_LAPS = 3;
  const ROAD_WIDTH = 2200;
  const CAM_HEIGHT = 1000;
  const CAM_DEPTH = 0.84;
  const DRAW_DIST = 180;
  const SEGMENT_LEN = 1;

  const ITEM_TYPES = ["banana", "soda", "pricegun", "coupon"];

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function createRacer(cart, opts) {
    return {
      cart,
      name: cart.name,
      isPlayer: !!opts.isPlayer,
      z: opts.z || 0,
      x: opts.x || 0,
      speed: 0,
      maxSpeed: 280 * cart.speed,
      accel: 140 * cart.accel,
      handling: 2.6 * cart.handling,
      steer: 0,
      gas: false,
      brake: false,
      lap: 0,
      finished: false,
      finishOrder: 0,
      item: null,
      shield: 0,
      boost: 0,
      stunned: 0,
      wobble: 0,
      color: cart.color,
      accent: cart.accent,
      aiPhase: Math.random() * Math.PI * 2,
      progress: 0,
    };
  }

  class CartClashEngine {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.w = 960;
      this.h = 540;
      this.state = "idle";
      this.racers = [];
      this.player = null;
      this.hazards = [];
      this.pickups = [];
      this.particles = [];
      this.projectiles = [];
      this.time = 0;
      this.raceTime = 0;
      this.countdown = 0;
      this.finishCount = 0;
      this.cameraX = 0;
      this.banner = "";
      this.bannerTimer = 0;
      this.onFinish = null;
      this.onHud = null;
      this._last = 0;
      this._raf = 0;
      this.resize();
    }

    resize() {
      const rect = this.canvas.getBoundingClientRect();
      this.w = Math.max(640, Math.floor(rect.width));
      this.h = Math.max(360, Math.floor(rect.height));
      this.canvas.width = Math.floor(this.w * this.dpr);
      this.canvas.height = Math.floor(this.h * this.dpr);
      this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    }

    start(playerCart) {
      this.resize();
      const carts = window.CARTS;
      const playerIdx = carts.findIndex((c) => c.id === playerCart.id);
      this.racers = [];

      // Player starts near middle of pack
      this.player = createRacer(playerCart, { isPlayer: true, z: 8, x: 0 });
      this.racers.push(this.player);

      let slot = 0;
      carts.forEach((c, i) => {
        if (i === playerIdx) return;
        const x = slot % 2 === 0 ? -0.35 : 0.35;
        const z = 4 + slot * 3;
        this.racers.push(createRacer(c, { z, x }));
        slot++;
      });

      // Extra AI filler so race feels packed
      const fillers = [
        { name: "Squeaky Pete", color: "#7a8f3a", accent: "#3a4a18", speed: 0.95, accel: 1.0, handling: 1.05 },
        { name: "Bent Axle", color: "#8a4a6a", accent: "#4a2038", speed: 1.03, accel: 0.95, handling: 0.95 },
        { name: "Milk Crate", color: "#4a6aaa", accent: "#203050", speed: 0.98, accel: 1.05, handling: 1.0 },
      ];
      fillers.forEach((f, i) => {
        this.racers.push(
          createRacer(
            { ...f, id: `filler-${i}` },
            { z: 2 + i * 2.5, x: (i - 1) * 0.28 }
          )
        );
      });

      this.hazards = [];
      this.pickups = [];
      this.particles = [];
      this.projectiles = [];
      this.seedPickups();
      this.time = 0;
      this.raceTime = 0;
      this.finishCount = 0;
      this.countdown = 3.2;
      this.state = "countdown";
      this.banner = "";
      this.bannerTimer = 0;
      this._last = performance.now();
      cancelAnimationFrame(this._raf);
      this.loop(this._last);
    }

    seedPickups() {
      this.pickups = [];
      const trackLen = TRACK.length;
      for (let i = 0; i < 18; i++) {
        this.pickups.push({
          z: ((i + 1) / 19) * trackLen,
          x: (i % 3 === 0 ? -0.45 : i % 3 === 1 ? 0 : 0.45) + (Math.random() - 0.5) * 0.1,
          type: ITEM_TYPES[i % ITEM_TYPES.length],
          alive: true,
          respawn: 0,
        });
      }
    }

    stop() {
      this.state = "idle";
      cancelAnimationFrame(this._raf);
    }

    pause() {
      if (this.state === "racing" || this.state === "countdown") this.state = "paused";
    }

    resume() {
      if (this.state === "paused") {
        this.state = this.countdown > 0 ? "countdown" : "racing";
        this._last = performance.now();
        this.loop(this._last);
      }
    }

    setInput({ steer, gas, brake, useItem }) {
      if (!this.player) return;
      if (typeof steer === "number") this.player.steer = clamp(steer, -1, 1);
      if (typeof gas === "boolean") this.player.gas = gas;
      if (typeof brake === "boolean") this.player.brake = brake;
      if (useItem) this.useItem(this.player);
    }

    useItem(racer) {
      if (!racer.item || racer.stunned > 0 || racer.finished) return;
      const item = racer.item;
      racer.item = null;

      if (item === "soda") {
        racer.boost = Math.max(racer.boost, 1.6);
        this.flashBanner(`${racer.name}: SODA BOOST!`);
        this.burst(racer, "#e23a2e", 10);
      } else if (item === "coupon") {
        racer.shield = Math.max(racer.shield, 3.5);
        this.flashBanner(`${racer.name}: COUPON SHIELD!`);
      } else if (item === "banana") {
        this.hazards.push({
          z: racer.z - 4,
          x: racer.x,
          type: "banana",
          life: 18,
        });
        this.flashBanner(`${racer.name} dropped a peel`);
      } else if (item === "pricegun") {
        this.projectiles.push({
          owner: racer,
          z: racer.z + 6,
          x: racer.x,
          speed: 420,
          life: 2.2,
        });
        this.flashBanner(`${racer.name}: PRICE GUN!`);
      }
    }

    flashBanner(text) {
      this.banner = text;
      this.bannerTimer = 1.6;
    }

    burst(racer, color, n) {
      for (let i = 0; i < n; i++) {
        this.particles.push({
          z: racer.z,
          x: racer.x + (Math.random() - 0.5) * 0.2,
          vx: (Math.random() - 0.5) * 0.8,
          vz: (Math.random() - 0.5) * 40,
          life: 0.5 + Math.random() * 0.4,
          color,
        });
      }
    }

    loop(now) {
      if (this.state === "idle" || this.state === "paused") return;
      const dt = Math.min(0.05, (now - this._last) / 1000);
      this._last = now;
      this.update(dt);
      this.draw();
      this._raf = requestAnimationFrame((t) => this.loop(t));
    }

    update(dt) {
      this.time += dt;
      if (this.bannerTimer > 0) this.bannerTimer -= dt;

      if (this.state === "countdown") {
        this.countdown -= dt;
        this.updateAI(dt * 0.15);
        this.racers.forEach((r) => {
          if (!r.isPlayer) this.applyPhysics(r, dt * 0.2);
        });
        if (this.countdown <= 0) {
          this.state = "racing";
          this.flashBanner("GO!");
        }
        this.emitHud();
        return;
      }

      if (this.state !== "racing" && this.state !== "finished") return;

      if (this.state === "racing") this.raceTime += dt;

      this.updateAI(dt);
      this.racers.forEach((r) => this.applyPhysics(r, dt));
      this.resolveCollisions();
      this.updatePickups(dt);
      this.updateHazards(dt);
      this.updateProjectiles(dt);
      this.updateParticles(dt);
      this.updateLaps();
      this.cameraX = lerp(this.cameraX, this.player.x, 1 - Math.pow(0.001, dt));
      this.emitHud();

      if (this.state === "racing" && this.player.finished) {
        // Wait briefly then finish screen once pack settles / timeout
        if (this.finishCount >= this.racers.length || this.raceTime > this.player._finishTime + 4) {
          this.state = "finished";
          if (this.onFinish) this.onFinish(this.results());
        }
      }
    }

    applyPhysics(r, dt) {
      if (r.finished) {
        r.speed = lerp(r.speed, r.maxSpeed * 0.35, dt * 2);
      }

      if (r.stunned > 0) {
        r.stunned -= dt;
        r.speed *= 1 - dt * 1.8;
        r.wobble += dt * 20;
      }
      if (r.shield > 0) r.shield -= dt;
      if (r.boost > 0) r.boost -= dt;

      const sample = TRACK.sample(r.z);
      const curveForce = sample.curve * 0.0009 * (r.speed / r.maxSpeed);

      if (!r.finished) {
        // Arcade feel: carts keep rolling; gas boosts, brake cuts speed.
        const autoDrive = r.isPlayer ? !r.brake : r.gas;
        if (r.gas || autoDrive) r.speed += r.accel * (r.gas ? 1 : 0.72) * dt;
        if (r.brake) r.speed -= r.accel * 1.5 * dt;
        if (!r.gas && !autoDrive && !r.brake) r.speed -= 35 * dt;
      }

      let cap = r.maxSpeed;
      if (r.boost > 0) cap *= 1.35;
      r.speed = clamp(r.speed, 0, cap);

      // Off-road drag
      const off = Math.abs(r.x) > 0.92;
      if (off) r.speed *= 1 - dt * 1.4;

      r.x += r.steer * r.handling * (0.35 + r.speed / r.maxSpeed) * dt;
      r.x -= curveForce * r.speed * dt;
      r.x = clamp(r.x, -1.35, 1.35);

      r.z += (r.speed * dt) / 20;
      if (r.z >= TRACK.length) {
        r.z -= TRACK.length;
        if (!r.finished && this.state === "racing") {
          r.lap += 1;
          if (r.isPlayer) this.flashBanner(`LAP ${Math.min(r.lap + 1, TOTAL_LAPS)}`);
          if (r.lap >= TOTAL_LAPS) {
            r.finished = true;
            r.finishOrder = ++this.finishCount;
            r._finishTime = this.raceTime;
            if (r.isPlayer) this.flashBanner(`FINISHED ${PLACE_SUFFIX(r.finishOrder)}!`);
          }
        }
      }

      r.progress = r.lap * TRACK.length + r.z;
    }

    updateAI(dt) {
      this.racers.forEach((r) => {
        if (r.isPlayer || r.finished) return;
        r.aiPhase += dt;
        r.gas = true;
        r.brake = false;

        // Follow racing line with wobble
        const target = Math.sin(r.aiPhase * 0.7) * 0.35;
        const err = target - r.x;
        r.steer = clamp(err * 2.2 + Math.sin(r.aiPhase * 3) * 0.1, -1, 1);

        // Rubber-band: keep AI competitive with player
        if (this.player) {
          const delta = this.player.progress - r.progress;
          if (delta > 40) r.speed = Math.min(r.speed + 40 * dt, r.maxSpeed * 1.15);
          if (delta < -55) r.speed *= 1 - dt * 0.35;
        }

        // Use items opportunistically
        if (r.item && Math.random() < dt * 0.55) {
          if (r.item === "soda" || r.item === "coupon" || Math.random() < 0.5) this.useItem(r);
        }
      });
    }

    updatePickups(dt) {
      this.pickups.forEach((p) => {
        if (!p.alive) {
          p.respawn -= dt;
          if (p.respawn <= 0) p.alive = true;
          return;
        }
        this.racers.forEach((r) => {
          if (r.finished || r.item) return;
          if (this.near(r, p, 5, 0.22)) {
            p.alive = false;
            p.respawn = 6 + Math.random() * 4;
            r.item = p.type;
            if (r.isPlayer) this.flashBanner(`Got ${ITEMS[p.type].name}!`);
          }
        });
      });
    }

    updateHazards(dt) {
      this.hazards = this.hazards.filter((h) => {
        h.life -= dt;
        if (h.life <= 0) return false;
        this.racers.forEach((r) => {
          if (r.stunned > 0) return;
          if (this.near(r, h, 4, 0.18)) {
            if (r.shield > 0) {
              r.shield = 0;
              h.life = 0;
              if (r.isPlayer) this.flashBanner("Shield saved you!");
            } else {
              r.stunned = 1.1;
              r.speed *= 0.35;
              this.burst(r, "#f0d24b", 8);
              if (r.isPlayer) this.flashBanner("Slipped on a peel!");
              h.life = 0;
            }
          }
        });
        return h.life > 0;
      });
    }

    updateProjectiles(dt) {
      this.projectiles = this.projectiles.filter((p) => {
        p.life -= dt;
        p.z += (p.speed * dt) / 20;
        if (p.z >= TRACK.length) p.z -= TRACK.length;
        let hit = false;
        this.racers.forEach((r) => {
          if (hit || r === p.owner || r.finished) return;
          if (this.near(r, p, 8, 0.28)) {
            hit = true;
            if (r.shield > 0) {
              r.shield = 0;
              if (r.isPlayer) this.flashBanner("Coupon blocked the zap!");
            } else {
              r.stunned = 1.3;
              r.speed *= 0.25;
              this.burst(r, "#1fa7a0", 12);
              if (r.isPlayer) this.flashBanner("ZAPPED by Price Gun!");
              else if (p.owner.isPlayer) this.flashBanner(`Hit ${r.name}!`);
            }
          }
        });
        return p.life > 0 && !hit;
      });
    }

    updateParticles(dt) {
      this.particles = this.particles.filter((p) => {
        p.life -= dt;
        p.x += p.vx * dt;
        p.z += (p.vz * dt) / 20;
        return p.life > 0;
      });
    }

    near(a, b, zWindow, xWindow) {
      let dz = Math.abs(a.z - b.z);
      dz = Math.min(dz, TRACK.length - dz);
      return dz < zWindow && Math.abs(a.x - b.x) < xWindow;
    }

    resolveCollisions() {
      for (let i = 0; i < this.racers.length; i++) {
        for (let j = i + 1; j < this.racers.length; j++) {
          const a = this.racers[i];
          const b = this.racers[j];
          if (this.near(a, b, 3.2, 0.16)) {
            const push = 0.04;
            if (a.x < b.x) {
              a.x -= push;
              b.x += push;
            } else {
              a.x += push;
              b.x -= push;
            }
            const avg = (a.speed + b.speed) * 0.5;
            a.speed = lerp(a.speed, avg * 0.92, 0.4);
            b.speed = lerp(b.speed, avg * 0.92, 0.4);
          }
        }
      }
    }

    updateLaps() {
      // no-op placeholder; lap logic in physics
    }

    standings() {
      return [...this.racers].sort((a, b) => {
        if (a.finished || b.finished) {
          if (a.finished && b.finished) return a.finishOrder - b.finishOrder;
          if (a.finished) return -1;
          return 1;
        }
        return b.progress - a.progress;
      });
    }

    results() {
      return this.standings().map((r, i) => ({
        place: r.finished ? r.finishOrder : i + 1,
        name: r.name,
        isPlayer: r.isPlayer,
        finished: r.finished,
        time: r._finishTime || this.raceTime,
      }));
    }

    emitHud() {
      if (!this.onHud || !this.player) return;
      const standings = this.standings();
      const place = standings.findIndex((r) => r.isPlayer) + 1;
      this.onHud({
        place,
        lap: Math.min(this.player.lap + 1, TOTAL_LAPS),
        totalLaps: TOTAL_LAPS,
        time: this.raceTime,
        countdown: this.state === "countdown" ? Math.ceil(this.countdown) : 0,
        banner: this.bannerTimer > 0 ? this.banner : "",
        item: this.player.item,
        state: this.state,
      });
    }

    // ---------- DRAW ----------
    draw() {
      const ctx = this.ctx;
      const W = this.w;
      const H = this.h;
      ctx.clearRect(0, 0, W, H);

      // Ceiling / fluorescent wash
      const sky = ctx.createLinearGradient(0, 0, 0, H * 0.55);
      sky.addColorStop(0, "#16343c");
      sky.addColorStop(0.55, "#1c2a30");
      sky.addColorStop(1, "#241c16");
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, W, H);

      this.drawFluorescents(ctx, W, H);
      this.drawRoad(ctx, W, H);
      this.drawSprites(ctx, W, H);
      this.drawPlayerCart(ctx, W, H);

      // Vignette
      const vig = ctx.createRadialGradient(W / 2, H * 0.55, H * 0.2, W / 2, H * 0.5, H * 0.85);
      vig.addColorStop(0, "rgba(0,0,0,0)");
      vig.addColorStop(1, "rgba(5,14,16,0.55)");
      ctx.fillStyle = vig;
      ctx.fillRect(0, 0, W, H);
    }

    drawFluorescents(ctx, W, H) {
      ctx.save();
      ctx.globalAlpha = 0.25 + Math.sin(this.time * 2) * 0.03;
      for (let i = 0; i < 5; i++) {
        const x = (W / 5) * i + W / 10;
        const g = ctx.createLinearGradient(x, 0, x, H * 0.45);
        g.addColorStop(0, "rgba(200, 240, 240, 0.55)");
        g.addColorStop(1, "rgba(200, 240, 240, 0)");
        ctx.fillStyle = g;
        ctx.fillRect(x - 18, 0, 36, H * 0.45);
      }
      ctx.restore();
    }

    project(x, z, camZ, camX, curveAccum) {
      const relZ = z - camZ;
      const scale = CAM_DEPTH / (relZ + CAM_DEPTH);
      const px = this.w / 2 + (x - camX) * ROAD_WIDTH * scale * 0.42 + curveAccum;
      const py = this.h * 0.55 + CAM_HEIGHT * scale * 0.42;
      const roadW = ROAD_WIDTH * scale * 0.42;
      return { x: px, y: py, w: roadW, scale, relZ };
    }

    drawRoad(ctx, W, H) {
      const player = this.player || { z: 0, x: 0 };
      const baseZ = player.z;
      const camX = this.cameraX;

      let curveAccum = 0;
      let prevY = H;
      let prevX = W / 2;
      let prevW = ROAD_WIDTH;

      // Clip floor
      ctx.fillStyle = "#1a1510";
      ctx.fillRect(0, H * 0.52, W, H * 0.48);

      for (let n = DRAW_DIST; n >= 0; n--) {
        const z = baseZ + n * SEGMENT_LEN;
        const seg = TRACK.sample(z);
        const p = this.project(0, n * SEGMENT_LEN, 0, camX, curveAccum);
        // Build curve influence for nearer segments
        curveAccum += seg.curve * n * 0.018;

        const y = p.y;
        const x = p.x;
        const w = p.w;
        const theme = seg.theme;

        if (n < DRAW_DIST) {
          const stripe = Math.floor(z) % 2 === 0;

          // Shelves / walls
          ctx.fillStyle = stripe ? theme.wallL : theme.shelf;
          ctx.fillRect(0, y, x - w * 1.15, prevY - y);
          ctx.fillStyle = stripe ? theme.wallR : theme.shelf;
          ctx.fillRect(x + w * 1.15, y, W - (x + w * 1.15), prevY - y);

          // Shelf goods dots
          if (n % 4 === 0 && n > 8) {
            ctx.globalAlpha = clamp(1 - n / DRAW_DIST, 0.15, 0.7);
            ctx.fillStyle = "#e23a2e";
            ctx.fillRect(x - w * 1.35, y + 2, Math.max(2, w * 0.05), Math.max(2, (prevY - y) * 0.4));
            ctx.fillStyle = "#f0b429";
            ctx.fillRect(x + w * 1.28, y + 2, Math.max(2, w * 0.05), Math.max(2, (prevY - y) * 0.4));
            ctx.globalAlpha = 1;
          }

          // Road
          ctx.fillStyle = stripe ? theme.road : shade(theme.road, 1.08);
          this.poly(ctx, prevX, prevY, prevW, x, y, w);

          // Edge lines
          ctx.fillStyle = theme.edge;
          this.poly(ctx, prevX, prevY, prevW, x, y, w * 1.02);
          ctx.fillStyle = stripe ? theme.road : shade(theme.road, 1.08);
          this.poly(ctx, prevX, prevY, prevW * 0.94, x, y, w * 0.94);

          // Center dashes
          if (Math.floor(z) % 3 === 0) {
            ctx.fillStyle = "rgba(244,239,228,0.35)";
            this.poly(ctx, prevX, prevY, prevW * 0.03, x, y, w * 0.03);
          }

          // Start/finish band near z~0
          const lapZ = ((z % TRACK.length) + TRACK.length) % TRACK.length;
          if (lapZ < 2) {
            ctx.fillStyle = Math.floor(z * 4) % 2 ? "#f4efe4" : "#0b1f24";
            this.poly(ctx, prevX, prevY, prevW * 0.9, x, y, w * 0.9);
          }
        }

        prevY = y;
        prevX = x;
        prevW = w;
      }
    }

    poly(ctx, x1, y1, w1, x2, y2, w2) {
      ctx.beginPath();
      ctx.moveTo(x1 - w1, y1);
      ctx.lineTo(x1 + w1, y1);
      ctx.lineTo(x2 + w2, y2);
      ctx.lineTo(x2 - w2, y2);
      ctx.closePath();
      ctx.fill();
    }

    drawSprites(ctx, W, H) {
      const player = this.player;
      if (!player) return;

      const sprites = [];

      this.pickups.forEach((p) => {
        if (!p.alive) return;
        let dz = p.z - player.z;
        if (dz < 0) dz += TRACK.length;
        if (dz > 0 && dz < DRAW_DIST) sprites.push({ kind: "pickup", ref: p, dz });
      });
      this.hazards.forEach((h) => {
        let dz = h.z - player.z;
        if (dz < 0) dz += TRACK.length;
        if (dz > 0 && dz < DRAW_DIST) sprites.push({ kind: "hazard", ref: h, dz });
      });
      this.projectiles.forEach((p) => {
        let dz = p.z - player.z;
        if (dz < 0) dz += TRACK.length;
        if (dz > 0 && dz < DRAW_DIST) sprites.push({ kind: "bolt", ref: p, dz });
      });
      this.racers.forEach((r) => {
        if (r.isPlayer) return;
        let dz = r.z - player.z;
        if (dz < -TRACK.length / 2) dz += TRACK.length;
        if (dz > TRACK.length / 2) dz -= TRACK.length;
        if (dz > 1 && dz < DRAW_DIST) sprites.push({ kind: "racer", ref: r, dz });
      });
      this.particles.forEach((p) => {
        let dz = p.z - player.z;
        if (dz < 0) dz += TRACK.length;
        if (dz > 0 && dz < DRAW_DIST) sprites.push({ kind: "particle", ref: p, dz });
      });

      sprites.sort((a, b) => b.dz - a.dz);

      let curveAccum = 0;
      // Precompute curve at distances roughly
      const curveAt = (dz) => {
        let c = 0;
        for (let n = DRAW_DIST; n >= dz; n--) {
          c += TRACK.sample(player.z + n).curve * n * 0.018;
        }
        // Approximate: sample average curve
        return TRACK.curveAhead(player.z, Math.max(2, dz)) * dz * 0.55;
      };

      sprites.forEach((s) => {
        const curve = curveAt(s.dz);
        const p = this.project(s.ref.x, s.dz, 0, this.cameraX, curve);
        if (p.y > H || p.scale <= 0) return;

        if (s.kind === "pickup") this.drawPickup(ctx, p, s.ref);
        else if (s.kind === "hazard") this.drawBanana(ctx, p);
        else if (s.kind === "bolt") this.drawBolt(ctx, p);
        else if (s.kind === "racer") this.drawCart(ctx, p, s.ref, false);
        else if (s.kind === "particle") {
          ctx.globalAlpha = clamp(s.ref.life * 2, 0, 1);
          ctx.fillStyle = s.ref.color;
          const sz = 4 * p.scale * 40;
          ctx.fillRect(p.x - sz / 2, p.y - sz / 2, sz, sz);
          ctx.globalAlpha = 1;
        }
      });
    }

    drawPickup(ctx, p, ref) {
      const s = Math.max(6, 48 * p.scale * 28);
      const bob = Math.sin(this.time * 6 + ref.z) * 4 * p.scale * 20;
      ctx.save();
      ctx.translate(p.x, p.y - s * 0.4 + bob);
      ctx.fillStyle = "rgba(0,0,0,0.25)";
      ctx.beginPath();
      ctx.ellipse(0, s * 0.45, s * 0.35, s * 0.12, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = ITEMS[ref.type].color;
      ctx.beginPath();
      ctx.moveTo(0, -s * 0.45);
      ctx.lineTo(s * 0.4, 0);
      ctx.lineTo(0, s * 0.45);
      ctx.lineTo(-s * 0.4, 0);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "rgba(255,255,255,0.55)";
      ctx.lineWidth = Math.max(1, s * 0.06);
      ctx.stroke();
      ctx.restore();
    }

    drawBanana(ctx, p) {
      const s = Math.max(5, 36 * p.scale * 28);
      ctx.save();
      ctx.translate(p.x, p.y - s * 0.15);
      ctx.fillStyle = "#f0d24b";
      ctx.beginPath();
      ctx.ellipse(0, 0, s * 0.45, s * 0.2, -0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#3a2a10";
      ctx.fillRect(-s * 0.05, -s * 0.25, s * 0.1, s * 0.15);
      ctx.restore();
    }

    drawBolt(ctx, p) {
      const s = Math.max(4, 30 * p.scale * 28);
      ctx.save();
      ctx.translate(p.x, p.y - s);
      ctx.fillStyle = "#1fa7a0";
      ctx.beginPath();
      ctx.moveTo(0, -s);
      ctx.lineTo(s * 0.35, -s * 0.1);
      ctx.lineTo(s * 0.05, -s * 0.1);
      ctx.lineTo(s * 0.25, s);
      ctx.lineTo(-s * 0.35, -s * 0.05);
      ctx.lineTo(-0.02, -s * 0.05);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    drawCart(ctx, p, racer, isPlayer) {
      const s = Math.max(8, (isPlayer ? 70 : 55) * p.scale * (isPlayer ? 1 : 28));
      const lean = (racer.steer || 0) * 8 + Math.sin(racer.wobble || 0) * 6;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate((lean * Math.PI) / 180);

      // shadow
      ctx.fillStyle = "rgba(0,0,0,0.3)";
      ctx.beginPath();
      ctx.ellipse(0, 0, s * 0.55, s * 0.16, 0, 0, Math.PI * 2);
      ctx.fill();

      // basket
      ctx.fillStyle = racer.color;
      ctx.strokeStyle = racer.accent || "#222";
      ctx.lineWidth = Math.max(1, s * 0.05);
      const bw = s * 0.7;
      const bh = s * 0.45;
      ctx.beginPath();
      ctx.moveTo(-bw * 0.5, -bh * 0.2);
      ctx.lineTo(bw * 0.5, -bh * 0.2);
      ctx.lineTo(bw * 0.42, -bh);
      ctx.lineTo(-bw * 0.42, -bh);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();

      // wire grid
      ctx.strokeStyle = "rgba(255,255,255,0.35)";
      ctx.lineWidth = Math.max(1, s * 0.03);
      for (let i = 1; i <= 3; i++) {
        const yy = -bh * 0.2 - (bh * 0.8 * i) / 4;
        ctx.beginPath();
        ctx.moveTo(-bw * 0.45 + i, yy);
        ctx.lineTo(bw * 0.45 - i, yy);
        ctx.stroke();
      }

      // handle
      ctx.strokeStyle = shade(racer.color, 0.75);
      ctx.lineWidth = Math.max(2, s * 0.08);
      ctx.beginPath();
      ctx.moveTo(-bw * 0.2, -bh);
      ctx.lineTo(-bw * 0.25, -bh * 1.35);
      ctx.lineTo(bw * 0.25, -bh * 1.35);
      ctx.lineTo(bw * 0.2, -bh);
      ctx.stroke();

      // wheels
      ctx.fillStyle = "#1a1a1a";
      ctx.beginPath();
      ctx.arc(-bw * 0.35, s * 0.02, s * 0.12, 0, Math.PI * 2);
      ctx.arc(bw * 0.35, s * 0.02, s * 0.12, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#888";
      ctx.beginPath();
      ctx.arc(-bw * 0.35, s * 0.02, s * 0.05, 0, Math.PI * 2);
      ctx.arc(bw * 0.35, s * 0.02, s * 0.05, 0, Math.PI * 2);
      ctx.fill();

      // shield ring
      if (racer.shield > 0) {
        ctx.strokeStyle = `rgba(240,180,41,${0.4 + Math.sin(this.time * 10) * 0.3})`;
        ctx.lineWidth = Math.max(2, s * 0.06);
        ctx.beginPath();
        ctx.ellipse(0, -bh * 0.5, bw * 0.7, bh * 0.9, 0, 0, Math.PI * 2);
        ctx.stroke();
      }

      // name tag for AI
      if (!isPlayer) {
        ctx.fillStyle = "rgba(11,31,36,0.75)";
        ctx.font = `bold ${Math.max(9, s * 0.22)}px "IBM Plex Sans", sans-serif`;
        ctx.textAlign = "center";
        const label = racer.name;
        const tw = ctx.measureText(label).width + 8;
        ctx.fillRect(-tw / 2, -bh * 1.7, tw, Math.max(12, s * 0.28));
        ctx.fillStyle = "#f4efe4";
        ctx.fillText(label, 0, -bh * 1.7 + Math.max(10, s * 0.22));
      }

      ctx.restore();
    }

    drawPlayerCart(ctx, W, H) {
      if (!this.player) return;
      const p = {
        x: W / 2 + this.player.steer * 18,
        y: H * 0.86,
        scale: 1,
      };
      // Fake speed stretch
      const fake = {
        ...this.player,
        steer: this.player.steer,
      };
      this.drawCart(ctx, p, fake, true);

      // Speed lines
      if (this.player.speed > 40) {
        ctx.save();
        ctx.globalAlpha = clamp(this.player.speed / this.player.maxSpeed, 0, 0.55);
        ctx.strokeStyle = "rgba(244,239,228,0.35)";
        ctx.lineWidth = 2;
        for (let i = 0; i < 8; i++) {
          const x = (W / 8) * i + ((this.time * 400) % 40);
          ctx.beginPath();
          ctx.moveTo(x, H * 0.55);
          ctx.lineTo(x - 20, H);
          ctx.stroke();
        }
        ctx.restore();
      }
    }
  }

  function shade(hex, factor) {
    const n = hex.replace("#", "");
    const num = parseInt(n.length === 3 ? n.split("").map((c) => c + c).join("") : n, 16);
    let r = (num >> 16) & 255;
    let g = (num >> 8) & 255;
    let b = num & 255;
    r = clamp(Math.round(r * factor), 0, 255);
    g = clamp(Math.round(g * factor), 0, 255);
    b = clamp(Math.round(b * factor), 0, 255);
    return `rgb(${r},${g},${b})`;
  }

  window.CartClashEngine = CartClashEngine;
  window.TOTAL_LAPS = TOTAL_LAPS;
})();
