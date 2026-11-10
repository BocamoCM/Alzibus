// Resumen de las incidencias de TomTom para el aviso de "tráfico denso".
//
// TomTom devuelve en la caja de Alzira cualquier incidencia: obras, carriles
// cortados, vehículos averiados… Casi siempre hay alguna, así que contarlas
// todas hacía que el aviso saliera siempre. Solo cuenta como tráfico denso un
// atasco (iconCategory 6, "Jam") con retraso moderado o grande
// (magnitudeOfDelay 2 o 3), o con más de 2 minutos de retraso.
// https://developer.tomtom.com/traffic-api/documentation/traffic-incidents/incident-details

const JAM = 6;
const MIN_DELAY_S = 120;

function isDenseTraffic(props) {
    if (!props || props.iconCategory !== JAM) return false;
    const magnitude = Number(props.magnitudeOfDelay) || 0;
    const delay = Number(props.delay) || 0;
    return magnitude === 2 || magnitude === 3 || delay >= MIN_DELAY_S;
}

/** { incidentCount, hasIncidents, totalIncidents } a partir de la lista de TomTom. */
function summarizeIncidents(incidents) {
    const list = Array.isArray(incidents) ? incidents : [];
    const jams = list.filter((i) => isDenseTraffic(i && i.properties));
    return { incidentCount: jams.length, hasIncidents: jams.length > 0, totalIncidents: list.length };
}

module.exports = { summarizeIncidents, isDenseTraffic };
