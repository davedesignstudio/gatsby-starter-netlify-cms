(function () {
  'use strict';

  var container = document.getElementById('zoom-container');
  var sections = document.querySelectorAll('.zoom-section');
  var navDots = document.querySelectorAll('.zoom-nav__dot');
  var tiles = document.querySelectorAll('.zoom-tile');

  if (!container || !sections.length) return;

  /* Intersection Observer — zoom sections into view */
  var sectionObserver = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');

          var id = entry.target.id;
          navDots.forEach(function (dot) {
            dot.classList.toggle('is-active', dot.getAttribute('data-section') === id);
          });
        }
      });
    },
    { root: container, threshold: 0.4 }
  );

  sections.forEach(function (section) {
    sectionObserver.observe(section);
  });

  /* Smooth scroll via nav dots */
  navDots.forEach(function (dot) {
    dot.addEventListener('click', function (e) {
      e.preventDefault();
      var target = document.getElementById(dot.getAttribute('data-section'));
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  /* Service tile focus — zoom one tile at a time on hover */
  tiles.forEach(function (tile) {
    tile.addEventListener('mouseenter', function () {
      tiles.forEach(function (t) {
        t.classList.remove('is-focused');
      });
      tile.classList.add('is-focused');
    });

    tile.addEventListener('mouseleave', function () {
      tile.classList.remove('is-focused');
    });
  });

  /* Keyboard navigation between sections */
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;

    var currentIndex = -1;
    sections.forEach(function (section, i) {
      if (section.classList.contains('is-visible')) currentIndex = i;
    });

    if (currentIndex === -1) return;

    var nextIndex = e.key === 'ArrowDown'
      ? Math.min(currentIndex + 1, sections.length - 1)
      : Math.max(currentIndex - 1, 0);

    if (nextIndex !== currentIndex) {
      e.preventDefault();
      sections[nextIndex].scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });

  /* Trigger hero visibility on load */
  window.addEventListener('load', function () {
    var hero = document.getElementById('home');
    if (hero) hero.classList.add('is-visible');
  });
})();
