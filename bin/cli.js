#!/usr/bin/env node
'use strict';
/**
 * Installs the Claude Master Setup harness into Claude Code
 * (global ~/.claude or local ./.claude) — Forge-style UX.
 *
 * Usage:
 *   npx claude-master-setup              # interactive
 *   npx claude-master-setup --global     # ~/.claude
 *   npx claude-master-setup --local      # ./.claude + project scripts/docs
 *   npx claude-master-setup --scaffold [dir]  # legacy: dump harness into a folder
 */
const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { spawnSync } = require('child_process');

const PKG_ROOT = path.resolve(__dirname, '..');
const pkg = require('../package.json');

const cyan = '\x1b[36m';
const green = '\x1b[32m';
const yellow = '\x1b[33m';
const dim = '\x1b[2m';
const reset = '\x1b[0m';

const banner = `
${cyan}  ███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
  ████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
  ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
  ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
  ██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
  ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝${reset}

  Claude Master Setup ${dim}v${pkg.version}${reset}
  Autonomous engineering harness for Claude Code
`;

const SKIP_RELATIVE = new Set([
  '.claude/state',
  '.claude/settings.local.json',
  '.cursor',
  '.git',
  'node_modules',
]);

const args = process.argv.slice(2);
const hasGlobal = args.includes('--global') || args.includes('-g');
const hasLocal = args.includes('--local') || args.includes('-l');
const hasHelp = args.includes('--help') || args.includes('-h');
const skipCompanions = args.includes('--skip-companions');
const forceCompanions = args.includes('--with-companions');
const scaffoldIdx = args.findIndex((a) => a === '--scaffold' || a === '-s');
const wantsScaffold = scaffoldIdx !== -1;

function parseConfigDirArg() {
  const idx = args.findIndex((a) => a === '--config-dir' || a === '-c');
  if (idx !== -1) {
    const next = args[idx + 1];
    if (!next || next.startsWith('-')) {
      console.error(`  ${yellow}--config-dir requires a path argument${reset}`);
      process.exit(1);
    }
    return next;
  }
  const eq = args.find((a) => a.startsWith('--config-dir=') || a.startsWith('-c='));
  return eq ? eq.split('=')[1] : null;
}

const explicitConfigDir = parseConfigDirArg();

function expandTilde(filePath) {
  if (filePath && filePath.startsWith('~/')) {
    return path.join(os.homedir(), filePath.slice(2));
  }
  return filePath;
}

