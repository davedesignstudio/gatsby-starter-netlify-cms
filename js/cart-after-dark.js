(() => {
  "use strict";

  const canvas = document.getElementById("game-canvas");
  const ctx = canvas.getContext("2d", { alpha: false });

  const ui = {
    menu: document.getElementById("menu-screen"),
    hud: document.getElementById("hud"),
    controls: document.getElementById("touch-controls"),
    start: document.getElementById("start-button"),
    pause: document.getElementById("pause-button"),
    pauseScreen: document.getElementById("pause-screen"),
    resume: document.getElementById("resume-button"),
    restart: document.getElementById("restart-button"),
    result: document.getElementById("result-screen"),
    raceAgain: document.getElementById("race-again-button"),
    changeCart: document.getElementById("change-cart-button"),
    sound: document.getElementById("sound-button"),
    countdown: document.getElementById("countdown"),
    announcer: document.getElementById("announcer"),
    position: document.getElementById("position-value"),
    lap: document.getElementById("lap-value"),
    speed: document.getElementById("speed-value"),
    progressFill: document.getElementById("progress-fill"),
    progressPlayer: document.getElementById("progress-player"),
    boostFill: document.getElementById("boost-fill"),
    boostLabel: document.getElementById("boost-label"),
    itemSlot: document.getElementById("item-slot"),
    itemIcon: document.getElementById("item-icon"),
    itemName: document.getElementById("item-name"),
    controlItemIcon: document.getElementById("control-item-icon"),
    status: document.getElementById("a11y-status"),
    resultKicker: document.getElementById("result-kicker"),
    resultPosition: document.getElementById("result-position"),
    resultTitle: document.getElementById("result-title"),
    resultCopy: document.getElementById("result-copy"),
    resultTime: document.getElementById("result-time"),
    resultLap: document.getElementById("result-lap"),
    resultPickups: document.getElementById("result-pickups"),
    racerCount: document.getElementById("racer-count"),
  };

  const RACERS = [
    { name: "The Rattler", color: "#ff4b3e", accent: "#ffd2bd", maxSpeed: 108, accel: 47, handling: 1, armor: 1 },
    { name: "Blue Streak", color: "#25e3ff", accent: "#d8fbff", maxSpeed: 116, accel: 43, handling: 1.08, armor: 0.84 },
    { name: "Big Haul", color: "#ffbd2e", accent: "#fff0b2", maxSpeed: 102, accel: 44, handling: 0.9, armor: 1.34 },
  ];

  const ITEMS = {
    boost: { name: "Fizz boost", icon: "⚡", color: "#dfff34" },
    shield: { name: "Bubble wrap", icon: "◎", color: "#25e3ff" },
    snack: { name: "Snack attack", icon: "✦", color: "#ffbd2e" },
  };

  const COLORS = ["#ff4b3e", "#25e3ff", "#ffbd2e", "#bd69ff", "#62e56f"];
  const TOTAL_LAPS = 3;
  const LAP_LENGTH = 1800;
  const TOTAL_DISTANCE = TOTAL_LAPS * LAP_LENGTH;
  const VIEW_DISTANCE = 430;
  const input = { left: false, right: false, drift: false };

  let width = 1;
  let height = 1;
  let dpr = 1;
  let selectedRacer = 0;
  let phase = "menu";
  let previousPhase = "menu";
  let lastFrame = performance.now();
  let menuTime = 0;
  let countdownTimer = 0;
  let announcerTimer = 0;
  let shake = 0;
  let swipePointer = null;
  let swipeStart = 0;
  let objects = [];
  let opponents = [];
  let particles = [];
  let player;

  class GameAudio {
    constructor() {
      this.context = null;
      this.muted = false;
      this.engine = null;
      this.engineGain = null;
      this.engineFilter = null;
    }

    unlock() {
      if (this.muted) return;
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      if (!this.context) {
        this.context = new AudioContext();
        this.engine = this.context.createOscillator();
        this.engineGain = this.context.createGain();
        this.engineFilter = this.context.createBiquadFilter();
        this.engine.type = "sawtooth";
        this.engine.frequency.value = 48;
        this.engineFilter.type = "lowpass";
        this.engineFilter.frequency.value = 180;
        this.engineGain.gain.value = 0;
        this.engine.connect(this.engineFilter).connect(this.engineGain).connect(this.context.destination);
        this.engine.start();
      }
      if (this.context.state === "suspended") this.context.resume();
    }

    setEngine(speed, active) {
      if (!this.context || this.muted) return;
      const now = this.context.currentTime;
      const amount = Math.min(speed / 115, 1.3);
      this.engine.frequency.setTargetAtTime(48 + amount * 58, now, 0.07);
      this.engineFilter.frequency.setTargetAtTime(160 + amount * 430, now, 0.08);
      this.engineGain.gain.setTargetAtTime(active ? 0.025 + amount * 0.018 : 0, now, 0.1);
    }

    tone(frequency, duration = 0.12, type = "square", volume = 0.06, slide = 0) {
      if (!this.context || this.muted) return;
      const now = this.context.currentTime;
      const oscillator = this.context.createOscillator();
      const gain = this.context.createGain();
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, now);
      if (slide) oscillator.frequency.exponentialRampToValueAtTime(Math.max(30, frequency + slide), now + duration);
      gain.gain.setValueAtTime(volume, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
      oscillator.connect(gain).connect(this.context.destination);
      oscillator.start(now);
      oscillator.stop(now + duration);
    }

    countdown(number) {
      this.tone(number === 0 ? 520 : 260 + (3 - number) * 45, number === 0 ? 0.35 : 0.16, "square", 0.075, number === 0 ? 300 : 0);
    }

    pickup() {
      this.tone(520, 0.08, "sine", 0.07, 220);
      window.setTimeout(() => this.tone(790, 0.11, "sine", 0.05, 150), 55);
    }

    crash() {
      this.tone(95, 0.25, "sawtooth", 0.09, -55);
    }

    boost() {
      this.tone(180, 0.32, "sawtooth", 0.055, 480);
    }

    finish() {
      [330, 440, 554, 660].forEach((note, index) => {
        window.setTimeout(() => this.tone(note, 0.22, "square", 0.06, 50), index * 120);
      });
    }

    toggle() {
      this.muted = !this.muted;
      document.body.classList.toggle("is-muted", this.muted);
      if (!this.muted) this.unlock();
      if (this.engineGain && this.context) {
        this.engineGain.gain.setTargetAtTime(0, this.context.currentTime, 0.04);
      }
      return this.muted;
    }
  }

  const audio = new GameAudio();

  function createPlayer() {
    return {
      distance: 0,
      previousDistance: 0,
      x: 0,
      speed: 0,
      item: null,
      boostTimer: 0,
      shieldTimer: 0,
      invulnerable: 0,
      driftCharge: 0,
      wasDrifting: false,
      rank: 4,
      lap: 1,
      raceTime: 0,
      lapStarted: 0,
      lapTimes: [],
      pickups: 0,
      hitFlash: 0,
    };
  }

  function seededRandom(seed) {
    let value = seed >>> 0;
    return () => {
      value += 0x6d2b79f5;
      let result = value;
      result = Math.imul(result ^ (result >>> 15), result | 1);
      result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
      return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
    };
  }

  function buildTrack() {
    const random = seededRandom(9137);
    objects = [];
    for (let lap = 0; lap < TOTAL_LAPS; lap += 1) {
      const base = lap * LAP_LENGTH;
      for (let distance = 150; distance < LAP_LENGTH - 80; distance += 74 + random() * 50) {
        const typeRoll = random();
        const lane = -0.78 + random() * 1.56;
        let type = "crate";
        if (typeRoll < 0.36) type = "pickup";
        else if (typeRoll < 0.64) type = "spill";
        else if (typeRoll < 0.83) type = "crate";
        else type = "cone";
        objects.push({
          id: `${lap}-${Math.round(distance)}`,
          distance: base + distance,
          x: lane,
          type,
          used: false,
          spin: random() * Math.PI * 2,
        });
      }
    }

    const names = ["Night Owl", "Coupon King", "Loose Wheel", "Aisle Ace", "Tin Rocket"];
    const starts = [30, 17, 7, -10, -24];
    opponents = names.map((name, index) => ({
      name,
      color: COLORS[(index + 1) % COLORS.length],
      accent: COLORS[(index + 3) % COLORS.length],
      distance: starts[index],
      speed: 0,
      maxSpeed: 91 + index * 2.6 + random() * 6,
      x: -0.74 + index * 0.36,
      targetX: -0.7 + random() * 1.4,
      changeTimer: 1 + random() * 2,
      wobble: random() * Math.PI * 2,
      stunned: 0,
      finished: false,
    }));
  }

  function resizeCanvas() {
    width = Math.max(1, window.innerWidth);
    height = Math.max(1, window.innerHeight);
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function ordinal(number) {
    const mod100 = number % 100;
    if (mod100 >= 11 && mod100 <= 13) return `${number}<sup>th</sup>`;
    const suffix = number % 10 === 1 ? "st" : number % 10 === 2 ? "nd" : number % 10 === 3 ? "rd" : "th";
    return `${number}<sup>${suffix}</sup>`;
  }

  function formatTime(seconds) {
    if (!Number.isFinite(seconds)) return "—";
    const minutes = Math.floor(seconds / 60);
    const rest = seconds - minutes * 60;
    return `${minutes}:${rest.toFixed(2).padStart(5, "0")}`;
  }

  function announce(message, duration = 1150) {
    ui.announcer.textContent = message;
    ui.announcer.classList.remove("is-hidden");
    ui.status.textContent = message;
    announcerTimer = duration / 1000;
  }

  function setItem(item) {
    player.item = item;
    const data = item ? ITEMS[item] : null;
    ui.itemSlot.classList.toggle("is-empty", !item);
    ui.itemIcon.textContent = data ? data.icon : "?";
    ui.itemName.textContent = data ? data.name : "Item";
    ui.controlItemIcon.textContent = data ? data.icon : "?";
    if (data) ui.itemSlot.style.borderColor = data.color;
    else ui.itemSlot.style.removeProperty("border-color");
  }

  function updateHud() {
    const progress = Math.min(100, (player.distance / TOTAL_DISTANCE) * 100);
    ui.position.innerHTML = ordinal(player.rank);
    ui.lap.textContent = Math.min(TOTAL_LAPS, player.lap);
    ui.speed.textContent = Math.round(player.speed * 2.15);
    ui.progressFill.style.width = `${progress}%`;
    ui.progressPlayer.style.left = `${progress}%`;
    ui.boostFill.style.width = `${Math.min(100, player.driftCharge * 100)}%`;
    ui.boostLabel.textContent =
      player.boostTimer > 0 ? "Boosting" : player.driftCharge >= 0.7 ? "Charged" : player.driftCharge > 0.1 ? "Charging" : "Ready";
  }

  function resetRace() {
    player = createPlayer();
    buildTrack();
    particles = [];
    shake = 0;
    setItem(null);
    updateHud();
  }

  function showRaceUi(show) {
    ui.hud.classList.toggle("is-hidden", !show);
    ui.controls.classList.toggle("is-hidden", !show);
  }

  function startRace() {
    audio.unlock();
    resetRace();
    phase = "countdown";
    countdownTimer = 3.85;
    ui.menu.classList.add("is-hidden");
    ui.result.classList.add("is-hidden");
    ui.pauseScreen.classList.add("is-hidden");
    showRaceUi(true);
    ui.countdown.classList.remove("is-hidden");
    displayCountdown("3");
    audio.countdown(3);
    ui.status.textContent = `Race starting with ${RACERS[selectedRacer].name}`;
  }

  function displayCountdown(value) {
    ui.countdown.textContent = value;
    ui.countdown.classList.remove("is-popping");
    void ui.countdown.offsetWidth;
    ui.countdown.classList.add("is-popping");
  }

  function updateCountdown(dt) {
    const before = Math.ceil(countdownTimer);
    countdownTimer -= dt;
    const after = Math.ceil(countdownTimer);
    if (after !== before && after > 0 && after <= 3) {
      displayCountdown(String(after));
      audio.countdown(after);
    }
    if (countdownTimer <= 0.7 && countdownTimer + dt > 0.7) {
      displayCountdown("GO!");
      audio.countdown(0);
    }
    if (countdownTimer <= 0) {
      phase = "racing";
      ui.countdown.classList.add("is-hidden");
      announce("Own the aisle!");
    }
  }

  function pauseGame() {
    if (phase !== "racing" && phase !== "countdown") return;
    previousPhase = phase;
    phase = "paused";
    input.left = false;
    input.right = false;
    input.drift = false;
    ui.pauseScreen.classList.remove("is-hidden");
    showRaceUi(false);
    audio.setEngine(0, false);
  }

  function resumeGame() {
    if (phase !== "paused") return;
    audio.unlock();
    phase = previousPhase;
    ui.pauseScreen.classList.add("is-hidden");
    showRaceUi(true);
    lastFrame = performance.now();
  }

  function returnToMenu() {
    phase = "menu";
    showRaceUi(false);
    ui.pauseScreen.classList.add("is-hidden");
    ui.result.classList.add("is-hidden");
    ui.menu.classList.remove("is-hidden");
    ui.countdown.classList.add("is-hidden");
    ui.announcer.classList.add("is-hidden");
    audio.setEngine(0, false);
  }

  function releaseDrift() {
    if (!player || !player.wasDrifting) return;
    if (player.driftCharge >= 0.22) {
      player.boostTimer = Math.max(player.boostTimer, 0.65 + player.driftCharge * 1.9);
      announce(player.driftCharge > 0.72 ? "Mega drift!" : "Drift boost!");
      audio.boost();
      burstParticles(14, RACERS[selectedRacer].color);
    }
    player.driftCharge = 0;
    player.wasDrifting = false;
  }

  function useItem() {
    if (phase !== "racing" || !player.item) return;
    const item = player.item;
    setItem(null);
    if (item === "boost") {
      player.boostTimer = Math.max(player.boostTimer, 2.7);
      announce("Fizz boost!");
      audio.boost();
      burstParticles(18, ITEMS.boost.color);
    } else if (item === "shield") {
      player.shieldTimer = 7;
      announce("Bubble wrapped!");
      audio.pickup();
    } else {
      const target = opponents
        .filter((opponent) => opponent.distance > player.distance && opponent.distance - player.distance < 260)
        .sort((a, b) => a.distance - b.distance)[0];
      if (target) {
        target.stunned = 1.8;
        target.speed *= 0.55;
        announce(`${target.name} got snacked!`);
      } else {
        player.boostTimer = Math.max(player.boostTimer, 1.1);
        announce("Snack-fueled boost!");
      }
      audio.tone(260, 0.2, "triangle", 0.07, -100);
    }
  }

  function chooseRandomItem() {
    const roll = Math.random();
    if (player.rank >= 5) return roll < 0.65 ? "boost" : "shield";
    if (player.rank >= 3) return roll < 0.45 ? "boost" : roll < 0.74 ? "shield" : "snack";
    return roll < 0.28 ? "boost" : roll < 0.54 ? "shield" : "snack";
  }

  function updateOpponents(dt) {
    opponents.forEach((opponent, index) => {
      opponent.stunned = Math.max(0, opponent.stunned - dt);
      opponent.changeTimer -= dt;
      if (opponent.changeTimer <= 0) {
        opponent.targetX = -0.8 + Math.random() * 1.6;
        opponent.changeTimer = 1.4 + Math.random() * 2.6;
      }
      opponent.x += (opponent.targetX - opponent.x) * Math.min(1, dt * 0.85);

      const rubberBand = Math.max(-8, Math.min(8, (player.distance - opponent.distance) * 0.012));
      const lapEnergy = Math.sin(opponent.wobble + opponent.distance * 0.013) * 2.6;
      const targetSpeed = opponent.stunned > 0 ? 35 : opponent.maxSpeed + rubberBand + lapEnergy;
      opponent.speed += (targetSpeed - opponent.speed) * Math.min(1, dt * (opponent.stunned > 0 ? 5 : 0.65));
      if (!opponent.finished) opponent.distance += opponent.speed * dt;
      if (opponent.distance >= TOTAL_DISTANCE) {
        opponent.distance = TOTAL_DISTANCE + 1 + index * 0.01;
        opponent.finished = true;
      }
    });
  }

  function updatePlayer(dt) {
    const racer = RACERS[selectedRacer];
    player.previousDistance = player.distance;
    player.raceTime += dt;
    player.boostTimer = Math.max(0, player.boostTimer - dt);
    player.shieldTimer = Math.max(0, player.shieldTimer - dt);
    player.invulnerable = Math.max(0, player.invulnerable - dt);
    player.hitFlash = Math.max(0, player.hitFlash - dt);

    const steer = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    const speedRatio = Math.min(1, player.speed / racer.maxSpeed);
    const driftActive = input.drift && steer !== 0 && player.speed > 28;
    const steeringRate = racer.handling * (driftActive ? 1.38 : 0.94) * (0.62 + speedRatio * 0.54);
    player.x += steer * steeringRate * dt;
    player.x -= curveAt(player.distance) * player.speed * dt * 0.0017;
    player.x = Math.max(-1.18, Math.min(1.18, player.x));

    if (driftActive) {
      player.driftCharge = Math.min(1, player.driftCharge + dt * (0.28 + Math.abs(steer) * 0.17));
      player.wasDrifting = true;
      if (Math.random() < dt * 16) addDriftParticle();
    } else if (player.wasDrifting) {
      releaseDrift();
    }

    const offTrack = Math.abs(player.x) > 0.94;
    const boosted = player.boostTimer > 0;
    let targetSpeed = racer.maxSpeed + (boosted ? 34 : 0);
    if (offTrack) targetSpeed *= 0.58;
    const acceleration = racer.accel * (boosted ? 1.7 : 1);
    if (player.speed < targetSpeed) player.speed = Math.min(targetSpeed, player.speed + acceleration * dt);
    else player.speed = Math.max(targetSpeed, player.speed - 34 * dt);
    if (offTrack && Math.random() < dt * 20) addDustParticle();

    player.distance += player.speed * dt;
    checkObjects();

    const newLap = Math.min(TOTAL_LAPS, Math.floor(player.distance / LAP_LENGTH) + 1);
    if (newLap > player.lap) {
      player.lapTimes.push(player.raceTime - player.lapStarted);
      player.lapStarted = player.raceTime;
      player.lap = newLap;
      announce(newLap === TOTAL_LAPS ? "Final lap!" : `Lap ${newLap} — keep pushing!`, 1500);
      audio.tone(440, 0.15, "square", 0.06, 180);
    }

    player.rank = 1 + opponents.filter((opponent) => opponent.distance > player.distance).length;
    if (player.distance >= TOTAL_DISTANCE) finishRace();
  }

  function checkObjects() {
    const racer = RACERS[selectedRacer];
    objects.forEach((object) => {
      if (
        object.used ||
        object.distance < player.previousDistance - 2 ||
        object.distance > player.distance + Math.max(9, player.speed * 0.04)
      ) {
        return;
      }
      if (Math.abs(object.x - player.x) > (object.type === "spill" ? 0.31 : 0.24)) return;

      object.used = true;
      if (object.type === "pickup") {
        player.pickups += 1;
        if (!player.item) {
          const item = chooseRandomItem();
          setItem(item);
          announce(`${ITEMS[item].icon} ${ITEMS[item].name}`);
        } else {
          player.boostTimer = Math.max(player.boostTimer, 0.7);
          announce("Pickup converted to boost!");
        }
        audio.pickup();
        burstParticles(12, "#dfff34");
        return;
      }

      if (player.shieldTimer > 0) {
        player.shieldTimer = 0;
        player.invulnerable = 0.8;
        announce("Bubble wrap saved it!");
        audio.tone(610, 0.16, "sine", 0.06, -220);
        burstParticles(16, "#25e3ff");
        return;
      }

      if (player.invulnerable > 0) return;
      player.invulnerable = 1.1;
      player.hitFlash = 0.35;
      player.speed *= Math.max(0.38, 0.52 + (racer.armor - 1) * 0.18);
      player.x += object.x > player.x ? -0.16 : 0.16;
      shake = 16;
      announce(object.type === "spill" ? "Cleanup on aisle fast!" : "Cart crash!");
      audio.crash();
      burstParticles(11, object.type === "spill" ? "#65d8ff" : "#ffbd2e");
      if (navigator.vibrate) navigator.vibrate(45);
    });
  }

  function finishRace() {
    if (phase === "finished") return;
    player.distance = TOTAL_DISTANCE;
    player.lapTimes.push(player.raceTime - player.lapStarted);
    player.rank = 1 + opponents.filter((opponent) => opponent.distance >= TOTAL_DISTANCE).length;
    phase = "finished";
    showRaceUi(false);
    audio.setEngine(0, false);
    audio.finish();

    const won = player.rank === 1;
    ui.resultKicker.textContent = won ? "Night shift legend" : player.rank <= 3 ? "Podium cart" : "Still rolling";
    ui.resultPosition.innerHTML = ordinal(player.rank);
    ui.resultTitle.textContent = won ? "Aisle champion!" : player.rank <= 3 ? "Shelf-made podium!" : "Run it back!";
    ui.resultCopy.textContent = won
      ? "That cart just became store folklore."
      : player.rank <= 3
        ? "One clean drift away from the top spot."
        : "A few dents, zero regrets. The night is young.";
    ui.resultTime.textContent = formatTime(player.raceTime);
    ui.resultLap.textContent = formatTime(Math.min(...player.lapTimes));
    ui.resultPickups.textContent = String(player.pickups);
    window.setTimeout(() => ui.result.classList.remove("is-hidden"), 700);
  }

  function update(dt) {
    menuTime += dt;
    if (announcerTimer > 0) {
      announcerTimer -= dt;
      if (announcerTimer <= 0) ui.announcer.classList.add("is-hidden");
    }

    if (phase === "countdown") {
      updateCountdown(dt);
      updateOpponents(dt * 0.08);
    } else if (phase === "racing") {
      updatePlayer(dt);
      updateOpponents(dt);
      updateParticles(dt);
      updateHud();
    } else {
      updateParticles(dt);
    }
    shake = Math.max(0, shake - dt * 42);
    audio.setEngine(player ? player.speed : 0, phase === "racing");
  }

  function curveAt(distance) {
    return Math.sin(distance / 245) * 0.66 + Math.sin(distance / 710 + 1.1) * 0.32;
  }

  function horizonY() {
    return Math.max(118, height * 0.235);
  }

  function roadProjection(relative, x = 0) {
    const horizon = horizonY();
    const bottom = height * 0.94;
    const t = Math.max(0, Math.min(1, 1 - relative / VIEW_DISTANCE));
    const eased = t * t;
    const half = 20 + eased * width * 0.43;
    const currentCurve = curveAt((player ? player.distance : menuTime * 42) + relative);
    const baseCurve = curveAt(player ? player.distance : menuTime * 42);
    const driverX = player ? player.x : Math.sin(menuTime * 0.35) * 0.12;
    const center = width * 0.5 - driverX * width * 0.09 + (currentCurve - baseCurve) * width * 0.105 * t;
    return {
      x: center + x * half * 0.86,
      y: horizon + eased * (bottom - horizon),
      half,
      center,
      t,
      scale: 0.12 + eased * 0.98,
    };
  }

  function drawBackground() {
    const horizon = horizonY();
    const gradient = ctx.createLinearGradient(0, 0, 0, horizon);
    gradient.addColorStop(0, "#150c29");
    gradient.addColorStop(1, "#322047");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, horizon + 1);

    ctx.fillStyle = "#0c0716";
    ctx.fillRect(0, 0, width, Math.max(24, height * 0.055));

    drawCeilingLights(horizon);

    const floor = ctx.createLinearGradient(0, horizon, 0, height);
    floor.addColorStop(0, "#39333f");
    floor.addColorStop(0.55, "#29252e");
    floor.addColorStop(1, "#17131d");
    ctx.fillStyle = floor;
    ctx.fillRect(0, horizon, width, height - horizon);

    drawFloorBands();
    drawShelves();
    drawOverheadSigns();
  }

  function drawCeilingLights(horizon) {
    const offset = ((player ? player.distance : menuTime * 45) % 150) / 150;
    for (let index = 0; index < 6; index += 1) {
      const depth = (index + offset) / 6;
      const y = 10 + depth * depth * (horizon - 25);
      const lightWidth = 20 + depth * width * 0.28;
      const lightHeight = 2 + depth * 7;
      ctx.fillStyle = `rgba(238,255,220,${0.13 + depth * 0.35})`;
      ctx.shadowColor = "#dfffbc";
      ctx.shadowBlur = 5 + depth * 10;
      ctx.fillRect(width / 2 - lightWidth / 2, y, lightWidth, lightHeight);
      ctx.shadowBlur = 0;
    }
  }

  function drawFloorBands() {
    const distance = player ? player.distance : menuTime * 42;
    const spacing = 62;
    const first = Math.ceil(distance / spacing) * spacing;
    for (let world = first; world < distance + VIEW_DISTANCE; world += spacing) {
      const relative = world - distance;
      const near = roadProjection(relative, 0);
      const far = roadProjection(Math.min(VIEW_DISTANCE, relative + 5), 0);
      const alpha = 0.04 + near.t * 0.1;
      ctx.fillStyle = `rgba(255,255,255,${alpha})`;
      ctx.beginPath();
      ctx.moveTo(far.center - far.half, far.y);
      ctx.lineTo(far.center + far.half, far.y);
      ctx.lineTo(near.center + near.half, near.y);
      ctx.lineTo(near.center - near.half, near.y);
      ctx.closePath();
      ctx.fill();
    }

    [-0.5, 0.5].forEach((lane) => {
      ctx.strokeStyle = "rgba(223,255,52,0.12)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let relative = VIEW_DISTANCE; relative >= 0; relative -= 12) {
        const point = roadProjection(relative, lane);
        if (relative === VIEW_DISTANCE) ctx.moveTo(point.x, point.y);
        else ctx.lineTo(point.x, point.y);
      }
      ctx.stroke();
    });
  }

  function drawShelves() {
    const horizon = horizonY();
    const bottomLeft = roadProjection(0, 0);
    const far = roadProjection(VIEW_DISTANCE, 0);

    const leftGradient = ctx.createLinearGradient(0, horizon, bottomLeft.center - bottomLeft.half, height);
    leftGradient.addColorStop(0, "#2c1d3b");
    leftGradient.addColorStop(1, "#100a19");
    ctx.fillStyle = leftGradient;
    ctx.beginPath();
    ctx.moveTo(0, horizon * 0.65);
    ctx.lineTo(far.center - far.half, horizon);
    ctx.lineTo(bottomLeft.center - bottomLeft.half, height);
    ctx.lineTo(0, height);
    ctx.closePath();
    ctx.fill();

    const rightGradient = ctx.createLinearGradient(width, horizon, bottomLeft.center + bottomLeft.half, height);
    rightGradient.addColorStop(0, "#241b38");
    rightGradient.addColorStop(1, "#0e0917");
    ctx.fillStyle = rightGradient;
    ctx.beginPath();
    ctx.moveTo(width, horizon * 0.65);
    ctx.lineTo(far.center + far.half, horizon);
    ctx.lineTo(bottomLeft.center + bottomLeft.half, height);
    ctx.lineTo(width, height);
    ctx.closePath();
    ctx.fill();

    const distance = player ? player.distance : menuTime * 42;
    const spacing = 44;
    const first = Math.ceil(distance / spacing) * spacing;
    for (let world = first; world < distance + VIEW_DISTANCE; world += spacing) {
      const relative = world - distance;
      const point = roadProjection(relative, 0);
      drawShelfSlice(point, world);
    }

    ctx.strokeStyle = "rgba(255,255,255,0.19)";
    ctx.lineWidth = 2;
    [0.32, 0.54, 0.75].forEach((factor) => {
      const y = horizon + (height - horizon) * factor;
      ctx.beginPath();
      ctx.moveTo(0, y * 0.89);
      ctx.lineTo(bottomLeft.center - bottomLeft.half, y);
      ctx.moveTo(width, y * 0.89);
      ctx.lineTo(bottomLeft.center + bottomLeft.half, y);
      ctx.stroke();
    });
  }

  function drawShelfSlice(point, world) {
    if (point.t < 0.07) return;
    const rackHeight = 18 + point.t * height * 0.27;
    const thickness = 1 + point.t * 4;
    const leftEdge = point.center - point.half;
    const rightEdge = point.center + point.half;
    ctx.strokeStyle = `rgba(178,156,196,${0.18 + point.t * 0.35})`;
    ctx.lineWidth = thickness;
    ctx.beginPath();
    ctx.moveTo(leftEdge, point.y);
    ctx.lineTo(leftEdge - point.t * width * 0.22, point.y - rackHeight);
    ctx.moveTo(rightEdge, point.y);
    ctx.lineTo(rightEdge + point.t * width * 0.22, point.y - rackHeight);
    ctx.stroke();

    if (point.t < 0.28) return;
    const blockSize = 3 + point.t * 10;
    const paletteIndex = Math.floor(world / 44) % COLORS.length;
    ctx.fillStyle = COLORS[paletteIndex];
    ctx.globalAlpha = 0.28 + point.t * 0.5;
    for (let shelf = 0; shelf < 3; shelf += 1) {
      const y = point.y - rackHeight * (0.24 + shelf * 0.25);
      ctx.fillRect(leftEdge - blockSize * (2.3 + shelf * 0.25), y, blockSize * 1.7, blockSize * 0.9);
      ctx.fillRect(rightEdge + blockSize * (0.6 + shelf * 0.15), y, blockSize * 1.7, blockSize * 0.9);
    }
    ctx.globalAlpha = 1;
  }

  function drawOverheadSigns() {
    const distance = player ? player.distance : menuTime * 42;
    const signSpacing = 360;
    const first = Math.ceil(distance / signSpacing) * signSpacing;
    for (let world = first; world < distance + VIEW_DISTANCE; world += signSpacing) {
      const point = roadProjection(world - distance, 0);
      if (point.t < 0.18) continue;
      const signWidth = 25 + point.t * 92;
      const signHeight = 13 + point.t * 28;
      const y = point.y - 54 - point.t * 120;
      ctx.fillStyle = "#dfff34";
      ctx.fillRect(point.center - signWidth / 2, y, signWidth, signHeight);
      ctx.fillStyle = "#171022";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.font = `900 ${Math.max(8, point.t * 24)}px Arial`;
      ctx.fillText(`AISLE ${1 + (Math.floor(world / signSpacing) % 12)}`, point.center, y + signHeight / 2);
    }
  }

  function drawRaceObjects() {
    if (!player) return;
    const visible = objects
      .filter((object) => !object.used && object.distance >= player.distance && object.distance < player.distance + VIEW_DISTANCE)
      .sort((a, b) => b.distance - a.distance);
    visible.forEach((object) => {
      const point = roadProjection(object.distance - player.distance, object.x);
      drawObject(object, point);
    });
  }

  function drawObject(object, point) {
    const scale = point.scale;
    ctx.save();
    ctx.translate(point.x, point.y);
    if (object.type === "pickup") {
      const bob = Math.sin(menuTime * 5 + object.spin) * 4 * scale;
      ctx.translate(0, -10 * scale + bob);
      ctx.rotate(menuTime * 1.8 + object.spin);
      ctx.shadowColor = "#dfff34";
      ctx.shadowBlur = 14 * scale;
      ctx.fillStyle = "#dfff34";
      ctx.beginPath();
      for (let side = 0; side < 8; side += 1) {
        const angle = (Math.PI * 2 * side) / 8;
        const radius = (side % 2 ? 10 : 15) * scale;
        const x = Math.cos(angle) * radius;
        const y = Math.sin(angle) * radius;
        if (side === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.fillStyle = "#160d25";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.font = `900 ${Math.max(7, 15 * scale)}px Arial`;
      ctx.fillText("?", 0, 0);
    } else if (object.type === "spill") {
      ctx.fillStyle = "rgba(58,204,255,0.62)";
      ctx.beginPath();
      ctx.ellipse(0, 0, 26 * scale, 8 * scale, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.48)";
      ctx.beginPath();
      ctx.ellipse(-5 * scale, -1 * scale, 9 * scale, 2 * scale, 0, 0, Math.PI * 2);
      ctx.fill();
    } else if (object.type === "cone") {
      ctx.fillStyle = "#ff7138";
      ctx.beginPath();
      ctx.moveTo(0, -28 * scale);
      ctx.lineTo(15 * scale, 0);
      ctx.lineTo(-15 * scale, 0);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#f9e5c2";
      ctx.fillRect(-10 * scale, -12 * scale, 20 * scale, 5 * scale);
      ctx.fillStyle = "#a94222";
      ctx.fillRect(-18 * scale, -3 * scale, 36 * scale, 5 * scale);
    } else {
      ctx.fillStyle = "#a96b35";
      ctx.fillRect(-18 * scale, -25 * scale, 36 * scale, 25 * scale);
      ctx.strokeStyle = "#e1a25e";
      ctx.lineWidth = Math.max(1, 2 * scale);
      ctx.strokeRect(-18 * scale, -25 * scale, 36 * scale, 25 * scale);
      ctx.beginPath();
      ctx.moveTo(-18 * scale, -25 * scale);
      ctx.lineTo(18 * scale, 0);
      ctx.moveTo(18 * scale, -25 * scale);
      ctx.lineTo(-18 * scale, 0);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawOpponents() {
    if (!player) return;
    opponents
      .filter((opponent) => opponent.distance > player.distance + 2 && opponent.distance < player.distance + VIEW_DISTANCE)
      .sort((a, b) => b.distance - a.distance)
      .forEach((opponent) => {
        const point = roadProjection(opponent.distance - player.distance, opponent.x);
        drawCart(point.x, point.y, 42 * point.scale, opponent.color, opponent.accent, 0, false, opponent.stunned > 0);
        if (point.scale > 0.44) {
          ctx.fillStyle = "rgba(14,7,24,0.72)";
          const labelWidth = ctx.measureText(opponent.name).width + 12;
          ctx.fillRect(point.x - labelWidth / 2, point.y - 58 * point.scale, labelWidth, 12);
          ctx.fillStyle = "#f8f2dc";
          ctx.font = "700 8px Arial";
          ctx.textAlign = "center";
          ctx.fillText(opponent.name.toUpperCase(), point.x, point.y - 49 * point.scale);
        }
      });
  }

  function drawPlayer() {
    if (!player || phase === "menu") return;
    const racer = RACERS[selectedRacer];
    const point = roadProjection(0, player.x);
    const size = Math.min(width * 0.19, height * 0.125, 92);
    const lean = ((input.right ? 1 : 0) - (input.left ? 1 : 0)) * (input.drift ? 0.22 : 0.11);
    const bounce = Math.sin(menuTime * (8 + player.speed * 0.07)) * Math.min(2.5, player.speed * 0.018);

    if (player.boostTimer > 0) drawSpeedLines();
    if (player.shieldTimer > 0) {
      ctx.strokeStyle = `rgba(37,227,255,${0.5 + Math.sin(menuTime * 8) * 0.2})`;
      ctx.lineWidth = 3;
      ctx.shadowColor = "#25e3ff";
      ctx.shadowBlur = 15;
      ctx.beginPath();
      ctx.ellipse(point.x, point.y - size * 0.45, size * 0.88, size * 0.7, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    ctx.globalAlpha = player.invulnerable > 0 && Math.floor(player.invulnerable * 12) % 2 ? 0.45 : 1;
    drawCart(point.x, point.y + bounce, size, racer.color, racer.accent, lean, true, false);
    ctx.globalAlpha = 1;
  }

  function drawCart(x, y, size, color, accent, lean, isPlayer, stunned) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(lean);
    const unit = size / 70;

    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.beginPath();
    ctx.ellipse(0, 3 * unit, 34 * unit, 9 * unit, 0, 0, Math.PI * 2);
    ctx.fill();

    if (isPlayer && player.boostTimer > 0) {
      const flame = 18 + Math.random() * 14;
      ctx.fillStyle = "#dfff34";
      ctx.beginPath();
      ctx.moveTo(-17 * unit, -2 * unit);
      ctx.lineTo(-9 * unit, flame * unit);
      ctx.lineTo(-2 * unit, -1 * unit);
      ctx.fill();
      ctx.fillStyle = "#25e3ff";
      ctx.beginPath();
      ctx.moveTo(3 * unit, -2 * unit);
      ctx.lineTo(12 * unit, flame * unit);
      ctx.lineTo(19 * unit, -1 * unit);
      ctx.fill();
    }

    ctx.fillStyle = "#17131e";
    ctx.beginPath();
    ctx.ellipse(-22 * unit, 0, 7 * unit, 9 * unit, 0, 0, Math.PI * 2);
    ctx.ellipse(22 * unit, 0, 7 * unit, 9 * unit, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#d7d3d8";
    ctx.beginPath();
    ctx.arc(-22 * unit, 0, 2.6 * unit, 0, Math.PI * 2);
    ctx.arc(22 * unit, 0, 2.6 * unit, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = color;
    ctx.strokeStyle = accent;
    ctx.lineWidth = Math.max(1.2, 2.2 * unit);
    ctx.beginPath();
    ctx.moveTo(-31 * unit, -42 * unit);
    ctx.lineTo(31 * unit, -42 * unit);
    ctx.lineTo(25 * unit, -5 * unit);
    ctx.lineTo(-25 * unit, -5 * unit);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.globalAlpha *= 0.72;
    ctx.strokeStyle = accent;
    ctx.lineWidth = Math.max(0.8, 1.3 * unit);
    for (let line = -20; line <= 20; line += 10) {
      ctx.beginPath();
      ctx.moveTo(line * unit, -40 * unit);
      ctx.lineTo(line * 0.8 * unit, -7 * unit);
      ctx.stroke();
    }
    [-30, -18].forEach((line) => {
      ctx.beginPath();
      ctx.moveTo(-28 * unit, line * unit);
      ctx.lineTo(28 * unit, line * unit);
      ctx.stroke();
    });
    ctx.globalAlpha /= 0.72;

    ctx.strokeStyle = "#d7d3d8";
    ctx.lineWidth = 4 * unit;
    ctx.beginPath();
    ctx.moveTo(27 * unit, -38 * unit);
    ctx.lineTo(36 * unit, -56 * unit);
    ctx.lineTo(19 * unit, -56 * unit);
    ctx.stroke();
    ctx.strokeStyle = color;
    ctx.lineWidth = 5 * unit;
    ctx.beginPath();
    ctx.moveTo(17 * unit, -56 * unit);
    ctx.lineTo(36 * unit, -56 * unit);
    ctx.stroke();

    ctx.fillStyle = stunned ? "#ffbd2e" : "#2b2038";
    ctx.beginPath();
    ctx.arc(0, -48 * unit, 12 * unit, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = accent;
    ctx.fillRect(-12 * unit, -52 * unit, 24 * unit, 7 * unit);
    ctx.fillStyle = "#171020";
    ctx.beginPath();
    ctx.moveTo(-15 * unit, -47 * unit);
    ctx.lineTo(15 * unit, -47 * unit);
    ctx.lineTo(10 * unit, -35 * unit);
    ctx.lineTo(-10 * unit, -35 * unit);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "#bc8e72";
    ctx.lineWidth = 4 * unit;
    ctx.beginPath();
    ctx.moveTo(-9 * unit, -38 * unit);
    ctx.lineTo(-22 * unit, -53 * unit);
    ctx.moveTo(9 * unit, -38 * unit);
    ctx.lineTo(22 * unit, -53 * unit);
    ctx.stroke();
    ctx.restore();
  }

  function drawSpeedLines() {
    ctx.strokeStyle = "rgba(223,255,52,0.4)";
    ctx.lineWidth = 2;
    for (let index = 0; index < 12; index += 1) {
      const x = ((index * 97 + menuTime * 800) % (width + 100)) - 50;
      const y = height * 0.3 + ((index * 137) % Math.max(100, height * 0.62));
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + (x - width / 2) * 0.09, y + 28);
      ctx.stroke();
    }
  }

  function addDriftParticle() {
    if (!player) return;
    const point = roadProjection(0, player.x);
    particles.push({
      x: point.x + (Math.random() - 0.5) * 50,
      y: point.y + Math.random() * 8,
      vx: (Math.random() - 0.5) * 48,
      vy: -20 - Math.random() * 34,
      life: 0.45 + Math.random() * 0.3,
      maxLife: 0.75,
      color: player.driftCharge > 0.7 ? "#dfff34" : player.driftCharge > 0.35 ? "#ffbd2e" : "#25e3ff",
      size: 2 + Math.random() * 3,
    });
  }

  function addDustParticle() {
    if (!player) return;
    const point = roadProjection(0, player.x);
    particles.push({
      x: point.x + (Math.random() - 0.5) * 40,
      y: point.y,
      vx: (Math.random() - 0.5) * 32,
      vy: -10 - Math.random() * 22,
      life: 0.45,
      maxLife: 0.45,
      color: "#b59d85",
      size: 4 + Math.random() * 6,
    });
  }

  function burstParticles(count, color) {
    if (!player) return;
    const point = roadProjection(0, player.x);
    for (let index = 0; index < count; index += 1) {
      particles.push({
        x: point.x + (Math.random() - 0.5) * 35,
        y: point.y - 25 + (Math.random() - 0.5) * 25,
        vx: (Math.random() - 0.5) * 150,
        vy: -25 - Math.random() * 100,
        life: 0.5 + Math.random() * 0.5,
        maxLife: 1,
        color,
        size: 2 + Math.random() * 5,
      });
    }
  }

  function updateParticles(dt) {
    particles.forEach((particle) => {
      particle.life -= dt;
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vy += 95 * dt;
      particle.vx *= 0.98;
    });
    particles = particles.filter((particle) => particle.life > 0);
  }

  function drawParticles() {
    particles.forEach((particle) => {
      ctx.globalAlpha = Math.max(0, particle.life / particle.maxLife);
      ctx.fillStyle = particle.color;
      ctx.fillRect(particle.x, particle.y, particle.size, particle.size);
    });
    ctx.globalAlpha = 1;
  }

  function draw() {
    ctx.save();
    if (shake > 0) ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);
    drawBackground();
    drawRaceObjects();
    drawOpponents();
    drawParticles();
    drawPlayer();
    if (player && player.hitFlash > 0) {
      ctx.fillStyle = `rgba(255,75,62,${player.hitFlash * 0.5})`;
      ctx.fillRect(0, 0, width, height);
    }
    ctx.restore();
  }

  function frame(now) {
    const dt = Math.min(0.034, Math.max(0, (now - lastFrame) / 1000));
    lastFrame = now;
    if (phase !== "paused") update(dt);
    draw();
    requestAnimationFrame(frame);
  }

  function bindHoldControl(button, key) {
    const activate = (event) => {
      event.preventDefault();
      if (button.setPointerCapture && event.pointerId !== undefined) button.setPointerCapture(event.pointerId);
      input[key] = true;
      button.classList.add("is-active");
    };
    const release = (event) => {
      if (event) event.preventDefault();
      input[key] = false;
      button.classList.remove("is-active");
      if (key === "drift") releaseDrift();
    };
    button.addEventListener("pointerdown", activate);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("lostpointercapture", release);
  }

  document.querySelectorAll("[data-control]").forEach((button) => {
    const control = button.dataset.control;
    if (control === "item") {
      button.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        button.classList.add("is-active");
        useItem();
      });
      button.addEventListener("pointerup", () => button.classList.remove("is-active"));
      button.addEventListener("pointercancel", () => button.classList.remove("is-active"));
    } else {
      bindHoldControl(button, control);
    }
  });

  document.querySelectorAll(".racer-card").forEach((card) => {
    card.addEventListener("click", () => {
      selectedRacer = Number(card.dataset.racer);
      document.querySelectorAll(".racer-card").forEach((other, index) => {
        const active = index === selectedRacer;
        other.classList.toggle("is-selected", active);
        other.setAttribute("aria-pressed", String(active));
      });
      ui.racerCount.textContent = `0${selectedRacer + 1} / 03`;
      audio.unlock();
      audio.tone(220 + selectedRacer * 80, 0.08, "square", 0.04, 40);
    });
  });

  canvas.addEventListener("pointerdown", (event) => {
    if (phase !== "racing") return;
    swipePointer = event.pointerId;
    swipeStart = event.clientX;
    canvas.setPointerCapture(event.pointerId);
  });

  canvas.addEventListener("pointermove", (event) => {
    if (event.pointerId !== swipePointer || phase !== "racing") return;
    const distance = event.clientX - swipeStart;
    input.left = distance < -12;
    input.right = distance > 12;
    input.drift = Math.abs(distance) > Math.min(75, width * 0.15);
  });

  const endSwipe = (event) => {
    if (event.pointerId !== swipePointer) return;
    input.left = false;
    input.right = false;
    input.drift = false;
    releaseDrift();
    swipePointer = null;
  };
  canvas.addEventListener("pointerup", endSwipe);
  canvas.addEventListener("pointercancel", endSwipe);

  window.addEventListener("keydown", (event) => {
    if (["ArrowLeft", "ArrowRight", "Space"].includes(event.code)) event.preventDefault();
    if (event.code === "ArrowLeft" || event.code === "KeyA") input.left = true;
    if (event.code === "ArrowRight" || event.code === "KeyD") input.right = true;
    if (event.code === "Space" || event.code === "ShiftLeft" || event.code === "ShiftRight") input.drift = true;
    if ((event.code === "KeyX" || event.code === "KeyE") && !event.repeat) useItem();
    if ((event.code === "Escape" || event.code === "KeyP") && !event.repeat) {
      if (phase === "paused") resumeGame();
      else pauseGame();
    }
  });

  window.addEventListener("keyup", (event) => {
    if (event.code === "ArrowLeft" || event.code === "KeyA") input.left = false;
    if (event.code === "ArrowRight" || event.code === "KeyD") input.right = false;
    if (event.code === "Space" || event.code === "ShiftLeft" || event.code === "ShiftRight") {
      input.drift = false;
      releaseDrift();
    }
  });

  ui.start.addEventListener("click", startRace);
  ui.pause.addEventListener("click", pauseGame);
  ui.resume.addEventListener("click", resumeGame);
  ui.restart.addEventListener("click", startRace);
  ui.raceAgain.addEventListener("click", startRace);
  ui.changeCart.addEventListener("click", returnToMenu);
  ui.sound.addEventListener("click", () => {
    const muted = audio.toggle();
    ui.sound.setAttribute("aria-label", muted ? "Turn sound on" : "Turn sound off");
  });

  window.addEventListener("resize", resizeCanvas);
  window.addEventListener("orientationchange", resizeCanvas);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && (phase === "racing" || phase === "countdown")) pauseGame();
  });
  document.addEventListener("contextmenu", (event) => event.preventDefault());

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("./sw.js").catch(() => {}));
  }

  resizeCanvas();
  resetRace();
  requestAnimationFrame(frame);
})();
