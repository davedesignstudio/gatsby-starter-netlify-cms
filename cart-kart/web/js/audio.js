/* Cart Kart — procedural WebAudio: engine, sfx, tiny music loop */
"use strict";

CK.audio = (function () {
  var ctx = null;
  var master = null;
  var engineOsc = null, engineGain = null, engineOsc2 = null;
  var rattleNoise = null, rattleGain = null, rattleFilter = null;
  var musicTimer = null, musicStep = 0;
  var muted = false;

  function ensure() {
    if (ctx) {
      if (ctx.state === "suspended") { ctx.resume(); }
      return true;
    }
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) { return false; }
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.5;
    master.connect(ctx.destination);
    return true;
  }

  function noiseBuffer(seconds) {
    var len = Math.floor(ctx.sampleRate * seconds);
    var buf = ctx.createBuffer(1, len, ctx.sampleRate);
    var d = buf.getChannelData(0);
    for (var i = 0; i < len; i++) { d[i] = Math.random() * 2 - 1; }
    return buf;
  }

  /* --- engine: two detuned saws + wheel-rattle noise, pitch follows speed --- */
  function startEngine() {
    if (!ensure() || engineOsc) { return; }
    engineGain = ctx.createGain();
    engineGain.gain.value = 0.0;
    engineGain.connect(master);

    engineOsc = ctx.createOscillator();
    engineOsc.type = "sawtooth";
    engineOsc.frequency.value = 40;
    engineOsc2 = ctx.createOscillator();
    engineOsc2.type = "square";
    engineOsc2.frequency.value = 41;
    var lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = 500;
    engineOsc.connect(lp);
    engineOsc2.connect(lp);
    lp.connect(engineGain);
    engineOsc.start();
    engineOsc2.start();

    rattleNoise = ctx.createBufferSource();
    rattleNoise.buffer = noiseBuffer(1.0);
    rattleNoise.loop = true;
    rattleFilter = ctx.createBiquadFilter();
    rattleFilter.type = "bandpass";
    rattleFilter.frequency.value = 3000;
    rattleFilter.Q.value = 1.2;
    rattleGain = ctx.createGain();
    rattleGain.gain.value = 0.0;
    rattleNoise.connect(rattleFilter);
    rattleFilter.connect(rattleGain);
    rattleGain.connect(master);
    rattleNoise.start();
  }

  function stopEngine() {
    if (!engineOsc) { return; }
    try {
      engineOsc.stop(); engineOsc2.stop(); rattleNoise.stop();
    } catch (e) { /* already stopped */ }
    engineOsc = engineOsc2 = rattleNoise = null;
  }

  /* speed01: 0..1, boost: bool */
  function engine(speed01, boosting) {
    if (!engineOsc || muted) { return; }
    var f = 34 + speed01 * 100 + (boosting ? 30 : 0);
    engineOsc.frequency.setTargetAtTime(f, ctx.currentTime, 0.05);
    engineOsc2.frequency.setTargetAtTime(f * 1.013, ctx.currentTime, 0.05);
    engineGain.gain.setTargetAtTime(0.05 + speed01 * 0.075, ctx.currentTime, 0.08);
    rattleGain.gain.setTargetAtTime(speed01 * 0.05, ctx.currentTime, 0.1);
    rattleFilter.frequency.setTargetAtTime(2000 + speed01 * 3000, ctx.currentTime, 0.1);
  }

  function blip(freq, dur, type, vol, slideTo) {
    if (!ensure() || muted) { return; }
    var o = ctx.createOscillator();
    var g = ctx.createGain();
    o.type = type || "square";
    o.frequency.value = freq;
    if (slideTo) { o.frequency.exponentialRampToValueAtTime(slideTo, ctx.currentTime + dur); }
    g.gain.value = vol || 0.16;
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + dur);
    o.connect(g); g.connect(master);
    o.start(); o.stop(ctx.currentTime + dur);
  }

  function thud(vol) {
    if (!ensure() || muted) { return; }
    var src = ctx.createBufferSource();
    src.buffer = noiseBuffer(0.18);
    var f = ctx.createBiquadFilter();
    f.type = "lowpass"; f.frequency.value = 380;
    var g = ctx.createGain();
    g.gain.value = vol || 0.4;
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.18);
    src.connect(f); f.connect(g); g.connect(master);
    src.start();
  }

  var sfx = {
    countBeep: function () { blip(440, 0.12, "square", 0.2); },
    countGo: function () { blip(880, 0.4, "square", 0.22); },
    pickup: function () { blip(660, 0.09, "triangle", 0.2, 1320); },
    boost: function () { blip(220, 0.5, "sawtooth", 0.2, 880); },
    throwItem: function () { blip(500, 0.12, "square", 0.15, 250); },
    spin: function () { blip(700, 0.35, "sawtooth", 0.2, 120); },
    bump: function () { thud(0.45); },
    splash: function () { thud(0.25); blip(300, 0.2, "sine", 0.12, 90); },
    lap: function () { blip(523, 0.1, "square", 0.18); setTimeout(function () { blip(784, 0.16, "square", 0.18); }, 110); },
    finish: function () {
      [523, 659, 784, 1047].forEach(function (f, i) {
        setTimeout(function () { blip(f, 0.22, "square", 0.2); }, i * 140);
      });
    },
    roulette: function () { blip(880, 0.04, "square", 0.08); }
  };

  /* --- tiny music loop: bass + lead, jaunty supermarket-muzak-goes-racing --- */
  var BASS = [0, 0, 7, 0, 5, 5, 3, 5];                 /* semitones from A2 */
  var LEAD = [12, 16, 19, 16, 24, 19, 16, 12, 14, 17, 21, 17, 26, 21, 17, 14];

  function note(semis, base) { return base * Math.pow(2, semis / 12); }

  function startMusic() {
    if (!ensure() || musicTimer) { return; }
    musicStep = 0;
    musicTimer = setInterval(function () {
      if (muted || !ctx) { return; }
      var s = musicStep++;
      blip(note(BASS[s % 8], 110), 0.14, "triangle", 0.11);
      if (s % 2 === 0) {
        blip(note(LEAD[(s / 2) % 16], 110), 0.1, "square", 0.05);
      }
    }, 150);
  }

  function stopMusic() {
    if (musicTimer) { clearInterval(musicTimer); musicTimer = null; }
  }

  return {
    ensure: ensure,
    startEngine: startEngine,
    stopEngine: stopEngine,
    engine: engine,
    startMusic: startMusic,
    stopMusic: stopMusic,
    sfx: sfx,
    setMuted: function (m) {
      muted = m;
      if (master) { master.gain.value = m ? 0 : 0.5; }
    },
    isMuted: function () { return muted; }
  };
})();
