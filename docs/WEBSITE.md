# Official website

The English homepage and Korean translation are static HTML. Product copy lives in `scripts/site-content.mjs`; the generator is `scripts/build-site.mjs`. The site does not require an application server, database, external fonts or analytics.

## Build and check

```sh
node scripts/build-site.mjs
node scripts/test-site.mjs
node scripts/package-site.mjs
SITE_TEST_ROOT=build/site node scripts/test-site.mjs
```

The default canonical domain is `https://clipbara.app`. Set `SITE_URL` explicitly if the official domain changes. Canonical, hreflang, Open Graph and sitemap URLs are generated together. Public safety and privacy canonicals use extensionless URLs, matching Cloudflare Pages routing; `.html` links remain compatible with the legacy GitHub Pages copy.

`package-site.mjs` copies only referenced website assets and the explicit public page list into `build/site`. It does not publish documentation, local `.agents` notes or unused images. It never deletes files: unexpected leftovers cause an error instead of silently removing them.

## Local preview

```sh
node scripts/preview-site.mjs
# Or test the exact publish directory on another port:
SITE_PREVIEW_ROOT=build/site PORT=4389 node scripts/preview-site.mjs
```

The server listens only on `127.0.0.1` and marks all local responses `noindex`. It applies global security headers, serves extensionless HTML routes and returns a real 404 for missing pages. It does not emulate Cloudflare's CDN or TLS issuance.

## Hosting

Planned production host: Cloudflare Pages, with Git integration to this repository.

- Framework preset: None
- Production branch: `main`
- Build command: `node scripts/build-site.mjs && node scripts/test-site.mjs && node scripts/package-site.mjs && SITE_TEST_ROOT=build/site node scripts/test-site.mjs`
- Build output directory: `build/site`
- Environment: `SITE_URL=https://clipbara.app`, `NODE_VERSION=22`
- Domain: `clipbara.app`
- No Pages Functions or paid add-ons

The existing GitHub Pages source (`main`, `/docs`) remains in place, with no custom domain or CNAME file. This preserves the existing `mobrava.github.io/Clipbara/privacy.html` URL. Do not bind the new domain to GitHub Pages as part of the Cloudflare deployment.

Create the Pages project and associate the custom domain through Cloudflare before changing its DNS. Use the actual hostname returned for the project, not an assumed `pages.dev` address. Cloudflare can then create the required DNS record for the owned zone. Do not point DNS at a provider before claiming the target there.

`_headers` sets basic security policy and marks provider/preview `pages.dev` URLs `noindex`. `404.html` disables the Pages SPA fallback. A www-domain alias or provider-domain redirect is not currently configured; any future domain-level redirect must use Cloudflare's supported redirect rules, not `_redirects` (which does not support domain-level sources).

## Publication checks

- HTTPS certificate valid on `clipbara.app`.
- English and Korean pages, privacy and safety routes, images and CSS return expected statuses.
- Missing paths return 404, not the homepage.
- No security-policy violations prevent menu, carousel or copy-command behavior.
- Canonical, hreflang, sitemap and social image use `clipbara.app`.
- App Store and GitHub download links still resolve.
- Legacy GitHub privacy URL still returns 200.
- Site headers allow indexing on `clipbara.app`, but not on Pages provider/preview URLs.

Publishing code, creating the Cloudflare project, DNS changes, public repository metadata changes and Search Console registration each need to remain within the user's explicitly approved scope.
