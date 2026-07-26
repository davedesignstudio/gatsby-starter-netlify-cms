const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const out = path.join(root, "public");

const files = [
  "index.html",
  "services.html",
  "about.html",
  "contact.html",
  "portfolio.html",
  "siteicon.png",
  "thumbnail.jpg",
  "preview.jpg",
];

const dirs = ["css", "js", "images"];

function rmrf(target) {
  fs.rmSync(target, { recursive: true, force: true });
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(from, to);
    } else {
      fs.copyFileSync(from, to);
    }
  }
}

rmrf(out);
fs.mkdirSync(out, { recursive: true });

for (const file of files) {
  const from = path.join(root, file);
  if (fs.existsSync(from)) {
    fs.copyFileSync(from, path.join(out, file));
  }
}

for (const dir of dirs) {
  const from = path.join(root, dir);
  if (fs.existsSync(from)) {
    copyDir(from, path.join(out, dir));
  }
}

console.log("Built static site to public/");
