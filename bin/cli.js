#!/usr/bin/env node
'use strict';
/**
 * Agent Master universal CLI plus the optional Claude Code provider installer.
 *
 * Framework files (agents, commands, skills, scripts, docs, hooks) live once,
 * shared, at the resolved config dir — never duplicated per project.
 * A project only ever gets `.master/` (protocol, state, its own docs) and thin
 * root/IDE adapters that point back to `.master/`.
 *
 * Usage:
 *   agent-master init
 *   agent-master start "goal"
 *   agent-master status --format json
 *   agent-master install claude
 *
 * Legacy claude-master-setup flags remain available during migration.
 */
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');
const { AgentMasterError, initProject, runUniversalCli } = require('../lib/agent-master');
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

  Agent Master ${dim}v${pkg.version}${reset}
  Portable project state and reliable cross-agent handoffs
`;

const SKIP_RELATIVE = new Set([
  '.claude/state',
  '.claude/settings.local.json',
  '.cursor',
  '.git',
  '.github',
  'node_modules',
  '.env',
  '.env.example',
]);

/** Consumer reference docs shipped into the shared framework (keep in sync with package.json "files"). */
const FRAMEWORK_DOCS = [
  'LOOP.md',
  'SETUP.md',
  'SECURITY.md',
];

/** Runtime scripts shipped into the shared framework (keep in sync with package.json "files"). */
const FRAMEWORK_SCRIPTS = [
  'detect-stack.sh',
  'list-local-skills.sh',
  'select-skills.sh',
  'sync-project-docs.sh',
  'install-default-skills.sh',
  'install-skill.sh',
  'ensure-skills.sh',
];

const args = process.argv.slice(2);
const hasGlobal = args.includes('--global') || args.includes('-g');
const hasLocal = args.includes('--local') || args.includes('-l');
const hasFrameworkOnly = args.includes('--framework-only') || args.includes('-F');
const hasHelp = args.includes('--help') || args.includes('-h');
const hasForce = args.includes('--force') || args.includes('-f');
const hasDoctor = args.includes('--doctor');
const hasRepair = args.includes('--repair');
const scaffoldIdx = args.findIndex((a) => a === '--scaffold' || a === '-s');
const wantsScaffold = scaffoldIdx !== -1;

/** Known harness hook script basenames (used to detect legacy duplicates). */
const HARNESS_HOOK_SCRIPTS = [
  'session-start.sh',
  'pre-bash-guard.sh',
  'protect-paths.sh',
  'notify-stop.sh',
];

const EXPECTED_HARNESS_IDS = [
  'harness:session-start',
  'harness:pre-bash-guard',
  'harness:protect-paths',
  'harness:notify-stop',
];

const MASTER_PLUGIN_KEY = 'master@claude-master-setup';

/**
 * Resolve config dir: --config-dir flag → CLAUDE_CONFIG_DIR env → ~/.claude
 */
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
  if (eq) return eq.split('=')[1];
  // Honor Claude Code's alternate config directory.
  if (process.env.CLAUDE_CONFIG_DIR) return process.env.CLAUDE_CONFIG_DIR;
  return null;
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

  ${yellow}Default (no flags):${reset}
    Install the shared framework once into Claude Code config, then seed this
    project's ${cyan}.master/${reset} + thin adapters. Skip seed when run inside the harness
    source repo itself. This is the recommended path for every new project.

  ${yellow}Options:${reset}
    ${cyan}--framework-only, -F${reset}      Install shared framework only — do not seed a project
    ${cyan}--global, -g${reset}              Alias for --framework-only (kept for backward compat)
    ${cyan}--local, -l${reset}               Alias for default (framework + seed current project)
    ${cyan}-c, --config-dir <path>${reset}   Custom Claude config dir (overrides CLAUDE_CONFIG_DIR env)
    ${cyan}-s, --scaffold [dir]${reset}      Legacy: copy full harness into a directory
    ${cyan}--doctor${reset}                  Check install health (hooks, dual path, framework files)
    ${cyan}--repair${reset}                  Deduplicate hooks, restore framework, enforce single path
    ${cyan}-f, --force${reset}               Install even if Claude Code CLI is missing
    ${cyan}-h, --help${reset}                Show this help

  ${yellow}Install rule:${reset}
    Use ${cyan}npm${reset} (shared framework) ${yellow}or${reset} the ${cyan}plugin${reset} — never both.
    Dual install double-fires hooks. Prefer npm; ${cyan}--repair${reset} disables the plugin when both exist.

  ${yellow}Config dir resolution (in order):${reset}
    1. ${cyan}--config-dir <path>${reset}    explicit flag
    2. ${cyan}CLAUDE_CONFIG_DIR${reset}      environment variable
    3. ${cyan}~/.claude${reset}              default

  ${yellow}What gets installed:${reset}
    ${dim}Shared framework${reset}   agents/  commands/  statusline.sh  claude-master-setup/ (scripts, hooks, docs, templates)
    ${dim}Per-project${reset}        .master/ (protocol + docs + gitignored state)  AGENTS.md  CLAUDE.md  .cursor/rules/

  ${yellow}Five-minute tour (plugin path):${reset}
    ${cyan}claude plugin marketplace add AnupDangi/Claude-Master-Setup${reset}
    ${cyan}claude plugin install master@claude-master-setup${reset}
    Then: ${cyan}/master:bootstrap${reset} → ${cyan}/master:loop${reset} → ${cyan}/master:status${reset} → ${cyan}/master:pause${reset} → ${cyan}/master:handoff${reset}

  ${yellow}Uninstall:${reset}
    Remove ${cyan}~/.claude/claude-master-setup/${reset}, ${cyan}~/.claude/agents/</cyan>, ${cyan}~/.claude/commands/${reset}
    Remove the master blocks from ${cyan}~/.claude/settings.json${reset} (hooks, CLAUDE_MASTER_ROOT)
    In project: delete ${cyan}AGENTS.md${reset}, ${cyan}CLAUDE.md${reset}, ${cyan}.cursor/rules/master-protocol.mdc${reset}, and ${cyan}.master/${reset}
`);
}

