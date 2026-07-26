import { TRACK, pointOnPath } from "./track.js";

function drawFloor(ctx, cam) {
  const tile = 64;
  const startX = Math.floor((cam.x - cam.w / 2) / tile) * tile - tile;
  const startY = Math.floor((cam.y - cam.h / 2) / tile) * tile - tile;
  const endX = cam.x + cam.w / 2 + tile;
  const endY = cam.y + cam.h / 2 + tile;

  ctx.fillStyle = "#243628";
  ctx.fillRect(cam.x - cam.w / 2, cam.y - cam.h / 2, cam.w, cam.h);

  for (let y = startY; y < endY; y += tile) {
    for (let x = startX; x < endX; x += tile) {
      const shade = ((x / tile + y / tile) & 1) === 0 ? "#2c4032" : "#274032";
      ctx.fillStyle = shade;
      ctx.fillRect(x, y, tile - 1, tile - 1);
    }
  }

  // Wax sheen bands
  ctx.save();
  ctx.globalAlpha = 0.06;
  ctx.fillStyle = "#c8e06a";
  for (let i = 0; i < 8; i++) {
    ctx.fillRect(cam.x - cam.w / 2 + i * 180 + (cam.x * 0.02), cam.y - cam.h / 2, 40, cam.h);
  }
  ctx.restore();
}

function drawRoad(ctx) {
  const path = TRACK.path;
  ctx.save();
  ctx.lineJoin = "round";
  ctx.lineCap = "round";

  // Road asphalt / linoleum racing lane
  ctx.strokeStyle = "#3d5240";
  ctx.lineWidth = TRACK.roadHalf * 2 + 24;
  ctx.beginPath();
  ctx.moveTo(path[0].x, path[0].y);
  for (let i = 1; i < path.length; i++) ctx.lineTo(path[i].x, path[i].y);
  ctx.closePath();
  ctx.stroke();

  ctx.strokeStyle = "#4a6350";
  ctx.lineWidth = TRACK.roadHalf * 2;
  ctx.stroke();

  // Lane dashes
  ctx.setLineDash([28, 22]);
  ctx.strokeStyle = "rgba(240, 198, 70, 0.35)";
  ctx.lineWidth = 4;
  ctx.stroke();
  ctx.setLineDash([]);

  // Start/finish
  const a = pointOnPath(0);
  const nx = Math.cos(a.angle + Math.PI / 2);
  const ny = Math.sin(a.angle + Math.PI / 2);
  const hw = TRACK.roadHalf;
  ctx.save();
  for (let i = -4; i < 4; i++) {
    ctx.fillStyle = (i + 8) % 2 === 0 ? "#f4efe6" : "#0e1610";
    const x1 = a.x + nx * (i * (hw / 4));
    const y1 = a.y + ny * (i * (hw / 4));
    const x2 = a.x + nx * ((i + 1) * (hw / 4));
    const y2 = a.y + ny * ((i + 1) * (hw / 4));
    const bx = Math.cos(a.angle) * 10;
    const by = Math.sin(a.angle) * 10;
    ctx.beginPath();
    ctx.moveTo(x1 - bx, y1 - by);
    ctx.lineTo(x2 - bx, y2 - by);
    ctx.lineTo(x2 + bx, y2 + by);
    ctx.lineTo(x1 + bx, y1 + by);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
  ctx.restore();
}

function drawShelves(ctx) {
  for (const s of TRACK.shelves) {
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(s.x + 6, s.y + 8, s.w, s.h);

    const grad = ctx.createLinearGradient(s.x, s.y, s.x, s.y + s.h);
    grad.addColorStop(0, "#6b4a32");
    grad.addColorStop(0.5, "#8a5e3b");
    grad.addColorStop(1, "#5a3c28");
    ctx.fillStyle = grad;
    ctx.fillRect(s.x, s.y, s.w, s.h);

    // Shelf lips
    ctx.fillStyle = "rgba(255,255,255,0.12)";
    ctx.fillRect(s.x, s.y, s.w, 6);
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.fillRect(s.x, s.y + s.h - 8, s.w, 8);

    // Product dots
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = `hsl(${(i * 47 + s.x) % 360} 55% 55%)`;
      const px = s.x + 16 + (i % 3) * ((s.w - 32) / 3);
      const py = s.y + 18 + Math.floor(i / 3) * (s.h * 0.35);
      ctx.fillRect(px, py, Math.min(36, s.w / 4), 14);
    }

    if (s.label) {
      ctx.fillStyle = "rgba(244,239,230,0.75)";
      ctx.font = "700 11px Outfit, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(s.label, s.x + s.w / 2, s.y + s.h / 2 + 4);
    }
  }

  for (const w of TRACK.walls) {
    ctx.fillStyle = "#1a221c";
    ctx.fillRect(w.x, w.y, w.w, w.h);
    ctx.fillStyle = "rgba(200,224,106,0.08)";
    ctx.fillRect(w.x, w.y, w.w, 4);
  }
}

