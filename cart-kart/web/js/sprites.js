/* Cart Kart — all art is drawn procedurally into offscreen canvases at boot */
"use strict";

/* ---------- roster ---------- */
CK.CHARS = [
  { name: "Scrappy Sam", desc: "The all-rounder of Aisle 9",
    stats: { top: 0.85, accel: 0.8, handling: 0.8, weight: 0.7 },
    pal: { coat: "#7a8a3f", coatD: "#5a6a2c", skin: "#e0b48c", hat: "#c94040", hatStyle: "beanie", hair: "#5a4632", junk: ["#c9803a", "#5a7ab0", "#d8d3c0"], flair: "umbrella" } },
  { name: "Bindle Betty", desc: "Corners like a coupon queen",
    stats: { top: 0.75, accel: 0.85, handling: 1.0, weight: 0.5 },
    pal: { coat: "#8a5aa0", coatD: "#6a4080", skin: "#caa27a", hat: "#d8c070", hatStyle: "straw", hair: "#c0c0c8", junk: ["#b05a5a", "#e0d8b0", "#6aa06a"], flair: "bindle" } },
  { name: "Cardboard Carl", desc: "Heavy build, box-plate armor",
    stats: { top: 1.0, accel: 0.6, handling: 0.6, weight: 1.0 },
    pal: { coat: "#a8794a", coatD: "#875f38", skin: "#d8a878", hat: "#3a3a3a", hatStyle: "band", hair: "#2a2420", junk: ["#b08a56", "#c09a66", "#9a7a46"], flair: "box" } },
  { name: "Penny Pigeon", desc: "Rockets off the line, birds included",
    stats: { top: 0.7, accel: 1.0, handling: 0.85, weight: 0.45 },
    pal: { coat: "#4a8a8a", coatD: "#357070", skin: "#e8bc94", hat: "#888890", hatStyle: "bun", hair: "#9a9aa2", junk: ["#d8d8e0", "#b0c8d8", "#e8e0c0"], flair: "pigeon" } },
  { name: "Dumpster Dave", desc: "Top speed found behind the deli",
    stats: { top: 0.95, accel: 0.65, handling: 0.65, weight: 0.9 },
    pal: { coat: "#3f5a3f", coatD: "#2c422c", skin: "#c89878", hat: "#2f5a8a", hatStyle: "cap", hair: "#4a3a28", junk: ["#5a5a5a", "#8a6a3a", "#4a6a8a"], flair: "trashlid" } },
  { name: "Noodle Nelly", desc: "Light as instant ramen",
    stats: { top: 0.7, accel: 0.9, handling: 0.95, weight: 0.4 },
    pal: { coat: "#d8813a", coatD: "#b06428", skin: "#e8c49c", hat: null, hatStyle: "messy", hair: "#3a2a3a", junk: ["#e8c840", "#d84a3a", "#f0e8d0"], flair: "noodles" } }
];

