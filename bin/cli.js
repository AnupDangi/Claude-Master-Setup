#!/usr/bin/env node
'use strict';
/**
 * Scaffolds the Claude Master Setup harness into a target directory, then
 * runs scripts/install.sh (the same idempotent setup a manual git-clone
 * install uses — this script does not duplicate that logic).
 *
 * Usage:
 *   npx github:AnupDangi/Claude-Master-Setup [target-dir]
 *   npx github:AnupDangi/Claude-Master-Setup            # installs into cwd
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const PKG_ROOT = path.resolve(__dirname, '..');
const COPY_ITEMS = [
  '.claude',
  'docs',
  'scripts',
  'CLAUDE.md',
  'MASTER-PROMPT.md',
  '.env.example',
  '.gitignore',
];
// Runtime/local state and editor-local files never get copied into a new install.
const SKIP_RELATIVE = new Set(['.claude/state', '.cursor', '.git', 'node_modules']);

function copyRecursive(src, dest) {
  const rel = path.relative(PKG_ROOT, src);
  if (SKIP_RELATIVE.has(rel)) return;

  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      copyRecursive(path.join(src, entry), path.join(dest, entry));
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

function main() {
  if (process.platform === 'win32') {
    console.error(
      'This harness relies on bash scripts and hooks and has only been built for ' +
        'macOS/Linux (or WSL). Running it under native Windows is untested.'
    );
  }

  const target = process.argv[2] || '.';
  const dest = path.resolve(process.cwd(), target);
  fs.mkdirSync(dest, { recursive: true });

  console.log(`Claude Master Setup — installing into ${dest}\n`);

  for (const item of COPY_ITEMS) {
    const srcPath = path.join(PKG_ROOT, item);
    if (!fs.existsSync(srcPath)) continue;
    const destPath = path.join(dest, item);
    if (fs.existsSync(destPath)) {
      console.log(`  skip (already exists): ${item}`);
      continue;
    }
    copyRecursive(srcPath, destPath);
    console.log(`  + ${item}`);
  }

  console.log('\nRunning scripts/install.sh...\n');
  const result = spawnSync('bash', ['scripts/install.sh'], {
    cwd: dest,
    stdio: 'inherit',
  });
  if (result.status !== 0) {
    console.error('\nscripts/install.sh failed — see output above.');
    process.exitCode = result.status || 1;
    return;
  }

  console.log('\nNext steps:');
  if (target !== '.') console.log(`  cd ${target}`);
  console.log('  add PRD.md and PTR.md to the repo root');
  console.log('  claude');
  console.log('  /bootstrap   then   /loop');
}

main();
