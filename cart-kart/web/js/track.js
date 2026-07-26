/* Cart Kart — the "Midnight Megamart" circuit: floor texture, waypoints,
   surface lookup, item boxes, hazards, wall decorations, minimap */
"use strict";

CK.track = (function () {
  var WORLD = 2048;          /* world units, square */
  var TEX = 1024;            /* texture px (1 texel = 2 world units) */
  var HALF_W = 70;           /* racing lane half-width */
  var WALL_D = 98;           /* hard wall distance from centerline */
  var N_WP = 600;            /* sampled waypoints */

  var CONTROL = [
    { x: 420, y: 1760 }, { x: 900, y: 1800 }, { x: 1380, y: 1760 },
    { x: 1720, y: 1560 }, { x: 1780, y: 1220 }, { x: 1560, y: 1000 },
    { x: 1280, y: 940 }, { x: 1240, y: 700 }, { x: 1460, y: 520 },
    { x: 1700, y: 380 }, { x: 1560, y: 180 }, { x: 1160, y: 200 },
    { x: 820, y: 320 }, { x: 520, y: 220 }, { x: 260, y: 380 },
    { x: 240, y: 700 }, { x: 480, y: 860 }, { x: 560, y: 1080 },
    { x: 340, y: 1240 }, { x: 240, y: 1520 }
  ];

  var waypoints = [];        /* {x,y,dx,dy} unit direction */
  var texU32 = null;         /* Uint32 view of floor texture RGBA */
  var voidColor = 0;

  /* nearest-waypoint coarse grid */
  var GRID = 128;
  var CELL = WORLD / GRID;
  var gridIdx = new Uint16Array(GRID * GRID);
  var gridDist = new Float32Array(GRID * GRID);

  var itemBoxSpots = [];     /* {x,y} */
  var hazards = [];          /* slick circles {x,y,r} */
  var solids = [];           /* collidable props {x,y,r} */
  var decor = [];            /* {x,y,img,w,h} world-size sprites */
  var minimap = null;

  /* ---------------- geometry ---------------- */

  function buildWaypoints() {
    for (var i = 0; i < N_WP; i++) {
      var p = CK.catmullRom(CONTROL, i / N_WP);
      waypoints.push({ x: p.x, y: p.y, dx: 0, dy: 0 });
    }
    for (i = 0; i < N_WP; i++) {
      var a = waypoints[i];
      var b = waypoints[(i + 1) % N_WP];
      var dx = b.x - a.x, dy = b.y - a.y;
      var l = Math.hypot(dx, dy) || 1;
      a.dx = dx / l; a.dy = dy / l;
    }
  }

  function wp(i) {
    return waypoints[((i % N_WP) + N_WP) % N_WP];
  }

  /* lateral offset point: +off is to the right of travel direction */
  function lateral(i, off) {
    var w = wp(i);
    return { x: w.x - w.dy * off, y: w.y + w.dx * off };
  }

  function buildGrid() {
    gridDist.fill(1e9);
    for (var i = 0; i < N_WP; i++) {
      var w = waypoints[i];
      var cx = Math.floor(w.x / CELL), cy = Math.floor(w.y / CELL);
      var R = Math.ceil(200 / CELL);
      for (var gy = Math.max(0, cy - R); gy <= Math.min(GRID - 1, cy + R); gy++) {
        for (var gx = Math.max(0, cx - R); gx <= Math.min(GRID - 1, cx + R); gx++) {
          var px = gx * CELL + CELL / 2, py = gy * CELL + CELL / 2;
          var d = CK.dist2(px, py, w.x, w.y);
          var gi = gy * GRID + gx;
          if (d < gridDist[gi]) { gridDist[gi] = d; gridIdx[gi] = i; }
        }
      }
    }
  }

  /* precise surface info: perpendicular distance + continuous progress */
  function surfaceAt(x, y) {
    var gx = CK.clamp(Math.floor(x / CELL), 0, GRID - 1);
    var gy = CK.clamp(Math.floor(y / CELL), 0, GRID - 1);
    var seed = gridIdx[gy * GRID + gx];
    if (gridDist[gy * GRID + gx] > 1e8) {
      return { dist: 9999, prog: 0, slick: false };
    }
    var best = seed, bestD = 1e18;
    for (var o = -10; o <= 10; o++) {
      var i = ((seed + o) % N_WP + N_WP) % N_WP;
      var w = waypoints[i];
      var d = CK.dist2(x, y, w.x, w.y);
      if (d < bestD) { bestD = d; best = i; }
    }
    /* project onto segment best -> best+1 for smooth progress */
    var a = waypoints[best], b = wp(best + 1);
    var abx = b.x - a.x, aby = b.y - a.y;
    var ab2 = abx * abx + aby * aby || 1;
    var t = CK.clamp(((x - a.x) * abx + (y - a.y) * aby) / ab2, 0, 1);
    var px = a.x + abx * t, py = a.y + aby * t;
    var dist = Math.hypot(x - px, y - py);

    var slick = false;
    for (var h = 0; h < hazards.length; h++) {
      if (CK.dist2(x, y, hazards[h].x, hazards[h].y) < hazards[h].r * hazards[h].r) {
        slick = true; break;
      }
    }
    return { dist: dist, prog: best + t, slick: slick };
  }

  /* pull a point back inside the shelving corridor; returns null if inside */
  function clampToCorridor(x, y, maxDist) {
    var surf = surfaceAt(x, y);
    if (surf.dist <= maxDist) { return null; }
    var a = waypoints[Math.floor(surf.prog) % N_WP];
    var b = wp(Math.floor(surf.prog) + 1);
    var abx = b.x - a.x, aby = b.y - a.y;
    var ab2 = abx * abx + aby * aby || 1;
    var t = CK.clamp(((x - a.x) * abx + (y - a.y) * aby) / ab2, 0, 1);
    var cxp = a.x + abx * t, cyp = a.y + aby * t;
    var nx = (x - cxp) / surf.dist, ny = (y - cyp) / surf.dist;
    return {
      x: cxp + nx * maxDist,
      y: cyp + ny * maxDist,
      wallDir: Math.atan2(aby, abx)
    };
  }

  /* ---------------- floor texture ---------------- */

  function paintTexture() {
    var c = document.createElement("canvas");
    c.width = TEX; c.height = TEX;
    var g = c.getContext("2d");
    g.save();
    g.scale(TEX / WORLD, TEX / WORLD);

    /* base tiles */
    var tile = 64;
    for (var ty = 0; ty < WORLD / tile; ty++) {
      for (var tx = 0; tx < WORLD / tile; tx++) {
        g.fillStyle = (tx + ty) % 2 ? "#ded7c4" : "#d4cdba";
        g.fillRect(tx * tile, ty * tile, tile, tile);
      }
    }
    /* grout lines */
    g.strokeStyle = "rgba(150,142,125,0.5)";
    g.lineWidth = 2;
    g.beginPath();
    for (var l = 0; l <= WORLD; l += tile) {
      g.moveTo(l, 0); g.lineTo(l, WORLD);
      g.moveTo(0, l); g.lineTo(WORLD, l);
    }
    g.stroke();

    /* department tint zones */
    function zone(x, y, r, col) {
      var gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, col);
      gr.addColorStop(1, "rgba(0,0,0,0)");
      g.fillStyle = gr;
      g.fillRect(x - r, y - r, r * 2, r * 2);
    }
    zone(360, 320, 500, "rgba(90,160,90,0.14)");     /* produce */
    zone(1650, 350, 480, "rgba(90,140,200,0.14)");   /* frozen */
    zone(1600, 1500, 500, "rgba(200,150,80,0.12)");  /* bakery */
    zone(400, 1500, 450, "rgba(180,100,160,0.10)");  /* candy */

    /* track path helper */
    function tracePath(off) {
      g.beginPath();
      for (var i = 0; i <= N_WP; i++) {
        var p = off ? lateral(i % N_WP, off) : wp(i % N_WP);
        if (i === 0) { g.moveTo(p.x, p.y); } else { g.lineTo(p.x, p.y); }
      }
      g.closePath();
    }

    /* waxed racing lane */
    g.lineJoin = "round"; g.lineCap = "round";
    tracePath(0);
    g.strokeStyle = "#b9c0b4";
    g.lineWidth = HALF_W * 2 + 10;
    g.stroke();
    tracePath(0);
    g.strokeStyle = "#c2c9bd";
    g.lineWidth = HALF_W * 2 - 14;
    g.stroke();
    /* subtle tile seams on the lane */
    g.setLineDash([4, 60]);
    tracePath(0);
    g.strokeStyle = "rgba(130,138,128,0.5)";
    g.lineWidth = HALF_W * 2 - 14;
    g.stroke();
    g.setLineDash([]);

    /* yellow floor-tape edges */
    g.setLineDash([26, 18]);
    g.strokeStyle = "#e5c435";
    g.lineWidth = 6;
    tracePath(HALF_W - 6);
    g.stroke();
    tracePath(-(HALF_W - 6));
    g.stroke();
    g.setLineDash([]);

    /* direction chevrons */
    g.fillStyle = "rgba(255,255,255,0.75)";
    for (var ci = 10; ci < N_WP; ci += 30) {
      var w = wp(ci);
      g.save();
      g.translate(w.x, w.y);
      g.rotate(Math.atan2(w.dy, w.dx));
      g.beginPath();
      g.moveTo(10, 0); g.lineTo(-6, -12); g.lineTo(-1, 0); g.lineTo(-6, 12);
      g.closePath(); g.fill();
      g.restore();
    }

    /* start / finish checker band (waypoint 0) */
    var s0 = wp(0);
    g.save();
    g.translate(s0.x, s0.y);
    g.rotate(Math.atan2(s0.dy, s0.dx));
    var sq = 14;
    for (var r = 0; r < 2; r++) {
      for (var q = -5; q < 5; q++) {
        g.fillStyle = (r + q) % 2 ? "#1c1c22" : "#f2f2ee";
        g.fillRect(r * sq - sq, q * sq, sq, sq);
      }
    }
    g.restore();

    /* floor decals */
    g.save();
    var d1 = wp(30);
    g.translate(d1.x, d1.y);
    g.rotate(Math.atan2(d1.dy, d1.dx));
    g.fillStyle = "rgba(60,80,140,0.4)";
    g.font = "bold 42px Arial";
    g.textAlign = "center";
    g.fillText("AISLE 9", 0, 12);
    g.restore();

    g.save();
    var d2 = wp(300);
    g.translate(d2.x, d2.y);
    g.rotate(Math.atan2(d2.dy, d2.dx));
    g.fillStyle = "rgba(140,60,60,0.35)";
    g.font = "bold 36px Arial";
    g.textAlign = "center";
    g.fillText("CLEARANCE", 0, 12);
    g.restore();

    /* slick puddles baked in (physics circles added in buildFeatures) */
    for (var hz = 0; hz < hazards.length; hz++) {
      var H = hazards[hz];
      var shine = g.createRadialGradient(H.x, H.y, 0, H.x, H.y, H.r);
      shine.addColorStop(0, "rgba(235,240,255,0.85)");
      shine.addColorStop(0.7, "rgba(200,215,240,0.55)");
      shine.addColorStop(1, "rgba(200,215,240,0)");
      g.fillStyle = shine;
      g.beginPath(); g.arc(H.x, H.y, H.r, 0, CK.TAU); g.fill();
      g.fillStyle = "rgba(255,255,255,0.7)";
      g.beginPath();
      g.ellipse(H.x - H.r * 0.25, H.y - H.r * 0.2, H.r * 0.35, H.r * 0.16, 0.5, 0, CK.TAU);
      g.fill();
    }

    g.restore();

    var data = g.getImageData(0, 0, TEX, TEX);
    texU32 = new Uint32Array(data.data.buffer);

    /* void color: dark ceiling-space, computed in same byte order */
    var vc = document.createElement("canvas");
    vc.width = 1; vc.height = 1;
    var vg = vc.getContext("2d");
    vg.fillStyle = "#15151d";
    vg.fillRect(0, 0, 1, 1);
    voidColor = new Uint32Array(vg.getImageData(0, 0, 1, 1).data.buffer)[0];
  }

  /* ---------------- features / props ---------------- */

  function buildFeatures() {
    var S = CK.sprites;
    var rng = CK.makeRng(4242);

    /* hazards first (they're painted into the texture) */
    var hz1 = lateral(200, 20);
    var hz2 = lateral(462, -18);
    hazards.push({ x: hz1.x, y: hz1.y, r: 46 });
    hazards.push({ x: hz2.x, y: hz2.y, r: 42 });

    /* item box rows */
    [70, 255, 430].forEach(function (i) {
      [-45, -15, 15, 45].forEach(function (off) {
        var p = lateral(i, off);
        itemBoxSpots.push({ x: p.x, y: p.y });
      });
    });

    /* shelf walls lining the corridor */
    for (var i = 0; i < N_WP; i += 5) {
      for (var side = -1; side <= 1; side += 2) {
        var p = lateral(i, side * (WALL_D + 16));
        if (p.x < 40 || p.x > WORLD - 40 || p.y < 40 || p.y > WORLD - 40) { continue; }
        /* leave occasional gaps so it breathes */
        var slot = Math.floor(i / 5) * 2 + (side + 1) / 2;
        if (slot % 11 === 7) {
          var deco = CK.pick(rng, [S.props.plant, S.props.sale, S.props.pallet]);
          decor.push({ x: p.x, y: p.y, img: deco, w: 26, h: 34 });
          continue;
        }
        decor.push({
          x: p.x, y: p.y,
          img: S.shelves[Math.floor(rng() * S.shelves.length)],
          w: 50, h: 36
        });
      }
    }

    /* wet-floor signs next to puddles */
    hazards.forEach(function (H, hi) {
      var p = lateral(hi === 0 ? 193 : 455, hi === 0 ? -40 : 40);
      decor.push({ x: p.x, y: p.y, img: S.props.wetSign, w: 14, h: 19 });
    });

    /* checkout registers flanking the finish line */
    var fl = lateral(0, HALF_W + 34);
    var fr = lateral(0, -(HALF_W + 34));
    decor.push({ x: fl.x, y: fl.y, img: S.props.checkout, w: 40, h: 40 });
    decor.push({ x: fr.x, y: fr.y, img: S.props.checkout, w: 40, h: 40 });

    /* solid pallet displays as mid-track obstacles */
    [{ i: 130, off: 30 }, { i: 330, off: -28 }, { i: 540, off: 25 }].forEach(function (o) {
      var p = lateral(o.i, o.off);
      solids.push({ x: p.x, y: p.y, r: 17 });
      decor.push({ x: p.x, y: p.y, img: S.props.pallet, w: 30, h: 34, solid: true });
    });
  }

  function paintMinimap() {
    var M = 100;
    minimap = document.createElement("canvas");
    minimap.width = M; minimap.height = M;
    var g = minimap.getContext("2d");
    var sc = M / WORLD;
    g.strokeStyle = "rgba(20,20,28,0.85)";
    g.lineWidth = 7;
    g.lineJoin = "round";
    g.beginPath();
    for (var i = 0; i <= N_WP; i++) {
      var w = wp(i % N_WP);
      if (i === 0) { g.moveTo(w.x * sc, w.y * sc); } else { g.lineTo(w.x * sc, w.y * sc); }
    }
    g.closePath();
    g.stroke();
    g.strokeStyle = "rgba(255,255,255,0.9)";
    g.lineWidth = 4;
    g.stroke();
    /* start notch */
    var s = wp(0);
    g.fillStyle = "#ffd23c";
    g.fillRect(s.x * sc - 2.5, s.y * sc - 2.5, 5, 5);
  }

  /* grid slots behind the finish line; slot 0 is pole position */
  function startPositions(n) {
    var out = [];
    for (var k = 0; k < n; k++) {
      var row = Math.floor(k / 2);
      var side = (k % 2) ? 30 : -30;
      var i = N_WP - 10 - row * 9;
      var p = lateral(i, side);
      var w = wp(i);
      out.push({ x: p.x, y: p.y, heading: Math.atan2(w.dy, w.dx), prog: i });
    }
    return out;
  }

  function init() {
    buildWaypoints();
    buildGrid();
    buildFeatures();   /* before texture: puddles get baked in */
    paintTexture();
    paintMinimap();
  }

  return {
    WORLD: WORLD, TEX: TEX,
    HALF_W: HALF_W, WALL_D: WALL_D, N_WP: N_WP,
    init: init,
    wp: wp,
    lateral: lateral,
    surfaceAt: surfaceAt,
    clampToCorridor: clampToCorridor,
    getTex: function () { return texU32; },
    getVoid: function () { return voidColor; },
    itemBoxSpots: itemBoxSpots,
    hazards: hazards,
    solids: solids,
    decor: decor,
    getMinimap: function () { return minimap; },
    startPositions: startPositions
  };
})();
