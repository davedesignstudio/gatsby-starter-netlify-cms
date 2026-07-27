import {
  TRACKS, CHARACTERS, CUPS, TOTAL_LAPS, getTrack,
} from './data.js';
import { AudioManager } from './audio.js';
import { Input } from './input.js';
import {
  createRacer, applyInput, updateRacer, checkCheckpoint,
  deployItem, hitHazard, collectItemBox,
} from './racer.js';
import { updateAI } from './ai.js';
import {
  drawTrack, drawItemBoxes, drawHazards, drawRacer, drawHUD, drawTouchControls, formatTime,
} from './renderer.js';
import {
  isMobile, getPixelRatio, WakeLock, lockLandscape, unlockOrientation, vibrate,
} from './platform.js';

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.input = new Input(canvas);
    this.audio = new AudioManager();
    this.wakeLock = new WakeLock();
    this.mobile = isMobile;
    this.paused = false;
    this.state = 'menu';
    this.resize();
    window.addEventListener('resize', () => this.resize());
    window.addEventListener('orientationchange', () => this.resize());
    document.addEventListener('visibilitychange', () => this.onVisibilityChange());

    this.settings = {
      trackIndex: 0,
      charIndex: 0,
      cupIndex: 0,
      gameMode: 'quick',
      twoPlayer: false,
    };

    this.cupSession = null;
    this.race = null;
    this.menuRects = {};
    this.last = performance.now();

    this.canvas.addEventListener('click', (e) => this.onMenuClick(e));
  }

  onVisibilityChange() {
    if (document.hidden) {
      this.paused = true;
      this.audio.stopMusic();
      this.wakeLock.release();
    } else if (this.state === 'menu' || this.state === 'results' || this.state === 'cupresults') {
      this.paused = false;
      this.audio.startMusic();
    } else if (this.state === 'race') {
      this.paused = false;
      this.wakeLock.request();
    }
  }

  resize() {
    const dpr = getPixelRatio();
    const w = this.canvas.clientWidth || window.innerWidth;
    const h = this.canvas.clientHeight || window.innerHeight;
    if (w < 1 || h < 1) return;
    this.canvas.width = Math.round(w * dpr);
    this.canvas.height = Math.round(h * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.w = w;
    this.h = h;
  }

  start() {
    this.audio.startMusic();
    requestAnimationFrame((t) => this.loop(t));
  }

  loop(now) {
    if (this.paused) {
      this.last = now;
      requestAnimationFrame((t) => this.loop(t));
      return;
    }

    const dt = Math.min((now - this.last) / 1000, this.mobile ? 0.04 : 0.05);
    this.last = now;

    const menuTap = this.input.takeMenuTap();
    if (menuTap && (this.state === 'menu' || this.state === 'results' || this.state === 'cupresults')) {
      this.audio.play('menu');
      this.handleMenuAction(menuTap);
    }

    if (this.state === 'menu') this.updateMenu();
    else if (this.state === 'race') this.updateRace(dt);
    else if (this.state === 'results') this.updateResults();
    else if (this.state === 'cupresults') this.updateCupResults();

    this.render();
    requestAnimationFrame((t) => this.loop(t));
  }

  onMenuClick(e) {
    if (this.state !== 'menu' && this.state !== 'results' && this.state !== 'cupresults') return;
    const r = this.canvas.getBoundingClientRect();
    const x = (e.clientX - r.left) * (this.w / r.width);
    const y = (e.clientY - r.top) * (this.h / r.height);
    const hit = Object.entries(this.menuRects).find(([, rect]) => x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h);
    if (!hit) return;
    this.audio.play('menu');
    this.handleMenuAction(normalizeMenuAction(hit[0]));
  }

  handleMenuAction(action) {
    if (action === 'start') {
      if (this.settings.gameMode === 'cup') this.beginCup();
      this.startRace();
      return;
    }
    if (action === 'menu') {
      this.state = 'menu';
      this.cupSession = null;
      this.audio.startMusic();
      this.wakeLock.release();
      unlockOrientation();
      return;
    }
    if (action === 'retry') {
      if (this.cupSession && !this.cupSession.done) { this.startRace(getTrack(this.cupSession.nextTrackId())); return; }
      this.startRace();
      return;
    }
    if (action === 'gamemode') this.settings.gameMode = this.settings.gameMode === 'quick' ? 'cup' : 'quick';
    if (action === 'track') this.settings.trackIndex = (this.settings.trackIndex + 1) % TRACKS.length;
    if (action === 'character') this.settings.charIndex = (this.settings.charIndex + 1) % CHARACTERS.length;
    if (action === 'cup') this.settings.cupIndex = (this.settings.cupIndex + 1) % CUPS.length;
    if (action === 'players') this.settings.twoPlayer = !this.settings.twoPlayer;
  }

  beginCup() {
    const cup = CUPS[this.settings.cupIndex];
    const names = this.settings.twoPlayer
      ? [CHARACTERS[this.settings.charIndex].name, CHARACTERS[(this.settings.charIndex + 1) % CHARACTERS.length].name, 'Rusty Ron', 'Cart Carl']
      : [CHARACTERS[this.settings.charIndex].name, 'Rusty Ron', 'Cart Carl', 'Wheels Wendy'];
    this.cupSession = {
      cup,
      raceIndex: 0,
      done: false,
      standings: names.map((n, i) => ({ name: n, points: 0, human: i < (this.settings.twoPlayer ? 2 : 1) })),
      nextTrackId() { return cup.trackIds[this.raceIndex]; },
    };
  }

  startRace(trackOverride = null) {
    const track = trackOverride || (this.cupSession ? getTrack(this.cupSession.nextTrackId()) : TRACKS[this.settings.trackIndex]);
    const aiChars = [CHARACTERS[1], CHARACTERS[2], CHARACTERS[3], CHARACTERS[4]];
    const humans = this.settings.twoPlayer ? 2 : 1;
    const racers = [];

    for (let i = 0; i < 4; i++) {
      const isHuman = i < humans;
      const ch = isHuman
        ? CHARACTERS[(this.settings.charIndex + i) % CHARACTERS.length]
        : aiChars[(i - humans) % aiChars.length];
      const racer = createRacer(ch, { isPlayer: isHuman, slot: i });
      const start = track.starts[i];
      racer.x = start.x;
      racer.y = start.y;
      racer.angle = start.a;
      racers.push(racer);
    }

    this.race = {
      track,
      racers,
      humans: racers.filter((r) => r.isPlayer),
      itemBoxes: track.items.map((p) => ({ ...p, active: true })),
      hazards: [],
      time: 0,
      countdown: 3,
      countdownTimer: 0,
      started: false,
      finished: [],
      cam: { x: this.w / 2, y: this.h / 2, zoom: 0.55 },
      pulse: 0,
    };
    this.state = 'race';
    this.audio.stopMusic();
    this.audio.play('countdown');
    this.wakeLock.request();
    if (this.mobile) lockLandscape();
  }

  updateRace(dt) {
    const race = this.race;
    race.pulse += dt;

    if (!race.started) {
      race.countdownTimer += dt;
      if (race.countdownTimer >= 1) {
        race.countdownTimer = 0;
        race.countdown -= 1;
        if (race.countdown > 0) this.audio.play('countdown');
        else if (race.countdown === 0) { this.audio.play('go'); race.countdown = 'GO!'; }
        else { race.started = true; race.countdown = 0; }
      }
      return;
    }

    race.time += dt;

    const player = race.humans[0];
    const inp = this.input.getPlayerInput();
    const used = applyInput(player, inp);
    if (used) {
      const fx = deployItem(used, player, race.racers, race.hazards);
      if (fx === 'boost') {
        this.audio.play('boost');
        vibrate(20);
      }
    }

    for (const racer of race.racers) {
      if (!racer.isPlayer) {
        const aiItem = updateAI(racer, race.track, race.racers, dt);
        if (aiItem) deployItem(aiItem, racer, race.racers, race.hazards);
      }
      const hit = updateRacer(racer, dt, race.track);
      if (hit === 'collision' && racer.isPlayer) {
        this.audio.play('collision');
        vibrate(35);
      }

      const lapEvt = checkCheckpoint(racer, race.track);
      if (lapEvt === 'lap' && racer.isPlayer) this.audio.play('lap');

      if (racer.lap >= TOTAL_LAPS && !racer.finished) {
        racer.finished = true;
        racer.finishTime = race.time;
        racer.speed = 0;
        race.finished.push(racer);
        if (racer.isPlayer) {
          this.audio.play('finish');
          vibrate([30, 40, 30]);
        }
      }
    }

    this.updatePositions();
    this.checkCollisions();

    const cx = race.humans.reduce((s, r) => s + r.x, 0) / race.humans.length;
    const cy = race.humans.reduce((s, r) => s + r.y, 0) / race.humans.length;
    const targetZoom = Math.min(this.w, this.h) / 1800;
    race.cam.zoom += (targetZoom - race.cam.zoom) * 0.05;
    race.cam.x += (this.w / 2 - cx * race.cam.zoom - race.cam.x) * 0.1;
    race.cam.y += (this.h / 2 - cy * race.cam.zoom - race.cam.y) * 0.1;

    const humansDone = race.humans.every((r) => r.finished);
    if (humansDone || race.finished.length === race.racers.length) {
      if (this.cupSession) this.recordCupRace();
      this.results = { order: race.finished, time: race.time };
      this.state = this.cupSession?.done ? 'cupresults' : 'results';
      this.audio.startMusic();
      this.wakeLock.release();
      unlockOrientation();
    }
  }

  recordCupRace() {
    const session = this.cupSession;
    const cup = session.cup;
    this.race.finished.forEach((racer, i) => {
      if (i >= cup.points.length) return;
      const pts = cup.points[i];
      let standing = session.standings.find((s) => s.name === racer.name);
      if (!standing) standing = session.standings.find((s) => s.human);
      if (standing) standing.points += pts;
    });
    session.raceIndex += 1;
    session.done = session.raceIndex >= cup.trackIds.length;
  }

  updatePositions() {
    const sorted = [...this.race.racers].sort((a, b) => {
      if (a.lap !== b.lap) return b.lap - a.lap;
      if (a.checkpoint !== b.checkpoint) return b.checkpoint - a.checkpoint;
      const acp = this.race.track.checkpoints[a.checkpoint % 4];
      const bcp = this.race.track.checkpoints[b.checkpoint % 4];
      return Math.hypot(a.x - acp.x, a.y - acp.y) - Math.hypot(b.x - bcp.x, b.y - bcp.y);
    });
    sorted.forEach((r, i) => { r.position = i + 1; });
  }

  checkCollisions() {
    const race = this.race;
    for (const racer of race.racers) {
      for (const box of race.itemBoxes) {
        if (!box.active) continue;
        if (Math.hypot(racer.x - box.x, racer.y - box.y) < 40) {
          box.active = false;
          collectItemBox(racer);
          this.audio.play('item');
          setTimeout(() => { box.active = true; }, 4000);
        }
      }
      for (let i = race.hazards.length - 1; i >= 0; i--) {
        const h = race.hazards[i];
        if (Math.hypot(racer.x - h.x, racer.y - h.y) < h.r + 10) {
          hitHazard(racer, h);
          this.audio.play('spin');
          race.hazards.splice(i, 1);
        }
      }
    }
  }

  updateMenu() {}
  updateResults() {}
  updateCupResults() {}

  render() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.w, this.h);

    if (this.state === 'menu') this.renderMenu(ctx);
    else if (this.state === 'race') this.renderRace(ctx);
    else if (this.state === 'results') this.renderResults(ctx);
    else if (this.state === 'cupresults') this.renderCupResults(ctx);
  }

  renderMenu(ctx) {
    const g = ctx.createLinearGradient(0, 0, 0, this.h);
    g.addColorStop(0, '#141a24');
    g.addColorStop(1, '#0d1118');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, this.w, this.h);

    ctx.fillStyle = '#c7bfb3';
    ctx.fillRect(0, this.h * 0.55, this.w, this.h * 0.45);

    ctx.fillStyle = '#ffd033';
    ctx.font = '800 48px Avenir, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('CART KART', this.w / 2, this.h * 0.18);
    ctx.fillStyle = '#d7e2ee';
    ctx.font = '600 18px Avenir, system-ui, sans-serif';
    ctx.fillText('Grocery Gauntlet — Web Edition', this.w / 2, this.h * 0.18 + 34);

    const ch = CHARACTERS[this.settings.charIndex];
    ctx.font = '64px serif';
    ctx.fillText('🛒', this.w / 2, this.h * 0.34);
    ctx.font = '28px serif';
    ctx.fillText(ch.emoji, this.w / 2 + 50, this.h * 0.34 - 20);

    const mobile = this.mobile;
    const rowW = mobile ? Math.min(340, this.w - 40) : 310;
    const rowH = mobile ? 44 : 38;
    const rows = [
      ['gamemode', `Mode: ${this.settings.gameMode === 'cup' ? 'Cup Mode' : 'Quick Race'}`],
      ['character', `Rider: ${ch.emoji} ${ch.name}`],
      ...(this.settings.gameMode === 'cup'
        ? [['cup', `Cup: ${CUPS[this.settings.cupIndex].emoji} ${CUPS[this.settings.cupIndex].name}`]]
        : [['track', `Track: ${TRACKS[this.settings.trackIndex].emoji} ${TRACKS[this.settings.trackIndex].name}`]]),
      ['players', `Players: ${this.settings.twoPlayer ? '2 Players' : '1 Player'}`],
    ];

    this.menuRects = {};
    let y = this.h * (mobile ? 0.4 : 0.42);
    rows.forEach(([id, text]) => {
      const rect = { x: this.w / 2 - rowW / 2, y: y - rowH / 2 + 2, w: rowW, h: rowH };
      this.menuRects[id] = rect;
      roundRect(ctx, rect.x, rect.y, rect.w, rect.h, 10);
      ctx.fillStyle = 'rgba(255,255,255,0.08)';
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.2)';
      ctx.stroke();
      ctx.fillStyle = '#fff';
      ctx.font = '500 14px Avenir, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(text, this.w / 2, y + 5);
      y += rowH + 8;
    });

    const startRect = { x: this.w / 2 - rowW / 2, y: y + 10, w: rowW, h: mobile ? 54 : 50 };
    this.menuRects.start = startRect;
    roundRect(ctx, startRect.x, startRect.y, startRect.w, startRect.h, 14);
    ctx.fillStyle = '#2e9ef2';
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = '700 18px Avenir, system-ui, sans-serif';
    ctx.fillText('START RACE', this.w / 2, y + 40);

    ctx.fillStyle = 'rgba(255,255,255,0.45)';
    ctx.font = `${mobile ? 11 : 12}px Avenir, system-ui, sans-serif`;
    if (mobile) {
      ctx.fillText('Tap rows to change settings • Landscape recommended', this.w / 2, this.h - 24);
      ctx.fillText('Joystick + GO / DRIFT / ITEM during races', this.w / 2, this.h - 8);
    } else {
      ctx.fillText('Keyboard: WASD/Arrows • Space=GO • Shift=DRIFT • E=Item', this.w / 2, this.h - 24);
      ctx.fillText('6 tracks • 5 characters • cup mode • touch controls', this.w / 2, this.h - 8);
    }
    this.input.setTouchRects(toTouchMenuRects(this.menuRects));
  }

  renderRace(ctx) {
    const race = this.race;
    ctx.fillStyle = race.track.dark ? '#0a0c12' : '#1a1c22';
    ctx.fillRect(0, 0, this.w, this.h);

    drawTrack(ctx, race.track, race.cam);
    drawItemBoxes(ctx, race.itemBoxes.filter((b) => b.active), race.cam, race.pulse);
    drawHazards(ctx, race.hazards, race.cam);
    race.racers.forEach((r) => drawRacer(ctx, r, race.cam));
    drawHUD(ctx, this.w, this.h, {
      player: race.humans[0],
      raceTime: race.time,
      countdown: race.started ? 0 : (race.countdown === 'GO!' ? 'GO!' : race.countdown),
      mobile: this.mobile,
    });
    if (this.mobile) drawTouchControls(ctx, this.w, this.h, this.input, true);
  }

  renderResults(ctx) {
    ctx.fillStyle = '#0f1218';
    ctx.fillRect(0, 0, this.w, this.h);
    ctx.fillStyle = '#ffd033';
    ctx.font = '700 32px Avenir, system-ui, sans-serif';
    ctx.textAlign = 'center';
    const title = this.cupSession && !this.cupSession.done
      ? `Cup Race ${this.cupSession.raceIndex}/${this.cupSession.cup.trackIds.length}`
      : 'RACE RESULTS';
    ctx.fillText(title, this.w / 2, 70);

    this.results.order.forEach((r, i) => {
      const y = 130 + i * 52;
      roundRect(ctx, this.w / 2 - 170, y - 20, 340, 42, 10);
      ctx.fillStyle = r.isPlayer ? 'rgba(46,158,242,0.3)' : 'rgba(255,255,255,0.08)';
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = `${r.isPlayer ? '700' : '500'} 16px Avenir, system-ui, sans-serif`;
      ctx.textAlign = 'left';
      ctx.fillText(`${i + 1}. ${r.name}`, this.w / 2 - 150, y + 5);
      ctx.textAlign = 'right';
      ctx.fillText(formatTime(r.finishTime), this.w / 2 + 150, y + 5);
    });

    if (this.cupSession && !this.cupSession.done) {
      const pts = this.cupSession.standings.map((s) => `${s.name}: ${s.points}`).join('  ');
      ctx.textAlign = 'center';
      ctx.font = '12px Avenir, system-ui, sans-serif';
      ctx.fillStyle = 'rgba(255,255,255,0.55)';
      ctx.fillText(`Cup pts — ${pts}`, this.w / 2, this.h - 120);
    }

    const btnW = this.mobile ? Math.min(280, this.w - 48) : 240;
    const btnH = this.mobile ? 50 : 46;
    this.menuRects = {};
    this.menuRects.menu = { x: this.w / 2 - btnW / 2, y: this.h - 170, w: btnW, h: btnH };
    this.menuRects.retry = { x: this.w / 2 - btnW / 2, y: this.h - 110, w: btnW, h: btnH };
    [['menu', 'MAIN MENU'], ['retry', this.cupSession && !this.cupSession.done ? 'NEXT RACE' : 'RACE AGAIN']].forEach(([id, label]) => {
      const rect = this.menuRects[id];
      roundRect(ctx, rect.x, rect.y, rect.w, rect.h, 12);
      ctx.fillStyle = id === 'retry' ? '#2e9ef2' : 'rgba(255,255,255,0.12)';
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = '700 16px Avenir, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(label, this.w / 2, rect.y + 29);
    });
    this.input.setTouchRects(toTouchMenuRects(this.menuRects));
  }

  renderCupResults(ctx) {
    ctx.fillStyle = '#0f1218';
    ctx.fillRect(0, 0, this.w, this.h);
    const cup = this.cupSession.cup;
    ctx.fillStyle = '#ffd033';
    ctx.font = '700 28px Avenir, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`${cup.emoji} ${cup.name.toUpperCase()}`, this.w / 2, 70);
    ctx.fillStyle = '#fff';
    ctx.font = '600 18px Avenir, system-ui, sans-serif';
    ctx.fillText('Final Standings', this.w / 2, 100);

    const sorted = [...this.cupSession.standings].sort((a, b) => b.points - a.points);
    sorted.forEach((s, i) => {
      const y = 140 + i * 48;
      roundRect(ctx, this.w / 2 - 170, y - 18, 340, 40, 10);
      ctx.fillStyle = s.human ? 'rgba(46,158,242,0.3)' : 'rgba(255,255,255,0.08)';
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.textAlign = 'left';
      ctx.font = `${s.human ? '700' : '500'} 15px Avenir, system-ui, sans-serif`;
      ctx.fillText(`${i + 1}. ${s.name}`, this.w / 2 - 150, y + 4);
      ctx.textAlign = 'right';
      ctx.fillText(`${s.points} pts`, this.w / 2 + 150, y + 4);
    });

    const btnW = this.mobile ? Math.min(280, this.w - 48) : 240;
    const btnH = this.mobile ? 50 : 46;
    this.menuRects = { menu: { x: this.w / 2 - btnW / 2, y: this.h - 90, w: btnW, h: btnH } };
    const rect = this.menuRects.menu;
    roundRect(ctx, rect.x, rect.y, rect.w, rect.h, 12);
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = '700 16px Avenir, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('MAIN MENU', this.w / 2, rect.y + 29);
    this.input.setTouchRects(toTouchMenuRects(this.menuRects));
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

function normalizeMenuAction(action) {
  return action.startsWith('menu_') ? action.slice(5) : action;
}

function toTouchMenuRects(menuRects) {
  const touch = {};
  for (const [key, rect] of Object.entries(menuRects)) {
    touch[`menu_${key}`] = rect;
  }
  return touch;
}
