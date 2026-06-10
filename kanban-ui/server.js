#!/usr/bin/env node
// kanban-ui/server.js — coordinator kanban board
// Usage: KANBAN_PROJECT_ROOT=/path/to/project node server.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const UI_PORT = process.env.KANBAN_UI_PORT || 2999;
const PROJECT_ROOT = process.env.KANBAN_PROJECT_ROOT || process.cwd();
const KANBAN_DIR = path.join(PROJECT_ROOT, 'kanban');
const KNOWLEDGE_DIR = path.join(PROJECT_ROOT, 'knowledge');
const PORTS_FILE = path.join(KANBAN_DIR, '.ports.json');

// ── Port registry ────────────────────────────────────────────────────────────

function readPortRegistry() {
  if (!fs.existsSync(PORTS_FILE)) return {};
  try { return JSON.parse(fs.readFileSync(PORTS_FILE, 'utf8')); }
  catch { return {}; }
}

function collectUsedPorts() {
  const ports = new Set([parseInt(UI_PORT)]);
  if (fs.existsSync(KANBAN_DIR)) {
    fs.readdirSync(KANBAN_DIR)
      .filter(f => f.endsWith('.md'))
      .forEach(f => {
        const text = fs.readFileSync(path.join(KANBAN_DIR, f), 'utf8');
        const fm = parseFrontmatter(text);
        if (fm.port && !isNaN(parseInt(fm.port))) ports.add(parseInt(fm.port));
      });
  }
  Object.values(readPortRegistry()).forEach(p => {
    if (!isNaN(parseInt(p))) ports.add(parseInt(p));
  });
  return ports;
}

function pickFreshPort() {
  const used = collectUsedPorts();
  let p = 4000;
  while (used.has(p)) p++;
  return p;
}

function registerTestPort(issue, port) {
  const reg = readPortRegistry();
  reg[`test:${issue}`] = port;
  try { fs.writeFileSync(PORTS_FILE, JSON.stringify(reg, null, 2)); } catch {}
}

// ── Markdown / frontmatter parsing ───────────────────────────────────────────

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

