const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.dao', 'workspaces', 'cd03dea5683d', 'config.json'), 'utf8'));
const auth1 = cfg.devinAuth1, org = cfg.devinOrgId, bare = org.replace(/^org-/, '');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36';
const RULES = fs.readFileSync('C:\\Users\\Administrator\\plugins\\dao-vsix\\media\\dao-rules.md', 'utf8').trim();
const NAME = '道法约束·帛书规则';
function req(method, p, bodyObj) {
  return new Promise((resolve) => {
    const u = new URL('https://app.devin.ai' + p);
    const data = bodyObj ? JSON.stringify(bodyObj) : null;
    const headers = { Accept: 'application/json', 'User-Agent': UA, Authorization: 'Bearer ' + auth1, 'x-cog-org-id': org };
    if (data) { headers['Content-Type'] = 'application/json'; headers['Content-Length'] = Buffer.byteLength(data); }
    const r = https.request({ hostname: u.hostname, port: 443, path: u.pathname + u.search, method, headers, timeout: 20000, rejectUnauthorized: false }, (res) => {
      let d = ''; res.on('data', c => d += c); res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    r.on('error', e => resolve({ status: 0, body: e.message }));
    r.on('timeout', () => { r.destroy(); resolve({ status: 0, body: 'TIMEOUT' }); });
    if (data) r.write(data); r.end();
  });
}
function listKnowledge() { return req('GET', '/api/org-' + bare + '/learning/all').then(r => { try { const j = JSON.parse(r.body); return Array.isArray(j.learnings) ? j.learnings : (Array.isArray(j) ? j : []); } catch { return []; } }); }
(async () => {
  console.log('RULES len=', RULES.length, 'startsOK=', RULES.startsWith('你本無名'));
  let arr = await listKnowledge();
  const before = arr.filter(k => k.name === NAME);
  console.log('BEFORE: total=', arr.length, 'existing 帛书规则=', before.length);
  for (const k of before) { const d = await req('DELETE', '/api/org-' + bare + '/learning/' + k.id); console.log('  delete', k.id, '->', d.status); }
  const ins = await req('POST', '/api/org-' + bare + '/learning', { name: NAME, body: RULES, trigger_description: 'Always — 你本无名 名可名也', pinned_repo: null, parent_folder_id: null, is_enabled: true });
  console.log('INJECT status=', ins.status, 'body[0:120]=', ins.body.slice(0, 120));
  arr = await listKnowledge();
  const after = arr.filter(k => k.name === NAME);
  console.log('AFTER: total=', arr.length, '帛书规则 present=', after.length);
  if (after.length === 1) {
    const k = after[0];
    console.log('  RESULT PASS  id=', k.id, 'enabled=', k.is_enabled, 'bodyLen=', (k.body || '').length);
  } else {
    console.log('  RESULT FAIL  expected exactly 1, got', after.length);
  }
})();
