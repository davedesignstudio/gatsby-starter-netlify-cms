(() => {
  const services = {
    logo: {
      eyebrow: "Identity",
      title: "Logo Design",
      body:
        "Marks, wordmarks, and full brand systems built to hold up on a storefront, a menu, and a phone screen. We shape distinctive logos that feel owned—not templated.",
    },
    poster: {
      eyebrow: "Campaign",
      title: "Poster Design",
      body:
        "Event posters, promotions, and wall-worthy pieces with bold hierarchy and print-ready craft. Ideal for restaurants, shows, and seasonal campaigns.",
    },
    print: {
      eyebrow: "Collateral",
      title: "Print Media",
      body:
        "Menus, business cards, flyers, packaging, and leave-behinds. We design for paper, ink, and the moment someone picks it up.",
    },
    web: {
      eyebrow: "Digital",
      title: "Website Design",
      body:
        "Clean, conversion-minded websites that carry your brand online—layouts, type, imagery, and a clear path to contact or order.",
    },
  };

  const header = document.querySelector("[data-header]");
  const nav = document.querySelector("[data-nav]");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const grid = document.querySelector("[data-zoom-grid]");
  const tiles = document.querySelectorAll(".zoom-tile");
  const detail = document.querySelector("[data-service-detail]");
  const closeDetail = document.querySelector("[data-close-detail]");
  const year = document.querySelector("[data-year]");

  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  const onScroll = () => {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 24);
  };

  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  if (navToggle && nav) {
    navToggle.addEventListener("click", () => {
      const open = nav.classList.toggle("is-open");
      navToggle.setAttribute("aria-expanded", open ? "true" : "false");
    });

    nav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        nav.classList.remove("is-open");
        navToggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  const renderDetail = (key) => {
    if (!detail || !services[key]) return;
    const data = services[key];
    detail.hidden = false;
    detail.querySelector("[data-detail-eyebrow]").textContent = data.eyebrow;
    detail.querySelector("[data-detail-title]").textContent = data.title;
    detail.querySelector("[data-detail-body]").textContent = data.body;
    detail.scrollIntoView({ behavior: "smooth", block: "nearest" });
  };

  const clearPin = () => {
    if (!grid) return;
    grid.classList.remove("is-pinned");
    tiles.forEach((tile) => {
      tile.classList.remove("is-active");
      tile.setAttribute("aria-pressed", "false");
    });
    if (detail) detail.hidden = true;
  };

  tiles.forEach((tile) => {
    tile.addEventListener("click", () => {
      const key = tile.getAttribute("data-service");
      const already = tile.classList.contains("is-active");

      if (already) {
        clearPin();
        return;
      }

      tiles.forEach((other) => {
        other.classList.toggle("is-active", other === tile);
        other.setAttribute("aria-pressed", other === tile ? "true" : "false");
      });

      if (grid) grid.classList.add("is-pinned");
      renderDetail(key);
    });
  });

  if (closeDetail) {
    closeDetail.addEventListener("click", clearPin);
  }

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") clearPin();
  });
})();
