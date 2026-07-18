#!/usr/bin/env node
'use strict';
/**
 * Scaffolds the Claude Master Setup harness into a target directory, then
 * runs scripts/install.sh (the same idempotent setup a manual git-clone
 * install uses — this script does not duplicate that logic).
 *
 * Usage:
 *   npx claude-master-setup [target-dir]
 *   npx claude-master-setup@0.1.1 [target-dir]
 *   npx github:AnupDangi/Claude-Master-Setup [target-dir]
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
const SKIP_RELATIVE = new Set([
  '.claude/state',
  '.claude/settings.local.json',
  '.cursor',
  '.git',
  'node_modules',
]);

function printHelp() {
  console.log(`claude-master-setup — scaffold the Claude Code engineering harness

Usage:
  npx claude-master-setup [target-dir]
  npx claude-master-setup@<version> [target-dir]

Arguments:
  target-dir   Directory to scaffold into (default: current directory)

Options:
  -h, --help   Show this help

After install:
  1. Add PRD.md and PTR.md to the project root
  2. Run: claude
  3. Run: /bootstrap   then   /loop
  4. Verify: bash scripts/self-check.sh
`);
}

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
  const arg = process.argv[2];

  if (arg === '-h' || arg === '--help' || arg === 'help') {
    printHelp();
    return;
  }

  if (arg && arg.startsWith('-')) {
    console.error(`Unknown option: ${arg}\n`);
    printHelp();
    process.exitCode = 1;
    return;
  }

  if (process.platform === 'win32') {
    console.error(
      'This harness relies on bash scripts and hooks and has only been built for ' +
        'macOS/Linux (or WSL). Running it under native Windows is untested.'
    );
  }

  const target = arg || '.';
  const dest = path.resolve(process.cwd(), target);
  fs.mkdirSync(dest, { recursive: true });

  console.log(`Claude Master Setup — installing into ${dest}\n`);

  let missing = [];
  for (const item of COPY_ITEMS) {
    const srcPath = path.join(PKG_ROOT, item);
    if (!fs.existsSync(srcPath)) {
      missing.push(item);
      console.log(`  ! missing from package (skipped): ${item}`);
      continue;
    }
    const destPath = path.join(dest, item);
    if (fs.existsSync(destPath)) {
      console.log(`  skip (already exists): ${item}`);
      continue;
    }
    copyRecursive(srcPath, destPath);
    console.log(`  + ${item}`);
  }

  if (missing.includes('.gitignore')) {
    console.error(
      '\nPackage is incomplete: .gitignore was not published. ' +
        'Reinstall a newer version (0.1.1+) or open an issue.'
    );
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

  // install.sh already prints next steps; keep a one-line pointer for npx users.
  if (target !== '.') {
    console.log(`\nScaffold ready. cd ${target} then open Claude Code.`);
  } else {
    console.log('\nScaffold ready. Open Claude Code in this directory.');
  }
}

main();
