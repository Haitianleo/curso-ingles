/* PasaStickers — service worker.
   1) Guarda la app para que abra sin conexión.
   2) Recibe lo que otras apps mandan con "Compartir" (Android) y se lo deja a la página. */

const SHELL = 'pasa-shell-v3';
const INBOX = 'pasa-inbox';
const ASSETS = [
  './',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './vendor/webp_enc.js',
  './vendor/webp_enc.wasm',
  './vendor/gifenc.js',
  './vendor/omggif.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(SHELL).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) {
      if (k.startsWith('pasa-shell-') && k !== SHELL) await caches.delete(k);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin) return;
  if (e.request.method === 'POST' && url.pathname.endsWith('/recibir')) {
    e.respondWith(receive(e.request));
    return;
  }
  if (e.request.method !== 'GET') return;
  e.respondWith(networkFirst(e.request));
});

/* Lo compartido se guarda en una caché "buzón"; la página lo lee al abrir. */
async function receive(request) {
  try {
    const form = await request.formData();
    const inbox = await caches.open(INBOX);
    for (const k of await inbox.keys()) await inbox.delete(k);
    let n = 0;
    for (const f of form.getAll('media')) {
      if (!f || typeof f === 'string' || !f.size) continue;
      if (!/^(image|video)\//.test(f.type || '')) continue;
      await inbox.put('inbox/file-' + n, new Response(f, { headers: { 'Content-Type': f.type } }));
      n++;
    }
    const meta = {
      files: n,
      title: String(form.get('title') || ''),
      text: String(form.get('text') || ''),
      url: String(form.get('url') || ''),
    };
    await inbox.put('inbox/meta', new Response(JSON.stringify(meta), {
      headers: { 'Content-Type': 'application/json' },
    }));
  } catch (err) {
    /* Si algo falla, la app abre igual, solo que sin nada en el buzón. */
  }
  return Response.redirect('./?recibido=1', 303);
}

/* Red primero para que las actualizaciones lleguen; caché si no hay conexión. */
async function networkFirst(request) {
  const cache = await caches.open(SHELL);
  try {
    const res = await fetch(request);
    if (res && res.ok) cache.put(request, res.clone());
    return res;
  } catch (err) {
    const hit = await cache.match(request, { ignoreSearch: request.mode === 'navigate' });
    if (hit) return hit;
    if (request.mode === 'navigate') {
      const shell = await cache.match('./');
      if (shell) return shell;
    }
    throw err;
  }
}
