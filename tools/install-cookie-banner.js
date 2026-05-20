#!/usr/bin/env node
/*
 * tools/install-cookie-banner.js
 * ─────────────────────────────────────────────────────────
 * Recorre todos los HTMLs de website/ y:
 *   1. Reemplaza el `<script async ... adsbygoogle.js ...>` directo por
 *      `<script defer src="/cookie-banner.js"></script>` — así el script
 *      de AdSense solo se carga si el usuario consiente cookies.
 *   2. Añade `<link rel="stylesheet" href="/cookie-banner.css">` al <head>.
 *
 * Idempotente: si ya está instalado, no toca el archivo.
 *
 * Uso: node tools/install-cookie-banner.js
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', 'website');
const SKIP = new Set([
    'googlec0a97513f59cf3be.html', // archivo de verificación Search Console
]);

// Regex que matchea el script de AdSense actual (con o sin variaciones de espacios)
const ADSENSE_SCRIPT_RE = /<script\s+async\s+src="https:\/\/pagead2\.googlesyndication\.com\/pagead\/js\/adsbygoogle\.js\?client=ca-pub-[\d]+"\s*\n?\s*crossorigin="anonymous"><\/script>/g;

const COOKIE_BANNER_SCRIPT = '<script defer src="/cookie-banner.js"></script>';
const COOKIE_BANNER_CSS = '<link rel="stylesheet" href="/cookie-banner.css">';

let totalFiles = 0;
let modifiedFiles = 0;
let skippedFiles = 0;
let alreadyInstalled = 0;

function processFile(filePath) {
    const rel = path.relative(ROOT, filePath);
    const filename = path.basename(filePath);
    if (SKIP.has(filename)) {
        console.log(`  ⊘ ${rel} (skip)`);
        skippedFiles++;
        return;
    }

    let content = fs.readFileSync(filePath, 'utf8');
    const originalContent = content;
    let changed = false;

    // 1. Reemplazar script AdSense por banner si está presente
    if (ADSENSE_SCRIPT_RE.test(content)) {
        content = content.replace(ADSENSE_SCRIPT_RE, COOKIE_BANNER_SCRIPT);
        ADSENSE_SCRIPT_RE.lastIndex = 0;
        changed = true;
    }

    // 2. Asegurar que el CSS del banner está enlazado en el <head>
    if (!content.includes('cookie-banner.css')) {
        content = content.replace(
            /<\/head>/,
            `    ${COOKIE_BANNER_CSS}\n</head>`
        );
        changed = true;
    }

    // 3. Si el HTML no tenía el script de AdSense (raros), añadir el banner script
    //    antes del cierre de </body>.
    if (!content.includes('cookie-banner.js')) {
        if (content.includes('</body>')) {
            content = content.replace(
                /<\/body>/,
                `    ${COOKIE_BANNER_SCRIPT}\n</body>`
            );
            changed = true;
        }
    }

    if (changed) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log(`  ✓ ${rel}`);
        modifiedFiles++;
    } else {
        console.log(`  · ${rel} (ya instalado)`);
        alreadyInstalled++;
    }
}

function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            // Saltamos /app/ (Flutter web, tiene su propio sistema)
            if (entry.name === 'app') continue;
            walk(full);
        } else if (entry.isFile() && entry.name.endsWith('.html')) {
            totalFiles++;
            processFile(full);
        }
    }
}

console.log('🍪 Instalando cookie banner en website/...\n');
walk(ROOT);
console.log(`\n📊 Resumen:`);
console.log(`   Total HTMLs encontrados:   ${totalFiles}`);
console.log(`   Modificados:               ${modifiedFiles}`);
console.log(`   Ya instalado (sin cambio): ${alreadyInstalled}`);
console.log(`   Saltados (Google verif):   ${skippedFiles}`);
console.log(`\n✅ Listo.`);
