// सिर्फ़ ऐप का ढाँचा कैश होता है। लॉगिन, पेमेंट, API का कोई जवाब कभी कैश नहीं होता।
const V = 'mx-shell-v2', SHELL = ['/', '/app.css', '/theme.css', '/art/ui.svg', '/fonts/hind-400.woff', '/fonts/hind-700.woff', '/fonts/baloo2.woff', '/config.js', '/sb.js', '/home.js', '/app.js', '/manifest.webmanifest'];
self.addEventListener('install', e => e.waitUntil(caches.open(V).then(c => c.addAll(SHELL))));
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k))))));
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
