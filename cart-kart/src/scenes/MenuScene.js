import Phaser from 'phaser';
import { CHARACTERS } from '../data/characters.js';

export default class MenuScene extends Phaser.Scene {
  constructor() { super({ key: 'MenuScene' }); }

  create() {
    const { width: W, height: H } = this.scale;

    // ── Background gradient ────────────────────────────────────────────
    const bg = this.add.graphics();
    bg.fillGradientStyle(0x1a1a2e, 0x1a1a2e, 0x16213e, 0x0f3460, 1);
    bg.fillRect(0, 0, W, H);

    // Animated store-tile checkerboard floor (subtle)
    for (let x = 0; x < W; x += 40) {
      for (let y = H * 0.6; y < H; y += 40) {
        const shade = ((Math.floor(x / 40) + Math.floor(y / 40)) % 2 === 0) ? 0x22304a : 0x1e2a40;
        const tile = this.add.graphics();
        tile.fillStyle(shade);
        tile.fillRect(x, y, 40, 40);
      }
    }

    // ── Title ─────────────────────────────────────────────────────────
    const title = this.add.text(W / 2, H * 0.15, '🛒 CART KART', {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '64px',
      color: '#FFD700',
      stroke: '#000',
      strokeThickness: 8,
      shadow: { offsetX: 4, offsetY: 4, color: '#000', blur: 8, fill: true },
    }).setOrigin(0.5);

    this.tweens.add({
      targets: title,
      y: H * 0.15 + 6,
      duration: 1200,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    });

    this.add.text(W / 2, H * 0.27, 'RACE THROUGH THE MEGA MART!', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '18px',
      color: '#87CEEB',
      stroke: '#000',
      strokeThickness: 3,
    }).setOrigin(0.5);

    // ── Demo carts rolling across screen ──────────────────────────────
    this._spawnDemoCarts(W, H);

    // ── Character select ──────────────────────────────────────────────
    this.selectedChar = 0;
    this._buildCharSelect(W, H);

    // ── Start button ──────────────────────────────────────────────────
    const startBtn = this.add.text(W / 2, H * 0.87, '▶  START RACE', {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '28px',
      color: '#FFFFFF',
      backgroundColor: '#E74C3C',
      padding: { x: 28, y: 12 },
      stroke: '#000',
      strokeThickness: 4,
    })
      .setOrigin(0.5)
      .setInteractive({ useHandCursor: true });

    startBtn.on('pointerover', () => startBtn.setStyle({ backgroundColor: '#FF6B6B' }));
    startBtn.on('pointerout',  () => startBtn.setStyle({ backgroundColor: '#E74C3C' }));
    startBtn.on('pointerdown', () => this._startRace());

    this.tweens.add({
      targets: startBtn,
      scaleX: 1.04,
      scaleY: 1.04,
      duration: 700,
      yoyo: true,
      repeat: -1,
    });

    // Keyboard shortcut
    this.input.keyboard.once('keydown-SPACE', () => this._startRace());
    this.input.keyboard.once('keydown-ENTER', () => this._startRace());

    // ── How to play hint ──────────────────────────────────────────────
    const hint = window.navigator.maxTouchPoints > 0
      ? 'Joystick: steer  |  GAS: accelerate  |  ITEM: use power-up'
      : 'Arrow / WASD: steer & go  |  SPACE: use power-up';

