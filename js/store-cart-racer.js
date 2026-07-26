(function () {
  const canvas = document.getElementById("game-canvas");
  if (!canvas) {
    return;
  }

  const ctx = canvas.getContext("2d");
  const lapReadout = document.getElementById("lap-readout");
  const placeReadout = document.getElementById("place-readout");
  const speedReadout = document.getElementById("speed-readout");
  const itemReadout = document.getElementById("item-readout");
  const boostReadout = document.getElementById("boost-readout");
  const countdownReadout = document.getElementById("countdown-readout");
  const statusReadout = document.getElementById("race-status");
  const leaderboardList = document.getElementById("leaderboard-list");
  const restartButton = document.getElementById("restart-race");
  const touchButtons = Array.from(document.querySelectorAll("[data-control]"));

  const world = {
    width: canvas.width,
    height: canvas.height,
    trackWidth: 118,
    maxLaps: 3,
    startProgress: 210,
  };

  const trackPoints = [
    { x: 175, y: 122 },
    { x: 332, y: 95 },
    { x: 548, y: 95 },
    { x: 790, y: 135 },
    { x: 885, y: 255 },
    { x: 855, y: 408 },
    { x: 735, y: 518 },
    { x: 518, y: 550 },
    { x: 260, y: 530 },
    { x: 138, y: 452 },
    { x: 106, y: 320 },
    { x: 130, y: 205 },
  ];

  const shelves = [
    { x: 240, y: 142, w: 228, h: 46, tint: "#8b4f22", goods: "#7cd86d", label: "Produce" },
    { x: 540, y: 145, w: 206, h: 42, tint: "#93552d", goods: "#ff8f70", label: "Snacks" },
    { x: 215, y: 255, w: 126, h: 38, tint: "#936840", goods: "#4dd8ff", label: "Drinks" },
    { x: 415, y: 245, w: 176, h: 38, tint: "#8a5b34", goods: "#ffcb57", label: "Pantry" },
    { x: 650, y: 255, w: 126, h: 38, tint: "#936840", goods: "#a9ff84", label: "Deli" },
    { x: 205, y: 360, w: 134, h: 38, tint: "#7f532c", goods: "#d8f3ff", label: "Frozen" },
    { x: 405, y: 360, w: 196, h: 40, tint: "#8f5f38", goods: "#d5a8ff", label: "Aisle 9" },
    { x: 650, y: 370, w: 150, h: 38, tint: "#845229", goods: "#ff9f1c", label: "Bakery" },
    { x: 700, y: 485, w: 196, h: 52, tint: "#27364e", goods: "#cde7ff", label: "Checkout" },
  ];

  const inputs = {
    left: false,
    right: false,
    accel: false,
    brake: false,
  };

  let useQueued = false;
  let raceState = null;
  let lastFrame = performance.now();

  const trackSegments = buildTrack(trackPoints);
  const totalLength = trackSegments.totalLength;
  const pickupPads = [
    { progress: totalLength * 0.08, lane: -24, cooldown: 0 },
    { progress: totalLength * 0.22, lane: 30, cooldown: 0 },
    { progress: totalLength * 0.37, lane: -10, cooldown: 0 },
    { progress: totalLength * 0.51, lane: 28, cooldown: 0 },
    { progress: totalLength * 0.68, lane: -26, cooldown: 0 },
    { progress: totalLength * 0.84, lane: 18, cooldown: 0 },
  ];

  resetRace();
  bindControls();
  requestAnimationFrame(loop);

  function resetRace() {
    const roster = [
      createRacer("You", "#ffb703", "#ffe699", true, 0, -16, 282, 235),
      createRacer("Mara", "#ff5b7a", "#ffc4d2", false, 1, 18, 270, 220),
      createRacer("Brick", "#56ccf2", "#c5f3ff", false, 2, -4, 266, 216),
      createRacer("Nori", "#9eff6c", "#ddffc6", false, 3, 14, 262, 214),
      createRacer("Hex", "#c3a6ff", "#efe2ff", false, 4, -28, 259, 212),
    ];

    raceState = {
      phase: "countdown",
      countdown: 3.4,
      racers: roster,
      hazards: [],
      message: "Grid up: waiting for the green light.",
      messageTimer: 0,
      playerFinishPlace: null,
      startTime: null,
      finishTime: null,
    };

    pickupPads.forEach(function (pickup) {
      pickup.cooldown = 0;
    });

    updateHud();
  }

  function createRacer(name, color, accent, isPlayer, slot, lane, maxSpeed, accel) {
    return {
      name: name,
      color: color,
      accent: accent,
      isPlayer: isPlayer,
      progress: world.startProgress - slot * 30,
      lane: lane,
      speed: 0,
      baseMaxSpeed: maxSpeed,
      accel: accel,
      lap: 0,
      item: null,
      boostTimer: 0,
      shieldTimer: 0,
      aiTimer: 0.25 + slot * 0.11,
      targetLane: lane,
      finished: false,
      finishPlace: null,
    };
  }

  function buildTrack(points) {
    const segments = [];
    let total = 0;

    for (let index = 0; index < points.length; index += 1) {
      const nextIndex = (index + 1) % points.length;
      const length = distance(points[index], points[nextIndex]);
      segments.push({
        start: points[index],
        end: points[nextIndex],
        length: length,
        cumulative: total,
      });
      total += length;
    }

    return {
      segments: segments,
      totalLength: total,
      points: points,
    };
  }

  function bindControls() {
    const keyMap = {
      ArrowLeft: "left",
      KeyA: "left",
      ArrowRight: "right",
      KeyD: "right",
      ArrowUp: "accel",
      KeyW: "accel",
      ArrowDown: "brake",
      KeyS: "brake",
    };

    document.addEventListener("keydown", function (event) {
      if (keyMap[event.code]) {
        inputs[keyMap[event.code]] = true;
        event.preventDefault();
        return;
      }

      if (event.code === "Space" || event.code === "Enter") {
        useQueued = true;
        event.preventDefault();
      }
    });

    document.addEventListener("keyup", function (event) {
      if (keyMap[event.code]) {
        inputs[keyMap[event.code]] = false;
        event.preventDefault();
      }
    });

    touchButtons.forEach(function (button) {
      const control = button.getAttribute("data-control");

      if (control === "use") {
        button.addEventListener("click", function () {
          useQueued = true;
        });
        return;
      }

      const setPressed = function (pressed) {
        inputs[control] = pressed;
        button.classList.toggle("is-active", pressed);
      };

      button.addEventListener("pointerdown", function (event) {
        setPressed(true);
        event.preventDefault();
      });

      ["pointerup", "pointercancel", "pointerleave"].forEach(function (eventName) {
        button.addEventListener(eventName, function () {
          setPressed(false);
        });
      });
    });

    restartButton.addEventListener("click", function () {
      resetRace();
    });
  }

  function loop(timestamp) {
    const dt = Math.min(0.035, (timestamp - lastFrame) / 1000);
    lastFrame = timestamp;

    update(dt);
    render(timestamp);

    requestAnimationFrame(loop);
  }

  function update(dt) {
    if (raceState.phase === "countdown") {
      raceState.countdown = Math.max(0, raceState.countdown - dt);
      if (raceState.countdown === 0) {
        raceState.phase = "running";
        raceState.startTime = performance.now();
        announce("Green light. Floor it.");
      }
    }

    if (raceState.messageTimer > 0) {
      raceState.messageTimer = Math.max(0, raceState.messageTimer - dt);
    }

    updatePickups(dt);
    updateHazards(dt);

    if (raceState.phase === "finished") {
      updateHud();
      return;
    }

    raceState.racers.forEach(function (racer) {
      if (racer.finished) {
        return;
      }

      updateTimers(racer, dt);

      if (racer.isPlayer) {
        updatePlayer(racer, dt);
      } else {
        updateAi(racer, dt);
      }

      moveRacer(racer, dt);
      checkPickups(racer);
      checkHazards(racer);
    });

    const standings = getStandings();
    standings.forEach(function (racer, index) {
      if (!racer.finished && racer.lap >= world.maxLaps) {
        racer.finished = true;
        racer.finishPlace = index + 1;
        if (racer.isPlayer) {
          raceState.phase = "finished";
          raceState.playerFinishPlace = racer.finishPlace;
          raceState.finishTime = performance.now();
          announce("Race over. " + ordinal(racer.finishPlace) + " place.");
        } else if (index === 0) {
          announce(racer.name + " just took the lead and crossed the line.");
        }
      }
    });

    updateHud();
  }

  function updatePickups(dt) {
    pickupPads.forEach(function (pickup) {
      if (pickup.cooldown > 0) {
        pickup.cooldown = Math.max(0, pickup.cooldown - dt);
      }
    });
  }

  function updateHazards(dt) {
    for (let index = raceState.hazards.length - 1; index >= 0; index -= 1) {
      raceState.hazards[index].ttl -= dt;
      if (raceState.hazards[index].ttl <= 0) {
        raceState.hazards.splice(index, 1);
      }
    }
  }

  function updateTimers(racer, dt) {
    if (racer.boostTimer > 0) {
      racer.boostTimer = Math.max(0, racer.boostTimer - dt);
    }

    if (racer.shieldTimer > 0) {
      racer.shieldTimer = Math.max(0, racer.shieldTimer - dt);
    }
  }

  function updatePlayer(racer, dt) {
    if (raceState.phase !== "running") {
      racer.speed = Math.max(0, racer.speed - 160 * dt);
      return;
    }

    const steer = (inputs.right ? 1 : 0) - (inputs.left ? 1 : 0);
    const drag = 96;
    const brakePower = inputs.brake ? 250 : 0;
    const trackPressure = curvatureAt(racer.progress) * (55 + racer.speed * 0.08);
    const boostTopSpeed = racer.boostTimer > 0 ? 102 : 0;
    const topSpeed = racer.baseMaxSpeed + boostTopSpeed;

    if (inputs.accel) {
      racer.speed += racer.accel * dt;
    }

    racer.speed -= (drag + brakePower + trackPressure) * dt;
    racer.speed = clamp(racer.speed, 0, topSpeed);

    if (steer !== 0) {
      const laneShift = (78 + racer.speed * 0.08) * dt;
      racer.lane += laneShift * steer;
    } else {
      racer.lane *= 1 - 1.65 * dt;
    }

    racer.lane = clamp(racer.lane, -world.trackWidth * 0.39, world.trackWidth * 0.39);

    if (useQueued) {
      useItem(racer);
      useQueued = false;
    }
  }

  function updateAi(racer, dt) {
    if (raceState.phase !== "running") {
      racer.speed = Math.max(0, racer.speed - 130 * dt);
      return;
    }

    racer.aiTimer -= dt;
    if (racer.aiTimer <= 0) {
      racer.aiTimer = 0.45 + Math.random() * 0.65;

      const desiredLane = pickAiLane(racer);
      racer.targetLane = desiredLane;

      if (racer.item === "boost" && Math.random() < 0.42) {
        useItem(racer);
      } else if (racer.item === "spill" && Math.random() < 0.25) {
        useItem(racer);
      } else if (racer.item === "shield" && Math.random() < 0.18 && racer.shieldTimer === 0) {
        useItem(racer);
      }
    }

    const boostTopSpeed = racer.boostTimer > 0 ? 88 : 0;
    const targetSpeed = racer.baseMaxSpeed + boostTopSpeed - curvatureAt(racer.progress) * 82;

    racer.speed += (targetSpeed - racer.speed) * dt * 1.3;
    racer.speed = clamp(racer.speed, 0, racer.baseMaxSpeed + 100);

    racer.lane += (racer.targetLane - racer.lane) * dt * 2.1;
    racer.lane = clamp(racer.lane, -world.trackWidth * 0.37, world.trackWidth * 0.37);
  }

  function pickAiLane(racer) {
    const hazard = getNearestHazard(racer.progress);
    if (hazard && hazard.distanceAhead < 95 && Math.abs(hazard.lane - racer.lane) < 28) {
      return hazard.lane > 0 ? -32 : 32;
    }

    if (!racer.item) {
      const pickup = pickupPads
        .filter(function (pad) {
          return pad.cooldown === 0;
        })
        .map(function (pad) {
          return {
            lane: pad.lane,
            distanceAhead: aheadDistance(racer.progress, pad.progress),
          };
        })
        .sort(function (left, right) {
          return left.distanceAhead - right.distanceAhead;
        })[0];

      if (pickup && pickup.distanceAhead < 165) {
        return pickup.lane;
      }
    }

    return clamp((Math.random() - 0.5) * world.trackWidth * 0.7, -40, 40);
  }

  function moveRacer(racer, dt) {
    racer.progress += racer.speed * dt;

    while (racer.progress >= totalLength) {
      racer.progress -= totalLength;
      racer.lap += 1;
      if (racer.lap < world.maxLaps) {
        announce(racer.isPlayer ? "Lap " + (racer.lap + 1) + ". Keep pushing." : racer.name + " starts lap " + (racer.lap + 1) + ".");
      }
    }
  }

  function checkPickups(racer) {
    pickupPads.forEach(function (pickup) {
      if (pickup.cooldown > 0 || racer.item) {
        return;
      }

      const onPad = circularDistance(racer.progress, pickup.progress) < 20 && Math.abs(racer.lane - pickup.lane) < 18;
      if (!onPad) {
        return;
      }

      pickup.cooldown = 5 + Math.random() * 2.5;
      racer.item = rollItem();
      if (racer.isPlayer) {
        announce("Picked up " + labelForItem(racer.item) + ".");
      }
    });
  }

  function checkHazards(racer) {
    for (let index = raceState.hazards.length - 1; index >= 0; index -= 1) {
      const hazard = raceState.hazards[index];
      if (hazard.owner === racer.name) {
        continue;
      }

      const hitHazard = circularDistance(racer.progress, hazard.progress) < 18 && Math.abs(racer.lane - hazard.lane) < 16;
      if (!hitHazard) {
        continue;
      }

      if (racer.shieldTimer > 0) {
        racer.shieldTimer = 0;
        if (racer.isPlayer) {
          announce("Shield burned up on impact.");
        }
      } else {
        racer.speed *= 0.53;
        racer.lane += hazard.lane > 0 ? -10 : 10;
        if (racer.isPlayer) {
          announce("You slipped on a soda spill.");
        }
      }

      raceState.hazards.splice(index, 1);
    }
  }

  function useItem(racer) {
    if (!racer.item || raceState.phase !== "running") {
      return;
    }

    if (racer.item === "boost") {
      racer.boostTimer = 1.45;
      racer.speed = Math.min(racer.speed + 74, racer.baseMaxSpeed + 90);
      if (racer.isPlayer) {
        announce("Turbo coffee engaged.");
      }
    } else if (racer.item === "shield") {
      racer.shieldTimer = 4.25;
      if (racer.isPlayer) {
        announce("Soup lid shield up.");
      }
    } else if (racer.item === "spill") {
      raceState.hazards.push({
        progress: wrapDistance(racer.progress - 28),
        lane: racer.lane,
        ttl: 10,
        owner: racer.name,
      });
      if (racer.isPlayer) {
        announce("Dropped a soda spill.");
      }
    }

    racer.item = null;
  }

  function rollItem() {
    const roll = Math.random();
    if (roll < 0.4) {
      return "boost";
    }
    if (roll < 0.72) {
      return "shield";
    }
    return "spill";
  }

  function getStandings() {
    return raceState.racers
      .slice()
      .sort(function (left, right) {
        const distanceDelta = progressScore(right) - progressScore(left);
        if (distanceDelta !== 0) {
          return distanceDelta;
        }
        return right.speed - left.speed;
      });
  }

  function progressScore(racer) {
    return racer.lap * totalLength + racer.progress;
  }

  function updateHud() {
    const player = raceState.racers[0];
    const standings = getStandings();
    const place = standings.findIndex(function (racer) {
      return racer.isPlayer;
    }) + 1;

    lapReadout.textContent = Math.min(world.maxLaps, player.lap + 1) + " / " + world.maxLaps;
    placeReadout.textContent = ordinal(place);
    speedReadout.textContent = Math.round(player.speed * 0.52) + " mph";
    itemReadout.textContent = labelForItem(player.item);
    boostReadout.textContent = player.boostTimer > 0 ? player.boostTimer.toFixed(1) + "s" : player.shieldTimer > 0 ? "Shield" : "Cold";

    if (raceState.phase === "countdown") {
      countdownReadout.textContent = raceState.countdown > 0.2 ? String(Math.ceil(raceState.countdown)) : "GO";
    } else if (raceState.phase === "finished") {
      countdownReadout.textContent = "Done";
    } else {
      countdownReadout.textContent = "Live";
    }

    if (raceState.messageTimer > 0 || raceState.phase === "finished") {
      statusReadout.textContent = raceState.message;
    } else if (raceState.phase === "countdown") {
      statusReadout.textContent = "Grid up: waiting for the green light.";
    } else {
      statusReadout.textContent = "Race hot: hold a clean line through the aisles.";
    }

    leaderboardList.innerHTML = "";
    standings.forEach(function (racer, index) {
      const itemText = racer.finished ? "Finished" : labelForItem(racer.item);
      const item = document.createElement("li");
      item.innerHTML =
        '<span class="leaderboard__place">' +
        (index + 1) +
        '</span><span class="leaderboard__name">' +
        racer.name +
        "</span><span class=\"leaderboard__item\">" +
        itemText +
        "</span>";
      leaderboardList.appendChild(item);
    });
  }

  function announce(message) {
    raceState.message = message;
    raceState.messageTimer = 2.5;
  }

  function render(timestamp) {
    ctx.clearRect(0, 0, world.width, world.height);
    drawBackground();
    drawShelves();
    drawTrack();
    drawPickups(timestamp);
    drawHazards();
    drawFinishLine();
    drawRacers();
    drawCanvasHud();
  }

  function drawBackground() {
    const gradient = ctx.createLinearGradient(0, 0, 0, world.height);
    gradient.addColorStop(0, "#132740");
    gradient.addColorStop(1, "#0a1426");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, world.width, world.height);

    ctx.strokeStyle = "rgba(255, 255, 255, 0.03)";
    for (let x = 24; x < world.width; x += 44) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, world.height);
      ctx.stroke();
    }

    for (let y = 24; y < world.height; y += 44) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(world.width, y);
      ctx.stroke();
    }
  }

  function drawShelves() {
    shelves.forEach(function (shelf) {
      ctx.fillStyle = shelf.tint;
      ctx.strokeStyle = "rgba(0, 0, 0, 0.28)";
      ctx.lineWidth = 3;
      roundedRect(ctx, shelf.x, shelf.y, shelf.w, shelf.h, 12, true, true);

      for (let x = shelf.x + 14; x < shelf.x + shelf.w - 10; x += 30) {
        ctx.fillStyle = shelf.goods;
        ctx.globalAlpha = 0.88;
        ctx.fillRect(x, shelf.y + 8, 18, shelf.h - 16);
      }
      ctx.globalAlpha = 1;

      ctx.fillStyle = "rgba(255, 255, 255, 0.8)";
      ctx.font = "bold 12px Arial";
      ctx.fillText(shelf.label, shelf.x + 10, shelf.y + shelf.h / 2 + 4);
    });
  }

  function drawTrack() {
    const samples = sampleLoop(180);

    strokePath(samples, world.trackWidth + 24, "rgba(0, 0, 0, 0.18)");
    strokePath(samples, world.trackWidth, "#d5dbe4");
    strokePath(samples, world.trackWidth - 20, "#aeb8c6");

    ctx.save();
    ctx.setLineDash([20, 16]);
    strokePath(samples, 4, "#ffe57a");
    ctx.restore();

    strokePath(samples, world.trackWidth, "rgba(255, 255, 255, 0.18)");
  }

  function drawPickups(timestamp) {
    pickupPads.forEach(function (pickup) {
      if (pickup.cooldown > 0) {
        return;
      }

      const point = lanePosition(pickup.progress, pickup.lane);
      const pulse = 1 + Math.sin(timestamp / 220) * 0.08;

      ctx.save();
      ctx.translate(point.x, point.y);
      ctx.rotate(timestamp / 600);
      ctx.scale(pulse, pulse);
      ctx.fillStyle = "#4dd8ff";
      ctx.globalAlpha = 0.18;
      ctx.fillRect(-18, -18, 36, 36);
      ctx.globalAlpha = 1;
      ctx.fillStyle = "#ffce61";
      ctx.fillRect(-12, -12, 24, 24);
      ctx.strokeStyle = "#fff8d8";
      ctx.lineWidth = 2;
      ctx.strokeRect(-12, -12, 24, 24);
      ctx.fillStyle = "#111";
      ctx.font = "bold 16px Arial";
      ctx.fillText("?", -5, 6);
      ctx.restore();
    });
  }

  function drawHazards() {
    raceState.hazards.forEach(function (hazard) {
      const point = lanePosition(hazard.progress, hazard.lane);
      ctx.save();
      ctx.translate(point.x, point.y);
      ctx.fillStyle = "rgba(78, 48, 28, 0.78)";
      ctx.beginPath();
      ctx.ellipse(0, 0, 14, 10, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255, 199, 99, 0.48)";
      ctx.beginPath();
      ctx.ellipse(2, -1, 7, 4, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    });
  }

  function drawFinishLine() {
    const sample = sampleTrack(world.startProgress);
    const normal = sample.normal;
    const tangent = sample.tangent;
    const halfWidth = world.trackWidth * 0.42;

    ctx.save();
    ctx.translate(sample.x, sample.y);
    ctx.rotate(Math.atan2(tangent.y, tangent.x));

    for (let index = -3; index < 3; index += 1) {
      ctx.fillStyle = index % 2 === 0 ? "#fff" : "#111";
      ctx.fillRect(-10 + index * 10, -halfWidth, 10, halfWidth * 2);
    }

    ctx.restore();

    ctx.strokeStyle = "rgba(255, 255, 255, 0.4)";
    ctx.beginPath();
    ctx.moveTo(sample.x - normal.x * halfWidth, sample.y - normal.y * halfWidth);
    ctx.lineTo(sample.x + normal.x * halfWidth, sample.y + normal.y * halfWidth);
    ctx.stroke();
  }

  function drawRacers() {
    raceState.racers.forEach(function (racer) {
      const point = lanePosition(racer.progress, racer.lane);
      const angle = point.angle;

      ctx.save();
      ctx.translate(point.x, point.y);
      ctx.rotate(angle);

      ctx.fillStyle = "rgba(0, 0, 0, 0.25)";
      ctx.beginPath();
      ctx.ellipse(0, 12, 20, 10, 0, 0, Math.PI * 2);
      ctx.fill();

      if (racer.shieldTimer > 0) {
        ctx.strokeStyle = "rgba(196, 242, 255, 0.8)";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(0, 0, 22, 0, Math.PI * 2);
        ctx.stroke();
      }

      ctx.fillStyle = racer.color;
      ctx.strokeStyle = "rgba(0, 0, 0, 0.4)";
      ctx.lineWidth = 2;
      roundedRect(ctx, -18, -10, 36, 26, 8, true, true);

      ctx.strokeStyle = racer.accent;
      ctx.lineWidth = 3;
      ctx.strokeRect(-10, -6, 20, 12);

      ctx.fillStyle = "#1c2431";
      ctx.fillRect(-12, 4, 24, 6);

      ctx.fillStyle = "#111";
      ctx.fillRect(-18, -14, 6, 5);
      ctx.fillRect(12, -14, 6, 5);
      ctx.fillRect(-18, 14, 6, 5);
      ctx.fillRect(12, 14, 6, 5);

      if (racer.boostTimer > 0) {
        ctx.fillStyle = "#ffb347";
        ctx.beginPath();
        ctx.moveTo(-7, 16);
        ctx.lineTo(0, 28);
        ctx.lineTo(7, 16);
        ctx.closePath();
        ctx.fill();
      }

      ctx.restore();

      ctx.fillStyle = racer.isPlayer ? "#fff5ce" : "#edf4ff";
      ctx.font = racer.isPlayer ? "bold 13px Arial" : "12px Arial";
      ctx.textAlign = "center";
      ctx.fillText(racer.name, point.x, point.y - 26);

      if (racer.isPlayer) {
        ctx.fillStyle = "#ffce61";
        ctx.beginPath();
        ctx.moveTo(point.x, point.y - 40);
        ctx.lineTo(point.x - 8, point.y - 54);
        ctx.lineTo(point.x + 8, point.y - 54);
        ctx.closePath();
        ctx.fill();
      }
    });
  }

  function drawCanvasHud() {
    if (raceState.phase === "countdown") {
      drawCenterBanner(raceState.countdown > 0.2 ? String(Math.ceil(raceState.countdown)) : "GO");
    } else if (raceState.phase === "finished") {
      const player = raceState.racers[0];
      const finishMs = raceState.finishTime && raceState.startTime ? (raceState.finishTime - raceState.startTime) / 1000 : 0;
      drawCenterBanner(ordinal(player.finishPlace || 1) + " place", finishMs > 0 ? finishMs.toFixed(1) + "s" : "Race done");
    }
  }

  function drawCenterBanner(title, subtitle) {
    ctx.save();
    ctx.translate(world.width / 2, 82);
    ctx.fillStyle = "rgba(5, 10, 20, 0.72)";
    roundedRect(ctx, -110, -34, 220, 68, 18, true, false);
    ctx.fillStyle = "#ffefc5";
    ctx.font = "bold 34px Arial";
    ctx.textAlign = "center";
    ctx.fillText(title, 0, 6);
    if (subtitle) {
      ctx.font = "14px Arial";
      ctx.fillStyle = "rgba(233, 244, 255, 0.8)";
      ctx.fillText(subtitle, 0, 24);
    }
    ctx.restore();
  }

  function sampleLoop(steps) {
    const points = [];
    for (let index = 0; index <= steps; index += 1) {
      points.push(sampleTrack((index / steps) * totalLength));
    }
    return points;
  }

  function sampleTrack(distanceAlongTrack) {
    const wrapped = wrapDistance(distanceAlongTrack);
    let segmentIndex = 0;

    while (
      segmentIndex < trackSegments.segments.length - 1 &&
      wrapped >= trackSegments.segments[segmentIndex].cumulative + trackSegments.segments[segmentIndex].length
    ) {
      segmentIndex += 1;
    }

    const segment = trackSegments.segments[segmentIndex];
    const localDistance = wrapped - segment.cumulative;
    const t = segment.length === 0 ? 0 : localDistance / segment.length;
    const count = trackSegments.points.length;
    const p0 = trackSegments.points[(segmentIndex - 1 + count) % count];
    const p1 = trackSegments.points[segmentIndex % count];
    const p2 = trackSegments.points[(segmentIndex + 1) % count];
    const p3 = trackSegments.points[(segmentIndex + 2) % count];

    const position = catmullRom(p0, p1, p2, p3, t);
    const tangent = catmullTangent(p0, p1, p2, p3, t);
    const tangentLength = Math.max(0.0001, Math.hypot(tangent.x, tangent.y));
    const unitTangent = { x: tangent.x / tangentLength, y: tangent.y / tangentLength };
    const normal = { x: -unitTangent.y, y: unitTangent.x };

    return {
      x: position.x,
      y: position.y,
      angle: Math.atan2(unitTangent.y, unitTangent.x),
      tangent: unitTangent,
      normal: normal,
    };
  }

  function lanePosition(progress, lane) {
    const point = sampleTrack(progress);
    return {
      x: point.x + point.normal.x * lane,
      y: point.y + point.normal.y * lane,
      angle: point.angle,
    };
  }

  function curvatureAt(progress) {
    const ahead = sampleTrack(progress + 45);
    const behind = sampleTrack(progress - 45);
    return Math.abs(normalizeAngle(ahead.angle - behind.angle));
  }

  function getNearestHazard(progress) {
    return raceState.hazards
      .map(function (hazard) {
        return {
          lane: hazard.lane,
          distanceAhead: aheadDistance(progress, hazard.progress),
        };
      })
      .sort(function (left, right) {
        return left.distanceAhead - right.distanceAhead;
      })[0];
  }

  function strokePath(points, width, strokeStyle) {
    ctx.save();
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = strokeStyle;
    ctx.lineWidth = width;
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let index = 1; index < points.length; index += 1) {
      ctx.lineTo(points[index].x, points[index].y);
    }
    ctx.closePath();
    ctx.stroke();
    ctx.restore();
  }

  function roundedRect(context, x, y, width, height, radius, fill, stroke) {
    const r = Math.min(radius, width / 2, height / 2);
    context.beginPath();
    context.moveTo(x + r, y);
    context.lineTo(x + width - r, y);
    context.quadraticCurveTo(x + width, y, x + width, y + r);
    context.lineTo(x + width, y + height - r);
    context.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    context.lineTo(x + r, y + height);
    context.quadraticCurveTo(x, y + height, x, y + height - r);
    context.lineTo(x, y + r);
    context.quadraticCurveTo(x, y, x + r, y);
    context.closePath();

    if (fill) {
      context.fill();
    }

    if (stroke) {
      context.stroke();
    }
  }

  function catmullRom(p0, p1, p2, p3, t) {
    const t2 = t * t;
    const t3 = t2 * t;

    return {
      x:
        0.5 *
        ((2 * p1.x) +
          (-p0.x + p2.x) * t +
          (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
          (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
      y:
        0.5 *
        ((2 * p1.y) +
          (-p0.y + p2.y) * t +
          (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
          (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3),
    };
  }

  function catmullTangent(p0, p1, p2, p3, t) {
    const t2 = t * t;
    return {
      x:
        0.5 *
        ((-p0.x + p2.x) +
          2 * (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t +
          3 * (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t2),
      y:
        0.5 *
        ((-p0.y + p2.y) +
          2 * (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t +
          3 * (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t2),
    };
  }

  function wrapDistance(value) {
    return ((value % totalLength) + totalLength) % totalLength;
  }

  function aheadDistance(from, to) {
    return wrapDistance(to - from);
  }

  function circularDistance(a, b) {
    const delta = Math.abs(wrapDistance(a) - wrapDistance(b));
    return Math.min(delta, totalLength - delta);
  }

  function labelForItem(item) {
    if (item === "boost") {
      return "Turbo Coffee";
    }
    if (item === "shield") {
      return "Soup Lid Shield";
    }
    if (item === "spill") {
      return "Soda Spill";
    }
    return "None";
  }

  function ordinal(value) {
    if (value % 100 >= 11 && value % 100 <= 13) {
      return value + "th";
    }
    if (value % 10 === 1) {
      return value + "st";
    }
    if (value % 10 === 2) {
      return value + "nd";
    }
    if (value % 10 === 3) {
      return value + "rd";
    }
    return value + "th";
  }

  function normalizeAngle(angle) {
    let normalized = angle;
    while (normalized > Math.PI) {
      normalized -= Math.PI * 2;
    }
    while (normalized < -Math.PI) {
      normalized += Math.PI * 2;
    }
    return normalized;
  }

  function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y);
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }
})();
