export class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.keys = new Set();
    this.joystick = { active: false, x: 0, y: 0, id: null, ox: 0, oy: 0 };
    this.buttons = { go: false, drift: false, item: false };
    this.itemTap = false;
    this.touchRects = {};

    window.addEventListener('keydown', (e) => {
      this.keys.add(e.code);
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));

    canvas.addEventListener('touchstart', (e) => this.onTouch(e, true), { passive: false });
    canvas.addEventListener('touchmove', (e) => this.onTouch(e, false), { passive: false });
    canvas.addEventListener('touchend', (e) => this.onTouchEnd(e), { passive: false });
    canvas.addEventListener('mousedown', (e) => this.onMouse(e, true));
    canvas.addEventListener('mousemove', (e) => this.onMouse(e, false));
    window.addEventListener('mouseup', () => this.clearMouse());
  }

  setTouchRects(rects) {
    this.touchRects = rects;
  }

  canvasPoint(e, touch) {
    const r = this.canvas.getBoundingClientRect();
    const sx = this.canvas.width / r.width;
    const sy = this.canvas.height / r.height;
    return {
      x: (touch.clientX - r.left) * sx,
      y: (touch.clientY - r.top) * sy,
    };
  }

  inRect(p, rect) {
    return rect && p.x >= rect.x && p.x <= rect.x + rect.w && p.y >= rect.y && p.y <= rect.y + rect.h;
  }

  onTouch(e, start) {
    e.preventDefault();
    for (const t of e.changedTouches) {
      const p = this.canvasPoint(e, t);
      if (start && this.inRect(p, this.touchRects.joystick)) {
        this.joystick.active = true;
        this.joystick.id = t.identifier;
        this.joystick.ox = this.touchRects.joystick.cx;
        this.joystick.oy = this.touchRects.joystick.cy;
      }
      if (this.inRect(p, this.touchRects.go)) this.buttons.go = start;
      if (this.inRect(p, this.touchRects.drift)) this.buttons.drift = start;
      if (this.inRect(p, this.touchRects.item) && start) {
        this.buttons.item = true;
        this.itemTap = true;
      }
      if (this.joystick.id === t.identifier && this.joystick.active) {
        const dx = p.x - this.joystick.ox;
        const dy = p.y - this.joystick.oy;
        const len = Math.hypot(dx, dy) || 1;
        const max = 52;
        const scale = Math.min(1, max / len);
        this.joystick.x = (dx * scale) / max;
        this.joystick.y = (-dy * scale) / max;
      }
    }
  }

  onTouchEnd(e) {
    for (const t of e.changedTouches) {
      if (t.identifier === this.joystick.id) {
        this.joystick.active = false;
        this.joystick.x = 0;
        this.joystick.y = 0;
        this.joystick.id = null;
      }
      this.buttons.go = false;
      this.buttons.drift = false;
      this.buttons.item = false;
    }
  }

  onMouse(e, down) {
    const fake = { clientX: e.clientX, clientY: e.clientY, identifier: 0 };
    this.onTouch({ changedTouches: [fake], preventDefault: () => {} }, down);
  }

  clearMouse() {
    this.onTouchEnd({ changedTouches: [{ identifier: 0 }] });
  }

  getPlayerInput() {
    const left = this.keys.has('ArrowLeft') || this.keys.has('KeyA');
    const right = this.keys.has('ArrowRight') || this.keys.has('KeyD');
    const up = this.keys.has('ArrowUp') || this.keys.has('KeyW');
    const down = this.keys.has('ArrowDown') || this.keys.has('KeyS');

    let steer = (right ? 1 : 0) - (left ? 1 : 0);
    if (this.joystick.active) steer = this.joystick.x;

    const accel = up || this.keys.has('Space') || this.buttons.go || this.joystick.y > 0.35;
    const brake = down || this.joystick.y < -0.35;
    const drift = this.keys.has('ShiftLeft') || this.keys.has('ShiftRight') || this.buttons.drift;
    const useItem = this.keys.has('KeyE') || this.itemTap;
    this.itemTap = false;

    return { steer, accel, brake, drift, useItem };
  }

  consumeMenuTap(x, y) {
    for (const [name, rect] of Object.entries(this.touchRects)) {
      if (name.startsWith('menu_') && this.inRect({ x, y }, rect)) return name.replace('menu_', '');
    }
    return null;
  }
}
