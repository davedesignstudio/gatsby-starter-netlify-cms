"use strict";

const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

const CHROME = process.env.CHROME_BIN || "google-chrome";
const PORT = 9224;
const GAME_URL = process.env.GAME_URL || "http://127.0.0.1:8000/";
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "cart-rally-chrome-"));
const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

const chrome = spawn(
  CHROME,
  [
    "--headless=new",
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--hide-scrollbars",
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${profile}`,
    "--window-size=1280,720",
    GAME_URL,
  ],
  { stdio: ["ignore", "ignore", "pipe"] }
);

let stderr = "";
chrome.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

async function getPageTarget() {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${PORT}/json`);
      const targets = await response.json();
      const page = targets.find((target) => target.type === "page");
      if (page && page.webSocketDebuggerUrl) return page;
    } catch (_) {
      // Chrome can take a moment to expose its debugging endpoint.
    }
    await delay(100);
  }
  throw new Error(`Chrome debugging endpoint did not start.\n${stderr}`);
}

async function run() {
  const target = await getPageTarget();
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  const pending = new Map();
  const errors = [];
  let nextId = 1;

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
      return;
    }
    if (message.method === "Runtime.exceptionThrown") {
      errors.push(message.params.exceptionDetails.text);
    }
    if (message.method === "Log.entryAdded" && message.params.entry.level === "error") {
      errors.push(message.params.entry.text);
    }
  });

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  const command = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = nextId;
      nextId += 1;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });

  const evaluate = async (expression) => {
    const response = await command("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    return response.result.value;
  };

  await command("Runtime.enable");
  await command("Log.enable");
  await command("Page.enable");

  for (let attempt = 0; attempt < 40; attempt += 1) {
    if (await evaluate("document.readyState === 'complete'")) break;
    await delay(100);
  }

  assert.equal(await evaluate("document.title"), "Carts After Dark — The Community Cup");
  assert.equal(await evaluate("typeof window.CartRally"), "object");
  assert.equal(await evaluate("Boolean(document.querySelector('#game-canvas'))"), true);

  await evaluate("document.querySelector('#meet-racers-button').click()");
  await delay(200);
  assert.equal(await evaluate("document.querySelector('#select-screen').classList.contains('is-active')"), true);

  await evaluate("document.querySelector('[data-racer=\"2\"]').click()");
  assert.equal(await evaluate("document.querySelector('[data-racer=\"2\"]').getAttribute('aria-checked')"), "true");

  await evaluate("document.querySelector('#start-race-button').click()");
  await delay(4300);
  assert.equal(await evaluate("document.querySelector('#hud').classList.contains('is-hidden')"), false);
  assert.equal(await evaluate("document.querySelector('#countdown').classList.contains('is-hidden')"), true);

  await evaluate("window.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyW' }))");
  await delay(1100);
  await evaluate("window.dispatchEvent(new KeyboardEvent('keyup', { code: 'KeyW' }))");
  assert.ok(Number(await evaluate("document.querySelector('#speed-value').textContent")) > 0, "Player cart did not accelerate");

  await evaluate("document.querySelector('#pause-button').click()");
  await delay(100);
  assert.equal(await evaluate("document.querySelector('#pause-screen').classList.contains('is-active')"), true);

  const screenshot = await command("Page.captureScreenshot", { format: "png" });
  fs.writeFileSync(path.join(os.tmpdir(), "cart-game-racing.png"), Buffer.from(screenshot.data, "base64"));

  assert.deepEqual(errors, [], `Browser reported runtime errors: ${errors.join("; ")}`);
  socket.close();
  console.log("Browser smoke test passed: menu, racer selection, countdown, acceleration, and pause all work.");
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => {
    chrome.kill("SIGTERM");
    fs.rmSync(profile, { recursive: true, force: true });
  });
