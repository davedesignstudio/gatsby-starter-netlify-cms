/* ===================================================================
   DPhilhower Studio — Zoom Layout JavaScript
   Handles: scroll progress, nav state, zoom-in animations via
   IntersectionObserver, section dot navigation, mobile menu,
   and contact form UX.
   =================================================================== */

(function () {
  'use strict';

  /* ─── DOM refs ──────────────────────────────────────────────────── */
  const nav          = document.getElementById('site-nav');
  const progressBar  = document.getElementById('scroll-progress');
  const navToggle    = document.getElementById('nav-toggle');
  const navLinks     = document.getElementById('nav-links');
  const sectionDots  = document.querySelectorAll('.dot');
  const zoomSections = document.querySelectorAll('.zoom-section');
  const allNavLinks  = document.querySelectorAll('a.nav-link');
  const contactForm  = document.getElementById('contact-form');

  /* ─── Scroll Progress + Nav Styling ────────────────────────────── */
  function onScroll () {
    const scrollTop    = window.scrollY;
    const docHeight    = document.documentElement.scrollHeight - window.innerHeight;
    const scrollPct    = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;

    progressBar.style.width = scrollPct.toFixed(1) + '%';

    if (scrollTop > 40) {
      nav.classList.add('scrolled');
    } else {
      nav.classList.remove('scrolled');
    }
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll(); // run once on load

  /* ─── Zoom-In via IntersectionObserver ─────────────────────────── */
  const sectionObserver = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in-view');
          updateActiveDot(entry.target.dataset.section);
          updateActiveNavLink(entry.target.dataset.section);
        }
      });
    },
    {
      threshold:  0.18,   // trigger when 18% of section is visible
      rootMargin: '-60px 0px -60px 0px'
    }
  );

  zoomSections.forEach(function (section) {
    sectionObserver.observe(section);
  });

  /* ─── Section Dot Navigation ────────────────────────────────────── */
  function updateActiveDot (sectionId) {
    sectionDots.forEach(function (dot) {
      dot.classList.toggle('active', dot.dataset.target === sectionId);
    });
  }

  sectionDots.forEach(function (dot) {
    dot.addEventListener('click', function () {
      const target = document.getElementById(dot.dataset.target);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  /* ─── Active Nav Link highlighting ─────────────────────────────── */
  function updateActiveNavLink (sectionId) {
    allNavLinks.forEach(function (link) {
      const href = link.getAttribute('href');
      link.classList.toggle('active-section', href === '#' + sectionId);
    });
  }

  /* ─── Mobile Menu ───────────────────────────────────────────────── */
  navToggle.addEventListener('click', function () {
    const isOpen = navLinks.classList.toggle('open');
    navToggle.classList.toggle('open', isOpen);
    navToggle.setAttribute('aria-expanded', String(isOpen));
    document.body.style.overflow = isOpen ? 'hidden' : '';
  });

  // Close on link click
  navLinks.querySelectorAll('a').forEach(function (link) {
    link.addEventListener('click', function () {
      navLinks.classList.remove('open');
      navToggle.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    });
  });

  // Close on outside click
  document.addEventListener('click', function (e) {
    if (navLinks.classList.contains('open') &&
        !nav.contains(e.target)) {
      navLinks.classList.remove('open');
      navToggle.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    }
  });

  /* ─── Smooth Anchor Scrolling ───────────────────────────────────── */
  document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
    anchor.addEventListener('click', function (e) {
      const href = anchor.getAttribute('href');
      if (href === '#') return;
      const target = document.querySelector(href);
      if (target) {
        e.preventDefault();
        const navHeight = nav.offsetHeight;
        const top = target.getBoundingClientRect().top + window.scrollY - navHeight;
        window.scrollTo({ top: top, behavior: 'smooth' });
      }
    });
  });

  /* ─── Contact Form ──────────────────────────────────────────────── */
  if (contactForm) {
    contactForm.addEventListener('submit', function (e) {
      e.preventDefault();

      const btn    = contactForm.querySelector('button[type="submit"]');
      const note   = contactForm.querySelector('.form-note');
      const fields = contactForm.querySelectorAll('[required]');
      let   valid  = true;

      // Simple inline validation
      fields.forEach(function (field) {
        field.style.borderColor = '';
        if (!field.value.trim()) {
          field.style.borderColor = '#ff5f56';
          valid = false;
        }
      });

      if (!valid) {
        note.textContent = 'Please fill in all required fields.';
        note.style.color = '#ff5f56';
        return;
      }

      // Simulate submission (replace with real endpoint)
      btn.disabled     = true;
      btn.textContent  = 'Sending…';
      note.textContent = '';

      setTimeout(function () {
        btn.textContent  = 'Message Sent ✓';
        btn.style.background = '#28c840';
        note.textContent = 'Thank you! We\'ll be in touch within 1 business day.';
        note.style.color = 'rgba(255,255,255,0.45)';
        contactForm.reset();

        setTimeout(function () {
          btn.textContent      = 'Send Message';
          btn.style.background = '';
          btn.disabled         = false;
        }, 4000);
      }, 1200);
    });
  }

  /* ─── Stat counter animation (About section) ────────────────────── */
  function animateCounter (el, from, to, duration) {
    const start   = performance.now();
    const range   = to - from;
    const suffix  = el.querySelector('span') ? el.querySelector('span').textContent : '';

    function tick (now) {
      const elapsed  = now - start;
      const progress = Math.min(elapsed / duration, 1);
      // ease-out cubic
      const eased    = 1 - Math.pow(1 - progress, 3);
      const value    = Math.round(from + range * eased);
      el.childNodes[0].textContent = value;
      if (progress < 1) requestAnimationFrame(tick);
    }

    requestAnimationFrame(tick);
  }

  const aboutSection = document.getElementById('about');
  let statsAnimated  = false;

  const statObserver = new IntersectionObserver(
    function (entries) {
      if (entries[0].isIntersecting && !statsAnimated) {
        statsAnimated = true;
        document.querySelectorAll('.stat-num').forEach(function (el) {
          const text = el.textContent.trim();
          const to   = parseInt(text, 10);
          animateCounter(el, 0, to, 1400);
        });
      }
    },
    { threshold: 0.4 }
  );

  if (aboutSection) statObserver.observe(aboutSection);

  /* ─── Keyboard nav for dots ─────────────────────────────────────── */
  sectionDots.forEach(function (dot, idx) {
    dot.setAttribute('tabindex', '0');
    dot.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        dot.click();
      }
      if (e.key === 'ArrowDown' && sectionDots[idx + 1]) {
        sectionDots[idx + 1].focus();
        sectionDots[idx + 1].click();
      }
      if (e.key === 'ArrowUp' && sectionDots[idx - 1]) {
        sectionDots[idx - 1].focus();
        sectionDots[idx - 1].click();
      }
    });
  });

})();
