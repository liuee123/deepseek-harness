/** Assemble the container's CLI and browser providers from the built workspace. */
import { existsSync, mkdirSync, readFileSync, realpathSync, symlinkSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const browserPackages = [
  '@deepseek-ai/dsh-browser-use',
  '@deepseek-ai/dsh-experimental-browser-use-playwright-mcp',
]

/** Add the container's local browser providers to the CLI deployment dependencies. */
export function withBrowserDependencies(manifest) {
  return {
    ...manifest,
    dependencies: {
      ...manifest.dependencies,
      ...Object.fromEntries(browserPackages.map(name => [name, 'workspace:*'])),
    },
  }
}

async function main() {
  if (process.env.DSH_DOCKER_BUILD !== '1' || process.platform !== 'linux') {
    throw new Error('docker/deploy.mjs runs only inside the Linux Docker builder')
  }
  const root = process.cwd()
  const manifestPath = resolve(root, 'apps/cli/package.json')
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  writeFileSync(manifestPath, `${JSON.stringify(withBrowserDependencies(manifest), null, 2)}\n`)
  for (const name of browserPackages) {
    const link = resolve(root, 'apps/cli/node_modules', name)
    mkdirSync(resolve(link, '..'), { recursive: true })
    if (!existsSync(link)) symlinkSync(realpathSync(resolve(root, 'node_modules', name)), link, 'dir')
  }

  const { pnpmInvocation, restoreLegacyHoists, verifyStagedDependencies } =
    await import('../scripts/executable-packaging.ts')
  const { materializeStagedLinks, deduplicateStagedWorkspacePackages } =
    await import('../scripts/build-exe-for-python-sdk-staging.ts')
  function runPnpm(args) {
    const [command, argv] = pnpmInvocation(args)
    const result = spawnSync(command, argv, { cwd: root, stdio: 'inherit' })
    if (result.error) throw result.error
    if (result.status !== 0) throw new Error(`container deployment failed: pnpm exited ${result.status}`)
  }

  const destination = '/opt/dsh-runtime'
  // Match the repository's SSH carrier deployment for its non-injected workspace.
  // All dependencies must already be available from the initial locked install.
  runPnpm([
    '--filter', '@deepseek-ai/dsh', 'deploy', '--legacy', '--prod', '--offline',
    '--config.allow-unused-patches=true',
    '--config.node-linker=hoisted',
    '--config.auto-install-peers=false',
    `--config.pnpmfile=${resolve(root, 'scripts/python-runtime-deploy.pnpmfile.mjs')}`,
    '--config.link-workspace-packages=true',
    '--config.hoist-workspace-packages=false',
    destination,
  ])
  await restoreLegacyHoists(destination, resolve(root, 'apps/cli/node_modules'))
  await materializeStagedLinks(destination)
  await deduplicateStagedWorkspacePackages(destination, root)
  await verifyStagedDependencies(destination)
}

if (import.meta.main) await main()
