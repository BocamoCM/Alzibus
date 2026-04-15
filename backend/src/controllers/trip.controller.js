const tripService = require('../services/trip.service');

class TripController {
    async getTrips(req, res, next) {
        try {
            const result = await tripService.getTrips(req.user.id);
            res.json(result);
        } catch (err) { next(err); }
    }

    async createTrip(req, res, next) {
        try {
            const result = await tripService.createTrip(req.user.id, req.user.email, req.body);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async deleteTrip(req, res, next) {
        try {
            await tripService.deleteTrip(req.params.id, req.user.id);
            res.json({ message: 'Viaje eliminado' });
        } catch (err) { next(err); }
    }

    async deleteAllTrips(req, res, next) {
        try {
            await tripService.deleteAllTrips(req.user.id);
            res.json({ message: 'Historial borrado' });
        } catch (err) { next(err); }
    }
}

module.exports = new TripController();
