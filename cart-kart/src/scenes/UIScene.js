import Phaser from 'phaser';

const MINIMAP_SCALE = 0.065;
const MINIMAP_W = 130;
const MINIMAP_H = 100;

export default class UIScene extends Phaser.Scene {
  constructor() { super({ key: 'UIScene' }); }

  init(data) {
    this.playerCharIndex = data?.playerCharIndex ?? 3;
  }

  create() {
    const { width: W, height: H } = this.scale;
    this._W = W;
    this._H = H;

    // ── Top bar (position + laps) ──────────────────────────────────
    const topBg = this.add.graphics();
    topBg.fillStyle(0x000000, 0.5);
    topBg.fillRoundedRect(4, 4, 240, 56, 8);

    this._lapText = this.add.text(14, 10, 'LAP 0/3', {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '22px',
      color: '#FFD700',
      stroke: '#000',
      strokeThickness: 4,
    });

    this._posText = this.add.text(14, 34, 'POS: 1st', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '15px',
      color: '#FFFFFF',
      stroke: '#000',
      strokeThickness: 3,
    });

    // ── Race timer ─────────────────────────────────────────────────
    const timerBg = this.add.graphics();
    timerBg.fillStyle(0x000000, 0.45);
    timerBg.fillRoundedRect(W / 2 - 70, 4, 140, 34, 8);

    this._timerText = this.add.text(W / 2, 20, '0:00.00', {
      fontFamily: 'monospace',
      fontSize: '18px',
      color: '#CCFFCC',
      stroke: '#000',
      strokeThickness: 3,
    }).setOrigin(0.5);

    // ── Held item display ─────────────────────────────────────────
    const itemBg = this.add.graphics();
    itemBg.fillStyle(0x000000, 0.5);
    itemBg.fillRoundedRect(W - 70, 4, 64, 64, 8);