/**
 * If `dest` already exists as a symlink, remove it first. `fs.copyFileSync`
 * and `fs.writeFileSync` follow symlinks by default, so writing straight to
 * an attacker-planted symlink at a config path would write through it to an
 * arbitrary file with the installing user's privileges. Always call this
 * immediately before copying/writing to a destination path.
 */
function removeIfSymlink(dest) {
  let st;
  try {
    st = fs.lstatSync(dest);
  } catch {
    return;
  }
  if (st.isSymbolicLink()) fs.unlinkSync(dest);
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
    removeIfSymlink(dest);
    fs.copyFileSync(src, dest);
  }
}

/**
 * Recursively copy, replacing the literal token `${CLAUDE_PLUGIN_ROOT}` in
 * text files with `replacement` (an absolute path). Mirrors FORGE Framework's
 * copy-time path substitution: agent/command source files hardcode the token
 * assuming plugin-native resolution; for the npm install paths we perform the
 * identical substitution ourselves at copy time so every reference is already
 * a literal, correct absolute path by the time Claude Code loads the file.
 */
function copyWithTokenSubstitution(src, dest, replacement) {
  const rel = path.relative(PKG_ROOT, src);
  if (SKIP_RELATIVE.has(rel)) return;

  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      copyWithTokenSubstitution(path.join(src, entry), path.join(dest, entry), replacement);
    }
    return;
  }

  fs.mkdirSync(path.dirname(dest), { recursive: true });
  removeIfSymlink(dest);
  if (src.endsWith('.md') || src.endsWith('.json')) {
    const content = fs.readFileSync(src, 'utf8');
    const replaced = content.split('${CLAUDE_PLUGIN_ROOT}').join(replacement);
    fs.writeFileSync(dest, replaced, 'utf8');
  } else {
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

function copyDirContents(srcDir, destDir, replacement) {
  if (!fs.existsSync(srcDir)) return 0;
  fs.mkdirSync(destDir, { recursive: true });
  let n = 0;
  for (const entry of fs.readdirSync(srcDir)) {
    const src = path.join(srcDir, entry);
    const dest = path.join(destDir, entry);
    const stat = fs.statSync(src);
    if (stat.isDirectory()) {
      copyWithTokenSubstitution(src, dest, replacement);
    } else if (entry.endsWith('.md') || entry.endsWith('.json')) {
      const content = fs.readFileSync(src, 'utf8');
      removeIfSymlink(dest);
      fs.writeFileSync(dest, content.split('${CLAUDE_PLUGIN_ROOT}').join(replacement), 'utf8');
    } else {
      removeIfSymlink(dest);
      fs.copyFileSync(src, dest);
    }
    n += 1;
  }
  return n;
}

/** Copy only files that don't already exist at dest — never clobber. */
function copyDirContentsIfAbsent(srcDir, destDir) {
  if (!fs.existsSync(srcDir)) return 0;
  fs.mkdirSync(destDir, { recursive: true });
  let n = 0;
  for (const entry of fs.readdirSync(srcDir)) {
    const dest = path.join(destDir, entry);
    if (fs.existsSync(dest)) continue;
    removeIfSymlink(dest); // clears a dangling symlink existsSync missed
    fs.copyFileSync(path.join(srcDir, entry), dest);
    n += 1;
  }
  return n;
}

/**
 * Create fresh loop state (same shape everywhere: bin/cli.js, scripts/install.sh,
 * bootstrap scaffold, and scripts/install.sh — keep in sync when the schema changes).
 */
function loopStateJson() {
  return (
    JSON.stringify(
      {
        schema_version: 1,
        active: false,
        status: 'idle',
        prompt: null,
        iteration: 0,
        max_iterations: 2,
        completion_promise: null,
        complexity: 'unclassified',
        execution_mode: 'unclassified',
        task_graph: [],
        selected_skills: [],
        assigned_agents: [],
        validation: {
          status: 'not_run',
          command: null,
          agent: null,
          checks: [],
          checked_at: null,
        },
        next_action: null,
        pause_reason: null,
        phase: 'gate',
        ship_completed: false,
        correction_log: [],
        await_clarify_questions: [],
        architecture_pending: false,
        stall_count: 0,
        last_error: null,
        blocked_on: null,
        progress_fingerprint: null,
        last_progress_at: null,
        started_at: null,
        updated_at: null,
      },
      null,
      2
    ) + '\n'
  );
}

function inferProjectMetadata(projectRoot) {
  const exists = (rel) => fs.existsSync(path.join(projectRoot, rel));
  let name = path.basename(projectRoot);
  let stack = 'unknown';
  let commands = [];

  if (exists('package.json')) {
    try {
      const p = JSON.parse(fs.readFileSync(path.join(projectRoot, 'package.json'), 'utf8'));
      name = p.name || name;
      stack = exists('pnpm-lock.yaml') ? 'Node.js (pnpm)' : exists('yarn.lock') ? 'Node.js (yarn)' : 'Node.js (npm)';
      for (const key of ['dev', 'test', 'lint', 'build']) {
        if (p.scripts && p.scripts[key]) commands.push(`${key}: npm run ${key}`);
      }
    } catch {
      stack = 'Node.js';
    }
  } else if (exists('pyproject.toml')) {
    stack = 'Python';
  } else if (exists('Cargo.toml')) {
    stack = 'Rust';
  } else if (exists('go.mod')) {
    stack = 'Go';
  } else if (exists('pom.xml') || exists('build.gradle')) {
    stack = 'Java';
  }

  let mission = `Project ${name}.`;
  if (exists('README.md')) {
    const lines = fs.readFileSync(path.join(projectRoot, 'README.md'), 'utf8').split(/\r?\n/);
    const paragraph = lines.find((line) => {
      const s = line.trim();
      return s && !s.startsWith('#') && !s.startsWith('![') && !s.startsWith('<');
    });
    if (paragraph) mission = paragraph.trim().slice(0, 500);
  }

  const hasTests =
    exists('test') || exists('tests') || exists('__tests__') ||
    (exists('package.json') && commands.some((c) => c.startsWith('test:')));
  const hasCi = exists('.github/workflows') || exists('.gitlab-ci.yml');
  const hasSource = ['src', 'app', 'lib', 'cmd'].some(exists);
  const maturity = hasCi && hasTests ? 'production' : hasSource && hasTests ? 'existing' : hasSource ? 'prototype' : 'new';

  return { name, mission, stack, commands, maturity };
}

/**
 * Seed a project's `.master/` (protocol, state, starter docs) and thin adapters.
 * Never overwrites existing files. `frameworkRoot` is the shared install (for
 * adapter templates' own ${CLAUDE_PLUGIN_ROOT} references, which get the same
 * copy-time substitution).
 *
 * Returns an array of strings describing what was touched (for success summary).
 */
function seedMasterFolder(projectRoot, frameworkRoot) {
  console.log('  Seeding .master/…');
  const before = new Set([
    '.master/README.md',
    'AGENTS.md',
    'CLAUDE.md',
    '.cursor/rules/master-protocol.mdc',
  ].filter((rel) => fs.existsSync(path.join(projectRoot, rel))));
  const result = initProject(projectRoot, path.join(PKG_ROOT, 'templates'));
  const touched = [...result.created];
  if (!before.has('.master/README.md') && fs.existsSync(path.join(projectRoot, '.master', 'README.md'))) {
    touched.push('.master/README.md');
  }
  touched.push('.master/project.json');
  if (result.migrated_run) touched.push(`.master/runs/${result.migrated_run}.json (migrated)`);
  console.log(`  ${green}✓${reset} schema v2 project contract ready`);
  console.log(`  ${green}✓${reset} runtime dirs ready (runs, events, evidence, locks)`);
  console.log(`  ${green}✓${reset} thin AGENTS.md, CLAUDE.md, and Cursor adapters ready`);
  console.log(`  ${green}✓${reset} .gitignore updated (runtime state and .env excluded)`);
  console.log(`  ${green}✓${reset} node ${process.version}`);

  return [...new Set(touched)];
}

/**
 * Idempotent: install/refresh the shared framework (agents, commands, skills,
 * plus the reference bundle — docs/scripts/hooks/templates) at `configDir`.
 * Both default and --framework-only call this; default additionally seeds a project's
 * own `.master/`. This is the ONE place framework files live per install —
 * never duplicated per project.
 *
 * Returns frameworkRoot (the absolute path to the installed framework bundle).
 */
function ensureFrameworkInstalled(configDir) {
  fs.mkdirSync(configDir, { recursive: true });

  const packDest = path.join(configDir, 'claude-master-setup');
  const frameworkRoot = path.resolve(packDest);
  const obsoleteCommands = ['decide', 'evaluate', 'go', 'mcp-add', 'plan', 'review', 'ship'];
  const obsoleteAgents = [
    'docs-writer', 'evaluator', 'mcp-scout', 'security',
    // v1.1: retired the heavy multi-agent loop roles — the universal core
    // (init/start/checkpoint/validate/handoff) does not require subagents.
    'architect', 'implementer', 'implementer-opus', 'orchestrator', 'planner', 'reviewer', 'validator',
  ];
  const retireIfManaged = (target) => {
    if (!fs.existsSync(target)) return;
    const stat = fs.statSync(target);
    const markerFile = stat.isDirectory() ? path.join(target, 'SKILL.md') : target;
    if (!fs.existsSync(markerFile)) return;
    const source = fs.readFileSync(markerFile, 'utf8');
    const isManaged = [
      '${CLAUDE_PLUGIN_ROOT}',
      'Claude Master Setup',
      '.master/state/loop.json',
      'capability-orchestrator',
    ].some((marker) => source.includes(marker));
    if (isManaged) backupIfExists(target);
  };
  for (const name of obsoleteCommands) {
    retireIfManaged(path.join(configDir, 'commands', `${name}.md`));
  }
  for (const name of obsoleteAgents) {
    retireIfManaged(path.join(configDir, 'agents', `${name}.md`));
  }
  retireIfManaged(path.join(configDir, 'skills', 'capability-orchestrator'));

  const agentsSrc = path.join(PKG_ROOT, '.claude', 'agents');
  const agentsDest = path.join(configDir, 'agents');
  const agentsN = copyDirContents(agentsSrc, agentsDest, frameworkRoot);
  console.log(`  ${green}✓${reset} Installed agents/ (${agentsN} agents)`);

  const commandsSrc = path.join(PKG_ROOT, '.claude', 'commands');
  const commandsDest = path.join(configDir, 'commands');
  const commandsN = copyDirContents(commandsSrc, commandsDest, frameworkRoot);
  console.log(`  ${green}✓${reset} Installed commands/ (${commandsN} commands)`);

  const packBackup = backupIfExists(packDest);
  if (packBackup) {
    console.log(`  ${dim}↳ backed up existing claude-master-setup → ${path.basename(packBackup)}${reset}`);
  }
  fs.mkdirSync(packDest, { recursive: true });

  // Docs: allowlisted consumer references only (never maintainer working memory).
  const docsDest = path.join(packDest, 'docs');
  fs.mkdirSync(docsDest, { recursive: true });
  for (const name of FRAMEWORK_DOCS) {
    const src = path.join(PKG_ROOT, 'docs', name);
    if (!fs.existsSync(src)) continue;
    fs.copyFileSync(src, path.join(docsDest, name));
  }
  for (const item of ['templates', 'bin', 'lib', 'adapters']) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const dest = path.join(packDest, item);
      copyRecursive(src, dest);
  }
  fs.copyFileSync(path.join(PKG_ROOT, 'package.json'), path.join(packDest, 'package.json'));

  // Hooks are shared runtime files.
  for (const item of ['.claude/hooks']) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const destName = item.slice('.claude/'.length);
    copyRecursive(src, path.join(packDest, destName));
  }

  // Scripts: allowlisted runtime only (never install.sh / self-check.sh).
  const scriptsDest = path.join(packDest, 'scripts');
  fs.mkdirSync(scriptsDest, { recursive: true });
  for (const name of FRAMEWORK_SCRIPTS) {
    const src = path.join(PKG_ROOT, 'scripts', name);
    if (!fs.existsSync(src)) continue;
    fs.copyFileSync(src, path.join(scriptsDest, name));
  }

  // Scripts must be executable wherever they end up.
  if (fs.existsSync(scriptsDest)) {
    for (const f of fs.readdirSync(scriptsDest)) {
      if (f.endsWith('.sh')) {
        try {
          fs.chmodSync(path.join(scriptsDest, f), 0o755);
        } catch {
          /* best-effort */
        }
      }
    }
  }
  const hookDir = path.join(packDest, 'hooks');
  if (fs.existsSync(hookDir)) {
    for (const f of fs.readdirSync(hookDir)) {
      if (f.endsWith('.sh')) {
        try {
          fs.chmodSync(path.join(hookDir, f), 0o755);
        } catch {
          /* best-effort */
        }
      }
    }
  }
  console.log(`  ${green}✓${reset} Installed Claude adapter (universal CLI, commands, hooks, templates)`);

  mergeFrameworkSettings(configDir, frameworkRoot);
  return frameworkRoot;
}

