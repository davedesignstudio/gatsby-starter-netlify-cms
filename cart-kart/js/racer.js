/** Player & AI shopping-cart racers */
(function () {
  const RADIUS = 16;

  function createRacer(opts) {
    const cart = opts.cart;
    return {
      id: opts.id,
      name: opts.name || cart.name,
      cart,
      isPlayer: !!opts.isPlayer,
      x: opts.x,
      y: opts.y,
      angle: opts.angle || 0,
      speed: 0,
      vx: 0,
      vy: 0,
      lap: 0,
      wp: 0,
      progress: 0,
      place: 1,
      item: null,
      stunned: 0,
      boost: 0,
      slip: 0,
      finished: false,
      finishTime: 0,
      finishPlace: 0,
      aiTimer: 0,
      aiSteer: 0,
      trail: [],
    };
  }

  function updateProgress(r) {
    const wps = Track.waypoints;
    const wp = wps[r.wp % wps.length];
    const dx = wp.x - r.x;
    const dy = wp.y - r.y;
    const dist = Math.hypot(dx, dy);
    if (dist < 70) {
      r.wp = (r.wp + 1) % wps.length;
      if (r.wp === 0) {
        r.lap += 1;
      }
    }
    // Progress score for ranking
    const seg = 1 - Math.min(dist / 400, 1);
    r.progress = r.lap * 1000 + r.wp * 10 + seg;
  }

  function applyPhysics(r, input, dt) {
    if (r.finished) return;

    if (r.stunned > 0) {
      r.stunned -= dt;
      r.speed *= 0.92;
    }

    const cart = r.cart;
    let throttle = 0;
    let steer = 0;
    let braking = false;

    if (r.isPlayer) {
      throttle = input.gas ? 1 : 0;
      if (input.brake) {
        braking = true;
        throttle = 0;
      }
      steer = input.steer;
    } else {
      // AI: seek next waypoint with slight noise
      r.aiTimer -= dt;
      if (r.aiTimer <= 0) {
        r.aiTimer = 0.15 + Math.random() * 0.25;
        r.aiSteer = (Math.random() - 0.5) * 0.35;
      }
      const wps = Track.waypoints;
      const target = wps[r.wp % wps.length];
      // Look ahead a bit
      const look = wps[(r.wp + 1) % wps.length];
      const tx = target.x * 0.65 + look.x * 0.35;
      const ty = target.y * 0.65 + look.y * 0.35;
      const desired = Math.atan2(ty - r.y, tx - r.x);
      let diff = desired - r.angle;
      while (diff > Math.PI) diff -= Math.PI * 2;
      while (diff < -Math.PI) diff += Math.PI * 2;
      steer = Math.max(-1, Math.min(1, diff * 1.8 + r.aiSteer));
      throttle = r.slip > 0 ? 0.35 : 0.72 + Math.random() * 0.18;
      // Use items opportunistically
      if (r.item && Math.random() < 0.012) {
        input.queueItem = r;
      }
    }

    const maxSp = cart.maxSpeed * (r.boost > 0 ? 1.55 : 1) * (r.slip > 0 ? 0.45 : 1);
    const grip = cart.grip * (r.slip > 0 ? 0.35 : 1);

    if (braking) {
      r.speed *= 0.9;
    } else if (throttle > 0 && r.stunned <= 0) {
      r.speed += cart.accel * throttle * (r.boost > 0 ? 1.4 : 1);
    } else {
      r.speed *= 0.985;
    }
    r.speed = Math.max(0, Math.min(maxSp, r.speed));

    const turnRate = cart.turn * (0.45 + 0.55 * (r.speed / Math.max(maxSp, 0.01)));
    r.angle += steer * turnRate * (r.slip > 0 ? 1.8 : 1);

    // Produce slow pads
    if (Track.tileAt(r.x, r.y) === 4) {
      r.speed *= 0.96;
    }

    if (r.boost > 0) r.boost -= dt;
    if (r.slip > 0) r.slip -= dt;

    const targetVx = Math.cos(r.angle) * r.speed;
    const targetVy = Math.sin(r.angle) * r.speed;
    r.vx = r.vx * (1 - grip) + targetVx * grip;
    r.vy = r.vy * (1 - grip) + targetVy * grip;

    let nx = r.x + r.vx;
    let ny = r.y + r.vy;

    if (!Track.solidAt(nx, r.y, RADIUS)) {
      r.x = nx;
    } else {
      r.vx *= -0.3;
      r.speed *= 0.55;
    }
    if (!Track.solidAt(r.x, ny, RADIUS)) {
      r.y = ny;
    } else {
      r.vy *= -0.3;
      r.speed *= 0.55;
    }

    // Soft clamp inside map
    r.x = Math.max(RADIUS, Math.min(Track.width - RADIUS, r.x));
    r.y = Math.max(RADIUS, Math.min(Track.height - RADIUS, r.y));

    r.trail.push({ x: r.x, y: r.y, a: r.angle });
    if (r.trail.length > 12) r.trail.shift();

    updateProgress(r);
  }

  function drawCart(ctx, r) {
    ctx.save();
    ctx.translate(r.x, r.y);
    ctx.rotate(r.angle);

    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(2, 6, 18, 10, 0, 0, Math.PI * 2);
    ctx.fill();

    const c = r.cart;
    // Body / basket
    ctx.fillStyle = c.basket;
    ctx.strokeStyle = c.accent;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-14, -10);
    ctx.lineTo(12, -11);
    ctx.lineTo(16, 10);
    ctx.lineTo(-12, 11);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Wire grid
    ctx.strokeStyle = "rgba(40,50,60,0.35)";
    ctx.lineWidth = 1;
    for (let i = -8; i <= 8; i += 5) {
      ctx.beginPath();
      ctx.moveTo(i, -9);
      ctx.lineTo(i + 2, 9);
      ctx.stroke();
    }

    // Handle
    ctx.strokeStyle = c.color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-14, -10);
    ctx.lineTo(-18, -16);
    ctx.lineTo(-6, -16);
    ctx.stroke();

    // Bumper plate
    ctx.fillStyle = c.color;
    ctx.fillRect(12, -8, 8, 16);
    ctx.fillStyle = c.accent;
    ctx.fillRect(18, -6, 3, 12);

    // Wheels
    ctx.fillStyle = "#222";
    ctx.beginPath();
    ctx.arc(-8, 12, 4, 0, Math.PI * 2);
    ctx.arc(8, 12, 4, 0, Math.PI * 2);
    ctx.arc(-8, -12, 3.5, 0, Math.PI * 2);
    ctx.arc(10, -12, 3.5, 0, Math.PI * 2);
    ctx.fill();

    // Boost glow
    if (r.boost > 0) {
      ctx.fillStyle = "rgba(43, 179, 255, 0.5)";
      ctx.beginPath();
      ctx.moveTo(-16, -6);
      ctx.lineTo(-28 - Math.random() * 6, 0);
      ctx.lineTo(-16, 6);
      ctx.fill();
    }

    // Slip stars
    if (r.slip > 0) {
      ctx.fillStyle = "#f0c419";
      ctx.font = "10px sans-serif";
      ctx.fillText("✦", -4, -18);
    }

    ctx.restore();

    // Nameplate
    if (!r.isPlayer) {
      ctx.fillStyle = "rgba(0,0,0,0.45)";
      ctx.font = "bold 10px Space Grotesk, sans-serif";
      ctx.textAlign = "center";
      const label = r.name;
      const tw = ctx.measureText(label).width;
      ctx.fillRect(r.x - tw / 2 - 4, r.y - 34, tw + 8, 14);
      ctx.fillStyle = "#f7f3ea";
      ctx.fillText(label, r.x, r.y - 24);
    } else {
      // Player arrow
      ctx.fillStyle = "#f0c419";
      ctx.beginPath();
      ctx.moveTo(r.x, r.y - 30);
      ctx.lineTo(r.x - 6, r.y - 40);
      ctx.lineTo(r.x + 6, r.y - 40);
      ctx.fill();
    }
  }

  function separate(racers) {
    for (let i = 0; i < racers.length; i++) {
      for (let j = i + 1; j < racers.length; j++) {
        const a = racers[i];
        const b = racers[j];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const d = Math.hypot(dx, dy) || 0.01;
        const min = RADIUS * 2.05;
        if (d < min) {
          const push = (min - d) / 2;
          const nx = dx / d;
          const ny = dy / d;
          a.x -= nx * push;
          a.y -= ny * push;
          b.x += nx * push;
          b.y += ny * push;
          // Bump speed exchange
          const impact = 0.15;
          a.speed *= 1 - impact;
          b.speed *= 1 - impact;
          a.vx -= nx * 0.8;
          a.vy -= ny * 0.8;
          b.vx += nx * 0.8;
          b.vy += ny * 0.8;
        }
      }
    }
  }

  window.Racer = {
    RADIUS,
    create: createRacer,
    update: applyPhysics,
    draw: drawCart,
    separate,
  };
})();