function printHelp() {
  console.log(banner);
  console.log(`  ${yellow}Usage:${reset} npx claude-master-setup [options]

  ${yellow}Options:${reset}
    ${cyan}-g, --global${reset}              Install into Claude config (~/.claude) — all projects
    ${cyan}-l, --local${reset}               Install into ./.claude + project scripts/docs
    ${cyan}-c, --config-dir <path>${reset}   Custom Claude config dir (with --global)
    ${cyan}-s, --scaffold [dir]${reset}      Legacy: copy full harness into a directory
    ${cyan}--with-companions${reset}         Also run claude plugin marketplace/install (default on --global)
    ${cyan}--skip-companions${reset}         Only merge settings.json; do not call claude plugin CLI
    ${cyan}-h, --help${reset}                Show this help

  ${yellow}Examples:${reset}
    ${dim}# Interactive (asks global vs local)${reset}
    npx claude-master-setup

    ${dim}# Global — agents + commands + auto-install companions${reset}
    npx claude-master-setup --global

    ${dim}# Global without downloading plugins${reset}
    npx claude-master-setup --global --skip-companions

    ${dim}# Local — full harness in this project${reset}
    npx claude-master-setup --local

  ${yellow}What gets installed:${reset}
    ${dim}global${reset}  agents/  commands/  claude-master-setup/ + companion plugins (if claude CLI present)
    ${dim}local${reset}   .claude/  scripts/  docs/  CLAUDE.md  MASTER-PROMPT.md
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

function backupIfExists(dir) {
  if (!fs.existsSync(dir)) return null;
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backup = `${dir}.backup-${stamp}`;
  fs.renameSync(dir, backup);
  return backup;
}

function copyDirContents(srcDir, destDir) {
  if (!fs.existsSync(srcDir)) return 0;
  fs.mkdirSync(destDir, { recursive: true });
  let n = 0;
  for (const entry of fs.readdirSync(srcDir)) {
    const src = path.join(srcDir, entry);
    const dest = path.join(destDir, entry);
    const stat = fs.statSync(src);
    if (stat.isDirectory()) {
      copyRecursive(src, dest);
    } else {
      fs.copyFileSync(src, dest);
    }
    n += 1;
  }
  return n;
}

function chmodHooksAndScripts(claudeDir, projectRoot) {
  const hookDir = path.join(claudeDir, 'hooks');
  if (fs.existsSync(hookDir)) {
    for (const f of fs.readdirSync(hookDir)) {
      if (f.endsWith('.sh')) fs.chmodSync(path.join(hookDir, f), 0o755);
    }
  }
  const scriptsDir = path.join(projectRoot, 'scripts');
  if (fs.existsSync(scriptsDir)) {
    for (const f of fs.readdirSync(scriptsDir)) {
      if (f.endsWith('.sh')) fs.chmodSync(path.join(scriptsDir, f), 0o755);
    }
  }
}

/**
 * Global: wire agents + commands into Claude Code user config.
 * Hooks stay project-local (they need $CLAUDE_PROJECT_DIR/scripts).
 */
function installGlobal() {
  const configDir =
    expandTilde(explicitConfigDir) ||
    expandTilde(process.env.CLAUDE_CONFIG_DIR) ||
    path.join(os.homedir(), '.claude');
  const label = configDir.replace(os.homedir(), '~');

  console.log(`  Installing to ${cyan}${label}${reset}\n`);

  fs.mkdirSync(configDir, { recursive: true });

  const agentsSrc = path.join(PKG_ROOT, '.claude', 'agents');
  const agentsDest = path.join(configDir, 'agents');
  const agentsN = copyDirContents(agentsSrc, agentsDest);
  console.log(`  ${green}✓${reset} Installed agents/ (${agentsN} agents)`);

  const commandsSrc = path.join(PKG_ROOT, '.claude', 'commands');
  const commandsDest = path.join(configDir, 'commands');
  const commandsN = copyDirContents(commandsSrc, commandsDest);
  console.log(`  ${green}✓${reset} Installed commands/ (${commandsN} commands)`);

  const packDest = path.join(configDir, 'claude-master-setup');
  const packBackup = backupIfExists(packDest);
  if (packBackup) {
    console.log(`  ${dim}↳ backed up existing claude-master-setup → ${path.basename(packBackup)}${reset}`);
  }
  fs.mkdirSync(packDest, { recursive: true });
  for (const item of ['docs', 'MASTER-PROMPT.md', 'CLAUDE.md', 'templates']) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const dest = path.join(packDest, item);
    copyRecursive(src, dest);
  }
  // Keep a copy of hooks/scripts as reference for adopters
  for (const item of ['.claude/hooks', '.claude/context', 'scripts']) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const destName = item.startsWith('.claude/') ? item.slice('.claude/'.length) : item;
    copyRecursive(src, path.join(packDest, destName));
  }
  const companionsSrc = path.join(PKG_ROOT, 'docs', 'COMPANIONS.md');
  if (fs.existsSync(companionsSrc)) {
    fs.copyFileSync(companionsSrc, path.join(packDest, 'COMPANIONS.md'));
  }
  console.log(`  ${green}✓${reset} Installed claude-master-setup/ (docs + references)`);

  mergeCompanionSettings(configDir);

  // settings.json only *enables* plugins; claude plugin CLI downloads them.
  const shouldInstallCompanions = forceCompanions || (!skipCompanions && true);
  if (shouldInstallCompanions) {
    installCompanionsViaClaudeCli();
  } else {
    printCompanionNextSteps();
  }

  console.log(`  ${green}Done!${reset} Launch Claude Code and run ${cyan}/status${reset} or ${cyan}/loop${reset}.

  ${dim}Note: validate hooks + scripts/validate.sh are project-local.
  For a full gate in one repo, also run:${reset} ${cyan}npx claude-master-setup --local${reset}
`);
}

/** Recommended Claude Code plugins (Forge-style settings merge into ~/.claude). */
const COMPANION_MARKETPLACES = {
  thedotmack: {
    source: { source: 'github', repo: 'thedotmack/claude-mem' },
  },
  'antigravity-awesome-skills': {
    source: {
      source: 'git',
      url: 'https://github.com/sickn33/antigravity-awesome-skills.git',
    },
  },
};

const COMPANION_PLUGINS = {
  'claude-mem@thedotmack': true,
  'superpowers@claude-plugins-official': true,
  'code-review@claude-plugins-official': true,
  'antigravity-awesome-skills@antigravity-awesome-skills': true,
};

/**
 * Safely merge companion marketplaces + enabledPlugins into settings.json.
 * Never deletes unrelated keys (permissions, hooks, etc.).
 */
function mergeCompanionSettings(configDir) {
  const settingsPath = path.join(configDir, 'settings.json');
  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch (err) {
      console.log(
        `  ${yellow}!${reset} Could not parse ${settingsPath} — skipping companion settings merge (${err.message})`
      );
      return;
    }
  }

  settings.extraKnownMarketplaces = {
    ...(settings.extraKnownMarketplaces || {}),
    ...COMPANION_MARKETPLACES,
  };
  settings.enabledPlugins = {
    ...(settings.enabledPlugins || {}),
    ...COMPANION_PLUGINS,
  };

  fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`, 'utf8');
  console.log(`  ${green}✓${reset} Updated settings.json (companion marketplaces + plugins)`);
}

