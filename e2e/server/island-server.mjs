/**
 * Bastion Islands Test Server
 *
 * A minimal Node.js server that implements the Bastion island protocol
 * (HTTP + WebSocket) to enable end-to-end Playwright testing of the
 * march-islands.js client runtime without requiring the March compiler.
 *
 * Implements:
 *   - Counter   (server-mode: server owns state, pushes renders on events)
 *   - ClientCounter (client-mode: sends handoff:true, WASM takes over locally)
 *   - TodoList + TodoItem (parent-child: child dispatches toggle event upward)
 *
 * Admin endpoints (used by Playwright tests):
 *   GET  /admin/close-ws        — force-close all active WebSocket connections
 *   POST /admin/push/:islandId  — push a state update to a specific island
 */

import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = 4001;

// Path to the compiled JS assets (two levels up from e2e/server/)
const PROJECT_ROOT = join(__dirname, '..', '..');
const JS_DIR = join(PROJECT_ROOT, 'priv', 'js');

// ── Island Handlers ────────────────────────────────────────────────────────

/**
 * Normalise a msg payload: if it's a JSON string, parse it.
 * If it's already an object, use as-is.
 */
function parseMsg(raw) {
  if (typeof raw === 'object' && raw !== null) return raw;
  if (typeof raw === 'string') {
    try { return JSON.parse(raw); } catch { return raw; }
  }
  return raw;
}

/**
 * Each handler has:
 *   dataflow  — "server" | "client"
 *   init()    — returns initial state object
 *   update(state, msg) — returns new state object
 *   render(state)      — returns HTML string
 *   child_event?(state, eventName, payload) — optional, returns new state
 */
