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
    { cls: 'b3', icon: '🏪', title: 'अपनी दुकान, अपना ब्रांड', sub: 'पहले विक्रेता बनिए और अपना बाज़ार सजाइए' },
    { cls: 'b1', icon: '🎬', title: 'क्रिएटर क्लब', sub: 'असली बिक्री पर कमाई, हर महीने पूरी रिपोर्ट के साथ' },
    { cls: 'b2', icon: '🛡️', title: 'सुरक्षित सौदा', sub: 'पैसा सीधे आपके बीच, हर साइन-इन की जाँच' }
  ];
  // श्रेणियाँ (PRD के अनुसार)
  var GROUPS = [
    ['घर और निर्माण', '🏗️', [['🧱','ईंट-सीमेंट'],['🪨','रेत-गिट्टी'],['🪵','लकड़ी-प्लाईवुड'],['🚰','प्लंबिंग'],['💡','बिजली का सामान'],['🎨','पेंट-हार्डवेयर'],['🏗️','स्टील-सरिया'],['📦','कंटेनर-केबिन'],['🪟','टाइल्स-खिड़की'],['🚪','दरवाज़े-ग्रिल'],['🧰','औज़ार-मशीन'],['🏺','सैनिटरी-बाथ']]],
    ['खेती और मंडी', '🌾', [['🌾','अनाज-मंडी'],['🫘','दालें'],['🥬','सब्ज़ी'],['🍎','फल'],['🌱','बीज'],['🧪','खाद-दवा'],['🚜','खेती के औज़ार'],['💧','सिंचाई-पंप'],['🥛','दूध-डेयरी'],['🍯','शहद-मसाले'],['🌿','जड़ी-बूटी'],['🥜','सूखे मेवे'],['🌻','तेल-तिलहन'],['🐝','मधुमक्खी-पालन']]],
    ['पशु और पक्षी', '🐄', [['🐄','गाय-बैल'],['🐃','भैंस'],['🐐','बकरी-भेड़'],['🐔','मुर्गी'],['🐟','मछली'],['🐴','घोड़ा-ऊँट'],['🐕','पालतू कुत्ते-बिल्ली'],['🌾','चारा-दाना'],['💉','पशु-दवा'],['🏠','पशु-शेड सामान']]],
    ['रोज़ का सामान', '🛒', [['🛒','किराना'],['🥫','पैक्ड फ़ूड'],['🍪','बिस्कुट-नमकीन'],['🥤','पेय-चाय-कॉफ़ी'],['🧴','घरेलू सामान'],['🧼','साबुन-सफ़ाई'],['🍳','बर्तन-किचन'],['🧸','खिलौने'],['✏️','स्टेशनरी'],['📚','किताबें'],['🎒','स्कूल का सामान'],['🎁','गिफ़्ट-आइटम']]],
    ['कपड़े और फ़ैशन', '👗', [['👕','पुरुष कपड़े'],['👗','महिला कपड़े'],['🧒','बच्चों के कपड़े'],['🥻','साड़ी-सूट'],['🧣','ऊनी-शॉल'],['👟','जूते'],['🩴','चप्पल'],['👜','बैग-पर्स'],['🕶️','चश्मे-घड़ी'],['💍','गहने'],['🧵','कपड़ा-थान'],['🪡','सिलाई का सामान'],['👰','शादी के कपड़े'],['🧢','टोपी-पगड़ी']]],
    ['घर सजावट', '🛋️', [['🛋️','सोफ़ा-कुर्सी'],['🛏️','पलंग-गद्दे'],['🗄️','अलमारी-टेबल'],['🪞','आइना-फ़्रेम'],['🪟','परदे-कालीन'],['💡','झूमर-लाइट'],['🪔','पूजा-सामान'],['🖼️','कला-पेंटिंग'],['🪴','गमले-पौधे'],['🧺','टोकरी-हस्तशिल्प'],['🏺','मिट्टी के बर्तन'],['🕰️','घड़ी-सजावट']]],
    ['मोबाइल और इलेक्ट्रॉनिक्स', '📱', [['📱','मोबाइल'],['🔋','चार्जर-बैटरी'],['💻','लैपटॉप-कंप्यूटर'],['🖨️','प्रिंटर-ऑफ़िस'],['📺','टीवी'],['🧊','फ़्रिज-वॉशिंग'],['❄️','कूलर-AC-पंखे'],['🔌','सोलर-इन्वर्टर'],['🎧','ऑडियो-स्पीकर'],['📷','कैमरा-CCTV'],['🎮','गेमिंग'],['🛠️','पुर्ज़े-रिपेयर'],['⌚','स्मार्टवॉच']]],
    ['गाड़ियाँ और ढुलाई', '🚗', [['🚗','कार'],['🏍️','बाइक'],['🛵','स्कूटर'],['🛺','ऑटो-ई-रिक्शा'],['🚚','ट्रक-किराया'],['🚛','टेम्पो-पिकअप'],['🚜','ट्रैक्टर'],['🚌','बस-वैन'],['🚲','साइकिल'],['⚙️','गाड़ी के पुर्ज़े'],['🛞','टायर-बैटरी'],['🔧','गाड़ी रिपेयर'],['🚕','टैक्सी-किराया']]],
    ['ज़मीन और प्रॉपर्टी', '🏠', [['🌱','खेती की ज़मीन'],['📐','प्लॉट'],['🏠','मकान'],['🏪','दुकान'],['🔑','किराए पर कमरा'],['🏢','ऑफ़िस-गोदाम'],['🏭','फ़ैक्ट्री-शेड'],['🛖','फ़ार्महाउस'],['🛏️','PG-हॉस्टल']]],
    ['कारीगर और मज़दूर', '👷', [['👷','मज़दूर-मिस्त्री'],['⚡','इलेक्ट्रीशियन'],['🚿','प्लंबर'],['🪚','बढ़ई'],['⚒️','लोहार-वेल्डर'],['🎨','पेंटर'],['🧵','दर्ज़ी'],['👨‍🍳','कुक-हलवाई'],['🚗','ड्राइवर'],['🧹','सफ़ाई-देखभाल'],['👵','घरेलू सहायक'],['🔧','मैकेनिक'],['🌳','माली-बाग़वानी'],['💇','सैलून-ब्यूटी'],['🪡','कढ़ाई-हस्तकला'],['🏺','कुम्हार']]],
    ['सेवाएँ', '🛎️', [['🎓','ट्यूशन'],['💻','कंप्यूटर कोर्स'],['🩺','सेहत-सेवाएँ'],['💊','दवा-मेडिकल'],['🧘','योग-फ़िटनेस'],['📸','फ़ोटो-वीडियो'],['🖨️','प्रिंटिंग-फ़्लेक्स'],['📑','दस्तावेज़-काग़ज़ी काम'],['🚚','पैकर-मूवर्स'],['🔒','सुरक्षा-गार्ड'],['🐛','पेस्ट कंट्रोल'],['📡','इंटरनेट-DTH']]],
    ['खाना-पीना', '🍽️', [['🍽️','रेस्टोरेंट'],['🍛','ढाबा'],['🍰','मिठाई-बेकरी'],['🍕','फ़ास्ट फ़ूड'],['☕','चाय-कैफ़े'],['🍱','टिफ़िन-सेवा'],['🥘','कैटरिंग'],['🍦','आइसक्रीम-जूस'],['🥟','घर का खाना']]],
    ['ठहरना और शादी-इवेंट', '🏨', [['🏨','होटल'],['🛖','गेस्ट हाउस'],['🏛️','मैरिज हॉल'],['🎉','इवेंट-टेंट'],['🎶','DJ-बैंड'],['💐','फूल-सजावट'],['🪭','दूल्हा-दुल्हन सेवा'],['🏕️','घूमना-टूर'],['🚌','यात्रा-बुकिंग']]],
    ['किराये पर', '🔑', [['🏗️','JCB-मशीन'],['🚜','ट्रैक्टर-किराया'],['🪜','सीढ़ी-पाड़'],['🔊','साउंड-माइक'],['🎪','टेंट-कुर्सी'],['🍳','बर्तन-किराया'],['🏍️','बाइक-किराया'],['👗','कपड़े-किराया'],['🛠️','औज़ार-किराया']]],
    ['क्रिएटर और ब्रांड', '🎬', [['🎬','क्रिएटर'],['🏷️','ब्रांड शोकेस'],['🏭','कंपनी-थोक'],['📦','थोक बाज़ार'],['🤝','डीलर-वितरक'],['📣','विज्ञापन-प्रचार'],['🎙️','आवाज़-संगीत'],['🖌️','डिज़ाइन-लोगो']]]
    ,['मशीनरी और उद्योग', '⚙️', [['⚙️','औद्योगिक मशीन'],['🏭','फ़ैक्ट्री का सामान'],['🔩','नट-बोल्ट-बेयरिंग'],['🛢️','तेल-ग्रीस'],['🧪','केमिकल'],['🧯','सुरक्षा उपकरण'],['🪛','वेल्डिंग-कटिंग'],['🔋','जनरेटर-मोटर'],['📏','नापतोल-तराज़ू'],['🧲','पाइप-फ़िटिंग']]],
    ['पैकिंग और काग़ज़', '📦', [['📦','डिब्बे-कार्टन'],['🛍️','प्लास्टिक-थैले'],['🧾','काग़ज़-रोल'],['🖨️','छपाई-पैंफ़लेट'],['🏷️','लेबल-स्टिकर'],['🧃','बोतल-जार'],['🪢','रस्सी-टेप'],['🗞️','रद्दी-कबाड़']]],
    ['सेहत और ब्यूटी', '💄', [['💄','मेकअप'],['🧴','स्किन-हेयर केयर'],['🪒','पुरुष ग्रूमिंग'],['🩹','प्राथमिक उपचार'],['🦷','ओरल केयर'],['🌿','आयुर्वेद-घरेलू'],['🏋️','जिम-फ़िटनेस'],['♿','सहायक उपकरण']]],
    ['खेल, संगीत और शौक', '🎵', [['🏏','क्रिकेट-खेल'],['⚽','फ़ुटबॉल-बैडमिंटन'],['🎸','वाद्य यंत्र'],['🎨','कला-क्राफ़्ट'],['🎣','मछली पकड़ना'],['🏕️','ट्रेकिंग-कैंपिंग'],['🧩','बोर्ड गेम'],['📿','माला-पूजा-धर्म']]],
    ['पुराना और बचत बाज़ार', '♻️', [['♻️','पुराना सामान'],['📱','पुराने मोबाइल'],['🛋️','पुराना फ़र्नीचर'],['🚲','पुरानी साइकिल-बाइक'],['📚','पुरानी किताबें'],['🔧','पुरानी मशीनें'],['🎁','ज़रूरतमंद को दान']]],
    ['बच्चे और परिवार', '🧸', [['🍼','बेबी केयर'],['🛒','बेबी प्रोडक्ट्स'],['🎒','स्कूल यूनिफ़ॉर्म'],['🧸','खिलौने-गेम'],['🛏️','झूला-पालना'],['📖','बच्चों की किताबें'],['🎂','जन्मदिन सामान']]]
  ];
  var CATS = [], CI = 0;
  GROUPS.forEach(function (g, gi) { g[2].forEach(function (c) { CATS.push([c[0], c[1], 'k' + (CI++ % 16 + 1), g[0], gi, g[1]]); }); });

  var io = null;
  function watch(el) {
    if (!('IntersectionObserver' in window)) { el.classList.add('in'); return; }
    if (!io) io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }); }, { rootMargin: '0px 0px -8% 0px', threshold: 0.12 });
    io.observe(el);
  }
  var sy = 0, ticking = false;
  window.addEventListener('scroll', function () { sy = window.scrollY; if (!ticking) { ticking = true; requestAnimationFrame(function () { document.documentElement.style.setProperty('--sy', sy); ticking = false; }); } }, { passive: true });
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
      else if (name === 'soon') soonTab(extra);
      else if (name === 'search') searchTab();
      else if (name === 'sell') sellTab();
      else if (name === 'rank') body.appendChild(emptyState('🏆', 'लीडरबोर्ड अभी ख़ाली है', 'यहाँ वही दुकानें, ब्रांड और क्रिएटर आएँगे जिनके सौदे दोनों पक्षों ने पक्के किए हों। पहला सौदा आपका हो सकता है।'));
      else accountTab();
    }
    function homeTab() {
      if (ctx.note) body.appendChild(h('div', 'alert', [txt('b', '', '⚠️ सुरक्षा सूचना'), txt('span', '', ctx.note)]));
      var search = h('button', 'searchbar', ['🔍 सामान, दुकान या सेवा खोजिए']); search.type = 'button'; search.addEventListener('click', function () { setTab('search'); });
      var logo = h('img', 'hlogo'); logo.src = '/icons/icon-192.png'; logo.alt = 'मंडी एक्स्ट्रा';
      body.appendChild(h('header', 'hdr', [logo, search, (function () { var n = h('button', 'bell', ['🔔']); n.type = 'button'; n.setAttribute('aria-label', 'सूचनाएँ'); n.addEventListener('click', function () { setTab('soon', ['🔔', 'सूचनाएँ']); }); return n; })()]));
      var ql = h('div', 'qlinks');
      [['📡', 'मंडी लाइव'], ['🧮', 'बिज़नेस कैलकुलेटर'], ['🎬', 'क्रिएटर क्लब'], ['📊', 'रिपोर्ट'], ['🛡️', 'सुरक्षा']].forEach(function (q) {
        var b = h('button', 'ql', [txt('span', '', q[0]), txt('b', '', q[1])]); b.type = 'button'; b.addEventListener('click', function () { setTab('soon', q); }); ql.appendChild(b);
      });
      body.appendChild(ql);
      var slot = h('div', 'bslot'); body.appendChild(slot);
      loadBanners().then(function (rows) { if (!slot.isConnected) return; banner = carousel(rows); slot.appendChild(banner); });
      var st = h('div', 'stats');
      [['2%', 'अधिकतम कुल शुल्क'], ['सीधा', 'ख़रीदार से विक्रेता'], ['UTR', 'हर भुगतान का सबूत'], ['18+', 'सिर्फ़ वयस्क']].forEach(function (x) { st.appendChild(h('div', 'st', [txt('b', '', x[0]), txt('span', '', x[1])])); });
      body.appendChild(st);
      body.appendChild(txt('h2', 'sec', 'ख़ास श्रेणियाँ'));
      var feat = h('div', 'hrow big');
      [0, 12, 26, 36, 44, 58, 68, 82, 90, 104].forEach(function (ix) { var c = CATS[ix]; if (c) feat.appendChild(catCard(c, true)); });
      body.appendChild(feat);
      body.appendChild(txt('h2', 'sec', 'सारी श्रेणियाँ (' + CATS.length + ')'));
      GROUPS.forEach(function (g, gi) {
        var sec = h('section', 'gsec rv');
        var head = h('div', 'gh g' + (gi % 8), [txt('span', 'gbi', g[1]), h('div', '', [txt('h3', '', g[0]), txt('div', 'fine', g[2].length + ' श्रेणियाँ')])]);
        var row = h('div', 'hrow');
        CATS.filter(function (c) { return c[4] === gi; }).forEach(function (c) { row.appendChild(catCard(c)); });
        sec.appendChild(head); sec.appendChild(row); body.appendChild(sec); watch(sec);
      });
      body.appendChild(listenCard('v17_sab_kuchh_yahan.mp3', 'मंडी एक्स्ट्रा पर क्या-क्या हो सकता है', 'आवाज़ में सुनिए (1 मिनट)'));
    }
    function catCard(c, big) {
      var t = h('button', 'hcard ' + c[2] + (big ? ' big' : '')); t.type = 'button';
      t.appendChild(txt('span', 'emo', c[0])); t.appendChild(txt('span', 'lbl', c[1]));
      t.addEventListener('click', function () { setTab('cat', c); }); return t;
    }
    function soonTab(q) {
      var back = h('button', 'back', ['← वापस']); back.type = 'button'; back.addEventListener('click', function () { setTab('home'); });
      body.appendChild(back);
      body.appendChild(emptyState(q[0], q[1] + ' जल्द आ रहा है', 'यह हिस्सा अगले चरण में जुड़ रहा है। तब तक सारी श्रेणियाँ देखिए।'));
    }
    function searchTab() {
      var q = h('input', 'field'); q.type = 'search'; q.placeholder = 'श्रेणी खोजिए, जैसे: ट्रैक्टर, साड़ी'; q.maxLength = 40;
      var res = h('div', 'grid'); body.appendChild(h('h2', 'pad', ['खोजिए'])); body.appendChild(q); body.appendChild(res);
      body.appendChild(txt('p', 'fine', 'सामान की खोज तब चालू होगी जब विक्रेता सामान डाल देंगे। अभी श्रेणियाँ खोज सकते हैं।'));
      function draw() {
        var t = q.value.trim(); res.replaceChildren();
        CATS.filter(function (c) { return !t || c[1].indexOf(t) > -1 || c[3].indexOf(t) > -1; }).slice(0, 60).forEach(function (c) {
          var b = h('button', 'tile ' + c[2]); b.type = 'button'; b.appendChild(txt('span', 'emo', c[0])); b.appendChild(txt('span', 'lbl', c[1]));
          b.addEventListener('click', function () { setTab('cat', c); }); res.appendChild(b);
        });
      }
      q.addEventListener('input', draw); draw();
    }
    function catTab(c) {
      var back = h('button', 'back', ['← वापस']); back.type = 'button'; back.addEventListener('click', function () { setTab('home'); });
      body.appendChild(back);
      var parts = []; for (var i = 0; i < 5; i++) { var pe = txt('span', 'pt', c[0]); pe.style.setProperty('--x', (i * 19 + 6) + '%'); pe.style.setProperty('--dl', (i * 1.3) + 's'); pe.style.setProperty('--sz', (14 + (i % 3) * 6) + 'px'); parts.push(pe); }
      var hero = h('div', 'chero g' + (c[4] % 8), parts.concat([h('div', 'ctext', [txt('div', 'fine', c[3]), txt('h1', '', c[1]), h('div', 'pills', [txt('span', '', 'सीधे विक्रेता से'), txt('span', '', 'अधिकतम 2% शुल्क')])]), h('span', 'cbig', [c[0]])]));
      body.appendChild(hero);
      var cslot = h('div', 'bslot'); body.appendChild(cslot);
      loadBanners('category:' + c[1]).then(function (rows) { if (!cslot.isConnected || !rows.length) return; banner = carousel(rows); cslot.appendChild(banner); });
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
