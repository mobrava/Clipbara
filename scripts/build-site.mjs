// Builds the static official site into docs/. Copy lives in site-content.mjs.
// Usage: SITE_URL=https://example.com node scripts/build-site.mjs
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {content, repo, store, release} from './site-content.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'docs');
const base = (process.env.SITE_URL || 'https://clipbara.app').replace(/\/$/, '');
if (!base.startsWith('https://')) throw new Error('SITE_URL must use HTTPS');

const escape = v => String(v).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const plain = v => String(v).replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
const icons = {
  copy: '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
  left: '<path d="m14 6-6 6 6 6"/>',
  right: '<path d="m10 6 6 6-6 6"/>'
};
const svg = name => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name]}</svg>`;

function head(lang, t, security = false) {
  const page = security ? 'security' : '';
  const canonical = `${base}/${lang === 'ko' ? 'ko/' : ''}${page}`;
  const title = security ? `${t.securityTitle} | Clipbara` : t.title;
  const prefix = lang === 'ko' ? '../' : './';
  const schema = {'@context': 'https://schema.org', '@type': 'SoftwareApplication', name: 'Clipbara', url: `${base}/`, applicationCategory: 'UtilitiesApplication', operatingSystem: 'macOS 14 or later; iOS 26 or later', description: t.description, softwareHelp: `${repo}/issues`, sameAs: [repo, 'https://apps.apple.com/app/id6803537696']};
  const homeOnly = security ? '' : `<link rel="preload" href="${prefix}site-assets/panel-history${lang === 'ko' ? '-ko' : ''}.webp" as="image" fetchpriority="high"><script type="application/ld+json">${JSON.stringify(schema).replaceAll('<', '\\u003c')}</script>`;
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(title)}</title><meta name="description" content="${escape(t.description)}"><meta name="theme-color" content="#ffffff"><meta name="color-scheme" content="light"><link rel="canonical" href="${canonical}"><link rel="alternate" hreflang="en" href="${base}/${page}"><link rel="alternate" hreflang="ko" href="${base}/ko/${page}"><link rel="alternate" hreflang="x-default" href="${base}/${page}"><meta property="og:type" content="website"><meta property="og:site_name" content="Clipbara"><meta property="og:title" content="${escape(title)}"><meta property="og:description" content="${escape(t.description)}"><meta property="og:url" content="${canonical}"><meta property="og:image" content="${base}/site-assets/social.png"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="Clipbara clipboard manager on Mac and iPhone"><meta property="og:locale" content="${lang === 'ko' ? 'ko_KR' : 'en_US'}"><meta name="twitter:card" content="summary_large_image"><link rel="icon" type="image/png" href="${prefix}site-assets/favicon.png"><link rel="apple-touch-icon" href="${prefix}site-assets/apple-touch-icon.png"><link rel="stylesheet" href="${prefix}site.css"><script src="${prefix}site.js" defer></script>${homeOnly}</head>`;
}

function header(lang, t, security = false) {
  const a = lang === 'ko' ? '../site-assets/' : './site-assets/';
  const home = security ? './' : '';
  const other = `${lang === 'ko' ? '../' : './ko/'}${security ? 'security.html' : ''}`;
  return `<body><a class="skip-link" href="#main">${t.skip}</a><header class="site-header"><div class="header-inner wrap"><a href="./" class="brand" aria-label="Clipbara ${lang === 'ko' ? '홈' : 'home'}"><img src="${a}icon.webp" width="36" height="36" alt="">Clipbara</a><nav class="main-nav" id="main-nav" aria-label="${lang === 'ko' ? '주 메뉴' : 'Main navigation'}"><a href="${home}#features">${t.features}</a><a href="${home}#privacy">${t.privacy}</a><a href="${home}#faq">${t.help}</a><a href="${repo}/releases">${t.updates}</a><a class="mobile-only" href="${other}" lang="${lang === 'ko' ? 'en' : 'ko'}">${lang === 'ko' ? 'English' : '한국어'}</a></nav><div class="nav-end"><a class="language" href="${other}" lang="${lang === 'ko' ? 'en' : 'ko'}">${lang === 'ko' ? 'EN' : '한국어'}</a><a href="${home}#download" class="button small">${t.get}</a><button class="menu-toggle" aria-label="${t.menu}" aria-expanded="false" aria-controls="main-nav"><span></span><span></span></button></div></div></header>`;
}

function footer(lang, t, security = false) {
  const a = lang === 'ko' ? '../site-assets/' : './site-assets/';
  const up = lang === 'ko' ? '../' : './';
  const page = security ? 'security.html' : '';
  return `<footer class="site-footer"><div class="wrap"><div class="footer-top"><div class="footer-brand"><a class="brand" href="./"><img src="${a}icon.webp" width="36" height="36" alt="">Clipbara</a><p>${t.footerBlurb}</p></div><div class="footer-groups"><div class="footer-links"><h3>${t.product}</h3><a href="./#features">${t.features}</a><a href="./#download">${t.download}</a><a href="${repo}/releases">${t.updates}</a></div><div class="footer-links"><h3>${t.resources}</h3><a href="./#faq">${t.help}</a><a href="${repo}">${t.source}</a><a href="./security.html">${t.safety}</a><a href="${up}privacy.html">${t.privacy}</a></div></div></div><div class="footer-bottom"><span>${t.copyright}</span><nav class="locale-links" aria-label="${t.languageLabel}"><a href="${up}${page}" lang="en" ${lang === 'en' ? 'aria-current="page"' : ''}>English</a><a href="${lang === 'ko' ? './' : './ko/'}${page}" lang="ko" ${lang === 'ko' ? 'aria-current="page"' : ''}>한국어</a></nav></div></div></footer></body></html>`;
}

