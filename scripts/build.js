const { cp, mkdir, rm } = require('node:fs/promises')
const { join } = require('node:path')

const root = join(__dirname, '..')
const output = join(root, 'public')
const files = ['index.html', 'manifest.webmanifest', 'service-worker.js']
const directories = ['css', 'js', 'icons']

async function build() {
  await rm(output, { recursive: true, force: true })
  await mkdir(output, { recursive: true })
  await Promise.all([
    ...files.map((file) => cp(join(root, file), join(output, file))),
    ...directories.map((directory) => cp(join(root, directory), join(output, directory), { recursive: true })),
  ])
  console.log('Cart Crashers built to public/')
}

build().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
