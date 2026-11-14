Codificador WebP (libwebp compilado a WebAssembly), tomado sin cambios del
paquete `@jsquash/webp` 1.5.0 (`codec/enc/webp_enc.js` y `webp_enc.wasm`),
que a su vez viene de Squoosh (Google). Licencia Apache-2.0, ver `LICENSE`.

Solo se carga en navegadores cuyo `canvas.toBlob` no sabe generar WebP
(por ejemplo Safari en iPhone).
