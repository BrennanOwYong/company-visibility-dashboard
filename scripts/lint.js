const fs = require('fs');
for (const file of ['server.js', 'public/app.js']) {
  const source = fs.readFileSync(file, 'utf8');
  if (/console\.log/.test(source)) { console.error(`lint: unsafe logging marker in ${file}`); process.exit(1); }
}
console.log('lint: PASS');
