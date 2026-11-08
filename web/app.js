(function () {
  'use strict';
  var root = document.getElementById('app'), C = window.MX_CONFIG, A = window.MXA;
  var pending = { email: '', consent: null };   // सहमति पहले मेमोरी में, लॉगिन के बाद रिकॉर्ड में

  function h(tag, cls, kids) {
    var e = document.createElement(tag); if (cls) e.className = cls;
    (kids || []).forEach(function (k) { e.appendChild(typeof k === 'string' ? document.createTextNode(k) : k); });
    return e;
  }
  function show(nodes) { root.replaceChildren.apply(root, nodes); window.scrollTo(0, 0); }
  function brand() {
    var img = h('img', 'logo'); img.src = '/icons/logo.jpg'; img.alt = 'मंडी एक्स्ट्रा'; return img;
  }
  function msgBox() { var m = h('p', 'msg'); m.setAttribute('role', 'alert'); return m; }
  function checkbox(id, label, required) {
    var i = h('input'); i.type = 'checkbox'; i.id = id; i.checked = false;      // कभी पहले से टिक नहीं
    var l = h('label', 'cb', [i, h('span', '', [label + (required ? '' : ' (वैकल्पिक)')])]); l.htmlFor = id;
    return { box: l, input: i };
  }

  function signIn() {
    var email = h('input', 'field'); email.type = 'email'; email.placeholder = 'आपका ईमेल'; email.autocomplete = 'email'; email.inputMode = 'email'; email.maxLength = 120;
    var c1 = checkbox('c-privacy', 'मैंने प्राइवेसी नोटिस पढ़ लिया है और मैं सहमत हूँ', true);
    var c2 = checkbox('c-age', 'मेरी उम्र 18 साल या उससे ज़्यादा है', true);
    var c3 = checkbox('c-mkt', 'मुझे ऑफ़र और ख़बरें भेजी जाएँ', false);
    var btn = h('button', 'btn', ['कोड भेजें']); btn.type = 'button'; btn.disabled = true;
    var gbtn = h('button', 'btn google', ['Google से जारी रखें']); gbtn.type = 'button'; gbtn.disabled = true;
    var msg = msgBox();
    function consentOk() { return c1.input.checked && c2.input.checked; }
    function ok() { return consentOk() && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value.trim()); }
    function refresh() { btn.disabled = !ok(); gbtn.disabled = !consentOk(); }
    gbtn.addEventListener('click', async function () {
      if (!consentOk()) return;
      gbtn.disabled = true; msg.textContent = 'Google खुल रहा है…';
      try {
        sessionStorage.setItem('mx.pc', JSON.stringify({ privacy: true, age: true, marketing: c3.input.checked }));
        await A.googleStart();
      } catch (e) { msg.textContent = e.message; gbtn.disabled = false; }
    });
    [c1.input, c2.input, email].forEach(function (x) { x.addEventListener('input', refresh); x.addEventListener('change', refresh); });
    btn.addEventListener('click', async function () {
      if (!ok()) return;
      btn.disabled = true; msg.textContent = 'कोड भेज रहे हैं…';
      try {
        pending.email = email.value.trim().toLowerCase();
        pending.consent = { privacy: true, age: true, marketing: c3.input.checked };
        try { sessionStorage.setItem('mx.pc', JSON.stringify(pending.consent)); } catch (e) {}   // लिंक से लौटने पर सहमति दर्ज होगी
        await A.sendCode(pending.email);
        enterCode();
      } catch (e) { msg.textContent = e.message; btn.disabled = false; }
    });
    show([h('main', 'wrap', [
      brand(), h('h1', '', ['नमस्ते! अपना बाज़ार शुरू कीजिए']),
      h('p', '', ['Google से या ईमेल से साइन-इन कीजिए। पासवर्ड की ज़रूरत नहीं।']),
      h('div', 'card', [c1.box, c2.box, c3.box,
        h('p', 'fine', ['पहले से कोई टिक नहीं लगा है। सहमति आप कभी भी वापस ले सकते हैं, और माँगने पर आपका डेटा मिटा दिया जाएगा।'])]),
      h('div', 'card', [email]),
      btn, h('p', 'or', ['या']), gbtn, msg,
      h('p', 'fine', ['हम सिर्फ़ वही जानकारी लेते हैं जो ज़रूरी है। आपका डेटा भारत में सुरक्षित रहता है।'])
    ])]);
  }

  function enterCode() {
    var code = h('input', 'field code'); code.inputMode = 'numeric'; code.autocomplete = 'one-time-code'; code.maxLength = 8; code.placeholder = '• • • • • •';
    var btn = h('button', 'btn', ['साइन-इन करें']); btn.type = 'button'; btn.disabled = true;
    var back = h('button', 'link', ['ईमेल बदलें']); back.type = 'button';
    var msg = msgBox();
    code.addEventListener('input', function () { code.value = code.value.replace(/\D/g, ''); btn.disabled = code.value.length < 6; });
    back.addEventListener('click', signIn);
    btn.addEventListener('click', async function () {
      btn.disabled = true; msg.textContent = 'जाँच रहे हैं…';
      try {
        await A.verifyCode(pending.email, code.value);
        var c = pending.consent || {};
        await A.rpc('record_consent', { p_purpose: 'privacy_notice', p_granted: !!c.privacy, p_version: C.NOTICE_VERSION });
        await A.rpc('record_consent', { p_purpose: 'age_18plus', p_granted: !!c.age, p_version: C.NOTICE_VERSION });
        if (c.marketing) await A.rpc('record_consent', { p_purpose: 'marketing', p_granted: true, p_version: C.NOTICE_VERSION });
        pending = { email: '', consent: null };
        home();
      } catch (e) { msg.textContent = e.message; btn.disabled = code.value.length < 6; }
    });
    show([h('main', 'wrap', [
      brand(), h('h1', '', ['कोड डालिए']),
      h('p', '', [pending.email + ' पर ईमेल भेजा है। उसमें लिंक हो तो उसे दबा दीजिए। कोड हो तो यहाँ डालिए। स्पैम फ़ोल्डर भी देख लीजिए।']),
      h('div', 'card', [code]), btn, msg, back
    ])]);
  }

  async function home() {
    var s = await A.session(); if (!s) return signIn();
    var out = h('button', 'btn ghost', ['साइन-आउट']); out.type = 'button';
    var del = h('button', 'btn danger', ['मेरा डेटा मिटाने का अनुरोध']); del.type = 'button';
    var msg = msgBox();
    out.addEventListener('click', async function () { await A.signOut(); signIn(); });
    del.addEventListener('click', async function () {
      if (!window.confirm('आपका खाता और डेटा 48 घंटे बाद हमेशा के लिए मिटा दिया जाएगा। आगे बढ़ें?')) return;
      try { var t = await A.rpc('request_deletion'); msg.textContent = 'अनुरोध दर्ज हुआ। मिटाने का समय: ' + new Date(t).toLocaleString('hi-IN') + '। तब तक आप इसे रद्द कर सकते हैं।'; }
      catch (e) { msg.textContent = e.message; }
    });
    show([h('main', 'wrap', [
      brand(), h('h1', '', ['स्वागत है!']),
      h('p', '', [(s.email || '') + ' से साइन-इन हो गया।']),
      h('div', 'card', [h('p', '', ['आपका बाज़ार जल्द खुल रहा है: सामान, सौदे और दुकान अगले चरणों में जुड़ेंगे।'])]),
      out, del, msg
    ])]);
  }

  async function afterGoogle() {
    var s = A.linkFinish() || await A.googleFinish();   // null अगर Google/ईमेल-लिंक से लौटे नहीं हैं
    if (!s) return false;
    var c = null; try { c = JSON.parse(sessionStorage.getItem('mx.pc')); sessionStorage.removeItem('mx.pc'); } catch (e) {}
    if (c && c.privacy && c.age) {
      await A.rpc('record_consent', { p_purpose: 'privacy_notice', p_granted: true, p_version: C.NOTICE_VERSION });
      await A.rpc('record_consent', { p_purpose: 'age_18plus', p_granted: true, p_version: C.NOTICE_VERSION });
      if (c.marketing) await A.rpc('record_consent', { p_purpose: 'marketing', p_granted: true, p_version: C.NOTICE_VERSION });
    }
    return true;
  }

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(function () {});
  afterGoogle().then(function (done) { return done ? home() : A.session().then(function (s) { return s ? home() : signIn(); }); })
    .catch(function (e) { signIn(); var m = document.querySelector('.msg'); if (m) m.textContent = e.message; });
})();
