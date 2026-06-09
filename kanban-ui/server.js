#!/usr/bin/env node
// kanban-ui/server.js
// Usage: KANBAN_PROJECT_ROOT=/path/to/project node server.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = process.env.KANBAN_UI_PORT || 2999;
const PROJECT_ROOT = process.env.KANBAN_PROJECT_ROOT || process.cwd();
const KANBAN_DIR = path.join(PROJECT_ROOT, 'kanban');
const KNOWLEDGE_DIR = path.join(PROJECT_ROOT, 'knowledge');

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

// Parse a generated test card (flat text) into named sections
function parseTestCard(text) {
  const lines = text.split('\n');
  const sections = { header: '', whatBuilt: '', setup: '', verified: [], yourCall: [] };
  let current = null;

  for (const line of lines) {
    if (/^━+$/.test(line.trim())) continue;
    if (line.startsWith('USER TEST —')) { sections.header = line.replace('USER TEST — ', '').trim(); continue; }
    if (line.startsWith('Issue:')) continue;
    if (line.startsWith('Features:')) continue;
    if (line === 'WHAT WAS BUILT') { current = 'whatBuilt'; continue; }
    if (line === 'SETUP') { current = 'setup'; continue; }
    if (line.startsWith('ALREADY VERIFIED')) { current = 'verified'; continue; }
    if (line === 'YOUR CALL' || line === 'WHAT YOU ARE JUDGING') { current = 'yourCall'; continue; }
    if (line.startsWith('Reply:')) { current = null; continue; }

    if (current === 'whatBuilt' && line.trim()) sections.whatBuilt += line.trim() + ' ';
    if (current === 'setup' && line.trim()) sections.setup = line.trim();
    if (current === 'verified' && line.match(/^- \[x\]/)) sections.verified.push(line.replace(/^- \[x\] /, '').trim());
    if (current === 'yourCall' && line.trim() && !line.startsWith('Think')) {
      const clean = line.replace(/^[•\[\] ]+/, '').trim();
      if (clean) sections.yourCall.push(clean);
    }
  }
  return sections;
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
        testCard: fs.existsSync(cardPath) ? parseTestCard(fs.readFileSync(cardPath, 'utf8')) : null,
      };
    });
}

