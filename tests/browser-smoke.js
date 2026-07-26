const assert = require("node:assert/strict");

const DEVTOOLS_URL = process.env.DEVTOOLS_URL || "http://127.0.0.1:9223";
const APP_URL = process.env.APP_URL || "http://127.0.0.1:4173/";
const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function getGameTab() {
  const response = await fetch(`${DEVTOOLS_URL}/json`);
  const tabs = await response.json();
  return tabs.find((tab) => tab.type === "page" && tab.url.startsWith(APP_URL));
}

async function run() {
  const tab = await getGameTab();
  assert(tab, `No game tab found for ${APP_URL}`);

  const socket = new WebSocket(tab.webSocketDebuggerUrl);
  const pending = new Map();
  const browserErrors = [];
  let commandId = 0;

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
    }
    if (message.method === "Runtime.exceptionThrown") {
      browserErrors.push(message.params.exceptionDetails.text);
    }
    if (message.method === "Log.entryAdded" && message.params.entry.level === "error") {
      browserErrors.push(message.params.entry.text);
    }
  });

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  function command(method, params = {}) {
    commandId += 1;
    return new Promise((resolve, reject) => {
      pending.set(commandId, { resolve, reject });
      socket.send(JSON.stringify({ id: commandId, method, params }));
    });
  }

  async function evaluate(expression) {
    const result = await command("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true
    });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  }

  await command("Runtime.enable");
  await command("Log.enable");
  await command("Page.enable");
  await command("Page.reload", { ignoreCache: true });
  await wait(500);

  const initial = await evaluate(`({
    title: document.title,
    menuVisible: !document.querySelector("#menuScreen").classList.contains("hidden"),
    raceLabel: document.querySelector("#raceButton").textContent.trim()
  })`);
  assert.equal(initial.title, "Cart Rush — After Hours");
  assert.equal(initial.menuVisible, true);
  assert.match(initial.raceLabel, /Race now/i);

  await evaluate(`document.querySelector("#raceButton").click()`);
  const selectionVisible = await evaluate(`!document.querySelector("#selectScreen").classList.contains("hidden")`);
  assert.equal(selectionVisible, true);

  await evaluate(`document.querySelector('[data-racer="gus"]').click()`);
  const selectedRacer = await evaluate(`document.querySelector(".racer-card.selected").dataset.racer`);
  assert.equal(selectedRacer, "gus");

  await evaluate(`document.querySelector("#startButton").click()`);
  await wait(4200);

  const started = await evaluate(`({
    gameVisible: !document.querySelector("#gameScreen").classList.contains("hidden"),
    canvasWidth: document.querySelector("#gameCanvas").width,
    time: document.querySelector("#timeValue").textContent,
    lap: document.querySelector("#lapValue").textContent
  })`);
  assert.equal(started.gameVisible, true);
  assert(started.canvasWidth > 0, "Canvas should have a rendered width");
  assert.notEqual(started.time, "00:00.0");
  assert.equal(started.lap, "1");

  await command("Input.dispatchKeyEvent", { type: "keyDown", key: "ArrowRight", code: "ArrowRight" });
  await command("Input.dispatchKeyEvent", { type: "keyDown", key: " ", code: "Space" });
  await wait(500);
  await command("Input.dispatchKeyEvent", { type: "keyUp", key: "ArrowRight", code: "ArrowRight" });
  await command("Input.dispatchKeyEvent", { type: "keyUp", key: " ", code: "Space" });

  await evaluate(`document.querySelector("#pauseButton").click()`);
  const paused = await evaluate(`document.querySelector("#pauseButton").classList.contains("paused")`);
  assert.equal(paused, true);
  await evaluate(`document.querySelector("#pauseButton").click()`);

  assert.deepEqual(browserErrors, [], `Browser errors: ${browserErrors.join("; ")}`);
  socket.close();
  console.log("Browser smoke test passed: menu, selection, race, controls, and pause.");
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
