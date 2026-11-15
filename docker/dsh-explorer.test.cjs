'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');
const { setTimeout: delay } = require('node:timers/promises');
const { test } = require('node:test');
const { resolveTarget } = require(process.env.DSH_EXPLORER_MODULE || './dsh-explorer.cjs');

test('Explorer opener preserves literal paths and decodes file URLs', () => {
  const target = path.resolve("配置 folder", "agent's config.yml");
  assert.equal(resolveTarget([target]), target);
  assert.equal(resolveTarget([pathToFileURL(target).href]), target);
});

test('Explorer reveal arguments resolve to the selected file', () => {
  const target = path.resolve('configuration with spaces.yml');
  assert.equal(resolveTarget(['/select,', target]), target);
  assert.equal(resolveTarget([`/select,${pathToFileURL(target).href}`]), target);
});

test('Explorer opener rejects missing or ambiguous targets', () => {
  for (const args of [[], [''], ['/select,'], ['first', 'second']]) {
    assert.throws(() => resolveTarget(args));
  }
});

// Run inside the image so this covers PATH lookup, executable permissions,
// Tk dependencies and the real editor, rather than just parsing arguments.
test('spawn explorer.exe opens the configuration editor on the virtual desktop', {
  skip: process.env.DSH_EXPLORER_SMOKE !== '1',
  timeout: 15000,
}, async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'dsh-explorer-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  t.after(() => fs.rmSync('/tmp/dsh-editor.log', { force: true }));
  const target = path.join(directory, "config file's settings.yml");
  fs.writeFileSync(target, 'test: true\n');
  const display = ':199';
  const env = { ...process.env, DISPLAY: display };
  const xvfb = spawn('Xvfb', [display, '-screen', '0', '800x600x24', '-ac', '-nolisten', 'tcp'], {
    stdio: 'ignore',
  });
  let displayError;
  xvfb.on('error', error => { displayError = error; });
  t.after(async () => {
    if (xvfb.pid && xvfb.exitCode === null && xvfb.signalCode === null) {
      const closed = new Promise(resolve => xvfb.once('close', resolve));
      xvfb.kill();
      await closed;
    }
  });

  let ready = false;
  for (let attempt = 0; attempt < 50; attempt++) {
    if (displayError) throw displayError;
    if (spawnSync('xdpyinfo', ['-display', display], { env, stdio: 'ignore' }).status === 0) {
      ready = true;
      break;
    }
    await delay(100);
  }
  assert.ok(ready, 'virtual display must become ready');

  const opened = spawnSync('explorer.exe', [pathToFileURL(target).href], {
    env, encoding: 'utf8', timeout: 3000,
  });
  assert.ifError(opened.error);
  assert.equal(opened.status, 0, opened.stderr);
  for (let attempt = 0; attempt < 50; attempt++) {
    const windows = spawnSync('xwininfo', ['-root', '-tree'], { env, encoding: 'utf8' });
    if (windows.stdout?.includes(`Edit: ${target}`)) return;
    await delay(100);
  }
  const log = fs.existsSync('/tmp/dsh-editor.log') ? fs.readFileSync('/tmp/dsh-editor.log', 'utf8') : '';
  assert.fail(`configuration editor window did not appear: ${log}`);
});
