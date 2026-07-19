#!/usr/bin/env node
'use strict';
/**
 * Installs the Claude Master Setup harness into Claude Code.
 *
 * Framework files (agents, commands, skills, scripts, docs, hooks) live once,
 * shared, at the resolved config dir — never duplicated per project.
 * A project only ever gets `.master/` (state + its own docs) + `CLAUDE.md`.
 *
 * Usage:
 *   npx claude-master-setup                   # install framework + seed current project
 *   npx claude-master-setup --framework-only  # install shared framework only (no project seed)
 *   npx claude-master-setup --global          # alias for --framework-only
 *   npx claude-master-setup --local           # alias for default (framework + seed)
 *   npx claude-master-setup --scaffold [dir]  # legacy: copy harness into a folder
 */
const fs = require('fs');
const path = require('path');
const os = require('os');
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
  Adaptive coding loops for Claude Code
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
  'validate.sh',
  'worktree-fanout.sh',
  'setup-loop.sh',
  'cancel-loop.sh',
  'classify-task.py',
  'write-handoff.py',
];

const args = process.argv.slice(2);
const hasGlobal = args.includes('--global') || args.includes('-g');
const hasLocal = args.includes('--local') || args.includes('-l');
const hasFrameworkOnly = args.includes('--framework-only') || args.includes('-F');
const hasHelp = args.includes('--help') || args.includes('-h');
const hasForce = args.includes('--force') || args.includes('-f');
const scaffoldIdx = args.findIndex((a) => a === '--scaffold' || a === '-s');
const wantsScaffold = scaffoldIdx !== -1;

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
    project's ${cyan}.master/${reset} + ${cyan}CLAUDE.md${reset}. Skip seed when run inside the harness
    source repo itself. This is the recommended path for every new project.

  ${yellow}Options:${reset}
    ${cyan}--framework-only, -F${reset}      Install shared framework only — do not seed a project
    ${cyan}--global, -g${reset}              Alias for --framework-only (kept for backward compat)
    ${cyan}--local, -l${reset}               Alias for default (framework + seed current project)
    ${cyan}-c, --config-dir <path>${reset}   Custom Claude config dir (overrides CLAUDE_CONFIG_DIR env)
    ${cyan}-s, --scaffold [dir]${reset}      Legacy: copy full harness into a directory
    ${cyan}-f, --force${reset}               Install even if Claude Code CLI is missing
    ${cyan}-h, --help${reset}                Show this help

  ${yellow}Config dir resolution (in order):${reset}
    1. ${cyan}--config-dir <path>${reset}    explicit flag
    2. ${cyan}CLAUDE_CONFIG_DIR${reset}      environment variable
    3. ${cyan}~/.claude${reset}              default

  ${yellow}What gets installed:${reset}
    ${dim}Shared framework${reset}   agents/  commands/  statusline.sh  claude-master-setup/ (scripts, hooks, docs, templates)
    ${dim}Per-project${reset}        .master/ (state + starter docs, gitignored state)  CLAUDE.md

  ${yellow}Five-minute tour (plugin path):${reset}
    ${cyan}claude plugin marketplace add AnupDangi/Claude-Master-Setup${reset}
    ${cyan}claude plugin install master@claude-master-setup${reset}
    Then: ${cyan}/master:bootstrap${reset} → ${cyan}/master:loop${reset} → ${cyan}/master:status${reset} → ${cyan}/master:pause${reset} → ${cyan}/master:handoff${reset}

  ${yellow}Uninstall:${reset}
    Remove ${cyan}~/.claude/claude-master-setup/${reset}, ${cyan}~/.claude/agents/</cyan>, ${cyan}~/.claude/commands/${reset}
    Remove the master blocks from ${cyan}~/.claude/settings.json${reset} (hooks, CLAUDE_MASTER_ROOT)
    In project: delete ${cyan}CLAUDE.md${reset} and ${cyan}.master/${reset}
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
      fs.writeFileSync(dest, content.split('${CLAUDE_PLUGIN_ROOT}').join(replacement), 'utf8');
    } else {
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
          checked_at: null,
        },
        next_action: null,
        pause_reason: null,
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
 * Seed a project's `.master/` (state + starter docs) and `./CLAUDE.md` — the
 * only things this harness ever puts in a project. Never overwrites existing
 * files. `frameworkRoot` is the shared install (for CLAUDE.md.starter's own
 * ${CLAUDE_PLUGIN_ROOT} references, which get the same copy-time substitution).
 *
 * Returns an array of strings describing what was touched (for success summary).
 */
