/* PasaStickers — se inyecta en la página de Instagram que la app muestra por dentro.
 *
 * Al mantener pulsada una imagen, un sticker o un GIF aparece un botón «Pasar a PasaStickers».
 * Al tocarlo, se le manda a la app la dirección del archivo original (o el archivo mismo
 * cuando no tiene dirección descargable) por el canal `pasa`.
 *
 * No depende de cómo llame Instagram a sus clases, que cambian a menudo: mira qué imagen o
 * video hay bajo el dedo, aunque esté tapado por capas transparentes.
 */
(() => {
  if (window.__pasaGrab) return;
  window.__pasaGrab = true;

  const post = (m) => window.webkit.messageHandlers.pasa.postMessage(m);
  const HOLD_MS = 450;        // cuánto hay que mantener pulsado
  const MOVE_PX = 12;         // si el dedo se mueve más que esto, era un desplazamiento
  const MIN_SIDE = 56;        // más chico que esto son iconos y fotos de perfil

  // El iPhone muestra su propio menú («Guardar en Fotos», «Copiar») al mantener pulsada una
  // imagen; aquí estorbaría.
  document.documentElement.style.webkitTouchCallout = 'none';

  let timer = 0, hideTimer = 0, bubble = null, sx = 0, sy = 0, swallowUntil = 0;

  const hide = () => {
    clearTimeout(hideTimer);
    if (bubble) { bubble.remove(); bubble = null; }
  };

  /* El botón flotante. Con `onTap` es pulsable; sin él es solo un aviso que se va solo. */
  const say = (text, x, y, onTap) => {
    hide();
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = text;
    const s = b.style;
    s.position = 'fixed';
    s.zIndex = '2147483647';
    s.left = Math.max(12, Math.min(window.innerWidth - 232, x - 110)) + 'px';
    s.top = Math.max(12, y - 84) + 'px';
    s.width = '220px';
    s.padding = '14px 10px';
    s.border = '0';
    s.borderRadius = '16px';
    s.background = '#ffd23f';
    s.color = '#1a1505';
    s.font = '700 16px -apple-system, system-ui, sans-serif';
    s.boxShadow = '0 8px 24px rgba(0,0,0,.45)';
    s.webkitTapHighlightColor = 'transparent';
    if (onTap) {
      b.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); onTap(b); }, true);
    } else {
      s.pointerEvents = 'none';
    }
    document.documentElement.appendChild(b);
    bubble = b;
    hideTimer = setTimeout(hide, onTap ? 6000 : 3200);
  };
  // La app avisa por aquí si no pudo descargar lo elegido.
  window.__pasaSay = (text) => say(text, window.innerWidth / 2, window.innerHeight / 2, null);

  /* Qué imagen o video hay bajo ese punto, de arriba hacia abajo. */
  const mediaAt = (x, y) => {
    for (const el of document.elementsFromPoint(x, y)) {
      if (el === bubble) continue;
      if (el.tagName === 'VIDEO') return { kind: 'video', url: el.currentSrc || el.src || '', el };
      if (el.tagName === 'IMG') {
        const r = el.getBoundingClientRect();
        if (r.width >= MIN_SIDE && r.height >= MIN_SIDE) return { kind: 'img', url: el.currentSrc || el.src || '', el };
      }
    }
    return null;
  };

  const base64 = (buf) => {
    const u = new Uint8Array(buf);
    let out = '';
    for (let i = 0; i < u.length; i += 0x8000) out += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
    return btoa(out);
  };

  const send = async (m, b) => {
    b.textContent = 'Pasando…';
    b.disabled = true;
    try {
      // Con dirección web: la descarga la app, que no tiene las restricciones de la página.
      if (/^https?:/i.test(m.url)) { post({ type: 'grab', url: m.url, kind: m.kind }); return; }
      // Imagen que vive solo en la página: se manda el archivo.
      if (m.kind === 'img' && /^(blob|data):/i.test(m.url)) {
        const blob = await (await fetch(m.url)).blob();
        post({ type: 'grab', data: base64(await blob.arrayBuffer()), mime: blob.type });
        return;
      }
      // Video sin dirección propia (reels, historias): se pasa el cuadro que se está viendo,
      // para recortarlo a mano.
      if (m.kind === 'video' && m.el.videoWidth) {
        const c = document.createElement('canvas');
        c.width = m.el.videoWidth;
        c.height = m.el.videoHeight;
        c.getContext('2d').drawImage(m.el, 0, 0);
        post({ type: 'grab', data: c.toDataURL('image/png').split(',')[1], mime: 'image/png', edit: true });
        return;
      }
      say('Eso no se puede pasar.', sx, sy, null);
    } catch (err) {
      say('Eso no se puede pasar.', sx, sy, null);
    }
  };

  const cancel = () => clearTimeout(timer);
  const quiet = { capture: true, passive: true };

  addEventListener('touchstart', (e) => {
    if (bubble && e.target === bubble) return;
    hide();
    cancel();
    if (e.touches.length !== 1) return;
    sx = e.touches[0].clientX;
    sy = e.touches[0].clientY;
    timer = setTimeout(() => {
      const m = mediaAt(sx, sy);
      if (!m) return;
      swallowUntil = Date.now() + 900;     // al soltar el dedo, que Instagram no lo tome como un toque
      say('Pasar a PasaStickers', sx, sy, (b) => send(m, b));
    }, HOLD_MS);
  }, quiet);
  addEventListener('touchmove', (e) => {
    const t = e.touches[0];
    if (t && Math.hypot(t.clientX - sx, t.clientY - sy) > MOVE_PX) cancel();
  }, quiet);
  addEventListener('touchend', cancel, quiet);
  addEventListener('touchcancel', cancel, quiet);
  addEventListener('scroll', cancel, quiet);
  addEventListener('click', (e) => {
    if (bubble && e.target === bubble) return;
    if (Date.now() < swallowUntil) { e.preventDefault(); e.stopPropagation(); swallowUntil = 0; }
  }, true);
})();
