import { spawn } from 'node:child_process'
import { existsSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const serverPort = 8100 + Math.floor(Math.random() * 300)
const debugPort = serverPort + 500
const chromePath = process.env.CHROME_PATH || [
  '/usr/local/bin/google-chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].find(existsSync)

if (!chromePath) throw new Error('Chrome or Chromium is required for the browser smoke test.')

const server = spawn('python3', ['-m', 'http.server', String(serverPort)], {
  cwd: root,
  stdio: 'ignore',
})
const chrome = spawn(chromePath, [
  '--headless=new',
  '--no-sandbox',
  '--disable-gpu',
  '--hide-scrollbars',
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=/tmp/cart-dash-chrome-${process.pid}`,
  '--window-size=390,844',
  `http://127.0.0.1:${serverPort}/`,
], { stdio: 'ignore' })

const wait = (duration) => new Promise((resolveWait) => setTimeout(resolveWait, duration))
const consoleErrors = []

async function retry(callback, attempts = 50) {
  let lastError
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await callback()
    } catch (error) {
      lastError = error
      await wait(100)
    }
  }
  throw lastError
}

try {
  await retry(async function () {
    const response = await fetch(`http://127.0.0.1:${serverPort}/`)
    if (!response.ok) throw new Error(`Server returned ${response.status}`)
  })

  const page = await retry(async function () {
    const response = await fetch(`http://127.0.0.1:${debugPort}/json/list`)
    const pages = await response.json()
    const match = pages.find((candidate) => candidate.type === 'page')
    if (!match) throw new Error('No browser page target available')
    return match
  })

  const socket = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((resolveSocket, rejectSocket) => {
    socket.addEventListener('open', resolveSocket, { once: true })
    socket.addEventListener('error', rejectSocket, { once: true })
  })

  let messageId = 0
  const pending = new Map()
  socket.addEventListener('message', function (event) {
    const message = JSON.parse(event.data)
    if (message.id && pending.has(message.id)) {
      const handlers = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) handlers.reject(new Error(message.error.message))
      else handlers.resolve(message.result)
    }
    if (message.method === 'Runtime.exceptionThrown') {
      consoleErrors.push(message.params.exceptionDetails.text)
    }
    if (message.method === 'Log.entryAdded' && message.params.entry.level === 'error') {
      consoleErrors.push(message.params.entry.text)
    }
  })

  function send(method, params = {}) {
    const id = messageId += 1
    socket.send(JSON.stringify({ id, method, params }))
    return new Promise((resolveMessage, rejectMessage) => {
      pending.set(id, { resolve: resolveMessage, reject: rejectMessage })
    })
  }

  await send('Page.enable')
  await send('Runtime.enable')
  await send('Log.enable')
  await retry(async function () {
    const result = await send('Runtime.evaluate', {
      expression: 'document.readyState',
      returnByValue: true,
    })
    if (result.result.value !== 'complete') throw new Error('Page is still loading')
  })

  const initial = await send('Runtime.evaluate', {
    expression: `({
      canvasWidth: document.getElementById('gameCanvas').width,
      menuVisible: !document.getElementById('menuScreen').classList.contains('is-hidden'),
      playLabel: document.getElementById('playButton').innerText.trim()
    })`,
    returnByValue: true,
  })
  if (!initial.result.value.menuVisible || initial.result.value.canvasWidth < 300) {
    throw new Error(`Initial game screen did not render: ${JSON.stringify(initial.result.value)}`)
  }

  await send('Runtime.evaluate', {
    expression: `document.getElementById('playButton').click()`,
    userGesture: true,
  })
  await wait(3650)
  await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'ArrowRight', code: 'ArrowRight' })
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'ArrowRight', code: 'ArrowRight' })
  await send('Input.dispatchKeyEvent', { type: 'keyDown', key: ' ', code: 'Space' })
  await wait(650)
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: ' ', code: 'Space' })
  await wait(1100)

  const raceState = await send('Runtime.evaluate', {
    expression: `({
      hudVisible: !document.getElementById('raceHud').classList.contains('is-hidden'),
      controlsVisible: !document.getElementById('touchControls').classList.contains('is-hidden'),
      distance: document.getElementById('distanceValue').textContent,
      boost: document.getElementById('boostFill').style.height,
      canvasPixels: document.getElementById('gameCanvas').width * document.getElementById('gameCanvas').height
    })`,
    returnByValue: true,
  })

  const state = raceState.result.value
  const distance = Number.parseInt(state.distance, 10)
  if (!state.hudVisible || !state.controlsVisible || !Number.isFinite(distance) || distance <= 0) {
    throw new Error(`Race did not start correctly: ${JSON.stringify(state)}`)
  }
  if (consoleErrors.length) throw new Error(`Browser errors:\n${consoleErrors.join('\n')}`)

  if (process.env.SCREENSHOT_PATH) {
    const screenshot = await send('Page.captureScreenshot', { format: 'png', fromSurface: true })
    writeFileSync(resolve(process.env.SCREENSHOT_PATH), Buffer.from(screenshot.data, 'base64'))
  }

  console.log(`Browser smoke test passed at ${state.distance}; boost meter ${state.boost}.`)
  socket.close()
} finally {
  chrome.kill('SIGTERM')
  server.kill('SIGTERM')
}
