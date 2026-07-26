(() => {
  "use strict";

  const TRACK_LENGTH = 7800;
  const TOTAL_LAPS = 3;
  const VIEW_DISTANCE = 2100;
  const MAX_SPEED = 430;
  const BOOST_SPEED = 575;
  const COLORS = ["#f05b39", "#7bcac2", "#e6fa35", "#9c7ad6", "#ff9d42"];

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const lerp = (a, b, t) => a + (b - a) * t;
  const wrap = (value, size) => ((value % size) + size) % size;
  const suffix = (place) => (place === 1 ? "ST" : place === 2 ? "ND" : place === 3 ? "RD" : "TH");
  const formatTime = (seconds) => {
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    const hundredths = Math.floor((seconds % 1) * 100);
    return `${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${String(hundredths).padStart(2, "0")}`;
  };

  class SoundDeck {
    constructor(button) {
      this.button = button;
      this.enabled = true;
      this.context = null;
      this.rattleAt = 0;
    }

    unlock() {
      if (!this.context) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) this.context = new AudioContext();
      }
      if (this.context?.state === "suspended") this.context.resume();
    }

    toggle() {
      this.enabled = !this.enabled;
      this.button.classList.toggle("muted", !this.enabled);
      this.button.setAttribute("aria-label", this.enabled ? "Mute sound" : "Turn sound on");
      if (this.enabled) {
        this.unlock();
        this.tone(340, .05, "triangle", .035);
      }
    }

    tone(frequency, duration = .09, type = "square", volume = .05, endFrequency = frequency) {
      if (!this.enabled || !this.context) return;
      const now = this.context.currentTime;
      const oscillator = this.context.createOscillator();
      const gain = this.context.createGain();
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, now);
      oscillator.frequency.exponentialRampToValueAtTime(Math.max(20, endFrequency), now + duration);
      gain.gain.setValueAtTime(volume, now);
      gain.gain.exponentialRampToValueAtTime(.001, now + duration);
      oscillator.connect(gain).connect(this.context.destination);
      oscillator.start(now);
      oscillator.stop(now + duration);
    }

    countdown(go = false) {
      this.tone(go ? 660 : 330, go ? .22 : .08, "square", .045, go ? 880 : 300);
    }

    pickup() {
      this.tone(510, .16, "triangle", .07, 980);
    }

    crash() {
      this.tone(120, .25, "sawtooth", .08, 38);
    }

    boost() {
      this.tone(180, .48, "sawtooth", .055, 680);
    }

    tick(speed, time) {
      if (!this.enabled || speed < 80 || time < this.rattleAt) return;
      this.rattleAt = time + lerp(.13, .045, speed / BOOST_SPEED);
      this.tone(70 + Math.random() * 35, .018, "square", .012, 45);
    }
  }

  class AisleOutlaws {
    constructor() {
      this.canvas = document.querySelector("#game");
      this.ctx = this.canvas.getContext("2d");
      this.dom = {
        menu: document.querySelector("#menu-screen"),
        how: document.querySelector("#how-screen"),
        hud: document.querySelector("#hud"),
        countdown: document.querySelector("#countdown"),
        pause: document.querySelector("#pause-screen"),
        result: document.querySelector("#result-screen"),
        touch: document.querySelector("#touch-controls"),
        pauseButton: document.querySelector("#pause-button"),
        boostButton: document.querySelector("#boost-button"),
        speed: document.querySelector("#speed"),
        lap: document.querySelector("#lap"),
        position: document.querySelector("#position"),
        suffix: document.querySelector("#position-suffix"),
        mapDot: document.querySelector("#map-dot"),
        toast: document.querySelector("#toast"),
      };
      this.sound = new SoundDeck(document.querySelector("#sound-button"));
      this.width = 0;
      this.height = 0;
      this.dpr = 1;
      this.state = "menu";
      this.lastTime = 0;
      this.keys = { left: false, right: false };
      this.steer = 0;
      this.shake = 0;
      this.flash = 0;
      this.animation = requestAnimationFrame((time) => this.frame(time));
      this.bind();
      this.resize();
      this.reset();
    }

    bind() {
      window.addEventListener("resize", () => this.resize());
      window.addEventListener("orientationchange", () => setTimeout(() => this.resize(), 160));
      document.querySelector("#play-button").addEventListener("click", () => this.start());
      document.querySelector("#again-button").addEventListener("click", () => this.start());
      document.querySelector("#how-button").addEventListener("click", () => this.dom.how.classList.remove("hidden"));
      document.querySelectorAll("[data-close]").forEach((button) => {
        button.addEventListener("click", () => this.dom.how.classList.add("hidden"));
      });
      document.querySelector("#sound-button").addEventListener("click", () => this.sound.toggle());
      this.dom.pauseButton.addEventListener("click", () => this.pause());
      document.querySelector("#resume-button").addEventListener("click", () => this.resume());
      document.querySelector("#quit-button").addEventListener("click", () => this.menu());
      document.querySelector("#menu-button").addEventListener("click", () => this.menu());
      this.dom.boostButton.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        this.useBoost();
      });

      this.bindHold(document.querySelector("#left-button"), "left");
      this.bindHold(document.querySelector("#right-button"), "right");

      window.addEventListener("keydown", (event) => {
        if (["ArrowLeft", "a", "A"].includes(event.key)) this.keys.left = true;
        if (["ArrowRight", "d", "D"].includes(event.key)) this.keys.right = true;
        if (event.key === " " || event.key === "ArrowUp") {
          event.preventDefault();
          this.useBoost();
        }
        if (event.key === "Escape" && this.state === "racing") this.pause();
        else if (event.key === "Escape" && this.state === "paused") this.resume();
      });
      window.addEventListener("keyup", (event) => {
        if (["ArrowLeft", "a", "A"].includes(event.key)) this.keys.left = false;
        if (["ArrowRight", "d", "D"].includes(event.key)) this.keys.right = false;
      });
      document.addEventListener("visibilitychange", () => {
        if (document.hidden && this.state === "racing") this.pause();
      });
    }

    bindHold(button, direction) {
      const down = (event) => {
        event.preventDefault();
        button.setPointerCapture?.(event.pointerId);
        this.keys[direction] = true;
        button.classList.add("pressed");
      };
      const up = () => {
        this.keys[direction] = false;
        button.classList.remove("pressed");
      };
      button.addEventListener("pointerdown", down);
      button.addEventListener("pointerup", up);
      button.addEventListener("pointercancel", up);
      button.addEventListener("lostpointercapture", up);
    }

    resize() {
      const rect = this.canvas.getBoundingClientRect();
      this.dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.width = Math.max(1, rect.width);
      this.height = Math.max(1, rect.height);
      this.canvas.width = Math.round(this.width * this.dpr);
      this.canvas.height = Math.round(this.height * this.dpr);
      this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    }

    reset() {
      this.progress = 0;
      this.previousProgress = 0;
      this.speed = 0;
      this.topSpeed = 0;
      this.playerX = 0;
      this.steer = 0;
      this.raceTime = 0;
      this.boostCharge = false;
      this.boostTimer = 0;
      this.hitTimer = 0;
      this.crates = 0;
      this.finishedPlace = 1;
      this.collected = new Set();
      this.hitObjects = new Set();
      this.objects = this.makeObjects();
      this.rivals = this.makeRivals();
      this.updateHud();
    }

    makeObjects() {
      const objects = [];
      const lanes = [-.62, 0, .62];
      for (let z = 620, i = 0; z < TRACK_LENGTH - 220; z += 430, i += 1) {
        const lane = lanes[(i * 2 + 1) % lanes.length];
        if (i % 3 === 0 || i % 7 === 0) {
          objects.push({ z, lane, type: "crate", id: `c${i}` });
        } else {
          objects.push({ z, lane, type: i % 2 ? "spill" : "display", id: `o${i}` });
        }
        if (i % 4 === 1) {
          const secondLane = lanes[(i + 1) % lanes.length];
          objects.push({ z: z + 155, lane: secondLane, type: "crate", id: `b${i}` });
        }
      }
      return objects;
    }

    makeRivals() {
      return COLORS.map((color, index) => ({
        name: ["RUSTY", "ZIP", "MABEL", "WOBBLE", "PATCH"][index],
        color,
        progress: 25 + index * 28,
        speed: 344 + index * 7 + Math.random() * 20,
        baseSpeed: 344 + index * 7 + Math.random() * 20,
        lane: -.65 + index * .32,
        targetLane: -.65 + index * .32,
        wobble: Math.random() * Math.PI * 2,
        nextLaneAt: 700 + Math.random() * 800,
      }));
    }

    async start() {
      this.sound.unlock();
      this.reset();
      this.state = "countdown";
      this.dom.menu.classList.add("hidden");
      this.dom.result.classList.add("hidden");
      this.dom.pause.classList.add("hidden");
      this.dom.how.classList.add("hidden");
      this.canvas.classList.add("active");
      this.dom.hud.classList.remove("hidden");
      this.dom.touch.classList.remove("hidden");
      this.dom.pauseButton.classList.remove("hidden");

      for (const value of ["3", "2", "1", "GO!"]) {
        this.dom.countdown.textContent = value;
        this.dom.countdown.classList.remove("hidden");
        this.dom.countdown.style.animation = "none";
        void this.dom.countdown.offsetWidth;
        this.dom.countdown.style.animation = "";
        this.sound.countdown(value === "GO!");
        await new Promise((resolve) => setTimeout(resolve, value === "GO!" ? 650 : 720));
        if (this.state !== "countdown") return;
      }
      this.dom.countdown.classList.add("hidden");
      this.state = "racing";
      this.lastTime = performance.now();
    }

    pause() {
      if (this.state !== "racing" && this.state !== "countdown") return;
      this.state = "paused";
      this.keys.left = false;
      this.keys.right = false;
      this.dom.pause.classList.remove("hidden");
    }

    resume() {
      if (this.state !== "paused") return;
      this.state = "racing";
      this.lastTime = performance.now();
      this.dom.pause.classList.add("hidden");
    }

    menu() {
      this.state = "menu";
      this.keys.left = false;
      this.keys.right = false;
      this.dom.menu.classList.remove("hidden");
      this.dom.pause.classList.add("hidden");
      this.dom.result.classList.add("hidden");
      this.dom.hud.classList.add("hidden");
      this.dom.touch.classList.add("hidden");
      this.dom.pauseButton.classList.add("hidden");
      this.dom.countdown.classList.add("hidden");
      this.canvas.classList.remove("active");
    }

    useBoost() {
      if (this.state !== "racing" || !this.boostCharge) return;
      this.boostCharge = false;
      this.boostTimer = 2.15;
      this.speed = Math.max(this.speed, MAX_SPEED);
      this.flash = .8;
      this.dom.boostButton.classList.add("empty");
      this.sound.boost();
      navigator.vibrate?.([25, 20, 35]);
      this.toast("EXPRESS LANE!");
    }

    toast(message) {
      this.dom.toast.textContent = message;
      this.dom.toast.classList.remove("hidden");
      this.dom.toast.style.animation = "none";
      void this.dom.toast.offsetWidth;
      this.dom.toast.style.animation = "";
      clearTimeout(this.toastTimer);
      this.toastTimer = setTimeout(() => this.dom.toast.classList.add("hidden"), 950);
    }

    curveAt(z) {
      const phase = wrap(z, TRACK_LENGTH) / TRACK_LENGTH;
      return Math.sin(phase * Math.PI * 4) * .42 + Math.sin(phase * Math.PI * 10 + .8) * .14;
    }

    trackCenterAt(distance, roadHalf) {
      const here = this.curveAt(this.progress);
      const ahead = this.curveAt(this.progress + distance);
      const influence = Math.pow(clamp(distance / VIEW_DISTANCE, 0, 1), .75);
      return this.width / 2 + (ahead - here) * roadHalf * 1.7 * influence - this.playerX * roadHalf * .27;
    }

    update(dt, now) {
      if (this.state !== "racing") return;
      dt = Math.min(dt, .035);
      this.raceTime += dt;
      this.previousProgress = this.progress;
      this.hitTimer = Math.max(0, this.hitTimer - dt);
      this.boostTimer = Math.max(0, this.boostTimer - dt);
      this.flash = Math.max(0, this.flash - dt * 1.8);
      this.shake = Math.max(0, this.shake - dt * 2.6);

      const steering = (this.keys.right ? 1 : 0) - (this.keys.left ? 1 : 0);
      this.steer = lerp(this.steer, steering, clamp(dt * 9, 0, 1));
      const steerRate = lerp(1.05, 1.62, clamp(this.speed / MAX_SPEED, 0, 1));
      this.playerX = clamp(this.playerX + this.steer * steerRate * dt, -1.04, 1.04);

      const cap = this.boostTimer > 0 ? BOOST_SPEED : MAX_SPEED;
      const acceleration = this.hitTimer > 0 ? 70 : 128;
      this.speed = Math.min(cap, this.speed + acceleration * dt);
      if (this.boostTimer <= 0 && this.speed > MAX_SPEED) this.speed -= 105 * dt;
      if (Math.abs(this.playerX) > .81) this.speed -= 215 * dt;
      if (this.hitTimer > 0) this.speed -= 80 * dt;
      this.speed = clamp(this.speed, 80, BOOST_SPEED);
      this.topSpeed = Math.max(this.topSpeed, this.speed);
      this.progress += this.speed * dt;

      this.updateRivals(dt);
      this.checkObjects();
      this.sound.tick(this.speed, now / 1000);
      this.updateHud();

      if (this.progress >= TRACK_LENGTH * TOTAL_LAPS) this.finish();
    }

    updateRivals(dt) {
      this.rivals.forEach((rival, index) => {
        const lap = rival.progress / TRACK_LENGTH;
        const rubberBand = clamp((this.progress - rival.progress) / 3500, -.1, .13);
        const lateRace = lap > 2 ? index * 2.3 : 0;
        rival.speed = lerp(rival.speed, rival.baseSpeed * (1 + rubberBand) + lateRace, dt * .8);
        rival.progress += rival.speed * dt;
        rival.wobble += dt * (1.3 + index * .09);
        if (rival.progress > rival.nextLaneAt) {
          rival.targetLane = -.7 + Math.random() * 1.4;
          rival.nextLaneAt += 750 + Math.random() * 1200;
        }
        rival.lane = lerp(rival.lane, rival.targetLane, dt * .42);
      });
    }

    checkObjects() {
      const currentLap = Math.floor(this.progress / TRACK_LENGTH);
      const oldWrapped = wrap(this.previousProgress, TRACK_LENGTH);
      const newWrapped = wrap(this.progress, TRACK_LENGTH);
      const crossed = (z) => {
        if (newWrapped >= oldWrapped) return z > oldWrapped && z <= newWrapped + 25;
        return z > oldWrapped || z <= newWrapped + 25;
      };

      this.objects.forEach((object) => {
        if (!crossed(object.z) || Math.abs(this.playerX - object.lane) > .27) return;
        const key = `${currentLap}:${object.id}`;
        if (object.type === "crate") {
          if (this.collected.has(key)) return;
          this.collected.add(key);
          this.crates += 1;
          this.boostCharge = true;
          this.dom.boostButton.classList.remove("empty");
          this.sound.pickup();
          navigator.vibrate?.(25);
          this.toast("BOOST READY");
        } else {
          if (this.hitObjects.has(key) || this.boostTimer > 0) return;
          this.hitObjects.add(key);
          this.speed *= .55;
          this.hitTimer = .9;
          this.shake = 1;
          this.sound.crash();
          navigator.vibrate?.([45, 30, 55]);
          this.toast(object.type === "spill" ? "CLEANUP, AISLE 5!" : "DISPLAY DEMOLISHED");
        }
      });
    }

    place() {
      return 1 + this.rivals.filter((rival) => rival.progress > this.progress).length;
    }

    updateHud() {
      if (!this.dom.speed) return;
      const place = this.place();
      const lap = clamp(Math.floor(this.progress / TRACK_LENGTH) + 1, 1, TOTAL_LAPS);
      this.dom.speed.textContent = Math.round(this.speed * .52);
      this.dom.lap.textContent = `${lap} / ${TOTAL_LAPS}`;
      this.dom.position.textContent = place;
      this.dom.suffix.textContent = suffix(place);
      const angle = (wrap(this.progress, TRACK_LENGTH) / TRACK_LENGTH) * Math.PI * 2;
      this.dom.mapDot.setAttribute("cx", String(50 + Math.cos(angle) * 33));
      this.dom.mapDot.setAttribute("cy", String(34 + Math.sin(angle) * 21));
    }

    finish() {
      this.state = "finished";
      this.finishedPlace = this.place();
      this.speed *= .7;
      this.dom.touch.classList.add("hidden");
      this.dom.pauseButton.classList.add("hidden");
      document.querySelector("#result-position").innerHTML = `${this.finishedPlace}<sup>${suffix(this.finishedPlace)}</sup>`;
      document.querySelector("#result-title").textContent = this.finishedPlace === 1 ? "AISLE LEGEND" : this.finishedPlace <= 3 ? "PODIUM SCRAPPER" : "CART SURVIVOR";
      document.querySelector("#result-time").textContent = formatTime(this.raceTime);
      document.querySelector("#result-speed").textContent = `${Math.round(this.topSpeed * .52)} KM/H`;
      document.querySelector("#result-crates").textContent = this.crates;
      setTimeout(() => {
        if (this.state === "finished") this.dom.result.classList.remove("hidden");
      }, 700);
      this.sound.tone(this.finishedPlace === 1 ? 520 : 330, .55, "triangle", .06, this.finishedPlace === 1 ? 1040 : 460);
    }

    frame(time) {
      const dt = this.lastTime ? (time - this.lastTime) / 1000 : 0;
      this.lastTime = time;
      this.update(dt, time);
      if (this.state !== "menu") this.render(time / 1000);
      this.animation = requestAnimationFrame((next) => this.frame(next));
    }

    render(time) {
      const ctx = this.ctx;
      const w = this.width;
      const h = this.height;
      ctx.save();
      if (this.shake > 0) {
        ctx.translate((Math.random() - .5) * this.shake * 12, (Math.random() - .5) * this.shake * 8);
      }
      ctx.clearRect(-20, -20, w + 40, h + 40);
      this.drawStore(time);
      this.drawTrack(time);
      this.drawWorldObjects(time);
      this.drawRivals(time);
      this.drawPlayer(time);
      if (this.flash > 0) {
        ctx.fillStyle = `rgba(230,250,53,${this.flash * .1})`;
        ctx.fillRect(0, 0, w, h);
      }
      ctx.restore();
    }

    drawStore(time) {
      const ctx = this.ctx;
      const w = this.width;
      const h = this.height;
      const horizon = h * .28;
      const ceiling = ctx.createLinearGradient(0, 0, 0, horizon);
      ceiling.addColorStop(0, "#171a17");
      ceiling.addColorStop(1, "#4b5045");
      ctx.fillStyle = ceiling;
      ctx.fillRect(0, 0, w, horizon + 2);

      ctx.strokeStyle = "rgba(236,240,214,.08)";
      ctx.lineWidth = 1;
      for (let x = -w; x < w * 2; x += Math.max(80, w / 10)) {
        ctx.beginPath();
        ctx.moveTo(w / 2, horizon);
        ctx.lineTo(x, 0);
        ctx.stroke();
      }
      for (let y = 18; y < horizon; y += 34) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }

      const lightOffset = wrap(this.progress * .75, 180);
      for (let x = -180 + lightOffset; x < w + 180; x += 180) {
        const spread = (x - w / 2) * .17;
        ctx.fillStyle = "rgba(238,244,218,.72)";
        ctx.shadowColor = "#eaffd7";
        ctx.shadowBlur = 12;
        ctx.fillRect(x + spread, 12, 72, 3);
      }
      ctx.shadowBlur = 0;

      const signText = ["PRODUCE", "HOMEWARES", "FROZEN", "CHECKOUT"][Math.floor(wrap(this.progress, TRACK_LENGTH) / (TRACK_LENGTH / 4))];
      ctx.save();
      ctx.translate(w / 2 + Math.sin(time * .7) * 2, horizon * .54);
      ctx.fillStyle = "#e6fa35";
      ctx.transform(1, 0, -.08, 1, 0, 0);
      ctx.fillRect(-62, -17, 124, 34);
      ctx.fillStyle = "#171813";
      ctx.font = "900 16px 'Barlow Condensed', sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(signText, 0, 0);
      ctx.restore();
    }

    drawTrack() {
      const ctx = this.ctx;
      const w = this.width;
      const h = this.height;
      const horizon = h * .28;
      const slices = 44;
      let previous = null;

      for (let i = 0; i <= slices; i += 1) {
        const t = i / slices;
        const depth = Math.pow(t, 1.62);
        const distance = VIEW_DISTANCE * (1 - t);
        const y = horizon + depth * (h - horizon + 45);
        const half = lerp(w * .055, w * .55, Math.pow(t, 1.42));
        const center = this.trackCenterAt(distance, half);
        const current = { y, half, center, distance };

        if (previous) {
          const segment = Math.floor((this.progress + distance) / 135);
          ctx.fillStyle = segment % 2 ? "#8d9185" : "#9b9f92";
          this.quad(
            previous.center - previous.half, previous.y,
            previous.center + previous.half, previous.y,
            current.center + current.half, current.y,
            current.center - current.half, current.y
          );

          const edgeColor = segment % 2 ? "#e6fa35" : "#23251f";
          ctx.fillStyle = edgeColor;
          this.roadStripe(previous, current, -1);
          this.roadStripe(previous, current, 1);

          if (segment % 3 === 0) {
            ctx.strokeStyle = "rgba(53,56,49,.34)";
            ctx.lineWidth = Math.max(1, t * 2);
            for (const lane of [-.33, .33]) {
              ctx.beginPath();
              ctx.moveTo(previous.center + previous.half * lane, previous.y);
              ctx.lineTo(current.center + current.half * lane, current.y);
              ctx.stroke();
            }
          }

          this.drawShelfSlice(previous, current, segment, -1, t);
          this.drawShelfSlice(previous, current, segment, 1, t);
        }
        previous = current;
      }
    }

    quad(x1, y1, x2, y2, x3, y3, x4, y4) {
      const ctx = this.ctx;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.lineTo(x3, y3);
      ctx.lineTo(x4, y4);
      ctx.closePath();
      ctx.fill();
    }

    roadStripe(far, near, side) {
      const widthFar = Math.max(1.5, far.half * .025);
      const widthNear = Math.max(2, near.half * .025);
      this.quad(
        far.center + side * far.half, far.y,
        far.center + side * (far.half - widthFar), far.y,
        near.center + side * (near.half - widthNear), near.y,
        near.center + side * near.half, near.y
      );
    }

    drawShelfSlice(far, near, segment, side, t) {
      if (segment % 4 !== 0) return;
      const ctx = this.ctx;
      const baseX = near.center + side * (near.half + near.half * .06);
      const width = Math.max(4, near.half * .18);
      const height = Math.max(8, t * t * this.height * .52);
      ctx.fillStyle = side < 0 ? "#2d322d" : "#34382f";
      ctx.fillRect(side < 0 ? baseX - width : baseX, near.y - height, width, height);
      ctx.fillStyle = segment % 8 ? "#f05b39" : "#7bcac2";
      const shelfX = side < 0 ? baseX - width * .87 : baseX + width * .12;
      for (let row = 1; row <= 3; row += 1) {
        const yy = near.y - height * (row / 4);
        ctx.fillRect(shelfX, yy, width * .75, Math.max(2, height * .08));
      }
      ctx.fillStyle = "rgba(230,250,53,.6)";
      ctx.fillRect(side < 0 ? baseX - width : baseX, near.y - 3, width, Math.max(2, t * 4));
    }

    project(distance, lane) {
      const t = clamp(1 - distance / VIEW_DISTANCE, 0, 1);
      const y = this.height * .28 + Math.pow(t, 1.62) * (this.height * .76);
      const half = lerp(this.width * .055, this.width * .55, Math.pow(t, 1.42));
      return {
        x: this.trackCenterAt(distance, half) + lane * half * .72,
        y,
        scale: .12 + Math.pow(t, 1.85) * 1.08,
        alpha: clamp(t * 1.8, 0, 1),
      };
    }

    drawWorldObjects(time) {
      const lap = Math.floor(this.progress / TRACK_LENGTH);
      const wrapped = wrap(this.progress, TRACK_LENGTH);
      const visible = [];
      this.objects.forEach((object) => {
        let distance = object.z - wrapped;
        if (distance < 0) distance += TRACK_LENGTH;
        if (distance < 35 || distance > VIEW_DISTANCE) return;
        const key = `${lap}:${object.id}`;
        if (object.type === "crate" && this.collected.has(key)) return;
        if (object.type !== "crate" && this.hitObjects.has(key)) return;
        visible.push({ ...object, distance });
      });
      visible.sort((a, b) => b.distance - a.distance);
      visible.forEach((object) => {
        const point = this.project(object.distance, object.lane);
        this.ctx.save();
        this.ctx.globalAlpha = point.alpha;
        this.ctx.translate(point.x, point.y);
        this.ctx.scale(point.scale, point.scale);
        if (object.type === "crate") this.drawCrate(time + object.z);
        else if (object.type === "spill") this.drawSpill();
        else this.drawDisplay();
        this.ctx.restore();
      });
    }

    drawCrate(time) {
      const ctx = this.ctx;
      const bob = Math.sin(time * 3) * 5;
      ctx.translate(0, bob);
      ctx.shadowColor = "#e6fa35";
      ctx.shadowBlur = 22;
      ctx.fillStyle = "rgba(230,250,53,.25)";
      ctx.fillRect(-26, -62, 52, 58);
      ctx.shadowBlur = 0;
      ctx.fillStyle = "#e6fa35";
      ctx.fillRect(-22, -58, 44, 44);
      ctx.strokeStyle = "#171813";
      ctx.lineWidth = 5;
      ctx.strokeRect(-22, -58, 44, 44);
      ctx.fillStyle = "#171813";
      ctx.beginPath();
      ctx.moveTo(4, -53);
      ctx.lineTo(-10, -31);
      ctx.lineTo(1, -31);
      ctx.lineTo(-4, -17);
      ctx.lineTo(13, -38);
      ctx.lineTo(2, -38);
      ctx.closePath();
      ctx.fill();
    }

    drawSpill() {
      const ctx = this.ctx;
      ctx.fillStyle = "#f05b39";
      ctx.beginPath();
      ctx.ellipse(0, -3, 44, 12, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#f4d3b1";
      ctx.fillRect(-7, -29, 19, 26);
      ctx.fillStyle = "#7bcac2";
      ctx.fillRect(-4, -26, 13, 8);
    }

    drawDisplay() {
      const ctx = this.ctx;
      ctx.fillStyle = "#574339";
      ctx.fillRect(-42, -60, 84, 60);
      ctx.fillStyle = "#f0b347";
      for (let row = 0; row < 3; row += 1) {
        for (let col = 0; col < 4; col += 1) {
          ctx.beginPath();
          ctx.arc(-29 + col * 19, -48 + row * 17, 7, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      ctx.fillStyle = "#e9e4d5";
      ctx.fillRect(-47, -72, 94, 17);
      ctx.fillStyle = "#171813";
      ctx.font = "900 11px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("DEAL!", 0, -60);
    }

    drawRivals(time) {
      const visible = [];
      this.rivals.forEach((rival) => {
        let distance = rival.progress - this.progress;
        if (distance < -30) distance += TRACK_LENGTH;
        if (distance < 60 || distance > VIEW_DISTANCE) return;
        visible.push({ rival, distance });
      });
      visible.sort((a, b) => b.distance - a.distance);
      visible.forEach(({ rival, distance }) => {
        const point = this.project(distance, rival.lane + Math.sin(rival.wobble) * .025);
        this.ctx.save();
        this.ctx.globalAlpha = point.alpha;
        this.ctx.translate(point.x, point.y);
        this.ctx.scale(point.scale * .86, point.scale * .86);
        this.drawCart(rival.color, Math.sin(time * 8 + rival.wobble) * 2, false);
        this.ctx.restore();
      });
    }

    drawPlayer(time) {
      const ctx = this.ctx;
      const w = this.width;
      const h = this.height;
      const x = w / 2 + this.steer * w * .025;
      const y = h * .92;

      if (this.boostTimer > 0) {
        const strength = this.boostTimer / 2.15;
        ctx.strokeStyle = `rgba(230,250,53,${.15 + strength * .3})`;
        ctx.lineWidth = 2;
        for (let i = 0; i < 14; i += 1) {
          const sx = Math.random() * w;
          const sy = h * .3 + Math.random() * h * .7;
          ctx.beginPath();
          ctx.moveTo(sx, sy);
          ctx.lineTo(sx + (sx - w / 2) * .12, sy + 25 + Math.random() * 45);
          ctx.stroke();
        }
      }

      const scale = clamp(w / 920, .72, 1.15);
      ctx.save();
      ctx.translate(x, y + Math.sin(time * 15) * Math.min(2.5, this.speed / 180));
      ctx.rotate(-this.steer * .045);
      ctx.scale(scale, scale);
      this.drawCart("#e6fa35", this.steer * 5, true);
      ctx.restore();
    }

    drawCart(color, lean, player) {
      const ctx = this.ctx;
      ctx.save();
      ctx.translate(lean, 0);
      ctx.shadowColor = "rgba(0,0,0,.55)";
      ctx.shadowBlur = 14;
      ctx.shadowOffsetY = 10;
      ctx.fillStyle = "#151613";
      ctx.beginPath();
      ctx.ellipse(0, 0, player ? 69 : 58, player ? 16 : 13, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.shadowOffsetY = 0;

      ctx.fillStyle = "#11120f";
      ctx.fillRect(-55, -8, 17, 24);
      ctx.fillRect(38, -8, 17, 24);
      ctx.fillStyle = "#c7ccc4";
      ctx.fillRect(-50, -5, 7, 15);
      ctx.fillRect(43, -5, 7, 15);

      ctx.fillStyle = color;
      ctx.strokeStyle = "#171813";
      ctx.lineWidth = player ? 7 : 6;
      ctx.beginPath();
      ctx.moveTo(-57, -67);
      ctx.lineTo(57, -67);
      ctx.lineTo(43, -12);
      ctx.lineTo(-43, -12);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();

      ctx.strokeStyle = "rgba(22,24,19,.7)";
      ctx.lineWidth = 4;
      for (let x = -31; x <= 31; x += 21) {
        ctx.beginPath();
        ctx.moveTo(x, -63);
        ctx.lineTo(x * .72, -16);
        ctx.stroke();
      }
      for (let y = -49; y <= -25; y += 13) {
        ctx.beginPath();
        ctx.moveTo(-51, y);
        ctx.lineTo(51, y);
        ctx.stroke();
      }

      ctx.strokeStyle = "#d5d9d1";
      ctx.lineWidth = 7;
      ctx.beginPath();
      ctx.moveTo(-48, -65);
      ctx.lineTo(-63, -92);
      ctx.lineTo(-78, -92);
      ctx.stroke();
      ctx.strokeStyle = color;
      ctx.lineWidth = 11;
      ctx.beginPath();
      ctx.moveTo(-79, -92);
      ctx.lineTo(-108, -92);
      ctx.stroke();

      ctx.fillStyle = "#e7e2d6";
      ctx.fillRect(-29, -59, 58, 22);
      ctx.fillStyle = "#181914";
      ctx.font = `900 ${player ? 17 : 14}px 'Barlow Condensed', sans-serif`;
      ctx.textAlign = "center";
      ctx.fillText(player ? "07" : "RIVAL", 0, -43);
      ctx.restore();
    }
  }

  window.addEventListener("DOMContentLoaded", () => {
    window.aisleOutlaws = new AisleOutlaws();
    if ("serviceWorker" in navigator && location.protocol !== "file:") {
      navigator.serviceWorker.register("service-worker.js").catch(() => {});
    }
  });

  if (typeof module !== "undefined") {
    module.exports = { clamp, lerp, wrap, suffix, formatTime, TRACK_LENGTH, TOTAL_LAPS };
  }
})();
