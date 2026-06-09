#!/usr/bin/env node
// kanban-ui/server.js
// Usage: KANBAN_PROJECT_ROOT=/path/to/project node server.js
// Defaults to cwd if KANBAN_PROJECT_ROOT not set.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = process.env.KANBAN_UI_PORT || 2999;
const PROJECT_ROOT = process.env.KANBAN_PROJECT_ROOT || process.cwd();
const KANBAN_DIR = path.join(PROJECT_ROOT, 'kanban');

function parseFrontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return {};
  const fm = {};
  for (const line of m[1].split('\n')) {
    const idx = line.indexOf(':');
    if (idx === -1) continue;
    fm[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
  }
  return fm;
}

function parseSection(text, heading) {
  const re = new RegExp(`## ${heading}\\n([\\s\\S]*?)(?=\\n## |$)`);
  const m = text.match(re);
  return m ? m[1].trim() : '';
}

function readTickets() {
  if (!fs.existsSync(KANBAN_DIR)) return [];
  return fs.readdirSync(KANBAN_DIR)
    .filter(f => f.endsWith('.md'))
    .map(f => {
      const fp = path.join(KANBAN_DIR, f);
      const text = fs.readFileSync(fp, 'utf8');
      const fm = parseFrontmatter(text);
      const id = fm.issue || path.basename(f, '.md');
      const cardPath = path.join(KANBAN_DIR, 'user-test-cards', `${id}-card.md`);
      return {
        issue: id,
        feature: fm.feature || '',
        status: fm.status || 'UNKNOWN',
        port: fm.port || '',
        test_command: fm.test_command || '',
        dependsOn: fm.dependsOn || '',
        whatBuilt: parseSection(text, 'What was built'),
        tests: (text.match(/^- \[x\].*$/gm) || []),
        lastUpdate: (text.match(/^### .+$/gm) || []).slice(-1)[0] || '',
        testCard: fs.existsSync(cardPath) ? fs.readFileSync(cardPath, 'utf8') : null,
      };
    });
}

const STATUS_ORDER = ['IN_PROGRESS', 'NEEDS_ACTION', 'BLOCKED_ON', 'BUILT', 'COMPLETE'];
const STATUS_META = {
  IN_PROGRESS:  { color: '#3b82f6', label: 'In Progress' },
  NEEDS_ACTION: { color: '#f59e0b', label: 'Needs Action' },
  BLOCKED_ON:   { color: '#ef4444', label: 'Blocked On' },
  BUILT:        { color: '#8b5cf6', label: 'Built — Awaiting Review' },
  COMPLETE:     { color: '#10b981', label: 'Complete' },
};

function esc(s) {
  return String(s)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function renderPage(tickets) {
  const grouped = {};
  STATUS_ORDER.forEach(s => grouped[s] = []);
  tickets.forEach(t => {
    const k = STATUS_ORDER.includes(t.status) ? t.status : 'IN_PROGRESS';
    grouped[k].push(t);
  });

  const projectName = path.basename(PROJECT_ROOT);

  const sections = STATUS_ORDER.map(st => {
    const list = grouped[st];
    if (!list.length) return '';
    const { color, label } = STATUS_META[st];

    const cards = list.map(t => {
      const deps = t.dependsOn && t.dependsOn !== '[]' && t.dependsOn !== ''
        ? `<div class="dep">depends on ${esc(t.dependsOn)}</div>` : '';
      const last = t.lastUpdate
        ? `<div class="last">${esc(t.lastUpdate.replace(/^### /,''))}</div>` : '';
      const built = t.whatBuilt
        ? `<p class="what-built">${esc(t.whatBuilt)}</p>` : '';
      const testsHtml = t.tests.length
        ? `<div class="tests"><span>Verified:</span><ul>${t.tests.map(tt =>
            `<li>${esc(tt.replace(/^- \[x\] /,''))}</li>`).join('')}</ul></div>` : '';

      let testBlock = '';
      if (t.testCard) {
        const launchBtn = t.test_command
          ? `<button class="launch-btn" onclick="launch(this,${JSON.stringify(t.test_command)})">▶ Launch Test</button>` : '';
        testBlock = `<div class="test-card"><pre>${esc(t.testCard)}</pre>${launchBtn}</div>`;
      } else if (t.test_command) {
        testBlock = `<div class="test-card"><button class="launch-btn" onclick="launch(this,${JSON.stringify(t.test_command)})">▶ Launch Test</button></div>`;
      }

      return `<div class="ticket">
        <div class="ticket-header">
          <span class="issue">${esc(t.issue)}</span>
          <span class="feature-badge">${esc(t.feature || '—')}</span>
          ${t.port ? `<span class="port-badge">:${esc(t.port)}</span>` : ''}
        </div>
        ${built}${testsHtml}${deps}${last}${testBlock}
      </div>`;
    }).join('');

    return `<div class="col">
      <div class="col-header" style="border-color:${color}">
        <span class="dot" style="background:${color}"></span>
        ${label}
        <span class="count">${list.length}</span>
      </div>
      ${cards}
    </div>`;
  }).join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kanban — ${esc(projectName)}</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'SF Mono','Cascadia Code','Fira Code',monospace;background:#0d1117;color:#e2e8f0;min-height:100vh}
header{padding:18px 28px;border-bottom:1px solid #1e2433;display:flex;align-items:center;gap:12px}
header h1{font-size:17px;font-weight:600;color:#f1f5f9}
.proj{color:#475569;font-size:12px}
.refresh{margin-left:auto;background:#161b27;border:1px solid #2d3748;color:#94a3b8;padding:5px 12px;border-radius:5px;cursor:pointer;font-size:11px;font-family:inherit}
.refresh:hover{background:#1e2433}
.board{display:flex;gap:18px;padding:22px 28px;align-items:flex-start;overflow-x:auto}
.col{flex:0 0 320px}
.col-header{display:flex;align-items:center;gap:7px;padding:8px 0 8px 11px;border-left:3px solid;margin-bottom:10px;font-size:11px;font-weight:700;letter-spacing:.07em;text-transform:uppercase;color:#94a3b8}
.dot{width:7px;height:7px;border-radius:50%;flex-shrink:0}
.count{background:#161b27;border-radius:9px;padding:1px 6px;font-size:10px;color:#475569;margin-left:auto}
.ticket{background:#161b27;border:1px solid #1e2433;border-radius:7px;padding:13px;margin-bottom:9px}
.ticket-header{display:flex;align-items:center;gap:7px;margin-bottom:7px;flex-wrap:wrap}
.issue{font-size:13px;font-weight:600;color:#f1f5f9}
.feature-badge{background:#1e293b;border:1px solid #2d3748;color:#7c9eb5;font-size:10px;padding:2px 7px;border-radius:3px}
.port-badge{background:#161b27;border:1px solid #2d3748;color:#475569;font-size:10px;padding:2px 7px;border-radius:3px}
.what-built{font-size:11px;color:#94a3b8;line-height:1.5;margin-bottom:7px}
.tests{font-size:11px;color:#475569;margin-bottom:7px}
.tests span{color:#475569}
.tests ul{margin-top:3px;padding-left:14px}
.tests li{color:#10b981;margin-bottom:1px}
.dep{font-size:11px;color:#f59e0b;margin-bottom:5px}
.last{font-size:10px;color:#374151;margin-bottom:7px}
.test-card{margin-top:11px;border-top:1px solid #1e2433;padding-top:11px}
.test-card pre{font-size:10px;color:#94a3b8;white-space:pre-wrap;word-break:break-word;line-height:1.5;max-height:240px;overflow-y:auto;background:#0d1117;border-radius:4px;padding:9px;margin-bottom:9px}
.launch-btn{background:#6d28d9;border:none;color:#e2e8f0;padding:6px 14px;border-radius:5px;cursor:pointer;font-size:11px;font-family:inherit;font-weight:600}
.launch-btn:hover{background:#7c3aed}
.launch-btn:disabled{background:#2d3748;color:#475569;cursor:not-allowed}
.launch-out{margin-top:7px;font-size:10px;background:#0d1117;border-radius:4px;padding:7px;white-space:pre-wrap;color:#10b981}
.launch-err{color:#ef4444}
.empty{padding:50px 28px;color:#374151;font-size:13px}
</style>
</head>
<body>
<header>
  <h1>Kanban</h1>
  <span class="proj">${esc(projectName)}</span>
  <button class="refresh" onclick="location.reload()">↺ Refresh</button>
</header>
<div class="board">
${sections || `<div class="empty">No tickets found in ${esc(KANBAN_DIR)}</div>`}
</div>
<script>
async function launch(btn, cmd) {
  btn.disabled = true;
  btn.textContent = '⏳ Launching…';
  let out = btn.nextElementSibling;
  if (!out || !out.classList.contains('launch-out')) {
    out = document.createElement('div');
    out.className = 'launch-out';
    btn.after(out);
  }
  out.textContent = 'Running: ' + cmd;
  try {
    const r = await fetch('/launch', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({command: cmd})
    });
    const j = await r.json();
    if (j.ok) {
      out.textContent = j.output;
      btn.textContent = '✓ Launched';
    } else {
      out.className = 'launch-out launch-err';
      out.textContent = j.error;
      btn.disabled = false;
      btn.textContent = '▶ Launch Test';
    }
  } catch(e) {
    out.className = 'launch-out launch-err';
    out.textContent = 'Request failed: ' + e.message;
    btn.disabled = false;
    btn.textContent = '▶ Launch Test';
  }
}
</script>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/') {
    const tickets = readTickets();
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8'});
    res.end(renderPage(tickets));
    return;
  }

  if (req.method === 'POST' && req.url === '/launch') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const { command } = JSON.parse(body);
        if (!command || typeof command !== 'string') {
          res.writeHead(400, {'Content-Type':'application/json'});
          res.end(JSON.stringify({ok:false, error:'No command'}));
          return;
        }
        const child = spawn('bash', ['-c', command], {detached:true, stdio:'ignore'});
        child.unref();
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:true, output:`Launched in background: ${command}`}));
      } catch(e) {
        res.writeHead(500, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:false, error:e.message}));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`Kanban UI  →  http://localhost:${PORT}`);
  console.log(`Project    →  ${PROJECT_ROOT}`);
  console.log(`Kanban dir →  ${KANBAN_DIR}`);
});
