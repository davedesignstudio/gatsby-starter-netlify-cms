/* Cart Kart — boot, resize, main loop */
"use strict";

(function () {
  var canvas = document.getElementById("game");

  /* roundRect fallback for older WebKit */
  if (!CanvasRenderingContext2D.prototype.roundRect) {
    CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h, r) {
      if (typeof r === "number") { r = [r, r, r, r]; }
      this.moveTo(x + r[0], y);
      this.arcTo(x + w, y, x + w, y + h, r[1]);
      this.arcTo(x + w, y + h, x, y + h, r[2]);
      this.arcTo(x, y + h, x, y, r[3]);
      this.arcTo(x, y, x + w, y, r[0]);
      this.closePath();
      return this;
    };
  }

  function resize() {
    var vw = window.innerWidth, vh = window.innerHeight;
    var scale = Math.min(vw / 480, vh / 270);
    canvas.style.width = Math.floor(480 * scale) + "px";
    canvas.style.height = Math.floor(270 * scale) + "px";

    var isTouch = ("ontouchstart" in window) || navigator.maxTouchPoints > 0;
    var portrait = vh > vw;
    var overlay = document.getElementById("rotate-overlay");
    overlay.classList.toggle("show", isTouch && portrait);
  }

  window.addEventListener("resize", resize);
  window.addEventListener("orientationchange", function () {
    setTimeout(resize, 250);
  });

  /* block iOS Safari double-tap zoom & scroll */
  document.addEventListener("touchmove", function (e) { e.preventDefault(); }, { passive: false });
  var lastTouch = 0;
  document.addEventListener("touchend", function (e) {
    var now = Date.now();
    if (now - lastTouch < 350) { e.preventDefault(); }
    lastTouch = now;
  }, { passive: false });

  function boot() {
    CK.sprites.init();
    CK.track.init();
    CK.render.init(canvas);
    CK.ui.init(canvas);
    CK.initInput();
    resize();

    var last = performance.now();
    function loop(now) {
      var dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      CK.ui.frame(dt);
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
