// होम स्क्रीन: चलता बैनर, श्रेणियाँ, नीचे का टैब-बार। कोई नक़ली सामान/सौदा नहीं; ख़ाली अवस्था में सच्चा संदेश।
(function () {
  'use strict';
  var C = window.MX_CONFIG;
  function h(tag, cls, kids) { var e = document.createElement(tag); if (cls) e.className = cls; (kids || []).forEach(function (k) { e.appendChild(typeof k === 'string' ? document.createTextNode(k) : k); }); return e; }
  function txt(tag, cls, t) { var e = h(tag, cls); e.textContent = t; return e; }

  // ऐप की अपनी जानकारी वाले बैनर (विज्ञापन/सैंपल नहीं)। एडमिन के बैनर आने पर वे इनकी जगह दिखेंगे।
  var DEFAULT_BANNERS = [
    { cls: 'b1', icon: '🤝', title: 'सीधा सौदा, कोई बिचौलिया नहीं', sub: 'ख़रीदार और विक्रेता आमने-सामने बात करते हैं' },
    { cls: 'b2', icon: '💸', title: 'कमीशन सिर्फ़ 2%', sub: 'कारीगरों के लिए सिर्फ़ 1%, सौदा हो तभी लगता है' },
    { cls: 'b3', icon: '🏪', title: 'अपनी दुकान, अपना ब्रांड', sub: 'पहले विक्रेता बनिए और अपना बाज़ार सजाइए' }
  ];
  // श्रेणियाँ (PRD के अनुसार)
  var GROUPS = [
    ['घर और निर्माण', [['🧱','ईंट-सीमेंट'],['🪵','लकड़ी-प्लाईवुड'],['🚰','प्लंबिंग'],['💡','बिजली का सामान'],['🎨','पेंट-हार्डवेयर'],['🏗️','स्टील-कंटेनर'],['🪟','टाइल्स-खिड़की']]],
    ['खेती और मंडी', [['🌾','अनाज-मंडी'],['🥬','सब्ज़ी-फल'],['🌱','बीज-खाद'],['🚜','खेती के औज़ार'],['🥛','दूध-डेयरी'],['🍯','मसाले-शहद'],['🐄','पशु'],['🐔','मुर्गी-मछली']]],
    ['रोज़ का सामान', [['🛒','किराना'],['🥫','पैक्ड फ़ूड'],['🧴','घरेलू सामान'],['🧸','खिलौने'],['✏️','स्टेशनरी'],['📚','किताबें'],['🎒','स्कूल का सामान']]],
    ['फ़ैशन और घर सजावट', [['👕','फ़ैशन'],['👗','साड़ी-कपड़ा'],['👟','जूते-चप्पल'],['👜','बैग'],['💍','गहने'],['🛋️','फ़र्नीचर'],['🛏️','बिस्तर-परदे'],['🪔','पूजा-सजावट']]],
    ['इलेक्ट्रॉनिक्स', [['📱','मोबाइल'],['💻','कंप्यूटर'],['📺','टीवी-फ़्रिज'],['🔌','सोलर-बैटरी'],['🎧','ऑडियो-कैमरा'],['🛠️','पुर्ज़े-रिपेयर']]],
    ['गाड़ियाँ और ढुलाई', [['🚗','कार'],['🏍️','बाइक-स्कूटर'],['🚚','ट्रक-किराया'],['🛺','ऑटो-ई-रिक्शा'],['🚜','ट्रैक्टर'],['⚙️','गाड़ी के पुर्ज़े']]],
    ['ज़मीन और प्रॉपर्टी', [['🌱','ज़मीन-खेत'],['🏠','मकान-दुकान'],['🔑','किराए पर कमरा'],['🏢','गोदाम-ऑफ़िस']]],
    ['कारीगर और सेवाएँ', [['🔧','कारीगर-सेवा'],['👷','मज़दूर-मिस्त्री'],['⚡','इलेक्ट्रीशियन'],['🪚','बढ़ई-लोहार'],['🧵','दर्ज़ी-बुनकर'],['🧹','सफ़ाई-देखभाल'],['🎓','ट्यूशन-कोर्स'],['🩺','सेहत-सेवाएँ']]],
    ['खाना और ठहरना', [['🍽️','रेस्टोरेंट'],['🍰','मिठाई-बेकरी'],['🏨','होटल-हॉल'],['🎉','शादी-इवेंट'],['🏕️','घूमना-टूर']]],
    ['क्रिएटर और ब्रांड', [['🎬','क्रिएटर'],['🏷️','ब्रांड शोकेस'],['🏭','कंपनी-थोक']]]
  ];
  var CATS = [], CI = 0;
  GROUPS.forEach(function (g) { g[1].forEach(function (c) { CATS.push([c[0], c[1], 'k' + (CI++ % 16 + 1), g[0]]); }); });

  async function loadBanners(place) {
    try {
      var now = new Date().toISOString();
      var r = await fetch(C.SUPABASE_URL + '/rest/v1/banners?select=image_path,link_url,is_sponsored&placement=eq.' + encodeURIComponent(place || 'home') + '&order=created_at.desc&limit=8', { headers: { apikey: C.SUPABASE_KEY } });
      if (!r.ok) return [];
      var rows = await r.json();
      return Array.isArray(rows) ? rows : [];
    } catch (e) { return []; }
  }
  function safeHref(u) { return typeof u === 'string' && /^(https:\/\/|\/)/.test(u) ? u : null; }

  function carousel(dbBanners, defaults) {
    var slides = [], dots = [];
    var wrap = h('div', 'carousel'); wrap.setAttribute('role', 'region'); wrap.setAttribute('aria-label', 'ख़ास जानकारी');
    var track = h('div', 'track'); wrap.appendChild(track);
    var items = dbBanners.length ? dbBanners.map(function (b) { return { db: b }; }) : (defaults || DEFAULT_BANNERS);
    items.forEach(function (it, i) {
      var s;
      if (it.db) {
        s = h(safeHref(it.db.link_url) ? 'a' : 'div', 'slide img');
        if (s.tagName === 'A') { s.href = safeHref(it.db.link_url); s.rel = 'noopener noreferrer'; }
        var im = h('img'); im.alt = ''; im.loading = i ? 'lazy' : 'eager'; im.src = C.SUPABASE_URL + '/storage/v1/object/public/' + encodeURI(it.db.image_path); s.appendChild(im);
        if (it.db.is_sponsored) s.appendChild(txt('span', 'adtag', 'विज्ञापन'));
      } else {
        s = h('div', 'slide ' + it.cls, [txt('div', 'bicon', it.icon), h('div', 'btext', [txt('b', '', it.title), txt('span', '', it.sub)])]);
      }
      track.appendChild(s); slides.push(s);
    });
    var dotBox = h('div', 'dots');
    slides.forEach(function (_, i) { var d = h('button', 'dot'); d.type = 'button'; d.setAttribute('aria-label', 'बैनर ' + (i + 1)); d.addEventListener('click', function () { go(i, true); }); dotBox.appendChild(d); dots.push(d); });
    wrap.appendChild(dotBox);
    var cur = 0, timer = null;
    function go(i, user) { cur = (i + slides.length) % slides.length; track.style.transform = 'translateX(' + (-100 * cur) + '%)'; dots.forEach(function (d, k) { d.classList.toggle('on', k === cur); }); if (user) restart(); }
    function restart() { clearInterval(timer); if (slides.length > 1 && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) timer = setInterval(function () { if (!document.hidden) go(cur + 1); }, 4500); }
    // उँगली से खिसकाना
    var x0 = null;
    wrap.addEventListener('touchstart', function (e) { x0 = e.touches[0].clientX; clearInterval(timer); }, { passive: true });
    wrap.addEventListener('touchend', function (e) { if (x0 !== null) { var dx = e.changedTouches[0].clientX - x0; if (Math.abs(dx) > 40) go(cur + (dx < 0 ? 1 : -1)); x0 = null; } restart(); }, { passive: true });
    go(0); restart();
    wrap.stop = function () { clearInterval(timer); };
    return wrap;
  }

  function listenCard(file, title, sub) {
    var a = null, b = h('button', 'listen'); b.type = 'button';
    function label(on) { b.textContent = on ? '⏹ रोकिए' : '🔊 सुनिए'; }
    label(false);
    b.addEventListener('click', function () {
      if (a) { a.pause(); a = null; label(false); return; }
      a = new Audio('/media/voice/' + file); label(true);
      a.addEventListener('ended', function () { a = null; label(false); });
      a.play().catch(function () { a = null; label(false); });
    });
    return h('div', 'guide', [h('div', '', [txt('b', '', title), txt('span', '', sub)]), b]);
  }

  function emptyState(icon, title, body, actions) {
    return h('div', 'empty', [txt('div', 'eicon', icon), txt('h2', '', title), txt('p', '', body)].concat(actions || []));
  }

  function render(ctx) {
    var main = h('main', 'app'), tabs = h('nav', 'tabbar'), body = h('div', 'body');
    var banner = null;
    function setTab(name, extra) {
      if (banner && banner.stop) banner.stop(); banner = null;
      body.replaceChildren(); window.scrollTo(0, 0);
      Array.prototype.forEach.call(tabs.children, function (t) { t.classList.toggle('on', t.dataset.tab === name); });
      if (name === 'home') homeTab();
      else if (name === 'cat') catTab(extra);
      else if (name === 'search') body.appendChild(emptyState('🔍', 'खोज जल्द आ रही है', 'जैसे ही पहले विक्रेता सामान डालेंगे, आप यहाँ नाम, श्रेणी और शहर से खोज सकेंगे।'));
      else if (name === 'sell') sellTab();
      else if (name === 'rank') body.appendChild(emptyState('🏆', 'लीडरबोर्ड अभी ख़ाली है', 'यहाँ वही दुकानें, ब्रांड और क्रिएटर आएँगे जिनके सौदे दोनों पक्षों ने पक्के किए हों। पहला सौदा आपका हो सकता है।'));
      else accountTab();
    }
    function homeTab() {
      var search = h('button', 'searchbar', ['🔍 सामान, दुकान या सेवा खोजिए']); search.type = 'button'; search.addEventListener('click', function () { setTab('search'); });
      body.appendChild(h('header', 'top', [txt('div', 'hi', 'नमस्ते 👋'), txt('h1', '', 'आज क्या चाहिए?'), search]));
      var slot = h('div', 'bslot'); body.appendChild(slot);
      loadBanners().then(function (rows) { if (!slot.isConnected) return; banner = carousel(rows); slot.appendChild(banner); });
      body.appendChild(txt('h2', 'sec', 'सारी श्रेणियाँ (' + CATS.length + ')'));
      GROUPS.forEach(function (g) {
        body.appendChild(txt('h3', 'gt', g[0]));
        var grid = h('div', 'grid');
        CATS.filter(function (c) { return c[3] === g[0]; }).forEach(function (c, i) {
          var t = h('button', 'tile ' + c[2]); t.type = 'button'; t.style.setProperty('--d', (i % 4) * 0.35 + 's');
          t.appendChild(txt('span', 'emo', c[0])); t.appendChild(txt('span', 'lbl', c[1]));
          t.addEventListener('click', function () { setTab('cat', c); });
          grid.appendChild(t);
        });
        body.appendChild(grid);
      });
      body.appendChild(listenCard('v17_sab_kuchh_yahan.mp3', 'मंडी एक्स्ट्रा पर क्या-क्या हो सकता है', 'आवाज़ में सुनिए (1 मिनट)'));
    }
    function catTab(c) {
      var back = h('button', 'back', ['← वापस']); back.type = 'button'; back.addEventListener('click', function () { setTab('home'); });
      body.appendChild(back);
      body.appendChild(h('div', 'cathead ' + c[2], [txt('span', 'emo big', c[0]), h('div', '', [txt('h1', '', c[1]), txt('div', 'fine', c[3])])]));
      var cslot = h('div', 'bslot'); body.appendChild(cslot);
      loadBanners('category:' + c[1]).then(function (rows) { if (!cslot.isConnected) return; banner = carousel(rows, [{ cls: 'b' + (CATS.indexOf(c) % 3 + 1), icon: c[0], title: c[1] + ' में पहले बेचिए', sub: 'आपका सामान इस श्रेणी में सबसे पहले दिखेगा' }]); cslot.appendChild(banner); });
      var sell = h('button', 'btn', ['इस श्रेणी में बेचिए']); sell.type = 'button'; sell.addEventListener('click', function () { setTab('sell'); });
      body.appendChild(emptyState('🌟', 'यहाँ अभी कोई सामान नहीं है', 'आप पहले विक्रेता बन सकते हैं। आपका सामान सबसे पहले दिखेगा।', [sell]));
      if (c[1] === 'निर्माण' || c[1] === 'अनाज-मंडी') body.appendChild(listenCard('v04_shreniyan.mp3', 'श्रेणियों के बारे में सुनिए', 'क्या-क्या बेच सकते हैं'));
    }
    function sellTab() {
      body.appendChild(txt('h1', 'pad', 'बेचना शुरू कीजिए'));
      body.appendChild(emptyState('🏷️', 'विक्रेता बनना जल्द खुल रहा है', 'सामान, दुकान, रेस्टोरेंट, गाड़ी, पशु, ज़मीन और सेवाएँ, सब डालने का पन्ना अगले चरण में जुड़ रहा है। तब तक अपना खाता तैयार रखिए।'));
    }
    function accountTab() {
      body.appendChild(txt('h1', 'pad', 'मेरा खाता'));
      body.appendChild(h('div', 'card', [txt('p', '', (ctx.email || '') + ' से साइन-इन है।')]));
      body.appendChild(ctx.signOutBtn); body.appendChild(ctx.deleteBtn); body.appendChild(ctx.msg);
    }
    [['home', '🏠', 'होम'], ['search', '🔍', 'खोजें'], ['sell', '+', 'बेचें'], ['rank', '🏆', 'रैंक'], ['me', '👤', 'मेरा']].forEach(function (t) {
      var b = h('button', 'tab' + (t[0] === 'sell' ? ' plus' : '')); b.type = 'button'; b.dataset.tab = t[0];
      b.appendChild(txt('span', 'ti', t[1])); b.appendChild(txt('span', 'tl', t[2]));
      b.addEventListener('click', function () { setTab(t[0] === 'me' ? 'me' : t[0]); });
      tabs.appendChild(b);
    });
    main.appendChild(body); main.appendChild(tabs); setTab('home');
    return [main];
  }
  window.MXHome = { render: render };
})();
