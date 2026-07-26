/** Power-ups, hazards, projectiles */
(function () {
  const ITEM_KEYS = Object.keys(window.ITEM_DEFS);

  function createWorldItems() {
    const crates = [];
    for (let y = 0; y < Track.H; y++) {
      for (let x = 0; x < Track.W; x++) {
        if (Track.rows[y][x] === 3) {
          crates.push({
            x: (x + 0.5) * Track.TILE,
            y: (y + 0.5) * Track.TILE,
            alive: true,
            respawn: 0,
            phase: Math.random() * Math.PI * 2,
          });
        }
      }
    }
    return {
      crates,
      hazards: [],
      projectiles: [],
      effects: [],
    };
  }

  function randomItem() {
    return ITEM_KEYS[(Math.random() * ITEM_KEYS.length) | 0];
  }

  function update(world, racers, dt, onHit) {
    // Crates
    world.crates.forEach((c) => {
      c.phase += dt * 3;
      if (!c.alive) {
        c.respawn -= dt;
        if (c.respawn <= 0) c.alive = true;
        return;
      }
      racers.forEach((r) => {
        if (r.finished || r.item) return;
        if (Math.hypot(r.x - c.x, r.y - c.y) < 22) {
          c.alive = false;
          c.respawn = 6;
          r.item = randomItem();
          world.effects.push({
            x: c.x,
            y: c.y,
            life: 0.4,
            kind: "pickup",
          });
        }
      });
    });

    // Hazards
    world.hazards = world.hazards.filter((h) => {
      h.life -= dt;
      if (h.life <= 0) return false;
      racers.forEach((r) => {
        if (r === h.owner || r.finished) return;
        if (Math.hypot(r.x - h.x, r.y - h.y) < h.radius) {
          if (h.kind === "banana") {
            r.slip = Math.max(r.slip, 1.4);
            r.speed *= 0.5;
            h.life = 0;
            onHit && onHit(r, "banana");
          } else if (h.kind === "milk") {
            r.slip = Math.max(r.slip, 2.0);
            r.angle += (Math.random() - 0.5) * 1.2;
            onHit && onHit(r, "milk");
          }
        }
      });
      return h.life > 0;
    });

    // Projectiles
    world.projectiles = world.projectiles.filter((p) => {
      p.life -= dt;
      p.x += Math.cos(p.angle) * p.speed;
      p.y += Math.sin(p.angle) * p.speed;
      if (Track.isWall(p.x, p.y)) return false;
      let hit = false;
      racers.forEach((r) => {
        if (r === p.owner || r.finished) return;
        if (Math.hypot(r.x - p.x, r.y - p.y) < 20) {
          r.stunned = Math.max(r.stunned, 1.1);
          r.speed *= 0.3;
          hit = true;
          onHit && onHit(r, "can");
        }
      });
      return p.life > 0 && !hit;
    });

    // FX
    world.effects = world.effects.filter((e) => {
      e.life -= dt;
      return e.life > 0;
    });
  }

  function useItem(racer, world, racers) {
    if (!racer.item) return;
    const id = racer.item;
    racer.item = null;
    const def = ITEM_DEFS[id];

    if (id === "soda") {
      racer.boost = 1.6;
      racer.speed = Math.max(racer.speed, racer.cart.maxSpeed * 1.2);
      world.effects.push({ x: racer.x, y: racer.y, life: 0.5, kind: "boost" });
    } else if (id === "banana") {
      world.hazards.push({
        kind: "banana",
        x: racer.x - Math.cos(racer.angle) * 28,
        y: racer.y - Math.sin(racer.angle) * 28,
        radius: 16,
        life: 12,
        owner: racer,
      });
    } else if (id === "milk") {
      world.hazards.push({
        kind: "milk",
        x: racer.x - Math.cos(racer.angle) * 20,
        y: racer.y - Math.sin(racer.angle) * 20,
        radius: 36,
        life: 8,
        owner: racer,
      });
    } else if (id === "can") {
      world.projectiles.push({
        x: racer.x + Math.cos(racer.angle) * 24,
        y: racer.y + Math.sin(racer.angle) * 24,
        angle: racer.angle,
        speed: 9,
        life: 1.4,
        owner: racer,
      });
    } else if (id === "bag") {
      racers.forEach((o) => {
        if (o === racer || o.finished) return;
        if (Math.hypot(o.x - racer.x, o.y - racer.y) < 110) {
          o.stunned = Math.max(o.stunned, 0.9);
          o.speed *= 0.4;
        }
      });
      world.effects.push({ x: racer.x, y: racer.y, life: 0.45, kind: "bag" });
    }

    return def;
  }

  function draw(ctx, world, time) {
    world.crates.forEach((c) => {
      if (!c.alive) return;
      const bob = Math.sin(c.phase) * 3;
      ctx.save();
      ctx.translate(c.x, c.y + bob);
      ctx.rotate(time * 1.2);
      // Crate
      ctx.fillStyle = "#f0c419";
      ctx.fillRect(-12, -12, 24, 24);
      ctx.strokeStyle = "#8a6a08";
      ctx.lineWidth = 2;
      ctx.strokeRect(-12, -12, 24, 24);
      ctx.beginPath();
      ctx.moveTo(-12, -12);
      ctx.lineTo(12, 12);
      ctx.moveTo(12, -12);
      ctx.lineTo(-12, 12);
      ctx.stroke();
      ctx.fillStyle = "#1a1408";
      ctx.font = "bold 10px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("?", 0, 4);
      ctx.restore();
    });

    world.hazards.forEach((h) => {
      if (h.kind === "banana") {
        ctx.font = "22px serif";
        ctx.textAlign = "center";
        ctx.fillText("🍌", h.x, h.y + 6);
      } else if (h.kind === "milk") {
        ctx.fillStyle = "rgba(244, 239, 228, 0.65)";
        ctx.beginPath();
        ctx.ellipse(h.x, h.y, h.radius, h.radius * 0.7, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "rgba(200, 190, 170, 0.5)";
        ctx.beginPath();
        ctx.ellipse(h.x + 8, h.y - 4, 12, 8, 0.3, 0, Math.PI * 2);
        ctx.fill();
      }
    });

    world.projectiles.forEach((p) => {
      ctx.font = "18px serif";
      ctx.textAlign = "center";
      ctx.fillText("🥫", p.x, p.y + 5);
    });

    world.effects.forEach((e) => {
      const a = Math.max(0, e.life * 2);
      if (e.kind === "pickup") {
        ctx.fillStyle = `rgba(240, 196, 25, ${a})`;
        ctx.beginPath();
        ctx.arc(e.x, e.y, 20 * (1 - e.life), 0, Math.PI * 2);
        ctx.fill();
      } else if (e.kind === "boost") {
        ctx.fillStyle = `rgba(43, 179, 255, ${a})`;
        ctx.beginPath();
        ctx.arc(e.x, e.y, 28, 0, Math.PI * 2);
        ctx.fill();
      } else if (e.kind === "bag") {
        ctx.strokeStyle = `rgba(232, 69, 47, ${a})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(e.x, e.y, 90 * (1 - e.life), 0, Math.PI * 2);
        ctx.stroke();
      }
    });
  }

  window.Items = {
    createWorld: createWorldItems,
    update,
    use: useItem,
    draw,
  };
})();
