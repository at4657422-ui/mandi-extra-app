(function () {
  'use strict';
  var root = document.getElementById('app'), C = window.MX_CONFIG, A = window.MXA;
  var EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

  function h(tag, cls, kids) {
    var e = document.createElement(tag); if (cls) e.className = cls;
    (kids || []).forEach(function (k) { e.appendChild(typeof k === 'string' ? document.createTextNode(k) : k); });
    return e;
  }
  function btn(label, cls, fn) { var b = h('button', 'btn ' + (cls || ''), [label]); b.type = 'button'; if (fn) b.addEventListener('click', fn); return b; }
  function show(nodes) { closeSheet(); root.replaceChildren.apply(root, nodes); window.scrollTo(0, 0); }
  function brand() { var i = h('img', 'logo'); i.src = '/icons/logo.jpg'; i.alt = 'मंडी एक्स्ट्रा'; return i; }
  function msgBox() { var m = h('p', 'msg'); m.setAttribute('role', 'alert'); return m; }
  function field(type, ph, extra) { var i = h('input', 'field'); i.type = type; i.placeholder = ph; i.maxLength = 120; Object.assign(i, extra || {}); return i; }

  // ---- नीचे से उठने वाला पॉपअप ----
  var sheetEl = null;
  function closeSheet() { stopAudio(); if (sheetEl) { sheetEl.remove(); sheetEl = null; document.body.classList.remove('lock'); } }
  function openSheet(title, kids) {
    closeSheet();
    var back = h('div', 'scrim'), card = h('div', 'sheet', [h('h2', '', [title])].concat(kids));
    card.setAttribute('role', 'dialog'); card.setAttribute('aria-modal', 'true'); card.setAttribute('aria-label', title);
    back.appendChild(card); back.addEventListener('click', function (e) { if (e.target === back) closeSheet(); });
    document.body.appendChild(back); document.body.classList.add('lock'); sheetEl = back;
    return card;
  }

  // ---- "सुनिए": कम पढ़े-लिखे लोगों के लिए आवाज़ में समझाइश ----
  var player = null;
  function stopAudio() { if (player) { player.pause(); player = null; } }
  function listenBtn(file) {
    var b = btn('🔊 सुनिए', 'ghost', function () {
      if (player) { stopAudio(); b.textContent = '🔊 सुनिए'; return; }
      player = new Audio('/media/voice/' + file); b.textContent = '⏹ रोकिए';
      player.addEventListener('ended', function () { player = null; b.textContent = '🔊 सुनिए'; });
      player.play().catch(function () { player = null; b.textContent = '🔊 सुनिए'; });
    });
    return b;
  }

  // ---- सहमति: एक साफ़ क्रिया "सहमत हूँ, आगे बढ़ें" (पहले से कोई टिक नहीं; समय-मुहर के साथ दर्ज) ----
  function askConsent(next) {
    var mkt = h('input'); mkt.type = 'checkbox'; mkt.id = 'c-mkt'; mkt.checked = false;
    var mk = h('label', 'cb', [mkt, h('span', '', ['मुझे ऑफ़र और ख़बरें भेजी जाएँ (वैकल्पिक)'])]); mk.htmlFor = 'c-mkt';
    openSheet('आगे बढ़ने से पहले', [
      h('p', 'lead', ['मैं पुष्टि करता/करती हूँ कि मेरी उम्र 18 साल या उससे ज़्यादा है, और मैंने प्राइवेसी नोटिस पढ़कर उससे सहमति दी है।']),
      h('p', 'fine', ['हम सिर्फ़ ज़रूरी जानकारी लेते हैं, जो भारत में सुरक्षित रहती है। सहमति आप कभी भी सेटिंग से वापस ले सकते हैं, और माँगने पर आपका डेटा मिटा दिया जाएगा।']),
      mk, listenBtn('v02_sahmati.mp3'),
      btn('सहमत हूँ, आगे बढ़ें', '', function () {
        var c = { privacy: true, age: true, marketing: mkt.checked };
        try { sessionStorage.setItem('mx.pc', JSON.stringify(c)); } catch (e) {}
        closeSheet(); next(c);
      }),
      btn('रद्द करें', 'ghost', closeSheet)
    ]);
  }
  async function recordConsent(c) {
    if (!c || !c.privacy || !c.age) return;
    await A.rpc('record_consent', { p_purpose: 'privacy_notice', p_granted: true, p_version: C.NOTICE_VERSION });
    await A.rpc('record_consent', { p_purpose: 'age_18plus', p_granted: true, p_version: C.NOTICE_VERSION });
    if (c.marketing) await A.rpc('record_consent', { p_purpose: 'marketing', p_granted: true, p_version: C.NOTICE_VERSION });
  }
  function savedConsent() { try { var c = JSON.parse(sessionStorage.getItem('mx.pc')); sessionStorage.removeItem('mx.pc'); return c; } catch (e) { return null; } }

  // ---- मुख्य साइन-इन पन्ना ----
  function signIn() {
    var msg = msgBox();
    show([h('main', 'wrap', [
      brand(), h('h1', '', ['नमस्ते! अपना बाज़ार शुरू कीजिए']),
      h('p', '', ['नीचे से एक तरीक़ा चुनिए।']),
      btn('ईमेल से जारी रखें', '', function () { askConsent(emailSheet); }),
      btn('Google से जारी रखें', 'google', function () { askConsent(async function () { msg.textContent = 'Google खुल रहा है…'; try { await A.googleStart(); } catch (e) { msg.textContent = e.message; } }); }),
      btn('ईमेल और पासवर्ड से', 'link', function () { askConsent(function () { passwordSheet(false); }); }),
      msg,
      h('p', 'fine', ['आगे बढ़ने पर आपसे सहमति ली जाएगी। पहले से कोई सहमति नहीं मानी जाती।'])
    ])]);
  }

  // ---- ईमेल से: पता डालो -> मेल ऐप खोलो ----
  function emailSheet(consent) {
    var email = field('email', 'आपका ईमेल', { autocomplete: 'email', inputMode: 'email' });
    var go = btn('लिंक/कोड भेजें', '', null); go.disabled = true; var msg = msgBox();
    email.addEventListener('input', function () { go.disabled = !EMAIL_RE.test(email.value.trim()); });
    go.addEventListener('click', async function () {
      var e = email.value.trim().toLowerCase(); go.disabled = true; msg.textContent = 'भेज रहे हैं…';
      try { await A.sendCode(e); sentSheet(e); } catch (er) { msg.textContent = er.message; go.disabled = false; }
    });
    openSheet('अपना ईमेल डालिए', [email, go, msg]);
  }
  function mailLink(label, url) { var a = h('a', 'btn ghost', [label]); a.href = url; a.target = '_blank'; a.rel = 'noopener noreferrer'; return a; }
  function sentSheet(e) {
    var code = field('text', 'ईमेल में कोड हो तो यहाँ डालिए', { inputMode: 'numeric', autocomplete: 'one-time-code', maxLength: 8 }); code.classList.add('code');
    var ok = btn('कोड से साइन-इन', '', null); ok.disabled = true; var msg = msgBox();
    code.addEventListener('input', function () { code.value = code.value.replace(/\D/g, ''); ok.disabled = code.value.length < 6; });
    ok.addEventListener('click', async function () {
      ok.disabled = true; msg.textContent = 'जाँच रहे हैं…';
      try { await A.verifyCode(e, code.value); await recordConsent(savedConsent()); home(); } catch (er) { msg.textContent = er.message; ok.disabled = false; }
    });
    openSheet('अपना ईमेल खोलिए', [
      h('p', 'lead', [e + ' पर हमने ईमेल भेजा है।']),
      h('div', 'trust', [
        h('p', '', ['✅ यह ईमेल हमारा ही है और इसका लिंक दबाना सुरक्षित है।']),
        h('p', '', ['भेजने वाले का नाम "Supabase Auth" दिख सकता है, यह हमारा ईमेल भेजने वाला साथी है। विषय: "Confirm your email address" या "Magic Link"।']),
        h('p', '', ['मंडी एक्स्ट्रा कभी आपसे पासवर्ड, ओटीपी या पैसे नहीं माँगता।'])
      ]),
      mailLink('Gmail खोलें', 'https://mail.google.com/mail/u/0/#search/mail.app.supabase.io'),
      mailLink('Outlook खोलें', 'https://outlook.live.com/mail/'),
      mailLink('Yahoo मेल खोलें', 'https://mail.yahoo.com/'),
      h('p', 'fine', ['ईमेल न दिखे तो स्पैम या प्रमोशन फ़ोल्डर देखिए। अगर उसमें सिर्फ़ कोड आए तो कोड यहाँ डालिए:']), code, ok, msg
    ]);
  }

  // ---- ईमेल + पासवर्ड ----
  function strongEnough(pw, em) {
    if (pw.length < 10) return 'पासवर्ड कम से कम 10 अक्षर का रखिए।';
    if (/^\d+$/.test(pw)) return 'पासवर्ड में सिर्फ़ अंक नहीं हो सकते।';
    if (em && pw.toLowerCase().indexOf(em.split('@')[0].toLowerCase()) >= 0 && em.split('@')[0].length > 3) return 'पासवर्ड में अपना ईमेल का नाम मत रखिए।';
    if (/^(.)\1+$/.test(pw) || /password|12345|qwerty/i.test(pw)) return 'यह पासवर्ड बहुत आसान है। कुछ और रखिए।';
    return '';
  }
  function passwordSheet(isNew) {
    var email = field('email', 'आपका ईमेल', { autocomplete: 'email', inputMode: 'email' });
    var pw = field('password', isNew ? 'नया पासवर्ड (कम से कम 10 अक्षर)' : 'पासवर्ड', { autocomplete: isNew ? 'new-password' : 'current-password', maxLength: 72 });
    var go = btn(isNew ? 'खाता बनाइए' : 'साइन-इन', '', null); var msg = msgBox();
    var sw = btn(isNew ? 'पहले से खाता है? साइन-इन' : 'नया खाता बनाइए', 'link', function () { passwordSheet(!isNew); });
    go.addEventListener('click', async function () {
      var e = email.value.trim().toLowerCase();
      if (!EMAIL_RE.test(e)) { msg.textContent = 'सही ईमेल डालिए।'; return; }
      if (isNew) { var w = strongEnough(pw.value, e); if (w) { msg.textContent = w; return; } }
      go.disabled = true; msg.textContent = 'जाँच रहे हैं…';
      try {
        var s = isNew ? await A.passwordSignUp(e, pw.value) : await A.passwordSignIn(e, pw.value);
        if (!s) { closeSheet(); sentSheet(e); return; }       // पुष्टि का लिंक भेजा गया
        await recordConsent(savedConsent()); home();
      } catch (er) { msg.textContent = er.message; go.disabled = false; }
    });
    openSheet(isNew ? 'नया खाता' : 'ईमेल और पासवर्ड', [email, pw, go, msg, sw]);
  }

  // ---- साइन-इन के बाद ----
  async function home() {
    var s = await A.session(); if (!s) return signIn();
    var msg = msgBox();
    var out = btn('साइन-आउट', 'ghost', async function () { await A.signOut(); signIn(); });
    var del = btn('मेरा डेटा मिटाने का अनुरोध', 'danger', async function () {
      if (!window.confirm('आपका खाता और डेटा 48 घंटे बाद हमेशा के लिए मिटा दिया जाएगा। आगे बढ़ें?')) return;
      try { var t = await A.rpc('request_deletion'); msg.textContent = 'अनुरोध दर्ज हुआ। मिटाने का समय: ' + new Date(t).toLocaleString('hi-IN') + '। तब तक आप इसे रद्द कर सकते हैं।'; }
      catch (e) { msg.textContent = e.message; }
    });
    show(window.MXHome.render({ email: s.email, signOutBtn: out, deleteBtn: del, msg: msg }));
  }

  async function afterRedirect() {
    var s = A.linkFinish() || await A.googleFinish();     // Google या ईमेल-लिंक से लौटे?
    if (!s) return false;
    await recordConsent(savedConsent());
    return true;
  }

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(function () {});
  afterRedirect().then(function (d) { return d ? home() : A.session().then(function (s) { return s ? home() : signIn(); }); })
    .catch(function (e) { signIn(); var m = document.querySelector('.msg'); if (m) m.textContent = e.message; });
})();
