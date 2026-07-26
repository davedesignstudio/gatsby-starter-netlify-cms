#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = path.join(__dirname, '..');
let passed = 0;
let failed = 0;

function ok(message) {
  passed += 1;
  console.log(`  ✓ ${message}`);
}

function fail(message) {
  failed += 1;
  console.error(`  ✗ ${message}`);
}

function read(file) {
  return fs.readFileSync(path.join(root, file), 'utf8');
}

function exists(file) {
  return fs.existsSync(path.join(root, file));
}

console.log('Running site smoke tests...\n');

const requiredFiles = [
  '_layouts/zoom.html',
  'css/dphilhower-zoom.css',
  'javascripts/dphilhower-zoom.js',
  'index.html',
];

requiredFiles.forEach((file) => {
  if (exists(file)) ok(`found ${file}`);
  else fail(`missing ${file}`);
});

try {
  execSync('node --check javascripts/dphilhower-zoom.js', { cwd: root, stdio: 'pipe' });
  ok('javascript syntax valid');
} catch {
  fail('javascript syntax invalid');
}

const css = read('css/dphilhower-zoom.css');
if (css.split('{').length === css.split('}').length) {
  ok('css braces balanced');
} else {
  fail('css braces unbalanced');
}

const colorTokens = [
  '--bg-deep: #000000',
  '--text-primary: #ffffff',
  '--accent: #1a4d8f',
  '--stroke: rgba(114, 47, 55, 0.2)',
];

colorTokens.forEach((token) => {
  if (css.includes(token)) ok(`color token ${token.split(':')[0]}`);
  else fail(`missing color token ${token.split(':')[0]}`);
});

const index = read('index.html');
if (index.includes('layout: zoom')) ok('index uses zoom layout');
else fail('index does not use zoom layout');

const services = ['Logo Design', 'Poster Design', 'Print Media', 'Website Design'];
services.forEach((service) => {
  if (index.includes(service)) ok(`service listed: ${service}`);
  else fail(`missing service: ${service}`);
});

const images = [...index.matchAll(/src="([^"]+)"/g)].map((match) => match[1]);
const missingImages = images.filter((image) => !exists(image));
if (missingImages.length === 0) ok(`portfolio images present (${images.length})`);
else fail(`missing images: ${missingImages.join(', ')}`);

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