function parseTestCard(text) {
  const lines = text.split('\n');
  const sections = { header: '', whatBuilt: '', setup: '', verified: [], yourCall: [] };
  let current = null;
  for (const line of lines) {
    if (/^━+$/.test(line.trim())) continue;
    if (line.startsWith('USER TEST —')) { sections.header = line.replace('USER TEST — ', '').trim(); continue; }
    if (line.startsWith('Issue:') || line.startsWith('Features:')) continue;
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

// ── Ticket reading ───────────────────────────────────────────────────────────

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
        status: fm.status || 'UNSTARTED',
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

// ── HTML escaping ─────────────────────────────────────────────────────────────

function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Card fragments ────────────────────────────────────────────────────────────

function renderDeps(raw, allTickets) {
  if (!raw || raw === '[]' || raw === '') return '';
  const cleaned = raw.replace(/[\[\]]/g, '').trim();
  if (!cleaned) return '';
  const deps = cleaned.split(',').map(d => d.trim()).filter(Boolean);
  const badges = deps.map(d => {
    const dep = allTickets && allTickets.find(t => t.issue === d);
    const anchor = dep && dep.feature ? `#${dep.feature}` : '';
    return `<a class="dep-badge" href="/prd${anchor}">${esc(d)}</a>`;
  }).join('');
  return `<div class="deps">depends on ${badges}</div>`;
}

// context: 'review' | 'complete' | 'other'
function renderTestCardBlock(card, test_command, feature, issue, context) {
  if (context === 'other') return '';

  const featureLink = feature
    ? `<a class="tc-feature-link" href="/prd#${esc(feature)}">${esc(feature)} ↗</a>` : '';

  const feedbackForm = `
    <div class="feedback-form" id="fb-${esc(issue)}" style="display:none">
      <textarea class="fb-input" placeholder="What did you think? Does this deliver what you asked for? Where did it slow you down or feel off?" rows="3"></textarea>
      <div class="fb-actions">
        <button class="fb-submit" onclick="submitFeedback('${esc(issue)}')">Submit feedback</button>
        <span class="fb-hint">Writes to the kanban file for the coordinator.</span>
      </div>
      <div class="fb-result" id="fb-result-${esc(issue)}"></div>
    </div>`;

  const showFeedbackBtn = context === 'review';
  const showTestBtn = (context === 'review' || context === 'complete');

  // No card yet — simple button layout
  if (!card) {
    if (!showTestBtn && !showFeedbackBtn) return '';
    const testBtn = (showTestBtn && test_command)
      ? `<button class="launch-btn" onclick="launchAndReveal(this,'${esc(issue)}',${JSON.stringify(test_command)})">▶ Test this feature</button>`
      : '';
    const fbBtn = (showFeedbackBtn && !test_command)
      ? `<button class="launch-btn launch-plain" onclick="revealFeedback('${esc(issue)}')">Give feedback</button>`
      : '';
    if (!testBtn && !fbBtn) return '';
    return `<div class="test-card">${featureLink}<div class="tc-setup">${testBtn}${fbBtn}</div>${showFeedbackBtn ? feedbackForm : ''}</div>`;
  }

  // Verified items — in a collapsible so non-technical users skip them
  const verifiedHtml = card.verified.length
    ? `<details class="tc-verified-details">
        <summary class="tc-verified-summary">What the builder already checked (${card.verified.length})</summary>
        <ul class="tc-verified-list">${card.verified.map(v => `<li>${esc(v)}</li>`).join('')}</ul>
       </details>`
    : '';

  const promptsHtml = card.yourCall.length
    ? card.yourCall.map(p => `<div class="tc-prompt">↳ ${esc(p)}</div>`).join('')
    : `<div class="tc-prompt">↳ Does this deliver what you had in mind?</div>
       <div class="tc-prompt">↳ How does the flow feel? Where does it slow you down?</div>
       <div class="tc-prompt">↳ What's your first impression — good or bad?</div>
       <div class="tc-prompt">↳ Would someone who's never seen this know what to do?</div>`;

  const testBtn = (showTestBtn && test_command)
    ? `<button class="launch-btn" onclick="launchAndReveal(this,'${esc(issue)}',${JSON.stringify(test_command)})">▶ Test this feature</button>`
    : '';
  const fbBtn = (showFeedbackBtn && !test_command)
    ? `<button class="launch-btn launch-plain" onclick="revealFeedback('${esc(issue)}')">Give feedback</button>`
    : '';

  return `<div class="test-card">
    ${featureLink}
    ${(testBtn || fbBtn)
      ? (card.setup
          ? `<div class="tc-setup"><code>${esc(card.setup)}</code>${testBtn}${fbBtn}</div>`
          : `<div class="tc-setup">${testBtn}${fbBtn}</div>`)
      : ''}
    ${verifiedHtml}
    <div class="tc-section tc-call">
      <div class="tc-call-header">Your call</div>
      <div class="tc-call-intro">Think back to what you asked for. Walk through this as a real user — then tell me what you think.</div>
      ${promptsHtml}
    </div>
    ${showFeedbackBtn ? feedbackForm : ''}
  </div>`;
}

function renderTicketCard(t, context, allTickets) {
  const featureHref = t.feature ? `/prd#${esc(t.feature)}` : '/prd';
  const built = t.whatBuilt ? `<p class="what-built">${esc(t.whatBuilt)}</p>` : '';
  const last = t.lastUpdate
    ? `<div class="last">${esc(t.lastUpdate.replace(/^### /, ''))}</div>` : '';

  return `<div class="ticket" id="ticket-${esc(t.issue)}">
    <div class="ticket-header">
      <span class="issue">${esc(t.issue)}</span>
      <a class="feature-badge" href="${featureHref}">${esc(t.feature || '—')}</a>
    </div>
    ${built}
    ${renderDeps(t.dependsOn, allTickets)}
    ${last}
    ${renderTestCardBlock(t.testCard, t.test_command, t.feature, t.issue, context)}
  </div>`;
}

// ── Page render ───────────────────────────────────────────────────────────────

function renderPage(tickets) {
  const projectName = path.basename(PROJECT_ROOT);

  const unstarted    = tickets.filter(t => t.status === 'UNSTARTED');
  const inProgress   = tickets.filter(t => t.status === 'IN_PROGRESS');
  const blocked      = tickets.filter(t => ['NEEDS_ACTION', 'BLOCKED_ON'].includes(t.status));
  const needsReview  = tickets.filter(t => t.status === 'BUILT');
  const complete     = tickets.filter(t => t.status === 'COMPLETE');
  // Anything else → in-progress
  const unknown      = tickets.filter(t => !['UNSTARTED','IN_PROGRESS','NEEDS_ACTION','BLOCKED_ON','BUILT','COMPLETE'].includes(t.status));

  const allInProgress = [...inProgress, ...unknown];

  function colCards(list, context) {
    return list.map(t => renderTicketCard(t, context, tickets)).join('');
  }

  const unstartedCol = `<div class="col">
    <div class="col-header" style="border-color:#475569">
      <span class="dot" style="background:#475569"></span>
      Unstarted
      <span class="count">${unstarted.length}</span>
    </div>
    ${unstarted.length ? colCards(unstarted, 'other') : '<div class="col-empty">Nothing queued yet</div>'}
  </div>`;

  const inProgressCol = `<div class="col">
    <div class="col-header" style="border-color:#3b82f6">
      <span class="dot" style="background:#3b82f6"></span>
      In Progress
      <span class="count">${allInProgress.length}</span>
    </div>
    ${allInProgress.length ? colCards(allInProgress, 'other') : '<div class="col-empty">Nothing in progress</div>'}
  </div>`;

  // Blocked column — dual pane with sliding header
  const blockedCol = `<div class="col">
    <div class="col-header blocked-col-header" style="border-color:#ef4444" onclick="toggleBlockedCol(this)" title="Click to switch view">
      <div class="blocked-slide-track">
        <div class="blocked-slide-inner" id="blocked-slide">
          <span class="slide-face">
            <span class="dot" style="background:#ef4444"></span>
            Blocked
            <span class="count">${blocked.length}</span>
          </span>
          <span class="slide-face">
            <span class="dot" style="background:#8b5cf6"></span>
            Needs Review
            <span class="count">${needsReview.length}</span>
          </span>
        </div>
      </div>
      <span class="toggle-hint">click to toggle</span>
    </div>
    <div id="blocked-pane-blocked">
      ${blocked.length ? colCards(blocked, 'other') : '<div class="col-empty">No blockers</div>'}
    </div>
    <div id="blocked-pane-review" style="display:none">
      ${needsReview.length ? colCards(needsReview, 'review') : '<div class="col-empty">Nothing awaiting review</div>'}
    </div>
  </div>`;

  const completeCol = `<div class="col">
    <div class="col-header" style="border-color:#10b981">
      <span class="dot" style="background:#10b981"></span>
      Done
      <span class="count">${complete.length}</span>
    </div>
    ${complete.length ? colCards(complete, 'complete') : '<div class="col-empty">Nothing complete yet</div>'}
  </div>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kanban — ${esc(projectName)}</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d1117;color:#e2e8f0;min-height:100vh;font-size:14px}
header{padding:20px 32px;border-bottom:1px solid #1e2433;display:flex;align-items:center;gap:14px}
header h1{font-size:19px;font-weight:700;color:#f1f5f9}
.proj{color:#475569;font-size:13px}
.hdr-links{margin-left:auto;display:flex;gap:8px;align-items:center}
.prd-link{color:#7c9eb5;font-size:12px;text-decoration:none;padding:6px 12px;border:1px solid #2d3748;border-radius:6px;background:#161b27}
.prd-link:hover{background:#1e2433;color:#93c5fd}
.refresh{background:#161b27;border:1px solid #2d3748;color:#94a3b8;padding:6px 14px;border-radius:6px;cursor:pointer;font-size:12px;font-family:inherit}
.refresh:hover{background:#1e2433}
.board{display:flex;gap:20px;padding:24px 32px;align-items:flex-start;overflow-x:auto;min-height:calc(100vh - 72px)}
.col{flex:0 0 340px}
.col-header{display:flex;align-items:center;gap:8px;padding:10px 0 10px 12px;border-left:3px solid;margin-bottom:12px;font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:#94a3b8}
.dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.count{background:#161b27;border-radius:10px;padding:2px 8px;font-size:11px;color:#475569;margin-left:auto}
.col-empty{font-size:13px;color:#374151;padding:16px 0;font-style:italic}

/* Blocked column sliding header */
.blocked-col-header{cursor:pointer;user-select:none;padding-right:10px}
.blocked-col-header:hover{opacity:.85}
.blocked-slide-track{overflow:hidden;flex:1;min-width:0}
.blocked-slide-inner{display:flex;width:200%;transition:transform .35s cubic-bezier(.4,0,.2,1)}
.blocked-slide-inner.in-review{transform:translateX(-50%)}
.slide-face{width:50%;display:flex;align-items:center;gap:8px;font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:#94a3b8;white-space:nowrap}
.toggle-hint{font-size:10px;color:#2d3748;letter-spacing:0;text-transform:none;font-weight:400;white-space:nowrap;flex-shrink:0}

/* Ticket card */
.ticket{background:#161b27;border:1px solid #1e2433;border-radius:8px;padding:16px;margin-bottom:10px}
.ticket-header{display:flex;align-items:center;gap:8px;margin-bottom:10px;flex-wrap:wrap}
.issue{font-size:15px;font-weight:700;color:#f1f5f9}
.feature-badge{background:#1e293b;border:1px solid #2d3748;color:#7c9eb5;font-size:11px;padding:3px 9px;border-radius:4px;text-decoration:none}
.feature-badge:hover{background:#1e3a5f;border-color:#3d5a80;color:#93c5fd}
.what-built{font-size:13px;color:#94a3b8;line-height:1.6;margin-bottom:10px}
.deps{font-size:12px;color:#64748b;margin-bottom:8px;display:flex;flex-wrap:wrap;gap:5px;align-items:center}
.dep-badge{display:inline-block;background:#1a1f2e;border:1px solid #2d3748;color:#7c9eb5;font-size:11px;padding:3px 8px;border-radius:4px;text-decoration:none}
.dep-badge:hover{background:#1e293b;border-color:#3d5a80;color:#93c5fd}
.last{font-size:11px;color:#374151;margin-bottom:10px}

/* Test card */
.test-card{margin-top:14px;border-top:1px solid #1e2433;padding-top:14px;display:flex;flex-direction:column;gap:12px}
.tc-setup{display:flex;align-items:center;gap:10px;flex-wrap:wrap;background:#0d1117;border-radius:6px;padding:10px 12px}
.tc-setup code{font-size:11px;color:#7dd3fc;font-family:'SF Mono','Cascadia Code',monospace;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tc-feature-link{font-size:11px;color:#7c9eb5;text-decoration:none;font-weight:600;letter-spacing:.04em;text-transform:uppercase}
.tc-feature-link:hover{color:#93c5fd}

/* Collapsible verified section */
.tc-verified-details{border-radius:5px;overflow:hidden}
.tc-verified-summary{font-size:11px;color:#475569;cursor:pointer;padding:6px 2px;list-style:none;display:flex;align-items:center;gap:4px;user-select:none}
.tc-verified-summary::before{content:'▸';font-size:9px;transition:transform .2s}
.tc-verified-details[open] .tc-verified-summary::before{transform:rotate(90deg)}
.tc-verified-summary:hover{color:#64748b}
.tc-verified-list{padding-left:16px;margin-top:6px}
.tc-verified-list li{font-size:12px;color:#10b981;margin-bottom:3px;line-height:1.5}

/* Your call section */
.tc-call{background:#0f1623;border:1px solid #1e3050;border-radius:7px;padding:14px 16px;display:flex;flex-direction:column;gap:10px}
.tc-call-header{font-size:12px;font-weight:700;color:#c4b5fd;letter-spacing:.05em;text-transform:uppercase}
.tc-call-intro{font-size:13px;color:#64748b;line-height:1.6}
.tc-prompt{font-size:14px;color:#94a3b8;line-height:1.65;padding-left:4px}

/* Buttons */
.launch-btn{background:#6d28d9;border:none;color:#e2e8f0;padding:7px 14px;border-radius:6px;cursor:pointer;font-size:13px;font-family:inherit;font-weight:600;white-space:nowrap;flex-shrink:0}
.launch-btn:hover{background:#7c3aed}
.launch-btn:disabled{background:#2d3748;color:#475569;cursor:not-allowed}
.launch-plain{background:#1e293b;border:1px solid #2d3748}
.launch-plain:hover{background:#273548}
.launch-link{display:inline-block;margin-top:6px;font-size:12px;color:#7dd3fc;text-decoration:underline;text-decoration-style:dotted;cursor:pointer}

/* Feedback form */
.feedback-form{flex-direction:column;gap:10px;background:#0a0f1a;border:1px solid #1e3050;border-radius:7px;padding:14px 16px}
.fb-input{background:#161b27;border:1px solid #2d3748;color:#e2e8f0;border-radius:6px;padding:10px 12px;font-size:13px;font-family:inherit;resize:vertical;width:100%;line-height:1.6}
.fb-input:focus{outline:none;border-color:#6d28d9}
.fb-input::placeholder{color:#374151}
.fb-actions{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
.fb-submit{background:#6d28d9;border:none;color:#e2e8f0;padding:7px 16px;border-radius:6px;cursor:pointer;font-size:13px;font-family:inherit;font-weight:600}
.fb-submit:hover{background:#7c3aed}
.fb-submit:disabled{background:#2d3748;color:#475569;cursor:not-allowed}
.fb-hint{font-size:11px;color:#374151}
.fb-result{font-size:12px;color:#10b981;margin-top:2px}
</style>
</head>
<body>
<header>
  <h1>Kanban</h1>
  <span class="proj">${esc(projectName)}</span>
  <div class="hdr-links">
    <a class="prd-link" href="/prd">Feature list</a>
    <button class="refresh" onclick="location.reload()">↺ Refresh</button>
  </div>
</header>
<div class="board">
  ${unstartedCol}
  ${inProgressCol}
  ${blockedCol}
  ${completeCol}
</div>
<script>
// Blocked column toggle
function toggleBlockedCol(hdr) {
  const slide = document.getElementById('blocked-slide');
  const paneBlocked = document.getElementById('blocked-pane-blocked');
  const paneReview  = document.getElementById('blocked-pane-review');
  const inReview = slide.classList.contains('in-review');
  if (inReview) {
    slide.classList.remove('in-review');
    paneBlocked.style.display = '';
    paneReview.style.display  = 'none';
  } else {
    slide.classList.add('in-review');
    paneBlocked.style.display = 'none';
    paneReview.style.display  = '';
  }
}

// Launch a feature test — server picks a fresh port
async function launchAndReveal(btn, issue, cmd) {
  btn.disabled = true;
  btn.textContent = '⏳ Launching…';
  try {
    const r = await fetch('/launch', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({command: cmd, issue}),
    });
    const j = await r.json();
    if (j.ok) {
      btn.textContent = '✓ Launched';
      if (j.url) {
        const link = document.createElement('a');
        link.href = j.url;
        link.target = '_blank';
        link.className = 'launch-link';
        link.textContent = 'Open → ' + j.url;
        btn.parentNode.appendChild(link);
      }
    } else {
      btn.disabled = false;
      btn.textContent = '▶ Test this feature';
    }
  } catch(e) {
    btn.disabled = false;
    btn.textContent = '▶ Test this feature';
  }
  revealFeedback(issue);
}

function revealFeedback(issue) {
  const form = document.getElementById('fb-' + issue);
  if (form) { form.style.display = 'flex'; form.querySelector('.fb-input').focus(); }
}

async function submitFeedback(issue) {
  const form   = document.getElementById('fb-' + issue);
  const text   = form.querySelector('.fb-input').value.trim();
  if (!text) return;
  const result = document.getElementById('fb-result-' + issue);
  const btn    = form.querySelector('.fb-submit');
  btn.disabled = true;
  result.textContent = 'Saving…';
  try {
    const r = await fetch('/feedback', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({issue, feedback: text}),
    });
    const j = await r.json();
    if (j.ok) {
      result.textContent = 'Saved. Tell the coordinator your verdict.';
      form.querySelector('.fb-input').disabled = true;
    } else {
      result.style.color = '#ef4444';
      result.textContent = j.error;
      btn.disabled = false;
    }
  } catch(e) {
    result.style.color = '#ef4444';
    result.textContent = 'Request failed: ' + e.message;
    btn.disabled = false;
  }
}
</script>
</body>
</html>`;
}

// ── PRD page ──────────────────────────────────────────────────────────────────

function parsePrdFeatures(text) {
  const features = [];
  const blocks = text.split(/\n---\n/);
  for (const block of blocks) {
    const nameMatch = block.match(/^### (.+)$/m);
    if (!nameMatch) continue;
    const name = nameMatch[1].trim();
    const descMatch = block.match(/^### .+\n+([\s\S]*?)(?=\n\*\*|$)/);
    const desc = descMatch ? descMatch[1].trim() : '';
    const flowMatch = block.match(/\*\*User flow:\*\*\n([\s\S]*?)(?=\n\*\*|$)/);
    const flow = flowMatch
      ? flowMatch[1].split('\n').map(l => l.trim()).filter(l => /^\d+\./.test(l)).map(l => l.replace(/^\d+\.\s*/, ''))
      : [];
    const edgesMatch = block.match(/\*\*Edge cases:\*\*\n([\s\S]*?)(?=\n\*\*|$)/);
    const edges = edgesMatch
      ? edgesMatch[1].split('\n').map(l => l.trim()).filter(l => l.startsWith('-')).map(l => l.replace(/^-\s*/, ''))
      : [];
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
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d1117;color:#e2e8f0;min-height:100vh;font-size:14px}
header{padding:16px 32px;border-bottom:1px solid #1e2433;display:flex;align-items:center;gap:12px}
a.back{color:#7c9eb5;font-size:13px;text-decoration:none}.msg{padding:40px 32px;color:#475569;font-size:13px}
code{background:#161b27;border:1px solid #1e2433;padding:2px 6px;border-radius:3px;color:#7dd3fc;font-family:'SF Mono',monospace}</style>
</head><body>
<header><a class="back" href="/">← Board</a></header>
<div class="msg">${msg}</div></body></html>`;

  if (!fs.existsSync(prdPath)) {
    return noDataPage(`No PRD found at <code>knowledge/user-flow.md</code>. The coordinator writes this during the spec phase.`);
  }

  const raw = fs.readFileSync(prdPath, 'utf8');
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
    const edgeItems = f.edges.map(e => `<li>${esc(e)}</li>`).join('');
    const issueBadges = f.issues.map(iss =>
      `<a class="issue-badge" href="/?issue=${esc(iss)}">↗ ${esc(iss)}</a>`
    ).join('');
    return `<div class="feature-card" id="${esc(f.name)}" style="--accent:${accent}">
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
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d1117;color:#e2e8f0;min-height:100vh;font-size:14px}
header{padding:18px 32px;border-bottom:1px solid #1e2433;display:flex;align-items:center;gap:14px}
a.back{color:#7c9eb5;font-size:13px;text-decoration:none;padding:5px 12px;border:1px solid #2d3748;border-radius:5px;background:#161b27}
a.back:hover{background:#1e2433;color:#93c5fd}
.hdr-title{font-size:17px;font-weight:700;color:#f1f5f9}
.hdr-sub{font-size:12px;color:#475569}
.prd-body{max-width:860px;margin:0 auto;padding:32px 32px;display:flex;flex-direction:column;gap:20px}
.prd-intro{font-size:13px;color:#64748b;line-height:1.7}
.feature-card{background:#161b27;border:1px solid #1e2433;border-radius:8px;overflow:hidden}
.fc-header{display:flex;align-items:stretch}
.fc-accent-bar{width:4px;background:var(--accent);flex-shrink:0}
.fc-title-row{display:flex;align-items:center;justify-content:space-between;flex:1;padding:16px 18px;flex-wrap:wrap;gap:8px}
.fc-name{font-size:15px;font-weight:700;color:#f1f5f9}
.fc-issues{display:flex;gap:6px;flex-wrap:wrap}
.issue-badge{display:inline-block;background:#0d1117;border:1px solid #2d3748;color:#7c9eb5;font-size:11px;padding:3px 10px;border-radius:4px;text-decoration:none}
.issue-badge:hover{background:#1e293b;border-color:var(--accent);color:#e2e8f0}
.fc-desc{font-size:13px;color:#94a3b8;line-height:1.65;padding:0 18px 14px 22px}
.fc-section{padding:0 18px 14px 22px;display:flex;flex-direction:column;gap:8px}
.fc-section+.fc-section{border-top:1px solid #1e2433;padding-top:14px}
.fc-section-label{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:#475569}
.flow-steps{display:flex;flex-direction:column;gap:7px}
.flow-step{display:flex;align-items:flex-start;gap:10px}
.step-num{width:22px;height:22px;border-radius:50%;background:var(--accent);color:#fff;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:1px;opacity:.85}
.step-text{font-size:13px;color:#cbd5e1;line-height:1.55}
.edge-list{padding-left:0;list-style:none;display:flex;flex-direction:column;gap:5px}
.edge-list li{font-size:12px;color:#64748b;line-height:1.5;padding-left:16px;position:relative}
.edge-list li::before{content:"⚠";position:absolute;left:0;font-size:9px;top:2px;color:#92400e}
</style>
</head>
<body>
<header>
  <a class="back" href="/">← Board</a>
  <div>
    <div class="hdr-title">${esc(title)}</div>
    <div class="hdr-sub">${features.length} feature${features.length !== 1 ? 's' : ''}</div>
  </div>
</header>
<div class="prd-body">
  ${intro ? `<p class="prd-intro">${esc(intro)}</p>` : ''}
  ${featureCards}
</div>
</body>
</html>`;
}

// ── HTTP server ───────────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/') {
    const tickets = readTickets();
    res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
    res.end(renderPage(tickets));
    return;
  }

  if (req.method === 'GET' && req.url === '/prd') {
    res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
    res.end(renderPrdPage());
    return;
  }

  if (req.method === 'GET' && req.url === '/ports') {
    const used = collectUsedPorts();
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({used: [...used].sort((a,b)=>a-b), registry: readPortRegistry()}));
    return;
  }

  if (req.method === 'POST' && req.url === '/launch') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const { command, issue } = JSON.parse(body);
        if (!command || typeof command !== 'string') {
          res.writeHead(400, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({ok: false, error: 'No command'}));
          return;
        }
        const freshPort = pickFreshPort();
        if (issue) registerTestPort(issue, freshPort);
        const env = Object.assign({}, process.env, {PORT: String(freshPort)});
        const child = spawn('bash', ['-c', command], {detached: true, stdio: 'ignore', env});
        child.unref();
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({ok: true, port: freshPort, url: `http://localhost:${freshPort}`}));
      } catch(e) {
        res.writeHead(500, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({ok: false, error: e.message}));
      }
    });
    return;
  }

  if (req.method === 'POST' && req.url === '/feedback') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const { issue, feedback } = JSON.parse(body);
        if (!issue || !feedback) {
          res.writeHead(400, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({ok: false, error: 'issue and feedback required'}));
          return;
        }
        const kf = path.join(KANBAN_DIR, `${issue}.md`);
        if (!fs.existsSync(kf)) {
          res.writeHead(404, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({ok: false, error: `No kanban file for ${issue}`}));
          return;
        }
        let content = fs.readFileSync(kf, 'utf8');
        if (content.includes('## Feedback from user')) {
          content = content.replace(/## Feedback from user\n[\s\S]*?(?=\n## |\s*$)/, `## Feedback from user\n${feedback}\n`);
        } else {
          content += `\n## Feedback from user\n${feedback}\n`;
        }
        fs.writeFileSync(kf, content);
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({ok: true}));
      } catch(e) {
        res.writeHead(500, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({ok: false, error: e.message}));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(UI_PORT, () => {
  console.log(`Kanban UI  →  http://localhost:${UI_PORT}`);
  console.log(`Project    →  ${PROJECT_ROOT}`);
  console.log(`Ports      →  http://localhost:${UI_PORT}/ports`);
});
