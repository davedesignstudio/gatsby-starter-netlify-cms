import Phaser from 'phaser';
import { CHARACTERS } from '../data/characters.js';

export default class BootScene extends Phaser.Scene {
  constructor() { super({ key: 'BootScene' }); }

  create() {
    this._generateCartTextures();
    this._generateItemTextures();
    this._generateMiscTextures();
    this.scene.start('MenuScene');
  }

  // ─────────────────────────────────────────────
  //  Shopping cart sprites  (48 × 64 each, top-down)
  // ─────────────────────────────────────────────
  _generateCartTextures() {
    CHARACTERS.forEach(char => {
      const key = `cart_${char.id}`;
      if (this.textures.exists(key)) return;

      const g = this.make.graphics({ x: 0, y: 0, add: false });
      const W = 48, H = 64;

      // Drop shadow
      g.fillStyle(0x000000, 0.25);
      g.fillEllipse(W / 2 + 3, H - 4, W - 12, 10);

      // Cart frame metal
      g.fillStyle(char.frameColor);
      // Main basket rectangle
      g.fillRect(8, 8, W - 16, H - 24);
      // Frame rails (outline effect)
      g.fillStyle(0x000000, 0.3);
      g.fillRect(8, 8, 2, H - 24);
      g.fillRect(W - 10, 8, 2, H - 24);
      g.fillRect(8, 8, W - 16, 2);

      // Inner basket (slightly darker)
      g.fillStyle(char.bodyColor);
      g.fillRect(11, 11, W - 22, H - 30);

      // Items in basket (character-specific coloured lumps)
      const ic = char.itemColors;
      if (ic.length >= 1) { g.fillStyle(ic[0]); g.fillRoundedRect(13, 13, 10, 9, 2); }
      if (ic.length >= 2) { g.fillStyle(ic[1]); g.fillRoundedRect(26, 13, 9, 8, 2); }
      if (ic.length >= 3) { g.fillStyle(ic[2]); g.fillRoundedRect(13, 24, 22, 7, 2); }
      if (ic.length >= 4) { g.fillStyle(ic[3]); g.fillRoundedRect(16, 33, 14, 6, 2); }

      // Handle bar (bottom of cart when facing up = top-down nose)
      g.fillStyle(0x333333);
      g.fillRect(5, H - 18, W - 10, 6);
      g.fillStyle(0x555555);
      g.fillRect(5, H - 18, W - 10, 2);

      // Wheels – 4 small rounded rects
      const wc = 0x111111;
      g.fillStyle(wc);
      g.fillRoundedRect(5,   4,    8, 5, 1); // front-left
      g.fillRoundedRect(W-13, 4,   8, 5, 1); // front-right
      g.fillRoundedRect(5,   H-12, 8, 5, 1); // rear-left
      g.fillRoundedRect(W-13, H-12, 8, 5, 1); // rear-right

      // Wheel shine
      g.fillStyle(0x666666);
      g.fillRect(6, 5, 2, 2);
      g.fillRect(W - 12, 5, 2, 2);
      g.fillRect(6, H - 11, 2, 2);
      g.fillRect(W - 12, H - 11, 2, 2);

      // Character number / label strip on front
      g.fillStyle(char.frameColor);
      g.fillRect(14, 4, 20, 4);

      g.generateTexture(key, W, H);
      g.destroy();

      // Also create a "spinning" / hit flash version (white tinted)
      const gFlash = this.make.graphics({ x: 0, y: 0, add: false });
      gFlash.fillStyle(0xFFFFFF, 0.9);
      gFlash.fillRoundedRect(8, 8, W - 16, H - 24, 3);
      gFlash.generateTexture(`${key}_flash`, W, H);
      gFlash.destroy();
    });
  }

  // ─────────────────────────────────────────────
  //  Power-up items + item box
  // ─────────────────────────────────────────────
  _generateItemTextures() {
    // Item question-mark box (36×36)
    this._makeItemBox();

    // Individual item sprites (28×28)
    this._makeSprite('item_banana',      g => this._drawBanana(g),      28, 28);
    this._makeSprite('item_energydrink', g => this._drawEnergyDrink(g), 28, 28);
    this._makeSprite('item_basket',      g => this._drawBasket(g),      28, 28);
    this._makeSprite('item_wetfloor',    g => this._drawWetFloor(g),    28, 28);
    this._makeSprite('item_shield',      g => this._drawShield(g),      28, 28);

    // Hazard decals placed on track
    this._makeSprite('hazard_banana',    g => this._drawBananaPeel(g),  32, 20);
    this._makeSprite('hazard_wetfloor',  g => this._drawWetFloorPuddle(g), 64, 40);
    this._makeSprite('explosion',        g => this._drawExplosion(g),   48, 48);
    this._makeSprite('boost_particle',   g => this._drawBoostParticle(g), 12, 12);
  }

