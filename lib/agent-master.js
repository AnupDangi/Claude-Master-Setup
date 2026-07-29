'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const SCHEMA_VERSION = 2;
const ACTIVE_STATUSES = new Set(['active', 'paused', 'handoff']);
const TERMINAL_STATUSES = new Set(['completed', 'cancelled']);

class AgentMasterError extends Error {
  constructor(message, exitCode = 1, details = null) {
    super(message);
    this.name = 'AgentMasterError';
    this.exitCode = exitCode;
    this.details = details;
  }
}

function nowIso() {
  return new Date().toISOString();
}

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function writeJsonAtomic(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temp = `${file}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(temp, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  fs.renameSync(temp, file);
}

function writeTextIfAbsent(file, content) {
  if (fs.existsSync(file)) return false;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
  return true;
}

function findProjectRoot(start = process.cwd()) {
  let cursor = path.resolve(start);
  while (true) {
    if (fs.existsSync(path.join(cursor, '.git')) || fs.existsSync(path.join(cursor, '.master'))) {
      return cursor;
    }
    const parent = path.dirname(cursor);
    if (parent === cursor) return path.resolve(start);
    cursor = parent;
  }
}

function masterPaths(root) {
  const master = path.join(root, '.master');
  return {
    root,
    master,
    project: path.join(master, 'project.json'),
    activeRun: path.join(master, 'active-run'),
    runs: path.join(master, 'runs'),
    eventsDir: path.join(master, 'events'),
    events: path.join(master, 'events', 'events.jsonl'),
    evidence: path.join(master, 'evidence'),
    locks: path.join(master, 'locks'),
    legacyState: path.join(master, 'state'),
  };
}

function ensureRuntimeDirs(paths) {
  for (const dir of [paths.runs, paths.eventsDir, paths.evidence, paths.locks]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function git(root, args, options = {}) {
  const result = spawnSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
    ...options,
  });
  return {
    ok: !result.error && result.status === 0,
    status: typeof result.status === 'number' ? result.status : 1,
    stdout: (result.stdout || '').trimEnd(),
    stderr: (result.stderr || '').trimEnd(),
    error: result.error || null,
  };
}

function isGitRepository(root) {
  return git(root, ['rev-parse', '--is-inside-work-tree']).stdout === 'true';
}

function changedFilesFromPorcelain(output) {
  const files = [];
  for (const line of output.split(/\r?\n/)) {
    if (!line) continue;
    const raw = line.slice(3);
    const target = raw.includes(' -> ') ? raw.split(' -> ').pop() : raw;
    if (target && !target.startsWith('.master/')) files.push(target);
  }
  return [...new Set(files)].sort();
}

function repositorySnapshot(root) {
  if (!isGitRepository(root)) {
    return {
      branch: null,
      base_commit: null,
      head_commit: null,
      working_tree_clean: null,
      changed_files: [],
      git_available: false,
    };
  }
  const branch = git(root, ['branch', '--show-current']).stdout || null;
  const head = git(root, ['rev-parse', 'HEAD']);
  const status = git(root, ['status', '--porcelain=v1', '--untracked-files=all']);
  return {
    branch,
    base_commit: null,
    head_commit: head.ok ? head.stdout : null,
    working_tree_clean: status.ok ? status.stdout.length === 0 : null,
    changed_files: status.ok ? changedFilesFromPorcelain(status.stdout) : [],
    git_available: true,
  };
}

function workingTreeFingerprint(root) {
  const hash = crypto.createHash('sha256');
  if (!isGitRepository(root)) {
    hash.update('not-a-git-repository');
    return hash.digest('hex');
  }

  const head = git(root, ['rev-parse', 'HEAD']).stdout;
  const status = git(root, ['status', '--porcelain=v1', '--untracked-files=all']).stdout;
  const diff = git(root, ['diff', '--binary', 'HEAD', '--', '.', ':(exclude).master']).stdout;
  hash.update(head);
  hash.update('\0');
  hash.update(status);
  hash.update('\0');
  hash.update(diff);

  for (const file of changedFilesFromPorcelain(status)) {
    const absolute = path.join(root, file);
    try {
      const stat = fs.statSync(absolute);
      if (stat.isFile()) {
        hash.update('\0');
        hash.update(file);
        hash.update('\0');
        hash.update(fs.readFileSync(absolute));
      }
    } catch {
      hash.update(`\0missing:${file}`);
    }
  }
  return hash.digest('hex');
}

function commandExists(command) {
  const result = spawnSync(process.platform === 'win32' ? 'where' : 'sh', process.platform === 'win32'
    ? [command]
    : ['-c', `command -v "${command.replace(/"/g, '\\"')}"`], {
    encoding: 'utf8',
  });
  return !result.error && result.status === 0;
}