/** Harness hooks, wired via $CLAUDE_MASTER_ROOT (mirrors .claude-plugin/plugin.json's ${CLAUDE_PLUGIN_ROOT} form). */
function harnessHooksBlock() {
  const h = (name) => `bash "$CLAUDE_MASTER_ROOT/hooks/${name}.sh"`;
  return {
    SessionStart: [
      {
        matcher: '*',
        hooks: [{ type: 'command', command: h('session-start') }],
        description: 'Print loop state and remind to read CLAUDE.md on new session',
        id: 'harness:session-start',
      },
    ],
    PreToolUse: [
      {
        matcher: 'Bash',
        hooks: [{ type: 'command', command: h('pre-bash-guard') }],
        description: 'Block dangerous shell commands (rm -rf /, piped installers, secret reads)',
        id: 'harness:pre-bash-guard',
      },
      {
        matcher: 'Write|Edit|MultiEdit',
        hooks: [{ type: 'command', command: h('protect-paths') }],
        description:
          'BLOCK .env*/lockfiles/CI/control-plane unless HARNESS_ALLOW_PROTECTED_EDITS=1',
        id: 'harness:protect-paths',
      },
    ],
    Stop: [
      {
        matcher: '*',
        hooks: [{ type: 'command', command: h('notify-stop'), async: true, timeout: 10 }],
        description: 'Optional desktop notification for terminal Agent Master run states',
        id: 'harness:notify-stop',
      },
    ],
  };
}