const handlers = {
  Counter: {
    dataflow: 'server',
    init: () => ({ count: 0 }),
    update(state, rawMsg) {
      const msg = parseMsg(rawMsg);
      const tag = typeof msg === 'object' ? msg.tag : msg;
      if (tag === 'Increment') return { ...state, count: state.count + 1 };
      if (tag === 'Decrement') return { ...state, count: Math.max(0, state.count - 1) };
      return state;
    },
    render(state) {
      return [
        `<p data-testid="count">${state.count}</p>`,
        `<button data-on-click="Increment" data-testid="inc">+</button>`,
        `<button data-on-click="Decrement" data-testid="dec">-</button>`,
      ].join('');
    },
  },

  ClientCounter: {
    dataflow: 'client',
    init: () => ({ count: 0 }),
    update(state, rawMsg) {
      const msg = parseMsg(rawMsg);
      const tag = typeof msg === 'object' ? msg.tag : msg;
      if (tag === 'Increment') return { ...state, count: state.count + 1 };
      if (tag === 'Decrement') return { ...state, count: Math.max(0, state.count - 1) };
      return state;
    },
    render(state) {
      return [
        `<p data-testid="count">${state.count}</p>`,
        `<button data-on-click="Increment" data-testid="inc">+</button>`,
        `<button data-on-click="Decrement" data-testid="dec">-</button>`,
      ].join('');
    },
  },

  TodoList: {
    dataflow: 'client',
    init: () => ({
      items: [
        { id: 1, text: 'Buy milk', done: false },
        { id: 2, text: 'Write tests', done: false },
        { id: 3, text: 'Ship it', done: true },
      ],
    }),
    update(state, _rawMsg) {
      return state;  // TodoList doesn't handle direct messages
    },
    render(state, instanceId) {
      const parentId = instanceId || 'TodoList-1';
      const itemsHtml = state.items.map(item => {
        const itemState = JSON.stringify(item).replace(/"/g, '&quot;');
        const checked = item.done ? 'checked' : '';
        return [
          `<div data-march-island="TodoItem"`,
          ` data-march-state="${itemState}"`,
          ` data-march-parent="${parentId}"`,
          ` data-march-on-event="toggle"`,
          ` data-march-dataflow="client"`,
          ` data-testid="todo-item-${item.id}">`,
          `  <span>${item.text}</span>`,
          `  <button data-on-click="Toggle" ${checked} data-testid="toggle-${item.id}">${item.done ? '[x]' : '[ ]'}</button>`,
          `</div>`,
        ].join('');
      }).join('\n');
      return `<div data-testid="todo-list">\n${itemsHtml}\n</div>`;
    },
    child_event(state, eventName, rawPayload) {
      if (eventName !== 'toggle') return state;
      const payload = parseMsg(rawPayload);
      const id = typeof payload === 'object' ? payload.id : parseInt(payload, 10);
      return {
        ...state,
        items: state.items.map(item =>
          item.id === id ? { ...item, done: !item.done } : item
        ),
      };
    },
  },

  TodoItem: {
    dataflow: 'client',
    init: () => ({ id: 0, text: '', done: false }),
    update(state, rawMsg) {
      const msg = parseMsg(rawMsg);
      const tag = typeof msg === 'object' ? msg.tag : msg;
      if (tag === 'Toggle') {
        return { ...state, done: !state.done };
      }
      return state;
    },
    render(state) {
      const checked = state.done ? 'checked' : '';
      return [
        `<span data-testid="item-text">${state.text}</span>`,
        `<button data-on-click="Toggle" ${checked} data-testid="toggle-btn">${state.done ? '[x]' : '[ ]'}</button>`,
      ].join('');
    },
  },
};

// ── Island Protocol Processing ─────────────────────────────────────────────

/**
 * Process a single island protocol message.
 * Returns { store, responses: string[] }.
 */
function processMsg(store, text) {
  let msg;
  try { msg = JSON.parse(text); } catch { return { store, responses: [] }; }

  const { island: islandId, type, module: moduleName } = msg;
  const responses = [];

  if (type === 'init') {
    const handler = handlers[moduleName];
    if (!handler) return { store, responses };

    // Accept client's state if provided (handles reconnect with updated state)
    const clientPayload = msg.payload;
    const initState = (typeof clientPayload === 'object' && clientPayload !== null)
      ? clientPayload
      : handler.init();

    store = { ...store, [islandId]: { moduleName, state: initState } };

    const html = handler.render(initState, islandId);
    const renderMsg = handler.dataflow === 'client'
      ? { island: islandId, type: 'render', payload: html, handoff: true }
      : { island: islandId, type: 'render', payload: html };
    responses.push(JSON.stringify(renderMsg));
    responses.push(JSON.stringify({ island: islandId, type: 'state', payload: initState }));
  }

  else if (type === 'msg') {
    const entry = store[islandId];
    if (!entry) return { store, responses };
    const handler = handlers[entry.moduleName];
    if (!handler) return { store, responses };

    const newState = handler.update(entry.state, msg.payload);
    store = { ...store, [islandId]: { ...entry, state: newState } };
    const html = handler.render(newState, islandId);
    responses.push(JSON.stringify({ island: islandId, type: 'render', payload: html }));
    responses.push(JSON.stringify({ island: islandId, type: 'state', payload: newState }));
  }

  else if (type === 'child_event') {
    const entry = store[islandId];  // islandId is the PARENT's id here
    if (!entry) return { store, responses };
    const handler = handlers[entry.moduleName];
    if (!handler || !handler.child_event) return { store, responses };

    const newState = handler.child_event(entry.state, msg.event, msg.payload);
    store = { ...store, [islandId]: { ...entry, state: newState } };
    const html = handler.render(newState, islandId);
    responses.push(JSON.stringify({ island: islandId, type: 'render', payload: html }));
    responses.push(JSON.stringify({ island: islandId, type: 'state', payload: newState }));
  }

  else if (type === 'destroy') {
    const { [islandId]: _removed, ...rest } = store;
    store = rest;
  }

  return { store, responses };
}

// ── HTML Pages ─────────────────────────────────────────────────────────────

function jsTag(file) {
  return `<script src="/${file}"></script>`;
}

function basePage(title, bodyContent) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${title}</title>
</head>
<body>
  ${bodyContent}
  ${jsTag('idiomorph.js')}
  ${jsTag('wasm-bridge.js')}
  ${jsTag('march-islands.js')}
</body>
</html>`;
}

const pages = {
  '/': basePage('Island Tests — Index', `
    <h1>Bastion Islands Test App</h1>
    <nav>
      <ul>
        <li><a href="/server-counter">Server-mode Counter</a></li>
        <li><a href="/client-counter">Client-mode Counter (WASM)</a></li>
        <li><a href="/todo-list">Parent-Child TodoList</a></li>
        <li><a href="/reconnect">Offline Reconnect Test</a></li>
      </ul>
    </nav>
  `),

  '/server-counter': basePage('Server Counter', `
    <h1>Server Counter</h1>
    <div
      data-march-island="Counter"
      data-march-state='{"count":0}'
      data-march-dataflow="server"
      data-testid="counter-island">
      <p data-testid="count">0</p>
      <button data-on-click="Increment" data-testid="inc">+</button>
      <button data-on-click="Decrement" data-testid="dec">-</button>
    </div>
  `),

  '/client-counter': basePage('Client Counter', `
    <h1>Client Counter (WASM)</h1>
    <div
      data-march-island="ClientCounter"
      data-march-state='{"count":0}'
      data-march-dataflow="client"
      data-testid="counter-island">
      <p data-testid="count">0</p>
      <button data-on-click="Increment" data-testid="inc">+</button>
      <button data-on-click="Decrement" data-testid="dec">-</button>
    </div>
  `),

  '/todo-list': basePage('TodoList', `
    <h1>Parent-Child TodoList</h1>
    <div
      data-march-island="TodoList"
      data-march-state='{"items":[{"id":1,"text":"Buy milk","done":false},{"id":2,"text":"Write tests","done":false},{"id":3,"text":"Ship it","done":true}]}'
      data-march-dataflow="client"
      data-testid="todolist-island">
      <div data-testid="todo-list">
        <div data-march-island="TodoItem"
             data-march-state='{"id":1,"text":"Buy milk","done":false}'
             data-march-parent="TodoList-1"
             data-march-on-event="toggle"
             data-march-dataflow="client"
             data-testid="todo-item-1">
          <span>Buy milk</span>
          <button data-on-click="Toggle" data-testid="toggle-1">[ ]</button>
        </div>
        <div data-march-island="TodoItem"
             data-march-state='{"id":2,"text":"Write tests","done":false}'
             data-march-parent="TodoList-1"
             data-march-on-event="toggle"
             data-march-dataflow="client"
             data-testid="todo-item-2">
          <span>Write tests</span>
          <button data-on-click="Toggle" data-testid="toggle-2">[ ]</button>
        </div>
        <div data-march-island="TodoItem"
             data-march-state='{"id":3,"text":"Ship it","done":true}'
             data-march-parent="TodoList-1"
             data-march-on-event="toggle"
             data-march-dataflow="client"
             data-testid="todo-item-3">
          <span>Ship it</span>
          <button data-on-click="Toggle" data-testid="toggle-3">[x]</button>
        </div>
      </div>
    </div>
  `),

  '/reconnect': basePage('Reconnect Test', `
    <h1>Offline Reconnect Test</h1>
    <div
      data-march-island="ClientCounter"
      data-march-state='{"count":0}'
      data-march-dataflow="client"
      data-testid="counter-island">
      <p data-testid="count">0</p>
      <button data-on-click="Increment" data-testid="inc">+</button>
    </div>
  `),
};

// ── HTTP + WebSocket Server ────────────────────────────────────────────────

// Track all active WebSocket connections (for admin close)
const activeConnections = new Set();

const server = createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const path = url.pathname;

  // Serve static JS files from priv/js/ (paths like /march-islands.js)
  if (path.endsWith('.js') && !path.slice(1).includes('/')) {
    const filename = path.slice(1);
    const filepath = join(JS_DIR, filename);
    try {
      const content = readFileSync(filepath, 'utf-8');
      res.writeHead(200, { 'Content-Type': 'application/javascript' });
      res.end(content);
      return;
    } catch {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
  }

  // Admin: force-close all WebSocket connections
  if (path === '/admin/close-ws') {
    let closed = 0;
    for (const ws of activeConnections) {
      ws.terminate();  // unclean close → client sees wasClean=false → reconnects
      closed++;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ closed }));
    return;
  }

  // Admin: push a state update to a specific island instance
  // POST /admin/push  body: { islandId, state }
  if (path === '/admin/push' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const { islandId, state, html } = JSON.parse(body);
        const renderMsg = JSON.stringify({ island: islandId, type: 'render', payload: html || '' });
        const stateMsg  = JSON.stringify({ island: islandId, type: 'state',  payload: state });
        for (const ws of activeConnections) {
          if (ws.readyState === 1) {
            ws.send(renderMsg);
            ws.send(stateMsg);
          }
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // Serve HTML pages
  const html = pages[path];
  if (html) {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

// ── WebSocket Server ───────────────────────────────────────────────────────

const wss = new WebSocketServer({ server, path: '/_bastion/ws' });

wss.on('connection', (ws) => {
  activeConnections.add(ws);
  let store = {};

  ws.on('message', (data) => {
    const text = data.toString();
    const result = processMsg(store, text);
    store = result.store;
    for (const resp of result.responses) {
      if (ws.readyState === 1) ws.send(resp);
    }
  });

  ws.on('close', () => {
    activeConnections.delete(ws);
  });

  ws.on('error', () => {
    activeConnections.delete(ws);
  });
});

server.listen(PORT, () => {
  console.log(`Bastion Islands test server running at http://localhost:${PORT}`);
});