CK.sprites = (function () {
  var NFRAMES = 16;
  var FR = 72;                 /* kart frame px */
  var kartAtlases = [];        /* per char: canvas NFRAMES*FR x FR */
  var portraits = [];
  var shelves = [];
  var props = {};
  var items = {};
  var icons = {};

  function cnv(w, h) {
    var c = document.createElement("canvas");
    c.width = w; c.height = h;
    return c;
  }

  function px(g) { g.imageSmoothingEnabled = false; return g; }

  /* ============ kart + racer, one rotation frame ============ */
  /* a = view angle: 0 seen from behind, PI seen from front */
  function drawKartFrame(g, size, a, pal, detail) {
    var s = Math.sin(a), f = Math.cos(a);
    var cx = size * 0.5;
    var y0 = size * 0.86;                  /* ground line */
    var u = size / 72;                     /* unit scale */

    /* shadow */
    g.fillStyle = "rgba(0,0,0,0.30)";
    g.beginPath();
    g.ellipse(cx, y0 + 1 * u, 24 * u, 6 * u, 0, 0, CK.TAU);
    g.fill();

    var bx = cx + s * 6 * u;               /* basket center x */
    var by = y0 - 6 * u + f * 0;           /* basket bottom y */
    var wb = (15 + Math.abs(s) * 5) * u;   /* half width bottom */
    var wt = wb + 4 * u;                   /* half width top */
    var bh = 20 * u;                       /* basket height */
    var k = s * 5 * u;                     /* perspective skew */

    var charX = cx - s * 15 * u;
    var charDepthFront = f < 0;            /* viewing racer through the cart */

    function wheels() {
      var off = [ -wb * 0.72, wb * 0.72 ];
      for (var i = 0; i < off.length; i++) {
        g.fillStyle = "#1c1c22";
        g.beginPath(); g.arc(bx + off[i], by + 3 * u, 3.6 * u, 0, CK.TAU); g.fill();
        g.fillStyle = "#585862";
        g.beginPath(); g.arc(bx + off[i], by + 3 * u, 1.6 * u, 0, CK.TAU); g.fill();
      }
    }

    function basket() {
      /* trapezoid body */
      var p = [
        [bx - wb, by], [bx + wb, by],
        [bx + wt + k, by - bh], [bx - wt + k, by - bh]
      ];
      g.fillStyle = Math.abs(s) > 0.55 ? "#7e8894" : "#98a2ae";
      g.beginPath();
      g.moveTo(p[0][0], p[0][1]);
      for (var i = 1; i < 4; i++) { g.lineTo(p[i][0], p[i][1]); }
      g.closePath(); g.fill();
      g.strokeStyle = "#3e4854"; g.lineWidth = 1.6 * u; g.stroke();

      /* wire grid */
      g.strokeStyle = "rgba(220,228,236,0.55)";
      g.lineWidth = 0.8 * u;
      g.beginPath();
      for (var r = 1; r <= 3; r++) {
        var t = r / 4;
        var lx = CK.lerp(p[0][0], p[3][0], t), ly = CK.lerp(p[0][1], p[3][1], t);
        var rx = CK.lerp(p[1][0], p[2][0], t), ry = CK.lerp(p[1][1], p[2][1], t);
        g.moveTo(lx, ly); g.lineTo(rx, ry);
      }
      for (var c2 = 1; c2 <= 4; c2++) {
        var t2 = c2 / 5;
        var tx = CK.lerp(p[3][0], p[2][0], t2), ty = CK.lerp(p[3][1], p[2][1], t2);
        var bx2 = CK.lerp(p[0][0], p[1][0], t2), by2 = CK.lerp(p[0][1], p[1][1], t2);
        g.moveTo(bx2, by2); g.lineTo(tx, ty);
      }
      g.stroke();

      /* rim */
      g.strokeStyle = "#c4ccd6";
      g.lineWidth = 2 * u;
      g.beginPath();
      g.moveTo(p[3][0], p[3][1]); g.lineTo(p[2][0], p[2][1]);
      g.stroke();
    }

    function junk() {
      var topY = by - bh;
      var jx = bx + k;
      var cols = pal.junk;
      /* bag lumps */
      g.fillStyle = cols[0];
      g.beginPath(); g.ellipse(jx - 7 * u, topY - 2 * u, 7 * u, 5.5 * u, 0, 0, CK.TAU); g.fill();
      g.fillStyle = cols[1];
      g.beginPath(); g.ellipse(jx + 6 * u, topY - 3 * u, 6.5 * u, 6 * u, 0, 0, CK.TAU); g.fill();
      g.fillStyle = cols[2];
      g.beginPath(); g.ellipse(jx, topY - 6 * u, 5 * u, 4 * u, 0, 0, CK.TAU); g.fill();
      g.strokeStyle = "rgba(0,0,0,0.25)"; g.lineWidth = u;
      g.beginPath(); g.ellipse(jx, topY - 6 * u, 5 * u, 4 * u, 0, 0, CK.TAU); g.stroke();

      /* per-character flair sticking out of the pile */
      var fl = pal.flair;
      if (fl === "umbrella") {
        g.strokeStyle = "#333"; g.lineWidth = 1.4 * u;
        g.beginPath(); g.moveTo(jx + 9 * u, topY - 4 * u); g.lineTo(jx + 15 * u, topY - 16 * u); g.stroke();
        g.fillStyle = "#c94040";
        g.beginPath(); g.arc(jx + 15 * u, topY - 16 * u, 5 * u, Math.PI * 0.9, Math.PI * 2.1); g.fill();
      } else if (fl === "bindle") {
        g.strokeStyle = "#8a6a3a"; g.lineWidth = 1.6 * u;
        g.beginPath(); g.moveTo(jx - 8 * u, topY - 2 * u); g.lineTo(jx - 14 * u, topY - 15 * u); g.stroke();
        g.fillStyle = "#d05a5a";
        g.beginPath(); g.arc(jx - 14 * u, topY - 16 * u, 4.5 * u, 0, CK.TAU); g.fill();
        g.fillStyle = "#fff"; g.fillRect(jx - 16 * u, topY - 18 * u, 2 * u, 2 * u);
      } else if (fl === "box") {
        g.fillStyle = "#c09a66";
        g.fillRect(jx - 4 * u, topY - 16 * u, 11 * u, 9 * u);
        g.strokeStyle = "#8a6a3a"; g.lineWidth = u;
        g.strokeRect(jx - 4 * u, topY - 16 * u, 11 * u, 9 * u);
        g.beginPath(); g.moveTo(jx + 1.5 * u, topY - 16 * u); g.lineTo(jx + 1.5 * u, topY - 7 * u); g.stroke();
      } else if (fl === "pigeon") {
        g.fillStyle = "#9a9aa8";
        g.beginPath(); g.ellipse(jx + 9 * u, topY - 12 * u, 4 * u, 3 * u, -0.3, 0, CK.TAU); g.fill();
        g.beginPath(); g.arc(jx + 12 * u, topY - 15 * u, 2.2 * u, 0, CK.TAU); g.fill();
        g.fillStyle = "#e8a030";
        g.beginPath(); g.moveTo(jx + 14 * u, topY - 15 * u); g.lineTo(jx + 16.5 * u, topY - 14.4 * u); g.lineTo(jx + 14 * u, topY - 13.8 * u); g.closePath(); g.fill();
      } else if (fl === "trashlid") {
        g.fillStyle = "#788088";
        g.beginPath(); g.ellipse(jx - 8 * u, topY - 9 * u, 7 * u, 7 * u, 0, 0, CK.TAU); g.fill();
        g.strokeStyle = "#4a5058"; g.lineWidth = u;
        g.beginPath(); g.ellipse(jx - 8 * u, topY - 9 * u, 4 * u, 4 * u, 0, 0, CK.TAU); g.stroke();
      } else if (fl === "noodles") {
        g.fillStyle = "#e8c840";
        g.fillRect(jx + 5 * u, topY - 13 * u, 8 * u, 8 * u);
        g.fillStyle = "#d84a3a";
        g.fillRect(jx + 5 * u, topY - 13 * u, 8 * u, 2.5 * u);
      }
    }

    function racer() {
      var hy = y0 - 20 * u;                /* head y */
      var ty = y0 - 8 * u;                 /* torso center y */
      if (charDepthFront) { hy -= 6 * u; ty -= 6 * u; }

      /* arms reaching to the handle (only when not fully frontal) */
      if (f > -0.7) {
        g.strokeStyle = pal.coatD;
        g.lineWidth = 3 * u;
        g.lineCap = "round";
        g.beginPath();
        g.moveTo(charX - 4 * u, ty - 2 * u); g.lineTo(bx - wb * 0.5, by - bh * 0.85);
        g.moveTo(charX + 4 * u, ty - 2 * u); g.lineTo(bx + wb * 0.5, by - bh * 0.85);
        g.stroke();
      }

      /* torso / coat */
      g.fillStyle = pal.coat;
      g.beginPath();
      g.ellipse(charX, ty, 8 * u, 10 * u, 0, 0, CK.TAU);
      g.fill();
      g.strokeStyle = pal.coatD; g.lineWidth = 1.2 * u; g.stroke();
      /* patch on coat */
      g.fillStyle = pal.coatD;
      g.fillRect(charX - 5 * u, ty + 1 * u, 4 * u, 3.5 * u);

      /* head */
      g.fillStyle = pal.skin;
      g.beginPath(); g.arc(charX, hy, 6 * u, 0, CK.TAU); g.fill();

      /* face when viewer sees the front */
      if (f < -0.25) {
        g.fillStyle = "#2a2020";
        g.beginPath(); g.arc(charX - 2.2 * u, hy - 0.5 * u, 0.9 * u, 0, CK.TAU); g.fill();
        g.beginPath(); g.arc(charX + 2.2 * u, hy - 0.5 * u, 0.9 * u, 0, CK.TAU); g.fill();
        g.strokeStyle = "#2a2020"; g.lineWidth = 0.9 * u;
        g.beginPath(); g.arc(charX, hy + 2 * u, 2 * u, 0.15 * Math.PI, 0.85 * Math.PI); g.stroke();
        /* stubble */
        g.fillStyle = "rgba(60,50,40,0.25)";
        g.beginPath(); g.arc(charX, hy + 3 * u, 3.4 * u, 0, Math.PI); g.fill();
      }

      /* hair + hat styles */
      var hs = pal.hatStyle;
      if (hs === "beanie") {
        g.fillStyle = pal.hat;
        g.beginPath(); g.arc(charX, hy - 1.5 * u, 6 * u, Math.PI, 0); g.fill();
        g.fillRect(charX - 6 * u, hy - 2.5 * u, 12 * u, 2 * u);
      } else if (hs === "cap") {
        g.fillStyle = pal.hat;
        g.beginPath(); g.arc(charX, hy - 1.5 * u, 6 * u, Math.PI, 0); g.fill();
        if (f < -0.25) { g.fillRect(charX - 6 * u, hy - 2.5 * u, 12 * u, 1.6 * u); }
        else { g.fillRect(charX - 8 * u - s * 3 * u, hy - 2.6 * u, 8 * u, 1.8 * u); }
      } else if (hs === "straw") {
        g.fillStyle = pal.hair;
        g.beginPath(); g.arc(charX, hy, 6.2 * u, Math.PI, 0); g.fill();
        g.fillStyle = pal.hat;
        g.beginPath(); g.ellipse(charX, hy - 3 * u, 9 * u, 2.6 * u, 0, 0, CK.TAU); g.fill();
        g.beginPath(); g.arc(charX, hy - 4 * u, 4.5 * u, Math.PI, 0); g.fill();
      } else if (hs === "band") {
        g.fillStyle = pal.hair;
        g.beginPath(); g.arc(charX, hy - 1 * u, 6 * u, Math.PI, 0); g.fill();
        g.fillStyle = "#d8d0c0";
        g.fillRect(charX - 6 * u, hy - 3 * u, 12 * u, 2 * u);
      } else if (hs === "bun") {
        g.fillStyle = pal.hair;
        g.beginPath(); g.arc(charX, hy - 1 * u, 6 * u, Math.PI, 0); g.fill();
        g.beginPath(); g.arc(charX, hy - 7 * u, 3 * u, 0, CK.TAU); g.fill();
      } else { /* messy */
        g.fillStyle = pal.hair;
        g.beginPath(); g.arc(charX, hy - 1 * u, 6.4 * u, Math.PI * 0.9, Math.PI * 0.1); g.fill();
        for (var i = -2; i <= 2; i++) {
          g.beginPath();
          g.arc(charX + i * 3 * u, hy - 5.5 * u, 1.8 * u, 0, CK.TAU);
          g.fill();
        }
      }

      /* scarf */
      if (detail) {
        g.strokeStyle = pal.junk[0];
        g.lineWidth = 2.2 * u;
        g.beginPath();
        g.moveTo(charX - 4 * u, hy + 5.5 * u);
        g.quadraticCurveTo(charX, hy + 7.5 * u, charX + 4 * u, hy + 5.5 * u);
        g.stroke();
      }
    }

    /* draw order depends on which is closer to the camera */
    wheels();
    if (charDepthFront) { racer(); basket(); junk(); }
    else { basket(); junk(); racer(); }
  }

  /* ============ shelves (track walls) ============ */
  function drawShelf(g, w, h, variant, rng) {
    /* metal frame */
    g.fillStyle = "#5a6470";
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#434c58";
    g.fillRect(0, 0, 4, h); g.fillRect(w - 4, 0, 4, h);

    if (variant === "freezer") {
      g.fillStyle = "#c8d4dc";
      g.fillRect(4, 4, w - 8, h - 10);
      g.fillStyle = "#9ec8e8";
      g.fillRect(8, 10, w - 16, h - 30);
      g.strokeStyle = "#ffffff"; g.lineWidth = 2;
      g.strokeRect(8, 10, w - 16, h - 30);
      g.fillStyle = "rgba(255,255,255,0.5)";
      g.beginPath();
      g.moveTo(12, h - 24); g.lineTo(26, 12); g.lineTo(34, 12); g.lineTo(20, h - 24);
      g.closePath(); g.fill();
      g.fillStyle = "#38648a";
      g.fillRect(4, 4, w - 8, 8);
      g.fillStyle = "#fff";
      g.font = "bold 9px Arial";
      g.fillText("FROZEN", 8, 11);
      /* handle */
      g.fillStyle = "#38424e";
      g.fillRect(w - 14, 16, 4, h - 44);
      return;
    }

    var rows = 4;
    var rowH = (h - 12) / rows;
    for (var r = 0; r < rows; r++) {
      var ry = 4 + r * rowH;
      /* shelf plate */
      g.fillStyle = "#8a94a0";
      g.fillRect(4, ry + rowH - 4, w - 8, 4);
      /* products */
      var x = 7;
      while (x < w - 10) {
        var pw = 6 + Math.floor(rng() * 8);
        var ph = rowH * (0.45 + rng() * 0.4);
        if (variant === "produce") {
          /* crates of round produce */
          g.fillStyle = "#9a7a4a";
          g.fillRect(x, ry + rowH - 4 - rowH * 0.5, pw + 4, rowH * 0.46);
          var pc = ["#5aa04a", "#d8503a", "#e8a030", "#7ab04a"][Math.floor(rng() * 4)];
          g.fillStyle = pc;
          for (var b = 0; b < 3; b++) {
            g.beginPath();
            g.arc(x + 3 + b * 4, ry + rowH - 6 - rowH * 0.5 + 2, 3, 0, CK.TAU);
            g.fill();
          }
          x += pw + 7;
        } else {
          var hue = Math.floor(rng() * 360);
          g.fillStyle = "hsl(" + hue + ",55%,55%)";
          g.fillRect(x, ry + rowH - 4 - ph, pw, ph);
          g.fillStyle = "hsl(" + hue + ",55%,72%)";
          g.fillRect(x, ry + rowH - 4 - ph, pw, 3);
          x += pw + 2;
        }
      }
    }
    /* price tags strip */
    g.fillStyle = "#e8e4d8";
    g.fillRect(4, h - 8, w - 8, 5);
    g.fillStyle = "#c94040";
    for (var t = 8; t < w - 10; t += 14) { g.fillRect(t, h - 7, 6, 3); }
  }

  /* ============ item / prop sprites ============ */
  function drawItemBox(g, w, h, phase) {
    var cx = w / 2, cy = h / 2;
    g.save();
    g.translate(cx, cy);
    g.rotate(Math.sin(phase * CK.TAU) * 0.22);
    var s = 1 + Math.sin(phase * CK.TAU * 2) * 0.06;
    g.scale(s, s);
    /* cereal-ish mystery box */
    g.fillStyle = "#e8b83a";
    g.fillRect(-14, -17, 28, 32);
    g.fillStyle = "#d89020";
    g.fillRect(-14, -17, 28, 6);
    g.fillRect(-14, 9, 28, 6);
    g.strokeStyle = "#8a5a10"; g.lineWidth = 2;
    g.strokeRect(-14, -17, 28, 32);
    g.fillStyle = "#fff";
    g.font = "bold 20px Arial";
    g.textAlign = "center"; g.textBaseline = "middle";
    g.strokeStyle = "#a04a20"; g.lineWidth = 3;
    g.strokeText("?", 0, -1);
    g.fillText("?", 0, -1);
    g.restore();
  }

  function drawBanana(g, w, h) {
    var cx = w / 2, cy = h / 2;
    g.strokeStyle = "#e8c83a";
    g.lineWidth = 7;
    g.lineCap = "round";
    g.beginPath();
    g.arc(cx, cy - 4, 11, 0.15 * Math.PI, 0.85 * Math.PI);
    g.stroke();
    g.strokeStyle = "#b89a20";
    g.lineWidth = 2.5;
    g.beginPath();
    g.arc(cx, cy - 4, 11, 0.2 * Math.PI, 0.8 * Math.PI);
    g.stroke();
    g.fillStyle = "#7a6a20";
    g.fillRect(cx + 8, cy + 2, 4, 4);
  }

  function drawCan(g, w, h) {
    var cx = w / 2;
    g.fillStyle = "#c93a30";
    g.fillRect(cx - 9, 8, 18, 20);
    g.fillStyle = "#e8e4dc";
    g.fillRect(cx - 9, 14, 18, 8);
    g.fillStyle = "#c93a30";
    g.font = "bold 6px Arial";
    g.textAlign = "center";
    g.fillText("SOUP", cx, 20);
    g.fillStyle = "#b8b8c0";
    g.beginPath(); g.ellipse(cx, 8, 9, 3, 0, 0, CK.TAU); g.fill();
    g.beginPath(); g.ellipse(cx, 28, 9, 3, 0, 0, CK.TAU); g.fill();
  }

  function drawMilk(g, w, h) {
    var cx = w / 2;
    g.fillStyle = "#f0f0ea";
    g.fillRect(cx - 8, 12, 16, 18);
    g.beginPath();
    g.moveTo(cx - 8, 12); g.lineTo(cx - 4, 5); g.lineTo(cx + 6, 5); g.lineTo(cx + 8, 12);
    g.closePath(); g.fill();
    g.fillStyle = "#4a90d8";
    g.fillRect(cx - 8, 18, 16, 6);
    g.fillStyle = "#3a70a8";
    g.fillRect(cx - 2, 3, 6, 4);
    g.strokeStyle = "#c8c8c0"; g.lineWidth = 1;
    g.strokeRect(cx - 8, 12, 16, 18);
  }

  function drawDrink(g, w, h) {
    var cx = w / 2;
    g.fillStyle = "#3ac93a";
    g.fillRect(cx - 7, 6, 14, 24);
    g.fillStyle = "#2a8a2a";
    g.fillRect(cx - 7, 6, 14, 5);
    g.fillStyle = "#e8e830";
    g.beginPath();
    g.moveTo(cx + 3, 12); g.lineTo(cx - 4, 20); g.lineTo(cx, 20);
    g.lineTo(cx - 3, 27); g.lineTo(cx + 5, 18); g.lineTo(cx + 1, 18);
    g.closePath(); g.fill();
    g.fillStyle = "#c8c8d0";
    g.beginPath(); g.ellipse(cx, 6, 7, 2.5, 0, 0, CK.TAU); g.fill();
  }

  function drawPuddle(g, w, h) {
    var cx = w / 2, cy = h / 2;
    g.fillStyle = "rgba(240,240,248,0.85)";
    g.beginPath();
    g.ellipse(cx, cy, w * 0.42, h * 0.30, 0, 0, CK.TAU);
    g.fill();
    g.fillStyle = "rgba(255,255,255,0.9)";
    g.beginPath();
    g.ellipse(cx - w * 0.1, cy - h * 0.05, w * 0.2, h * 0.12, 0.4, 0, CK.TAU);
    g.fill();
    g.fillStyle = "rgba(200,210,230,0.6)";
    g.beginPath();
    g.ellipse(cx + w * 0.22, cy + h * 0.1, w * 0.1, h * 0.06, 0, 0, CK.TAU);
    g.fill();
  }

  function drawWetSign(g, w, h) {
    var cx = w / 2;
    g.fillStyle = "#e8c820";
    g.beginPath();
    g.moveTo(cx, 4); g.lineTo(cx + w * 0.34, h - 6); g.lineTo(cx - w * 0.34, h - 6);
    g.closePath(); g.fill();
    g.strokeStyle = "#a88a10"; g.lineWidth = 2; g.stroke();
    g.fillStyle = "#2a2a2a";
    g.font = "bold " + Math.floor(h * 0.14) + "px Arial";
    g.textAlign = "center";
    g.fillText("WET", cx, h * 0.52);
    g.fillText("FLOOR", cx, h * 0.68);
    g.fillStyle = "rgba(0,0,0,0.3)";
    g.fillRect(cx - w * 0.3, h - 6, w * 0.6, 3);
  }

  function drawPalletCans(g, w, h, rng) {
    /* wooden pallet with pyramid of cans */
    g.fillStyle = "#9a7a4a";
    g.fillRect(2, h - 10, w - 4, 8);
    g.fillStyle = "#7a5a30";
    g.fillRect(2, h - 6, w - 4, 2);
    var rows = 4;
    for (var r = 0; r < rows; r++) {
      var count = rows - r;
      var cw = 12;
      var startX = w / 2 - (count * cw) / 2;
      for (var i = 0; i < count; i++) {
        var x = startX + i * cw;
        var y = h - 12 - (r + 1) * 14;
        g.fillStyle = r % 2 ? "#c93a30" : "#3a70c9";
        g.fillRect(x + 1, y, cw - 2, 13);
        g.fillStyle = "#e8e4dc";
        g.fillRect(x + 1, y + 4, cw - 2, 5);
        g.fillStyle = "#b8b8c0";
        g.beginPath(); g.ellipse(x + cw / 2, y, cw / 2 - 1, 2, 0, 0, CK.TAU); g.fill();
      }
    }
  }

  function drawCheckout(g, w, h) {
    /* checkout register lane end */
    g.fillStyle = "#4a90d8";
    g.fillRect(4, h * 0.4, w - 8, h * 0.55);
    g.fillStyle = "#38424e";
    g.fillRect(8, h * 0.34, w - 16, h * 0.08);
    /* register screen on a pole */
    g.fillStyle = "#5a6470";
    g.fillRect(w * 0.42, h * 0.1, 5, h * 0.3);
    g.fillStyle = "#2a2a30";
    g.fillRect(w * 0.28, h * 0.02, w * 0.42, h * 0.14);
    g.fillStyle = "#5ae86a";
    g.fillRect(w * 0.31, h * 0.045, w * 0.36, h * 0.09);
    /* lane number */
    g.fillStyle = "#e8c820";
    g.beginPath(); g.arc(w * 0.5, h * 0.52, w * 0.14, 0, CK.TAU); g.fill();
    g.fillStyle = "#2a2a2a";
    g.font = "bold " + Math.floor(w * 0.18) + "px Arial";
    g.textAlign = "center"; g.textBaseline = "middle";
    g.fillText("9", w * 0.5, h * 0.53);
  }

  function drawSaleSign(g, w, h) {
    g.fillStyle = "#8a94a0";
    g.fillRect(w / 2 - 2, h * 0.3, 4, h * 0.68);
    g.fillStyle = "#d83a3a";
    g.beginPath();
    g.arc(w / 2, h * 0.22, w * 0.34, 0, CK.TAU);
    g.fill();
    g.fillStyle = "#fff";
    g.font = "bold " + Math.floor(w * 0.22) + "px Arial";
    g.textAlign = "center"; g.textBaseline = "middle";
    g.fillText("SALE", w / 2, h * 0.22);
  }

  function drawPlant(g, w, h) {
    g.fillStyle = "#b06a3a";
    g.beginPath();
    g.moveTo(w * 0.3, h * 0.75); g.lineTo(w * 0.7, h * 0.75);
    g.lineTo(w * 0.62, h * 0.98); g.lineTo(w * 0.38, h * 0.98);
    g.closePath(); g.fill();
    g.strokeStyle = "#3a8a3a"; g.lineWidth = w * 0.07; g.lineCap = "round";
    for (var i = 0; i < 5; i++) {
      var a = -Math.PI / 2 + (i - 2) * 0.45;
      g.beginPath();
      g.moveTo(w / 2, h * 0.75);
      g.quadraticCurveTo(w / 2 + Math.cos(a) * w * 0.1, h * 0.4,
        w / 2 + Math.cos(a) * w * 0.42, h * 0.75 + Math.sin(a) * h * 0.62);
      g.stroke();
    }
  }

  /* ============ HUD icons ============ */
  function icon(drawFn) {
    var c = cnv(36, 36);
    drawFn(px(c.getContext("2d")), 36, 36);
    return c;
  }

  /* ============ init ============ */
  function init() {
    var i, c, g;

    for (i = 0; i < CK.CHARS.length; i++) {
      var atlas = cnv(FR * NFRAMES, FR);
      g = px(atlas.getContext("2d"));
      for (var fIdx = 0; fIdx < NFRAMES; fIdx++) {
        g.save();
        g.translate(fIdx * FR, 0);
        g.beginPath(); g.rect(0, 0, FR, FR); g.clip();
        drawKartFrame(g, FR, fIdx / NFRAMES * CK.TAU, CK.CHARS[i].pal, true);
        g.restore();
      }
      kartAtlases.push(atlas);

      var pc = cnv(120, 120);
      g = px(pc.getContext("2d"));
      drawKartFrame(g, 120, Math.PI * 0.68, CK.CHARS[i].pal, true);
      portraits.push(pc);
    }

    var rng = CK.makeRng(1337);
    var variants = ["goods", "goods", "produce", "freezer", "goods"];
    for (i = 0; i < variants.length; i++) {
      c = cnv(96, 120);
      drawShelf(px(c.getContext("2d")), 96, 120, variants[i], rng);
      shelves.push(c);
    }

    items.boxFrames = [];
    for (i = 0; i < 8; i++) {
      c = cnv(44, 44);
      drawItemBox(px(c.getContext("2d")), 44, 44, i / 8);
      items.boxFrames.push(c);
    }
    items.banana = cnv(36, 36); drawBanana(px(items.banana.getContext("2d")), 36, 36);
    items.can = cnv(36, 36); drawCan(px(items.can.getContext("2d")), 36, 36);
    items.milk = cnv(36, 36); drawMilk(px(items.milk.getContext("2d")), 36, 36);
    items.drink = cnv(36, 36); drawDrink(px(items.drink.getContext("2d")), 36, 36);
    items.puddle = cnv(64, 40); drawPuddle(px(items.puddle.getContext("2d")), 64, 40);

    props.wetSign = cnv(48, 64); drawWetSign(px(props.wetSign.getContext("2d")), 48, 64);
    props.pallet = cnv(72, 80); drawPalletCans(px(props.pallet.getContext("2d")), 72, 80, rng);
    props.checkout = cnv(90, 90); drawCheckout(px(props.checkout.getContext("2d")), 90, 90);
    props.sale = cnv(56, 90); drawSaleSign(px(props.sale.getContext("2d")), 56, 90);
    props.plant = cnv(56, 72); drawPlant(px(props.plant.getContext("2d")), 56, 72);

    icons.banana = icon(drawBanana);
    icons.can = icon(drawCan);
    icons.milk = icon(drawMilk);
    icons.drink = icon(drawDrink);
  }

  return {
    NFRAMES: NFRAMES,
    FR: FR,
    init: init,
    kartAtlases: kartAtlases,
    portraits: portraits,
    shelves: shelves,
    props: props,
    items: items,
    icons: icons,
    drawKartFrame: drawKartFrame
  };
})();