/**
 * True if a settings.json hook entry belongs to this harness (current or legacy).
 * Detects: harness:* ids, CLAUDE_MASTER_ROOT / HARNESS_FRAMEWORK_ROOT commands,
 * and known harness script names under those roots (covers ID-less duplicates).
 */
function isMasterOwnedHookEntry(entry) {
  if (!entry || typeof entry !== 'object') return false;
  if (typeof entry.id === 'string' && entry.id.startsWith('harness:')) return true;

  const commands = [];
  if (Array.isArray(entry.hooks)) {
    for (const h of entry.hooks) {
      if (h && typeof h.command === 'string') commands.push(h.command);
    }
  }
  if (typeof entry.command === 'string') commands.push(entry.command);

  for (const cmd of commands) {
    if (
      cmd.includes('$CLAUDE_MASTER_ROOT/hooks/') ||
      cmd.includes('${CLAUDE_MASTER_ROOT}/hooks/') ||
      cmd.includes('$HARNESS_FRAMEWORK_ROOT/hooks/') ||
      cmd.includes('${HARNESS_FRAMEWORK_ROOT}/hooks/')
    ) {
      return true;
    }
    for (const script of HARNESS_HOOK_SCRIPTS) {
      if (
        (cmd.includes('CLAUDE_MASTER_ROOT') || cmd.includes('HARNESS_FRAMEWORK_ROOT')) &&
        cmd.includes(script)
      ) {
        return true;
      }
      // Absolute path under a claude-master-setup install
      if (cmd.includes(`/claude-master-setup/hooks/${script}`)) return true;
    }
  }
  return false;
}

/**
 * Merge harness hook phases without wiping user hooks.
 * Replaces all Master-owned entries (by id, env token, or script path), then
 * appends exactly one fresh harnessHooksBlock() set.
 */
function mergeHookPhases(existingHooks, harnessHooks) {
  const out = { ...(existingHooks || {}) };
  for (const [phase, harnessEntries] of Object.entries(harnessHooks || {})) {
    const prev = Array.isArray(out[phase]) ? out[phase] : [];
    const nonHarness = prev.filter((e) => !isMasterOwnedHookEntry(e));
    out[phase] = [...nonHarness, ...(harnessEntries || [])];
  }
  // Also strip Master-owned entries from phases the harness no longer uses
  for (const phase of Object.keys(out)) {
    if (harnessHooks && Object.prototype.hasOwnProperty.call(harnessHooks, phase)) continue;
    if (!Array.isArray(out[phase])) continue;
    const cleaned = out[phase].filter((e) => !isMasterOwnedHookEntry(e));
    if (cleaned.length === 0) delete out[phase];
    else out[phase] = cleaned;
  }
  return out;
}

/** Count harness:* ids across all hook phases (for doctor / tests). */
function countHarnessIds(hooks) {
  const counts = Object.create(null);
  for (const entries of Object.values(hooks || {})) {
    if (!Array.isArray(entries)) continue;
    for (const e of entries) {
      if (e && typeof e.id === 'string' && e.id.startsWith('harness:')) {
        counts[e.id] = (counts[e.id] || 0) + 1;
      }
    }
  }
  return counts;
}

/** Whether settings or installed_plugins mark the master plugin as active. */
function isMasterPluginEnabled(configDir) {
  try {
    const settingsPath = path.join(configDir, 'settings.json');
    if (fs.existsSync(settingsPath)) {
      const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      const enabled = settings.enabledPlugins || {};
      if (enabled[MASTER_PLUGIN_KEY]) return true;
    }
  } catch {
    /* ignore */
  }
  try {
    const installed = path.join(os.homedir(), '.claude', 'plugins', 'installed_plugins.json');
    if (fs.existsSync(installed)) {
      const data = JSON.parse(fs.readFileSync(installed, 'utf8'));
      const plugins = data.plugins || data;
      if (plugins && typeof plugins === 'object') {
        if (
          Object.keys(plugins).some(
            (k) => k.includes(MASTER_PLUGIN_KEY) || k === MASTER_PLUGIN_KEY
          )
        ) {
          // Installed alone is not dual-fire; only enabledPlugins causes plugin hooks.
          // Still report installed for doctor context via separate helper.
        }
      }
    }
  } catch {
    /* ignore */
  }
  return false;
}

