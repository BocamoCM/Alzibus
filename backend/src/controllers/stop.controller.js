const stopService = require('../services/stop.service');

class StopController {
    async getAllStops(req, res, next) {
        try {
            const result = await stopService.getAllStops();
            res.json(result);
        } catch (err) { next(err); }
    }

    async createStop(req, res, next) {
        try {
            const result = await stopService.createStop(req.body);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async updateStop(req, res, next) {
        try {
            const result = await stopService.updateStop(req.params.id, req.body);
            if (!result) return res.status(404).json({ error: 'Parada no encontrada' });
            res.json(result);
        } catch (err) { next(err); }
    }

    async deleteStop(req, res, next) {
        try {
            const result = await stopService.deleteStop(req.params.id);
            if (!result) return res.status(404).json({ error: 'Parada no encontrada' });
            res.json({ message: 'Parada eliminada' });
        } catch (err) { next(err); }
    }
}

module.exports = new StopController();
