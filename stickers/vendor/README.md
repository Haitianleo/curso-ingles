Código de terceros, sin modificar:

- `webp_enc.js` y `webp_enc.wasm`: codificador WebP (libwebp compilado a
  WebAssembly), del paquete `@jsquash/webp` 1.5.0, que a su vez viene de
  Squoosh (Google). Licencia Apache-2.0, ver `LICENSE-webp`. Solo se carga
  en navegadores cuyo `canvas.toBlob` no sabe generar WebP (por ejemplo
  Safari en iPhone).
- `gifenc.js`: codificador GIF, del paquete `gifenc` 1.0.3 de Matt
  DesLauriers. Licencia MIT, ver `LICENSE-gifenc.md`. Solo se carga al crear
  un sticker animado.