function isMasterPluginInstalled() {
  try {
    const installed = path.join(os.homedir(), '.claude', 'plugins', 'installed_plugins.json');
    if (!fs.existsSync(installed)) return false;
    const data = JSON.parse(fs.readFileSync(installed, 'utf8'));
    const plugins = data.plugins || data;
    if (!plugins || typeof plugins !== 'object') return false;
    return Object.keys(plugins).some(
      (k) => k.includes(MASTER_PLUGIN_KEY) || k === MASTER_PLUGIN_KEY
    );
  } catch {
    return false;
  }
}

/**
 * Disable master plugin in settings when npm framework is present (single-path).
 * Returns true if a change was made.
 */
function disableMasterPluginInSettings(settings) {
  if (!settings.enabledPlugins || typeof settings.enabledPlugins !== 'object') return false;
  if (!settings.enabledPlugins[MASTER_PLUGIN_KEY]) return false;
  settings.enabledPlugins[MASTER_PLUGIN_KEY] = false;
  return true;
}

/**
 * Merge the shared framework root and hooks into settings.json. Never deletes unrelated keys.
 * Enforces single path: npm framework wins; disables master@claude-master-setup when both exist.
 * Strips legacy HARNESS_FRAMEWORK_ROOT from env.
 */
function mergeFrameworkSettings(configDir, frameworkRoot) {
  const settingsPath = path.join(configDir, 'settings.json');
  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch (err) {
      console.log(
        `  ${yellow}!${reset} Could not parse ${settingsPath} — skipping settings merge (${err.message})`
      );
      return;
    }
  }

  // Register optional companion marketplaces (user installs plugins explicitly).
  settings.extraKnownMarketplaces = {
    ...(settings.extraKnownMarketplaces || {}),
    thedotmack: { source: { source: 'github', repo: 'thedotmack/claude-mem' } },
    'antigravity-awesome-skills': {
      source: { source: 'github', repo: 'sickn33/antigravity-awesome-skills' },
    },
  };

  const prevEnv = { ...(settings.env || {}) };
  delete prevEnv.HARNESS_FRAMEWORK_ROOT;
  settings.env = {
    ...prevEnv,
    CLAUDE_MASTER_ROOT: frameworkRoot,
  };
  settings.hooks = mergeHookPhases(settings.hooks, harnessHooksBlock());

  if (disableMasterPluginInSettings(settings)) {
    console.log(
      `  ${yellow}!${reset} Disabled plugin ${cyan}${MASTER_PLUGIN_KEY}${reset} — npm framework is the active path (hooks must not double-fire)`
    );
  }

  fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`, 'utf8');
  console.log(`  ${green}✓${reset} Updated settings.json (framework root, hooks)`);
}


function statusLineCommandFor(configDir) {
  const homeClaude = path.join(os.homedir(), '.claude');
  if (path.resolve(configDir) === path.resolve(homeClaude)) {
    return 'python3 "$HOME/.claude/statusline.sh"';
  }
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

/** Install user-level statusline (~/.claude/statusline.sh) and wire settings.json. */
function installStatusline(configDir) {
  const src = path.join(PKG_ROOT, '.claude', 'statusline.sh');
  if (!fs.existsSync(src)) {
    console.log(`  ${yellow}!${reset} statusline.sh missing from package — skip`);
    return;
  }

  const homeClaude = path.join(os.homedir(), '.claude');
  const dest = path.join(configDir, 'statusline.sh');
  fs.mkdirSync(configDir, { recursive: true });
  fs.copyFileSync(src, dest);
  try {
    fs.chmodSync(dest, 0o755);
  } catch {
    /* best-effort */
  }
  const destLabel =
    path.resolve(configDir) === path.resolve(homeClaude) ? '~/.claude/statusline.sh' : dest;
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


/**
 * Install curated vercel-labs skills into ~/.claude/skills (best-effort).
 * Never fails the harness install. Claude plugins remain hints-only.
 */
function installDefaultSkills(frameworkRoot) {
  if (process.env.MASTER_SKIP_SKILLS === '1') {
    console.log(`  ${dim}skip: MASTER_SKIP_SKILLS=1 — default skills not installed${reset}`);
    return;
  }
  const script = path.join(frameworkRoot, 'scripts', 'install-default-skills.sh');
  const allowlist = path.join(frameworkRoot, 'templates', 'skills-allowlist.json');
  const fallbackScript = path.join(PKG_ROOT, 'scripts', 'install-default-skills.sh');
  const fallbackAllow = path.join(PKG_ROOT, 'templates', 'skills-allowlist.json');
  const sh = fs.existsSync(script) ? script : fallbackScript;
  const allow = fs.existsSync(allowlist) ? allowlist : fallbackAllow;
  if (!fs.existsSync(sh) || !fs.existsSync(allow)) {
    console.log(`  ${yellow}!${reset} default skills script/allowlist missing — skip`);
    return;
  }
  console.log(`  ${dim}Installing curated skills (npx skills → ~/.claude/skills)…${reset}`);
  const result = spawnSync('bash', [sh, allow], {
    encoding: 'utf8',
    timeout: 180000,
    env: { ...process.env },
  });
  const out = `${result.stdout || ''}${result.stderr || ''}`.trim();
  if (out) {
    for (const line of out.split('\n')) {
      console.log(line.startsWith(' ') ? line : `  ${line}`);
    }
  }
  if (result.error) {
    console.log(`  ${yellow}!${reset} skill install error: ${result.error.message} (harness install continues)`);
  }
}


/**
 * Warn when both npm shared framework and the Claude Code plugin are active
 * (hooks can double-fire). Prefer --repair which disables the plugin.
 */
function warnDualInstall(configDir) {
  const frameworkDir = path.join(configDir, 'claude-master-setup');
  const hasNpmFramework = fs.existsSync(frameworkDir);
  const pluginEnabled = isMasterPluginEnabled(configDir);
  if (hasNpmFramework && pluginEnabled) {
    console.log(`
  ${yellow}! Dual install detected${reset}: npm framework at ${cyan}${frameworkDir.replace(os.homedir(), '~')}${reset}
    AND plugin ${cyan}${MASTER_PLUGIN_KEY}${reset} enabled. Hooks may double-fire.
    Run ${cyan}npx claude-master-setup --repair${reset} to keep npm and disable the plugin.
