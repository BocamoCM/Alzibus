const { summarizeIncidents } = require('../../src/utils/traffic');

const inc = (iconCategory, magnitudeOfDelay, delay) => ({ properties: { iconCategory, magnitudeOfDelay, delay } });

test('obras, cortes de carril y averías no cuentan como tráfico denso', () => {
    const r = summarizeIncidents([inc(9, 0), inc(7, 4), inc(8, 4), inc(14, 1)]);
    expect(r).toEqual({ incidentCount: 0, hasIncidents: false, totalIncidents: 4 });
});

test('un atasco leve tampoco', () => {
    expect(summarizeIncidents([inc(6, 1, 40)]).hasIncidents).toBe(false);
});

test('atasco moderado, grande o con más de 2 min de retraso sí', () => {
    expect(summarizeIncidents([inc(6, 2)]).incidentCount).toBe(1);
    expect(summarizeIncidents([inc(6, 3)]).incidentCount).toBe(1);
    expect(summarizeIncidents([inc(6, 0, 180)]).incidentCount).toBe(1);
    expect(summarizeIncidents([inc(6, 2), inc(9, 0), inc(6, 1, 30)])).toEqual({ incidentCount: 1, hasIncidents: true, totalIncidents: 3 });
});

test('respuesta vacía o rara no rompe', () => {
    expect(summarizeIncidents(undefined)).toEqual({ incidentCount: 0, hasIncidents: false, totalIncidents: 0 });
    expect(summarizeIncidents([null, {}])).toEqual({ incidentCount: 0, hasIncidents: false, totalIncidents: 2 });
});