function printCompanionNextSteps() {
  console.log(`
  ${yellow}Recommended companions${reset} ${dim}(run in terminal, or inside Claude Code)${reset}:

    ${cyan}claude plugin marketplace add thedotmack/claude-mem${reset}
    ${cyan}claude plugin install claude-mem@thedotmack --scope user${reset}

    ${cyan}claude plugin install superpowers@claude-plugins-official --scope user${reset}
    ${cyan}claude plugin install code-review@claude-plugins-official --scope user${reset}

    ${cyan}claude plugin marketplace add sickn33/antigravity-awesome-skills${reset}
    ${cyan}claude plugin install antigravity-awesome-skills@antigravity-awesome-skills --scope user${reset}

  ${dim}Full guide:${reset} ~/.claude/claude-master-setup/COMPANIONS.md
`);
}

/**
 * Auto-complete companions via non-interactive Claude Code CLI.
 * Equivalent to /plugin marketplace add + /plugin install (no TUI).
 */
function installCompanionsViaClaudeCli() {
  const which = spawnSync('bash', ['-lc', 'command -v claude'], { encoding: 'utf8' });
  if (which.status !== 0 || !String(which.stdout || '').trim()) {
    console.log(
      `  ${yellow}!${reset} claude CLI not found — skipped auto companion install.`
    );
    printCompanionNextSteps();
    return;
  }

  console.log(`  ${dim}Installing companions via claude plugin CLI…${reset}\n`);

  const marketplaces = [
    ['thedotmack/claude-mem', 'thedotmack'],
    ['sickn33/antigravity-awesome-skills', 'antigravity-awesome-skills'],
  ];
  for (const [source, label] of marketplaces) {
    const r = spawnSync('claude', ['plugin', 'marketplace', 'add', source], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    if (r.status === 0) {
      console.log(`  ${green}✓${reset} Marketplace: ${label}`);
    } else {
      const err = `${r.stderr || r.stdout || ''}`.trim().split('\n')[0] || 'failed';
      // already-added is fine
      if (/already|exists|duplicate/i.test(`${r.stderr || ''}${r.stdout || ''}`)) {
        console.log(`  ${green}✓${reset} Marketplace: ${label} ${dim}(already added)${reset}`);
      } else {
        console.log(`  ${yellow}!${reset} Marketplace ${label}: ${err}`);
      }
    }
  }

  const plugins = [
    'claude-mem@thedotmack',
    'superpowers@claude-plugins-official',
    'code-review@claude-plugins-official',
    'antigravity-awesome-skills@antigravity-awesome-skills',
  ];
  for (const plugin of plugins) {
    const r = spawnSync(
      'claude',
      ['plugin', 'install', plugin, '--scope', 'user'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }
    );
    if (r.status === 0) {
      console.log(`  ${green}✓${reset} Plugin: ${plugin}`);
    } else {
      const blob = `${r.stderr || ''}${r.stdout || ''}`;
      if (/already installed|already enabled/i.test(blob)) {
        console.log(`  ${green}✓${reset} Plugin: ${plugin} ${dim}(already installed)${reset}`);
      } else {
        const err = blob.trim().split('\n').filter(Boolean).slice(-1)[0] || 'failed';
        console.log(`  ${yellow}!${reset} Plugin ${plugin}: ${err}`);
      }
    }
  }

  console.log(`
  ${dim}Restart Claude Code so new plugins load. Then:${reset} ${cyan}/learn-codebase${reset} ${dim}(once per repo)${reset}
`);
}

/**
 * Local: full project harness under ./.claude + scripts/docs at project root.
 */
function installLocal() {
  const projectRoot = path.resolve(process.cwd());
  const pkgRoot = path.resolve(PKG_ROOT);
  const claudeDir = path.join(projectRoot, '.claude');
  const srcClaude = path.join(pkgRoot, '.claude');
  console.log(`  Installing to ${cyan}./.claude${reset} (this project)\n`);

  // Running --local inside the harness repo itself: source === dest.
  // Backing up .claude would rename away the only copy of the package files.
  if (projectRoot === pkgRoot) {
    console.log(
      `  ${yellow}You are inside the Claude Master Setup source repo.${reset}\n` +
        `  ${dim}.claude/ is already the harness — not reinstalling over itself.${reset}\n` +
        `  ${dim}Use --local from another project, or --global for ~/.claude.${reset}\n`
    );
    if (!fs.existsSync(claudeDir)) {
      console.error(`  ${yellow}Missing .claude/ in the source repo — restore it from git.${reset}`);
      process.exitCode = 1;
      return;
    }
    chmodHooksAndScripts(claudeDir, projectRoot);
    const installSh = path.join(projectRoot, 'scripts', 'install.sh');
    if (fs.existsSync(installSh)) {
      spawnSync('bash', [installSh], { cwd: projectRoot, stdio: 'inherit' });
    }
    console.log(`  ${green}Done!${reset} Run ${cyan}claude${reset} here, or ${cyan}/loop${reset} in this repo.\n`);
    return;
  }

  if (!fs.existsSync(srcClaude)) {
    console.error(`  ${yellow}Package is incomplete: missing .claude/ in ${pkgRoot}${reset}`);
    process.exitCode = 1;
    return;
  }

  // Copy source to a temp dir first so backupIfExists can never delete our source
  // when someone has linked/copied the package oddly.
  const tmpClaude = fs.mkdtempSync(path.join(os.tmpdir(), 'cms-claude-'));
  try {
    copyRecursive(srcClaude, tmpClaude);

    const claudeBackup = backupIfExists(claudeDir);
    if (claudeBackup) {
      console.log(`  ${dim}↳ backed up existing .claude → ${path.basename(claudeBackup)}${reset}`);
    }

    copyRecursive(tmpClaude, claudeDir);
    console.log(`  ${green}✓${reset} Installed .claude/ (agents, commands, hooks, settings)`);
  } finally {
    fs.rmSync(tmpClaude, { recursive: true, force: true });
  }

  for (const item of ['scripts', 'docs', 'CLAUDE.md', 'MASTER-PROMPT.md', '.env.example']) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const dest = path.join(projectRoot, item);
    if (fs.existsSync(dest) && fs.statSync(dest).isDirectory()) {
      // merge/overwrite scripts & docs contents for a clean harness update
      if (item === 'scripts' || item === 'docs') {
        copyRecursive(src, dest);
        console.log(`  ${green}✓${reset} Updated ${item}/`);
        continue;
      }
    }
    if (fs.existsSync(dest) && !fs.statSync(dest).isDirectory()) {
      console.log(`  ${dim}skip (already exists): ${item}${reset}`);
      continue;
    }
    copyRecursive(src, dest);
    console.log(`  ${green}✓${reset} Installed ${item}`);
  }

  // gitignore template (npm strips .gitignore from packages)
  const giDest = path.join(projectRoot, '.gitignore');
  if (!fs.existsSync(giDest)) {
    const giSrc = path.join(PKG_ROOT, 'templates', 'gitignore');
    if (fs.existsSync(giSrc)) {
      fs.copyFileSync(giSrc, giDest);
      console.log(`  ${green}✓${reset} Installed .gitignore`);
    }
  } else {
    console.log(`  ${dim}skip (already exists): .gitignore${reset}`);
  }

  chmodHooksAndScripts(claudeDir, projectRoot);

  const installSh = path.join(projectRoot, 'scripts', 'install.sh');
  if (fs.existsSync(installSh)) {
    const result = spawnSync('bash', [installSh], { cwd: projectRoot, stdio: 'inherit' });
    if (result.status !== 0) {
      console.error(`\n  ${yellow}scripts/install.sh reported errors — see above.${reset}`);
      process.exitCode = result.status || 1;
      return;
    }
  }

  console.log(`
  ${green}Done!${reset} In this project run ${cyan}claude${reset}, then ${cyan}/bootstrap${reset} → ${cyan}/loop${reset}.
  Verify: ${cyan}bash scripts/self-check.sh${reset}
`);

  // Companions are user-scoped (~/.claude); same auto-install as --global.
  if (forceCompanions || !skipCompanions) {
    const userClaude = path.join(os.homedir(), '.claude');
    fs.mkdirSync(userClaude, { recursive: true });
    mergeCompanionSettings(userClaude);
    installCompanionsViaClaudeCli();
  } else {
    printCompanionNextSteps();
  }
}

