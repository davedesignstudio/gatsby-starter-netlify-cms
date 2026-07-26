(function () {
  const stage = document.querySelector(".stage");
  const buttons = document.querySelectorAll("[data-zoom]");
  if (!stage) return;

  const views = new Set(["home", "logo", "poster", "print", "web", "contact"]);
  let current = stage.getAttribute("data-view") || "home";

  function setView(view, options) {
    const force = options && options.force;
    if (!views.has(view)) return;
    if (view === current && !force) return;
    current = view;
    stage.setAttribute("data-view", view);

    buttons.forEach((btn) => {
      const active = btn.getAttribute("data-zoom") === view;
      btn.classList.toggle("is-active", active);
      if (btn.hasAttribute("aria-pressed")) {
        btn.setAttribute("aria-pressed", active ? "true" : "false");
      }
    });

    if (history.replaceState) {
      const url = view === "home" ? location.pathname : `#${view}`;
      history.replaceState(null, "", url);
    }
  }

  buttons.forEach((btn) => {
    btn.addEventListener("click", (event) => {
      event.preventDefault();
      setView(btn.getAttribute("data-zoom"));
    });
  });

  document.querySelectorAll(".service-hit").forEach((hit) => {
    hit.addEventListener("click", () => {
      const view = hit.getAttribute("data-zoom");
      if (view) setView(view);
    });
  });

  const hash = (location.hash || "").replace("#", "");
  if (views.has(hash)) setView(hash, { force: true });
  else setView("home", { force: true });

  window.addEventListener("hashchange", () => {
    const next = (location.hash || "").replace("#", "") || "home";
    if (views.has(next)) setView(next);
  });

  // Keyboard: Esc returns home; number keys jump services
  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setView("home");
    const map = { "1": "logo", "2": "poster", "3": "print", "4": "web", "0": "home" };
    if (map[event.key]) setView(map[event.key]);
  });

  // Wheel nudges between nearby views when not reduced motion
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!reduce) {
    let wheelLock = false;
    const order = ["home", "logo", "poster", "print", "web", "contact"];
    stage.addEventListener(
      "wheel",
      (event) => {
        if (Math.abs(event.deltaY) < 28 || wheelLock) return;
        wheelLock = true;
        const idx = order.indexOf(current);
        const next = event.deltaY > 0 ? order[Math.min(order.length - 1, idx + 1)] : order[Math.max(0, idx - 1)];
        setView(next);
        window.setTimeout(() => {
          wheelLock = false;
        }, 900);
      },
      { passive: true }
    );
  }
})();
