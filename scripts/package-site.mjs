// Copy only the public website, never local notes, legacy demos or test docs.
// No files are deleted. Unexpected files in an existing output cause a failure.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const input=path.join(project,'docs');
const output=path.join(project,'build/site');
const htmlPages=['index.html','ko/index.html','security.html','ko/security.html','privacy.html','404.html'];
const files=new Set([...htmlPages,'site.css','site.js','robots.txt','sitemap.xml','_headers','site-assets/social.png']);
for(const page of htmlPages){
 const html=await fs.readFile(path.join(input,page),'utf8');
 for(const m of html.matchAll(/\b(?:src|href)="([^"]+)"/g)){
  if(/^(https?:|mailto:|#)/.test(m[1]))continue;
  const relative=path.relative(input,path.resolve(input,path.dirname(page),m[1]));
  if(relative.startsWith('site-assets/'))files.add(relative);
 }
}
async function walk(dir,prefix=''){
 let entries;try{entries=await fs.readdir(dir,{withFileTypes:true});}catch(e){if(e.code==='ENOENT')return[];throw e;}
 const found=[];for(const e of entries){const p=path.join(prefix,e.name);if(e.isDirectory())found.push(...await walk(path.join(dir,e.name),p));else found.push(p);}return found;
}
const unexpected=(await walk(output)).filter(f=>!files.has(f));
if(unexpected.length)throw new Error('Unexpected existing output files; not deleted: '+unexpected.join(', '));
let bytes=0;for(const file of [...files].sort()){
 const source=path.join(input,file),target=path.join(output,file);await fs.mkdir(path.dirname(target),{recursive:true});await fs.copyFile(source,target);bytes+=(await fs.stat(target)).size;
}
console.log(`Packaged ${files.size} public files (${bytes} bytes) in build/site. No files deleted.`);