function homepage(lang, t) {
  const a = lang === 'ko' ? '../site-assets/' : './site-assets/';
  const loc = lang === 'ko' ? '-ko' : '';
  const storeHref = escape(store);
  const img = (name, alt, w, h, extra = 'loading="lazy"') => `<img src="${a}${name}${loc}.webp" alt="${escape(plain(alt))}" width="${w}" height="${h}" ${extra} decoding="async">`;
  const rows = list => list.map(([k, v]) => `<div><dt>${k}</dt><dd>${v}</dd></div>`).join('');

  const hero = `<section class="hero" aria-labelledby="hero-heading">
<div class="wrap"><h1 id="hero-heading">${t.hero}</h1><p class="hero-copy">${t.sub}</p><div class="hero-actions"><a class="button" href="#download">${t.cta}</a><a class="button secondary" href="${repo}">${t.secondary}</a></div><p class="hero-note">${t.note}</p></div>
<div class="stage"><div class="mac"><div class="mac-lid"><div class="mac-screen"><img class="mac-ql" src="${a}quicklook-popover${loc}.webp" alt="" width="1600" height="1172" decoding="async"><div class="mac-panel">${img('panel-history', t.deviceAlt, 3840, 747, 'fetchpriority="high"')}</div></div></div><div class="mac-base"></div></div><img class="stage-phone" src="${a}phone${loc}.webp" alt="${escape(t.phoneAlt)}" width="733" height="${lang === 'ko' ? 1560 : 1555}" decoding="async"></div>
</section>`;

  const tones = ['orange', 'dark', 'blue', 'light'];
  const card = (s, i) => {
    const popover = s[2] === 'quicklook-popover';
    return `<article class="feature-card tone-${tones[i]}${popover ? ' is-popover' : ''}" aria-roledescription="slide" aria-label="${i + 1} / ${t.slides.length}"><div class="feature-text"><h3>${s[0]}</h3><p>${s[1]}</p></div><div class="${popover ? 'shot-popover' : s[2].endsWith('-dark') ? 'shot-panel shot-dark' : 'shot-panel'}">${popover ? img(s[2], s[3], 1600, 1172) : img(s[2], s[3], 3840, 747)}</div></article>`;
  };
  const features = `<section class="features" id="features" aria-labelledby="features-heading">
<div class="wrap"><h2 id="features-heading">${t.featureHeading}</h2></div>
<div class="feature-track" role="region" aria-roledescription="carousel" aria-label="${t.carousel}" tabindex="0">${t.slides.map(card).join('')}</div>
<div class="carousel-controls wrap"><span></span><div class="dots">${t.slides.map((_, i) => `<button class="dot" aria-label="${t.slide} ${i + 1}" aria-current="${i === 0}"></button>`).join('')}</div><div class="arrows"><span class="sr-only" data-carousel-status aria-live="polite">1 / ${t.slides.length}</span><button class="round-button" data-prev aria-label="${t.previous}" disabled>${svg('left')}</button><button class="round-button" data-next aria-label="${t.next}">${svg('right')}</button></div></div>
</section>`;

  const chord = k => `<span class="chord"><kbd>⌘</kbd><kbd>${k}</kbd></span>`;
  const queue = `<section class="queue" aria-labelledby="queue-heading"><div class="wrap split">
<div class="split-text"><h2 id="queue-heading">${t.queueHeading}</h2><p>${t.queueText}</p><div class="keyseq" aria-hidden="true"><span class="keyseq-group">${chord('C').repeat(3)}</span><span class="keyseq-group"><span class="keyseq-arrow">→</span>${chord('V').repeat(3)}</span></div><p class="fine">${t.queueNote} <a href="${repo}#usage">${t.queueLink}</a></p></div>
<div class="queue-shot">${img('queue-hud', t.queueAlt, 1200, 548)}</div>
</div></section>`;

  const iphone = `<section class="iphone" id="iphone" aria-labelledby="iphone-heading"><div class="wrap split">
<div class="iphone-shot">${img('iphone-keyboard', t.syncAlt, 1200, 1500)}</div>
<div class="split-text"><h2 id="iphone-heading">${t.syncHeading}</h2><dl class="rows">${rows(t.syncRows)}</dl><a class="button" href="${storeHref}">${t.syncLink}</a><p class="fine">${t.syncNote}</p></div>
</div></section>`;

  const privacy = `<section class="privacy" id="privacy" aria-labelledby="privacy-heading"><div class="wrap">
<h2 id="privacy-heading">${t.privacyHeading}</h2>
<div class="facts">${t.facts.map(([k, v]) => `<div><h3>${k}</h3><p>${v}</p></div>`).join('')}</div>
<p class="privacy-more">${t.privacyMore} <a href="${lang === 'ko' ? '../' : './'}privacy.html">${t.privacyLink}</a> · <a href="${repo}">${t.sourceLink}</a></p>
</div></section>`;

  const brew = `<div class="brew"><code>brew install --cask mobrava/tap/clipbara</code><button class="copy-button" data-copy-brew data-success="${t.copied}" data-failure="${t.copyFail}" aria-label="${t.copy}">${svg('copy')}</button><span class="copy-feedback" role="status" aria-live="polite"></span></div>`;
  const edition = (e, i) => `<article class="edition"><h3>${e.name}</h3><p class="edition-price">${e.price}</p><p class="edition-sub">${e.sub}</p><a class="button${i === 0 ? ' secondary' : ''}" href="${i === 0 ? release : storeHref}">${e.button}</a><dl class="rows">${rows(e.rows)}</dl>${i === 0 ? brew : ''}</article>`;
  const download = `<section class="download" id="download" aria-labelledby="download-heading"><div class="wrap">
<h2 id="download-heading">${t.downloadHeading}</h2><p class="section-copy">${t.downloadText}</p>
<div class="editions">${t.editions.map(edition).join('')}</div>
<p class="signed">${t.signed} <a href="./security.html">${t.safetyLink}</a></p>
</div></section>`;

  const faq = `<section class="faq" id="faq" aria-labelledby="faq-heading"><div class="wrap">
<h2 id="faq-heading">${t.faqHeading}</h2>
<div class="faq-list">${t.faqs.map(([q, x]) => `<details class="faq-item"><summary>${q}</summary><p>${x}</p></details>`).join('')}</div>
</div></section>`;

  return `${head(lang, t)}${header(lang, t)}<main id="main">${hero}${features}${queue}${iphone}${privacy}${download}${faq}</main>${footer(lang, t)}`;
}

