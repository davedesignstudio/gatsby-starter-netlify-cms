export class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.keys = new Set();
    this.joystick = { active: false, x: 0, y: 0, id: null, ox: 0, oy: 0, max: 52 };
    this.buttons = { go: false, drift: false, item: false };
    this.buttonTouches = { go: null, drift: null, item: null };
    this.itemTap = false;
    this.touchRects = {};
    this.menuTap = null;
    this.pendingMenuPoint = null;

    window.addEventListener('keydown', (e) => {
      this.keys.add(e.code);
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));

    canvas.addEventListener('touchstart', (e) => this.onTouch(e, true), { passive: false });
    canvas.addEventListener('touchmove', (e) => this.onTouch(e, false), { passive: false });
    canvas.addEventListener('touchend', (e) => this.onTouchEnd(e), { passive: false });
    canvas.addEventListener('touchcancel', (e) => this.onTouchEnd(e), { passive: false });
    canvas.addEventListener('mousedown', (e) => this.onMouse(e, true));
    canvas.addEventListener('mousemove', (e) => this.onMouse(e, false));
    window.addEventListener('mouseup', () => this.clearMouse());
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  setTouchRects(rects) {
    this.touchRects = rects;
    if (rects.joystick?.max) this.joystick.max = rects.joystick.max;
  }

  canvasPoint(e, touch) {
    const r = this.canvas.getBoundingClientRect();
    const scaleX = r.width > 0 ? this.canvas.clientWidth / r.width : 1;
    const scaleY = r.height > 0 ? this.canvas.clientHeight / r.height : 1;
    return {
      x: (touch.clientX - r.left) * scaleX,
      y: (touch.clientY - r.top) * scaleY,
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
      if (start && this.inRect(p, this.touchRects.go)) {
        this.buttons.go = true;
        this.buttonTouches.go = t.identifier;
      }
      if (start && this.inRect(p, this.touchRects.drift)) {
        this.buttons.drift = true;
        this.buttonTouches.drift = t.identifier;
      }
      if (start && this.inRect(p, this.touchRects.item)) {
        this.buttons.item = true;
        this.buttonTouches.item = t.identifier;
        this.itemTap = true;
      }
      if (start) {
        const menuHit = this.consumeMenuTap(p.x, p.y);
        if (menuHit) this.menuTap = menuHit;
        else this.pendingMenuPoint = p;
      }
      if (this.joystick.id === t.identifier && this.joystick.active) {
        const dx = p.x - this.joystick.ox;
        const dy = p.y - this.joystick.oy;
        const len = Math.hypot(dx, dy) || 1;
        const max = this.joystick.max;
        const scale = Math.min(1, max / len);
        const dead = 0.12;
        let jx = (dx * scale) / max;
        let jy = (-dy * scale) / max;
        if (Math.abs(jx) < dead) jx = 0;
        if (Math.abs(jy) < dead) jy = 0;
        this.joystick.x = jx;
        this.joystick.y = jy;
      }
    }
  }

  onTouchEnd(e) {
    for (const t of e.changedTouches) {
      if (t.clientX != null && t.clientY != null && this.pendingMenuPoint) {
        const p = this.canvasPoint(e, t);
        const menuHit = this.consumeMenuTap(p.x, p.y);
        if (menuHit) this.menuTap = menuHit;
        this.pendingMenuPoint = null;
      } else if (this.pendingMenuPoint && t.identifier === 0) {
        this.pendingMenuPoint = null;
      }
      if (t.identifier === this.joystick.id) {
        this.joystick.active = false;
        this.joystick.x = 0;
        this.joystick.y = 0;
        this.joystick.id = null;
      }
      if (t.identifier === this.buttonTouches.go) {
        this.buttons.go = false;
        this.buttonTouches.go = null;
      }
      if (t.identifier === this.buttonTouches.drift) {
        this.buttons.drift = false;
        this.buttonTouches.drift = null;
      }
      if (t.identifier === this.buttonTouches.item) {
        this.buttons.item = false;
        this.buttonTouches.item = null;
      }
    }
  }

  onMouse(e, down) {
    const fake = { clientX: e.clientX, clientY: e.clientY, identifier: 0 };
    this.onTouch({ changedTouches: [fake], preventDefault: () => {} }, down);
  }

  clearMouse() {
    this.onTouchEnd({ changedTouches: [{ identifier: 0 }] });
  }

  consumeMenuTap(x, y) {
    for (const [name, rect] of Object.entries(this.touchRects)) {
      if (name.startsWith('menu_') && this.inRect({ x, y }, rect)) {
        return name.slice(5);
      }
    }
    return null;
  }

  takeMenuTap() {
    const tap = this.menuTap;
    this.menuTap = null;
    return tap;
  }

  getPlayerInput() {
    const left = this.keys.has('ArrowLeft') || this.keys.has('KeyA');
    const right = this.keys.has('ArrowRight') || this.keys.has('KeyD');
    const up = this.keys.has('ArrowUp') || this.keys.has('KeyW');
    const down = this.keys.has('ArrowDown') || this.keys.has('KeyS');

    let steer = (right ? 1 : 0) - (left ? 1 : 0);
    if (this.joystick.active) steer = this.joystick.x;

    const accel = up || this.keys.has('Space') || this.buttons.go || this.joystick.y > 0.3;
    const brake = down || this.joystick.y < -0.3;
    const drift = this.keys.has('ShiftLeft') || this.keys.has('ShiftRight') || this.buttons.drift;
    const useItem = this.keys.has('KeyE') || this.itemTap;
    this.itemTap = false;

    return { steer, accel, brake, drift, useItem };
  }
}
