import assert from 'node:assert/strict'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { withBrowserDependencies } from './deploy.mjs'
import { composeEnvironment } from './compose.mjs'

test('container deployment keeps CLI dependencies and selects local browser providers', () => {
  const manifest = { name: '@deepseek-ai/dsh', dependencies: { commander: '^15.0.0' } }
  const result = withBrowserDependencies(manifest)
  assert.deepEqual(result.dependencies, {
    commander: '^15.0.0',
    '@deepseek-ai/dsh-browser-use': 'workspace:*',
    '@deepseek-ai/dsh-experimental-browser-use-playwright-mcp': 'workspace:*',
  })
  assert.deepEqual(manifest.dependencies, { commander: '^15.0.0' })
})

test('Compose takes its version from source and preserves runtime settings', t => {
  const root = mkdtempSync(join(tmpdir(), 'dsh-compose-'))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  writeFileSync(join(root, 'package.json'), JSON.stringify({ version: '0.2.2-rc.1' }))
  const environment = { DSH_CLIENT_COMMIT_HASH: '1234567', DSH_PORT: '3088' }
  const result = composeEnvironment(root, environment)
  assert.equal(result.DSH_SOURCE_VERSION, '0.2.2-rc.1')
  assert.equal(result.DSH_PORT, '3088')
  assert.equal(environment.DSH_SOURCE_VERSION, undefined)
  assert.throws(() => composeEnvironment(root, { DSH_CLIENT_COMMIT_HASH: 'unknown' }))
})
