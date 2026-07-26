"use strict";

var fs = require("fs");
var path = require("path");

var root = path.resolve(__dirname, "..");
var output = path.join(root, "public");
var files = [
  "index.html",
  "manifest.webmanifest",
  "service-worker.js",
  "css/cart-racer.css",
  "js/game-core.js",
  "js/cart-racer.js",
  "images/cart-racer-icon.svg",
];

fs.rmSync(output, { recursive: true, force: true });

files.forEach(function (relativePath) {
  var source = path.join(root, relativePath);
  var destination = path.join(output, relativePath);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
});

console.log("Built Aisle Rush to public/ (" + files.length + " files)");
