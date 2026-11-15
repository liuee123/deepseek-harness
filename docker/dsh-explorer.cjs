#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { once } = require('node:events');
const { fileURLToPath } = require('node:url');

function resolveTarget(args) {
  let target;
  if (args.length === 2 && args[0].toLowerCase() === '/select,') {
    target = args[1];
  } else if (args.length === 1) {
    target = args[0].replace(/^\/select,/i, '');
  }
  if (!target) throw new Error('expected one local file or directory');
  return path.resolve(/^file:/i.test(target) ? fileURLToPath(target) : target);
}

async function openTarget(args) {
  const target = resolveTarget(args);
  fs.accessSync(target, fs.constants.R_OK);
  fs.accessSync('/usr/bin/wish', fs.constants.X_OK);
  fs.accessSync('/usr/local/bin/dsh-editor.tcl', fs.constants.R_OK);

  const display = process.env.DISPLAY || ':99';
  const ready = spawnSync('xdpyinfo', ['-display', display], {
    stdio: 'ignore', timeout: 2000,
  });
  if (ready.error) throw ready.error;
  if (ready.status !== 0) {
    throw new Error(`desktop display ${display} is unavailable; enable the container desktop`);
  }

  // The RPC must finish while the editor remains open. Keep editor diagnostics
  // in the writable tmpfs instead of holding the RPC's output pipes open.
  const log = fs.openSync('/tmp/dsh-editor.log', 'a', 0o600);
  try {
    const editor = spawn('/usr/bin/wish', ['/usr/local/bin/dsh-editor.tcl', target], {
      env: { ...process.env, DISPLAY: display },
      detached: true,
      stdio: ['ignore', log, log],
    });
    await once(editor, 'spawn');
    editor.unref();
  } finally {
    fs.closeSync(log);
  }
}

module.exports = { resolveTarget };
if (require.main === module) {
  openTarget(process.argv.slice(2)).catch(error => {
    console.error(`explorer.exe: ${error.message}`);
    process.exitCode = 1;
  });
}
