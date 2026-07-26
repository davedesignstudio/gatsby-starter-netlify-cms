import Phaser from 'phaser';
import { CHARACTERS, POWER_UPS } from '../data/characters.js';
import {
  WAYPOINTS, CHECKPOINTS, ITEM_BOX_POSITIONS, STORE_SECTIONS, TRACK_WIDTH,
} from '../data/trackWaypoints.js';

// ─── World constants ────────────────────────────────────────────────────────
const WORLD_W = 2000;
const WORLD_H = 1600;
const TOTAL_LAPS = 3;

// ─── Outer + inner boundary rects for collision ──────────────────────────────
// Outer frame
const OUTER_WALLS = [
  { x: 1000, y: 30,   w: WORLD_W, h: 60   }, // top
  { x: 1000, y: 1570, w: WORLD_W, h: 60   }, // bottom
  { x: 30,   y: 800,  w: 60,      h: WORLD_H }, // left
  { x: 1970, y: 800,  w: 60,      h: WORLD_H }, // right
];

// Inner island (shelves / displays that force the oval circuit)
const INNER_WALLS = [
  { x: 1000, y: 410,  w: 1130, h: 60  }, // top of island
  { x: 1000, y: 1190, w: 1130, h: 60  }, // bottom of island
  { x: 450,  y: 800,  w: 60,   h: 840 }, // left of island
  { x: 1555, y: 800,  w: 60,   h: 840 }, // right of island
];

// Chicane obstacle (top straight, forces left/right weave)
const CHICANE_WALLS = [
  { x: 1060, y: 230,  w: 180, h: 180 },
];

export default class GameScene extends Phaser.Scene {
  constructor() { super({ key: 'GameScene' }); }

  // ── init / create ───────────────────────────────────────────────────────────

  init(data) {
    this.playerCharIndex = data?.playerCharIndex ?? 3;
  }