function inferProject(root) {
  const exists = (rel) => fs.existsSync(path.join(root, rel));
  const packageJson = readJson(path.join(root, 'package.json'), {});
  const projectId = String(packageJson.name || path.basename(root))
    .replace(/^@/, '')
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'project';
  const scripts = packageJson.scripts || {};
  const testCommands = [];
  for (const name of ['lint', 'typecheck', 'test']) {
    if (scripts[name]) testCommands.push(`npm run ${name}`);
  }
  let installCommand = null;
  if (exists('pnpm-lock.yaml')) installCommand = 'pnpm install';
  else if (exists('yarn.lock')) installCommand = 'yarn install';
  else if (exists('package.json')) installCommand = 'npm install';
  else if (exists('pyproject.toml')) installCommand = 'python -m pip install -e .';

  let buildCommand = scripts.build ? 'npm run build' : null;
  if (!buildCommand && exists('Cargo.toml')) buildCommand = 'cargo build';
  if (!buildCommand && exists('go.mod')) buildCommand = 'go build ./...';

  if (testCommands.length === 0) {
    if (exists('pyproject.toml') || exists('pytest.ini') || exists('tests')) testCommands.push('pytest -q');
    else if (exists('Cargo.toml')) testCommands.push('cargo test');
    else if (exists('go.mod')) testCommands.push('go test ./...');
    else if (exists('Makefile')) testCommands.push('make test');
  }

  const hasSource = ['src', 'app', 'lib', 'cmd'].some(exists);
  const hasTests = testCommands.length > 0;
  const hasCi = exists('.github/workflows') || exists('.gitlab-ci.yml');
  const maturity = hasCi && hasTests ? 'production' : hasSource && hasTests ? 'existing' : hasSource ? 'prototype' : 'new';
  const sources = ['src', 'app', 'lib', 'cmd', 'tests', 'test', 'README.md'].filter(exists);

  return {
    schema_version: SCHEMA_VERSION,
    project_id: projectId,
    name: packageJson.name || path.basename(root),
    maturity,
    install_command: installCommand,
    test_commands: testCommands,
    build_command: buildCommand,
    runtime_check: null,
    sources_of_truth: sources.length > 0 ? sources : ['README.md'],
  };
}

function normalizeProject(project, root) {
  const inferred = inferProject(root);
  if (!project || typeof project !== 'object') return inferred;
  if (project.schema_version === SCHEMA_VERSION) {
    return {
      ...inferred,
      ...project,
      schema_version: SCHEMA_VERSION,
      project_id: project.project_id || project.name || inferred.project_id,
      test_commands: Array.isArray(project.test_commands) ? project.test_commands : inferred.test_commands,
      sources_of_truth: Array.isArray(project.sources_of_truth)
        ? project.sources_of_truth
        : Array.isArray(project.source_of_truth)
          ? project.source_of_truth
          : inferred.sources_of_truth,
    };
  }

  const commands = Array.isArray(project.commands) ? project.commands : [];
  const extracted = commands
    .map((entry) => String(entry).replace(/^[^:]+:\s*/, '').trim())
    .filter(Boolean);
  const legacyValidation = typeof project.validate_cmd === 'string' && project.validate_cmd.trim()
    ? [project.validate_cmd.trim()]
    : [];
  return {
    ...inferred,
    schema_version: SCHEMA_VERSION,
    project_id: project.name || inferred.project_id,
    name: project.name || inferred.name,
    maturity: project.maturity || inferred.maturity,
    install_command: project.install_command || inferred.install_command,
    test_commands: legacyValidation.length > 0 ? legacyValidation : extracted.length > 0 ? extracted : inferred.test_commands,
    build_command: project.build_command || inferred.build_command,
    runtime_check: project.runtime_check || null,
    sources_of_truth: project.sources_of_truth || project.source_of_truth || inferred.sources_of_truth,
    migration: {
      from_schema_version: project.schema_version || 1,
      migrated_at: nowIso(),
    },
  };
}

function validationCommands(project) {
  const commands = [];
  for (const command of project.test_commands || []) {
    if (typeof command === 'string' && command.trim()) commands.push({ kind: 'test', command: command.trim() });
  }
  if (typeof project.build_command === 'string' && project.build_command.trim()) {
    commands.push({ kind: 'build', command: project.build_command.trim() });
  }
  if (typeof project.runtime_check === 'string' && project.runtime_check.trim()) {
    commands.push({ kind: 'runtime', command: project.runtime_check.trim() });
  }
  return commands;
}

function validationConfigHash(project) {
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(validationCommands(project)))
    .digest('hex');
}

// .master/project.json is repo-committed and can be edited by anyone with
// write access to the repo (including a fresh clone of an untrusted repo).
// Its test/build/runtime commands run locally with the caller's privileges
// via spawnSync(shell:true), so we require an explicit, machine-local
// trust decision per exact command set before ever executing them.
function trustStorePath() {
  return path.join(os.homedir(), '.claude', 'agent-master-trust.json');
}

function readTrustStore() {
  const data = readJson(trustStorePath());
  return data && typeof data === 'object' ? data : {};
}

function isProjectTrusted(root, hash) {
  const store = readTrustStore();
  const trusted = store[path.resolve(root)];
  return Array.isArray(trusted) && trusted.includes(hash);
}