function renderMarkdown(text) {
  // Minimal markdown: headings, bold, bullets, paragraphs
  return text
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/^### (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h2>$1</h2>')
    .replace(/^# (.+)$/gm, '<h1>$1</h1>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/((<li>.*<\/li>\n?)+)/g, '<ul>$1</ul>')
    .replace(/\n{2,}/g, '</p><p>')
    .replace(/^(?!<[hul])(.+)$/gm, (m) => m.trim() ? m : '')
    .replace(/^<\/p><p>$/gm, '')
    .trim();
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
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function renderDeps(raw) {
  if (!raw || raw === '[]' || raw === '') return '';
  // Parse "[auth-system, analytics-dashboard]" or "auth-system,analytics-dashboard"
  const cleaned = raw.replace(/[\[\]]/g, '').trim();
  if (!cleaned) return '';
  const deps = cleaned.split(',').map(d => d.trim()).filter(Boolean);
  const badges = deps.map(d =>
    `<a class="dep-badge" href="/prd" title="View PRD / feature checklist">${esc(d)}</a>`
  ).join('');
  return `<div class="deps">depends on ${badges}</div>`;
}

function renderTestCardBlock(card, test_command) {
  if (!card) {
    if (!test_command) return '';
    return `<div class="test-card">
      <button class="launch-btn" onclick="launch(this,${JSON.stringify(test_command)})">▶ Launch Test</button>
    </div>`;
  }

  const verifiedHtml = card.verified.length
    ? `<div class="tc-section tc-verified">
        <div class="tc-label">Already verified by builder — skip these</div>
        <ul>${card.verified.map(v => `<li>${esc(v)}</li>`).join('')}</ul>
       </div>` : '';

  const promptsHtml = card.yourCall.length
    ? card.yourCall.map(p => `<div class="tc-prompt">↳ ${esc(p)}</div>`).join('')
    : `<div class="tc-prompt">↳ Does this deliver what you had in mind?</div>
       <div class="tc-prompt">↳ How does the flow feel? Where does it slow you down?</div>
       <div class="tc-prompt">↳ What's your first impression — good or bad?</div>
       <div class="tc-prompt">↳ Would someone who's never seen this know what to do?</div>`;

  const launchBtn = test_command
    ? `<button class="launch-btn" onclick="launch(this,${JSON.stringify(test_command)})">▶ Launch Test</button>` : '';

  return `<div class="test-card">
    ${card.setup ? `<div class="tc-setup"><span class="tc-label">Setup</span><code>${esc(card.setup)}</code>${launchBtn}</div>` : launchBtn ? `<div class="tc-setup">${launchBtn}</div>` : ''}
    ${verifiedHtml}
    <div class="tc-section tc-call">
      <div class="tc-call-header">Your call</div>
      <div class="tc-call-intro">Think back to what you asked for. Walk through this as a real user would — then tell me what you think.</div>
      ${promptsHtml}
    </div>
  </div>`;
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
      const last = t.lastUpdate
        ? `<div class="last">${esc(t.lastUpdate.replace(/^### /,''))}</div>` : '';
      const built = t.whatBuilt
        ? `<p class="what-built">${esc(t.whatBuilt)}</p>` : '';
      const testsHtml = t.tests.length
        ? `<div class="tests"><span>Verified:</span><ul>${t.tests.map(tt =>
            `<li>${esc(tt.replace(/^- \[x\] /,''))}</li>`).join('')}</ul></div>` : '';

      return `<div class="ticket">
        <div class="ticket-header">
          <span class="issue">${esc(t.issue)}</span>
          <span class="feature-badge">${esc(t.feature || '—')}</span>
          ${t.port ? `<span class="port-badge">:${esc(t.port)}</span>` : ''}
        </div>
        ${built}${testsHtml}
        ${renderDeps(t.dependsOn)}
        ${last}
        ${renderTestCardBlock(t.testCard, t.test_command)}
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
.hdr-links{margin-left:auto;display:flex;gap:8px;align-items:center}
.prd-link{color:#7c9eb5;font-size:11px;text-decoration:none;padding:5px 10px;border:1px solid #2d3748;border-radius:5px;background:#161b27}
.prd-link:hover{background:#1e2433;color:#93c5fd}
.refresh{background:#161b27;border:1px solid #2d3748;color:#94a3b8;padding:5px 12px;border-radius:5px;cursor:pointer;font-size:11px;font-family:inherit}
.refresh:hover{background:#1e2433}
.board{display:flex;gap:18px;padding:22px 28px;align-items:flex-start;overflow-x:auto}
.col{flex:0 0 330px}
.col-header{display:flex;align-items:center;gap:7px;padding:8px 0 8px 11px;border-left:3px solid;margin-bottom:10px;font-size:11px;font-weight:700;letter-spacing:.07em;text-transform:uppercase;color:#94a3b8}
.dot{width:7px;height:7px;border-radius:50%;flex-shrink:0}
.count{background:#161b27;border-radius:9px;padding:1px 6px;font-size:10px;color:#475569;margin-left:auto}
.ticket{background:#161b27;border:1px solid #1e2433;border-radius:7px;padding:13px;margin-bottom:9px}
.ticket-header{display:flex;align-items:center;gap:7px;margin-bottom:7px;flex-wrap:wrap}
.issue{font-size:13px;font-weight:600;color:#f1f5f9}
.feature-badge{background:#1e293b;border:1px solid #2d3748;color:#7c9eb5;font-size:10px;padding:2px 7px;border-radius:3px}
.port-badge{background:#0d1117;border:1px solid #1e2433;color:#475569;font-size:10px;padding:2px 7px;border-radius:3px}
.what-built{font-size:11px;color:#94a3b8;line-height:1.5;margin-bottom:7px}
.tests{font-size:11px;color:#475569;margin-bottom:7px}
.tests span{color:#475569}
.tests ul{margin-top:3px;padding-left:14px}
.tests li{color:#10b981;margin-bottom:1px}
.deps{font-size:11px;color:#64748b;margin-bottom:6px;display:flex;flex-wrap:wrap;gap:5px;align-items:center}
.dep-badge{display:inline-block;background:#1a1f2e;border:1px solid #2d3748;color:#7c9eb5;font-size:10px;padding:2px 7px;border-radius:3px;text-decoration:none;cursor:pointer}
.dep-badge:hover{background:#1e293b;border-color:#3d5a80;color:#93c5fd}
.last{font-size:10px;color:#374151;margin-bottom:7px}
.test-card{margin-top:11px;border-top:1px solid #1e2433;padding-top:12px;display:flex;flex-direction:column;gap:10px}
.tc-setup{display:flex;align-items:center;gap:8px;flex-wrap:wrap;background:#0d1117;border-radius:5px;padding:8px 10px}
.tc-setup code{font-size:10px;color:#7dd3fc;font-family:inherit;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tc-label{font-size:10px;color:#475569;text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px;font-weight:600}
.tc-section{display:flex;flex-direction:column;gap:3px}
.tc-verified ul{padding-left:14px;margin-top:4px}
.tc-verified li{font-size:10px;color:#10b981;margin-bottom:2px}
.tc-call{background:#0f1623;border:1px solid #1e3050;border-radius:6px;padding:11px 13px;gap:8px}
.tc-call-header{font-size:11px;font-weight:700;color:#c4b5fd;letter-spacing:.05em;text-transform:uppercase}
.tc-call-intro{font-size:11px;color:#64748b;line-height:1.5;margin-bottom:4px}
.tc-prompt{font-size:12px;color:#94a3b8;line-height:1.6;padding-left:4px}
.launch-btn{background:#6d28d9;border:none;color:#e2e8f0;padding:5px 12px;border-radius:5px;cursor:pointer;font-size:11px;font-family:inherit;font-weight:600;white-space:nowrap;flex-shrink:0}
.launch-btn:hover{background:#7c3aed}
.launch-btn:disabled{background:#2d3748;color:#475569;cursor:not-allowed}
.launch-out{font-size:10px;background:#0d1117;border-radius:4px;padding:7px;white-space:pre-wrap;color:#10b981;border:1px solid #1e2433}
.launch-err{color:#ef4444}
.empty{padding:50px 28px;color:#374151;font-size:13px}
</style>
</head>
<body>
<header>
  <h1>Kanban</h1>
  <span class="proj">${esc(projectName)}</span>
  <div class="hdr-links">
    <a class="prd-link" href="/prd">PRD / feature list</a>
    <button class="refresh" onclick="location.reload()">↺ Refresh</button>
  </div>
</header>
<div class="board">
${sections || `<div class="empty">No tickets found in ${esc(KANBAN_DIR)}</div>`}
</div>
<script>
async function launch(btn, cmd) {
  btn.disabled = true;
  btn.textContent = '⏳ Launching…';
  let out = btn.closest('.test-card').querySelector('.launch-out');
  if (!out) {
    out = document.createElement('div');
    out.className = 'launch-out';
    btn.closest('.test-card').appendChild(out);
  }
  try {
    const r = await fetch('/launch', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({command: cmd})
    });
    const j = await r.json();
    if (j.ok) { out.textContent = j.output; btn.textContent = '✓ Launched'; }
    else { out.className = 'launch-out launch-err'; out.textContent = j.error; btn.disabled = false; btn.textContent = '▶ Launch Test'; }
  } catch(e) {
    out.className = 'launch-out launch-err'; out.textContent = 'Request failed: ' + e.message;
    btn.disabled = false; btn.textContent = '▶ Launch Test';
  }
}
</script>
</body>
</html>`;
}

// Parse user-flow.md into structured feature objects
function parsePrdFeatures(text) {
  const features = [];
  // Split on --- separators between features
  const blocks = text.split(/\n---\n/);
  for (const block of blocks) {
    const nameMatch = block.match(/^### (.+)$/m);
    if (!nameMatch) continue;
    const name = nameMatch[1].trim();

    // Description: text between ### heading and first **bold** label
    const descMatch = block.match(/^### .+\n+([\s\S]*?)(?=\n\*\*|$)/);
    const desc = descMatch ? descMatch[1].trim() : '';

    // User flow steps
    const flowMatch = block.match(/\*\*User flow:\*\*\n([\s\S]*?)(?=\n\*\*|$)/);
    const flow = flowMatch
      ? flowMatch[1].split('\n').map(l => l.trim()).filter(l => /^\d+\./.test(l)).map(l => l.replace(/^\d+\.\s*/, ''))
      : [];

    // Edge cases
    const edgesMatch = block.match(/\*\*Edge cases:\*\*\n([\s\S]*?)(?=\n\*\*|$)/);
    const edges = edgesMatch
      ? edgesMatch[1].split('\n').map(l => l.trim()).filter(l => l.startsWith('-')).map(l => l.replace(/^-\s*/, ''))
      : [];

    // Issue tickets
    const issuesMatch = block.match(/\*\*Issue tickets:\*\*\s*(.+)$/m);
    const issues = issuesMatch ? issuesMatch[1].split(',').map(i => i.trim()).filter(Boolean) : [];

    features.push({ name, desc, flow, edges, issues });
  }
  return features;
}

const FEATURE_ACCENTS = ['#6d28d9','#0891b2','#059669','#b45309','#be185d','#7c3aed'];

function renderPrdPage() {
  const prdPath = path.join(KNOWLEDGE_DIR, 'user-flow.md');
  const projectName = path.basename(PROJECT_ROOT);

  const noDataPage = (msg) => `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<title>PRD — ${esc(projectName)}</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'SF Mono',monospace;background:#0d1117;color:#e2e8f0;min-height:100vh}
header{padding:16px 28px;border-bottom:1px solid #1e2433;display:flex;align-items:center;gap:12px}
a.back{color:#7c9eb5;font-size:12px;text-decoration:none}.msg{padding:40px 28px;color:#475569;font-size:12px}code{background:#161b27;border:1px solid #1e2433;padding:2px 6px;border-radius:3px;color:#7dd3fc}</style>
</head><body>
<header><a class="back" href="/">← Board</a></header>
<div class="msg">${msg}</div></body></html>`;

  if (!fs.existsSync(prdPath)) {
    return noDataPage(`No PRD found at <code>knowledge/user-flow.md</code>. The coordinator writes this during the spec phase.`);
  }

  const raw = fs.readFileSync(prdPath, 'utf8');

  // Extract top-level title and intro (before first ### feature block)
  const titleMatch = raw.match(/^# (.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : projectName;
  const introMatch = raw.match(/^# .+\n+([\s\S]*?)(?=\n###|$)/);
  const intro = introMatch ? introMatch[1].trim() : '';

  const features = parsePrdFeatures(raw);
  if (!features.length) return noDataPage('PRD exists but contains no feature sections (expected <code>### feature-name</code> headings).');

  const featureCards = features.map((f, i) => {
    const accent = FEATURE_ACCENTS[i % FEATURE_ACCENTS.length];

    const flowSteps = f.flow.map((step, idx) =>
      `<div class="flow-step">
        <span class="step-num">${idx + 1}</span>
        <span class="step-text">${esc(step)}</span>
      </div>`
    ).join('');

    const edgeItems = f.edges.map(e =>
      `<li>${esc(e)}</li>`
    ).join('');

    const issueBadges = f.issues.map(iss =>
      `<a class="issue-badge" href="/?issue=${esc(iss)}" title="View on board">↗ ${esc(iss)}</a>`
    ).join('');

    return `<div class="feature-card" style="--accent:${accent}">
      <div class="fc-header">
        <div class="fc-accent-bar"></div>
        <div class="fc-title-row">
          <span class="fc-name">${esc(f.name)}</span>
          ${issueBadges ? `<div class="fc-issues">${issueBadges}</div>` : ''}
        </div>
      </div>
      ${f.desc ? `<p class="fc-desc">${esc(f.desc)}</p>` : ''}
      ${f.flow.length ? `
      <div class="fc-section">
        <div class="fc-section-label">User flow</div>
        <div class="flow-steps">${flowSteps}</div>
      </div>` : ''}
      ${f.edges.length ? `
      <div class="fc-section">
        <div class="fc-section-label">Edge cases</div>
        <ul class="edge-list">${edgeItems}</ul>
      </div>` : ''}
    </div>`;
  }).join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PRD — ${esc(projectName)}</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'SF Mono','Cascadia Code','Fira Code',monospace;background:#0d1117;color:#e2e8f0;min-height:100vh}
header{padding:16px 28px;border-bottom:1px solid #1e2433;display:flex;align-items:center;gap:14px}
a.back{color:#7c9eb5;font-size:11px;text-decoration:none;padding:4px 10px;border:1px solid #2d3748;border-radius:4px;background:#161b27}
a.back:hover{background:#1e2433;color:#93c5fd}
.hdr-title{font-size:16px;font-weight:600;color:#f1f5f9}
.hdr-sub{font-size:11px;color:#475569}
.prd-body{max-width:860px;margin:0 auto;padding:32px 28px;display:flex;flex-direction:column;gap:20px}
.prd-intro{font-size:12px;color:#64748b;line-height:1.7;padding:0 2px}
.feature-card{background:#161b27;border:1px solid #1e2433;border-radius:8px;overflow:hidden}
.fc-header{display:flex;align-items:stretch;gap:0}
.fc-accent-bar{width:4px;background:var(--accent);flex-shrink:0}
.fc-title-row{display:flex;align-items:center;justify-content:space-between;flex:1;padding:14px 16px;flex-wrap:wrap;gap:8px}
.fc-name{font-size:14px;font-weight:700;color:#f1f5f9;letter-spacing:.02em}
.fc-issues{display:flex;gap:6px;flex-wrap:wrap}
.issue-badge{display:inline-block;background:#0d1117;border:1px solid #2d3748;color:#7c9eb5;font-size:10px;padding:3px 9px;border-radius:4px;text-decoration:none;transition:all .15s}
.issue-badge:hover{background:#1e293b;border-color:var(--accent);color:#e2e8f0}
.fc-desc{font-size:12px;color:#94a3b8;line-height:1.65;padding:0 16px 14px 20px}
.fc-section{padding:0 16px 14px 20px;display:flex;flex-direction:column;gap:8px}
.fc-section+.fc-section{border-top:1px solid #1e2433;padding-top:14px}
.fc-section-label{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:#475569}
.flow-steps{display:flex;flex-direction:column;gap:6px}
.flow-step{display:flex;align-items:flex-start;gap:10px}
.step-num{width:20px;height:20px;border-radius:50%;background:var(--accent);color:#fff;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:1px;opacity:.85}
.step-text{font-size:12px;color:#cbd5e1;line-height:1.55}
.edge-list{padding-left:0;list-style:none;display:flex;flex-direction:column;gap:5px}
.edge-list li{font-size:11px;color:#64748b;line-height:1.5;padding-left:14px;position:relative}
.edge-list li::before{content:"⚠";position:absolute;left:0;font-size:9px;top:2px;color:#92400e}
</style>
</head>
<body>
<header>
  <a class="back" href="/">← Board</a>
  <div>
    <div class="hdr-title">${esc(title)}</div>
    <div class="hdr-sub">${features.length} feature${features.length !== 1 ? 's' : ''} · knowledge/user-flow.md</div>
  </div>
</header>
<div class="prd-body">
  ${intro ? `<p class="prd-intro">${esc(intro)}</p>` : ''}
  ${featureCards}
</div>
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

  if (req.method === 'GET' && req.url === '/prd') {
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8'});
    res.end(renderPrdPage());
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
  console.log(`PRD        →  ${PROJECT_ROOT}/knowledge/user-flow.md`);
});
