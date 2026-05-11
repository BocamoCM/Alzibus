/**
 * Mini parser de User-Agent — sin dependencias externas.
 *
 * Devuelve { platform, browser }:
 *  - platform: android | ios | windows | macos | linux | other
 *  - browser:  chrome | safari | firefox | edge | opera | samsung | other
 *
 * Notas:
 *  - El orden de los `if` importa (Edge contiene "Chrome", Samsung Browser también, etc.)
 *  - Si el UA proviene de un cliente Dart (app móvil) devolvemos platform='unknown'
 *    porque la app debe enviar `platform` explícitamente en el body.
 */
function parseUserAgent(uaRaw) {
    const ua = (uaRaw || '').toString();
    if (!ua) return { platform: 'unknown', browser: 'unknown' };

    // ── Platform ──────────────────────────────────────────
    // 1º intentamos detectar el User-Agent propio de la app:
    //    "Alzitrans/1.0 (Android)" / "(iOS)" / "(Windows)" ...
    // Así no dependemos del body en endpoints que olviden enviar 'platform'.
    let platform = 'other';
    const alziMatch = ua.match(/Alzitrans\/[\d.]+\s*\(([A-Za-z]+)\)/);
    if (alziMatch) {
        const p = alziMatch[1].toLowerCase();
        if (['android','ios','windows','macos','linux','web'].includes(p)) {
            platform = p;
        }
    }
    // 2º fallback: User-Agent estándar de navegador
    else if (/android/i.test(ua)) platform = 'android';
    else if (/iphone|ipad|ipod/i.test(ua)) platform = 'ios';
    else if (/windows nt/i.test(ua)) platform = 'windows';
    else if (/mac os x|macintosh/i.test(ua)) platform = 'macos';
    else if (/linux/i.test(ua)) platform = 'linux';
    else if (/dart\//i.test(ua)) platform = 'unknown'; // cliente Flutter no especificó

    // ── Browser ───────────────────────────────────────────
    let browser = 'other';
    if (/edg\//i.test(ua)) browser = 'edge';                  // Edge (Chromium)
    else if (/opr\/|opera/i.test(ua)) browser = 'opera';
    else if (/samsungbrowser/i.test(ua)) browser = 'samsung';
    else if (/firefox|fxios/i.test(ua)) browser = 'firefox';
    else if (/chrome|crios/i.test(ua)) browser = 'chrome';    // tras Edge/Opera/Samsung
    else if (/safari/i.test(ua)) browser = 'safari';          // último (Chrome también lleva "Safari")

    return { platform, browser };
}

module.exports = { parseUserAgent };
