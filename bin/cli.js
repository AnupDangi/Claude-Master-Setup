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
// Install is filesystem copy + settings merge only; companion install is printed.

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
const hasForce = args.includes('--force') || args.includes('-f');
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

/**
 * Locate the `claude` binary via common install paths (no spawn, no env reads).
 * False negatives are ok — we then print install help.
 */
function findClaudeBinary() {
  const home = os.homedir();
  const names =
    process.platform === 'win32'
      ? ['claude.exe', 'claude.cmd', 'claude.bat', 'claude']
      : ['claude'];
  const dirs = [
    path.join(home, '.local', 'bin'),
    path.join(home, '.claude', 'local', 'bin'),
    path.join(home, '.npm-global', 'bin'),
    path.join(home, 'bin'),
    path.join(home, '.bun', 'bin'),
    path.join(home, '.homebrew', 'bin'),
    '/opt/homebrew/bin',
    '/usr/local/bin',
    path.join(home, 'AppData', 'Roaming', 'npm'),
  ];

  // Version managers: ~/.nvm/versions/node/<ver>/bin, ~/.fnm/node-versions/.../bin, etc.
  const versionRoots = [
    path.join(home, '.nvm', 'versions', 'node'),
    path.join(home, '.fnm', 'node-versions'),
    path.join(home, '.volta', 'bin'),
    path.join(home, '.asdf', 'shims'),
  ];
  for (const root of versionRoots) {
    if (!fs.existsSync(root)) continue;
    try {
      const st = fs.statSync(root);
      if (st.isFile() || root.endsWith(`${path.sep}bin`) || root.endsWith(`${path.sep}shims`)) {
        dirs.push(root);
        continue;
      }
      for (const entry of fs.readdirSync(root)) {
        const binDir = path.join(root, entry, 'installation', 'bin'); // fnm
        const nvmBin = path.join(root, entry, 'bin');
        if (fs.existsSync(nvmBin)) dirs.push(nvmBin);
        if (fs.existsSync(binDir)) dirs.push(binDir);
      }
    } catch {
      /* skip unreadable roots */
    }
  }

  for (const dir of dirs) {
    for (const name of names) {
      const candidate = path.join(dir, name);
      try {
        if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
          return candidate;
        }
      } catch {
        /* skip */
      }
    }
  }
  return null;
}

function printClaudeCodeInstallHelp() {
  console.log(`
  ${yellow}Stopped:${reset} Claude Code is required before this harness can do anything useful.

  ${dim}Note:${reset} ${cyan}.claude${reset} is a ${yellow}config folder${reset}, not a command.
  You need the ${cyan}claude${reset} CLI installed and working first.

  Install Claude Code:

    ${cyan}npm install -g @anthropic-ai/claude-code${reset}

  Or on macOS with Homebrew:

    ${cyan}brew install --cask claude-code${reset}

  Then verify and re-run this installer:

    ${cyan}claude --version${reset}
    ${cyan}npx claude-master-setup${reset}

  Docs: ${dim}code.claude.com/docs/en/install${reset}
`);
}

/** Refuse to install harness files unless Claude Code is present (or --force). */
function requireClaudeCodeOrExit() {
  if (findClaudeBinary()) return true;
  if (hasForce) {
    console.log(
      `  ${yellow}!${reset} Claude Code not found — continuing because ${cyan}--force${reset} was passed.\n`
    );
    return false;
  }
  printClaudeCodeInstallHelp();
  process.exit(1);
}

