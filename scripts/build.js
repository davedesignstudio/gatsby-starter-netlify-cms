const { cpSync, copyFileSync, mkdirSync, rmSync } = require("node:fs");
const { join } = require("node:path");

const root = join(__dirname, "..");
const output = join(root, "public");

rmSync(output, { recursive: true, force: true });
mkdirSync(join(output, "css"), { recursive: true });
mkdirSync(join(output, "js"), { recursive: true });
mkdirSync(join(output, "images"), { recursive: true });

copyFileSync(join(root, "index.html"), join(output, "index.html"));
copyFileSync(join(root, "manifest.webmanifest"), join(output, "manifest.webmanifest"));
copyFileSync(join(root, "service-worker.js"), join(output, "service-worker.js"));
copyFileSync(join(root, "css", "cart-dash.css"), join(output, "css", "cart-dash.css"));
copyFileSync(join(root, "js", "cart-dash.js"), join(output, "js", "cart-dash.js"));
copyFileSync(join(root, "images", "cart-dash-icon.svg"), join(output, "images", "cart-dash-icon.svg"));

console.log("Cart Dash built to public/");