function seedMasterFolder(projectRoot, frameworkRoot) {
  console.log('  Seeding .master/…');
  const touched = [];
  const metadata = inferProjectMetadata(projectRoot);

  const stateDir = path.join(projectRoot, '.master', 'state');
  fs.mkdirSync(stateDir, { recursive: true });
  const loopPath = path.join(stateDir, 'loop.json');
  if (!fs.existsSync(loopPath)) {
    fs.writeFileSync(loopPath, loopStateJson(), 'utf8');
    touched.push('.master/state/loop.json');
  }
  console.log(`  ${green}✓${reset} .master/state/ initialized`);

  const docsDir = path.join(projectRoot, '.master', 'docs');
  fs.mkdirSync(docsDir, { recursive: true });
  const roadmapSrc = path.join(PKG_ROOT, 'templates', 'master-docs', 'ROADMAP.md');
  const roadmapDest = path.join(docsDir, 'ROADMAP.md');
  if (!fs.existsSync(roadmapDest) && fs.existsSync(roadmapSrc)) {
    fs.copyFileSync(roadmapSrc, roadmapDest);
    touched.push('.master/docs/ROADMAP.md');
  }
  console.log(`  ${green}✓${reset} .master/docs/ seeded (ROADMAP stub only)`);

  const projectJsonSrc = path.join(PKG_ROOT, 'templates', 'project.json');
  const projectJsonDest = path.join(projectRoot, '.master', 'project.json');
  if (!fs.existsSync(projectJsonDest) && fs.existsSync(projectJsonSrc)) {
    const pj = fs.readFileSync(projectJsonSrc, 'utf8');
    const project = JSON.parse(pj);
    project.validate_cmd = String(project.validate_cmd || '').replace(
      '${CLAUDE_PLUGIN_ROOT}',
      frameworkRoot
    );
    project.name = metadata.name;
    project.maturity = metadata.maturity;
    project.stack = { detected: metadata.stack };
    project.commands = metadata.commands;
    fs.writeFileSync(projectJsonDest, `${JSON.stringify(project, null, 2)}\n`, 'utf8');
    touched.push('.master/project.json');
    console.log(`  ${green}✓${reset} .master/project.json created`);
  }

  const claudeMdDest = path.join(projectRoot, 'CLAUDE.md');
  if (!fs.existsSync(claudeMdDest)) {
    const starterSrc = path.join(PKG_ROOT, 'templates', 'CLAUDE.md.starter');
    if (fs.existsSync(starterSrc)) {
      const content = fs
        .readFileSync(starterSrc, 'utf8')
        .split('${CLAUDE_PLUGIN_ROOT}').join(frameworkRoot)
        .split('{{PROJECT_NAME}}').join(metadata.name)
        .split('{{MISSION}}').join(metadata.mission)
        .split('{{STACK}}').join(metadata.stack)
        .split('{{RUN_COMMANDS}}').join(metadata.commands.length ? metadata.commands.map((c) => `- ${c}`).join('\n') : '- Inspect project configuration');
      fs.writeFileSync(claudeMdDest, content, 'utf8');
      touched.push('CLAUDE.md');
      console.log(`  ${green}✓${reset} CLAUDE.md created`);
    }
  } else {
    console.log(`  ${dim}skip (already exists): CLAUDE.md${reset}`);
  }

  const giPath = path.join(projectRoot, '.gitignore');
  if (!fs.existsSync(giPath)) fs.writeFileSync(giPath, '', 'utf8');
  let gi = fs.readFileSync(giPath, 'utf8');
  const lines = gi.split(/\r?\n/);
  // Ignore secrets + loop state if the project later creates them — do not seed .env files.
  const patterns = ['.env', '.env.*', '.master/state/'];
  let changed = false;
  for (const pat of patterns) {
    if (!lines.includes(pat)) {
      gi = gi.endsWith('\n') || gi === '' ? `${gi}${pat}\n` : `${gi}\n${pat}\n`;
      changed = true;
    }
  }
  if (changed) {
    fs.writeFileSync(giPath, gi, 'utf8');
    touched.push('.gitignore (updated)');
  }
  console.log(`  ${green}✓${reset} .gitignore updated (.env* and .master/state/ excluded)`);
  console.log(`  ${green}✓${reset} node ${process.version}`);

  return touched;
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
  const obsoleteCommands = ['decide', 'evaluate', 'go', 'init', 'mcp-add', 'plan', 'review', 'ship', 'validate'];
  const obsoleteAgents = ['docs-writer', 'evaluator', 'mcp-scout', 'security'];
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
  for (const item of ['MASTER-PROMPT.md', 'templates']) {
    const src = path.join(PKG_ROOT, item);
    if (!fs.existsSync(src)) continue;
    const dest = path.join(packDest, item);
    copyRecursive(src, dest);
  }

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
  console.log(`  ${green}✓${reset} Installed claude-master-setup/ (shared framework: docs, scripts, hooks, templates)`);

  mergeFrameworkSettings(configDir, frameworkRoot);
  return frameworkRoot;
}

