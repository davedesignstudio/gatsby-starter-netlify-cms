/* Cart Kart — screens + HUD, drawn on the game canvas at internal res */
"use strict";

CK.ui = (function () {
  var W = 480, H = 270;
  var screen = "title";     /* title | select | race | results */
  var g = null;
  var canvas = null;
  var taps = [];            /* canvas-space taps this frame */
  var selIdx = 0;
  var demoProg = 0;
  var blinkT = 0;
  var finalLapT = 0;
  var lastLap = 0;
  var finishedT = 0;
  var isTouch = false;

  function init(cnv) {
    canvas = cnv;
    g = cnv.getContext("2d");
    isTouch = ("ontouchstart" in window) || navigator.maxTouchPoints > 0;

    function toCanvas(cx, cy) {
      var r = canvas.getBoundingClientRect();
      return { x: (cx - r.left) * (W / r.width), y: (cy - r.top) * (H / r.height) };
    }
    canvas.addEventListener("click", function (e) {
      taps.push(toCanvas(e.clientX, e.clientY));
    });
    canvas.addEventListener("touchstart", function (e) {
      for (var i = 0; i < e.changedTouches.length; i++) {
        var t = e.changedTouches[i];
        taps.push(toCanvas(t.clientX, t.clientY));
      }
    }, { passive: true });
  }

  /* ---------------- helpers ---------------- */

  function text(str, x, y, size, fill, align, outline, ow) {
    g.font = "900 " + size + "px 'Arial Black', Arial, sans-serif";
    g.textAlign = align || "center";
    g.textBaseline = "middle";
    if (outline) {
      g.lineJoin = "round";
      g.strokeStyle = outline;
      g.lineWidth = ow || Math.max(2, size * 0.16);
      g.strokeText(str, x, y);
    }
    g.fillStyle = fill;
    g.fillText(str, x, y);
  }

  function panel(x, y, w, h, r) {
    g.fillStyle = "rgba(16,18,30,0.78)";
    g.strokeStyle = "rgba(255,255,255,0.25)";
    g.lineWidth = 1.5;
    g.beginPath();
    g.roundRect(x, y, w, h, r || 6);
    g.fill();
    g.stroke();
  }

  function fmtTime(t) {
    var m = Math.floor(t / 60);
    var s = Math.floor(t % 60);
    var c = Math.floor((t * 100) % 100);
    return m + ":" + (s < 10 ? "0" : "") + s + "." + (c < 10 ? "0" : "") + c;
  }

  function ordinal(n) {
    return n + (n === 1 ? "st" : n === 2 ? "nd" : n === 3 ? "rd" : "th");
  }

  function tapIn(t, x, y, w, h) {
    return t.x >= x && t.x <= x + w && t.y >= y && t.y <= y + h;
  }

  function setTouchUI(on) {
    var el = document.getElementById("touch-ui");
    if (el) { el.classList.toggle("active", on && isTouch); }
  }

  /* ---------------- demo background (title/select) ---------------- */

  function drawDemoWorld(dt) {
    demoProg += dt * 14;
    var T = CK.track;
    var i = Math.floor(demoProg) % T.N_WP;
    var w = T.wp(i);
    var cam = { x: w.x, y: w.y, yaw: Math.atan2(w.dy, w.dx) };
    CK.render.render(cam, T.decor);
    g.fillStyle = "rgba(8,8,16,0.45)";
    g.fillRect(0, 0, W, H);
  }

  /* ---------------- title ---------------- */

  function drawTitle(dt, edges) {
    drawDemoWorld(dt);
    blinkT += dt;

    /* logo cart doodle */
    var S = CK.sprites;
    g.save();
    g.translate(W / 2 - 150, 52);
    g.rotate(-0.08);
    g.drawImage(S.portraits[0], -38, -20, 76, 76);
    g.restore();
    g.save();
    g.translate(W / 2 + 150, 58);
    g.rotate(0.08);
    g.drawImage(S.portraits[3], -38, -20, 76, 76);
    g.restore();

    text("CART KART", W / 2, 58, 52, "#ffd23c", "center", "#a03020", 10);
    text("AISLE RACERS", W / 2, 96, 18, "#ffffff", "center", "#203050", 5);
    text("Midnight Grand Prix at the Megamart", W / 2, 122, 10, "#c8d0e0", "center");

    if (Math.floor(blinkT * 2) % 2 === 0) {
      text(isTouch ? "TAP TO START" : "PRESS ANY KEY", W / 2, 190, 16, "#ffffff", "center", "#000", 4);
    }
    text("3 laps  -  grab ? boxes  -  don't slip", W / 2, 222, 9, "#9aa4c0", "center");

    if (edges.anyKey || taps.length) {
      CK.audio.ensure();
      CK.audio.sfx.pickup();
      screen = "select";
      blinkT = 0;
    }
  }

  /* ---------------- character select ---------------- */

  function drawSelect(dt, edges) {
    drawDemoWorld(dt);
    blinkT += dt;
    var S = CK.sprites;
    var chars = CK.CHARS;

    text("CHOOSE YOUR RACER", W / 2, 20, 18, "#ffd23c", "center", "#502010", 5);

    var cw = 64, ch = 74, gapX = 10;
    var cols = 6;
    var x0 = (W - cols * cw - (cols - 1) * gapX) / 2;
    var y0 = 38;

    var start = false;

    for (var i = 0; i < chars.length; i++) {
      var x = x0 + i * (cw + gapX);
      var sel = i === selIdx;
      g.fillStyle = sel ? "rgba(255,210,60,0.28)" : "rgba(16,18,30,0.7)";
      g.strokeStyle = sel ? "#ffd23c" : "rgba(255,255,255,0.25)";
      g.lineWidth = sel ? 2.5 : 1.5;
      g.beginPath();
      g.roundRect(x, y0, cw, ch, 8);
      g.fill(); g.stroke();
      g.drawImage(S.portraits[i], x + 2, y0 + 2, cw - 4, cw - 4);
      text(chars[i].name.split(" ")[0], x + cw / 2, y0 + ch - 8, 9, sel ? "#ffd23c" : "#c8d0e0");

      for (var t = 0; t < taps.length; t++) {
        if (tapIn(taps[t], x, y0, cw, ch)) {
          if (selIdx === i) { start = true; }
          selIdx = i;
          CK.audio.sfx.roulette();
        }
      }
    }

    /* stats card */
    var c = chars[selIdx];
    panel(W / 2 - 150, 126, 300, 74, 8);
    text(c.name, W / 2, 140, 14, "#ffd23c", "center");
    text(c.desc, W / 2, 156, 9, "#c8d0e0", "center");
    var stats = [["SPEED", c.stats.top], ["ACCEL", c.stats.accel], ["GRIP", c.stats.handling]];
    for (var s = 0; s < 3; s++) {
      var sy = 170 + s * 10;
      text(stats[s][0], W / 2 - 108, sy, 8, "#9aa4c0", "left");
      g.fillStyle = "rgba(255,255,255,0.15)";
      g.fillRect(W / 2 - 60, sy - 3, 160, 6);
      g.fillStyle = ["#5ae06a", "#5ab0e8", "#e8a05a"][s];
      g.fillRect(W / 2 - 60, sy - 3, 160 * stats[s][1], 6);
    }

    /* go button */
    var bw = 170, bh = 26, bx = W / 2 - bw / 2, by = 216;
    g.fillStyle = Math.floor(blinkT * 2) % 2 ? "#e84040" : "#ff5050";
    g.strokeStyle = "#801818";
    g.lineWidth = 2;
    g.beginPath(); g.roundRect(bx, by, bw, bh, 12); g.fill(); g.stroke();
    text(isTouch ? "TAP TO RACE!" : "ENTER / SPACE TO RACE!", W / 2, by + bh / 2 + 1, 12, "#fff");

    /* keyboard nav */
    if (edges.leftTap) { selIdx = (selIdx + chars.length - 1) % chars.length; CK.audio.sfx.roulette(); }
    if (edges.rightTap) { selIdx = (selIdx + 1) % chars.length; CK.audio.sfx.roulette(); }

    for (t = 0; t < taps.length; t++) {
      if (tapIn(taps[t], bx, by - 6, bw, bh + 12)) { start = true; }
    }
    if (edges.confirm || edges.item) { start = true; }

    if (start) {
      CK.audio.ensure();
      CK.game.startRace(selIdx);
      screen = "race";
      lastLap = 0;
      finalLapT = 0;
      finishedT = 0;
      setTouchUI(true);
    }
  }

  /* ---------------- race HUD ---------------- */

  function drawHUD(dt) {
    var game = CK.game;
    var p = game.getPlayer();
    var S = CK.sprites;
    var T = CK.track;

    /* item slot */
    panel(8, 8, 40, 40, 8);
    if (p.rouletteT > 0) {
      var icons = [S.icons.banana, S.icons.can, S.icons.milk, S.icons.drink];
      var ic = icons[Math.floor(p.rouletteT * 14) % 4];
      g.drawImage(ic, 12, 12, 32, 32);
    } else if (p.item) {
      var map = { banana: S.icons.banana, can: S.icons.can, milk: S.icons.milk, drink: S.icons.drink };
      g.drawImage(map[p.item], 12, 12, 32, 32);
      if (isTouch && Math.floor(blinkT * 3) % 2) {
        text("TAP!", 28, 56, 9, "#ffd23c", "center", "#000", 3);
      }
    } else {
      text("?", 28, 29, 20, "rgba(255,255,255,0.25)");
    }

    /* lap + time */
    var lapShow = CK.clamp(p.lap, 1, game.LAPS);
    text("LAP " + lapShow + "/" + game.LAPS, W / 2, 16, 14, "#ffffff", "center", "#000", 4);
    text(fmtTime(game.getTime()), W / 2, 32, 10, "#c8d0e0", "center", "#000", 3);

    /* rank */
    var rc = p.rank === 1 ? "#ffd23c" : p.rank <= 3 ? "#c8d0e0" : "#e88a5a";
    text(ordinal(p.rank), W - 34, 26, 26, rc, "center", "#000", 6);

    /* minimap */
    var mm = T.getMinimap();
    var ms = 62;
    var mx = W - ms - 8, my = H - ms - 8;
    g.globalAlpha = 0.9;
    g.drawImage(mm, mx, my, ms, ms);
    g.globalAlpha = 1;
    var karts = game.getKarts();
    for (var i = 0; i < karts.length; i++) {
      var k = karts[i];
      var dx = mx + k.x / T.WORLD * ms;
      var dy = my + k.y / T.WORLD * ms;
      g.fillStyle = k.isPlayer ? "#ffd23c" : "#e85a5a";
      g.beginPath();
      g.arc(dx, dy, k.isPlayer ? 3 : 2, 0, CK.TAU);
      g.fill();
      if (k.isPlayer) { g.strokeStyle = "#000"; g.lineWidth = 1; g.stroke(); }
    }

    /* countdown */
    var st = game.getState();
    if (st === "countdown") {
      var c = game.getCountdown();
      var n = Math.ceil(c - 0.2);
      if (n >= 1 && n <= 3) {
        var frac = (c - 0.2) - Math.floor(c - 0.2);
        text("" + n, W / 2, H / 2 - 20, 60 + frac * 14, "#ffd23c", "center", "#802010", 10);
      } else if (n <= 0) {
        text("GO!", W / 2, H / 2 - 20, 64, "#5ae06a", "center", "#104020", 10);
      }
    } else if (game.getTime() < 1.0) {
      text("GO!", W / 2, H / 2 - 20, 64, "#5ae06a", "center", "#104020", 10);
    }

    /* final lap banner */
    if (p.lap === game.LAPS && lastLap !== game.LAPS) {
      lastLap = game.LAPS;
      finalLapT = 2.2;
    }
    if (finalLapT > 0) {
      finalLapT -= dt;
      if (Math.floor(finalLapT * 6) % 2 === 0) {
        text("FINAL LAP!", W / 2, 72, 24, "#ff5050", "center", "#400808", 6);
      }
    }

    /* wrong way */
    if (p.wrongWayT > 0.9 && Math.floor(blinkT * 4) % 2 === 0) {
      text("WRONG WAY!", W / 2, H / 2 - 50, 22, "#ff5050", "center", "#400808", 6);
    }

    blinkT += dt;
  }

  function drawRace(dt, edges) {
    var game = CK.game;
    game.update(dt, edges);
    CK.render.render(game.getCam(), game.getDrawables());
    drawHUD(dt);

    if (game.getState() === "finished") {
      finishedT += dt;
      text("FINISH!", W / 2, H / 2 - 20, 44, "#ffd23c", "center", "#802010", 9);
      if (finishedT > 2.6) {
        screen = "results";
        setTouchUI(false);
      }
    }
  }

  /* ---------------- results ---------------- */

  function drawResults(dt, edges) {
    var game = CK.game;
    /* keep world going behind panel */
    game.update(dt, { item: false, anyKey: false });
    CK.render.render(game.getCam(), game.getDrawables());
    g.fillStyle = "rgba(8,8,16,0.6)";
    g.fillRect(0, 0, W, H);
    blinkT += dt;

    text("RACE RESULTS", W / 2, 24, 20, "#ffd23c", "center", "#502010", 5);

    var karts = game.getKarts().slice().sort(function (a, b) { return a.rank - b.rank; });
    panel(W / 2 - 130, 40, 260, 168, 8);
    for (var i = 0; i < karts.length; i++) {
      var k = karts[i];
      var y = 58 + i * 26;
      var medal = i === 0 ? "#ffd23c" : i === 1 ? "#c8d0da" : i === 2 ? "#d8955a" : "#5a6070";
      g.fillStyle = medal;
      g.beginPath(); g.arc(W / 2 - 108, y, 9, 0, CK.TAU); g.fill();
      text("" + (i + 1), W / 2 - 108, y + 1, 11, "#1a1a20");
      var S = CK.sprites;
      g.drawImage(S.portraits[k.charIdx], W / 2 - 94, y - 12, 24, 24);
      text(k.name, W / 2 - 64, y, 12, k.isPlayer ? "#ffd23c" : "#ffffff", "left");
      text(k.finished ? fmtTime(k.finishT) : "--:--.--", W / 2 + 118, y, 10, "#c8d0e0", "right");
    }

    if (Math.floor(blinkT * 2) % 2 === 0) {
      text(isTouch ? "TAP TO RACE AGAIN" : "PRESS ANY KEY TO RACE AGAIN", W / 2, 234, 13, "#ffffff", "center", "#000", 4);
    }

    if (edges.anyKey || taps.length) {
      game.setIdle();
      screen = "select";
      blinkT = 0;
    }
  }

  /* ---------------- frame ---------------- */

  function frame(dt) {
    var edges = CK.consumeInputEdges();
    if (screen === "title") { drawTitle(dt, edges); }
    else if (screen === "select") { drawSelect(dt, edges); }
    else if (screen === "race") { drawRace(dt, edges); }
    else if (screen === "results") { drawResults(dt, edges); }
    taps.length = 0;
  }

  return {
    init: init,
    frame: frame,
    getScreen: function () { return screen; }
  };
})();
