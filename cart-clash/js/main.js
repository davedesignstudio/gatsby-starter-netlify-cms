(() => {
  const $ = (id) => document.getElementById(id);

  const screens = {
    title: $("screen-title"),
    how: $("screen-how"),
    select: $("screen-select"),
    hud: $("screen-hud"),
    pause: $("screen-pause"),
    results: $("screen-results"),
  };

  const canvas = $("game");
  const engine = new CartClashEngine(canvas);
  let selectedCart = null;
  let keys = {};
  let steerTouch = 0;
  let gasTouch = false;
  let brakeTouch = false;

  function show(name) {
    Object.values(screens).forEach((el) => el.classList.remove("active"));
    screens[name].classList.add("active");
  }

  function formatTime(t) {
    const m = Math.floor(t / 60);
    const s = t % 60;
    return `${m}:${s.toFixed(1).padStart(4, "0")}`;
  }

  // Cart select grid
  const grid = $("cart-grid");
  CARTS.forEach((cart) => {
    const btn = document.createElement("button");
    btn.className = "cart-card";
    btn.type = "button";
    btn.innerHTML = `
      <div class="cart-swatch" style="background: linear-gradient(180deg, ${cart.color}, ${cart.accent})"></div>
      <h3>${cart.name}</h3>
      <p>${cart.blurb}</p>
      <p>SPD ${(cart.speed * 100) | 0} · HND ${(cart.handling * 100) | 0}</p>
    `;
    btn.addEventListener("click", () => {
      selectedCart = cart;
      grid.querySelectorAll(".cart-card").forEach((c) => c.classList.remove("selected"));
      btn.classList.add("selected");
      $("btn-start-race").disabled = false;
    });
    grid.appendChild(btn);
  });

  // Buttons
  $("btn-play").addEventListener("click", () => show("select"));
  $("btn-how").addEventListener("click", () => show("how"));
  $("btn-how-back").addEventListener("click", () => show("title"));
  $("btn-start-race").addEventListener("click", () => {
    if (!selectedCart) return;
    beginRace();
  });
  $("btn-pause").addEventListener("click", () => {
    engine.pause();
    show("pause");
  });
  $("btn-resume").addEventListener("click", () => {
    show("hud");
    engine.resume();
  });
  $("btn-quit").addEventListener("click", () => {
    engine.stop();
    show("title");
  });
  $("btn-retry").addEventListener("click", () => {
    if (!selectedCart) show("select");
    else beginRace();
  });
  $("btn-home").addEventListener("click", () => show("title"));

  function beginRace() {
    show("hud");
    engine.start(selectedCart);
  }

  engine.onHud = (hud) => {
    $("hud-place").textContent = PLACE_SUFFIX(hud.place);
    $("hud-lap").textContent = `LAP ${hud.lap}/${hud.totalLaps}`;
    $("hud-time").textContent = formatTime(hud.time);

    const cd = $("countdown");
    if (hud.countdown > 0) {
      cd.textContent = hud.countdown > 3 ? "3" : String(hud.countdown);
      cd.classList.remove("hidden");
    } else {
      cd.classList.add("hidden");
    }

    const banner = $("item-banner");
    if (hud.banner) {
      banner.textContent = hud.banner;
      banner.classList.remove("hidden");
    } else {
      banner.classList.add("hidden");
    }

    const itemBtn = $("btn-item");
    if (hud.item) {
      itemBtn.textContent = ITEMS[hud.item].name.split(" ")[0].toUpperCase();
      itemBtn.style.background = ITEMS[hud.item].color;
    } else {
      itemBtn.textContent = "ITEM";
      itemBtn.style.background = "";
    }
  };

  engine.onFinish = (results) => {
    const list = $("results-list");
    list.innerHTML = "";
    const player = results.find((r) => r.isPlayer);
    $("results-title").textContent = player && player.place === 1 ? "Aisle Champion!" : "Race Over";
    results.forEach((r) => {
      const li = document.createElement("li");
      if (r.isPlayer) li.className = "you";
      li.innerHTML = `<span>${PLACE_SUFFIX(r.place)} — ${r.name}${r.isPlayer ? " (You)" : ""}</span><span>${r.finished ? formatTime(r.time) : "DNF"}</span>`;
      list.appendChild(li);
    });
    show("results");
  };

  // Keyboard
  window.addEventListener("keydown", (e) => {
    keys[e.code] = true;
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(e.code)) {
      e.preventDefault();
    }
    if (e.code === "Space" || e.code === "KeyX") engine.setInput({ useItem: true });
    if (e.code === "Escape" && screens.hud.classList.contains("active")) {
      engine.pause();
      show("pause");
    }
  });
  window.addEventListener("keyup", (e) => {
    keys[e.code] = false;
  });

  // Touch / mouse pedals
  function bindHold(el, on, off) {
    const start = (e) => {
      e.preventDefault();
      el.classList.add("active");
      on();
    };
    const end = (e) => {
      e.preventDefault();
      el.classList.remove("active");
      off();
    };
    el.addEventListener("pointerdown", start);
    el.addEventListener("pointerup", end);
    el.addEventListener("pointerleave", end);
    el.addEventListener("pointercancel", end);
  }

  bindHold(
    $("btn-gas"),
    () => { gasTouch = true; },
    () => { gasTouch = false; }
  );
  bindHold(
    $("btn-brake"),
    () => { brakeTouch = true; },
    () => { brakeTouch = false; }
  );
  $("btn-item").addEventListener("pointerdown", (e) => {
    e.preventDefault();
    engine.setInput({ useItem: true });
  });

  // Steering pad
  const zone = $("steer-zone");
  const knob = $("steer-knob");
  let steering = false;

  function setKnob(nx, ny) {
    const rect = zone.getBoundingClientRect();
    const cx = rect.width / 2;
    const cy = rect.height / 2;
    const max = rect.width * 0.32;
    const dx = clamp(nx - cx, -max, max);
    const dy = clamp(ny - cy, -max, max);
    knob.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
    steerTouch = dx / max;
  }

  function resetKnob() {
    knob.style.transform = "translate(-50%, -50%)";
    steerTouch = 0;
    steering = false;
  }

  zone.addEventListener("pointerdown", (e) => {
    steering = true;
    zone.setPointerCapture(e.pointerId);
    const rect = zone.getBoundingClientRect();
    setKnob(e.clientX - rect.left, e.clientY - rect.top);
  });
  zone.addEventListener("pointermove", (e) => {
    if (!steering) return;
    const rect = zone.getBoundingClientRect();
    setKnob(e.clientX - rect.left, e.clientY - rect.top);
  });
  zone.addEventListener("pointerup", resetKnob);
  zone.addEventListener("pointercancel", resetKnob);

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  // Input pump
  function pumpInput() {
    const left = keys.ArrowLeft || keys.KeyA;
    const right = keys.ArrowRight || keys.KeyD;
    let steer = steerTouch;
    if (left || right) steer = (right ? 1 : 0) + (left ? -1 : 0);
    const brake = brakeTouch || keys.ArrowDown || keys.KeyS;
    const gas = gasTouch || keys.ArrowUp || keys.KeyW || !brake;
    engine.setInput({ steer, gas, brake });
    requestAnimationFrame(pumpInput);
  }
  pumpInput();

  // Resize
  window.addEventListener("resize", () => engine.resize());
  window.addEventListener("orientationchange", () => setTimeout(() => engine.resize(), 200));

  // Idle attract render — soft title background motion via CSS; warm canvas once
  engine.resize();
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "#0b1f24";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Prevent iOS bounce
  document.addEventListener("touchmove", (e) => e.preventDefault(), { passive: false });
})();
