import { cp, mkdir, readFile, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const output = join(root, "public");
const files = [
  "index.html",
  "manifest.webmanifest",
  "icon.svg",
  "sw.js",
  "css/game.css",
  "js/game.js",
  "js/game-core.js",
];

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });

for (const file of files) {
  const source = join(root, file);
  const destination = join(output, file);
  await mkdir(dirname(destination), { recursive: true });
  await cp(source, destination);
}

const html = await readFile(join(output, "index.html"), "utf8");
if (!html.includes('id="game"') || !html.includes("js/game.js")) {
  throw new Error("Built page is missing the game canvas or entry script.");
}

console.log(`Built Aisle Rally (${files.length} assets) → public/`);
