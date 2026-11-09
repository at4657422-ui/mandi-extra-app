const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const ctx = await b.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:2 }); const p = await ctx.newPage(); const errs=[], calls=[];
  p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type()==='error') errs.push(m.text()); });
  await ctx.route('https://ohfrmdpggsiytaxxfmmp.supabase.co/**', async r => { const u=r.request().url(); calls.push(u.split('.co')[1].slice(0,70)); await r.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body: u.includes('record_login')?'{"new_device":true,"flag":null}':'[]'}); });
  await p.goto('http://localhost:8766/'); await p.waitForSelector('.perm');
  console.log('F1 first screen is consent; switches on:', await p.$$eval('.swi',x=>x.filter(i=>i.checked).length), 'google btn on screen1:', await p.$$eval('.btn.google',x=>x.length));
  await p.screenshot({path:'/tmp/f1.png'});
  await p.click('.perm >> nth=2'); await p.click('text=सहमत हूँ, आगे बढ़ें'); await p.waitForSelector('.btn.google');
  console.log('F2 login page: first button =', (await p.$$eval('.wrap .btn',x=>x[0].textContent)).trim(), '| consent stored:', await p.evaluate(()=>JSON.parse(localStorage.getItem('mx.pc')).marketing));
  await p.screenshot({path:'/tmp/f2.png'});
  await p.reload(); await p.waitForSelector('.btn.google'); console.log('F3 reload skips consent screen: ok');
  await p.evaluate(()=>localStorage.setItem('mx.session',JSON.stringify({access_token:'a',refresh_token:'r',expires_at:Date.now()+3600000,email:'r@e.com'}))); await p.reload(); await p.waitForSelector('.hcard'); await p.waitForTimeout(800);
  console.log('F4 home cards:', await p.$$eval('.hcard',x=>x.length), '| new-device alert:', await p.$$eval('.alert',x=>x.length), '| calls:', calls.filter(c=>c.includes('rpc')));
  await p.screenshot({path:'/tmp/f4.png'}); await p.evaluate(()=>window.scrollTo(0,900)); await p.waitForTimeout(700); await p.screenshot({path:'/tmp/f5.png'});
  await p.evaluate(()=>window.scrollTo(0,0)); await p.click('.hcard >> nth=3'); await p.waitForSelector('.chero'); await p.waitForTimeout(600); await p.screenshot({path:'/tmp/f6.png'});
  console.log('errors:', errs.filter(e=>!/ERR_|Failed to load|play\(\)/.test(e))); await b.close();
})();