`);
  }
}

/**
 * Read-only health check. Exit 0 = healthy, 1 = problems.
 */
function runDoctor(configDir) {
  const label = configDir.replace(os.homedir(), '~');
  console.log(`  ${yellow}Doctor${reset} — checking ${cyan}${label}${reset}\n`);

  const problems = [];
  const warnings = [];
  const frameworkDir = path.join(configDir, 'claude-master-setup');
  const settingsPath = path.join(configDir, 'settings.json');

  if (!fs.existsSync(frameworkDir)) {
    problems.push(`Missing framework dir: ${label}/claude-master-setup/`);
  } else {
    for (const script of HARNESS_HOOK_SCRIPTS) {
      const p = path.join(frameworkDir, 'hooks', script);
      if (!fs.existsSync(p)) problems.push(`Missing hook: hooks/${script}`);
    }
    for (const name of ['install-skill.sh', 'ensure-skills.sh', 'select-skills.sh']) {
      const p = path.join(frameworkDir, 'scripts', name);
      if (!fs.existsSync(p)) problems.push(`Missing script: scripts/${name}`);
    }
    for (const name of ['setup-loop.sh', 'validate.sh', 'classify-task.py', 'append-loop-event.py']) {
      const p = path.join(frameworkDir, 'scripts', name);
      if (fs.existsSync(p)) warnings.push(`Legacy script still present: scripts/${name}`);
    }
  }

  let settings = null;
  if (!fs.existsSync(settingsPath)) {
    problems.push(`Missing settings.json at ${label}/`);
  } else {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch (err) {
      problems.push(`settings.json parse error: ${err.message}`);
    }
  }

  if (settings) {
    const env = settings.env || {};
    if (!env.CLAUDE_MASTER_ROOT) {
      problems.push('settings.env.CLAUDE_MASTER_ROOT is not set');
    } else if (
      fs.existsSync(frameworkDir) &&
      path.resolve(env.CLAUDE_MASTER_ROOT) !== path.resolve(frameworkDir)
    ) {
      warnings.push(
        `CLAUDE_MASTER_ROOT (${env.CLAUDE_MASTER_ROOT}) ≠ framework dir (${frameworkDir})`
      );
    }
    if (env.HARNESS_FRAMEWORK_ROOT) {
      problems.push('Legacy settings.env.HARNESS_FRAMEWORK_ROOT still set — run --repair');
    }

    const hooks = settings.hooks || {};
    const idCounts = countHarnessIds(hooks);
    for (const id of EXPECTED_HARNESS_IDS) {
      const n = idCounts[id] || 0;
      if (n === 0) problems.push(`Missing harness hook id: ${id}`);
      else if (n > 1) problems.push(`Duplicate harness hook id ${id} (count=${n}) — run --repair`);
    }
    // Legacy / ID-less master hooks
    let legacy = 0;
    for (const entries of Object.values(hooks)) {
      if (!Array.isArray(entries)) continue;
      for (const e of entries) {
        if (!isMasterOwnedHookEntry(e)) continue;
        const id = e && e.id;
        if (typeof id !== 'string' || !id.startsWith('harness:')) legacy += 1;
        else {
          const cmds = (e.hooks || []).map((h) => h.command || '').join(' ');
          if (cmds.includes('HARNESS_FRAMEWORK_ROOT')) legacy += 1;
        }
      }
    }
    if (legacy > 0) {
      problems.push(`Found ${legacy} legacy Master hook entr(y/ies) — run --repair`);
    }

    if (fs.existsSync(frameworkDir) && (settings.enabledPlugins || {})[MASTER_PLUGIN_KEY]) {
      problems.push(
        `Dual install: npm framework present AND ${MASTER_PLUGIN_KEY} enabled — run --repair`
      );
    }
  }

  // Project-level stale foreign hooks (warn only)
  const projectSettings = path.join(process.cwd(), '.claude', 'settings.json');
  if (fs.existsSync(projectSettings)) {
    try {
      const raw = fs.readFileSync(projectSettings, 'utf8');
      if (
        raw.includes('plugin-hook-bootstrap.js') ||
        /"id"\s*:\s*"pre:bash:dispatcher"/.test(raw) ||
        /"id"\s*:\s*"post:bash:dispatcher"/.test(raw)
      ) {
        warnings.push(
          `Project .claude/settings.json has stale foreign (ECC-like) hooks — remove manually; do not embed foreign harnesses in project settings`
        );
      }
    } catch {
      /* ignore */
    }
  }

  if (isMasterPluginInstalled() && !isMasterPluginEnabled(configDir) && fs.existsSync(frameworkDir)) {
    warnings.push(
      `Plugin ${MASTER_PLUGIN_KEY} is installed but disabled (OK with npm path)`
    );
  }

  for (const w of warnings) {
    console.log(`  ${yellow}warn${reset}  ${w}`);
  }
  for (const p of problems) {
    console.log(`  ${yellow}FAIL${reset}  ${p}`);
  }
  if (problems.length === 0) {
    console.log(`  ${green}✓ Healthy${reset} — single-path npm framework, hooks deduped\n`);
    return 0;
  }
  console.log(
    `\n  ${yellow}${problems.length} problem(s)${reset}. Fix with: ${cyan}npx claude-master-setup --repair${reset}\n`
  );
  return 1;
}

/**
 * Re-install framework + rewrite hooks + enforce single path.
 */
function runRepair(configDir) {
  const label = configDir.replace(os.homedir(), '~');
  console.log(`  ${yellow}Repair${reset} — ${cyan}${label}${reset}\n`);

  const settingsPath = path.join(configDir, 'settings.json');
  let before = { harnessIds: {}, pluginEnabled: false, legacyEnv: false };
  if (fs.existsSync(settingsPath)) {
    try {
      const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      before.harnessIds = countHarnessIds(s.hooks || {});
      before.pluginEnabled = !!(s.enabledPlugins || {})[MASTER_PLUGIN_KEY];
      before.legacyEnv = !!(s.env || {}).HARNESS_FRAMEWORK_ROOT;
    } catch {
      /* ignore */
    }
  }
  const beforeDupes = Object.values(before.harnessIds).filter((n) => n > 1).length;
  console.log(
    `  ${dim}before:${reset} harness id dupes=${beforeDupes}, pluginEnabled=${before.pluginEnabled}, legacyEnv=${before.legacyEnv}`
  );

  const frameworkRoot = ensureFrameworkInstalled(configDir);
  installStatusline(configDir);
  // Skills are best-effort; skip by default on repair unless user wants them
  if (process.env.MASTER_SKIP_SKILLS !== '0') {
    process.env.MASTER_SKIP_SKILLS = process.env.MASTER_SKIP_SKILLS || '1';
  }
  installDefaultSkills(frameworkRoot);
  warnDualInstall(configDir);

  let after = { harnessIds: {}, pluginEnabled: false, legacyEnv: false };
  if (fs.existsSync(settingsPath)) {
    try {
      const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      after.harnessIds = countHarnessIds(s.hooks || {});
      after.pluginEnabled = !!(s.enabledPlugins || {})[MASTER_PLUGIN_KEY];
      after.legacyEnv = !!(s.env || {}).HARNESS_FRAMEWORK_ROOT;
    } catch {
      /* ignore */
    }
  }
  const afterDupes = Object.values(after.harnessIds).filter((n) => n > 1).length;
  console.log(
    `  ${dim}after:${reset}  harness id dupes=${afterDupes}, pluginEnabled=${after.pluginEnabled}, legacyEnv=${after.legacyEnv}`
  );
  console.log(`  ${green}Done!${reset} Re-run ${cyan}--doctor${reset} to verify.\n`);
}

function printCompanionNextSteps() {
  console.log(`
  ${yellow}Optional Claude plugins${reset} ${dim}(hints only — install what you need)${reset}:

    ${cyan}claude plugin marketplace add thedotmack/claude-mem${reset}
    ${cyan}claude plugin install claude-mem@thedotmack --scope user${reset}

    ${cyan}claude plugin install superpowers@claude-plugins-official --scope user${reset}
    ${cyan}claude plugin install code-review@claude-plugins-official --scope user${reset}

    ${cyan}claude plugin marketplace add sickn33/antigravity-awesome-skills${reset}
    ${cyan}claude plugin install antigravity-awesome-skills@antigravity-awesome-skills --scope user${reset}

  ${dim}Default skills:${reset} curated vercel-labs/agent-skills installed to ~/.claude/skills via npx skills
  ${dim}Discovery:${reset} /loop auto-selects ≤3 local skills (project .claude/.agents > user > plugin).
