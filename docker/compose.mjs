/** Run this checkout's Compose project with its source version and Git revision. */
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawnSync } from 'node:child_process'

/** Resolve source metadata without changing the caller's environment. */
export function composeEnvironment(root, environment = process.env) {
  const manifest = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'))
  const revision = environment.DSH_CLIENT_COMMIT_HASH || execFileSync('git', [
    '-c', `safe.directory=${root}`, 'rev-parse', 'HEAD',
  ], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
  if (!/^[0-9a-f]{7,40}$/iu.test(revision)) {
    throw new Error('DSH_CLIENT_COMMIT_HASH must contain a 7–40 character Git commit hash')
  }
  return {
    ...environment,
    DSH_CLIENT_COMMIT_HASH: revision,
    DSH_SOURCE_VERSION: manifest.version,
  }
}

function main() {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
  const result = spawnSync('docker', ['compose', '--file', resolve(root, 'compose.yaml'), ...process.argv.slice(2)], {
    cwd: root,
    env: composeEnvironment(root),
    stdio: 'inherit',
  })
  if (result.error) throw result.error
  process.exitCode = result.status ?? 1
}

if (import.meta.main) {
  try {
    main()
  } catch (error) {
    console.error(`Docker: ${error.message}`)
    process.exitCode = 1
  }
}
