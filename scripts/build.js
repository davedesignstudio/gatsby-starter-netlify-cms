const { cpSync, existsSync, mkdirSync, rmSync } = require("node:fs");
const { join } = require("node:path");

const root = join(__dirname, "..");
const output = join(root, "public");
const files = ["index.html", "siteicon.png"];
const directories = ["css", "js", "images"];

rmSync(output, { recursive: true, force: true });
mkdirSync(output, { recursive: true });

for (const file of files) {
  const source = join(root, file);
  if (!existsSync(source)) throw new Error(`Missing build input: ${file}`);
  cpSync(source, join(output, file));
}

for (const directory of directories) {
  const source = join(root, directory);
  if (!existsSync(source)) throw new Error(`Missing build input: ${directory}`);
  cpSync(source, join(output, directory), { recursive: true });
}

console.log(`Built static site in ${output}`);
