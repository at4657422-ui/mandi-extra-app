// छोटा, बिना-निर्भरता वाला Supabase क्लाइंट (Auth + RPC)। बाहरी लाइब्रेरी नहीं, ताकि कोड छोटा और जाँचने लायक रहे।
(function () {
  'use strict';
  var C = window.MX_CONFIG, KEY = 'mx.session';
  function save(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) {} }
  function load() { try { return JSON.parse(localStorage.getItem(KEY)); } catch (e) { return null; } }
  function clear() { try { localStorage.removeItem(KEY); } catch (e) {} }
  async function call(path, opts) {
    opts = opts || {};
    var headers = { apikey: C.SUPABASE_KEY, 'Content-Type': 'application/json' };
    if (opts.token) headers.Authorization = 'Bearer ' + opts.token;
    var r;
    try {
      r = await fetch(C.SUPABASE_URL + path, { method: opts.method || 'POST', headers: headers, body: opts.body ? JSON.stringify(opts.body) : undefined });
    } catch (e) { throw new Error('नेटवर्क नहीं मिला। इंटरनेट जाँचकर दोबारा कोशिश कीजिए।'); }
    var j = null; try { j = await r.json(); } catch (e) {}
    if (!r.ok) {
      var m = (j && (j.msg || j.message || j.error_description)) || '';
      if (r.status === 429 || /rate limit/i.test(m)) throw new Error('बहुत जल्दी-जल्दी कोशिश हो गई। थोड़ी देर रुककर फिर कीजिए।');
      if (/expired|invalid/i.test(m)) throw new Error('कोड ग़लत है या पुराना हो गया। नया कोड मँगवाइए।');
      throw new Error('कुछ गड़बड़ हुई। दोबारा कोशिश कीजिए।');
    }
    return j;
  }
  function keep(j) {
    var s = { access_token: j.access_token, refresh_token: j.refresh_token, expires_at: Date.now() + (j.expires_in || 3600) * 1000, email: j.user && j.user.email };
    save(s); return s;
  }
  window.MXA = {
    sendCode: function (email) { return call('/auth/v1/otp', { body: { email: email, create_user: true } }); },
    verifyCode: async function (email, token) { return keep(await call('/auth/v1/verify', { body: { type: 'email', email: email, token: token } })); },
    session: async function () {
      var s = load(); if (!s || !s.refresh_token) return null;
      if (s.expires_at - Date.now() > 60000) return s;
      try { return keep(await call('/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: s.refresh_token } })); }
      catch (e) { clear(); return null; }
    },
    signOut: async function () {
      var s = load(); clear();
      if (s) { try { await call('/auth/v1/logout', { token: s.access_token }); } catch (e) {} }
    },
    rpc: async function (fn, args) {
      var s = await window.MXA.session(); if (!s) throw new Error('पहले साइन-इन कीजिए।');
      return call('/rest/v1/rpc/' + fn, { token: s.access_token, body: args || {} });
    }
  };
})();
