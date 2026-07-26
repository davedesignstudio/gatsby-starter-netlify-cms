/** Screen navigation & cart select UI */
(function () {
  let selectedId = "rusty";

  function show(id) {
    document.querySelectorAll(".screen").forEach((s) => s.classList.remove("active"));
    const el = document.getElementById(id);
    if (el) el.classList.add("active");
  }

  function paintCartGrid() {
    const grid = document.getElementById("cart-grid");
    grid.innerHTML = "";
    CARTS.forEach((cart) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "cart-card" + (cart.id === selectedId ? " selected" : "");
      btn.innerHTML =
        `<div class="cart-swatch" style="background:linear-gradient(135deg,${cart.color},${cart.accent})">` +
        `<svg width="100%" height="100%" viewBox="0 0 80 54" aria-hidden="true">` +
        `<rect x="18" y="14" width="44" height="26" rx="3" fill="${cart.basket}" stroke="${cart.accent}" stroke-width="2"/>` +
        `<rect x="58" y="18" width="10" height="18" fill="${cart.color}"/>` +
        `<path d="M18 14 L12 6 H28" stroke="${cart.color}" stroke-width="3" fill="none"/>` +
        `<circle cx="26" cy="44" r="4" fill="#222"/><circle cx="54" cy="44" r="4" fill="#222"/>` +
        `</svg></div>` +
        `<h3>${cart.name}</h3><p>${cart.blurb}</p>`;
      btn.addEventListener("click", () => {
        selectedId = cart.id;
        CartKart.state.selectedCartId = cart.id;
        paintCartGrid();
      });
      grid.appendChild(btn);
    });
  }

  function showResults(order) {
    show("screen-results");
    const title = document.getElementById("results-title");
    const you = order.find((r) => r.isPlayer);
    title.textContent =
      you && you.finishPlace === 1
        ? "Checkout Champ!"
        : you && you.finishPlace <= 3
          ? "Podium Run!"
          : "Back to the Corral";

    const list = document.getElementById("results-list");
    list.innerHTML = "";
    order.forEach((r) => {
      const li = document.createElement("li");
      if (r.isPlayer) li.classList.add("you");
      const time = r.finishTime ? formatTime(r.finishTime) : "—";
      li.innerHTML =
        `<span><span class="place">${r.finishPlace}${ordinal(r.finishPlace)}</span> ${r.name}` +
        `${r.isPlayer ? " (You)" : ""}</span><span>${time}</span>`;
      list.appendChild(li);
    });
  }

  function formatTime(t) {
    const m = Math.floor(t / 60);
    const s = Math.floor(t % 60);
    const ms = Math.floor((t % 1) * 100);
    return `${m}:${String(s).padStart(2, "0")}.${String(ms).padStart(2, "0")}`;
  }

  function togglePause() {
    if (!CartKart.isRacing()) return;
    const pausing = !CartKart.state.paused;
    CartKart.setPaused(pausing);
    if (pausing) {
      document.getElementById("screen-pause").classList.add("active");
    } else {
      document.getElementById("screen-pause").classList.remove("active");
    }
  }

  function bind() {
    document.getElementById("btn-play").addEventListener("click", () => {
      paintCartGrid();
      show("screen-select");
    });
    document.getElementById("btn-how").addEventListener("click", () => show("screen-how"));
    document.getElementById("btn-how-back").addEventListener("click", () => show("screen-title"));
    document.getElementById("btn-select-back").addEventListener("click", () => show("screen-title"));
    document.getElementById("btn-start-race").addEventListener("click", () => {
      CartKart.state.selectedCartId = selectedId;
      show("screen-race");
      CartKart.resize();
      CartKart.startRace();
    });
    document.getElementById("btn-pause").addEventListener("click", togglePause);
    document.getElementById("btn-resume").addEventListener("click", () => {
      CartKart.setPaused(false);
      document.getElementById("screen-pause").classList.remove("active");
      document.getElementById("screen-race").classList.add("active");
    });
    document.getElementById("btn-quit").addEventListener("click", () => {
      CartKart.quit();
      document.getElementById("screen-pause").classList.remove("active");
      show("screen-title");
    });
    document.getElementById("btn-menu").addEventListener("click", () => show("screen-title"));
    document.getElementById("btn-retry").addEventListener("click", () => {
      show("screen-race");
      CartKart.resize();
      CartKart.startRace();
    });
  }

  window.CartKartUI = {
    show,
    showResults,
    togglePause,
  };

  document.addEventListener("DOMContentLoaded", () => {
    bind();
    paintCartGrid();
    CartKart.init();
  });
})();
