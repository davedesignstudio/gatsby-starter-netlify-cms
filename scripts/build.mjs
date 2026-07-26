import { copyFile, mkdir, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const output = join(root, "public");
const assets = ["index.html", "game.css", "game.js", "manifest.webmanifest"];

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });

await Promise.all(
  assets.map((asset) => copyFile(join(root, asset), join(output, asset))),
);

console.log(`Built Aisle Rush → public/ (${assets.length} files)`);
