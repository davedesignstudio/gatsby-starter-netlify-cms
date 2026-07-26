document.documentElement.classList.add("js");

const menuButton = document.querySelector(".menu-button");
const mobileMenu = document.querySelector(".mobile-menu");

function setMenu(open) {
  menuButton?.setAttribute("aria-expanded", String(open));
  if (mobileMenu) mobileMenu.hidden = !open;
  document.body.classList.toggle("menu-open", open);
  const label = menuButton?.querySelector(".sr-only");
  if (label) label.textContent = open ? "Close menu" : "Open menu";
}

menuButton?.addEventListener("click", () => {
  setMenu(menuButton.getAttribute("aria-expanded") !== "true");
});

mobileMenu?.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", () => setMenu(false));
});

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") setMenu(false);
});

const revealItems = document.querySelectorAll(".reveal");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (reducedMotion || !("IntersectionObserver" in window)) {
  revealItems.forEach((item) => item.classList.add("is-visible"));
} else {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { rootMargin: "0px 0px -8% 0px", threshold: 0.08 },
  );

  revealItems.forEach((item) => observer.observe(item));
}

const zoomSection = document.querySelector(".zoom-section");

if (zoomSection && !reducedMotion) {
  window.addEventListener(
    "scroll",
    () => {
      const progress = Math.min(window.scrollY / window.innerHeight, 1);
      zoomSection.style.setProperty("--zoom", String(1 + progress * 0.025));
      zoomSection.style.setProperty("--fade", String(1 - progress * 0.24));
    },
    { passive: true },
  );
}