`);
}

function printUninstallHint(configDir) {
  const label = configDir.replace(os.homedir(), '~');
  console.log(`  ${dim}Uninstall: remove ${label}/claude-master-setup and the Agent Master command files${reset}`);
  console.log(`  ${dim}           plus master agent/hook entries from ${label}/settings.json${reset}`);
  console.log(`  ${dim}In project: delete AGENTS.md, CLAUDE.md, .cursor/rules/master-protocol.mdc, and .master/${reset}`);
}

/**
 * Install shared framework only (--framework-only / --global alias).
 * Does not seed any project.
 */
function installFrameworkOnly() {
  const configDir = expandTilde(explicitConfigDir) || path.join(os.homedir(), '.claude');
  const label = configDir.replace(os.homedir(), '~');

  console.log(`  Installing shared framework to ${cyan}${label}${reset}\n`);

  const frameworkRoot = ensureFrameworkInstalled(configDir);
  installStatusline(configDir);
  installDefaultSkills(frameworkRoot);
  warnDualInstall(configDir);
  printCompanionNextSteps();

  console.log(`  ${green}Done!${reset} Shared framework installed at ${cyan}${label}/claude-master-setup/${reset}`);
  console.log(`  Run ${cyan}claude${reset} in any project, then ${cyan}/bootstrap${reset} (or ${cyan}/master:bootstrap${reset}
  if installed as a plugin) to seed that project's ${cyan}.master/${reset}, then ${cyan}/loop "task"${reset}.
`);
  printUninstallHint(configDir);
  console.log();
}

/**
 * Default install: framework + seed current project's .master/.
 * Skip seed when run inside the harness source repo itself.
 * This is what runs for `npx claude-master-setup` (no flags) and --local.
 */
function installDefault() {
  const projectRoot = path.resolve(process.cwd());
  const pkgRoot = path.resolve(PKG_ROOT);
  const configDir = expandTilde(explicitConfigDir) || path.join(os.homedir(), '.claude');
  const configLabel = configDir.replace(os.homedir(), '~');
  const isSourceRepo = projectRoot === pkgRoot;

  if (!isSourceRepo) {
    console.log(
      `  Installing shared framework to ${cyan}${configLabel}${reset} and seeding ${cyan}${projectRoot}${reset}\n`
    );
  } else {
    console.log(`  Installing shared framework to ${cyan}${configLabel}${reset}\n`);
    console.log(
      `  ${yellow}Note:${reset} Running inside the Claude Master Setup source repo — skipping project seed.\n` +
        `  ${dim}This repo is the framework source, not a consumer project. Use from another project to seed .master/.${reset}\n`
    );
  }

  const frameworkRoot = ensureFrameworkInstalled(configDir);
  installStatusline(configDir);
  installDefaultSkills(frameworkRoot);
  warnDualInstall(configDir);

  let touched = [];
  if (!isSourceRepo) {
    touched = seedMasterFolder(projectRoot, frameworkRoot);
  }

  printCompanionNextSteps();

  // Success summary
  console.log(`  ${green}✓ Installation complete${reset}\n`);
  console.log(`  ${yellow}What was installed:${reset}`);
  console.log(`    ${cyan}Shared framework${reset}  → ${configLabel}/claude-master-setup/ (agents, commands, statusline, scripts, hooks)`);
  if (!isSourceRepo && touched.length > 0) {
    console.log(`    ${cyan}Project files${reset}     → ${projectRoot}/`);
    for (const f of touched) {
      console.log(`      ${green}+${reset} ${f}`);
    }
  }
  console.log();
  if (!isSourceRepo) {
    console.log(`  ${yellow}Next steps:${reset}`);
    console.log(`    ${cyan}claude${reset}           # open Claude Code`);
    console.log(`    ${cyan}/init${reset}            # initialize shared project context`);
    console.log(`    ${cyan}/start "goal"${reset}    # start a portable run`);
    console.log(`    ${cyan}/status${reset}          # inspect repository-backed state`);
    console.log(`    ${cyan}/handoff${reset}         # preserve context before ending a session`);
  } else {
    console.log(`  Run ${cyan}claude${reset} in any project, then ${cyan}/init${reset} to initialize that project's shared ${cyan}.master/${reset} state.`);
  }
  console.log();
  printUninstallHint(configDir);
  console.log();
}

