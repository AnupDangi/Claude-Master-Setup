#!/usr/bin/env node
'use strict';

process.stderr.write(
  'claude-master-setup has moved to agent-master-setup. ' +
  'This compatibility command will continue with Agent Master v1.1.\n'
);

require('./cli');
