// Caché de los feeds de Renfe: una sola descarga aunque lleguen varias
// peticiones a la vez, y con la caché caducada se responde al momento con el
// último dato mientras se renueva en segundo plano.
const { EventEmitter } = require('events');

jest.mock('https', () => ({ get: jest.fn() }));

const FEED = { entity: [] };
const DELAY_MS = 150;
let failNext = false;

function fakeGet(url, _opts, cb) {
    const req = new EventEmitter();
    req.setTimeout = jest.fn();
    req.destroy = jest.fn();
    setTimeout(() => {
        const res = new EventEmitter();
        res.statusCode = failNext ? 500 : 200;
        res.setEncoding = jest.fn();
        res.resume = jest.fn();
        cb(res);
        if (res.statusCode === 200) {
            res.emit('data', JSON.stringify(FEED));
            res.emit('end');
        }
    }, DELAY_MS);
    return req;
}

let https;
let trainService;
let now;

beforeEach(() => {
    jest.resetModules();
    https = require('https');
    https.get.mockImplementation(fakeGet);
    failNext = false;
    now = Date.parse('2026-11-03T10:00:00Z');
    jest.spyOn(Date, 'now').mockImplementation(() => now);
    jest.spyOn(console, 'warn').mockImplementation(() => {});
    trainService = require('../../src/services/train.service');
});

afterEach(() => jest.restoreAllMocks());

const feedCalls = () => https.get.mock.calls.filter(([u]) => !u.includes('alerts')).length;
const alertCalls = () => https.get.mock.calls.filter(([u]) => u.includes('alerts')).length;

test('dos peticiones a la vez con la caché vacía hacen una sola descarga de cada feed', async () => {
    const [a, b] = await Promise.all([trainService.getAlziraDepartures(), trainService.getAlziraDepartures()]);
    expect(a).toBeTruthy();
    expect(b).toBeTruthy();
    expect(feedCalls()).toBe(1);
    expect(alertCalls()).toBe(1);
});

test('con la caché caducada responde sin esperar a Renfe y renueva en segundo plano', async () => {
    await trainService.getAlziraDepartures();
    now += 31 * 1000; // pasa el TTL de 30 s del feed (las alertas duran 2 min)

    const t0 = process.hrtime.bigint();
    const res = await trainService.getAlziraDepartures();
    const ms = Number(process.hrtime.bigint() - t0) / 1e6;

    expect(res).toBeTruthy();
    expect(ms).toBeLessThan(DELAY_MS); // no ha esperado a la descarga
    expect(feedCalls()).toBe(2); // se ha lanzado la renovación
    expect(alertCalls()).toBe(1); // las alertas aún no habían caducado

    await new Promise((r) => setTimeout(r, DELAY_MS + 50));
    await trainService.getAlziraDepartures();
    expect(feedCalls()).toBe(2); // ya renovado: no vuelve a descargar
});

test('si Renfe falla se sigue sirviendo el último dato bueno sin lanzar', async () => {
    await trainService.getAlziraDepartures();
    now += 31 * 1000;
    failNext = true;

    await expect(trainService.getAlziraDepartures()).resolves.toBeTruthy();
    await new Promise((r) => setTimeout(r, DELAY_MS + 50));
    await expect(trainService.getAlziraDepartures()).resolves.toBeTruthy();
});

test('si Renfe falla la primera vez la respuesta no lanza', async () => {
    failNext = true;
    await expect(trainService.getAlziraDepartures()).resolves.toBeDefined();
});