/** Legacy: scaffold harness into an explicit directory (old npx behavior). */
function installScaffold(target) {
  const dest = path.resolve(process.cwd(), target || '.');
  fs.mkdirSync(dest, { recursive: true });
  console.log(`  Scaffolding into ${cyan}${dest}${reset}\n`);

  const prev = process.cwd();
  process.chdir(dest);
  try {
    installDefault();
  } finally {
    process.chdir(prev);
  }
}

function main() {
  const first = args[0];
  const universalCommands = new Set([
    'init',
    'start',
    'status',
    'inspect',
    'checkpoint',
    'validate',
    'handoff',
    'complete',
    'pause',
    'cancel',
    'claim',
    'release',
    'doctor',
    'pack',
    'help',
  ]);

  // Only route to the universal project CLI when an explicit subcommand is
  // given. Bare invocation (no args) and bare --help/-h fall through to the
  // installer below, matching the documented default: "no flags installs
  // the shared framework". Previously `args.length === 0` routed here too,
  // which silently replaced the framework install with a local `init`
  // scaffold for every existing `npx claude-master-setup` user.
  if (universalCommands.has(first)) {
    try {
      const response = runUniversalCli(args, {
        packageRoot: PKG_ROOT,
        templatesRoot: path.join(PKG_ROOT, 'templates'),
        packageName: pkg.name,
      });
      if (response.output) console.log(response.output);
      process.exitCode = response.exitCode;
    } catch (error) {
      if (error instanceof AgentMasterError) {
        console.error(`Agent Master: ${error.message}`);
        if (error.details) console.error(JSON.stringify(error.details, null, 2));
        process.exitCode = error.exitCode;
        return;
      }
      throw error;
    }
    return;
  }

  if (first === 'install') {
    const provider = args[1];
    if (!['claude', 'claude-code', 'codex', 'cursor'].includes(provider)) {
      console.error(`  ${yellow}Unknown provider: ${provider || '(missing)'}. v1.1 supports: claude, codex, cursor${reset}`);
      process.exitCode = 2;
      return;
    }
    console.log(banner);
    if (provider === 'claude' || provider === 'claude-code') {
      requireClaudeCodeOrExit();
      installFrameworkOnly();
      return;
    }
    if (provider === 'codex') {
      const codexHome = process.env.CODEX_HOME
        ? expandTilde(process.env.CODEX_HOME)
        : path.join(os.homedir(), '.codex');
      const source = path.join(PKG_ROOT, 'adapters', 'codex', 'skills', 'agent-master');
      const destination = path.join(codexHome, 'skills', 'agent-master');
      if (fs.existsSync(destination)) {
        const backup = backupIfExists(destination);
        console.log(`  ${dim}↳ backed up existing Codex skill → ${path.basename(backup)}${reset}`);
      }
      copyRecursive(source, destination);
      console.log(`  ${green}✓${reset} Installed Codex skill at ${cyan}${destination}${reset}`);
      console.log(`  Start a new Codex task, then use ${cyan}$agent-master${reset} in a repository initialized with Agent Master.`);
      return;
    }
    const result = initProject(process.cwd(), path.join(PKG_ROOT, 'templates'));
    console.log(`  ${green}✓${reset} Cursor project rule ready in ${cyan}${result.root}${reset}`);
    console.log(`  Cursor uses AGENTS.md, its native session lifecycle, and the Agent Master CLI.`);
    return;
  }

  if (process.platform === 'win32') {
    console.error(
      `  ${yellow}Hooks/scripts expect a Unix shell. Prefer macOS/Linux or WSL.${reset}`
    );
  }

  if (hasHelp) {
    printHelp();
    return;
  }

  if (hasDoctor && hasRepair) {
    console.error(`  ${yellow}Cannot combine --doctor with --repair${reset}`);
    process.exit(1);
  }
  if ((hasDoctor || hasRepair) && (hasGlobal || hasFrameworkOnly || hasLocal || wantsScaffold)) {
    console.error(
      `  ${yellow}Cannot combine --doctor/--repair with install flags (--framework-only/--local/--scaffold)${reset}`
    );
    process.exit(1);
  }

  if ((hasGlobal || hasFrameworkOnly) && hasLocal) {
    console.error(`  ${yellow}Cannot combine --framework-only/--global with --local${reset}`);
    process.exit(1);
  }
  if (explicitConfigDir && hasLocal) {
    console.error(`  ${yellow}Cannot use --config-dir with --local (--local always uses the default config dir + this project)${reset}`);
    process.exit(1);
  }

  console.log(banner);

  const configDir = expandTilde(explicitConfigDir) || path.join(os.homedir(), '.claude');

  if (hasDoctor) {
    const code = runDoctor(configDir);
    process.exit(code);
  }

  if (hasRepair) {
    requireClaudeCodeOrExit();
    runRepair(configDir);
    return;
  }

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

  if (hasGlobal || hasFrameworkOnly) {
    // Framework only — do not seed a project
    installFrameworkOnly();
  } else {
    // Default and --local: framework + seed current project
    installDefault();
  }
}

main();
