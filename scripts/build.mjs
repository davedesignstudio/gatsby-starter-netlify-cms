import { cp, mkdir, rm } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const output = resolve(root, "public");
const assets = ["index.html", "manifest.webmanifest", "css/cart-rush.css", "js/race-core.js", "js/cart-rush.js"];

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });

for (const asset of assets) {
  const source = resolve(root, asset);
  const destination = resolve(output, asset);
  await mkdir(resolve(destination, ".."), { recursive: true });
  await cp(source, destination);
}

console.log(`Built Aisle Drifters to ${output}`);
