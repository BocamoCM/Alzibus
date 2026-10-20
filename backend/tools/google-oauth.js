#!/usr/bin/env node
// ──────────────────────────────────────────────────────────────
//  google-oauth.js — Obtén un refresh_token para AdMob + AdSense.
//
//  Se ejecuta UNA VEZ, en una máquina con navegador (tu PC):
//
//     cd backend
//     npm install googleapis            # si no está
//     node tools/google-oauth.js <CLIENT_ID> <CLIENT_SECRET>
//     (o define GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET en el entorno)
//
//  Abre la URL que imprime, acepta, y copia el GOOGLE_REFRESH_TOKEN
//  resultante al backend/.env de la Raspberry.
//
//  Requisito en Google Cloud Console:
//    - Habilita "AdMob API" y "AdSense Management API".
//    - Crea una credencial OAuth 2.0 (tipo "App de escritorio" es lo
//      más fácil; si usas "Aplicación web", añade como URI de redirección
//      autorizada:  http://localhost:4455/oauth2callback )
// ──────────────────────────────────────────────────────────────

const http = require('http');
const { google } = require('googleapis');

const CLIENT_ID = process.argv[2] || process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.argv[3] || process.env.GOOGLE_CLIENT_SECRET;
const PORT = 4455;
const REDIRECT = `http://localhost:${PORT}/oauth2callback`;

const SCOPES = [
    'https://www.googleapis.com/auth/admob.readonly',
    'https://www.googleapis.com/auth/adsense.readonly',
];

if (!CLIENT_ID || !CLIENT_SECRET) {
    console.error('\n❌ Falta CLIENT_ID / CLIENT_SECRET.');
    console.error('   Uso: node tools/google-oauth.js <CLIENT_ID> <CLIENT_SECRET>\n');
    process.exit(1);
}

const oauth2 = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT);

const authUrl = oauth2.generateAuthUrl({
    access_type: 'offline',   // imprescindible para obtener refresh_token
    prompt: 'consent',        // fuerza a devolver refresh_token siempre
    scope: SCOPES,
});

console.log('\n1) Abre esta URL en tu navegador y acepta:\n');
console.log('   ' + authUrl + '\n');
console.log(`2) Esperando el redirect en ${REDIRECT} ...\n`);

const server = http.createServer(async (req, res) => {
    if (!req.url.startsWith('/oauth2callback')) {
        res.writeHead(404); res.end(); return;
    }
    const url = new URL(req.url, `http://localhost:${PORT}`);
    const code = url.searchParams.get('code');
    const err = url.searchParams.get('error');
    if (err) {
        res.end('Error: ' + err);
        console.error('❌ El usuario denegó o hubo un error:', err);
        server.close(); process.exit(1);
    }
    try {
        const { tokens } = await oauth2.getToken(code);
        res.end('✅ Listo. Ya puedes cerrar esta pestaña y volver a la terminal.');
        console.log('✅ ¡Conseguido!\n');
        if (tokens.refresh_token) {
            console.log('Añade esto al backend/.env de la Raspberry:\n');
            console.log('   GOOGLE_CLIENT_ID=' + CLIENT_ID);
            console.log('   GOOGLE_CLIENT_SECRET=' + CLIENT_SECRET);
            console.log('   GOOGLE_REFRESH_TOKEN=' + tokens.refresh_token + '\n');
        } else {
            console.log('⚠️  No se devolvió refresh_token. Revoca el acceso en');
            console.log('   https://myaccount.google.com/permissions y repite con prompt=consent.\n');
        }
    } catch (e) {
        res.end('Error al canjear el código: ' + e.message);
        console.error('❌ Error:', e.message);
    } finally {
        server.close();
        setTimeout(() => process.exit(0), 500);
    }
});

server.listen(PORT);
