import { existsSync, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const html = readFileSync(join(root, 'index.html'), 'utf8')
const gameScript = readFileSync(join(root, 'js/game.js'), 'utf8')
const problems = []

const assetPattern = /(?:src|href)="([^"]+)"/g
for (const match of html.matchAll(assetPattern)) {
  const asset = match[1]
  if (/^(?:https?:|#|data:)/.test(asset)) continue
  const cleanAsset = asset.split(/[?#]/)[0]
  if (!existsSync(join(root, cleanAsset))) problems.push(`Missing asset: ${cleanAsset}`)
}

const requiredIds = [...gameScript.matchAll(/getElementById\('([^']+)'\)/g)].map((match) => match[1])
for (const id of new Set(requiredIds)) {
  if (!html.includes(`id="${id}"`)) problems.push(`Missing DOM element: #${id}`)
}

for (const file of ['js/game-core.js', 'js/game.js']) {
  const check = spawnSync(process.execPath, ['--check', join(root, file)], { encoding: 'utf8' })
  if (check.status !== 0) problems.push(`${file} has invalid JavaScript:\n${check.stderr.trim()}`)
}

if (problems.length) {
  console.error(problems.join('\n'))
  process.exit(1)
}

console.log(`Cart Dash validated: ${new Set(requiredIds).size} UI hooks and all local assets are present.`)
