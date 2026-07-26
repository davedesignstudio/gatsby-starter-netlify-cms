/* Cart Kart: Aisle Racers — shared helpers */
"use strict";

var CK = window.CK = {};

CK.TAU = Math.PI * 2;

CK.clamp = function (v, lo, hi) {
  return v < lo ? lo : (v > hi ? hi : v);
};

CK.lerp = function (a, b, t) {
  return a + (b - a) * t;
};

/* shortest signed angle from a to b, in (-PI, PI] */
CK.angDiff = function (a, b) {
  var d = (b - a) % CK.TAU;
  if (d > Math.PI) d -= CK.TAU;
  if (d < -Math.PI) d += CK.TAU;
  return d;
};

CK.dist2 = function (ax, ay, bx, by) {
  var dx = bx - ax, dy = by - ay;
  return dx * dx + dy * dy;
};

/* deterministic-ish rng so track decorations are stable per load */
CK.makeRng = function (seed) {
  var s = seed >>> 0;
  return function () {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
};

CK.pick = function (rng, arr) {
  return arr[Math.floor(rng() * arr.length) % arr.length];
};

/* Catmull-Rom interpolation of a closed loop of points [{x,y},...] */
CK.catmullRom = function (pts, t) {
  var n = pts.length;
  var f = t * n;
  var i = Math.floor(f);
  var u = f - i;
  var p0 = pts[(i - 1 + n) % n];
  var p1 = pts[i % n];
  var p2 = pts[(i + 1) % n];
  var p3 = pts[(i + 2) % n];
  var u2 = u * u, u3 = u2 * u;
  return {
    x: 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * u +
      (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * u2 +
      (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * u3),
    y: 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * u +
      (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * u2 +
      (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * u3)
  };
};

/* ---------------- input ---------------- */

CK.input = {
  left: false,
  right: false,
  drift: false,
  item: false,      /* edge-triggered: consumed once per frame */
  accel: true,      /* auto-accelerate; keyboard can brake */
  brake: false,
  anyKey: false,    /* edge-triggered: menu advance */
  leftTap: false,   /* edge-triggered: menu nav */
  rightTap: false,
  confirm: false    /* edge-triggered: menu confirm */
};

CK.initInput = function () {
  var inp = CK.input;
  var keymap = {
    ArrowLeft: "left", a: "left", A: "left",
    ArrowRight: "right", d: "right", D: "right",
    ArrowDown: "brake", s: "brake", S: "brake",
    Shift: "drift", " ": "drift",
    x: "item", X: "item", ArrowUp: "item2"
  };

  window.addEventListener("keydown", function (e) {
    if (e.repeat) { return; }
    inp.anyKey = true;
    var k = keymap[e.key];
    if (k === "item") { inp.item = true; }
    else if (k && k !== "item2") { inp[k] = true; }
    if (k === "left") { inp.leftTap = true; }
    if (k === "right") { inp.rightTap = true; }
    if (e.key === "Enter" || e.key === " " || e.key === "Shift") { inp.confirm = true; }
    if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", " "].indexOf(e.key) >= 0) {
      e.preventDefault();
    }
  });

  window.addEventListener("keyup", function (e) {
    var k = keymap[e.key];
    if (k && k !== "item" && k !== "item2") { inp[k] = false; }
  });

  function bindBtn(id, prop) {
    var el = document.getElementById(id);
    if (!el) { return; }
    var press = function (e) {
      e.preventDefault();
      el.classList.add("pressed");
      if (prop === "item") { inp.item = true; }
      else { inp[prop] = true; }
      inp.anyKey = true;
    };
    var release = function (e) {
      e.preventDefault();
      el.classList.remove("pressed");
      if (prop !== "item") { inp[prop] = false; }
    };
    el.addEventListener("touchstart", press, { passive: false });
    el.addEventListener("touchend", release, { passive: false });
    el.addEventListener("touchcancel", release, { passive: false });
    el.addEventListener("mousedown", press);
    el.addEventListener("mouseup", release);
    el.addEventListener("mouseleave", release);
  }

  bindBtn("btn-left", "left");
  bindBtn("btn-right", "right");
  bindBtn("btn-drift", "drift");
  bindBtn("btn-item", "item");

  /* taps anywhere advance menus */
  window.addEventListener("touchstart", function () { inp.anyKey = true; }, { passive: true });
  window.addEventListener("mousedown", function () { inp.anyKey = true; });
};

/* consume edge-triggered flags once per frame */
CK.consumeInputEdges = function () {
  var i = CK.input;
  var r = { item: i.item, anyKey: i.anyKey, leftTap: i.leftTap, rightTap: i.rightTap, confirm: i.confirm };
  i.item = false;
  i.anyKey = false;
  i.leftTap = false;
  i.rightTap = false;
  i.confirm = false;
  return r;
};