/** The 5 hooks, wired via $CLAUDE_MASTER_ROOT (mirrors .claude-plugin/plugin.json's ${CLAUDE_PLUGIN_ROOT} form). */
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
    PostToolUse: [
      {
        matcher: 'Write|Edit|MultiEdit',
        hooks: [{ type: 'command', command: h('post-edit-track'), async: true, timeout: 15 }],
        description: 'Record edited source files so the loop knows validation is pending',
        id: 'harness:post-edit-track',
      },
    ],
    Stop: [
      {
        matcher: '*',
        hooks: [{ type: 'command', command: h('loop-stop-hook') }],
        description: 'Re-feed /loop task on Stop until max iterations or completion promise',
        id: 'harness:loop-stop',
      },
      {
        matcher: '*',
        hooks: [{ type: 'command', command: h('stop-validate-reminder'), async: true, timeout: 10 }],
        description: 'Remind to run the validation gate if source changed but validate did not run',
        id: 'harness:stop-validate-reminder',
      },
    ],
  };
}


/**
 * Merge harness hook phases without wiping user hooks.
 * Replaces only entries whose id starts with "harness:"; keeps all other hooks.
 */
function mergeHookPhases(existingHooks, harnessHooks) {
  const out = { ...(existingHooks || {}) };
  for (const [phase, harnessEntries] of Object.entries(harnessHooks || {})) {
    const prev = Array.isArray(out[phase]) ? out[phase] : [];
    const nonHarness = prev.filter(
      (e) => !(e && typeof e.id === 'string' && e.id.startsWith('harness:'))
    );
    out[phase] = [...nonHarness, ...(harnessEntries || [])];
  }
  return out;
}

/**
 * Merge the shared framework root and hooks into settings.json. Never deletes unrelated keys.
 * Note: if the `master` Claude Code plugin is ALSO installed on this machine,
 * hooks fire twice (Claude Code doesn't dedupe hooks from two sources) — the
 * npm path and the plugin path are meant to be mutually exclusive per machine
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

  settings.env = {
    ...(settings.env || {}),
    CLAUDE_MASTER_ROOT: frameworkRoot,
  };
  settings.hooks = mergeHookPhases(settings.hooks, harnessHooksBlock());

  fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}
`, 'utf8');
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

function printCompanionNextSteps() {
  console.log(`
  ${yellow}Skill / plugin ecosystem${reset} ${dim}(optional — install what you need)${reset}:

    ${cyan}claude plugin marketplace add thedotmack/claude-mem${reset}
    ${cyan}claude plugin install claude-mem@thedotmack --scope user${reset}

    ${cyan}claude plugin install superpowers@claude-plugins-official --scope user${reset}
    ${cyan}claude plugin install code-review@claude-plugins-official --scope user${reset}

    ${cyan}claude plugin marketplace add sickn33/antigravity-awesome-skills${reset}
    ${cyan}claude plugin install antigravity-awesome-skills@antigravity-awesome-skills --scope user${reset}

  ${dim}Also usable:${reset} Claude Master skills, Matt Pocock / community skills under ~/.claude/skills
  ${dim}Discovery:${reset} /loop auto-selects ≤3 local skills per task (project > user > plugin).
`);
}

function printUninstallHint(configDir) {
  const label = configDir.replace(os.homedir(), '~');
  console.log(`  ${dim}Uninstall: remove ${label}/claude-master-setup and the six master command files${reset}`);
  console.log(`  ${dim}           plus master agent/hook entries from ${label}/settings.json${reset}`);
  console.log(`  ${dim}In project: delete CLAUDE.md and .master/${reset}`);
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
    console.log(`    ${cyan}/bootstrap${reset}       # or /master:bootstrap — understand repo → minimal .master/`);
    console.log(`    ${cyan}/loop${reset}            # or /master:loop — adaptive build until done or max-iterations`);
    console.log(`    ${cyan}/status${reset}          # or /master:status — where are we`);
    console.log(`    ${cyan}/handoff${reset}         # or /master:handoff — before ending a session`);
  } else {
    console.log(`  Run ${cyan}claude${reset} in any project, then ${cyan}/bootstrap${reset} (or ${cyan}/master:bootstrap${reset}) to scaffold and foundation that project's ${cyan}.master/${reset}.`);
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
  if (process.platform === 'win32') {
    console.error(
      `  ${yellow}Hooks/scripts expect a Unix shell. Prefer macOS/Linux or WSL.${reset}`
    );
  }

  if (hasHelp) {
    printHelp();
    return;
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