/** Legacy: scaffold harness into an explicit directory (old npx behavior). */
function installScaffold(target) {
  const dest = path.resolve(process.cwd(), target || '.');
  fs.mkdirSync(dest, { recursive: true });
  console.log(`  Scaffolding into ${cyan}${dest}${reset}\n`);

  const prev = process.cwd();
  process.chdir(dest);
  try {
    installLocal();
  } finally {
    process.chdir(prev);
  }
}

function promptLocation() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const configDir =
    expandTilde(explicitConfigDir) ||
    expandTilde(process.env.CLAUDE_CONFIG_DIR) ||
    path.join(os.homedir(), '.claude');
  const globalLabel = configDir.replace(os.homedir(), '~');

  console.log(`  ${yellow}Where would you like to install?${reset}

  ${cyan}1${reset}) Global ${dim}(${globalLabel})${reset} - available in all projects
  ${cyan}2${reset}) Local  ${dim}(./.claude)${reset} - this project only
`);

  rl.question(`  Choice ${dim}[1]${reset}: `, (answer) => {
    rl.close();
    const choice = (answer || '1').trim() || '1';
    if (choice === '2') installLocal();
    else installGlobal();
  });
}

function main() {
  if (process.platform === 'win32') {
    console.error(
      `  ${yellow}This harness uses bash hooks/scripts. Prefer macOS/Linux or WSL.${reset}`
    );
  }

  if (hasHelp) {
    printHelp();
    return;
  }

  if (hasGlobal && hasLocal) {
    console.error(`  ${yellow}Cannot specify both --global and --local${reset}`);
    process.exit(1);
  }
  if (explicitConfigDir && hasLocal) {
    console.error(`  ${yellow}Cannot use --config-dir with --local${reset}`);
    process.exit(1);
  }

  console.log(banner);

  if (wantsScaffold) {
    const target = args[scaffoldIdx + 1] && !args[scaffoldIdx + 1].startsWith('-')
      ? args[scaffoldIdx + 1]
      : '.';
    installScaffold(target);
    return;
  }

  if (hasGlobal) {
    installGlobal();
  } else if (hasLocal) {
    installLocal();
  } else {
    promptLocation();
  }
}

main();