  _makeItemBox() {
    const g = this.make.graphics({ x: 0, y: 0, add: false });
    const S = 36;
    // Gold background
    g.fillStyle(0xFFD700);
    g.fillRoundedRect(2, 2, S - 4, S - 4, 4);
    // Shiny edge
    g.fillStyle(0xFFF176);
    g.fillRoundedRect(3, 3, S - 10, 6, 2);
    // Dark border
    g.lineStyle(2, 0x8B6914);
    g.strokeRoundedRect(2, 2, S - 4, S - 4, 4);
    // Question mark  
    g.fillStyle(0x8B6914);
    g.fillRect(15, 10, 6, 3);
    g.fillRect(13, 13, 3, 4);
    g.fillRect(15, 17, 4, 3);
    g.fillRect(15, 22, 4, 3);
    g.fillRect(15, 27, 4, 3);
    g.generateTexture('item_box', S, S);
    g.destroy();
  }

  _makeSprite(key, drawFn, w, h) {
    if (this.textures.exists(key)) return;
    const g = this.make.graphics({ x: 0, y: 0, add: false });
    drawFn(g);
    g.generateTexture(key, w, h);
    g.destroy();
  }

  _drawBanana(g) {
    g.fillStyle(0xFFE135);
    g.fillEllipse(14, 14, 24, 14);
    g.fillStyle(0xFFD700);
    g.fillEllipse(12, 13, 16, 8);
    g.fillStyle(0x8B6914, 0.5);
    g.fillCircle(22, 8, 3);
  }

  _drawEnergyDrink(g) {
    g.fillStyle(0xFF4500);
    g.fillRoundedRect(8, 4, 12, 20, 3);
    g.fillStyle(0xFFD700);
    g.fillRect(9, 7, 10, 5);
    g.fillStyle(0xFFFFFF, 0.7);
    g.fillRect(9, 4, 3, 20);
    g.fillStyle(0x222222);
    g.fillRoundedRect(8, 4, 12, 3, 2);
    g.fillRoundedRect(8, 21, 12, 3, 2);
    // Lightning bolt
    g.fillStyle(0xFFD700);
    g.fillTriangle(16, 10, 12, 16, 16, 16);
    g.fillTriangle(12, 16, 16, 16, 12, 22);
  }

  _drawBasket(g) {
    g.fillStyle(0x8B4513);
    g.fillRect(4, 10, 20, 14);
    g.lineStyle(2, 0x5C3317);
    g.strokeRect(4, 10, 20, 14);
    g.lineStyle(1, 0x5C3317);
    g.lineBetween(14, 10, 14, 24);
    g.lineBetween(4, 17, 24, 17);
    // Handle
    g.lineStyle(2, 0x5C3317);
    g.strokeArc(14, 10, 8, Math.PI, 0, true);
  }

  _drawWetFloor(g) {
    // Yellow triangle sign
    g.fillStyle(0xFFD700);
    g.fillTriangle(14, 2, 26, 24, 2, 24);
    g.lineStyle(2, 0x8B6914);
    g.strokeTriangle(14, 2, 26, 24, 2, 24);
    g.fillStyle(0x000000);
    g.fillRect(13, 10, 2, 8);
    g.fillRect(13, 20, 2, 2);
  }

  _drawShield(g) {
    g.fillStyle(0x00BFFF, 0.8);
    g.fillEllipse(14, 14, 26, 26);
    g.fillStyle(0x87CEEB, 0.6);
    g.fillEllipse(14, 14, 18, 18);
    g.fillStyle(0xFFFFFF, 0.5);
    g.fillEllipse(14, 14, 10, 10);
    g.lineStyle(2, 0x0080FF);
    g.strokeEllipse(14, 14, 26, 26);
  }

  _drawBananaPeel(g) {
    g.fillStyle(0xFFE135);
    g.fillEllipse(16, 10, 28, 14);
    g.fillStyle(0xFFD700);
    g.fillEllipse(14, 10, 18, 8);
    g.fillStyle(0x228B22);
    g.fillCircle(28, 5, 4);
  }

