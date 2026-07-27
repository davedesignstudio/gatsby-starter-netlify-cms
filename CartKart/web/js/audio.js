export class AudioManager {
  constructor() {
    this.ctx = null;
    this.enabled = true;
    this.musicOsc = null;
    this.musicGain = null;
  }

  init() {
    if (this.ctx) return;
    this.ctx = new (window.AudioContext || window.webkitAudioContext)();
  }

  resume() {
    this.init();
    if (this.ctx?.state === 'suspended') this.ctx.resume();
  }

  tone(freq, duration, volume = 0.3, type = 'sine') {
    if (!this.enabled) return;
    this.resume();
    const t0 = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(volume, t0);
    gain.gain.exponentialRampToValueAtTime(0.001, t0 + duration);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(t0);
    osc.stop(t0 + duration);
  }

  play(name) {
    const map = {
      countdown: [440, 0.12, 0.25],
      go: [880, 0.25, 0.35],
      boost: [660, 0.18, 0.3],
      item: [523, 0.15, 0.28],
      collision: [180, 0.2, 0.4, 'square'],
      spin: [250, 0.3, 0.3],
      lap: [740, 0.22, 0.32],
      finish: [988, 0.5, 0.4],
      menu: [392, 0.08, 0.2],
      squeak: [700, 0.1, 0.15],
    };
    const args = map[name];
    if (args) this.tone(...args);
  }

  startMusic() {
    if (!this.enabled || this.musicOsc) return;
    this.resume();
    this.musicGain = this.ctx.createGain();
    this.musicGain.gain.value = 0.06;
    this.musicGain.connect(this.ctx.destination);
    this.musicOsc = this.ctx.createOscillator();
    this.musicOsc.type = 'triangle';
    this.musicOsc.frequency.value = 196;
    this.musicOsc.connect(this.musicGain);
    this.musicOsc.start();
  }

  stopMusic() {
    if (this.musicOsc) {
      this.musicOsc.stop();
      this.musicOsc = null;
      this.musicGain = null;
    }
  }
}
