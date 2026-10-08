// ==========================================
// src/config/skin-catalog.js
// ==========================================
// Catálogo de skins de Albus con su COSTE en monedas.
//
// Es la FUENTE DE VERDAD del precio para la compra server-authoritative
// (POST /game/skins/purchase): el cliente decide la UI, pero el cobro real
// lo hace el servidor con ESTOS costes, para que no se puedan desbloquear
// skins sin pagar manipulando la app.
//
// Mantener en sync con lib/models/albus_skin.dart (campo `cost`). Al añadir
// una skin nueva hay que meterla aquí y redeployar la Pi: es intencionado —
// el servidor no puede vender algo cuyo precio no conoce.
const SKIN_CATALOG = Object.freeze({
    default: 0,
    fallero: 500,
    capurullo: 600,
    lluvia: 200,
    graduado: 350,
    navidad: 350,
    alzira_fc: 500,
});

module.exports = { SKIN_CATALOG };
