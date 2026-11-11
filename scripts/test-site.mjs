import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const root=path.resolve(project,process.env.SITE_TEST_ROOT||'docs');
const expectedBase=(process.env.SITE_URL||'https://clipbara.app').replace(/\/$/,'');
const pages=['index.html','ko/index.html','security.html','ko/security.html'];
let checks=0;
for(const page of pages){
 const full=path.join(root,page),html=await fs.readFile(full,'utf8');
 assert.equal((html.match(/<h1(?:\s|>)/g)||[]).length,1,`${page}: exactly one h1`);checks++;
 assert.equal((html.match(/rel="canonical"/g)||[]).length,1,`${page}: canonical`);checks++;
 const route=page.replace(/index\.html$/,'').replace(/\.html$/,'');
 assert.equal(html.match(/rel="canonical" href="([^"]+)"/)[1],expectedBase+'/'+route);checks++;
 assert.ok(!html.includes('https://mobrava.github.io/Clipbara'),page+': stale site URL');checks++;
 for(const alt of html.matchAll(/rel="alternate" hreflang="([^"]+)" href="([^"]+)"/g)){assert.ok(alt[2].startsWith(expectedBase+'/'));checks++;}
 assert.ok(html.includes('content="'+expectedBase+'/site-assets/social.png"'));checks++;
 assert.ok(html.includes(`lang="${page.startsWith('ko/')?'ko':'en'}"`));checks++;
 assert.ok(!html.includes('—'),`${page}: forbidden punctuation`);checks++;
 const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(ids).size,ids.length);checks++;
 for(const match of html.matchAll(/\b(?:href|src)="([^"]+)"/g)){
  const ref=match[1];if(/^(https?:|mailto:)/.test(ref))continue;
  const [p,fragment]=ref.split('#');let file=p?path.resolve(path.dirname(full),p):full;
  if(p?.endsWith('/'))file=path.join(file,'index.html');
  await fs.access(file);checks++;
  if(fragment){const target=await fs.readFile(file,'utf8');assert.ok(target.includes(`id="${fragment}"`),`${page}: missing anchor ${ref}`);checks++;}
 }
 for(const match of html.matchAll(/<script type="application\/ld\+json">(.*?)<\/script>/g)){const schema=JSON.parse(match[1]);assert.equal(schema.name,'Clipbara');assert.ok(schema.sameAs.includes('https://github.com/mobrava/Clipbara'));checks++;}
 for(const term of ['id6803537696','https://github.com/mobrava/Clipbara']){assert.ok(html.includes(term));checks++;}
 console.log(`PASS ${page}`);
}
const css=await fs.readFile(path.join(root,'site.css'),'utf8');assert.ok(css.includes('prefers-reduced-motion'));checks++;
assert.ok(css.includes(':focus-visible'));checks++;
await fs.access(path.join(root,'site-assets/social.png'));checks++;
const privacy=await fs.readFile(path.join(root,'privacy.html'),'utf8');assert.ok(privacy.includes('href="'+expectedBase+'/privacy"'));checks++;
const sitemap=await fs.readFile(path.join(root,'sitemap.xml'),'utf8');for(const m of sitemap.matchAll(/<loc>(.*?)<\/loc>/g)){assert.ok(m[1].startsWith(expectedBase+'/'));assert.ok(!m[1].endsWith('.html'));checks+=2;}
const notFound=await fs.readFile(path.join(root,'404.html'),'utf8');assert.ok(notFound.includes('content="noindex"'));checks++;
const headers=await fs.readFile(path.join(root,'_headers'),'utf8');assert.ok(headers.includes('https://:project.pages.dev/*'));assert.ok(headers.includes('frame-ancestors'));checks+=2;
console.log(`${checks} static checks passed for ${root}. Browser interaction and responsive checks are separate.`);
