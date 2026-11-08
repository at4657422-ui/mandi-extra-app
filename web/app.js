// चरण 1 की नींव: सिर्फ़ सर्विस-वर्कर पंजीकरण। लॉगिन/सहमति अगले चरण में।
if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});
