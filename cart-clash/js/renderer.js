/** Mode-7 style aisle renderer + shopping cart sprites. */

export function createRenderer(canvas) {
  const ctx = canvas.getContext("2d", { alpha: false });
  let w = canvas.width;
  let h = canvas.height;

  function resize(cssW, cssH, dpr) {
    w = Math.max(320, Math.floor(cssW * dpr));
    h = Math.max(480, Math.floor(cssH * dpr));
    canvas.width = w;
    canvas.height = h;
  }

  function draw(track, camera, sprites, hazards, pickups, particles) {
    const horizon = (h * 0.34) | 0;

    // Store ceiling / freezer lights
    const sky = ctx.createLinearGradient(0, 0, 0, horizon);
    sky.addColorStop(0, "#071418");
    sky.addColorStop(0.55, "#0f2a32");
    sky.addColorStop(1, "#16343c");
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, w, horizon);

    // Fluorescent strips
    ctx.globalAlpha = 0.35 + Math.sin(performance.now() / 400) * 0.05;
    ctx.fillStyle = "#5eead4";
    for (let i = 0; i < 5; i++) {
      const x = (w / 5) * i + (w / 10);
      ctx.fillRect(x - 18, 18, 36, 6);
      ctx.fillStyle = "rgba(94,234,212,0.15)";
      ctx.fillRect(x - 40, 24, 80, horizon - 30);
      ctx.fillStyle = "#5eead4";
    }
    ctx.globalAlpha = 1;

    // Mode 7 floor
    drawMode7(track, camera, horizon);

    // Project world sprites (far to near) — skip player (drawn fixed)
    const projected = [];
    let playerSprite = null;
    for (const s of sprites) {
      if (s.isPlayer) {
        playerSprite = s;
        continue;
      }
      const p = project(camera, s.x, s.y, horizon);
      if (p) projected.push({ ...p, kind: "kart", ref: s });
    }
    for (const hz of hazards) {
      const p = project(camera, hz.x, hz.y, horizon);
      if (p) projected.push({ ...p, kind: hz.type, ref: hz });
    }
    for (const pk of pickups) {
      if (!pk.alive) continue;
      const p = project(camera, pk.x, pk.y, horizon);
      if (p) projected.push({ ...p, kind: "pickup", ref: pk });
    }
    projected.sort((a, b) => a.depth - b.depth);

    for (const p of projected) {
      if (p.kind === "kart") drawCart(p);
      else if (p.kind === "banana") drawBanana(p);
      else if (p.kind === "oil") drawOil(p);
      else if (p.kind === "soup") drawSoup(p);
      else if (p.kind === "pickup") drawPickup(p);
    }

    // Player cart locked to bottom-center (Mario Kart feel)
    if (playerSprite) {
      const steerLean = (playerSprite._steerLean || 0) * 18;
      drawCart({
        x: w / 2 + steerLean,
        y: h * 0.72,
        scale: 2.1,
        depth: 0,
        ref: playerSprite,
      });
    }

    // Particles in screen space
    for (const pt of particles) {
      ctx.globalAlpha = Math.max(0, pt.life);
      ctx.fillStyle = pt.color;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    // Vignette
    const vig = ctx.createRadialGradient(w / 2, h * 0.55, h * 0.2, w / 2, h * 0.55, h * 0.75);
    vig.addColorStop(0, "rgba(0,0,0,0)");
    vig.addColorStop(1, "rgba(0,0,0,0.45)");
    ctx.fillStyle = vig;
    ctx.fillRect(0, 0, w, h);
  }

  function drawMode7(track, camera, horizon) {
    const camX = camera.x;
    const camY = camera.y;
    const angle = camera.angle;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    const fov = 0.65;
    const cameraHeight = 42;
    const floorH = h - horizon;
    // Render at half resolution for mobile framerate, then scale up
    const rw = (w / 2) | 0;
    const rh = (floorH / 2) | 0;
    const out = ctx.createImageData(rw, rh);
    const data = out.data;
    const map = track.imageData.data;
    const mapSize = track.size;
    const mapMask = mapSize - 1;

    for (let screenY = 0; screenY < rh; screenY++) {
      const row = screenY * 2 + 1;
      const distance = (cameraHeight / row) * 180;
      const halfWidth = Math.tan(fov) * distance;
      const rowY = camY + cos * distance;
      const rowX = camX - sin * distance;
      const startX = rowX - cos * halfWidth;
      const startY = rowY - sin * halfWidth;
      const dx = (cos * 2 * halfWidth) / rw;
      const dy = (sin * 2 * halfWidth) / rw;
      let sx = startX;
      let sy = startY;
      const base = screenY * rw * 4;
      const shade = Math.min(1, 0.45 + row / floorH);

      for (let screenX = 0; screenX < rw; screenX++) {
        const ix = sx & mapMask;
        const iy = sy & mapMask;
        // Clamp instead of wrap for store map edges
        const cx = sx < 0 ? 0 : sx >= mapSize ? mapMask : ix;
        const cy = sy < 0 ? 0 : sy >= mapSize ? mapMask : iy;
        const mi = (cy * mapSize + cx) * 4;
        const i = base + screenX * 4;
        data[i] = (map[mi] * shade) | 0;
        data[i + 1] = (map[mi + 1] * shade) | 0;
        data[i + 2] = (map[mi + 2] * shade) | 0;
        data[i + 3] = 255;
        sx += dx;
        sy += dy;
      }
    }

    // Blit scaled floor
    const tmp = drawMode7._tmp || (drawMode7._tmp = document.createElement("canvas"));
    tmp.width = rw;
    tmp.height = rh;
    tmp.getContext("2d").putImageData(out, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(tmp, 0, horizon, w, floorH);
  }

  function project(camera, x, y, horizon) {
    const dx = x - camera.x;
    const dy = y - camera.y;
    const cos = Math.cos(-camera.angle);
    const sin = Math.sin(-camera.angle);
    const rx = dx * cos - dy * sin;
    const ry = dx * sin + dy * cos;
    if (ry < 8) return null;
    const scale = 220 / ry;
    const screenX = w / 2 + rx * scale;
    const screenY = horizon + (42 * 180) / ry;
    if (screenY < horizon - 10 || screenY > h + 40) return null;
    if (screenX < -80 || screenX > w + 80) return null;
    return { x: screenX, y: screenY, scale, depth: ry };
  }

  function drawCart(p) {
    const s = Math.max(0.25, Math.min(2.8, p.scale * 0.9));
    const cart = p.ref;
    const bw = 46 * s;
    const bh = 30 * s;
    ctx.save();
    ctx.translate(p.x, p.y);

    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.4)";
    ctx.beginPath();
    ctx.ellipse(0, bh * 0.42, bw * 0.58, bh * 0.2, 0, 0, Math.PI * 2);
    ctx.fill();

    // Child seat / back panel
    ctx.fillStyle = cart.accent || "#333";
    roundRect(ctx, -bw * 0.38, -bh * 1.05, bw * 0.76, bh * 0.28, 3 * s);
    ctx.fill();

    // Basket body
    const grad = ctx.createLinearGradient(0, -bh, 0, bh * 0.2);
    grad.addColorStop(0, cart.color);
    grad.addColorStop(1, cart.accent || "#222");
    ctx.fillStyle = grad;
    ctx.strokeStyle = "rgba(255,255,255,0.35)";
    ctx.lineWidth = Math.max(1, 2 * s);
    roundRect(ctx, -bw / 2, -bh * 0.75, bw, bh * 0.85, 5 * s);
    ctx.fill();
    ctx.stroke();

    // Wire grid
    ctx.strokeStyle = "rgba(255,255,255,0.28)";
    ctx.lineWidth = Math.max(1, s);
    for (let i = 1; i < 5; i++) {
      const x = -bw / 2 + (bw * i) / 5;
      ctx.beginPath();
      ctx.moveTo(x, -bh * 0.65);
      ctx.lineTo(x, bh * 0.05);
      ctx.stroke();
    }
    for (let i = 1; i < 3; i++) {
      const y = -bh * 0.75 + (bh * 0.85 * i) / 3;
      ctx.beginPath();
      ctx.moveTo(-bw / 2 + 2, y);
      ctx.lineTo(bw / 2 - 2, y);
      ctx.stroke();
    }

    // Push handle (toward camera for player)
    ctx.strokeStyle = "#e8eef0";
    ctx.lineWidth = Math.max(2, 3.2 * s);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-bw * 0.32, -bh * 0.15);
    ctx.lineTo(-bw * 0.38, bh * 0.55);
    ctx.lineTo(bw * 0.38, bh * 0.55);
    ctx.lineTo(bw * 0.32, -bh * 0.15);
    ctx.stroke();

    // Wheels
    ctx.fillStyle = "#111";
    ctx.strokeStyle = "#5eead4";
    ctx.lineWidth = Math.max(1, s);
    for (const wx of [-bw * 0.3, bw * 0.3]) {
      ctx.beginPath();
      ctx.arc(wx, bh * 0.28, 6 * s, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }

    // Player marker
    if (cart.isPlayer) {
      ctx.fillStyle = "#ff8a3d";
      ctx.beginPath();
      ctx.moveTo(0, -bh * 1.45);
      ctx.lineTo(-7 * s, -bh * 1.15);
      ctx.lineTo(7 * s, -bh * 1.15);
      ctx.fill();
    }

    // Name tag for close carts
    if (s > 0.7 && cart.name) {
      ctx.fillStyle = "rgba(7,20,24,0.8)";
      ctx.font = `600 ${Math.max(10, 12 * Math.min(s, 1.4))}px DM Sans, sans-serif`;
      ctx.textAlign = "center";
      const label = cart.isPlayer ? "YOU" : cart.name;
      const tw = ctx.measureText(label).width + 12;
      const th = 16 * Math.max(0.9, Math.min(s, 1.2));
      roundRect(ctx, -tw / 2, -bh * 1.85, tw, th, 8);
      ctx.fill();
      ctx.fillStyle = cart.isPlayer ? "#ff8a3d" : "#f4efe6";
      ctx.fillText(label, 0, -bh * 1.85 + th * 0.72);
    }

    // Spinning overlay
    if (cart.spin > 0) {
      ctx.strokeStyle = "rgba(255,92,108,0.85)";
      ctx.lineWidth = 3 * s;
      ctx.beginPath();
      ctx.arc(0, -bh * 0.2, bw * 0.7, 0, Math.PI * 2 * Math.min(1, cart.spin / 1.2));
      ctx.stroke();
    }

    ctx.restore();
  }

  function drawBanana(p) {
    const s = Math.max(0.2, p.scale * 0.7);
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.fillStyle = "#f2d14b";
    ctx.beginPath();
    ctx.ellipse(0, 0, 10 * s, 5 * s, -0.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function drawOil(p) {
    const s = Math.max(0.2, p.scale * 0.9);
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.fillStyle = "rgba(20,20,20,0.7)";
    ctx.beginPath();
    ctx.ellipse(0, 0, 16 * s, 8 * s, 0.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function drawSoup(p) {
    const s = Math.max(0.2, p.scale * 0.7);
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.fillStyle = "#c45c26";
    ctx.fillRect(-6 * s, -6 * s, 12 * s, 12 * s);
    ctx.fillStyle = "#f4efe6";
    ctx.fillRect(-6 * s, -6 * s, 12 * s, 3 * s);
    ctx.restore();
  }

  function drawPickup(p) {
    const s = Math.max(0.25, p.scale * 0.85);
    const t = performance.now() / 200;
    ctx.save();
    ctx.translate(p.x, p.y - Math.sin(t) * 4);
    ctx.rotate(t * 0.4);
    ctx.fillStyle = "rgba(94,234,212,0.85)";
    ctx.strokeStyle = "#ff8a3d";
    ctx.lineWidth = 2 * s;
    ctx.beginPath();
    ctx.moveTo(0, -14 * s);
    ctx.lineTo(12 * s, 0);
    ctx.lineTo(0, 14 * s);
    ctx.lineTo(-12 * s, 0);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
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

  function screenShake(amount) {
    if (amount <= 0) return;
    const ox = (Math.random() - 0.5) * amount;
    const oy = (Math.random() - 0.5) * amount;
    ctx.setTransform(1, 0, 0, 1, ox, oy);
  }

  function resetTransform() {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
  }

  return { resize, draw, screenShake, resetTransform, get size() { return { w, h }; } };
}
