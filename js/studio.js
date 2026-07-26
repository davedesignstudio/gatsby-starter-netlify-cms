document.documentElement.classList.add("js");

const header = document.querySelector("[data-header]");
const menuButton = document.querySelector(".menu-toggle");
const navigation = document.querySelector(".site-nav");
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

function setHeaderState() {
  header?.classList.toggle("is-scrolled", window.scrollY > 24);
}

function closeMenu() {
  if (!menuButton || !navigation) return;
  menuButton.setAttribute("aria-expanded", "false");
  navigation.classList.remove("is-open");
  document.body.classList.remove("menu-open");
}

function toggleMenu() {
  if (!menuButton || !navigation) return;
  const willOpen = menuButton.getAttribute("aria-expanded") !== "true";
  menuButton.setAttribute("aria-expanded", String(willOpen));
  navigation.classList.toggle("is-open", willOpen);
  document.body.classList.toggle("menu-open", willOpen);
}

setHeaderState();
window.addEventListener("scroll", setHeaderState, { passive: true });
menuButton?.addEventListener("click", toggleMenu);

navigation?.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", closeMenu);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeMenu();
    menuButton?.focus();
  }
});

window.addEventListener("resize", () => {
  if (window.innerWidth > 800) closeMenu();
});

const reveals = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window && !prefersReducedMotion.matches) {
  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
  );

  reveals.forEach((element) => revealObserver.observe(element));
} else {
  reveals.forEach((element) => element.classList.add("is-visible"));
}

const parallaxCanvas = document.querySelector("[data-parallax]");
const heroArt = document.querySelector(".hero-art");

if (parallaxCanvas && heroArt && !prefersReducedMotion.matches) {
  heroArt.addEventListener("pointermove", (event) => {
    if (event.pointerType === "touch") return;
    const bounds = heroArt.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width - 0.5;
    const y = (event.clientY - bounds.top) / bounds.height - 0.5;

    parallaxCanvas.style.transform =
      `translate(calc(-50% + ${x * 12}px), calc(-49% + ${y * 12}px)) ` +
      `rotate(${3 + x * 2}deg) scale(1.015)`;
  });

  heroArt.addEventListener("pointerleave", () => {
    parallaxCanvas.style.transform = "";
  });
}

const year = document.querySelector("[data-year]");
if (year) year.textContent = String(new Date().getFullYear());
