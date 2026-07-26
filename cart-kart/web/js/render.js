/* Cart Kart — SNES-style mode-7 renderer: scanline floor, parallax store
   backdrop, billboard sprites */
"use strict";

CK.render = (function () {
  var W = 480, H = 270;
  var HOR = 96;               /* horizon row */
  var PROJ = 310;             /* focal length in px */
  var CAMH = 26;              /* camera height, world units */
  var Z_NEAR = 6, Z_FAR = 1000;

  var ctx = null;
  var floorImg = null;        /* ImageData for rows HOR..H */
  var floorBuf = null;        /* Uint32 view */
  var panorama = null;
  var fog = null;

  var PANW = 2048, PANH = HOR;

  function paintPanorama() {
    panorama = document.createElement("canvas");
    panorama.width = PANW; panorama.height = PANH;
    var g = panorama.getContext("2d");

    /* ceiling */
    var grad = g.createLinearGradient(0, 0, 0, PANH * 0.55);
    grad.addColorStop(0, "#14141d");
    grad.addColorStop(1, "#232330");
    g.fillStyle = grad;
    g.fillRect(0, 0, PANW, PANH * 0.55);

    /* fluorescent tube lights */
    for (var lx = 40; lx < PANW; lx += 160) {
      g.fillStyle = "rgba(200,220,255,0.12)";
      g.fillRect(lx - 26, 6, 76, 10);
      g.fillStyle = "#dce8ff";
      g.fillRect(lx - 18, 8, 60, 5);
      g.fillStyle = "rgba(220,235,255,0.35)";
      g.fillRect(lx - 22, 13, 68, 2);
    }

    /* back wall */
    g.fillStyle = "#2a2a38";
    g.fillRect(0, PANH * 0.55, PANW, PANH * 0.45);

    /* distant shelving silhouettes */
    for (var sx = 0; sx < PANW; sx += 54) {
      g.fillStyle = (sx / 54) % 2 ? "#333344" : "#30303f";
      g.fillRect(sx, PANH * 0.62, 46, PANH * 0.38);
      /* faint product speckles */
      g.fillStyle = "rgba(180,160,120,0.16)";
      for (var r = 0; r < 3; r++) {
        g.fillRect(sx + 4, PANH * (0.66 + r * 0.1), 38, 3);
      }
    }

    /* glowing signs */
    function sign(x, text, color, size) {
      g.save();
      g.font = "bold " + size + "px Arial";
      g.textAlign = "center";
      g.shadowColor = color;
      g.shadowBlur = 12;
      g.fillStyle = color;
      g.fillText(text, x, PANH * 0.5);
      g.restore();
    }
    sign(300, "MEGAMART", "#5ae0e8", 26);
    sign(560, "OPEN 24H", "#e85a8a", 15);
    sign(950, "PRODUCE", "#6ae86a", 18);
    sign(1350, "BAKERY", "#e8b45a", 18);
    sign(1750, "FROZEN", "#7ab0f0", 18);

    /* wall/floor seam */
    g.fillStyle = "rgba(90,90,110,0.6)";
    g.fillRect(0, PANH - 2, PANW, 2);
  }

  function makeFog() {
    fog = document.createElement("canvas");
    fog.width = 1; fog.height = 40;
    var g = fog.getContext("2d");
    var gr = g.createLinearGradient(0, 0, 0, 40);
    gr.addColorStop(0, "rgba(24,24,34,0.85)");
    gr.addColorStop(1, "rgba(24,24,34,0)");
    g.fillStyle = gr;
    g.fillRect(0, 0, 1, 40);
  }

  function init(canvas) {
    ctx = canvas.getContext("2d", { alpha: false });
    ctx.imageSmoothingEnabled = false;
    floorImg = ctx.createImageData(W, H - HOR);
    floorBuf = new Uint32Array(floorImg.data.buffer);
    paintPanorama();
    makeFog();
  }

  /* ---------------- floor ---------------- */

  function drawFloor(cam) {
    var tex = CK.track.getTex();
    var voidC = CK.track.getVoid();
    var fx = Math.cos(cam.yaw), fy = Math.sin(cam.yaw);
    var rx = -fy, ry = fx;
    var rows = H - HOR;
    var o = 0;

    for (var row = 0; row < rows; row++) {
      var z = CAMH * PROJ / (row + 1);
      var sxs = rx * z / PROJ;      /* world step per screen px */
      var sys = ry * z / PROJ;
      var wx = cam.x + fx * z - sxs * (W / 2);
      var wy = cam.y + fy * z - sys * (W / 2);
      for (var x = 0; x < W; x++) {
        var xi = (wx * 0.5) | 0;
        var yi = (wy * 0.5) | 0;
        if (((xi | yi) & ~1023) !== 0) {
          floorBuf[o++] = voidC;
        } else {
          floorBuf[o++] = tex[(yi << 10) | xi];
        }
        wx += sxs; wy += sys;
      }
    }
    ctx.putImageData(floorImg, 0, HOR);
  }

  /* ---------------- backdrop ---------------- */

  function drawBackdrop(cam) {
    var off = Math.floor((cam.yaw / CK.TAU) * PANW % PANW);
    if (off < 0) { off += PANW; }
    /* two slices for wraparound */
    var w1 = Math.min(PANW - off, W);
    ctx.drawImage(panorama, off, 0, w1, PANH, 0, 0, w1, PANH);
    if (w1 < W) {
      ctx.drawImage(panorama, 0, 0, W - w1, PANH, w1, 0, W - w1, PANH);
    }
  }

  /* ---------------- sprites ---------------- */

  /* drawable: {x, y, w, h, img}                — static billboard
               {x, y, w, h, kart, heading, spinT} — kart (frame by view angle)
               {x, y, yOff, w, h, img}          — floating (item boxes)
               {x, y, size, draw}               — custom shape callback  */
  function drawSprites(cam, drawables) {
    var fx = Math.cos(cam.yaw), fy = Math.sin(cam.yaw);
    var rx = -fy, ry = fx;
    var list = [];

    for (var i = 0; i < drawables.length; i++) {
      var d = drawables[i];
      var relx = d.x - cam.x, rely = d.y - cam.y;
      var z = relx * fx + rely * fy;
      if (z < Z_NEAR || z > Z_FAR) { continue; }
      var lat = relx * rx + rely * ry;
      var scale = PROJ / z;
      var sx = W / 2 + lat * scale;
      var sw = (d.w || d.size || 10) * scale;
      if (sx + sw < -20 || sx - sw > W + 20) { continue; }
      list.push({ d: d, z: z, sx: sx, sy: HOR + CAMH * scale, scale: scale });
    }

    /* the player's own kart is always drawn last so scenery can't hide it */
    list.sort(function (a, b) {
      if (a.d.topmost !== b.d.topmost) { return a.d.topmost ? 1 : -1; }
      return b.z - a.z;
    });

    for (i = 0; i < list.length; i++) {
      var e = list[i];
      var d2 = e.d;
      var sw2 = (d2.w || d2.size || 10) * e.scale;
      var sh = (d2.h || d2.size || 10) * e.scale;

      /* fade scenery that is about to hit the camera plane (never karts,
         or the player would vanish when the camera clamps at a wall) */
      var alpha = 1;
      if (e.z < 30 && d2.kart === undefined) {
        alpha = CK.clamp((e.z - 12) / 18, 0, 1);
        if (alpha < 0.04) { continue; }
      }
      ctx.globalAlpha = alpha;

      if (d2.draw) {
        d2.draw(ctx, e.sx, e.sy, e.scale);
        ctx.globalAlpha = 1;
        continue;
      }

      var img;
      var anchor = 1.0;
      if (d2.kart !== undefined) {
        var S = CK.sprites;
        var frame;
        if (d2.spinT > 0) {
          frame = Math.floor(d2.spinT * 24) % S.NFRAMES;
        } else {
          var viewAng = d2.heading - Math.atan2(rely = d2.y - cam.y, relx = d2.x - cam.x);
          frame = Math.round(viewAng / CK.TAU * S.NFRAMES) % S.NFRAMES;
          if (frame < 0) { frame += S.NFRAMES; }
        }
        var atlas = S.kartAtlases[d2.kart];
        anchor = 0.92;
        var dy = e.sy - sh * anchor + (d2.yOff || 0) * e.scale;
        ctx.drawImage(atlas, frame * S.FR, 0, S.FR, S.FR,
          e.sx - sw2 / 2, dy, sw2, sh);
        ctx.globalAlpha = 1;
        continue;
      }

      img = d2.img;
      var dy2 = e.sy - sh - (d2.yOff || 0) * e.scale;
      ctx.drawImage(img, e.sx - sw2 / 2, dy2, sw2, sh);
      ctx.globalAlpha = 1;
    }
  }

  function render(cam, drawables) {
    drawBackdrop(cam);
    drawFloor(cam);
    ctx.drawImage(fog, 0, 0, 1, 40, 0, HOR - 6, W, 30);
    drawSprites(cam, drawables);
  }

  return {
    W: W, H: H, HOR: HOR, PROJ: PROJ, CAMH: CAMH,
    init: init,
    render: render,
    ctx: function () { return ctx; }
  };
})();
