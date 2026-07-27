import { Game } from './game.js';
import { isMobile } from './platform.js';

const canvas = document.getElementById('game');
const game = new Game(canvas);

document.getElementById('loading')?.remove();
game.start();

function unlockAudio() {
  game.audio.resume();
}

document.body.addEventListener('touchstart', unlockAudio, { once: true, passive: true });
document.body.addEventListener('click', unlockAudio, { once: true });

if (isMobile) {
  const hint = document.getElementById('rotate-hint');
  const dismiss = document.getElementById('rotate-dismiss');
  const dismissed = sessionStorage.getItem('cartkart-rotate-dismissed') === '1';

  function updateRotateHint() {
    const portrait = window.innerHeight > window.innerWidth;
    if (hint) hint.hidden = !portrait || dismissed;
  }

  dismiss?.addEventListener('click', () => {
    sessionStorage.setItem('cartkart-rotate-dismissed', '1');
    if (hint) hint.hidden = true;
  });

  window.addEventListener('resize', updateRotateHint);
  window.addEventListener('orientationchange', updateRotateHint);
  updateRotateHint();
}