  create() {
    this.physics.world.setBounds(0, 0, WORLD_W, WORLD_H);

    // ── Track background ──────────────────────────────────────────────
    this._drawTrack();

    // ── Walls (static physics bodies) ────────────────────────────────
    this.walls = this.physics.add.staticGroup();
    [...OUTER_WALLS, ...INNER_WALLS, ...CHICANE_WALLS].forEach(r => {
      this.walls.create(r.x, r.y, 'pixel')
        .setDisplaySize(r.w, r.h)
        .setTint(0x000000)
        .setAlpha(0)
        .refreshBody();
    });

    // ── Checkpoints (overlap sensors) ────────────────────────────────
    this._checkpointGroup = this.add.group();
    CHECKPOINTS.forEach(cp => {
      const rect = this.add.rectangle(cp.x, cp.y, cp.w, cp.h, 0x00FF00, 0);
      this.physics.add.existing(rect, true);
      rect.setData('cpId', cp.id);
      this._checkpointGroup.add(rect);
    });

    // ── Carts ─────────────────────────────────────────────────────────
    const startPositions = [
      { x: 950,  y: 1350, angle: Math.PI },
      { x: 1050, y: 1390, angle: Math.PI },
      { x: 850,  y: 1390, angle: Math.PI },
      { x: 1150, y: 1350, angle: Math.PI },
    ];

    this.carts = [];
    CHARACTERS.forEach((char, i) => {
      const isPlayer = (i === this.playerCharIndex);
      const pos = startPositions[i] ?? startPositions[0];

      const aiIndex = isPlayer ? -1 : WAYPOINTS.indexOf(WAYPOINTS.find((_, wi) => wi === 0));
      const cart = new CartEntity(
        this, pos.x, pos.y, pos.angle, char, isPlayer, 0,
      );
      this.carts.push(cart);
    });

    this.playerCart = this.carts[this.playerCharIndex];

    // ── Collisions ────────────────────────────────────────────────────
    this.carts.forEach(cart => {
      this.physics.add.collider(cart.sprite, this.walls, () => {
        // Kill most speed on wall contact; arcade physics separates the bodies
        if (cart.speed > 0) cart.speed *= 0.25;
        else cart.speed = 0;
      });
    });

    // Cart-vs-cart collisions (use overlap + manual response to avoid sticking)
    for (let i = 0; i < this.carts.length; i++) {
      for (let j = i + 1; j < this.carts.length; j++) {
        const a = this.carts[i], b = this.carts[j];
        this.physics.add.collider(a.sprite, b.sprite, () => {
          const tmp = a.speed;
          a.speed = b.speed * 0.5;
          b.speed = tmp * 0.5;
        });
      }
    }

    // ── Power-up boxes ────────────────────────────────────────────────
    this._itemBoxGroup = this.physics.add.staticGroup();
    ITEM_BOX_POSITIONS.forEach(pos => {
      const box = this._itemBoxGroup.create(pos.x, pos.y, 'item_box');
      box.setData('active', true);
      this.tweens.add({
        targets: box,
        angle: 360,
        duration: 2000,
        repeat: -1,
        ease: 'Linear',
      });
    });

    // Collect item boxes
    this.carts.forEach(cart => {
      this.physics.add.overlap(cart.sprite, this._itemBoxGroup, (_, box) => {
        if (!box.getData('active')) return;
        this._giveItem(cart, box);
      });
    });

    // ── Hazards group (bananas, wet floors, baskets) ──────────────────
    this._hazards = this.physics.add.group();
    this.carts.forEach(cart => {
      this.physics.add.overlap(cart.sprite, this._hazards, (_, hazard) => {
        this._hitHazard(cart, hazard);
      });
    });

    // ── Camera ────────────────────────────────────────────────────────
    this.cameras.main.startFollow(this.playerCart.sprite, true, 0.1, 0.1);
    this.cameras.main.setZoom(0.75);
    this.cameras.main.setBounds(0, 0, WORLD_W, WORLD_H);

    // ── Start-finish line detection ───────────────────────────────────
    const sfLine = this.add.rectangle(700, 1370, 400, 40, 0xFFFF00, 0);
    this.physics.add.existing(sfLine, true);
    this.carts.forEach(cart => {
      this.physics.add.overlap(cart.sprite, sfLine, () => {
        this._onCrossStartFinish(cart);
      });
    });

    // ── Countdown ────────────────────────────────────────────────────
    this._raceState = 'countdown';
    this._countdownValue = 3;
    this._raceStarted = false;
    this._countdown();

    // ── Keyboard input ────────────────────────────────────────────────
    this.cursors = this.input.keyboard.createCursorKeys();
    this.wasd = this.input.keyboard.addKeys({ up: 'W', down: 'S', left: 'A', right: 'D' });
    this.spaceKey = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);

    // ── Store lap/position data for UIScene ───────────────────────────
    this.registry.set('laps',      0);
    this.registry.set('totalLaps', TOTAL_LAPS);
    this.registry.set('position',  1);
    this.registry.set('speed',     0);
    this.registry.set('heldItem',  null);
    this.registry.set('raceState', 'countdown');
    this.registry.set('raceTime',  0);
    this.registry.set('positions', []);

    // ── Race timer ────────────────────────────────────────────────────
    this._raceTime = 0;

    // ── Particle emitter for boost ────────────────────────────────────
    this._boostParticles = this.add.particles(0, 0, 'boost_particle', {
      speed: { min: 40, max: 120 },
      angle: { min: 150, max: 210 },
      lifespan: 400,
      quantity: 2,
      scale: { start: 1, end: 0 },
      alpha: { start: 0.8, end: 0 },
      emitting: false,
    });

