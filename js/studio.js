(function () {
  "use strict";

  var body = document.body;
  var header = document.querySelector("[data-header]");
  var menuButton = document.querySelector(".menu-toggle");
  var nav = document.querySelector(".site-nav");
  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function closeMenu() {
    body.classList.remove("menu-open");
    menuButton.setAttribute("aria-expanded", "false");
    document.querySelector(".menu-toggle-label").textContent = "Menu";
  }

  menuButton.addEventListener("click", function () {
    var isOpen = body.classList.toggle("menu-open");
    menuButton.setAttribute("aria-expanded", String(isOpen));
    document.querySelector(".menu-toggle-label").textContent = isOpen ? "Close" : "Menu";
  });

  nav.addEventListener("click", function (event) {
    if (event.target.closest("a")) {
      closeMenu();
    }
  });

  window.addEventListener("resize", function () {
    if (window.innerWidth > 900) {
      closeMenu();
    }
  });

  function updateHeader() {
    header.classList.toggle("is-scrolled", window.scrollY > 32);
  }

  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  var revealItems = document.querySelectorAll(".reveal");
  if (reducedMotion || !("IntersectionObserver" in window)) {
    revealItems.forEach(function (item) {
      item.classList.add("is-visible");
    });
  } else {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    }, {
      threshold: 0.13,
      rootMargin: "0px 0px -5% 0px"
    });

    revealItems.forEach(function (item, index) {
      item.style.transitionDelay = Math.min((index % 4) * 70, 210) + "ms";
      observer.observe(item);
    });
  }

  var dialog = document.querySelector(".project-dialog");
  var dialogImage = dialog.querySelector("[data-dialog-image]");
  var dialogTitle = dialog.querySelector("#dialog-title");
  var dialogCategory = dialog.querySelector("[data-dialog-category]");
  var closeButton = dialog.querySelector(".dialog-close");

  document.querySelectorAll(".project-card").forEach(function (card) {
    card.addEventListener("click", function () {
      var title = card.dataset.projectTitle;
      dialogTitle.textContent = title;
      dialogCategory.textContent = card.dataset.projectCategory;
      dialogImage.src = card.dataset.projectImage;
      dialogImage.alt = title + " project preview";
      dialog.showModal();
      body.classList.add("dialog-open");
    });
  });

  function closeDialog() {
    dialog.close();
    body.classList.remove("dialog-open");
  }

  closeButton.addEventListener("click", closeDialog);

  dialog.addEventListener("click", function (event) {
    if (event.target === dialog) {
      closeDialog();
    }
  });

  dialog.addEventListener("close", function () {
    body.classList.remove("dialog-open");
    dialogImage.removeAttribute("src");
  });

  document.querySelector("[data-year]").textContent = new Date().getFullYear();
})();
