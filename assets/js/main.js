/* D. Philhower Studio — dphilhowerstudio.com */
(function () {
  "use strict";

  /* ---------- Header: solid background after scrolling past the top ---------- */
  var header = document.querySelector(".site-header");
  function onScroll() {
    header.classList.toggle("is-scrolled", window.scrollY > 40);
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- Mobile navigation ---------- */
  var navToggle = document.querySelector(".nav-toggle");
  var siteNav = document.getElementById("site-nav");

  navToggle.addEventListener("click", function () {
    var open = siteNav.classList.toggle("is-open");
    navToggle.setAttribute("aria-expanded", open ? "true" : "false");
    document.body.classList.toggle("lightbox-open", open);
  });

  siteNav.addEventListener("click", function (event) {
    if (event.target.closest("a")) {
      siteNav.classList.remove("is-open");
      navToggle.setAttribute("aria-expanded", "false");
      document.body.classList.remove("lightbox-open");
    }
  });

  /* ---------- Zoom-in scroll reveals ---------- */
  var revealEls = Array.prototype.slice.call(document.querySelectorAll(".zoom-in"));
  revealEls.forEach(function (el) {
    var delay = el.getAttribute("data-delay");
    if (delay) el.style.setProperty("--reveal-delay", delay + "ms");
  });

  if ("IntersectionObserver" in window) {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: "0px 0px -5% 0px" }
    );
    revealEls.forEach(function (el) { observer.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("is-visible"); });
  }

  /* ---------- Active nav link highlighting ---------- */
  var sections = Array.prototype.slice.call(document.querySelectorAll("main section[id]"));
  var navLinks = Array.prototype.slice.call(
    document.querySelectorAll('.site-nav a[href^="#"]:not(.button)')
  );

  if ("IntersectionObserver" in window && sections.length) {
    var sectionObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var id = entry.target.id;
          navLinks.forEach(function (link) {
            link.classList.toggle("is-active", link.getAttribute("href") === "#" + id);
          });
        });
      },
      { rootMargin: "-40% 0px -55% 0px" }
    );
    sections.forEach(function (section) { sectionObserver.observe(section); });
  }

  /* ---------- Lightbox with zoom transition ---------- */
  var lightbox = document.getElementById("lightbox");
  var stage = lightbox.querySelector(".lightbox-stage");
  var stageImg = stage.querySelector("img");
  var stageCat = lightbox.querySelector(".lightbox-cat");
  var stageTitle = lightbox.querySelector(".lightbox-title");
  var closeBtn = lightbox.querySelector(".lightbox-close");
  var prevBtn = lightbox.querySelector(".lightbox-prev");
  var nextBtn = lightbox.querySelector(".lightbox-next");

  var workItems = Array.prototype.slice.call(document.querySelectorAll(".work-item"));
  var currentIndex = -1;
  var lastFocused = null;

  function renderSlide(index) {
    var item = workItems[index];
    currentIndex = index;
    stageImg.src = item.getAttribute("href");
    stageImg.alt = item.querySelector("img").alt;
    stageCat.textContent = item.getAttribute("data-cat") || "";
    stageTitle.textContent = item.getAttribute("data-title") || "";

    // retrigger the zoom animation
    stage.classList.remove("is-switching");
    void stage.offsetWidth;
    stage.classList.add("is-switching");
  }

  function openLightbox(index) {
    lastFocused = document.activeElement;
    renderSlide(index);
    lightbox.hidden = false;
    document.body.classList.add("lightbox-open");
    closeBtn.focus();
  }

  function closeLightbox() {
    lightbox.hidden = true;
    document.body.classList.remove("lightbox-open");
    if (lastFocused) lastFocused.focus();
  }

  function step(direction) {
    renderSlide((currentIndex + direction + workItems.length) % workItems.length);
  }

  workItems.forEach(function (item, index) {
    item.addEventListener("click", function (event) {
      event.preventDefault();
      openLightbox(index);
    });
  });

  closeBtn.addEventListener("click", closeLightbox);
  prevBtn.addEventListener("click", function () { step(-1); });
  nextBtn.addEventListener("click", function () { step(1); });

  lightbox.addEventListener("click", function (event) {
    if (event.target === lightbox) closeLightbox();
  });

  document.addEventListener("keydown", function (event) {
    if (lightbox.hidden) return;
    if (event.key === "Escape") closeLightbox();
    if (event.key === "ArrowLeft") step(-1);
    if (event.key === "ArrowRight") step(1);
  });

  /* ---------- Footer year ---------- */
  document.getElementById("year").textContent = new Date().getFullYear();
})();
