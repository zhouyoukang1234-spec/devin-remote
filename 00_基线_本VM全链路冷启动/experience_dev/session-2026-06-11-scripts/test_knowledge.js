const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.dao', 'workspaces', 'cd03dea5683d', 'config.json'), 'utf8'));
const auth1 = cfg.devinAuth1, org = cfg.devinOrgId, bare = org.replace(/^org-/, '');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36';
function get(p){return new Promise((resolve)=>{const u=new URL('https://app.devin.ai'+p);const req=https.request({hostname:u.hostname,port:443,path:u.pathname+u.search,method:'GET',headers:{Accept:'application/json','User-Agent':UA,Authorization:'Bearer '+auth1,'x-cog-org-id':org},timeout:15000,rejectUnauthorized:false},(res)=>{let d='';res.on('data',c=>d+=c);res.on('end',()=>resolve({status:res.statusCode,body:d}));});req.on('error',e=>resolve({status:0,body:e.message}));req.on('timeout',()=>{req.destroy();resolve({status:0,body:'TIMEOUT'});});req.end();});}
(async()=>{
  console.log('org=',org,'auth1.len=',(auth1||'').length);
  const k = await get('/api/org-'+bare+'/learning/all');
  console.log('KNOWLEDGE status=',k.status);
  try{const j=JSON.parse(k.body);const arr=Array.isArray(j.learnings)?j.learnings:(Array.isArray(j)?j:[]);console.log('  learnings count=',arr.length);arr.slice(0,5).forEach(x=>console.log('   -',(x.name||x.id||'?'),'| enabled=',x.is_enabled));}catch(e){console.log('  parse err, body[0:200]=',k.body.slice(0,200));}
  const pb = await get('/api/org-'+bare+'/playbooks');
  console.log('PLAYBOOKS status=',pb.status);
  try{const j=JSON.parse(pb.body);const arr=Array.isArray(j.playbooks)?j.playbooks:(Array.isArray(j)?j:[]);console.log('  playbooks count=',arr.length);arr.slice(0,5).forEach(x=>console.log('   -',(x.title||x.id||'?')));}catch(e){console.log('  parse err, body[0:200]=',pb.body.slice(0,200));}
})();