for (const [lang, t] of Object.entries(content)) {
  const dir = lang === 'ko' ? path.join(out, 'ko') : out;
  await fs.mkdir(dir, {recursive: true});
  await fs.writeFile(path.join(dir, 'index.html'), homepage(lang, t));
  await fs.writeFile(path.join(dir, 'security.html'), `${head(lang, t, true)}${header(lang, t, true)}<main id="main" class="safety wrap"><h1>${t.securityTitle}</h1><p class="lead">${t.securityLead}</p>${t.securitySections.map(([h, p]) => `<section><h2>${h}</h2>${p}</section>`).join('')}</main>${footer(lang, t, true)}`);
}

const privacyFile = path.join(out, 'privacy.html');
let privacyHtml = await fs.readFile(privacyFile, 'utf8');
const privacyCanonical = `<link rel="canonical" href="${base}/privacy">`;
privacyHtml = privacyHtml.includes('rel="canonical"') ? privacyHtml.replace(/<link rel="canonical"[^>]*>/, privacyCanonical) : privacyHtml.replace('</title>', '</title>\n' + privacyCanonical);
await fs.writeFile(privacyFile, privacyHtml);
await fs.writeFile(path.join(out, '.nojekyll'), '');
await fs.writeFile(path.join(out, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${base}/sitemap.xml\n`);
const alternates = page => `<xhtml:link rel="alternate" hreflang="en" href="${base}/${page}"/><xhtml:link rel="alternate" hreflang="ko" href="${base}/ko/${page}"/><xhtml:link rel="alternate" hreflang="x-default" href="${base}/${page}"/>`;
const urls = ['', 'ko/', 'security', 'ko/security', 'privacy'].map(p => `<url><loc>${base}/${p}</loc>${p.includes('privacy') ? '' : alternates(p.includes('security') ? 'security' : '')}</url>`).join('');
await fs.writeFile(path.join(out, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${urls}</urlset>\n`);

// A real 404 keeps Cloudflare Pages from treating this static site as an SPA.
await fs.writeFile(path.join(out, '404.html'), `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Page not found | Clipbara</title><style>body{margin:0;font:18px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1d1d21;background:#fff}main{max-width:620px;margin:14vh auto;padding:32px}a{color:#2463eb;text-decoration:none}h1{font-size:48px;letter-spacing:-.04em;line-height:1.12}p{color:#666}a:focus-visible{outline:3px solid #2463eb;outline-offset:5px}</style></head><body><main><a href="${base}/">Clipbara</a><h1>Page not found</h1><p>This page may have moved, or the address may be incorrect.</p><p lang="ko">페이지를 찾을 수 없어요. 주소를 확인하거나 홈페이지로 돌아가 주세요.</p><a href="${base}/">Go to the homepage</a> · <a href="${base}/ko/" lang="ko">한국어 홈페이지</a></main></body></html>`);
console.log(`Built English/Korean homepage + download-safety pages. Canonical: ${base}/`);
