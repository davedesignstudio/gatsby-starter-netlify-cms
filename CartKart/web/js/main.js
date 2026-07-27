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

  function updateRotateHint() {
    const portrait = window.innerHeight > window.innerWidth;
    if (hint) hint.hidden = !portrait;
  }

  window.addEventListener('resize', updateRotateHint);
  window.addEventListener('orientationchange', updateRotateHint);
  updateRotateHint();
}
