const http=require('http'),fs=require('fs'),path=require('path');
const root='/home/claude/mandi-extra-app/web';
const hdr=fs.readFileSync(root+'/_headers','utf8').split('\n').filter(l=>/^\s+[A-Za-z-]+:/.test(l)&&!l.includes('/sw.js')).map(l=>l.trim().split(/:\s(.+)/).slice(0,2));
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.jpg':'image/jpeg','.png':'image/png','.mp3':'audio/mpeg','.webmanifest':'application/manifest+json'};
http.createServer((q,s)=>{let p=q.url.split('?')[0];if(p==='/')p='/index.html';const f=path.join(root,p);
 if(!f.startsWith(root)||!fs.existsSync(f)){s.writeHead(404);return s.end();}
 const h={'Content-Type':types[path.extname(f)]||'application/octet-stream'};hdr.forEach(([k,v])=>{if(k&&v)h[k]=v});s.writeHead(200,h);fs.createReadStream(f).pipe(s);}).listen(8766);
