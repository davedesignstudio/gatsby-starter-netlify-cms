/** Procedural supermarket oval track + collision helpers. */

const MAP_SIZE = 1024;

export function createTrack() {
  const canvas = document.createElement("canvas");
  canvas.width = MAP_SIZE;
  canvas.height = MAP_SIZE;
  const ctx = canvas.getContext("2d");

  const cx = MAP_SIZE / 2;
  const cy = MAP_SIZE / 2;
  const rxOut = 360;
  const ryOut = 250;
  const rxIn = 200;
  const ryIn = 110;

  // Store floor outside the track (shelves / dark linoleum)
  ctx.fillStyle = "#14262c";
  ctx.fillRect(0, 0, MAP_SIZE, MAP_SIZE);

  // Outer shelf blocks
  paintShelves(ctx);

  // Road band via pixel walk for crisp ellipse ring
  const imageData = ctx.getImageData(0, 0, MAP_SIZE, MAP_SIZE);
  const data = imageData.data;
  const roadMask = new Uint8Array(MAP_SIZE * MAP_SIZE);

  for (let y = 0; y < MAP_SIZE; y++) {
    for (let x = 0; x < MAP_SIZE; x++) {
      const nx = (x - cx) / rxOut;
      const ny = (y - cy) / ryOut;
      const outside = nx * nx + ny * ny;
      const nix = (x - cx) / rxIn;
      const niy = (y - cy) / ryIn;
      const inside = nix * nix + niy * niy;
      const onRoad = outside <= 1 && inside >= 1;
      const i = (y * MAP_SIZE + x) * 4;
      if (onRoad) {
        roadMask[y * MAP_SIZE + x] = 1;
        const tile = ((x >> 5) + (y >> 5)) & 1;
        const base = tile ? 52 : 44;
        // Aisle glow near centerline
        const mid =
          Math.abs(outside - (inside + outside) * 0.35) < 0.08 ? 18 : 0;
        data[i] = base + mid + 8;
        data[i + 1] = base + 18 + mid;
        data[i + 2] = base + 24 + mid;
        data[i + 3] = 255;
      }
    }
  }
  ctx.putImageData(imageData, 0, 0);

  // Center produce island fill
  ctx.fillStyle = "#245338";
  ctx.beginPath();
  ctx.ellipse(cx, cy, rxIn - 8, ryIn - 8, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "rgba(155, 225, 93, 0.2)";
  for (let i = 0; i < 18; i++) {
    const a = (i / 18) * Math.PI * 2;
    ctx.beginPath();
    ctx.arc(cx + Math.cos(a) * 90, cy + Math.sin(a) * 50, 10, 0, Math.PI * 2);
    ctx.fill();
  }

  // Lane dashes
  ctx.strokeStyle = "rgba(255, 198, 92, 0.45)";
  ctx.lineWidth = 5;
  ctx.setLineDash([30, 24]);
  ctx.beginPath();
  ctx.ellipse(cx, cy, 280, 180, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);

  // Start/finish
  for (let i = 0; i < 14; i++) {
    ctx.fillStyle = i % 2 === 0 ? "#f4efe6" : "#111418";
    ctx.fillRect(400 + i * 16, 818, 16, 58);
  }

  // Signage
  ctx.font = "bold 26px sans-serif";
  ctx.fillStyle = "rgba(255, 138, 61, 0.75)";
  ctx.fillText("FREEZER", 90, 95);
  ctx.fillText("PRODUCE", 760, 120);
  ctx.fillStyle = "rgba(94, 234, 212, 0.7)";
  ctx.fillText("CHECKOUT", 430, 990);
  ctx.fillText("SOUP", 55, 520);

  // Price tag stickers on shelves
  ctx.fillStyle = "#ff8a3d";
  for (let i = 0; i < 10; i++) {
    ctx.fillRect(100 + i * 80, 55, 22, 14);
    ctx.fillRect(100 + i * 80, MAP_SIZE - 70, 22, 14);
  }

  const finalImage = ctx.getImageData(0, 0, MAP_SIZE, MAP_SIZE);
  const waypoints = buildWaypoints(cx, cy, 280, 180);
  const itemSpawns = waypoints
    .filter((_, i) => i % 4 === 1)
    .map((p) => ({ x: p.x, y: p.y, cooldown: 0, alive: true }));

  return {
    size: MAP_SIZE,
    canvas,
    imageData: finalImage,
    roadMask,
    waypoints,
    itemSpawns,
    start: { x: 512, y: 860, angle: -Math.PI / 2 },
  };
}

function paintShelves(ctx) {
  // Outer wall shelves
  const g = ctx.createLinearGradient(0, 0, 0, 100);
  g.addColorStop(0, "#6a3b28");
  g.addColorStop(1, "#4a2618");
  ctx.fillStyle = g;
  ctx.fillRect(20, 20, MAP_SIZE - 40, 64);
  ctx.fillRect(20, MAP_SIZE - 84, MAP_SIZE - 40, 64);
  ctx.fillRect(20, 20, 64, MAP_SIZE - 40);
  ctx.fillRect(MAP_SIZE - 84, 20, 64, MAP_SIZE - 40);

  // Shelf face details
  ctx.fillStyle = "rgba(0,0,0,0.22)";
  for (let i = 0; i < 16; i++) {
    ctx.fillRect(30 + i * 60, 28, 8, 48);
    ctx.fillRect(30 + i * 60, MAP_SIZE - 76, 8, 48);
  }
}

function buildWaypoints(cx, cy, rx, ry) {
  const pts = [];
  const count = 48;
  for (let i = 0; i < count; i++) {
    const a = -Math.PI / 2 + (i / count) * Math.PI * 2;
    pts.push({
      x: cx + Math.cos(a) * rx,
      y: cy + Math.sin(a) * ry,
      angle: a + Math.PI / 2,
    });
  }
  return pts;
}

export function isOnRoad(track, x, y) {
  const ix = x | 0;
  const iy = y | 0;
  if (ix < 0 || iy < 0 || ix >= track.size || iy >= track.size) return false;
  return track.roadMask[iy * track.size + ix] === 1;
}

export function sampleTrackColor(track, x, y) {
  const ix = Math.max(0, Math.min(track.size - 1, x | 0));
  const iy = Math.max(0, Math.min(track.size - 1, y | 0));
  const i = (iy * track.size + ix) * 4;
  const d = track.imageData.data;
  return [d[i], d[i + 1], d[i + 2]];
}

export function progressAlongTrack(track, x, y, currentIndex) {
  let best = currentIndex;
  let bestDist = Infinity;
  const n = track.waypoints.length;
  for (let k = -2; k < 10; k++) {
    const i = (currentIndex + k + n) % n;
    const p = track.waypoints[i];
    const dx = p.x - x;
    const dy = p.y - y;
    const d = dx * dx + dy * dy;
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

export function raceDistance(track, kart) {
  return kart.laps * track.waypoints.length + kart.wp + kart.lapFraction;
}
