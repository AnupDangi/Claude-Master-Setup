#!/usr/bin/env node
'use strict';

process.stderr.write(
  'claude-master-setup is deprecated. Use: npx agent-master-setup@latest\n'
);

require('agent-master-setup/bin/cli.js');
