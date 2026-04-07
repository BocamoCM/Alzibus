const { sendDiscordNotification } = require('../utils/discord');
require('dotenv').config({ path: '../.env' });

async function runTest() {
    console.log('--- TEST DE NOTIFICACIONES DISCORD ---');

    // Test 1: QR Scan (Embed base)
    console.log('Enviando Test 1: QR Scan...');
    await sendDiscordNotification({
        embeds: [{
            title: "📲 TEST: Nuevo Escaneo de QR",
            description: "Esto es una prueba del nuevo sistema de notificaciones enriquecidas.",
            fields: [
                { name: "Dispositivo", value: "Android (Test)", inline: true },
                { name: "Origen", value: "Script de Verificación", inline: true }
            ]
        }]
    });

    // Test 2: Error (Rojo)
    console.log('Enviando Test 2: Error Database...');
    await sendDiscordNotification({
        embeds: [{
            title: "🔴 TEST: Error de Base de Datos",
            description: "Simulación de un fallo crítico.",
            color: 0xFF0000,
            fields: [{ name: "Error", value: "`ETIMEDOUT: Connection timed out`" }]
        }]
    });

    // Test 3: Éxito/Instalación (Dorado)
    console.log('Enviando Test 3: Instalación...');
    await sendDiscordNotification({
        embeds: [{
            title: "🎉 TEST: ¡NUEVA INSTALACIÓN! 🎉",
            description: "¡Felicidades Borja! Todo funciona perfecto.",
            color: 0xD4AF37,
            fields: [{ name: "Campaña", value: "Organic Test" }]
        }]
    });

    console.log('--- TESTS ENVIADOS ---');
}

runTest();
