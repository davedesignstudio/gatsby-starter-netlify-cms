(function () {
  var year = document.getElementById("year");
  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  var drawer = document.getElementById("mobile-drawer");
  var menuBtn = document.querySelector(".mobile-menu-btn");
  if (drawer && menuBtn) {
    menuBtn.addEventListener("click", function () {
      var open = drawer.classList.toggle("is-open");
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
      document.body.style.overflow = open ? "hidden" : "";
    });
    drawer.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        drawer.classList.remove("is-open");
        menuBtn.setAttribute("aria-expanded", "false");
        document.body.style.overflow = "";
      });
    });
  }

  var reveals = document.querySelectorAll(".reveal");
  if (!reveals.length || !("IntersectionObserver" in window)) {
    reveals.forEach(function (el) {
      el.classList.add("is-in");
    });
    return;
  }

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.16, rootMargin: "0px 0px -40px 0px" }
  );

  reveals.forEach(function (el) {
    observer.observe(el);
  });
})();
