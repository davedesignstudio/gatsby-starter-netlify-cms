(function () {
  "use strict";

  const WORLD = { width: 1280, height: 720 };
  const TRACK = {
    cx: 640,
    cy: 382,
    outerRx: 545,
    outerRy: 286,
    innerRx: 322,
    innerRy: 112,
    lineRx: 433,
    lineRy: 199,
    start: Math.PI / 2,
  };
  const TOTAL_LAPS = 3;
  const TAU = Math.PI * 2;
  const TOUCH_DEVICE = window.matchMedia("(hover: none), (pointer: coarse)").matches;

  const RACERS = [
    {
      name: "Nia",
      number: "01",
      color: "#ef4f34",
      dark: "#9e2c1a",
      skin: "#87523a",
      accent: "#ffd34e",
      acceleration: 238,
      handling: 2.35,
      maxSpeed: 314,
      perk: "Quick off the line",
    },
    {
      name: "Mateo",
      number: "12",
      color: "#218a7d",
      dark: "#14554f",
      skin: "#ba7951",
      accent: "#f7d662",
      acceleration: 218,
      handling: 2.5,
      maxSpeed: 312,
      perk: "Holds every drift",
    },
    {
      name: "June",
      number: "77",
      color: "#d99d27",
      dark: "#8b5d13",
      skin: "#d69a72",
      accent: "#f6eee1",
      acceleration: 222,
      handling: 2.72,
      maxSpeed: 304,
      perk: "Turns on a dime",
    },
    {
      name: "Dev",
      number: "24",
      color: "#7166b1",
      dark: "#40376e",
      skin: "#704530",
      accent: "#72d3c7",
      acceleration: 218,
      handling: 2.38,
      maxSpeed: 310,
      perk: "Boosts last longer",
    },
  ];

  const PICKUP_SPOTS = [
    { t: 0.08, lane: -34 },
    { t: 0.76, lane: 30 },
    { t: 1.34, lane: -22 },
    { t: 2.12, lane: 28 },
    { t: 2.86, lane: -32 },
    { t: 3.61, lane: 25 },
    { t: 4.28, lane: -25 },
    { t: 5.15, lane: 30 },
    { t: 5.73, lane: -28 },
  ];

  const PUDDLE_SPOTS = [
    { t: 0.47, lane: 43, rotation: 0.2 },
    { t: 1.93, lane: -36, rotation: -0.4 },
    { t: 3.28, lane: 46, rotation: 0.5 },
    { t: 4.72, lane: -42, rotation: -0.2 },
  ];

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const lerp = (a, b, amount) => a + (b - a) * amount;

  function angleDifference(target, current) {
    let difference = (target - current + Math.PI) % TAU;
    if (difference < 0) difference += TAU;
    return difference - Math.PI;
  }

  function ordinalSuffix(value) {
    const mod100 = value % 100;
    if (mod100 >= 11 && mod100 <= 13) return "th";
    return value % 10 === 1 ? "st" : value % 10 === 2 ? "nd" : value % 10 === 3 ? "rd" : "th";
  }

  function formatTime(seconds) {
    if (!Number.isFinite(seconds)) return "0:00.0";
    const minutes = Math.floor(seconds / 60);
    const remainder = seconds - minutes * 60;
    return `${minutes}:${remainder.toFixed(1).padStart(4, "0")}`;
  }

  function pointOnTrack(theta, laneOffset) {
    const rx = TRACK.lineRx + (laneOffset || 0);
    const ry = TRACK.lineRy + (laneOffset || 0) * 0.46;
    return {
      x: TRACK.cx + Math.cos(theta) * rx,
      y: TRACK.cy + Math.sin(theta) * ry,
    };
  }

  function roundedRect(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + width, y, x + width, y + height, r);
    ctx.arcTo(x + width, y + height, x, y + height, r);
    ctx.arcTo(x, y + height, x, y, r);
    ctx.arcTo(x, y, x + width, y, r);
    ctx.closePath();
  }

  class AudioSystem {
    constructor() {
      this.context = null;
      this.engine = null;
      this.engineGain = null;
      this.muted = false;
    }

    enable() {
      if (this.context) {
        if (this.context.state === "suspended") this.context.resume();
        return;
      }
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      this.context = new AudioContext();
      this.engine = this.context.createOscillator();
      this.engineGain = this.context.createGain();
      const filter = this.context.createBiquadFilter();
      this.engine.type = "sawtooth";
      this.engine.frequency.value = 48;
      this.engineGain.gain.value = 0;
      filter.type = "lowpass";
      filter.frequency.value = 260;
      this.engine.connect(filter);
      filter.connect(this.engineGain);
      this.engineGain.connect(this.context.destination);
      this.engine.start();
    }

    setMuted(muted) {
      this.muted = muted;
    }

    beep(frequency, duration, type, volume) {
      if (!this.context || this.muted) return;
      const oscillator = this.context.createOscillator();
      const gain = this.context.createGain();
      const now = this.context.currentTime;
      oscillator.type = type || "square";
      oscillator.frequency.setValueAtTime(frequency, now);
      oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, frequency * 0.74), now + duration);
      gain.gain.setValueAtTime(volume || 0.07, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
      oscillator.connect(gain);
      gain.connect(this.context.destination);
      oscillator.start(now);
      oscillator.stop(now + duration);
    }

    updateEngine(speed, active, boosting) {
      if (!this.context || !this.engineGain) return;
      const now = this.context.currentTime;
      const normalized = clamp(Math.abs(speed) / 330, 0, 1);
      const gain = active && !this.muted ? 0.012 + normalized * 0.027 : 0.0001;
      this.engine.frequency.setTargetAtTime(44 + normalized * 72 + (boosting ? 24 : 0), now, 0.05);
      this.engineGain.gain.setTargetAtTime(gain, now, 0.08);
    }
  }

  class InputSystem {
    constructor() {
      this.keys = new Set();
      this.touch = { left: false, right: false, gas: false, brake: false };
      this.itemQueued = false;
      this.pauseQueued = false;
      this.bindKeyboard();
      this.bindTouch();
    }

    bindKeyboard() {
      const gameKeys = new Set([
        "ArrowLeft",
        "ArrowRight",
        "ArrowUp",
        "ArrowDown",
        "KeyA",
        "KeyD",
        "KeyW",
        "KeyS",
        "Space",
        "Escape",
        "KeyP",
      ]);
      window.addEventListener("keydown", (event) => {
        if (!gameKeys.has(event.code)) return;
        event.preventDefault();
        if (!event.repeat && event.code === "Space") this.itemQueued = true;
        if (!event.repeat && (event.code === "Escape" || event.code === "KeyP")) this.pauseQueued = true;
        this.keys.add(event.code);
      });
      window.addEventListener("keyup", (event) => {
        this.keys.delete(event.code);
      });
      window.addEventListener("blur", () => this.clear());
    }

    bindTouch() {
      document.querySelectorAll("[data-control]").forEach((button) => {
        const control = button.dataset.control;
        const release = (event) => {
          event.preventDefault();
          if (control in this.touch) this.touch[control] = false;
          button.classList.remove("is-pressed");
          if (button.hasPointerCapture && button.hasPointerCapture(event.pointerId)) {
            button.releasePointerCapture(event.pointerId);
          }
        };
        button.addEventListener("pointerdown", (event) => {
          event.preventDefault();
          audio.enable();
          if (button.setPointerCapture) button.setPointerCapture(event.pointerId);
          if (control === "item") {
            this.itemQueued = true;
            return;
          }
          this.touch[control] = true;
          button.classList.add("is-pressed");
        });
        button.addEventListener("pointerup", release);
        button.addEventListener("pointercancel", release);
        button.addEventListener("lostpointercapture", () => {
          if (control in this.touch) this.touch[control] = false;
          button.classList.remove("is-pressed");
        });
      });
    }

    read() {
      let steer =
        (this.keys.has("ArrowRight") || this.keys.has("KeyD") || this.touch.right ? 1 : 0) -
        (this.keys.has("ArrowLeft") || this.keys.has("KeyA") || this.touch.left ? 1 : 0);
      let throttle =
        (this.keys.has("ArrowUp") || this.keys.has("KeyW") || this.touch.gas ? 1 : 0) -
        (this.keys.has("ArrowDown") || this.keys.has("KeyS") || this.touch.brake ? 1 : 0);

      const pads = navigator.getGamepads ? navigator.getGamepads() : [];
      const pad = pads && pads[0];
      if (pad) {
        const deadzone = 0.18;
        if (Math.abs(pad.axes[0]) > deadzone) steer = pad.axes[0];
        if (pad.buttons[7] && pad.buttons[7].value > 0.1) throttle = pad.buttons[7].value;
        if (pad.buttons[6] && pad.buttons[6].value > 0.1) throttle = -pad.buttons[6].value;
        if (pad.buttons[0] && pad.buttons[0].pressed) this.itemQueued = true;
        if (pad.buttons[9] && pad.buttons[9].pressed) this.pauseQueued = true;
      }

      return { steer: clamp(steer, -1, 1), throttle: clamp(throttle, -1, 1) };
    }

    consumeItem() {
      const queued = this.itemQueued;
      this.itemQueued = false;
      return queued;
    }

    consumePause() {
      const queued = this.pauseQueued;
      this.pauseQueued = false;
      return queued;
    }

    clear() {
      this.keys.clear();
      Object.keys(this.touch).forEach((key) => {
        this.touch[key] = false;
      });
    }
  }

  class CartGame {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.state = "menu";
      this.selectedRacer = 0;
      this.carts = [];
      this.pickups = [];
      this.particles = [];
      this.raceTime = 0;
      this.countdown = 0;
      this.lastCountdownNumber = null;
      this.finishDelay = 0;
      this.shake = 0;
      this.ambientTime = 0;
      this.lastFrame = performance.now();
      this.player = null;
      this.hasItem = false;
      this.pickupCount = 0;
      this.lapStartTime = 0;
      this.lapTimes = [];
      this.announcementTimer = 0;
      this.layout = { scale: 1, x: 0, y: 0, dpr: 1 };
      this.resize();
      window.addEventListener("resize", () => this.resize());
      requestAnimationFrame((time) => this.loop(time));
    }

    resize() {
      const width = window.innerWidth;
      const height = window.innerHeight;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.canvas.width = Math.round(width * dpr);
      this.canvas.height = Math.round(height * dpr);
      this.canvas.style.width = `${width}px`;
      this.canvas.style.height = `${height}px`;
      const scale = Math.min(width / WORLD.width, height / WORLD.height);
      this.layout = {
        scale,
        x: (width - WORLD.width * scale) / 2,
        y: (height - WORLD.height * scale) / 2,
        dpr,
      };
    }

    setSelectedRacer(index) {
      this.selectedRacer = clamp(index, 0, RACERS.length - 1);
    }

    startRace() {
      this.resetRace();
      this.state = "countdown";
      this.countdown = 3.75;
      this.lastCountdownNumber = null;
      this.updateCountdown();
      this.setRacingUi(true);
      audio.enable();
      audio.beep(330, 0.12, "square", 0.08);
    }

    resetRace() {
      this.carts = [];
      this.particles = [];
      this.pickups = PICKUP_SPOTS.map((spot, index) => ({
        ...pointOnTrack(spot.t, spot.lane),
        theta: spot.t,
        active: true,
        respawn: 0,
        bob: index * 0.73,
      }));
      this.raceTime = 0;
      this.finishDelay = 0;
      this.shake = 0;
      this.hasItem = false;
      this.pickupCount = 0;
      this.lapStartTime = 0;
      this.lapTimes = [];

      const startingOrder = [
        (this.selectedRacer + 1) % 4,
        (this.selectedRacer + 2) % 4,
        (this.selectedRacer + 3) % 4,
        this.selectedRacer,
      ];

      startingOrder.forEach((racerIndex, slot) => {
        const racer = RACERS[racerIndex];
        const row = Math.floor(slot / 2);
        const lane = slot % 2 === 0 ? -28 : 28;
        const theta = TRACK.start - 0.06 - row * 0.13;
        const point = pointOnTrack(theta, lane);
        const tangentX = -TRACK.lineRx * Math.sin(theta);
        const tangentY = TRACK.lineRy * Math.cos(theta);
        const cart = {
          racer,
          racerIndex,
          x: point.x,
          y: point.y,
          vx: 0,
          vy: 0,
          angle: Math.atan2(tangentY, tangentX),
          steerVisual: 0,
          lane,
          progress: -0.06 - row * 0.13,
          lastTheta: theta,
          lap: 1,
          finished: false,
          finishTime: Infinity,
          boost: 0,
          hazardCooldown: 0,
          collisionCooldown: 0,
          isPlayer: racerIndex === this.selectedRacer,
          aiMood: 0.96 + racerIndex * 0.019,
        };
        if (cart.isPlayer) this.player = cart;
        this.carts.push(cart);
      });

      this.updateItemButton();
      this.updateHud();
    }

    setRacingUi(active) {
      ui.hud.classList.toggle("is-hidden", !active);
      ui.pauseButton.classList.toggle("is-hidden", !active);
      ui.touchControls.classList.toggle("is-hidden", !active || !TOUCH_DEVICE);
      document.getElementById("game").classList.toggle("is-racing", active);
    }

    pause() {
      if (this.state !== "racing" && this.state !== "countdown") return;
      this.stateBeforePause = this.state;
      this.state = "paused";
      input.clear();
      showScreen("pause");
      audio.updateEngine(0, false, false);
    }

    resume() {
      if (this.state !== "paused") return;
      hideScreens();
      this.state = this.stateBeforePause || "racing";
      this.lastFrame = performance.now();
    }

    useItem() {
      if (!this.hasItem || this.state !== "racing") return;
      this.hasItem = false;
      this.player.boost = this.player.racerIndex === 3 ? 2.7 : 2.15;
      this.shake = 0.12;
      this.spawnBurst(this.player.x, this.player.y, this.player.racer.accent, 14);
      this.announce("Express lane boost!");
      this.updateItemButton();
      audio.beep(620, 0.28, "sawtooth", 0.09);
      if (navigator.vibrate) navigator.vibrate(30);
    }

    update(dt) {
      this.ambientTime += dt;
      if (input.consumePause()) {
        if (this.state === "paused") this.resume();
        else this.pause();
      }

      if (this.state === "countdown") {
        this.countdown -= dt;
        this.updateCountdown();
        if (this.countdown <= 0) {
          this.state = "racing";
          ui.countdown.classList.add("is-hidden");
          this.announce("Go! Go! Go!");
          audio.beep(760, 0.3, "square", 0.1);
        }
      } else if (this.state === "racing") {
        this.raceTime += dt;
        if (input.consumeItem()) this.useItem();
        const playerControl = input.read();
        this.updateCart(this.player, playerControl, dt);

        this.carts.forEach((cart) => {
          if (cart.isPlayer || cart.finished) return;
          this.updateCart(cart, this.getAiControl(cart), dt);
        });

        this.resolveCartCollisions();
        this.updatePickups(dt);
        this.updateHazards(dt);
        this.updateRaceProgress();
        this.updateParticles(dt);
        this.updateHud();
      } else {
        input.consumeItem();
      }

      if (this.announcementTimer > 0) {
        this.announcementTimer -= dt;
        if (this.announcementTimer <= 0) ui.announcement.classList.remove("is-visible");
      }
      this.shake = Math.max(0, this.shake - dt);
      const speed = this.player ? Math.hypot(this.player.vx, this.player.vy) : 0;
      audio.updateEngine(speed, this.state === "racing", this.player && this.player.boost > 0);
    }

    updateCountdown() {
      if (this.countdown <= 0) return;
      const number = Math.ceil(this.countdown - 0.35);
      const display = clamp(number, 1, 3);
      if (display === this.lastCountdownNumber) return;
      this.lastCountdownNumber = display;
      ui.countdown.classList.remove("is-hidden");
      const oldSpan = ui.countdown.querySelector("span");
      const span = oldSpan.cloneNode(false);
      span.textContent = display;
      oldSpan.replaceWith(span);
      audio.beep(280 + (3 - display) * 55, 0.12, "square", 0.07);
    }

    getAiControl(cart) {
      const theta = Math.atan2((cart.y - TRACK.cy) / TRACK.lineRy, (cart.x - TRACK.cx) / TRACK.lineRx);
      const target = pointOnTrack(theta + 0.28, cart.lane);
      const desired = Math.atan2(target.y - cart.y, target.x - cart.x);
      const difference = angleDifference(desired, cart.angle);
      const speed = Math.hypot(cart.vx, cart.vy);
      const turnSlowdown = clamp(1 - Math.abs(difference) * 0.25, 0.64, 1);
      const catchUp = cart.progress < this.player.progress - 0.35 ? 1.045 : 1;
      const targetSpeed = cart.racer.maxSpeed * cart.aiMood * catchUp * turnSlowdown;
      return {
        steer: clamp(difference * 2.25, -1, 1),
        throttle: speed < targetSpeed ? 1 : 0.2,
      };
    }

    updateCart(cart, control, dt) {
      if (cart.finished) {
        cart.vx *= Math.pow(0.3, dt);
        cart.vy *= Math.pow(0.3, dt);
        return;
      }

      cart.boost = Math.max(0, cart.boost - dt);
      cart.hazardCooldown = Math.max(0, cart.hazardCooldown - dt);
      cart.collisionCooldown = Math.max(0, cart.collisionCooldown - dt);

      const forwardX = Math.cos(cart.angle);
      const forwardY = Math.sin(cart.angle);
      const rightX = -forwardY;
      const rightY = forwardX;
      let forwardSpeed = cart.vx * forwardX + cart.vy * forwardY;
      const lateralSpeed = cart.vx * rightX + cart.vy * rightY;

      const boostMultiplier = cart.boost > 0 ? 1.55 : 1;
      const acceleration = cart.racer.acceleration * boostMultiplier;
      if (control.throttle > 0) {
        cart.vx += forwardX * acceleration * control.throttle * dt;
        cart.vy += forwardY * acceleration * control.throttle * dt;
      } else if (control.throttle < 0) {
        const brakePower = forwardSpeed > 12 ? 380 : 135;
        cart.vx += forwardX * brakePower * control.throttle * dt;
        cart.vy += forwardY * brakePower * control.throttle * dt;
      }

      forwardSpeed = cart.vx * forwardX + cart.vy * forwardY;
      const speedRatio = clamp(Math.abs(forwardSpeed) / cart.racer.maxSpeed, 0, 1);
      const direction = forwardSpeed < -4 ? -1 : 1;
      const steering = control.steer * cart.racer.handling * (0.2 + speedRatio * 0.8) * direction;
      cart.angle += steering * dt;
      cart.steerVisual = lerp(cart.steerVisual, control.steer, clamp(dt * 10, 0, 1));

      const grip = cart.racerIndex === 1 ? 7.6 : 6.6;
      cart.vx -= rightX * lateralSpeed * clamp(grip * dt, 0, 0.92);
      cart.vy -= rightY * lateralSpeed * clamp(grip * dt, 0, 0.92);

      const drag = control.throttle > 0 ? 0.65 : 1.45;
      cart.vx *= Math.max(0, 1 - drag * dt);
      cart.vy *= Math.max(0, 1 - drag * dt);

      const maxSpeed = cart.racer.maxSpeed * (cart.boost > 0 ? 1.42 : 1);
      const speed = Math.hypot(cart.vx, cart.vy);
      if (speed > maxSpeed) {
        const scale = maxSpeed / speed;
        cart.vx *= scale;
        cart.vy *= scale;
      }

      cart.x += cart.vx * dt;
      cart.y += cart.vy * dt;
      this.constrainToTrack(cart);

      if (cart.boost > 0 && Math.random() < dt * 25) {
        this.spawnParticle(
          cart.x - Math.cos(cart.angle) * 24,
          cart.y - Math.sin(cart.angle) * 24,
          cart.racer.accent,
          -cart.vx * 0.25 + (Math.random() - 0.5) * 30,
          -cart.vy * 0.25 + (Math.random() - 0.5) * 30,
          0.4
        );
      }
    }

    constrainToTrack(cart) {
      const dx = cart.x - TRACK.cx;
      const dy = cart.y - TRACK.cy;
      const outerDistance = Math.sqrt((dx * dx) / (TRACK.outerRx * TRACK.outerRx) + (dy * dy) / (TRACK.outerRy * TRACK.outerRy));
      const innerDistance = Math.sqrt((dx * dx) / (TRACK.innerRx * TRACK.innerRx) + (dy * dy) / (TRACK.innerRy * TRACK.innerRy));
      let hit = false;

      if (outerDistance > 0.965) {
        const scale = 0.965 / outerDistance;
        cart.x = TRACK.cx + dx * scale;
        cart.y = TRACK.cy + dy * scale;
        hit = true;
      } else if (innerDistance < 1.06) {
        const scale = 1.06 / Math.max(innerDistance, 0.01);
        cart.x = TRACK.cx + dx * scale;
        cart.y = TRACK.cy + dy * scale;
        hit = true;
      }

      if (hit) {
        cart.vx *= 0.62;
        cart.vy *= 0.62;
        if (cart.isPlayer && cart.collisionCooldown <= 0) {
          this.shake = 0.12;
          cart.collisionCooldown = 0.32;
          audio.beep(95, 0.08, "square", 0.035);
        }
      }
    }

    resolveCartCollisions() {
      for (let i = 0; i < this.carts.length; i += 1) {
        for (let j = i + 1; j < this.carts.length; j += 1) {
          const a = this.carts[i];
          const b = this.carts[j];
          const dx = b.x - a.x;
          const dy = b.y - a.y;
          const distance = Math.hypot(dx, dy);
          const minimum = 31;
          if (distance >= minimum || distance < 0.01) continue;
          const nx = dx / distance;
          const ny = dy / distance;
          const overlap = minimum - distance;
          a.x -= nx * overlap * 0.5;
          a.y -= ny * overlap * 0.5;
          b.x += nx * overlap * 0.5;
          b.y += ny * overlap * 0.5;
          const impulse = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
          if (impulse < 0) {
            a.vx += nx * impulse * 0.45;
            a.vy += ny * impulse * 0.45;
            b.vx -= nx * impulse * 0.45;
            b.vy -= ny * impulse * 0.45;
          }
          if ((a.isPlayer || b.isPlayer) && a.collisionCooldown <= 0 && b.collisionCooldown <= 0) {
            this.shake = 0.09;
            a.collisionCooldown = 0.25;
            b.collisionCooldown = 0.25;
            this.spawnBurst((a.x + b.x) / 2, (a.y + b.y) / 2, "#fff1b4", 5);
            audio.beep(125, 0.07, "square", 0.025);
          }
        }
      }
    }

    updatePickups(dt) {
      this.pickups.forEach((pickup) => {
        pickup.bob += dt * 2.7;
        if (!pickup.active) {
          pickup.respawn -= dt;
          if (pickup.respawn <= 0) pickup.active = true;
          return;
        }
        const distance = Math.hypot(this.player.x - pickup.x, this.player.y - pickup.y);
        if (distance < 31) {
          pickup.active = false;
          pickup.respawn = 6.5;
          this.pickupCount += 1;
          if (!this.hasItem) {
            this.hasItem = true;
            this.announce("Boost bag ready");
            this.updateItemButton();
          } else {
            this.player.boost = Math.max(this.player.boost, 0.72);
            this.announce("Mini boost!");
          }
          this.spawnBurst(pickup.x, pickup.y, "#ffd34e", 10);
          audio.beep(520, 0.18, "sine", 0.08);
        }
      });
    }

    updateHazards() {
      this.carts.forEach((cart) => {
        if (cart.hazardCooldown > 0) return;
        PUDDLE_SPOTS.forEach((spot) => {
          const point = pointOnTrack(spot.t, spot.lane);
          if (Math.hypot(cart.x - point.x, cart.y - point.y) < 37) {
            cart.hazardCooldown = 2.2;
            cart.angle += cart.isPlayer ? 0.72 : 0.38;
            const vx = cart.vx;
            cart.vx = cart.vx * 0.35 - cart.vy * 0.42;
            cart.vy = cart.vy * 0.35 + vx * 0.42;
            if (cart.isPlayer) {
              this.shake = 0.18;
              this.announce("Slippery when speedy!");
              audio.beep(180, 0.25, "sawtooth", 0.06);
            }
          }
        });
      });
    }

    updateRaceProgress() {
      this.carts.forEach((cart) => {
        if (cart.finished) return;
        const theta = Math.atan2((cart.y - TRACK.cy) / TRACK.lineRy, (cart.x - TRACK.cx) / TRACK.lineRx);
        let delta = angleDifference(theta, cart.lastTheta);
        if (Math.abs(delta) > 0.55) delta = 0;
        cart.progress = Math.max(-0.45, cart.progress + delta);
        cart.lastTheta = theta;
        const completedLaps = Math.max(0, Math.floor(cart.progress / TAU));
        const newLap = completedLaps + 1;

        if (cart.isPlayer && newLap > cart.lap && newLap <= TOTAL_LAPS) {
          const lapTime = this.raceTime - this.lapStartTime;
          this.lapTimes.push(lapTime);
          this.lapStartTime = this.raceTime;
          this.announce(newLap === TOTAL_LAPS ? "Final lap!" : `Lap ${newLap} — keep rolling!`);
          audio.beep(newLap === TOTAL_LAPS ? 700 : 560, 0.25, "square", 0.08);
        }
        cart.lap = Math.min(newLap, TOTAL_LAPS);

        if (cart.progress >= TOTAL_LAPS * TAU) {
          cart.finished = true;
          cart.finishTime = this.raceTime;
          if (cart.isPlayer) {
            this.lapTimes.push(this.raceTime - this.lapStartTime);
            this.finishRace();
          }
        }
      });
    }

    getStandings() {
      return [...this.carts].sort((a, b) => {
        if (a.finished && b.finished) return a.finishTime - b.finishTime;
        if (a.finished) return -1;
        if (b.finished) return 1;
        return b.progress - a.progress;
      });
    }

    finishRace() {
      const standings = this.getStandings();
      const place = standings.indexOf(this.player) + 1;
      this.state = "finished";
      this.player.vx *= 0.8;
      this.player.vy *= 0.8;
      this.setRacingUi(false);
      ui.finishPlace.innerHTML = `${place}<sup>${ordinalSuffix(place)}</sup>`;
      ui.finishTime.textContent = formatTime(this.raceTime);
      ui.bestLap.textContent = formatTime(Math.min(...this.lapTimes));
      ui.pickupCount.textContent = String(this.pickupCount);
      if (place === 1) {
        ui.finishKicker.textContent = "Supply run complete";
        ui.finishTitle.textContent = "You brought it home!";
        ui.finishCopy.textContent = "The pantry is stocked and the whole crew is cheering.";
      } else {
        ui.finishKicker.textContent = `${place}${ordinalSuffix(place)} place — supply run complete`;
        ui.finishTitle.textContent = "Everybody delivers.";
        ui.finishCopy.textContent = "No cart left behind. The pantry wins either way.";
      }
      window.setTimeout(() => showScreen("finish"), 520);
      audio.beep(place === 1 ? 880 : 620, 0.55, "square", 0.1);
      statusMessage(`Race complete. You finished ${place}${ordinalSuffix(place)}.`);
    }

    updateParticles(dt) {
      this.particles.forEach((particle) => {
        particle.life -= dt;
        particle.x += particle.vx * dt;
        particle.y += particle.vy * dt;
        particle.vx *= Math.max(0, 1 - dt * 2);
        particle.vy *= Math.max(0, 1 - dt * 2);
      });
      this.particles = this.particles.filter((particle) => particle.life > 0);
    }

    spawnParticle(x, y, color, vx, vy, life) {
      this.particles.push({
        x,
        y,
        color,
        vx,
        vy,
        life,
        maxLife: life,
        size: 2 + Math.random() * 3,
      });
    }

    spawnBurst(x, y, color, count) {
      for (let i = 0; i < count; i += 1) {
        const angle = Math.random() * TAU;
        const speed = 35 + Math.random() * 90;
        this.spawnParticle(x, y, color, Math.cos(angle) * speed, Math.sin(angle) * speed, 0.35 + Math.random() * 0.35);
      }
    }

    announce(message) {
      ui.announcement.textContent = message;
      ui.announcement.classList.add("is-visible");
      this.announcementTimer = 1.75;
      statusMessage(message);
    }

    updateItemButton() {
      ui.itemButton.disabled = !this.hasItem;
      ui.itemButton.querySelector(".item-button__label").textContent = this.hasItem ? "Boost" : "Empty";
    }

    updateHud() {
      if (!this.player) return;
      const place = this.getStandings().indexOf(this.player) + 1;
      ui.lapValue.textContent = String(this.player.lap);
      ui.positionValue.textContent = String(place);
      ui.positionSuffix.textContent = ordinalSuffix(place);
      ui.speedValue.textContent = String(Math.round(Math.hypot(this.player.vx, this.player.vy) * 0.32));
    }

    loop(time) {
      const dt = Math.min((time - this.lastFrame) / 1000, 0.034);
      this.lastFrame = time;
      this.update(dt);
      this.render();
      requestAnimationFrame((nextTime) => this.loop(nextTime));
    }

    render() {
      const { ctx } = this;
      const { dpr, scale, x, y } = this.layout;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.fillStyle = "#111a22";
      ctx.fillRect(0, 0, this.canvas.width / dpr, this.canvas.height / dpr);
      ctx.save();
      ctx.translate(x, y);
      ctx.scale(scale, scale);
      if (this.shake > 0) {
        ctx.translate((Math.random() - 0.5) * 8, (Math.random() - 0.5) * 8);
      }
      this.drawStore();

      if (this.state === "menu" || this.state === "select") {
        this.drawAttractCarts();
        ctx.fillStyle = "rgba(9, 15, 20, 0.52)";
        ctx.fillRect(0, 0, WORLD.width, WORLD.height);
        this.drawLightSweep();
      } else {
        this.drawHazards();
        this.drawPickups();
        [...this.carts]
          .sort((a, b) => a.y - b.y)
          .forEach((cart) => this.drawCart(cart));
        this.drawParticles();
        this.drawSpeedLines();
      }
      ctx.restore();
    }

    drawStore() {
      const { ctx } = this;
      ctx.fillStyle = "#d8d0bb";
      ctx.fillRect(0, 0, WORLD.width, WORLD.height);

      ctx.strokeStyle = "rgba(75, 72, 64, 0.09)";
      ctx.lineWidth = 1;
      for (let x = 0; x <= WORLD.width; x += 36) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, WORLD.height);
        ctx.stroke();
      }
      for (let y = 0; y <= WORLD.height; y += 36) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(WORLD.width, y);
        ctx.stroke();
      }

      ctx.save();
      ctx.shadowColor = "rgba(34, 31, 27, 0.24)";
      ctx.shadowBlur = 18;
      ctx.shadowOffsetY = 8;
      ctx.fillStyle = "#b8af9c";
      ctx.beginPath();
      ctx.ellipse(TRACK.cx, TRACK.cy, TRACK.outerRx, TRACK.outerRy, 0, 0, TAU);
      ctx.fill();
      ctx.restore();

      ctx.fillStyle = "#ebe4d1";
      ctx.beginPath();
      ctx.ellipse(TRACK.cx, TRACK.cy, TRACK.innerRx, TRACK.innerRy, 0, 0, TAU);
      ctx.fill();

      ctx.save();
      ctx.strokeStyle = "rgba(255, 255, 255, 0.45)";
      ctx.lineWidth = 3;
      ctx.setLineDash([18, 21]);
      ctx.beginPath();
      ctx.ellipse(TRACK.cx, TRACK.cy, TRACK.lineRx, TRACK.lineRy, 0, 0, TAU);
      ctx.stroke();
      ctx.restore();

      ctx.strokeStyle = "rgba(64, 59, 52, 0.2)";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.ellipse(TRACK.cx, TRACK.cy, TRACK.outerRx - 8, TRACK.outerRy - 8, 0, 0, TAU);
      ctx.stroke();
      ctx.beginPath();
      ctx.ellipse(TRACK.cx, TRACK.cy, TRACK.innerRx + 7, TRACK.innerRy + 7, 0, 0, TAU);
      ctx.stroke();

      this.drawFinishLine();
      this.drawCenterShelves();
      this.drawOuterStoreDetails();
    }

    drawFinishLine() {
      const { ctx } = this;
      const inner = {
        x: TRACK.cx + Math.cos(TRACK.start) * (TRACK.innerRx + 8),
        y: TRACK.cy + Math.sin(TRACK.start) * (TRACK.innerRy + 8),
      };
      const outer = {
        x: TRACK.cx + Math.cos(TRACK.start) * (TRACK.outerRx - 8),
        y: TRACK.cy + Math.sin(TRACK.start) * (TRACK.outerRy - 8),
      };
      const dx = outer.x - inner.x;
      const dy = outer.y - inner.y;
      const length = Math.hypot(dx, dy);
      const angle = Math.atan2(dy, dx);
      ctx.save();
      ctx.translate(inner.x, inner.y);
      ctx.rotate(angle);
      const size = 12;
      for (let row = 0; row < 2; row += 1) {
        for (let column = 0; column < Math.ceil(length / size); column += 1) {
          ctx.fillStyle = (row + column) % 2 ? "#f4ead1" : "#26323a";
          ctx.fillRect(column * size, row * size - size, size + 0.5, size);
        }
      }
      ctx.restore();
    }

    drawCenterShelves() {
      const { ctx } = this;
      const shelves = [
        { x: 393, y: 316, width: 210, color: "#d65f40", label: "SOUP · BEANS · PASTA" },
        { x: 676, y: 316, width: 210, color: "#2c8a7d", label: "CEREAL · OATS · RICE" },
        { x: 470, y: 410, width: 340, color: "#d6a52d", label: "COMMUNITY PANTRY PICKUP" },
      ];
      shelves.forEach((shelf, shelfIndex) => {
        ctx.save();
        ctx.shadowColor = "rgba(38, 31, 22, 0.25)";
        ctx.shadowBlur = 8;
        ctx.shadowOffsetY = 6;
        roundedRect(ctx, shelf.x, shelf.y, shelf.width, 42, 4);
        ctx.fillStyle = "#4e5351";
        ctx.fill();
        ctx.shadowColor = "transparent";
        ctx.fillStyle = shelf.color;
        ctx.fillRect(shelf.x + 4, shelf.y + 4, shelf.width - 8, 8);
        const productColors = ["#f0c54c", "#e7724f", "#68a99c", "#ece5ca"];
        for (let product = 0; product < Math.floor((shelf.width - 20) / 17); product += 1) {
          ctx.fillStyle = productColors[(product + shelfIndex) % productColors.length];
          ctx.fillRect(shelf.x + 10 + product * 17, shelf.y + 17, 10, 17);
        }
        ctx.fillStyle = "#4a4c49";
        ctx.font = "700 8px 'DM Sans', sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(shelf.label, shelf.x + shelf.width / 2, shelf.y - 7);
        ctx.restore();
      });
    }

    drawOuterStoreDetails() {
      const { ctx } = this;
      const counters = [
        { x: 74, y: 42, label: "CHECKOUT 01", color: "#ef4f34" },
        { x: 278, y: 42, label: "CHECKOUT 02", color: "#ffd34e" },
        { x: 986, y: 42, label: "PANTRY DESK", color: "#218a7d" },
      ];
      counters.forEach((counter) => {
        roundedRect(ctx, counter.x, counter.y, 176, 54, 5);
        ctx.fillStyle = "#39434a";
        ctx.fill();
        ctx.fillStyle = counter.color;
        ctx.fillRect(counter.x + 6, counter.y + 7, 164, 8);
        ctx.fillStyle = "rgba(255,255,255,.74)";
        ctx.font = "800 11px 'Barlow Condensed', sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(counter.label, counter.x + 88, counter.y + 36);
      });

      ctx.fillStyle = "#29353c";
      ctx.fillRect(0, 0, WORLD.width, 18);
      ctx.fillRect(0, WORLD.height - 18, WORLD.width, 18);
      ctx.fillRect(0, 0, 18, WORLD.height);
      ctx.fillRect(WORLD.width - 18, 0, 18, WORLD.height);

      const signs = [
        { x: 32, y: 210, text: "PRODUCE", color: "#2b8a69" },
        { x: 32, y: 480, text: "BAKERY", color: "#d38f2d" },
        { x: 1115, y: 206, text: "HOME", color: "#3978b6" },
        { x: 1115, y: 486, text: "CARE", color: "#a9609e" },
      ];
      signs.forEach((sign) => {
        roundedRect(ctx, sign.x, sign.y, 132, 38, 3);
        ctx.fillStyle = sign.color;
        ctx.fill();
        ctx.fillStyle = "white";
        ctx.font = "900 15px 'Barlow Condensed', sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(sign.text, sign.x + 66, sign.y + 24);
      });
    }

    drawHazards() {
      const { ctx } = this;
      PUDDLE_SPOTS.forEach((spot) => {
        const point = pointOnTrack(spot.t, spot.lane);
        ctx.save();
        ctx.translate(point.x, point.y);
        ctx.rotate(spot.rotation);
        ctx.fillStyle = "rgba(63, 133, 159, 0.36)";
        ctx.beginPath();
        ctx.ellipse(0, 0, 42, 18, 0, 0, TAU);
        ctx.ellipse(17, -9, 21, 11, 0.4, 0, TAU);
        ctx.ellipse(-19, 8, 18, 10, -0.2, 0, TAU);
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,.45)";
        ctx.beginPath();
        ctx.ellipse(-10, -5, 11, 2.5, -0.2, 0, TAU);
        ctx.fill();
        ctx.restore();
      });
    }

    drawPickups() {
      const { ctx } = this;
      this.pickups.forEach((pickup) => {
        if (!pickup.active) return;
        const bob = Math.sin(pickup.bob) * 4;
        ctx.save();
        ctx.translate(pickup.x, pickup.y + bob);
        ctx.rotate(Math.sin(pickup.bob * 0.7) * 0.08);
        ctx.shadowColor = "rgba(50, 37, 17, 0.28)";
        ctx.shadowBlur = 8;
        ctx.shadowOffsetY = 6;
        roundedRect(ctx, -16, -18, 32, 34, 4);
        ctx.fillStyle = "#ffd34e";
        ctx.fill();
        ctx.shadowColor = "transparent";
        ctx.fillStyle = "#ef4f34";
        ctx.fillRect(-16, -8, 32, 8);
        ctx.fillStyle = "#172129";
        ctx.font = "900 18px 'Barlow Condensed', sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("⚡", 0, 9);
        ctx.strokeStyle = "#5d4b1e";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, -17, 8, Math.PI, 0);
        ctx.stroke();
        ctx.restore();
      });
    }

    drawCart(cart) {
      const { ctx } = this;
      const speed = Math.hypot(cart.vx, cart.vy);
      ctx.save();
      ctx.translate(cart.x, cart.y);
      ctx.rotate(cart.angle);

      ctx.fillStyle = "rgba(29, 26, 22, 0.2)";
      ctx.beginPath();
      ctx.ellipse(-2, 6, 39, 19, 0, 0, TAU);
      ctx.fill();

      if (cart.boost > 0) {
        ctx.fillStyle = cart.racer.accent;
        ctx.globalAlpha = 0.68 + Math.sin(this.ambientTime * 22) * 0.2;
        ctx.beginPath();
        ctx.moveTo(-32, -10);
        ctx.lineTo(-57 - Math.random() * 10, -4);
        ctx.lineTo(-31, 2);
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(-32, 8);
        ctx.lineTo(-53 - Math.random() * 12, 13);
        ctx.lineTo(-30, 17);
        ctx.fill();
        ctx.globalAlpha = 1;
      }

      ctx.save();
      ctx.translate(-31, 0);
      ctx.fillStyle = cart.racer.color;
      ctx.beginPath();
      ctx.ellipse(0, 0, 13, 11, 0, 0, TAU);
      ctx.fill();
      ctx.fillStyle = cart.racer.skin;
      ctx.beginPath();
      ctx.arc(1, -1, 7, 0, TAU);
      ctx.fill();
      ctx.fillStyle = "#17191a";
      ctx.beginPath();
      ctx.arc(3, -3, 1.2, 0, TAU);
      ctx.fill();
      ctx.strokeStyle = cart.racer.color;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(3, 8);
      ctx.lineTo(13, 15);
      ctx.moveTo(0, 8);
      ctx.lineTo(-7, 15);
      ctx.stroke();
      ctx.restore();

      ctx.strokeStyle = "#3e4a50";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-22, -15);
      ctx.lineTo(-13, -15);
      ctx.moveTo(-22, 15);
      ctx.lineTo(-13, 15);
      ctx.stroke();

      ctx.fillStyle = "#2e383d";
      [
        [-14, -18],
        [22, -18],
        [-14, 18],
        [22, 18],
      ].forEach(([wheelX, wheelY]) => {
        ctx.save();
        ctx.translate(wheelX, wheelY);
        ctx.rotate(cart.steerVisual * 0.4);
        ctx.fillRect(-4, -3, 8, 6);
        ctx.restore();
      });

      ctx.fillStyle = cart.racer.color;
      ctx.strokeStyle = "#f4f0e4";
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(-16, -15);
      ctx.lineTo(26, -12);
      ctx.lineTo(32, -7);
      ctx.lineTo(32, 7);
      ctx.lineTo(26, 12);
      ctx.lineTo(-16, 15);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();

      ctx.strokeStyle = "rgba(255,255,255,.42)";
      ctx.lineWidth = 1;
      for (let line = -8; line <= 8; line += 8) {
        ctx.beginPath();
        ctx.moveTo(-11, line);
        ctx.lineTo(26, line * 0.72);
        ctx.stroke();
      }
      for (let line = -5; line <= 17; line += 11) {
        ctx.beginPath();
        ctx.moveTo(line, -13);
        ctx.lineTo(line + 2, 13);
        ctx.stroke();
      }

      ctx.fillStyle = cart.racer.accent;
      ctx.beginPath();
      ctx.arc(8, 2, 6, 0, TAU);
      ctx.fill();
      ctx.fillStyle = cart.racer.dark;
      ctx.fillRect(0, -9, 9, 7);
      ctx.fillStyle = "white";
      ctx.font = "900 8px 'Barlow Condensed', sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(cart.racer.number, -5, 3);

      if (cart.isPlayer) {
        ctx.fillStyle = "#ffd34e";
        ctx.beginPath();
        ctx.moveTo(0, -30);
        ctx.lineTo(-6, -40);
        ctx.lineTo(6, -40);
        ctx.closePath();
        ctx.fill();
        if (speed < 5 && this.state === "countdown") {
          ctx.fillStyle = "rgba(17,26,34,.65)";
          roundedRect(ctx, -18, 26, 36, 14, 3);
          ctx.fill();
          ctx.fillStyle = "white";
          ctx.font = "800 8px 'DM Sans', sans-serif";
          ctx.fillText("YOU", 0, 36);
        }
      }

      ctx.restore();
    }

    drawParticles() {
      const { ctx } = this;
      this.particles.forEach((particle) => {
        ctx.globalAlpha = clamp(particle.life / particle.maxLife, 0, 1);
        ctx.fillStyle = particle.color;
        ctx.beginPath();
        ctx.arc(particle.x, particle.y, particle.size, 0, TAU);
        ctx.fill();
      });
      ctx.globalAlpha = 1;
    }

    drawSpeedLines() {
      if (!this.player) return;
      const speed = Math.hypot(this.player.vx, this.player.vy);
      if (speed < 330) return;
      const { ctx } = this;
      ctx.save();
      ctx.strokeStyle = "rgba(255,255,255,.34)";
      ctx.lineWidth = 2;
      const intensity = clamp((speed - 330) / 120, 0, 1);
      for (let i = 0; i < 14; i += 1) {
        const x = (i * 97 + this.ambientTime * 520) % WORLD.width;
        const y = 95 + ((i * 61) % 530);
        ctx.globalAlpha = intensity * (0.25 + (i % 3) * 0.2);
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x - 25 - intensity * 30, y);
        ctx.stroke();
      }
      ctx.restore();
    }

    drawAttractCarts() {
      for (let index = 0; index < RACERS.length; index += 1) {
        const theta = this.ambientTime * (0.2 + index * 0.008) + index * 0.74;
        const point = pointOnTrack(theta, index % 2 ? 28 : -28);
        const next = pointOnTrack(theta + 0.02, index % 2 ? 28 : -28);
        this.drawCart({
          racer: RACERS[index],
          racerIndex: index,
          x: point.x,
          y: point.y,
          angle: Math.atan2(next.y - point.y, next.x - point.x),
          vx: 100,
          vy: 0,
          steerVisual: Math.sin(theta * 2) * 0.25,
          boost: index === 0 && Math.sin(this.ambientTime * 0.8) > 0.35 ? 1 : 0,
          isPlayer: false,
        });
      }
    }

    drawLightSweep() {
      const { ctx } = this;
      const x = ((this.ambientTime * 52) % 1700) - 300;
      const gradient = ctx.createLinearGradient(x, 0, x + 330, 0);
      gradient.addColorStop(0, "rgba(255,244,190,0)");
      gradient.addColorStop(0.5, "rgba(255,244,190,0.08)");
      gradient.addColorStop(1, "rgba(255,244,190,0)");
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, WORLD.width, WORLD.height);
    }
  }

  const canvas = document.getElementById("game-canvas");
  const audio = new AudioSystem();
  const input = new InputSystem();
  const ui = {
    startScreen: document.getElementById("start-screen"),
    selectScreen: document.getElementById("select-screen"),
    pauseScreen: document.getElementById("pause-screen"),
    finishScreen: document.getElementById("finish-screen"),
    hud: document.getElementById("hud"),
    pauseButton: document.getElementById("pause-button"),
    soundButton: document.getElementById("sound-button"),
    touchControls: document.getElementById("touch-controls"),
    countdown: document.getElementById("countdown"),
    lapValue: document.getElementById("lap-value"),
    positionValue: document.getElementById("position-value"),
    positionSuffix: document.getElementById("position-suffix"),
    speedValue: document.getElementById("speed-value"),
    announcement: document.getElementById("announcement"),
    itemButton: document.getElementById("item-button"),
    finishPlace: document.getElementById("finish-place"),
    finishKicker: document.getElementById("finish-kicker"),
    finishTitle: document.getElementById("finish-title"),
    finishCopy: document.getElementById("finish-copy"),
    finishTime: document.getElementById("finish-time"),
    bestLap: document.getElementById("best-lap"),
    pickupCount: document.getElementById("pickup-count"),
  };

  const screens = {
    start: ui.startScreen,
    select: ui.selectScreen,
    pause: ui.pauseScreen,
    finish: ui.finishScreen,
  };

  function hideScreens() {
    Object.values(screens).forEach((screen) => screen.classList.remove("is-active"));
  }

  function showScreen(name) {
    hideScreens();
    if (screens[name]) screens[name].classList.add("is-active");
  }

  function statusMessage(message) {
    document.getElementById("sr-status").textContent = message;
  }

  const game = new CartGame(canvas);

  document.getElementById("meet-racers-button").addEventListener("click", () => {
    audio.enable();
    audio.beep(410, 0.1, "square", 0.05);
    game.state = "select";
    showScreen("select");
    document.querySelector(".racer-card.is-selected").focus();
  });

  document.getElementById("back-button").addEventListener("click", () => {
    game.state = "menu";
    showScreen("start");
  });

  document.querySelectorAll(".racer-card").forEach((card) => {
    card.addEventListener("click", () => {
      const racerIndex = Number(card.dataset.racer);
      game.setSelectedRacer(racerIndex);
      document.querySelectorAll(".racer-card").forEach((otherCard) => {
        const selected = otherCard === card;
        otherCard.classList.toggle("is-selected", selected);
        otherCard.setAttribute("aria-checked", String(selected));
      });
      audio.enable();
      audio.beep(350 + racerIndex * 70, 0.09, "sine", 0.055);
      statusMessage(`${RACERS[racerIndex].name} selected. ${RACERS[racerIndex].perk}.`);
    });
    card.addEventListener("keydown", (event) => {
      if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return;
      event.preventDefault();
      const cards = [...document.querySelectorAll(".racer-card")];
      const current = cards.indexOf(card);
      const next = event.key === "ArrowRight" ? (current + 1) % cards.length : (current - 1 + cards.length) % cards.length;
      cards[next].focus();
      cards[next].click();
    });
  });

  document.getElementById("start-race-button").addEventListener("click", () => {
    hideScreens();
    game.startRace();
    statusMessage(`Racing as ${RACERS[game.selectedRacer].name}. Three laps.`);
  });

  ui.pauseButton.addEventListener("click", () => game.pause());
  document.getElementById("resume-button").addEventListener("click", () => game.resume());
  document.getElementById("restart-button").addEventListener("click", () => {
    hideScreens();
    game.startRace();
  });
  document.getElementById("race-again-button").addEventListener("click", () => {
    hideScreens();
    game.startRace();
  });
  document.getElementById("change-racer-button").addEventListener("click", () => {
    game.state = "select";
    game.setRacingUi(false);
    showScreen("select");
  });

  ui.soundButton.addEventListener("click", () => {
    audio.enable();
    audio.setMuted(!audio.muted);
    ui.soundButton.classList.toggle("is-muted", audio.muted);
    ui.soundButton.setAttribute("aria-label", audio.muted ? "Turn sound on" : "Mute sound");
    if (!audio.muted) audio.beep(460, 0.08, "sine", 0.05);
  });

  const storyButton = document.getElementById("story-button");
  const storyNote = document.getElementById("story-note");
  storyButton.addEventListener("click", () => {
    const expanded = storyButton.getAttribute("aria-expanded") === "true";
    storyButton.setAttribute("aria-expanded", String(!expanded));
    storyNote.hidden = expanded;
  });

  document.addEventListener("visibilitychange", () => {
    if (document.hidden && (game.state === "racing" || game.state === "countdown")) game.pause();
  });

  window.addEventListener("contextmenu", (event) => event.preventDefault());

  if ("serviceWorker" in navigator && window.location.protocol.startsWith("http")) {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("service-worker.js").catch(() => {
        // Offline install is an enhancement; gameplay remains fully local without it.
      });
    });
  }

  window.CartRally = {
    formatTime,
    ordinalSuffix,
    angleDifference,
    pointOnTrack,
  };
})();
