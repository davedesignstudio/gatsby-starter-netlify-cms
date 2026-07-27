export function drawTrack(ctx, track, cam) {
  ctx.save();
  ctx.translate(cam.x, cam.y);
  ctx.scale(cam.zoom, cam.zoom);

  if (track.dark) {
    ctx.fillStyle = '#0a0c12';
    ctx.fillRect(track.outer.x - 100, track.outer.y - 100, track.outer.w + 200, track.outer.h + 200);
  }

  roundRect(ctx, track.outer.x, track.outer.y, track.outer.w, track.outer.h, 12);
  ctx.fillStyle = track.floor;
  ctx.fill();
  ctx.strokeStyle = track.dark ? '#3a4050' : '#8a8278';
  ctx.lineWidth = 6;
  ctx.stroke();

  roundRect(ctx, track.inner.x, track.inner.y, track.inner.w, track.inner.h, 10);
  ctx.fillStyle = track.island;
  ctx.fill();
  ctx.strokeStyle = track.dark ? '#2a3040' : '#736a60';
  ctx.lineWidth = 4;
  ctx.stroke();

  drawLabel(ctx, track.islandLabel, track.inner.x + track.inner.w / 2, track.inner.y + track.inner.h / 2, 28, track.dark ? 'rgba(255,255,255,0.2)' : 'rgba(255,255,255,0.25)');

  track.shelves.forEach((s, i) => {
    roundRect(ctx, s.x, s.y, s.w, s.h, 4);
    ctx.fillStyle = track.shelf;
    ctx.fill();
    ctx.strokeStyle = '#222';
    ctx.lineWidth = 2;
    ctx.stroke();
    drawLabel(ctx, track.shelfLabels[i % track.shelfLabels.length], s.x + s.w / 2, s.y + s.h / 2, 11, 'rgba(255,255,255,0.75)');
  });

  if (track.dark) {
    track.items.forEach((p) => {
      ctx.beginPath();
      ctx.arc(p.x, p.y, 60, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255,240,200,0.05)';
      ctx.fill();
    });
  }

  ctx.restore();
}

export function drawItemBoxes(ctx, boxes, cam, pulse) {
  ctx.save();
  ctx.translate(cam.x, cam.y);
  ctx.scale(cam.zoom, cam.zoom);
  for (const box of boxes) {
    const s = 18 + Math.sin(pulse * 4) * 2;
    roundRect(ctx, box.x - s, box.y - s, s * 2, s * 2, 6);
    ctx.fillStyle = 'rgba(242,140,26,0.9)';
    ctx.fill();
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 18px Avenir, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('?', box.x, box.y);
  }
  ctx.restore();
}

export function drawHazards(ctx, hazards, cam) {
  ctx.save();
  ctx.translate(cam.x, cam.y);
  ctx.scale(cam.zoom, cam.zoom);
  for (const h of hazards) {
    if (h.type === 'banana') {
      ctx.font = '28px serif';
      ctx.textAlign = 'center';
      ctx.fillText('🍌', h.x, h.y);
    } else if (h.type === 'milk') {
      ctx.beginPath();
      ctx.arc(h.x, h.y, h.r, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255,255,255,0.55)';
      ctx.fill();
    } else if (h.type === 'cans') {
      ctx.font = '20px serif';
      ctx.textAlign = 'center';
      ctx.fillText('🥫🥫🥫', h.x, h.y);
    }
  }
  ctx.restore();
}

