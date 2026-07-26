const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const output = path.join(root, "public");
const files = ["index.html", "siteicon.png"];
const directories = ["css", "js", "images", "fonts"];

fs.mkdirSync(output, { recursive: true });

files.forEach((file) => {
  fs.copyFileSync(path.join(root, file), path.join(output, file));
});

directories.forEach((directory) => {
  fs.cpSync(path.join(root, directory), path.join(output, directory), {
    recursive: true,
  });
});

console.log(`Built DPH Studio to ${path.relative(root, output)}/`);