  _drawWetFloorPuddle(g) {
    g.fillStyle(0x4FC3F7, 0.6);
    g.fillEllipse(32, 20, 60, 30);
    g.fillStyle(0x81D4FA, 0.4);
    g.fillEllipse(28, 17, 36, 18);
  }

  _drawExplosion(g) {
    // Orange burst
    g.fillStyle(0xFF8C00, 0.9);
    g.fillCircle(24, 24, 22);
    g.fillStyle(0xFFD700, 0.9);
    g.fillCircle(24, 24, 16);
    g.fillStyle(0xFF4500, 0.9);
    g.fillCircle(24, 24, 10);
    g.fillStyle(0xFFFFFF, 0.8);
    g.fillCircle(24, 24, 5);
    // Spikes
    const spikes = 8;
    for (let i = 0; i < spikes; i++) {
      const a = (i / spikes) * Math.PI * 2;
      g.fillStyle(0xFF8C00, 0.7);
      g.fillTriangle(
        24 + Math.cos(a) * 24, 24 + Math.sin(a) * 24,
        24 + Math.cos(a + 0.3) * 16, 24 + Math.sin(a + 0.3) * 16,
        24 + Math.cos(a - 0.3) * 16, 24 + Math.sin(a - 0.3) * 16,
      );
    }
  }

  _drawBoostParticle(g) {
    g.fillStyle(0x00FFFF, 0.9);
    g.fillCircle(6, 6, 5);
    g.fillStyle(0xFFFFFF, 0.8);
    g.fillCircle(6, 6, 2);
  }

  // ─────────────────────────────────────────────
  //  Misc textures
  // ─────────────────────────────────────────────
  _generateMiscTextures() {
    // 1×1 white pixel (used for tinted rectangles everywhere)
    if (!this.textures.exists('pixel')) {
      const g = this.make.graphics({ x: 0, y: 0, add: false });
      g.fillStyle(0xFFFFFF);
      g.fillRect(0, 0, 1, 1);
      g.generateTexture('pixel', 1, 1);
      g.destroy();
    }

    // Checkered start/finish stripe
    if (!this.textures.exists('sf_line')) {
      const g = this.make.graphics({ x: 0, y: 0, add: false });
      const cols = 10, rows = 4, cs = 10;
      for (let c = 0; c < cols; c++) {
        for (let r = 0; r < rows; r++) {
          g.fillStyle((c + r) % 2 === 0 ? 0xFFFFFF : 0x000000);
          g.fillRect(c * cs, r * cs, cs, cs);
        }
      }
      g.generateTexture('sf_line', cols * cs, rows * cs);
      g.destroy();
    }

    // Minimap cart dot
    if (!this.textures.exists('minimap_dot')) {
      const g = this.make.graphics({ x: 0, y: 0, add: false });
      g.fillStyle(0xFFFFFF);
      g.fillCircle(4, 4, 4);
      g.generateTexture('minimap_dot', 8, 8);
      g.destroy();
    }

    // Virtual joystick base + knob
    if (!this.textures.exists('joy_base')) {
      const g = this.make.graphics({ x: 0, y: 0, add: false });
      g.fillStyle(0xFFFFFF, 0.15);
      g.fillCircle(50, 50, 50);
      g.lineStyle(2, 0xFFFFFF, 0.4);
      g.strokeCircle(50, 50, 50);
      g.generateTexture('joy_base', 100, 100);
      g.destroy();
    }

    if (!this.textures.exists('joy_knob')) {
      const g = this.make.graphics({ x: 0, y: 0, add: false });
      g.fillStyle(0xFFFFFF, 0.5);
      g.fillCircle(28, 28, 28);
      g.fillStyle(0xFFFFFF, 0.8);
      g.fillCircle(28, 28, 14);
      g.generateTexture('joy_knob', 56, 56);
      g.destroy();
    }

    // Gas / item button
    ['btn_gas', 'btn_item'].forEach((key, idx) => {
      if (this.textures.exists(key)) return;
      const g = this.make.graphics({ x: 0, y: 0, add: false });
      const color = idx === 0 ? 0x00CC44 : 0xFF8800;
      g.fillStyle(color, 0.6);
      g.fillCircle(36, 36, 36);
      g.lineStyle(3, 0xFFFFFF, 0.5);
      g.strokeCircle(36, 36, 36);
      g.generateTexture(key, 72, 72);
      g.destroy();
    });
  }
}
