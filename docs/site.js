const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const header = document.querySelector('.site-header');
const menu = document.querySelector('.main-nav');
const menuButton = document.querySelector('.menu-toggle');
function closeMenu() { menu?.classList.remove('open'); menuButton?.setAttribute('aria-expanded', 'false'); }
menuButton?.addEventListener('click', () => { const open = menuButton.getAttribute('aria-expanded') !== 'true'; menuButton.setAttribute('aria-expanded', String(open)); menu.classList.toggle('open', open); });
menu?.querySelectorAll('a').forEach(a => a.addEventListener('click', closeMenu));
document.addEventListener('keydown', e => { if (e.key === 'Escape' && menuButton?.getAttribute('aria-expanded') === 'true') { closeMenu(); menuButton.focus(); } });
window.matchMedia('(min-width: 761px)').addEventListener('change', e => { if (e.matches) closeMenu(); });
function updateHeader() { header?.classList.toggle('scrolled', window.scrollY > 8); }
window.addEventListener('scroll', updateHeader, {passive:true}); updateHeader();
const track = document.querySelector('.feature-track');
if (track) {
  const cards = [...track.querySelectorAll('.feature-card')];
  const dots = [...document.querySelectorAll('.dot')];
  const prev = document.querySelector('[data-prev]');
  const next = document.querySelector('[data-next]');
  const live = document.querySelector('[data-carousel-status]');
  let current = 0, frame = 0;
  function go(index) {
    const target = Math.max(0, Math.min(cards.length - 1, index));
    const padding = parseFloat(getComputedStyle(track).paddingLeft);
    track.scrollTo({left: cards[target].offsetLeft - track.offsetLeft - padding, behavior: reducedMotion.matches ? 'instant' : 'smooth'});
  }
  function sync() {
    const max = track.scrollWidth - track.clientWidth;
    const padding = parseFloat(getComputedStyle(track).paddingLeft);
    const x = track.scrollLeft + padding;
    current = cards.reduce((best, card, i) => Math.abs(card.offsetLeft - track.offsetLeft - x) < Math.abs(cards[best].offsetLeft - track.offsetLeft - x) ? i : best, 0);
    if (track.scrollLeft >= max - 3) current = cards.length - 1;
    prev.disabled = current === 0;
    next.disabled = current === cards.length - 1;
    dots.forEach((dot, i) => dot.setAttribute('aria-current', String(i === current)));
    live.textContent = `${current + 1} / ${cards.length}`;
    frame = 0;
  }
  track.addEventListener('scroll', () => { if (!frame) frame = requestAnimationFrame(sync); }, {passive:true});
  track.addEventListener('keydown', e => { if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { e.preventDefault(); go(current + (e.key === 'ArrowRight' ? 1 : -1)); } });
  dots.forEach((dot, i) => dot.addEventListener('click', () => go(i)));
  prev.addEventListener('click', () => go(current - 1)); next.addEventListener('click', () => go(current + 1));
  window.addEventListener('resize', sync); sync();
}
const copyButton = document.querySelector('[data-copy-brew]');
copyButton?.addEventListener('click', async () => {
  const output = document.querySelector('.copy-feedback');
  try { await navigator.clipboard.writeText('brew install --cask mobrava/tap/clipbara'); output.textContent = copyButton.dataset.success; }
  catch { output.textContent = copyButton.dataset.failure; }
  setTimeout(() => { output.textContent = ''; }, 5000);
});