function drawLights(ctx, cam, t) {
  ctx.save();
  ctx.globalAlpha = 0.07 + Math.sin(t * 2) * 0.01;
  for (let i = 0; i < 5; i++) {
    const x = 300 + i * 420;
    if (x < cam.x - cam.w / 2 - 100 || x > cam.x + cam.w / 2 + 100) continue;
    const g = ctx.createRadialGradient(x, cam.y, 10, x, cam.y, 280);
    g.addColorStop(0, "#f0c646");
    g.addColorStop(1, "transparent");
    ctx.fillStyle = g;
    ctx.fillRect(x - 280, cam.y - 280, 560, 560);
  }
  ctx.restore();
}

export function drawCart(ctx, cart, t) {
  ctx.save();
  ctx.translate(cart.x, cart.y);
  ctx.rotate(cart.angle);

  // Shadow
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.beginPath();
  ctx.ellipse(4, 10, 28, 14, 0, 0, Math.PI * 2);
  ctx.fill();

  if (cart.shieldTimer > 0) {
    ctx.strokeStyle = `rgba(200,224,106,${0.4 + Math.sin(t * 10) * 0.25})`;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(0, 0, 36, 0, Math.PI * 2);
    ctx.stroke();
  }

  if (cart.boostTimer > 0) {
    ctx.fillStyle = `rgba(255,107,44,${0.35 + Math.sin(t * 20) * 0.2})`;
    ctx.beginPath();
    ctx.moveTo(-34, -10);
    ctx.lineTo(-54 - Math.random() * 10, 0);
    ctx.lineTo(-34, 10);
    ctx.closePath();
    ctx.fill();
  }

  // Basket
  const body = ctx.createLinearGradient(-24, -16, 24, 16);
  body.addColorStop(0, cart.color);
  body.addColorStop(1, cart.accent);
  ctx.fillStyle = body;
  ctx.strokeStyle = "rgba(0,0,0,0.35)";
  ctx.lineWidth = 2;
  roundRect(ctx, -26, -16, 48, 32, 4);
  ctx.fill();
  ctx.stroke();

  // Wire grid
  ctx.strokeStyle = "rgba(0,0,0,0.22)";
  ctx.lineWidth = 1;
  for (let i = -18; i <= 18; i += 9) {
    ctx.beginPath();
    ctx.moveTo(i, -14);
    ctx.lineTo(i, 14);
    ctx.stroke();
  }
  ctx.beginPath();
  ctx.moveTo(-22, 0);
  ctx.lineTo(20, 0);
  ctx.stroke();

  // Handle
  ctx.strokeStyle = cart.accent;
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(-28, -12);
  ctx.lineTo(-36, -18);
  ctx.lineTo(-36, 18);
  ctx.lineTo(-28, 12);
  ctx.stroke();

  // Wheels
  const spin = cart.wheelPhase + cart.speed * 0.08;
  ctx.fillStyle = "#1a1a1a";
  wheel(ctx, 16, -14, spin);
  wheel(ctx, 16, 14, spin);
  wheel(ctx, -14, -14, spin * 0.9);
  wheel(ctx, -14, 14, spin * 0.9);

  // Nose badge
  ctx.fillStyle = "#0e1610";
  ctx.beginPath();
  ctx.arc(20, 0, 5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = cart.isPlayer ? "#ff6b2c" : "#c8e06a";
  ctx.beginPath();
  ctx.arc(20, 0, 3, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();

  // Name tag
  ctx.save();
  ctx.font = "700 11px Outfit, sans-serif";
  ctx.textAlign = "center";
  ctx.fillStyle = "rgba(14,22,16,0.65)";
  const label = cart.isPlayer ? "YOU" : cart.name;
  const tw = ctx.measureText(label).width + 10;
  ctx.fillRect(cart.x - tw / 2, cart.y - 42, tw, 16);
  ctx.fillStyle = cart.isPlayer ? "#ff6b2c" : "#f4efe6";
  ctx.fillText(label, cart.x, cart.y - 30);
  ctx.restore();
}

function wheel(ctx, x, y, spin) {
  ctx.beginPath();
  ctx.arc(x, y, 5, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#888";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x + Math.cos(spin) * 4, y + Math.sin(spin) * 4);
  ctx.lineTo(x - Math.cos(spin) * 4, y - Math.sin(spin) * 4);
  ctx.stroke();
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

export function drawPickups(ctx, pickups, t) {
  for (const p of pickups) {
    if (!p.alive) continue;
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(t * 2 + p.spin);
    ctx.fillStyle = "rgba(255,107,44,0.25)";
    ctx.beginPath();
    ctx.arc(0, 0, 26 + Math.sin(t * 5 + p.spin) * 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ff6b2c";
    ctx.beginPath();
    ctx.moveTo(0, -16);
    ctx.lineTo(14, 0);
    ctx.lineTo(0, 16);
    ctx.lineTo(-14, 0);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#f4efe6";
    ctx.font = "700 14px Bebas Neue, sans-serif";
    ctx.textAlign = "center";
    ctx.rotate(-(t * 2 + p.spin));
    ctx.fillText("?", 0, 5);
    ctx.restore();
  }
}

export function drawHazards(ctx, hazards) {
  for (const h of hazards) {
    ctx.save();
    ctx.translate(h.x, h.y);
    if (h.type === "banana") {
      ctx.rotate(h.angle);
      ctx.fillStyle = "#f0c646";
      ctx.beginPath();
      ctx.ellipse(0, 0, 14, 7, 0.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#c49212";
      ctx.stroke();
    } else if (h.type === "milk") {
      ctx.fillStyle = "rgba(244,239,230,0.55)";
      ctx.beginPath();
      ctx.ellipse(0, 0, h.r, h.r * 0.7, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(200,224,106,0.4)";
      ctx.stroke();
    }
    ctx.restore();
  }
}

export function drawProjectiles(ctx, shots) {
  for (const s of shots) {
    ctx.fillStyle = "#c45c3a";
    ctx.beginPath();
    ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f4efe6";
    ctx.font = "10px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("SOUP", s.x, s.y + 3);
  }
}

export function renderWorld(ctx, state, cam) {
  ctx.save();
  ctx.setTransform(cam.scale, 0, 0, cam.scale, cam.screenW / 2 - cam.x * cam.scale, cam.screenH / 2 - cam.y * cam.scale);

  drawFloor(ctx, {
    x: cam.x,
    y: cam.y,
    w: cam.screenW / cam.scale,
    h: cam.screenH / cam.scale,
  });
  drawRoad(ctx);
  drawShelves(ctx);
  drawHazards(ctx, state.hazards);
  drawPickups(ctx, state.pickups, state.time);
  drawProjectiles(ctx, state.shots);

  const sorted = [...state.carts].sort((a, b) => a.y - b.y);
  for (const c of sorted) drawCart(ctx, c, state.time);

  drawLights(ctx, cam, state.time);
  ctx.restore();
}

export function renderMinimap(mctx, state) {
  const w = mctx.canvas.width;
  const h = mctx.canvas.height;
  mctx.clearRect(0, 0, w, h);
  mctx.fillStyle = "rgba(14,22,16,0.9)";
  mctx.fillRect(0, 0, w, h);

  const sx = w / TRACK.width;
  const sy = h / TRACK.height;

  mctx.strokeStyle = "#4a6350";
  mctx.lineWidth = 6;
  mctx.beginPath();
  mctx.moveTo(TRACK.path[0].x * sx, TRACK.path[0].y * sy);
  for (let i = 1; i < TRACK.path.length; i++) {
    mctx.lineTo(TRACK.path[i].x * sx, TRACK.path[i].y * sy);
  }
  mctx.closePath();
  mctx.stroke();

  for (const s of TRACK.shelves) {
    mctx.fillStyle = "#6b4a32";
    mctx.fillRect(s.x * sx, s.y * sy, s.w * sx, s.h * sy);
  }

  for (const c of state.carts) {
    mctx.fillStyle = c.isPlayer ? "#ff6b2c" : c.color;
    mctx.beginPath();
    mctx.arc(c.x * sx, c.y * sy, c.isPlayer ? 3.5 : 2.5, 0, Math.PI * 2);
    mctx.fill();
  }
}
