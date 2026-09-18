#!/usr/bin/env node

/**
 * ADB Manager MCP Server for Antigravity
 * Bridges Antigravity AI coding assistant with ADB Manager desktop application
 * for auto-hot-reload, hot-restart, and live device inspection.
 */

const readline = require('readline');

const BRIDGE_URL = process.env.ADB_MANAGER_URL || 'http://127.0.0.1:45678';

const TOOLS = [
  {
    name: 'adb_hot_reload',
    description: 'Trigger instant Hot Reload on connected Android virtual devices or physical phones via ADB Manager. Use this immediately after making code changes to Flutter widgets or logic.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: {
          type: 'string',
          description: 'Optional specific device ID (e.g. emulator-5554). If omitted, reloads the currently active device.'
        },
        all: {
          type: 'boolean',
          description: 'If true, broadcasts hot reload to all running devices simultaneously.'
        }
      }
    }
  },
  {
    name: 'adb_hot_restart',
    description: 'Trigger instant Hot Restart on connected Android virtual devices via ADB Manager. Resets app state and re-runs main(). Use after modifying global state, initializers, or main.dart.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: {
          type: 'string',
          description: 'Optional specific device ID (e.g. emulator-5554).'
        },
        all: {
          type: 'boolean',
          description: 'If true, broadcasts hot restart to all running devices simultaneously.'
        }
      }
    }
  },
  {
    name: 'adb_status',
    description: 'Get live status from ADB Manager: active project, connected virtual devices, running Flutter sessions, and Dart VM service URL.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'adb_run_app',
    description: 'Start the Flutter app on the target virtual device in ADB Manager if it is not currently running.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

async function callBridge(endpoint, method = 'GET', body = null) {
  const url = `${BRIDGE_URL}${endpoint}`;
  try {
    const opts = {
      method,
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(5000)
    };
    if (body) {
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(url, opts);
    return await res.json();
  } catch (err) {
    return {
      error: `Could not connect to ADB Manager Agent Bridge at ${BRIDGE_URL}. Ensure ADB Manager is running. (${err.message})`
    };
  }
}

async function handleToolCall(name, args) {
  if (name === 'adb_hot_reload') {
    const res = await callBridge('/api/reload', 'POST', args || {});
    return {
      content: [{ type: 'text', text: JSON.stringify(res, null, 2) }]
    };
  }

  if (name === 'adb_hot_restart') {
    const res = await callBridge('/api/restart', 'POST', args || {});
    return {
      content: [{ type: 'text', text: JSON.stringify(res, null, 2) }]
    };
  }

  if (name === 'adb_status') {
    const res = await callBridge('/api/status', 'GET');
    return {
      content: [{ type: 'text', text: JSON.stringify(res, null, 2) }]
    };
  }

  if (name === 'adb_run_app') {
    const res = await callBridge('/api/run', 'POST', args || {});
    return {
      content: [{ type: 'text', text: JSON.stringify(res, null, 2) }]
    };
  }

  return {
    isError: true,
    content: [{ type: 'text', text: `Unknown tool: ${name}` }]
  };
}

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', async (line) => {
  if (!line.trim()) return;

  let request;
  try {
    request = JSON.parse(line);
  } catch (err) {
    return;
  }

  const { id, method, params } = request;

  if (method === 'initialize') {
    const response = {
      jsonrpc: '2.0',
      id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: 'adb-manager',
          version: '1.0.0'
        }
      }
    };
    process.stdout.write(JSON.stringify(response) + '\n');
    return;
  }

  if (method === 'notifications/initialized') {
    return;
  }

  if (method === 'tools/list') {
    const response = {
      jsonrpc: '2.0',
      id,
      result: {
        tools: TOOLS
      }
    };
    process.stdout.write(JSON.stringify(response) + '\n');
    return;
  }

  if (method === 'tools/call') {
    const toolName = params?.name;
    const toolArgs = params?.arguments;
    const result = await handleToolCall(toolName, toolArgs);

    const response = {
      jsonrpc: '2.0',
      id,
      result
    };
    process.stdout.write(JSON.stringify(response) + '\n');
    return;
  }

  // Ping or unknown method
  if (id !== undefined) {
    const response = {
      jsonrpc: '2.0',
      id,
      result: {}
    };
    process.stdout.write(JSON.stringify(response) + '\n');
  }
});