function trustProject(root, hash) {
  const file = trustStorePath();
  const store = readTrustStore();
  const key = path.resolve(root);
  const trusted = new Set(store[key] || []);
  trusted.add(hash);
  store[key] = [...trusted];
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(store, null, 2)}\n`, 'utf8');
}

function slugify(value, fallback = 'run') {
  const slug = String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
  return slug || fallback;
}

function runPath(paths, runId) {
  return path.join(paths.runs, `${slugify(runId)}.json`);
}

function listRuns(paths) {
  if (!fs.existsSync(paths.runs)) return [];
  return fs.readdirSync(paths.runs)
    .filter((name) => name.endsWith('.json'))
    .map((name) => readJson(path.join(paths.runs, name)))
    .filter(Boolean)
    .sort((a, b) => String(b.updated_at || '').localeCompare(String(a.updated_at || '')));
}

function readActiveRunId(paths) {
  try {
    return fs.readFileSync(paths.activeRun, 'utf8').trim() || null;
  } catch {
    return null;
  }
}

function setActiveRun(paths, runId) {
  fs.mkdirSync(paths.master, { recursive: true });
  fs.writeFileSync(paths.activeRun, `${runId}\n`, 'utf8');
}

function resolveRun(paths, requested, { required = true } = {}) {
  const runId = requested || readActiveRunId(paths);
  if (!runId) {
    if (!required) return null;
    throw new AgentMasterError('No active run. Start one with: agent-master start "<goal>"', 2);
  }
  const file = runPath(paths, runId);
  const run = readJson(file);
  if (!run) throw new AgentMasterError(`Run not found: ${runId}`, 2);
  return { run, file, runId: run.run_id || runId };
}

function appendEvent(paths, type, run, detail = {}) {
  ensureRuntimeDirs(paths);
  const event = {
    schema_version: SCHEMA_VERSION,
    at: nowIso(),
    type,
    run_id: run && run.run_id ? run.run_id : detail.run_id || null,
    agent: detail.agent || (run && run.last_updated_by && run.last_updated_by.agent) || null,
    ...detail,
  };
  fs.appendFileSync(paths.events, `${JSON.stringify(event)}\n`, 'utf8');
  return event;
}

function readEvents(paths, runId = null) {
  if (!fs.existsSync(paths.events)) return [];
  return fs.readFileSync(paths.events, 'utf8')
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter((event) => event && (!runId || event.run_id === runId));
}

function acquireRunLock(paths, runId) {
  ensureRuntimeDirs(paths);
  const file = path.join(paths.locks, `${slugify(runId)}.lock`);
  const payload = JSON.stringify({ pid: process.pid, host: os.hostname(), created_at: nowIso() });
  try {
    const fd = fs.openSync(file, 'wx');
    fs.writeFileSync(fd, payload);
    fs.closeSync(fd);
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
    const existing = readJson(file, {});
    const age = existing.created_at ? Date.now() - Date.parse(existing.created_at) : Infinity;
    if (age > 60_000) {
      fs.unlinkSync(file);
      return acquireRunLock(paths, runId);
    }
    throw new AgentMasterError(`Run ${runId} is locked by another Agent Master process`, 3, existing);
  }
  return () => {
    try {
      fs.unlinkSync(file);
    } catch {
      // Best effort: stale locks are reclaimed after one minute.
    }
  };
}

function withRunLock(paths, runId, callback) {
  const release = acquireRunLock(paths, runId);
  try {
    return callback();
  } finally {
    release();
  }
}

function defaultRun(runId, goal, agent, repository) {
  const now = nowIso();
  return {
    schema_version: SCHEMA_VERSION,
    run_id: runId,
    goal,
    status: 'active',
    phase: 'planning',
    created_by: {
      agent,
      session_reference: null,
    },
    last_updated_by: {
      agent,
      session_reference: null,
    },
    repository: {
      ...repository,
      base_commit: repository.head_commit,
    },
    ownership: {
      files: [],
      lease_owner: null,
      lease_expires_at: null,
    },
    decisions: [],
    completed_tasks: [],
    commands_run: [],
    validation: {
      status: 'not_run',
      validated_commit: null,
      working_tree_fingerprint: null,
      config_hash: null,
      checks: [],
      evidence: [],
      checked_at: null,
      stale_reasons: [],
    },
    remaining_tasks: [],
    blockers: [],
    next_action: 'Inspect the repository and plan the smallest verifiable implementation.',
    created_at: now,
    updated_at: now,
    adapter_state: {
      'claude-code': {},
      codex: {},
      cursor: {},
    },
  };
}

function refreshRun(root, project, run) {
  const repository = repositorySnapshot(root);
  run.repository = {
    ...(run.repository || {}),
    ...repository,
    base_commit: run.repository && run.repository.base_commit
      ? run.repository.base_commit
      : repository.head_commit,
  };
  const validation = run.validation || {};
  const staleReasons = validation.status === 'stale'
    ? [...new Set(validation.stale_reasons || ['validation_evidence_stale'])]
    : [];
  if (validation.status === 'green') {
    if (!validation.validated_commit || validation.validated_commit !== repository.head_commit) {
      staleReasons.push('commit_changed');
    }
    const fingerprint = workingTreeFingerprint(root);
    if (!validation.working_tree_fingerprint || validation.working_tree_fingerprint !== fingerprint) {
      staleReasons.push('working_tree_changed');
    }
    if (!validation.config_hash || validation.config_hash !== validationConfigHash(project)) {
      staleReasons.push('validation_commands_changed');
    }
    const runtimeRequired = validationCommands(project).some((item) => item.kind === 'runtime');
    const runtimePassed = (validation.checks || []).some(
      (check) => check.kind === 'runtime' && check.exit_code === 0
    );
    if (runtimeRequired && !runtimePassed) staleReasons.push('runtime_check_missing');
  }
  validation.stale_reasons = staleReasons;
  if (validation.status === 'green' && staleReasons.length > 0) validation.status = 'stale';
  run.validation = validation;
  return run;
}

function updateActor(run, agent, sessionReference = null) {
  run.last_updated_by = {
    agent: agent || process.env.AGENT_NAME || process.env.MASTER_UPDATED_BY || 'unknown-agent',
    session_reference: sessionReference || null,
  };
  run.updated_at = nowIso();
}

function saveRun(paths, run, eventType = null, detail = {}) {
  writeJsonAtomic(runPath(paths, run.run_id), run);
  if (eventType) appendEvent(paths, eventType, run, detail);
  return run;
}

function migrateLegacyState(paths, project, agent = 'migration') {
  const loopFile = path.join(paths.legacyState, 'loop.json');
  const handoffFile = path.join(paths.legacyState, 'handoff.json');
  const loop = readJson(loopFile);
  const handoff = readJson(handoffFile);
  if (!loop && !handoff) return null;

  const existingMigrated = listRuns(paths).find(
    (run) => run.adapter_state && run.adapter_state['claude-code'] && run.adapter_state['claude-code'].legacy_migration
  );
  if (existingMigrated) return existingMigrated;

  const goal = (handoff && (handoff.task || handoff.goal)) || (loop && (loop.prompt || loop.task)) || 'Migrated Agent Master task';
  let runId = slugify(`migrated-${goal}`);
  let suffix = 2;
  while (fs.existsSync(runPath(paths, runId))) runId = `${slugify(`migrated-${goal}`).slice(0, 58)}-${suffix++}`;

  const repository = repositorySnapshot(paths.root);
  const run = defaultRun(runId, goal, agent, repository);
  const legacyStatus = (handoff && handoff.status) || (loop && loop.status) || 'active';
  run.status = legacyStatus === 'running'
    ? 'active'
    : legacyStatus === 'complete'
      ? 'completed'
      : legacyStatus;
  if (!ACTIVE_STATUSES.has(run.status) && !TERMINAL_STATUSES.has(run.status)) run.status = 'active';
  run.phase = (handoff && handoff.phase) || (loop && loop.phase) || 'planning';
  run.repository.branch = (handoff && handoff.branch) || repository.branch;
  run.repository.head_commit = (handoff && handoff.commit) || repository.head_commit;
  if (handoff && typeof handoff.working_tree_clean === 'boolean') {
    run.repository.working_tree_clean = handoff.working_tree_clean;
  }
  run.remaining_tasks = (handoff && handoff.remaining_tasks) || [];
  run.blockers = (handoff && handoff.blockers) || [];
  run.next_action = (handoff && (handoff.next_prompt || handoff.next_action)) || (loop && loop.next_action) || run.next_action;
  const legacyValidation = (handoff && handoff.validation) || (loop && loop.validation) || {};
  run.validation = {
    ...run.validation,
    status: legacyValidation.status || 'not_run',
    validated_commit: legacyValidation.validated_commit || null,
    checks: Array.isArray(legacyValidation.checks) ? legacyValidation.checks : [],
    checked_at: legacyValidation.checked_at || null,
    stale_reasons: legacyValidation.status === 'green' ? ['legacy_evidence_missing'] : [],
  };
  if (run.validation.status === 'green') run.validation.status = 'stale';
  const corrections = (loop && loop.correction_log) || [];
  run.decisions = corrections.map((entry) => ({
    at: entry.at || nowIso(),
    agent: 'claude-code',
    text: entry.prompt || String(entry),
    kind: 'legacy_correction',
  }));
  run.adapter_state['claude-code'] = {
    legacy_migration: true,
    migrated_at: nowIso(),
    iteration: loop && loop.iteration,
    max_iterations: loop && loop.max_iterations,
    assigned_agents: (loop && loop.assigned_agents) || [],
    correction_log: corrections,
    legacy_loop: loop || null,
    legacy_handoff: handoff || null,
  };
  updateActor(run, (handoff && handoff.updated_by) || agent);
  saveRun(paths, run, 'legacy_migrated', { source: '.master/state' });
  setActiveRun(paths, run.run_id);

  const oldEvents = path.join(paths.legacyState, 'history', 'events.jsonl');
  if (fs.existsSync(oldEvents)) {
    for (const line of fs.readFileSync(oldEvents, 'utf8').split(/\r?\n/).filter(Boolean)) {
      try {
        const event = JSON.parse(line);
        fs.appendFileSync(paths.events, `${JSON.stringify({
          schema_version: SCHEMA_VERSION,
          at: event.at || event.timestamp || nowIso(),
          type: `legacy:${event.type || 'event'}`,
          run_id: run.run_id,
          agent: event.agent || 'claude-code',
          legacy_event: event,
        })}\n`);
      } catch {
        // Ignore corrupt historical lines while preserving valid history.
      }
    }
  }
  return run;
}

function appendGitignore(root) {
  const file = path.join(root, '.gitignore');
  const patterns = [
    '.env',
    '.env.*',
    '.master/active-run',
    '.master/runs/',
    '.master/events/',
    '.master/evidence/',
    '.master/locks/',
    '.master/state/',
  ];
  let content = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const lines = new Set(content.split(/\r?\n/));
  let changed = false;
  for (const pattern of patterns) {
    if (!lines.has(pattern)) {
      content += `${content && !content.endsWith('\n') ? '\n' : ''}${pattern}\n`;
      lines.add(pattern);
      changed = true;
    }
  }
  if (changed) fs.writeFileSync(file, content, 'utf8');
  return changed;
}

function initProject(root, templatesRoot = null) {
  const paths = masterPaths(root);
  ensureRuntimeDirs(paths);
  fs.mkdirSync(path.join(paths.master, 'docs'), { recursive: true });
  const existing = readJson(paths.project);
  const project = normalizeProject(existing, root);
  writeJsonAtomic(paths.project, project);
  appendGitignore(root);

  const readTemplate = (name, fallback) => {
    if (!templatesRoot) return fallback;
    const file = path.join(templatesRoot, name);
    return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : fallback;
  };
  const projectName = project.name || project.project_id;
  const render = (content) => content.split('{{PROJECT_NAME}}').join(projectName);
  const created = [];
  if (writeTextIfAbsent(
    path.join(paths.master, 'README.md'),
    render(readTemplate('MASTER_README.md', '# Agent Master\n\nThis repository uses `.master/` as its shared agent state.\n'))
  )) created.push('.master/README.md');
  if (writeTextIfAbsent(
    path.join(root, 'AGENTS.md'),
    render(readTemplate('AGENTS.md.starter', '# Project\n\nRun `agent-master status --format json` before continuing existing work.\n'))
  )) created.push('AGENTS.md');
  if (writeTextIfAbsent(
    path.join(root, 'CLAUDE.md'),
    render(readTemplate('CLAUDE.md.starter', '# Claude Code Adapter\n\nFollow `AGENTS.md` and use the Agent Master CLI.\n'))
  )) created.push('CLAUDE.md');
  if (writeTextIfAbsent(
    path.join(root, '.cursor', 'rules', 'master-protocol.mdc'),
    render(readTemplate('CURSOR.mdc.starter', '---\nalwaysApply: true\n---\nFollow `AGENTS.md` and use the Agent Master CLI.\n'))
  )) created.push('.cursor/rules/master-protocol.mdc');

  const migrated = migrateLegacyState(paths, project);
  return { root, project, created, migrated_run: migrated ? migrated.run_id : null };
}

function startRun(root, options) {
  const paths = masterPaths(root);
  ensureRuntimeDirs(paths);
  const project = normalizeProject(readJson(paths.project), root);
  writeJsonAtomic(paths.project, project);
  const goal = options.goal && options.goal.trim();
  if (!goal) throw new AgentMasterError('A non-empty goal is required', 2);
  const agent = options.agent || process.env.AGENT_NAME || 'unknown-agent';
  const requested = slugify(options.run || goal);
  let runId = requested;
  let suffix = 2;
  while (fs.existsSync(runPath(paths, runId))) {
    const existing = readJson(runPath(paths, runId));
    if (existing && ACTIVE_STATUSES.has(existing.status)) {
      throw new AgentMasterError(`Run already exists: ${runId}. Continue it with --run ${runId}`, 2);
    }
    runId = `${requested.slice(0, 58)}-${suffix++}`;
  }
  const run = defaultRun(runId, goal, agent, repositorySnapshot(root));
  saveRun(paths, run, 'run_started', { goal });
  setActiveRun(paths, runId);
  return run;
}

function statusRun(root, runId, inspect = false) {
  const paths = masterPaths(root);
  const project = normalizeProject(readJson(paths.project), root);
  const resolved = resolveRun(paths, runId, { required: false });
  if (!resolved) {
    return {
      schema_version: SCHEMA_VERSION,
      active_run: null,
      runs: listRuns(paths).map((run) => ({
        run_id: run.run_id,
        goal: run.goal,
        status: run.status,
        updated_at: run.updated_at,
      })),
      repository: repositorySnapshot(root),
    };
  }
  const run = refreshRun(root, project, resolved.run);
  if (inspect) {
    return {
      ...run,
      project,
      events: readEvents(paths, run.run_id),
      verification: {
        repository_checked_at: nowIso(),
        repository_evidence_wins: true,
      },
    };
  }
  return run;
}

function mutateRun(root, runId, agent, eventType, mutator) {
  const paths = masterPaths(root);
  const project = normalizeProject(readJson(paths.project), root);
  const resolved = resolveRun(paths, runId);
  return withRunLock(paths, resolved.runId, () => {
    const fresh = readJson(resolved.file);
    const run = refreshRun(root, project, fresh);
    mutator(run, project, paths);
    updateActor(run, agent);
    saveRun(paths, run, eventType);
    setActiveRun(paths, run.run_id);
    return run;
  });
}

function checkpointRun(root, options) {
  if (options.status !== undefined) {
    if (TERMINAL_STATUSES.has(options.status)) {
      throw new AgentMasterError(
        `checkpoint cannot set status "${options.status}" — use "agent-master complete" or "agent-master cancel", which enforce the validation gate`,
        2,
      );
    }
    if (options.status !== 'active') {
      throw new AgentMasterError(
        `checkpoint only supports --status active (to resume); use "agent-master pause"/"agent-master handoff" for other transitions`,
        2,
      );
    }
  }
  return mutateRun(root, options.run, options.agent, 'checkpoint', (run) => {
    if (options.phase) run.phase = options.phase;
    if (options.next) run.next_action = options.next;
    for (const text of options.decisions || []) {
      run.decisions.push({ at: nowIso(), agent: options.agent || 'unknown-agent', text });
    }
    for (const text of options.completed || []) {
      run.completed_tasks.push({ at: nowIso(), agent: options.agent || 'unknown-agent', text });
    }
    if (options.remaining) run.remaining_tasks = options.remaining;
    if (options.blockers) run.blockers = options.blockers;
    if (options.status === 'active' || run.status === 'handoff' || run.status === 'paused') {
      run.status = 'active';
    }
  });
}

function shellLogName(command, index) {
  const name = slugify(command.split(/\s+/).slice(0, 4).join('-'), `check-${index + 1}`);
  return `${String(index + 1).padStart(2, '0')}-${name}.log`;
}

function validateRun(root, options) {
  const paths = masterPaths(root);
  const project = normalizeProject(readJson(paths.project), root);
  const resolved = resolveRun(paths, options.run);
  return withRunLock(paths, resolved.runId, () => {
    const run = refreshRun(root, project, readJson(resolved.file));
    const checks = [];
    const evidence = [];
    const commands = validationCommands(project);
    const evidenceDir = path.join(paths.evidence, run.run_id);
    fs.mkdirSync(evidenceDir, { recursive: true });
    let green = commands.length > 0;

    if (commands.length === 0) {
      checks.push({
        kind: 'configuration',
        command: null,
        exit_code: 2,
        started_at: nowIso(),
        completed_at: nowIso(),
        output_reference: null,
        error: 'No validation commands configured in .master/project.json',
      });
    }

    if (commands.length > 0) {
      const hash = validationConfigHash(project);
      const preTrusted = isProjectTrusted(root, hash);
      if (!preTrusted && !options.trust && process.env.AGENT_MASTER_TRUST_PROJECT !== '1') {
        const list = commands.map((c, i) => `  ${i + 1}. [${c.kind}] ${c.command}`).join('\n');
        throw new AgentMasterError(
          `Validation commands in .master/project.json have not been trusted on this machine yet. `
            + `This file is repo-committed and can be edited by anyone with write access (including a clone of `
            + `an untrusted repo or a peer agent), and these commands run locally with your privileges:\n${list}\n\n`
            + `Review them, then re-run with --trust to approve this exact command set on this machine `
            + `(or set AGENT_MASTER_TRUST_PROJECT=1 for CI).`,
          6,
        );
      }
      if (options.trust && !preTrusted) trustProject(root, hash);
    }

    commands.forEach((item, index) => {
      const startedAt = nowIso();
      const result = spawnSync(item.command, {
        cwd: root,
        encoding: 'utf8',
        shell: true,
        maxBuffer: 20 * 1024 * 1024,
        timeout: options.timeout || 10 * 60 * 1000,
        env: { ...process.env, AGENT_MASTER_RUN_ID: run.run_id },
      });
      const completedAt = nowIso();
      const exitCode = result.error
        ? result.error.code === 'ETIMEDOUT' ? 124 : 1
        : typeof result.status === 'number' ? result.status : 1;
      const logName = shellLogName(item.command, index);
      const logFile = path.join(evidenceDir, logName);
      const relative = path.relative(root, logFile).split(path.sep).join('/');
      const output = [
        `$ ${item.command}`,
        '',
        result.stdout || '',
        result.stderr || '',
        result.error ? `Agent Master error: ${result.error.message}` : '',
      ].filter((line) => line !== '').join('\n');
      fs.writeFileSync(logFile, `${output}\n`, 'utf8');
      const check = {
        kind: item.kind,
        command: item.command,
        exit_code: exitCode,
        started_at: startedAt,
        completed_at: completedAt,
        output_reference: relative,
      };
      checks.push(check);
      evidence.push(relative);
      run.commands_run.push(check);
      if (exitCode !== 0) green = false;
    });

    const repository = repositorySnapshot(root);
    run.repository = {
      ...(run.repository || {}),
      ...repository,
    };
    run.validation = {
      status: green ? 'green' : 'red',
      validated_commit: repository.head_commit,
      working_tree_fingerprint: workingTreeFingerprint(root),
      config_hash: validationConfigHash(project),
      checks,
      evidence,
      checked_at: nowIso(),
      stale_reasons: [],
    };
    run.phase = green ? 'validated' : 'implementation';
    updateActor(run, options.agent);
    saveRun(paths, run, green ? 'validation_green' : 'validation_red');
    return run;
  });
}

function handoffRun(root, options) {
  return mutateRun(root, options.run, options.agent, 'handoff', (run) => {
    run.status = 'handoff';
    run.phase = 'handoff';
    if (options.next) run.next_action = options.next;
    run.ownership.lease_owner = null;
    run.ownership.lease_expires_at = null;
  });
}

function pauseRun(root, options) {
  return mutateRun(root, options.run, options.agent, 'run_paused', (run) => {
    run.status = 'paused';
    run.phase = 'paused';
    if (options.blocker) run.blockers = [...new Set([...(run.blockers || []), options.blocker])];
    if (options.next) run.next_action = options.next;
    run.ownership.lease_owner = null;
    run.ownership.lease_expires_at = null;
  });
}

function cancelRun(root, options) {
  return mutateRun(root, options.run, options.agent, 'run_cancelled', (run) => {
    run.status = 'cancelled';
    run.phase = 'cancelled';
    if (options.reason) run.blockers = [...new Set([...(run.blockers || []), options.reason])];
    run.ownership.lease_owner = null;
    run.ownership.lease_expires_at = null;
  });
}

function completeRun(root, options) {
  return mutateRun(root, options.run, options.agent, 'run_completed', (run, project) => {
    refreshRun(root, project, run);
    if (!run.validation || run.validation.status !== 'green') {
      const reasons = run.validation && run.validation.stale_reasons && run.validation.stale_reasons.length
        ? ` (${run.validation.stale_reasons.join(', ')})`
        : '';
      throw new AgentMasterError(`Completion rejected: validation is ${run.validation ? run.validation.status : 'missing'}${reasons}`, 4);
    }
    run.status = 'completed';
    run.phase = 'complete';
    run.next_action = null;
    run.ownership.lease_owner = null;
    run.ownership.lease_expires_at = null;
  });
}

function claimFiles(root, options) {
  const paths = masterPaths(root);
  const requested = [...new Set((options.files || []).map((file) => {
    const relative = path.relative(root, path.resolve(root, file)).split(path.sep).join('/');
    if (relative.startsWith('../') || relative === '..') {
      throw new AgentMasterError(`Cannot claim a path outside the repository: ${file}`, 2);
    }
    return relative;
  }))].sort();
  if (requested.length === 0) throw new AgentMasterError('At least one file path is required', 2);
  const current = resolveRun(paths, options.run);
  const now = Date.now();
  const conflicts = [];
  for (const other of listRuns(paths)) {
    if (other.run_id === current.runId || !ACTIVE_STATUSES.has(other.status)) continue;
    const expires = other.ownership && other.ownership.lease_expires_at
      ? Date.parse(other.ownership.lease_expires_at)
      : Infinity;
    if (Number.isFinite(expires) && expires <= now) continue;
    const owned = new Set((other.ownership && other.ownership.files) || []);
    for (const file of requested) {
      if (owned.has(file)) conflicts.push({ file, run_id: other.run_id, owner: other.ownership.lease_owner });
    }
  }
  if (conflicts.length > 0 && !options.force) {
    throw new AgentMasterError('File ownership conflict', 5, conflicts);
  }
  return mutateRun(root, current.runId, options.agent, 'files_claimed', (run) => {
    run.ownership.files = [...new Set([...(run.ownership.files || []), ...requested])].sort();
    run.ownership.lease_owner = options.agent || 'unknown-agent';
    const minutes = Number(options.leaseMinutes || 60);
    run.ownership.lease_expires_at = new Date(Date.now() + minutes * 60_000).toISOString();
  });
}

function releaseFiles(root, options) {
  return mutateRun(root, options.run, options.agent, 'files_released', (run) => {
    if (!options.files || options.files.length === 0) {
      run.ownership.files = [];
    } else {
      const releasing = new Set(options.files.map((file) =>
        path.relative(root, path.resolve(root, file)).split(path.sep).join('/')
      ));
      run.ownership.files = (run.ownership.files || []).filter((file) => !releasing.has(file));
    }
    if (run.ownership.files.length === 0) {
      run.ownership.lease_owner = null;
      run.ownership.lease_expires_at = null;
    }
  });
}

function doctorProject(root, packageRoot = null) {
  const paths = masterPaths(root);
  const project = readJson(paths.project);
  const runs = listRuns(paths);
  const providers = {
    'claude-code': commandExists('claude'),
    codex: commandExists('codex'),
    cursor: commandExists('cursor-agent'),
  };
  const checks = [
    { name: 'project_config', ok: !!project, detail: project ? `.master/project.json schema ${project.schema_version}` : 'missing' },
    { name: 'schema_v2', ok: !!project && project.schema_version === SCHEMA_VERSION, detail: project && project.schema_version },
    { name: 'agents_adapter', ok: fs.existsSync(path.join(root, 'AGENTS.md')), detail: 'AGENTS.md' },
    { name: 'claude_adapter', ok: fs.existsSync(path.join(root, 'CLAUDE.md')), detail: 'CLAUDE.md' },
    { name: 'cursor_adapter', ok: fs.existsSync(path.join(root, '.cursor', 'rules', 'master-protocol.mdc')), detail: '.cursor/rules/master-protocol.mdc' },
    { name: 'git_repository', ok: isGitRepository(root), detail: root },
  ];
  if (packageRoot) {
    for (const provider of ['claude-code', 'codex', 'cursor']) {
      const manifest = path.join(packageRoot, 'adapters', provider, 'capabilities.json');
      checks.push({ name: `capabilities:${provider}`, ok: fs.existsSync(manifest), detail: manifest });
    }
  }
  return {
    healthy: checks.every((check) => check.ok),
    root,
    checks,
    providers,
    active_run: readActiveRunId(paths),
    run_count: runs.length,
  };
}

function packCommand(root, action, name, packageRoot) {
  const available = [{
    name: 'graph-engineering',
    status: 'planned',
    description: 'Progressive graph-system skills and checks (not included in v1.1).',
  }];
  const installedFile = path.join(root, '.master', 'packs.json');
  const installed = readJson(installedFile, { schema_version: 1, packs: [] });
  if (action === 'list') return { available, installed: installed.packs };
  if (!name) throw new AgentMasterError(`pack ${action} requires a pack name`, 2);
  const pack = available.find((entry) => entry.name === name);
  if (!pack) throw new AgentMasterError(`Unknown pack: ${name}`, 2);
  if (action === 'add') {
    if (pack.status !== 'available') {
      throw new AgentMasterError(`${name} is reserved but not shipped in v1.1`, 2);
    }
    installed.packs = [...new Set([...installed.packs, name])];
  } else if (action === 'remove') {
    installed.packs = installed.packs.filter((entry) => entry !== name);
  } else {
    throw new AgentMasterError(`Unknown pack action: ${action}`, 2);
  }
  writeJsonAtomic(installedFile, installed);
  return { available, installed: installed.packs, package_root: packageRoot };
}

/**
 * Split a single "--flag value --flag2 value2" blob into separate tokens,
 * respecting quoted substrings. Claude command wrappers pass the whole
 * `$ARGUMENTS` text as one shell-quoted string (required so `;`, `|`, and
 * `$(...)` in a decision/note never reach the shell) — this recovers the
 * individual flags/values from that single string inside Node, where
 * splitting is just string parsing and can never execute anything.
 */
function tokenizeArgsBlob(blob) {
  const tokens = [];
  let current = '';
  let quote = null;
  for (const ch of blob) {
    if (quote) {
      if (ch === quote) quote = null;
      else current += ch;
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
      continue;
    }
    if (/\s/.test(ch)) {
      if (current) {
        tokens.push(current);
        current = '';
      }
      continue;
    }
    current += ch;
  }
  if (current) tokens.push(current);
  return tokens;
}

/** Expand any argv item that is itself an unsplit "--flag value ..." blob. */
function expandArgumentBlobs(argv) {
  const expanded = [];
  for (const raw of argv) {
    if (raw.startsWith('--') && /\s/.test(raw)) {
      expanded.push(...tokenizeArgsBlob(raw));
    } else {
      expanded.push(raw);
    }
  }
  return expanded;
}

function parseCli(rawArgv) {
  const argv = expandArgumentBlobs(rawArgv);
  const positional = [];
  const options = {
    decisions: [],
    completed: [],
    remaining: null,
    blockers: null,
    files: [],
  };
  const take = (index, flag) => {
    if (index + 1 >= argv.length || argv[index + 1].startsWith('--')) {
      throw new AgentMasterError(`${flag} requires a value`, 2);
    }
    return argv[index + 1];
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith('--')) {
      positional.push(arg);
      continue;
    }
    const [flag, inline] = arg.split(/=(.*)/s, 2);
    const value = inline !== undefined ? inline : null;
    switch (flag) {
      case '--run':
        options.run = value !== null ? value : take(index++, flag);
        break;
      case '--agent':
        options.agent = value !== null ? value : take(index++, flag);
        break;
      case '--session':
        options.session = value !== null ? value : take(index++, flag);
        break;
      case '--format':
        options.format = value !== null ? value : take(index++, flag);
        break;
      case '--phase':
        options.phase = value !== null ? value : take(index++, flag);
        break;
      case '--status':
        options.status = value !== null ? value : take(index++, flag);
        break;
      case '--next':
        options.next = value !== null ? value : take(index++, flag);
        break;
      case '--decision':
        options.decisions.push(value !== null ? value : take(index++, flag));
        break;
      case '--completed':
        options.completed.push(value !== null ? value : take(index++, flag));
        break;
      case '--remaining':
        options.remaining = options.remaining || [];
        options.remaining.push(value !== null ? value : take(index++, flag));
        break;
      case '--blocker':
        options.blockers = options.blockers || [];
        options.blockers.push(value !== null ? value : take(index++, flag));
        break;
      case '--reason':
        options.reason = value !== null ? value : take(index++, flag);
        break;
      case '--lease-minutes':
        options.leaseMinutes = value !== null ? value : take(index++, flag);
        break;
      case '--timeout':
        options.timeout = Number(value !== null ? value : take(index++, flag)) * 1000;
        break;
      case '--force':
        options.force = true;
        break;
      case '--trust':
        options.trust = true;
        break;
      case '--help':
        options.help = true;
        break;
      default:
        throw new AgentMasterError(`Unknown option: ${flag}`, 2);
    }
  }
  return { positional, options };
}

function textSummary(command, result) {
  if (command === 'init') {
    const migration = result.migrated_run ? `\nMigrated legacy run: ${result.migrated_run}` : '';
    return `Agent Master initialized in ${result.root}${migration}`;
  }
  if (command === 'doctor') {
    const lines = result.checks.map((check) => `${check.ok ? 'OK' : 'FAIL'} ${check.name}: ${check.detail}`);
    return `${result.healthy ? 'Healthy' : 'Problems found'}\n${lines.join('\n')}`;
  }
  if (command === 'pack') return JSON.stringify(result, null, 2);
  if (result && result.run_id) {
    const validation = result.validation ? result.validation.status : 'not_run';
    return [
      `Run: ${result.run_id}`,
      `Goal: ${result.goal}`,
      `Status: ${result.status}`,
      `Phase: ${result.phase}`,
      `Validation: ${validation}`,
      `Next: ${result.next_action || '(none)'}`,
    ].join('\n');
  }
  return JSON.stringify(result, null, 2);
}

function helpText(packageName = 'agent-master-setup') {
  return `Agent Master ${SCHEMA_VERSION === 2 ? 'v1.1' : ''}

