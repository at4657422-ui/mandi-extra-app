const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const ctx = await b.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:2 }); const p = await ctx.newPage(); const calls=[], errs=[];
  p.on('pageerror', e => errs.push(e.message));
  await ctx.route('https://ohfrmdpggsiytaxxfmmp.supabase.co/**', async r => {
    const u=r.request().url(), body=r.request().postData()||''; calls.push(u.split('.co')[1].slice(0,48)+' '+body.slice(0,60));
    if (u.includes('/authorize')) return r.fulfill({status:302,headers:{location:'http://localhost:8765/?code=zz'}});
    let j={}, st=200;
    if (u.includes('/verify')||u.includes('pkce')||u.includes('grant_type=password')) j={access_token:'a',refresh_token:'r',expires_in:3600,user:{email:'t@x.in'}};
    if (u.includes('/signup')) j={user:{id:'1'}};            // पुष्टि-लिंक वाला मामला: कोई टोकन नहीं
    await r.fulfill({status:st,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(j)});
  });
  const fresh = async () => { await p.evaluate(()=>{localStorage.clear();sessionStorage.clear()}); await p.goto('http://localhost:8765/'); await p.reload(); await p.waitForSelector('text=ईमेल से जारी रखें'); calls.length=0; };
  await p.goto('http://localhost:8765/'); await fresh();
  console.log('T1 no checkboxes on main page:', await p.$$eval('input[type=checkbox]',x=>x.length));
  await p.click('text=ईमेल से जारी रखें'); await p.waitForSelector('.sheet');
  console.log('T2 consent box default unchecked:', !(await p.isChecked('#c-mkt'))); await p.screenshot({path:'/tmp/v2_consent.png'});
  await p.click('text=रद्द करें'); console.log('T3 cancel -> sheet gone, API calls:', calls.length, 'sheets:', await p.$$eval('.sheet',x=>x.length));
  await p.click('text=ईमेल से जारी रखें'); await p.click('text=सहमत हूँ, आगे बढ़ें');
  const go = p.locator('.sheet button.btn').first(); console.log('T4 send disabled until valid email:', await go.isDisabled());
  await p.fill('.sheet input[type=email]','a@b.in'); await go.click(); await p.waitForSelector('text=Gmail खोलें'); await p.screenshot({path:'/tmp/v2_mail.png'});
  console.log('T5 mail links:', await p.$$eval('a.btn',x=>x.map(a=>a.href+'|'+a.rel)));
  await p.fill('.sheet .code','123456'); await p.click('text=कोड से साइन-इन'); await p.waitForSelector('.tile');
  console.log('T6 email flow calls:'); calls.forEach(c=>console.log('   ',c));
  await fresh(); await p.click('text=Google से जारी रखें'); await p.click('text=सहमत हूँ, आगे बढ़ें'); await p.waitForSelector('.tile',{timeout:8000});
  console.log('T7 google flow ok, consent calls:', calls.filter(c=>c.includes('record_consent')).length);
  await fresh(); await p.click('text=ईमेल और पासवर्ड से'); await p.click('text=सहमत हूँ, आगे बढ़ें'); await p.click('text=नया खाता बनाइए');
  await p.fill('.sheet input[type=email]','ramesh@x.in');
  for (const [pw,exp] of [['short1','कम से कम 10'],['1234567890','सिर्फ़ अंक'],['rameshkumar99','ईमेल का नाम'],['Password12345','आसान']]) {
    await p.fill('.sheet input[type=password]',pw); await p.click('.sheet .btn:has-text("खाता बनाइए")'); console.log('T8 weak pw "'+pw+'":', (await p.textContent('.sheet .msg')).slice(0,30)); }
  calls.length=0; await p.fill('.sheet input[type=password]','Kela-Chaand-7391-Naav'); await p.click('.sheet .btn:has-text("खाता बनाइए")'); await p.waitForSelector('text=Gmail खोलें');
  console.log('T9 strong pw signup -> asks to open mail; calls:', calls.map(c=>c.slice(0,22)));
  console.log('errors:', errs); await b.close();
})();