function printHelp() {
  console.log(banner);
  console.log(`  ${yellow}Usage:${reset} npx claude-master-setup [options]

  ${yellow}Options:${reset}
    ${cyan}-g, --global${reset}              Install into Claude config (~/.claude) — all projects
    ${cyan}-l, --local${reset}               Install into ./.claude + project scripts/docs
    ${cyan}-c, --config-dir <path>${reset}   Custom Claude config dir (with --global)
    ${cyan}-s, --scaffold [dir]${reset}      Legacy: copy full harness into a directory
    ${cyan}-f, --force${reset}               Install even if Claude Code CLI is missing
    ${cyan}-h, --help${reset}                Show this help

  ${yellow}Examples:${reset}
    ${dim}# Interactive (asks global vs local)${reset}
    npx claude-master-setup

    ${dim}# Global — agents + commands + settings merge${reset}
    npx claude-master-setup --global

    ${dim}# Local — full harness in this project${reset}
    npx claude-master-setup --local

  ${yellow}What gets installed:${reset}
    ${dim}global${reset}  agents/  commands/  claude-master-setup/ + settings.json merge
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

/** Pure-Node project seed (mkdir, copy, chmod, write seed files). */
function seedProject(projectRoot) {
  console.log('  Seeding project harness state…');
  chmodHooksAndScripts(path.join(projectRoot, '.claude'), projectRoot);
  console.log(`  ${green}✓${reset} scripts and hooks are executable`);

  const envExample = path.join(projectRoot, '.env.example');
  const envFile = path.join(projectRoot, '.env');
  if (fs.existsSync(envExample) && !fs.existsSync(envFile)) {
    fs.copyFileSync(envExample, envFile);
    console.log(`  ${green}✓${reset} created .env from .env.example (fill in your secrets)`);
  }

  const giPath = path.join(projectRoot, '.gitignore');
  if (!fs.existsSync(giPath)) fs.writeFileSync(giPath, '', 'utf8');
  let gi = fs.readFileSync(giPath, 'utf8');
  const lines = gi.split(/\r?\n/);
  const patterns = ['.env', '.env.*', '!.env.example', '.claude/state/', '/tmp/harness_*'];
  let changed = false;
  for (const pat of patterns) {
    if (!lines.includes(pat)) {
      gi = gi.endsWith('\n') || gi === '' ? `${gi}${pat}\n` : `${gi}\n${pat}\n`;
      changed = true;
    }
  }
  if (changed) fs.writeFileSync(giPath, gi, 'utf8');
  console.log(`  ${green}✓${reset} .gitignore updated (secrets and local state excluded)`);

  const stateDir = path.join(projectRoot, '.claude', 'state');
  fs.mkdirSync(stateDir, { recursive: true });
  const loopPath = path.join(stateDir, 'loop.json');
  if (!fs.existsSync(loopPath)) {
    fs.writeFileSync(
      loopPath,
      JSON.stringify(
        {
          iteration: 0,
          phase: 'idle',
          task: null,
          validate_attempts: 0,
          max_validate_retries: 3,
          task_graph: null,
          task_complexity: null,
          skills_index: null,
          skills_assigned: [],
          skills_skipped: [],
          fanout: null,
          iterations_this_run: 0,
          max_iterations_per_run: 1,
          build_effort_tier: null,
          build_effort_score: null,
          docs_profile: null,
        },
        null,
        2
      ) + '\n',
      'utf8'
    );
  }
  console.log(`  ${green}✓${reset} loop state initialized`);
  console.log(`  ${green}✓${reset} node ${process.version}`);
}

/**
 * Global: wire agents + commands into Claude Code user config.
 * Hooks stay project-local (they need $CLAUDE_PROJECT_DIR/scripts).
 */
function installGlobal() {
  // Prefer --config-dir; otherwise ~/.claude under the user home directory.
  const configDir = expandTilde(explicitConfigDir) || path.join(os.homedir(), '.claude');
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

  const skillsSrc = path.join(PKG_ROOT, '.claude', 'skills');
  if (fs.existsSync(skillsSrc)) {
    const skillsDest = path.join(configDir, 'skills');
    const skillsN = copyDirContents(skillsSrc, skillsDest);
    console.log(`  ${green}✓${reset} Installed skills/ (${skillsN} skills)`);
  }

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
  installStatusline(configDir);
  printCompanionNextSteps();

  console.log(`  ${green}Done!${reset} Run ${cyan}claude${reset}, then ${cyan}/status${reset} or ${cyan}/loop${reset}.

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
    source: { source: 'github', repo: 'sickn33/antigravity-awesome-skills' },
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

function statusLineCommandFor(configDir) {
  const homeClaude = path.join(os.homedir(), '.claude');
  if (path.resolve(configDir) === path.resolve(homeClaude)) {
    return 'python3 "$HOME/.claude/statusline.sh"';
  }
  // Custom --config-dir: use an absolute path so the command works even when
  // CLAUDE_CONFIG_DIR / XDG paths differ from $HOME/.claude.
  const script = path.join(path.resolve(configDir), 'statusline.sh').replace(/"/g, '\\"');
  return `python3 "${script}"`;
}

function isUserStatusLineCommand(cmd, configDir) {
  if (!cmd || typeof cmd !== 'string') return false;
  if (!cmd.includes('python3') || !cmd.includes('statusline.sh')) return false;
  if (cmd.includes('CLAUDE_PROJECT_DIR')) return false;
  const homeClaude = path.join(os.homedir(), '.claude');
  if (path.resolve(configDir) === path.resolve(homeClaude)) {
    return (
      cmd.includes('$HOME/.claude/statusline.sh') ||
      cmd.includes('${HOME}/.claude/statusline.sh')
    );
  }
  return cmd.includes(path.resolve(configDir));
}

function isProjectStatusLineCommand(cmd) {
  if (!cmd || typeof cmd !== 'string') return false;
  return cmd.includes('CLAUDE_PROJECT_DIR') && cmd.includes('statusline');
}

/**
 * Statusline is user-level only (~/.claude/statusline.sh).
 * Project .claude/ must not wire statusLine to $CLAUDE_PROJECT_DIR — that
 * confuses cloud/local clones and nested cwds. Hooks stay project-local.
 *
 * @param {string} configDir  ~/.claude (user) or ignored for project wiring
 * @param {{ projectLevel?: boolean, projectSettingsPath?: string }} [opts]
 */
function installStatusline(configDir, opts = {}) {
  const src = path.join(PKG_ROOT, '.claude', 'statusline.sh');
  if (!fs.existsSync(src)) return;

  const homeClaude = path.join(os.homedir(), '.claude');

  // Project install: strip project statusLine; sync script + wire to ~/.claude only.
  if (opts.projectLevel) {
    const projectSettings =
      opts.projectSettingsPath || path.join(configDir, 'settings.json');
    if (fs.existsSync(projectSettings)) {
      try {
        const settings = JSON.parse(fs.readFileSync(projectSettings, 'utf8'));
        const cmd = settings.statusLine && settings.statusLine.command;
        if (settings.statusLine && (isProjectStatusLineCommand(cmd) || cmd)) {
          delete settings.statusLine;
          fs.writeFileSync(
            projectSettings,
            `${JSON.stringify(settings, null, 2)}\n`,
            'utf8'
          );
          console.log(
            `  ${green}✓${reset} Removed project statusLine (use ~/.claude only)`
          );
        }
      } catch (err) {
        console.log(
          `  ${yellow}!${reset} Could not strip project statusLine (${err.message})`
        );
      }
    }
    // Always refresh user-level statusline from package.
    installStatusline(homeClaude, { projectLevel: false });
    return;
  }

  const dest = path.join(configDir, 'statusline.sh');
  fs.mkdirSync(configDir, { recursive: true });
  fs.copyFileSync(src, dest);
  try {
    fs.chmodSync(dest, 0o755);
  } catch {
    /* best-effort */
  }
  const destLabel = path.resolve(configDir) === path.resolve(homeClaude) ? '~/.claude/statusline.sh' : dest;
  console.log(`  ${green}✓${reset} Installed ${destLabel}`);

  const settingsPath = path.join(configDir, 'settings.json');
  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch (err) {
      console.log(
        `  ${yellow}!${reset} Could not parse ${settingsPath} — skipping statusLine merge (${err.message})`
      );
      return;
    }
  }

  const desired = statusLineCommandFor(configDir);
  const existing = settings.statusLine && settings.statusLine.command;
  if (isUserStatusLineCommand(existing, configDir) && existing === desired) {
    console.log(`  ${dim}keep: settings.json statusLine → ${desired}${reset}`);
    return;
  }

  settings.statusLine = {
    type: 'command',
    command: desired,
  };
  fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`, 'utf8');
  const label = path.resolve(configDir) === path.resolve(homeClaude) ? '~/.claude' : configDir;
  if (existing) {
    console.log(`  ${green}✓${reset} Fixed statusLine → ${cyan}${desired}${reset}`);
  } else {
    console.log(`  ${green}✓${reset} Enabled statusLine in ${label}/settings.json`);
  }
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

function finishLocalDone() {
  console.log(`
  ${green}Done!${reset} In this project run ${cyan}claude${reset}, then ${cyan}/bootstrap${reset} → ${cyan}/loop${reset}.
  Verify: ${cyan}scripts/self-check.sh${reset}
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
    seedProject(projectRoot);
    finishLocalDone();
    return;
  }

  if (!fs.existsSync(srcClaude)) {
    console.error(`  ${yellow}Package is incomplete: missing .claude/ in ${pkgRoot}${reset}`);
    process.exitCode = 1;
    return;
  }

  // Copy via temp so backupIfExists never deletes our package source.
  // Statusline is user-level only — do not preserve project statusLine wiring.
  const tmpClaude = fs.mkdtempSync(path.join(os.tmpdir(), 'cms-claude-'));
  try {
    copyRecursive(srcClaude, tmpClaude);

    const claudeBackup = backupIfExists(claudeDir);
    if (claudeBackup) {
      console.log(`  ${dim}↳ backed up existing .claude → ${path.basename(claudeBackup)}${reset}`);
    }

    copyRecursive(tmpClaude, claudeDir);
    console.log(`  ${green}✓${reset} Installed .claude/ (agents, commands, hooks, skills, settings)`);
  } finally {
    fs.rmSync(tmpClaude, { recursive: true, force: true });
  }

  for (const item of [
    'scripts',
    'docs',
    'CLAUDE.md',
    'MASTER-PROMPT.md',
    '.env.example',
    '.github/workflows',
  ]) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const dest = path.join(projectRoot, item);
    if (fs.existsSync(dest) && fs.statSync(dest).isDirectory()) {
      if (item === 'scripts' || item === 'docs' || item === '.github/workflows') {
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

  seedProject(projectRoot);

  // Strip any project statusLine; install/fix statusline only under ~/.claude.
  installStatusline(claudeDir, { projectLevel: true });

  const userClaude = path.join(os.homedir(), '.claude');
  fs.mkdirSync(userClaude, { recursive: true });
  mergeCompanionSettings(userClaude);
  printCompanionNextSteps();
  finishLocalDone();
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
  const configDir = expandTilde(explicitConfigDir) || path.join(os.homedir(), '.claude');
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
      `  ${yellow}Hooks/scripts expect a Unix shell. Prefer macOS/Linux or WSL.${reset}`
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
    requireClaudeCodeOrExit();
    installScaffold(target);
    return;
  }

  // Harness is useless without Claude Code — stop unless --force.
  requireClaudeCodeOrExit();

  if (hasGlobal) {
    installGlobal();
  } else if (hasLocal) {
    installLocal();
  } else {
    promptLocation();
  }
}

main();
