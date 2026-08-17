const assert = require('assert');
const http = require('http');
const { spawn } = require('child_process');

const port = 43127;
const base = `http://127.0.0.1:${port}`;
const child = spawn(process.execPath, ['server.js'], { env: { ...process.env, PORT: String(port), DASHBOARD_FIXTURE: 'empty' }, stdio: ['ignore', 'pipe', 'pipe'] });
let output = '';
child.stdout.on('data', data => { output += data; });

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request(`${base}${path}`, options, res => { let body = ''; res.on('data', chunk => { body += chunk; }); res.on('end', () => resolve({ status: res.statusCode, body, headers: res.headers })); });
    req.on('error', reject); req.end(options.body);
  });
}

(async () => {
  for (let i = 0; i < 30; i += 1) {
    try { if ((await request('/health')).status === 200) break; } catch {}
    await new Promise(resolve => setTimeout(resolve, 25));
  }
  const health = await request('/health'); assert.equal(health.status, 200);
  const navigation = await request('/api/v1/navigation'); const data = JSON.parse(navigation.body);
  assert.deepEqual(data.entries.map(entry => entry.id), ['connected-tools', 'memory', 'create-page']);
  const page = await request('/api/v1/pages/memory'); assert.equal(page.status, 200);
  const failure = await request('/api/v1/navigation?fail=1'); assert.equal(failure.status, 503); assert.match(failure.body, /temporarily unavailable/);
  const telemetry = await request('/api/v1/telemetry', { method:'POST', headers:{ 'content-type':'application/json' }, body:JSON.stringify({ name:'ui.user_action', interaction_id:'test-interaction', route:'/memory', secret:'must-not-log' }) }); assert.equal(telemetry.status, 202);
  await new Promise(resolve => setTimeout(resolve, 25));
  assert.match(output, /"name":"api\.request\.completed"/); assert.match(output, /"name":"api\.request\.failed"/); assert(!output.includes('must-not-log'));
  child.kill('SIGTERM'); console.log('dashboard shell checks: PASS');
})().catch(error => { child.kill('SIGTERM'); console.error(error.stack); process.exitCode = 1; });