    // Touch input state (populated by UIScene via registry)
    this.registry.set('touchInput', { left: 0, right: 0, gas: false, useItem: false });
  }

  // ── update ──────────────────────────────────────────────────────────────────

  update(time, delta) {
    const dt = delta / 1000;

    if (this._raceState === 'finished') return;

    // ── Gather input ─────────────────────────────────────────────────
    const touch = this.registry.get('touchInput') || {};
    const gasDown    = this.cursors.up.isDown    || this.wasd.up.isDown    || touch.gas;
    const brakeDown  = this.cursors.down.isDown  || this.wasd.down.isDown;
    const leftDown   = this.cursors.left.isDown  || this.wasd.left.isDown  || (touch.steerX && touch.steerX < -0.2);
    const rightDown  = this.cursors.right.isDown || this.wasd.right.isDown || (touch.steerX && touch.steerX > 0.2);
    const itemUse    = Phaser.Input.Keyboard.JustDown(this.spaceKey)       || touch.useItem;

    // ── Player cart ───────────────────────────────────────────────────
    if (this._raceStarted) {
      const p = this.playerCart;

      if (gasDown)   p.accelerate(dt);
      else           p.applyFriction(dt);
      if (brakeDown) p.brake(dt);
      if (leftDown)  p.steer(-1, dt);
      if (rightDown) p.steer(1, dt);

      if (itemUse && p.heldItem) {
        this._useItem(p);
        this.registry.set('touchInput', { ...touch, useItem: false });
      }

      p.update(dt);

      // Boost particles follow player
      if (p.boosted && gasDown) {
        this._boostParticles.explode(3, p.sprite.x, p.sprite.y);
      }

      // ── Update registry for UI ──────────────────────────────────
      this.registry.set('laps',     p.laps);
      this.registry.set('speed',    Math.abs(p.speed));
      this.registry.set('heldItem', p.heldItem);
    }

    // ── AI carts ──────────────────────────────────────────────────────
    if (this._raceStarted) {
      this.carts.forEach(cart => {
        if (!cart.isPlayer) cart.updateAI(dt, this.carts);
      });
    }

    // ── Checkpoint overlaps (manual check for all carts) ──────────────
    this.carts.forEach(cart => this._checkCheckpoints(cart));

    // ── Compute positions ─────────────────────────────────────────────
    if (this._raceStarted) this._updatePositions();

    // ── Race timer ────────────────────────────────────────────────────
    if (this._raceStarted && this._raceState === 'racing') {
      this._raceTime += delta;
      this.registry.set('raceTime', this._raceTime);
    }

    // ── Update hazards ────────────────────────────────────────────────
    this._hazards.getChildren().forEach(h => {
      const age = h.getData('age') ?? 0;
      h.setData('age', age + delta);
      if (age > 8000) h.destroy();
    });

    // ── Camera zoom on speed ──────────────────────────────────────────
    if (this._raceStarted) {
      const targetZoom = 0.75 - (Math.abs(this.playerCart.speed) / this.playerCart.char.maxSpeed) * 0.12;
      this.cameras.main.setZoom(Phaser.Math.Linear(this.cameras.main.zoom, targetZoom, 0.05));
    }
  }

  // ── Track drawing ────────────────────────────────────────────────────────────

  _drawTrack() {
    const g = this.add.graphics();

    // ── Store carpet / grass (out-of-bounds areas) ──────────────────
    g.fillStyle(0x2C3E50);
    g.fillRect(0, 0, WORLD_W, WORLD_H);

    // ── Track surface (main loop) ──────────────────────────────────
    // Outer oval road (full area inside outer walls)
    g.fillStyle(0xD0CCBF);
    g.fillRect(60, 60, WORLD_W - 120, WORLD_H - 120);

    // ── Inner island (store shelves) ────────────────────────────────
    // Background
    g.fillStyle(0x1A252F);
    g.fillRect(480, 440, 1070, 720);

    // Store section decorations on island
    STORE_SECTIONS.forEach(sec => {
      g.fillStyle(sec.color, 0.55);
      g.fillRect(sec.x, sec.y, sec.w, sec.h);
    });

    // Shelf stripes on island
    g.fillStyle(0x111111, 0.5);
    for (let sx = 510; sx < 1530; sx += 80) {
      g.fillRect(sx, 460, 6, 700);
    }
    for (let sy = 470; sy < 1140; sy += 60) {
      g.fillRect(490, sy, 1040, 4);
    }

    // Island walls decoration
    g.lineStyle(8, 0x555555);
    g.strokeRect(480, 440, 1070, 720);

    // ── Track section floor colours ─────────────────────────────────
    // Produce section (bottom-left)
    g.fillStyle(0x27AE60, 0.25);
    g.fillRect(60, 1200, 400, 340);

    // Frozen foods (left straight top)
    g.fillStyle(0x2980B9, 0.20);
    g.fillRect(60, 60, 400, 500);

    // Bakery (top-right corner)
    g.fillStyle(0xD4789A, 0.20);
    g.fillRect(1540, 60, 400, 380);

    // Canned goods (bottom-right)
    g.fillStyle(0xD4A017, 0.20);
    g.fillRect(1540, 1150, 400, 390);

    // Checkout (bottom straight)
    g.fillStyle(0xAA9966, 0.20);
    g.fillRect(480, 1200, 1060, 350);

    // ── Lane markings ──────────────────────────────────────────────
    g.fillStyle(0xFFFFFF, 0.25);
    // Bottom straight dashes
    for (let x = 500; x < 1600; x += 80) {
      g.fillRect(x, 1375, 40, 8);
    }
    // Right straight dashes
    for (let y = 500; y < 1200; y += 80) {
      g.fillRect(1875, y, 8, 40);
    }
    // Top straight dashes
    for (let x = 500; x < 1600; x += 80) {
      g.fillRect(x, 225, 40, 8);
    }
    // Left straight dashes
    for (let y = 500; y < 1200; y += 80) {
      g.fillRect(125, y, 8, 40);
    }

    // ── Chicane obstacle ─────────────────────────────────────────────
    g.fillStyle(0x8B4513);
    g.fillRect(970, 140, 180, 180);
    g.fillStyle(0xCD853F, 0.5);
    g.fillRect(975, 145, 170, 170);
    // Shelf labels on chicane
    g.fillStyle(0xFFFFFF, 0.5);
    for (let sy = 160; sy < 310; sy += 30) {
      g.fillRect(975, sy, 170, 4);
    }
    g.lineStyle(4, 0xFFFF00);
    g.strokeRect(970, 140, 180, 180);

    // ── Start / Finish line ─────────────────────────────────────────
    const sfY = 1340, sfX = 500;
    for (let col = 0; col < 10; col++) {
      for (let row = 0; row < 3; row++) {
        const shade = (col + row) % 2 === 0 ? 0xFFFFFF : 0x111111;
        g.fillStyle(shade);
        g.fillRect(sfX + col * 40, sfY + row * 20, 40, 20);
      }
    }

    // Section label texts
    const labelStyle = {
      fontFamily: 'Arial, sans-serif',
      fontSize: '13px',
      color: '#FFFFFF',
      stroke: '#000',
      strokeThickness: 3,
      alpha: 0.7,
    };

    STORE_SECTIONS.forEach(sec => {
      this.add.text(sec.x + sec.w / 2, sec.y + sec.h / 2, sec.label, labelStyle)
        .setOrigin(0.5)
        .setAlpha(0.6);
    });

    // "MEGA MART" on the island
    this.add.text(1005, 800, '🏪 MEGA MART', {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '36px',
      color: '#FFD700',
      stroke: '#000',
      strokeThickness: 5,
      alpha: 0.7,
    }).setOrigin(0.5).setAlpha(0.55);

    // "START" label
    this.add.text(700, 1320, '▶  START / FINISH', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '14px',
      color: '#FFD700',
      stroke: '#000',
      strokeThickness: 3,
    }).setOrigin(0.5);
  }

  // ── Countdown ──────────────────────────────────────────────────────────────

  _countdown() {
    const { width: W, height: H } = this.scale;
    const cam = this.cameras.main;

    const showNum = (val) => {
      const txt = this.add.text(
        this.playerCart.sprite.x, this.playerCart.sprite.y - 60,
        val,
        {
          fontFamily: '"Arial Black", Gadget, sans-serif',
          fontSize: '80px',
          color: val === 'GO!' ? '#00FF7F' : '#FFD700',
          stroke: '#000',
          strokeThickness: 10,
        },
      ).setOrigin(0.5).setDepth(100);

      this.tweens.add({
        targets: txt,
        scaleX: 1.8,
        scaleY: 1.8,
        alpha: 0,
        duration: 800,
        ease: 'Power2',
        onComplete: () => txt.destroy(),
      });
    };

    let count = 3;
    const tick = () => {
      if (count > 0) {
        showNum(`${count}`);
        this._rumble(40);
        count--;
        this.time.delayedCall(900, tick);
      } else {
        showNum('GO!');
        this._rumble(80);
        this._raceStarted = true;
        this._raceState = 'racing';
        this.registry.set('raceState', 'racing');
      }
    };

    this.time.delayedCall(500, tick);
  }

  // ── Checkpoints ────────────────────────────────────────────────────────────

  _checkCheckpoints(cart) {
    const cpOrder = ['cp1', 'cp2', 'cp3', 'sf'];
    const bounds = cart.sprite.getBounds();

    this._checkpointGroup.getChildren().forEach(rect => {
      const cpId = rect.getData('cpId');
      const rb = rect.getBounds();
      if (!Phaser.Geom.Intersects.RectangleToRectangle(bounds, rb)) return;

      const nextExpected = cpOrder[cart.nextCheckpoint];
      if (cpId !== nextExpected) return;

      cart.nextCheckpoint = (cart.nextCheckpoint + 1) % cpOrder.length;

      // Lap completion – when sf is passed after all intermediate checkpoints
      if (cpId === 'sf' && cart.nextCheckpoint === 0 && cart.laps < TOTAL_LAPS) {
        cart.laps++;
        if (cart.isPlayer) {
          this.registry.set('laps', cart.laps);
          this._flashLap(cart.laps);
        }
        if (cart.laps >= TOTAL_LAPS) {
          this._finishRace(cart);
        }
      }
    });
  }

  _onCrossStartFinish(cart) {
    // Handled in _checkCheckpoints via the 'sf' checkpoint
  }

  _flashLap(lap) {
    const txt = this.add.text(
      this.playerCart.sprite.x, this.playerCart.sprite.y - 80,
      lap >= TOTAL_LAPS ? '🏁 FINAL LAP!' : `LAP ${lap}/${TOTAL_LAPS}`,
      {
        fontFamily: '"Arial Black", Gadget, sans-serif',
        fontSize: '40px',
        color: lap >= TOTAL_LAPS ? '#FF4500' : '#FFD700',
        stroke: '#000',
        strokeThickness: 6,
      },
    ).setOrigin(0.5).setDepth(100);

    this.tweens.add({
      targets: txt,
      y: txt.y - 60,
      alpha: 0,
      duration: 2000,
      ease: 'Power2',
      onComplete: () => txt.destroy(),
    });
  }

  // ── Power-up give / use ────────────────────────────────────────────────────

  _giveItem(cart, box) {
    if (cart.heldItem) return;

    box.setData('active', false);
    box.setAlpha(0.3);
    this.time.delayedCall(5000, () => {
      if (box && box.active) {
        box.setAlpha(1);
        box.setData('active', true);
      }
    });

    // Weighted random
    const roll = Math.random() * 100;
    let cumulative = 0;
    let chosen = POWER_UPS[0];
    for (const pu of POWER_UPS) {
      cumulative += pu.chance;
      if (roll <= cumulative) { chosen = pu; break; }
    }

    cart.heldItem = chosen;
    if (cart.isPlayer) this.registry.set('heldItem', chosen);

    // Visual feedback
    const pop = this.add.text(
      cart.sprite.x, cart.sprite.y - 50,
      chosen.icon,
      { fontSize: '32px' },
    ).setOrigin(0.5).setDepth(90);
    this.tweens.add({
      targets: pop,
      y: pop.y - 40,
      alpha: 0,
      duration: 1200,
      onComplete: () => pop.destroy(),
    });
  }

  _useItem(cart) {
    const item = cart.heldItem;
    if (!item) return;
    cart.heldItem = null;
    if (cart.isPlayer) this.registry.set('heldItem', null);

    switch (item.id) {
      case 'banana':      this._dropBanana(cart); break;
      case 'energydrink': this._applyBoost(cart); break;
      case 'basket':      this._throwBasket(cart); break;
      case 'wetfloor':    this._dropWetFloor(cart); break;
      case 'shield':      this._applyShield(cart); break;
    }
  }

  _dropBanana(cart) {
    const offsetX = -Math.cos(cart.sprite.rotation) * 40;
    const offsetY = -Math.sin(cart.sprite.rotation) * 40;
    const h = this._hazards.create(
      cart.sprite.x + offsetX,
      cart.sprite.y + offsetY,
      'hazard_banana',
    );
    h.setData({ type: 'banana', age: 0 });
    h.refreshBody();
  }

  _applyBoost(cart) {
    cart.boosted = true;
    const origMax = cart.char.maxSpeed;
    cart.char = { ...cart.char, maxSpeed: origMax * 1.55 };
    cart.speed = cart.char.maxSpeed * 0.8;

    // Blue trail flash
    if (cart.isPlayer) {
      this.cameras.main.flash(200, 0, 180, 255, false);
    }

    this.time.delayedCall(5000, () => {
      cart.char = { ...cart.char, maxSpeed: origMax };
      cart.boosted = false;
    });
  }

  _throwBasket(cart) {
    const vx = Math.cos(cart.sprite.rotation) * 500;
    const vy = Math.sin(cart.sprite.rotation) * 500;
    const proj = this.physics.add.image(cart.sprite.x, cart.sprite.y, 'item_basket')
      .setDepth(50);
    proj.body.setVelocity(vx, vy);
    proj.setData({ type: 'basket', age: 0 });

    this.carts.forEach(target => {
      if (target === cart) return;
      this.physics.add.overlap(proj, target.sprite, () => {
        this._spinoutCart(target);
        this._spawnExplosion(proj.x, proj.y);
        proj.destroy();
      });
    });

    // Auto-destroy after 2 seconds
    this.time.delayedCall(2000, () => { if (proj.active) proj.destroy(); });
  }

  _dropWetFloor(cart) {
    const h = this._hazards.create(cart.sprite.x, cart.sprite.y, 'hazard_wetfloor');
    h.setData({ type: 'wetfloor', age: 0 });
    h.setScale(2);
    h.refreshBody();
  }

  _applyShield(cart) {
    cart.shielded = true;
    const shieldGfx = this.add.graphics()
      .setDepth(80);
    shieldGfx.lineStyle(4, 0x00BFFF, 0.8);
    shieldGfx.strokeCircle(0, 0, 38);

    this.time.addEvent({
      delay: 16,
      callback: () => {
        if (!cart.sprite.active) { shieldGfx.destroy(); return; }
        shieldGfx.clear();
        shieldGfx.lineStyle(4, 0x00BFFF, 0.7 + 0.3 * Math.sin(Date.now() / 80));
        shieldGfx.strokeCircle(cart.sprite.x, cart.sprite.y, 38);
      },
      repeat: 300,
    });

    this.time.delayedCall(5000, () => {
      cart.shielded = false;
      shieldGfx.destroy();
    });
  }

  _hitHazard(cart, hazard) {
    if (cart.shielded || cart.spinning) return;
    const type = hazard.getData('type');
    if (type === 'banana') {
      this._spinoutCart(cart);
      this._spawnExplosion(hazard.x, hazard.y);
      hazard.destroy();
    } else if (type === 'wetfloor') {
      cart.speed *= 0.4;
    }
  }

  _spinoutCart(cart) {
    if (cart.spinning) return;
    cart.spinning = true;
    cart.speed *= 0.3;

    const origRotation = cart.sprite.rotation;
    this.tweens.add({
      targets: cart.sprite,
      angle: cart.sprite.angle + 720,
      duration: 1000,
      ease: 'Power2',
      onComplete: () => {
        cart.spinning = false;
      },
    });

    if (cart.isPlayer) this.cameras.main.shake(300, 0.012);
  }

  _spawnExplosion(x, y) {
    const exp = this.add.image(x, y, 'explosion').setScale(0.6).setDepth(90);
    this.tweens.add({
      targets: exp,
      scaleX: 1.8,
      scaleY: 1.8,
      alpha: 0,
      duration: 500,
      ease: 'Power2',
      onComplete: () => exp.destroy(),
    });
  }

  // ── Race position ───────────────────────────────────────────────────────────

  _updatePositions() {
    // Score = laps * 10000 + (progress along track based on nearest waypoint)
    const scored = this.carts.map(cart => {
      const progress = cart.laps * 10000 + this._trackProgress(cart);
      return { cart, progress };
    });
    scored.sort((a, b) => b.progress - a.progress);

    const playerRank = scored.findIndex(s => s.cart.isPlayer) + 1;
    this.registry.set('position', playerRank);

    const positions = scored.map((s, idx) => ({
      name: s.cart.char.name,
      pos: idx + 1,
      isPlayer: s.cart.isPlayer,
      laps: s.cart.laps,
    }));
    this.registry.set('positions', positions);
  }

  _trackProgress(cart) {
    let nearest = 0, nearDist = Infinity;
    WAYPOINTS.forEach((wp, i) => {
      const d = Phaser.Math.Distance.Between(cart.sprite.x, cart.sprite.y, wp.x, wp.y);
      if (d < nearDist) { nearDist = d; nearest = i; }
    });
    return nearest;
  }

  // ── Finish race ─────────────────────────────────────────────────────────────

  _finishRace(winner) {
    this._raceState = 'finished';
    this.registry.set('raceState', 'finished');
    this.registry.set('winner', winner.char.name);
    this.registry.set('playerWon', winner.isPlayer);
    this.registry.set('raceTime', this._raceTime);

    this.time.delayedCall(4500, () => this._showResults());
  }

  _showResults() {
    const positions = this.registry.get('positions') || [];
    const raceTime  = this.registry.get('raceTime') || 0;
    const playerWon = this.registry.get('playerWon');

    const { width: W, height: H } = this.scale;
    const camX = this.cameras.main.scrollX;
    const camY = this.cameras.main.scrollY;

    // Overlay
    const overlay = this.add.graphics().setDepth(200).setScrollFactor(0);
    overlay.fillStyle(0x000000, 0.75);
    overlay.fillRect(0, 0, W, H);

    // Panel
    const panelX = W / 2, panelY = H / 2;
    const panel = this.add.graphics().setDepth(201).setScrollFactor(0);
    panel.fillStyle(0x1a1a2e, 0.95);
    panel.fillRoundedRect(panelX - 200, panelY - 200, 400, 420, 12);
    panel.lineStyle(3, 0xFFD700);
    panel.strokeRoundedRect(panelX - 200, panelY - 200, 400, 420, 12);

    const headerText = playerWon ? '🏆 YOU WIN!' : '🏁 RACE OVER';
    this.add.text(panelX, panelY - 165, headerText, {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '36px',
      color: playerWon ? '#FFD700' : '#FF6B6B',
      stroke: '#000',
      strokeThickness: 5,
    }).setOrigin(0.5).setDepth(202).setScrollFactor(0);

    const mm = Math.floor(raceTime / 60000);
    const ss = Math.floor((raceTime % 60000) / 1000);
    const ms = Math.floor((raceTime % 1000) / 10);
    this.add.text(panelX, panelY - 120, `Time: ${mm}:${ss.toString().padStart(2,'0')}.${ms.toString().padStart(2,'0')}`, {
      fontFamily: 'Arial, sans-serif',
      fontSize: '18px',
      color: '#CCCCCC',
    }).setOrigin(0.5).setDepth(202).setScrollFactor(0);

    // Positions list
    positions.forEach((p, i) => {
      const medals = ['🥇', '🥈', '🥉', '4️⃣'];
      const col = p.isPlayer ? '#FFD700' : '#AAAAAA';
      this.add.text(panelX, panelY - 75 + i * 40, `${medals[i] || (i + 1)} ${p.name}`, {
        fontFamily: 'Arial, sans-serif',
        fontSize: '20px',
        color: col,
        fontStyle: p.isPlayer ? 'bold' : 'normal',
      }).setOrigin(0.5).setDepth(202).setScrollFactor(0);
    });

    // Replay button
    const replayBtn = this.add.text(panelX, panelY + 170, '🔄  PLAY AGAIN', {
      fontFamily: '"Arial Black", Gadget, sans-serif',
      fontSize: '22px',
      color: '#FFFFFF',
      backgroundColor: '#E74C3C',
      padding: { x: 20, y: 10 },
    }).setOrigin(0.5).setDepth(202).setScrollFactor(0)
      .setInteractive({ useHandCursor: true });

    replayBtn.on('pointerdown', () => {
      this.scene.stop('UIScene');
      this.scene.start('MenuScene');
      this.scene.stop('GameScene');
    });
  }

  _rumble(intensity = 20) {
    this.cameras.main.shake(100, intensity / 1000);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CartEntity – handles physics, AI and rendering for one cart
// ─────────────────────────────────────────────────────────────────────────────

class CartEntity {
  constructor(scene, x, y, angle, char, isPlayer, startWaypoint) {
    this.scene = scene;
    this.char = { ...char };
    this.isPlayer = isPlayer;

    // Physics sprite
    this.sprite = scene.physics.add.sprite(x, y, `cart_${char.id}`)
      .setCollideWorldBounds(true)
      .setDepth(10)
      .setRotation(angle);
    this.sprite.body.setSize(28, 40);

    // Physics state
    this.speed = 0;
    this.angle = angle;

    // Race state
    this.laps = 0;
    this.nextCheckpoint = 0;
    this.heldItem = null;
    this.boosted = false;
    this.shielded = false;
    this.spinning = false;

    // AI state
    this._wpIndex = startWaypoint ?? 0;
    this._aiReactTimer = 0;
    this._aiTargetSteer = 0;
  }

  // ── Player physics ──────────────────────────────────────────────────────────

  accelerate(dt) {
    if (this.spinning) return;
    const accel = this.char.acceleration * (this.boosted ? 1.4 : 1);
    this.speed = Math.min(this.speed + accel * dt, this.char.maxSpeed);
  }

  brake(dt) {
    this.speed = Math.max(this.speed - this.char.acceleration * 2 * dt, -this.char.maxSpeed * 0.4);
  }

  applyFriction(dt) {
    const frictionCoeff = Math.pow(this.char.friction, dt * 60);
    this.speed *= frictionCoeff;
    if (Math.abs(this.speed) < 2) this.speed = 0;
  }

  steer(dir, dt) {
    if (this.spinning) return;
    const speedFactor = Math.min(Math.abs(this.speed) / (this.char.maxSpeed * 0.5), 1);
    this.angle += dir * this.char.turnRate * speedFactor * dt;
  }

  update(dt) {
    if (this.spinning) {
      this.speed *= 0.97;
    }

    // Drive velocity via Phaser arcade physics – collisions handled automatically
    this.sprite.body.setVelocity(
      Math.cos(this.angle) * this.speed,
      Math.sin(this.angle) * this.speed,
    );
    this.sprite.setRotation(this.angle);

    // Keep our logical position in sync after physics resolution
    this.sprite.x = this.sprite.body.x + this.sprite.body.halfWidth;
    this.sprite.y = this.sprite.body.y + this.sprite.body.halfHeight;
  }

  // ── AI ─────────────────────────────────────────────────────────────────────

  updateAI(dt, allCarts) {
    if (this.spinning) { this.speed *= 0.97; this.update(dt); return; }

    // Advance waypoint
    const wp = WAYPOINTS[this._wpIndex];
    const dx = wp.x - this.sprite.x;
    const dy = wp.y - this.sprite.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist < 80) {
      this._wpIndex = (this._wpIndex + 1) % WAYPOINTS.length;
    }

    // Steer toward waypoint
    const targetAngle = Math.atan2(dy, dx);
    let diff = targetAngle - this.angle;
    while (diff > Math.PI)  diff -= 2 * Math.PI;
    while (diff < -Math.PI) diff += 2 * Math.PI;

    const steerForce = Phaser.Math.Clamp(diff * 3, -1, 1);
    const speedFactor = Math.min(Math.abs(this.speed) / (this.char.maxSpeed * 0.5), 1);
    this.angle += steerForce * this.char.turnRate * speedFactor * dt;

    // Rubber-banding speed
    const playerCart = allCarts.find(c => c.isPlayer);
    const myProgress  = this.laps * 10000 + this._wpIndex;
    const plrProgress = playerCart ? (playerCart.laps * 10000 + playerCart._wpIndex ?? 0) : 0;
    const gap = plrProgress - myProgress;
    const rubberBand = 1 + Phaser.Math.Clamp(gap / 5000, -0.25, 0.35);

    const targetSpeed = this.char.maxSpeed * 0.88 * rubberBand;
    this.speed += (targetSpeed - this.speed) * 2 * dt;
    this.speed = Phaser.Math.Clamp(this.speed, 0, this.char.maxSpeed * 1.1);

    // Occasionally use held item
    if (this.heldItem && Math.random() < 0.005) {
      this.scene._useItem(this);
    }

    this.update(dt);
  }
}