    this.add.text(W / 2, H * 0.96, hint, {
      fontFamily: 'Arial, sans-serif',
      fontSize: '11px',
      color: '#778899',
    }).setOrigin(0.5);
  }

  // ─────────────────────────────────────────────
  _spawnDemoCarts(W, H) {
    const y = H * 0.44;
    CHARACTERS.forEach((char, i) => {
      const startX = -80 - i * 200;
      const cart = this.add.image(startX, y + (i % 2 === 0 ? -12 : 12), `cart_${char.id}`)
        .setScale(1.4)
        .setRotation(Math.PI / 2); // facing right

      this.tweens.add({
        targets: cart,
        x: W + 80,
        duration: 3500 + i * 400,
        delay: i * 300,
        repeat: -1,
        ease: 'Linear',
      });
    });
  }

  // ─────────────────────────────────────────────
  _buildCharSelect(W, H) {
    const baseY = H * 0.62;
    const cardW = 155, cardH = 130;
    const gap = 10;
    const totalW = CHARACTERS.length * cardW + (CHARACTERS.length - 1) * gap;
    const startX = (W - totalW) / 2;

    this.charCards = [];

    CHARACTERS.forEach((char, i) => {
      const cx = startX + i * (cardW + gap) + cardW / 2;

      // Card background
      const card = this.add.graphics();
      card.setData('charIndex', i);

      const border = this.add.graphics();

      // Cart image
      const img = this.add.image(cx, baseY - 18, `cart_${char.id}`)
        .setScale(1.3)
        .setRotation(Math.PI / 2);

      // Name
      const nameText = this.add.text(cx, baseY + 30, char.name, {
        fontFamily: '"Arial Black", Gadget, sans-serif',
        fontSize: '14px',
        color: '#FFD700',
        stroke: '#000',
        strokeThickness: 3,
      }).setOrigin(0.5);

      // Subtitle
      const sub = this.add.text(cx, baseY + 46, char.subtitle, {
        fontFamily: 'Arial, sans-serif',
        fontSize: '11px',
        color: '#CCCCCC',
      }).setOrigin(0.5);

      // Stat bars
      const statNames = ['SPD', 'HDL', 'PWR'];
      const statVals  = [char.stats.speed, char.stats.handling, char.stats.power];
      statNames.forEach((sn, si) => {
        this.add.text(cx - 55, baseY + 60 + si * 14, sn, {
          fontSize: '9px', color: '#AAAAAA',
        });
        const barBg = this.add.graphics();
        barBg.fillStyle(0x333333);
        barBg.fillRect(cx - 38, baseY + 58 + si * 14, 80, 8);
        const barFill = this.add.graphics();
        barFill.fillStyle(this._statColor(statVals[si]));
        barFill.fillRect(cx - 38, baseY + 58 + si * 14, (statVals[si] / 5) * 80, 8);
      });

      this.charCards.push({ card, border, img, nameText, sub, cx, baseY, cardW, cardH });

      // Click / tap to select
      const hitArea = this.add.rectangle(cx, baseY + 20, cardW, cardH, 0xFFFFFF, 0)
        .setInteractive({ useHandCursor: true });
      hitArea.on('pointerdown', () => {
        this.selectedChar = i;
        this._updateCardHighlights();
      });
    });

    this._updateCardHighlights();

    // Arrow keys for selection
    this.input.keyboard.on('keydown-LEFT',  () => { this.selectedChar = Math.max(0, this.selectedChar - 1); this._updateCardHighlights(); });
    this.input.keyboard.on('keydown-RIGHT', () => { this.selectedChar = Math.min(CHARACTERS.length - 1, this.selectedChar + 1); this._updateCardHighlights(); });
    this.input.keyboard.on('keydown-A',     () => { this.selectedChar = Math.max(0, this.selectedChar - 1); this._updateCardHighlights(); });
    this.input.keyboard.on('keydown-D',     () => { this.selectedChar = Math.min(CHARACTERS.length - 1, this.selectedChar + 1); this._updateCardHighlights(); });
  }

  _updateCardHighlights() {
    this.charCards.forEach(({ border, cx, baseY, cardW, cardH }, i) => {
      border.clear();
      if (i === this.selectedChar) {
        border.lineStyle(3, 0xFFD700, 1);
        border.strokeRoundedRect(cx - cardW / 2, baseY - 65, cardW, cardH, 8);
        border.fillStyle(0xFFD700, 0.06);
        border.fillRoundedRect(cx - cardW / 2, baseY - 65, cardW, cardH, 8);
      } else {
        border.lineStyle(1, 0x445566, 0.7);
        border.strokeRoundedRect(cx - cardW / 2, baseY - 65, cardW, cardH, 8);
        border.fillStyle(0x000000, 0.25);
        border.fillRoundedRect(cx - cardW / 2, baseY - 65, cardW, cardH, 8);
      }
    });
  }

  _statColor(v) {
    if (v >= 5) return 0x00FF7F;
    if (v >= 4) return 0x7FFF00;
    if (v >= 3) return 0xFFD700;
    if (v >= 2) return 0xFF8C00;
    return 0xFF4500;
  }

  _startRace() {
    this.cameras.main.fadeOut(400, 0, 0, 0);
    this.cameras.main.once('camerafadeoutcomplete', () => {
      this.scene.start('GameScene', { playerCharIndex: this.selectedChar });
      this.scene.start('UIScene',   { playerCharIndex: this.selectedChar });
    });
  }
}