    this._itemIcon = this.add.text(W - 38, 36, '', { fontSize: '32px' }).setOrigin(0.5);
    this._itemLabel = this.add.text(W - 38, 65, '', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '8px',
      color: '#CCCCCC',
    }).setOrigin(0.5);

    // ── Speedometer ───────────────────────────────────────────────
    this._speedText = this.add.text(W - 10, H - 10, '0 km/h', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '14px',
      color: '#AAFFAA',
      stroke: '#000',
      strokeThickness: 2,
    }).setOrigin(1, 1);

    // ── Minimap ───────────────────────────────────────────────────
    this._buildMinimap(W, H);

    // ── Touch controls (only if touch device) ─────────────────────
    const isTouch = window.navigator.maxTouchPoints > 0;
    if (isTouch) {
      this._buildTouchControls(W, H);
    }

    // ── Listen to game registry ────────────────────────────────────
    this.registry.events.on('changedata', this._onRegistryChange, this);

    // ── Race state overlay ─────────────────────────────────────────
    this._raceStateBanner = this.add.text(W / 2, H * 0.35, '', {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '52px',
      color: '#FFD700',
      stroke: '#000',
      strokeThickness: 8,
      alpha: 0,
    }).setOrigin(0.5).setDepth(50);

    // Minimap cart dots (updated each frame)
    this._minimapDots = [];
  }

  update() {
    this._updateMinimap();
    this._updateSpeedometer();
  }

  // ─────────────────────────────────────────────
  _onRegistryChange(parent, key, value) {
    switch (key) {
      case 'laps': {
        const total = this.registry.get('totalLaps') ?? 3;
        this._lapText.setText(`LAP ${Math.min(value, total)}/${total}`);
        break;
      }
      case 'position':
        this._posText.setText(`POS: ${this._ordinal(value)}`);
        break;
      case 'heldItem':
        this._itemIcon.setText(value?.icon ?? '');
        this._itemLabel.setText(value?.name ?? '');
        break;
      case 'raceTime': {
        const t = value;
        const mm = Math.floor(t / 60000);
        const ss = Math.floor((t % 60000) / 1000);
        const ms = Math.floor((t % 1000) / 10);
        this._timerText.setText(`${mm}:${ss.toString().padStart(2,'0')}.${ms.toString().padStart(2,'0')}`);
        break;
      }
      case 'raceState':
        if (value === 'finished') {
          this._showFinished();
        }
        break;
    }
  }

  _ordinal(n) {
    const suffixes = ['th', 'st', 'nd', 'rd'];
    const v = n % 100;
    return n + (suffixes[(v - 20) % 10] || suffixes[v] || suffixes[0]);
  }

  // ─────────────────────────────────────────────
  _buildMinimap(W, H) {
    const mx = W - MINIMAP_W - 8;
    const my = H - MINIMAP_H - 8;

    // Background
    const mmBg = this.add.graphics();
    mmBg.fillStyle(0x000000, 0.6);
    mmBg.fillRoundedRect(mx - 4, my - 4, MINIMAP_W + 8, MINIMAP_H + 8, 6);
    mmBg.lineStyle(1, 0x445566, 0.8);
    mmBg.strokeRoundedRect(mx - 4, my - 4, MINIMAP_W + 8, MINIMAP_H + 8, 6);

    // Draw mini track outline
    const mg = this.add.graphics();
    const sx = MINIMAP_W / 2000, sy = MINIMAP_H / 1600;

    // Outer rectangle
    mg.lineStyle(2, 0x667788, 0.8);
    mg.strokeRect(mx + 60 * sx, my + 60 * sy, (2000 - 120) * sx, (1600 - 120) * sy);

    // Inner island
    mg.fillStyle(0x222233);
    mg.fillRect(mx + 480 * sx, my + 440 * sy, 1070 * sx, 720 * sy);

    // Track surface hint
    mg.fillStyle(0x556677, 0.3);
    mg.fillRect(mx + 60 * sx, my + 60 * sy, (2000 - 120) * sx, (1600 - 120) * sy);

    // Chicane obstacle
    mg.fillStyle(0x8B4513, 0.8);
    mg.fillRect(mx + 970 * sx, my + 140 * sy, 180 * sx, 180 * sy);

    // Start/finish line
    mg.fillStyle(0xFFFFFF, 0.7);
    mg.fillRect(mx + 500 * sx, my + 1340 * sy, 400 * sx, 8 * sy);

    this._minimapOriginX = mx;
    this._minimapOriginY = my;
    this._minimapScaleX  = sx;
    this._minimapScaleY  = sy;
  }

  _updateMinimap() {
    const gameScene = this.scene.get('GameScene');
    if (!gameScene || !gameScene.carts) return;

    const mx = this._minimapOriginX;
    const my = this._minimapOriginY;
    const sx = this._minimapScaleX;
    const sy = this._minimapScaleY;

    // Remove old dots
    this._minimapDots.forEach(d => d.destroy());
    this._minimapDots = [];

    gameScene.carts.forEach((cart, i) => {
      if (!cart.sprite.active) return;
      const dotX = mx + cart.sprite.x * sx;
      const dotY = my + cart.sprite.y * sy;
      const color = cart.isPlayer ? 0xFFD700 : 0xFF4444;
      const dot = this.add.graphics();
      dot.fillStyle(color);
      dot.fillCircle(dotX, dotY, cart.isPlayer ? 4 : 2.5);
      this._minimapDots.push(dot);
    });
  }

  _updateSpeedometer() {
    const spd = this.registry.get('speed') ?? 0;
    // Convert to km/h equivalent (scale 300px/s → ~180 km/h)
    const kmh = Math.round(spd * 0.6);
    this._speedText.setText(`${kmh} km/h`);
  }

  // ─────────────────────────────────────────────
  _buildTouchControls(W, H) {
    // Virtual joystick (left side)
    const joyX = 90, joyY = H - 100;

    this._joyBase = this.add.image(joyX, joyY, 'joy_base').setAlpha(0.75).setDepth(60);
    this._joyKnob = this.add.image(joyX, joyY, 'joy_knob').setAlpha(0.85).setDepth(61);

    this._joyBaseX = joyX;
    this._joyBaseY = joyY;
    this._joyActive = false;
    this._joyPointerId = null;
    this._joyRadius = 46;

    // Gas button (right side, lower)
    this._gasBtn = this.add.image(W - 90, H - 100, 'btn_gas')
      .setAlpha(0.8)
      .setDepth(60)
      .setInteractive();

    // Item button (right side, upper)
    this._itemBtn = this.add.image(W - 180, H - 170, 'btn_item')
      .setAlpha(0.7)
      .setDepth(60)
      .setInteractive();

    // Gas labels
    this.add.text(W - 90, H - 100, 'GAS', {
      fontFamily: '"Arial Black"',
      fontSize: '12px',
      color: '#FFFFFF',
      stroke: '#000',
      strokeThickness: 2,
    }).setOrigin(0.5).setDepth(62);

    this.add.text(W - 180, H - 170, 'ITEM', {
      fontFamily: '"Arial Black"',
      fontSize: '10px',
      color: '#FFFFFF',
      stroke: '#000',
      strokeThickness: 2,
    }).setOrigin(0.5).setDepth(62);

    // Touch input state
    this._gasDown  = false;
    this._itemDown = false;

    // Joystick multi-touch tracking
    this.input.on('pointerdown', (ptr) => {
      if (ptr.x < W / 2) {
        // Left side = joystick
        if (!this._joyActive) {
          this._joyActive = true;
          this._joyPointerId = ptr.id;
          this._joyBaseX = ptr.x;
          this._joyBaseY = ptr.y;
          this._joyBase.setPosition(ptr.x, ptr.y);
          this._joyKnob.setPosition(ptr.x, ptr.y);
        }
      } else {
        // Right side – check which button
        if (Phaser.Math.Distance.Between(ptr.x, ptr.y, this._gasBtn.x, this._gasBtn.y) < 50) {
          this._gasDown = true;
          this._gasBtn.setAlpha(1);
        }
        if (Phaser.Math.Distance.Between(ptr.x, ptr.y, this._itemBtn.x, this._itemBtn.y) < 46) {
          this._itemDown = true;
          this._itemBtn.setAlpha(1);
          // Single fire
          this.time.delayedCall(16, () => this._itemDown = false);
        }
      }
      this._pushTouchInput();
    });

    this.input.on('pointermove', (ptr) => {
      if (!this._joyActive || ptr.id !== this._joyPointerId) return;
      const dx = ptr.x - this._joyBaseX;
      const dy = ptr.y - this._joyBaseY;
      const len = Math.sqrt(dx * dx + dy * dy);
      const clamped = Math.min(len, this._joyRadius);
      const nx = dx / (len || 1);
      const ny = dy / (len || 1);
      this._joyKnob.setPosition(
        this._joyBaseX + nx * clamped,
        this._joyBaseY + ny * clamped,
      );
      this._joySteerX = dx / this._joyRadius;
      this._joySteerY = dy / this._joyRadius;
      // Gas from upper joystick push
      if (this._joySteerY < -0.4) this._gasDown = true;
      else this._gasDown = false;
      this._pushTouchInput();
    });

    this.input.on('pointerup', (ptr) => {
      if (ptr.id === this._joyPointerId) {
        this._joyActive = false;
        this._joyPointerId = null;
        this._joyKnob.setPosition(this._joyBaseX, this._joyBaseY);
        this._joySteerX = 0;
        this._joySteerY = 0;
        this._gasDown = false;
      }
      if (ptr.x >= this._W / 2) {
        if (Phaser.Math.Distance.Between(ptr.x, ptr.y, this._gasBtn.x, this._gasBtn.y) < 60) {
          this._gasDown = false;
          this._gasBtn.setAlpha(0.8);
        }
      }
      this._pushTouchInput();
    });
  }

  _pushTouchInput() {
    this.registry.set('touchInput', {
      steerX: this._joySteerX ?? 0,
      steerY: this._joySteerY ?? 0,
      gas:    this._gasDown  ?? false,
      useItem: this._itemDown ?? false,
    });
  }

  // ─────────────────────────────────────────────
  _showFinished() {
    // Handled by GameScene overlay
  }
}
