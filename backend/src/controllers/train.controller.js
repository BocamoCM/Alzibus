const trainService = require('../services/train.service');

class TrainController {
    async getAlziraDepartures(req, res, next) {
        try {
            const result = await trainService.getAlziraDepartures();
            // La web lo consulta cada minuto: que los navegadores/proxies no
            // guarden más de 30 s (lo mismo que dura la caché del servicio).
            res.set('Cache-Control', 'public, max-age=30');
            res.status(result.ok ? 200 : 503).json(result);
        } catch (err) { next(err); }
    }
}

module.exports = new TrainController();