Usage:
  agent-master init
  agent-master start "<goal>" [--run id] [--agent name]
  agent-master status [--run id] [--format json]
  agent-master inspect [--run id] [--format json]
  agent-master checkpoint [--run id] [--decision text] [--completed text]
                         [--remaining text] [--blocker text] [--next text]
  agent-master validate [--run id] [--agent name] [--trust]
  agent-master handoff [--run id] [--next text]
  agent-master complete [--run id]
  agent-master pause [--run id] [--blocker text] [--next text]
  agent-master cancel [--run id] [--reason text]
  agent-master claim [--run id] [--agent name] <files...>
  agent-master release [--run id] <files...>
  agent-master doctor
  agent-master pack list|add|remove [name]
  agent-master install claude|codex|cursor

Repository evidence always overrides recorded state. Completion requires current
GREEN validation evidence.

Package: ${packageName}`;
}

function runUniversalCli(argv, context = {}) {
  const packageRoot = context.packageRoot || path.resolve(__dirname, '..');
  const templatesRoot = context.templatesRoot || path.join(packageRoot, 'templates');
  const packageName = context.packageName || 'agent-master-setup';
  const { positional, options } = parseCli(argv);
  const command = positional.shift() || 'init';
  if (options.help || command === 'help') {
    return { exitCode: 0, output: helpText(packageName), result: null };
  }
  const root = findProjectRoot(context.cwd || process.cwd());
  let result;

  switch (command) {
    case 'init':
      result = initProject(root, templatesRoot);
      break;
    case 'start':
      options.goal = positional.join(' ');
      result = startRun(root, options);
      break;
    case 'status':
      result = statusRun(root, options.run, false);
      break;
    case 'inspect':
      result = statusRun(root, options.run, true);
      break;
    case 'checkpoint':
      result = checkpointRun(root, options);
      break;
    case 'validate':
      result = validateRun(root, options);
      break;
    case 'handoff':
      result = handoffRun(root, options);
      break;
    case 'complete':
      result = completeRun(root, options);
      break;
    case 'pause':
      options.blocker = options.blockers && options.blockers[0];
      result = pauseRun(root, options);
      break;
    case 'cancel':
      result = cancelRun(root, options);
      break;
    case 'claim':
      options.files = positional;
      result = claimFiles(root, options);
      break;
    case 'release':
      options.files = positional;
      result = releaseFiles(root, options);
      break;
    case 'doctor':
      result = doctorProject(root, packageRoot);
      break;
    case 'pack':
      result = packCommand(root, positional[0] || 'list', positional[1], packageRoot);
      break;
    default:
      throw new AgentMasterError(`Unknown command: ${command}\n\n${helpText(packageName)}`, 2);
  }

  return {
    exitCode: 0,
    output: options.format === 'json' ? JSON.stringify(result, null, 2) : textSummary(command, result),
    result,
  };
}

module.exports = {
  ACTIVE_STATUSES,
  AgentMasterError,
  SCHEMA_VERSION,
  claimFiles,
  completeRun,
  doctorProject,
  findProjectRoot,
  initProject,
  masterPaths,
  migrateLegacyState,
  normalizeProject,
  repositorySnapshot,
  runUniversalCli,
  statusRun,
  validationCommands,
  workingTreeFingerprint,
};