export function drawRacer(ctx, racer, cam) {
  ctx.save();
  ctx.translate(cam.x, cam.y);
  ctx.scale(cam.zoom, cam.zoom);
  ctx.translate(racer.x, racer.y);
  ctx.rotate(racer.angle);

  ctx.fillStyle = 'rgba(0,0,0,0.25)';
  ctx.beginPath();
  ctx.ellipse(0, 18, 27, 14, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.rotate(racer.wobble);
  ctx.fillStyle = racer.cart;
  roundRect(ctx, -22, -8, 44, 34, 6);
  ctx.fill();
  ctx.strokeStyle = '#444';
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = racer.body;
  roundRect(ctx, -11, 0, 22, 30, 8);
  ctx.fill();

  ctx.fillStyle = '#f2c79e';
  ctx.beginPath();
  ctx.arc(0, 24, 10, 0, Math.PI * 2);
  ctx.fill();

  const wheels = [[-18, -18], [18, -18], [-18, 2], [18, 2]];
  wheels.forEach(([wx, wy]) => {
    ctx.fillStyle = '#333';
    ctx.beginPath();
    ctx.arc(wx, wy, 7, 0, Math.PI * 2);
    ctx.fill();
  });

  if (racer.isPlayer) {
    ctx.fillStyle = racer.slot === 0 ? '#ff0' : '#0ff';
    ctx.font = 'bold 10px Avenir, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(racer.slot === 0 ? 'P1' : 'P2', 0, -28);
  }
  ctx.restore();
  ctx.restore();
}

export function drawHUD(ctx, w, h, state) {
  ctx.fillStyle = 'rgba(0,0,0,0.35)';
  ctx.fillRect(0, 0, w, 56);
  ctx.fillStyle = '#fff';
  ctx.font = '600 16px Avenir, system-ui, sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(`Lap ${Math.min(state.player.lap + 1, 3)}/3`, 16, 34);
  ctx.textAlign = 'center';
  ctx.fillText(formatTime(state.raceTime), w / 2, 34);
  ctx.textAlign = 'right';
  ctx.font = '700 22px Avenir, system-ui, sans-serif';
  ctx.fillText(ordinal(state.player.position), w - 16, 36);
  ctx.font = '500 13px Avenir, system-ui, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(state.player.item ? `Item: ${state.player.item.icon} ${state.player.item.name}` : 'Item: None', w / 2, 52);

  if (state.countdown > 0) {
    ctx.fillStyle = 'rgba(0,0,0,0.45)';
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = state.countdown === 'GO!' ? '#4ade80' : '#ffd033';
    ctx.font = '800 96px Avenir, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(String(state.countdown), w / 2, h / 2);
  }
}

export function drawTouchControls(ctx, w, h, input) {
  const joy = { x: 80, y: h - 100, r: 52 };
  const go = { x: w - 70, y: h - 100, r: 38 };
  const drift = { x: w - 150, y: h - 55, r: 34 };
  const item = { x: w - 70, y: h - 175, r: 34 };

  input.setTouchRects({
    joystick: { ...joy, cx: joy.x, cy: joy.y, w: joy.r * 2, h: joy.r * 2, x: joy.x - joy.r, y: joy.y - joy.r },
    go: { x: go.x - go.r, y: go.y - go.r, w: go.r * 2, h: go.r * 2 },
    drift: { x: drift.x - drift.r, y: drift.y - drift.r, w: drift.r * 2, h: drift.r * 2 },
    item: { x: item.x - item.r, y: item.y - item.r, w: item.r * 2, h: item.r * 2 },
  });

  drawButton(ctx, joy.x, joy.y, joy.r, 'rgba(255,255,255,0.12)', input.joystick.active ? input.joystick.x * 24 : 0, input.joystick.active ? -input.joystick.y * 24 : 0);
  drawButton(ctx, go.x, go.y, go.r, 'rgba(51,204,89,0.35)', 0, 0, 'GO', input.buttons.go);
  drawButton(ctx, drift.x, drift.y, drift.r, 'rgba(242,140,26,0.35)', 0, 0, 'DRIFT', input.buttons.drift);
  drawButton(ctx, item.x, item.y, item.r, 'rgba(140,89,242,0.35)', 0, 0, 'ITEM', input.buttons.item);
}

function drawButton(ctx, x, y, r, color, ox, oy, label = '', pressed = false) {
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fillStyle = color;
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,0.5)';
  ctx.lineWidth = 2;
  ctx.stroke();
  if (label) {
    ctx.fillStyle = '#fff';
    ctx.font = `bold ${r > 36 ? 14 : 11}px Avenir, sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.globalAlpha = pressed ? 0.7 : 1;
    ctx.fillText(label, x, y);
    ctx.globalAlpha = 1;
  }
  if (ox || oy) {
    ctx.beginPath();
    ctx.arc(x + ox, y + oy, r * 0.45, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
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

function drawLabel(ctx, text, x, y, size, color) {
  ctx.fillStyle = color;
  ctx.font = `700 ${size}px Avenir, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, x, y);
}

function ordinal(n) {
  const s = ['th', 'st', 'nd', 'rd'];
  const v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]);
}

export function formatTime(t) {
  const m = Math.floor(t / 60);
  const s = Math.floor(t % 60);
  const d = Math.floor((t * 10) % 10);
  return `${m}:${String(s).padStart(2, '0')}.${d}`;
}
