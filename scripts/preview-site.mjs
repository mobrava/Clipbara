// Local-only preview. Also exercises extensionless HTML and global _headers.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const root=path.resolve(project,process.env.SITE_PREVIEW_ROOT||'docs');
const port=Number(process.env.PORT||4388);
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml','.xml':'application/xml','.txt':'text/plain; charset=utf-8'};
async function globalHeaders(){
 const result={};let text;try{text=await fs.readFile(path.join(root,'_headers'),'utf8');}catch{return result;}
 let global=false;for(const line of text.split('\n')){if(!line.trim()||line.startsWith('#'))continue;if(!/^\s/.test(line)){global=line.trim()==='/*';continue;}if(global){const pos=line.indexOf(':');if(pos>0)result[line.slice(0,pos).trim()]=line.slice(pos+1).trim();}}return result;
}
http.createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://localhost');let p=decodeURIComponent(url.pathname);
  if(p.startsWith('/Clipbara/'))p=p.replace('/Clipbara','');
  if(p.endsWith('/'))p+='index.html';
  let file=path.resolve(root,'.'+p);
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  let body,status=200;
  try{body=await fs.readFile(file);}catch(e){
   if(e.code==='ENOENT'&&!path.extname(file)){try{file+='.html';body=await fs.readFile(file);}catch{}}
   if(body===undefined){status=404;file=path.join(root,'404.html');try{body=await fs.readFile(file);}catch{body=Buffer.from('Not found');file='404.txt';}}
  }
  res.writeHead(status,{...await globalHeaders(),'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow','X-Content-Type-Options':'nosniff'});
  res.end(req.method==='HEAD'?undefined:body);
 }catch{res.writeHead(400,{'Content-Type':'text/plain; charset=utf-8'});res.end('Bad request');}
}).listen(port,'127.0.0.1',()=>console.log(`Clipbara preview: http://127.0.0.1:${port}/ (${root})`));
