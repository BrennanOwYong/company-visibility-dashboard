const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = __dirname;
const port = Number(process.env.PORT || 3000);
const clients = new Set();

function id(prefix) {
  return `${prefix}-${crypto.randomUUID()}`;
}

function logEvent(name, fields = {}) {
  const event = {
    event_id: id('evt'), name, schema_version: 1,
    occurred_at: new Date().toISOString(), source: 'web', outcome: fields.outcome || 'succeeded',
    ...fields
  };
  process.stdout.write(`${JSON.stringify(event)}\n`);
  return event;
}

const fixedEntries = [
  { id: 'connected-tools', kind: 'fixed', title: 'Connected Tools', icon_key: 'plug', route: '/connected-tools' },
  { id: 'memory', kind: 'fixed', title: 'Memory', icon_key: 'spark', route: '/memory' },
  { id: 'create-page', kind: 'fixed', title: 'Create page', icon_key: 'plus', route: '/pages/new' }
];

function navigation(url) {
  const fixture = url.searchParams.get('fixture') || process.env.DASHBOARD_FIXTURE || 'empty';
  if (fixture === 'failure' || url.searchParams.get('fail') === '1') {
    const error = new Error('navigation unavailable');
    error.code = 'temporary_failure';
    throw error;
  }
  const pages = fixture === 'page' ? [{ id: 'evaluation-page', kind: 'page', title: 'Revenue overview', icon_key: 'chart', route: '/pages/evaluation-page' }] : [];
  return { version: 1, entries: [...fixedEntries, ...pages] };
}

function sendJson(res, status, body, requestId) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'x-request-id': requestId });
  res.end(JSON.stringify(body));
}

function routePage(res, route, requestId) {
  const unavailable = route.includes('unavailable') || route.includes('fail');
  if (unavailable) {
    sendJson(res, 503, { error: { code: 'temporary_failure', message: 'This page is temporarily unavailable.', recovery: 'retry', request_id: requestId } }, requestId);
    return;
  }
  sendJson(res, 200, { page: { route, title: route === '/pages/new' ? 'Create a page' : route === '/memory' ? 'Memory' : route === '/connected-tools' ? 'Connected Tools' : 'Revenue overview' }, version: 1 }, requestId);
}

function serveFile(res, file, type) {
  fs.readFile(path.join(root, file), (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'content-type': type }); res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const requestId = id('req');
  const url = new URL(req.url, `http://${req.headers.host || '127.0.0.1'}`);
  if (req.method === 'GET' && url.pathname === '/health') return sendJson(res, 200, { status: 'ok' }, requestId);
  if (req.method === 'GET' && url.pathname === '/api/v1/navigation') {
    try {
      const result = navigation(url);
      logEvent('api.request.completed', { request_id: requestId, safe_attributes: { route: '/api/v1/navigation', count: result.entries.length } });
      return sendJson(res, 200, result, requestId);
    } catch (error) {
      logEvent('api.request.failed', { request_id: requestId, outcome: 'failed', safe_attributes: { route: '/api/v1/navigation', error_class: error.code } });
      return sendJson(res, 503, { error: { code: error.code, message: 'Saved pages are temporarily unavailable.', recovery: 'retry', request_id: requestId } }, requestId);
    }
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/events') {
    res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
    res.write(': connected\n\n'); clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/telemetry') {
    let body = '';
    req.on('data', chunk => { body += chunk; if (body.length > 10000) req.destroy(); });
    req.on('end', () => {
      try {
        const event = JSON.parse(body);
        const safe = { interaction_id: event.interaction_id, route: event.route, state: event.state, count: event.count, duration: event.duration, error_class: event.error_class, entry_kind: event.entry_kind, outcome: event.outcome };
        logEvent(event.name, Object.fromEntries(Object.entries(safe).filter(([, value]) => value !== undefined)));
        sendJson(res, 202, { accepted: true }, requestId);
      } catch { sendJson(res, 400, { error: { code: 'invalid_input', message: 'Telemetry could not be recorded.', request_id: requestId } }, requestId); }
    });
    return;
  }
  if (req.method === 'GET' && url.pathname.startsWith('/api/v1/pages/')) return routePage(res, url.pathname.replace('/api/v1/pages', '') || '/', requestId);
  if (req.method === 'GET' && url.pathname === '/') return serveFile(res, 'public/index.html', 'text/html; charset=utf-8');
  if (req.method === 'GET' && url.pathname === '/app.js') return serveFile(res, 'public/app.js', 'text/javascript; charset=utf-8');
  if (req.method === 'GET' && url.pathname === '/styles.css') return serveFile(res, 'public/styles.css', 'text/css; charset=utf-8');
  res.writeHead(404); res.end('Not found');
});

server.listen(port, '127.0.0.1', () => logEvent('runtime.ready', { safe_attributes: { route: '/', port } }));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
