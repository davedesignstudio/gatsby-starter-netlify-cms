import { cp, mkdir, rm } from "node:fs/promises";
import { dirname } from "node:path";

const files = [
  "index.html",
  "manifest.webmanifest",
  "sw.js",
  "assets/cart-dash-icon.svg",
  "css/game.css",
  "js/game.js",
  "js/game-core.js",
];

await rm("public", { recursive: true, force: true });
await mkdir("public", { recursive: true });
await Promise.all(
  files.map(async (file) => {
    const destination = `public/${file}`;
    await mkdir(dirname(destination), { recursive: true });
    await cp(file, destination);
  }),
);

console.log("Cart Dash built in public/");
