import { Game } from './game.js';

const canvas = document.getElementById('game');
const game = new Game(canvas);

document.getElementById('loading')?.remove();
game.start();

document.body.addEventListener('click', () => game.audio.resume(), { once: true });
