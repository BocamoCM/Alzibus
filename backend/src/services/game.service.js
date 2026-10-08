// ==========================================
// src/services/game.service.js
// ==========================================
// Lógica de monedas y skins del jugador.
//
// El cliente es offline-first: hace cambios localmente y luego sincroniza
// con el servidor mediante PUT con el valor ABSOLUTO. Esto es el patrón
// más simple y resiliente; el servidor confía en el cliente como source
// of truth de su propia sesión (las monedas no tienen valor económico).
//
// Para detectar y resolver conflictos multi-dispositivo, el servidor
// devuelve el valor actual junto con el resultado del PUT. Si el cliente
// recibe un valor distinto al que envió, sabe que hay que reconciliar
// (en la práctica: usar `max`, gana el más alto).

const gameRepository = require('../repositories/game.repository');
const { BadRequestError } = require('../utils/errors');

// Límites de sanidad. Si un cliente intenta enviar > MAX_COINS asumimos
// abuso/bug y se rechaza. No es 100% prevención de fraude — para eso
// habría que llevar todo el gameplay al servidor — pero filtra valores
// obviamente inválidos en logs y dashboards.
const MAX_COINS = 100000;

// owned_skins se persiste como CSV (ver repository). Por tanto un ID de skin
// NO puede contener comas ni caracteres raros: si lo hiciera, un cliente
// podría inyectar separadores y "colar" múltiples tokens en un solo string
// (bypass del límite por-item), o guardar payloads arbitrarios que algún
// día se rendericen en un panel admin (XSS almacenado). Restringimos a un
// charset seguro que cubre todos los IDs reales (default, fallero,
// capurullo, lluvia, graduado, navidad, alzira_fc, …) con margen de sobra.
const SKIN_ID_REGEX = /^[a-z0-9_]{1,32}$/;
// Tope de skins distintos por usuario. El catálogo real son ~7; 64 deja
// margen para años de skins futuros pero impide que un cliente infle la
// columna TEXT con miles de IDs válidos de charset.
const MAX_OWNED_SKINS = 64;

class GameService {
    async getState(userId) {
        return await gameRepository.getState(userId);
    }

    /**
     * Sincroniza monedas. El cliente envía su valor LOCAL. El servidor:
     *   - Lee su propio valor
     *   - Devuelve el MAYOR de ambos (gana el más alto = preserva ganancias
     *     entre dispositivos sin contabilidad por delta)
     *   - Persiste ese mayor
     *
     * Esto NO es contabilidad estricta — si un usuario gana 10 en móvil A
     * (offline) y 20 en móvil B (offline) y luego ambos conectan, el
     * servidor se quedará con 20, no 30. Tradeoff aceptable para
     * monedas decorativas. Si en el futuro las monedas valen dinero real,
     * habría que migrar a un modelo basado en deltas con timestamps.
     */
    async syncCoins(userId, clientCoins) {
        if (typeof clientCoins !== 'number' || !Number.isFinite(clientCoins)) {
            throw new BadRequestError('coins debe ser un número finito');
        }
        if (clientCoins < 0) {
            throw new BadRequestError('coins no puede ser negativo');
        }
        if (clientCoins > MAX_COINS) {
            throw new BadRequestError(`coins no puede exceder ${MAX_COINS}`);
        }

        // Actualización atómica (GREATEST en una sola query): elimina la
        // carrera del antiguo read-then-write. El servidor se queda con el
        // mayor entre lo que había y lo que envía el cliente.
        const coins = await gameRepository.bumpCoins(userId, Math.floor(clientCoins));
        return { coins };
    }

    /**
     * Sincroniza el set de skins poseídos. El cliente envía SU set.
     * Server hace la UNIÓN (preservar skins desbloqueados en cualquier
     * dispositivo). Si el cliente intenta "deshacer" un desbloqueo, se
     * ignora.
     */
    async syncOwnedSkins(userId, clientSkins) {
        if (!Array.isArray(clientSkins)) {
            throw new BadRequestError('ownedSkins debe ser un array');
        }
        if (clientSkins.length > MAX_OWNED_SKINS) {
            throw new BadRequestError(
                `ownedSkins no puede contener más de ${MAX_OWNED_SKINS} elementos`
            );
        }
        // Solo IDs con charset seguro (ver SKIN_ID_REGEX). Descartamos el
        // resto silenciosamente: un cliente legítimo nunca manda otra cosa,
        // y así un atacante no puede inyectar comas (separador CSV) ni
        // payloads arbitrarios en la columna TEXT.
        const validated = clientSkins.filter(
            s => typeof s === 'string' && SKIN_ID_REGEX.test(s)
        );

        const state = await gameRepository.getState(userId);
        const union = Array.from(new Set([...state.ownedSkins, ...validated, 'default']));
        // Defensa en profundidad: aunque el input venga acotado, el estado
        // previo en BD podría estar "sucio" de antes de esta validación.
        // Nunca persistimos un set por encima del tope.
        if (union.length > MAX_OWNED_SKINS) {
            throw new BadRequestError(
                `El conjunto de skins excede el máximo de ${MAX_OWNED_SKINS}`
            );
        }

        if (union.length !== state.ownedSkins.length) {
            await gameRepository.setOwnedSkins(userId, union);
        }
        return { ownedSkins: union };
    }
}

module.exports = new GameService();
