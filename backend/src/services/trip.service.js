const tripRepository = require('../repositories/trip.repository');
const { sendDiscordNotification } = require('../../utils/discord');
const { BadRequestError, NotFoundError } = require('../utils/errors');

class TripService {
    async getTrips(userId) {
        return await tripRepository.getTripsByUser(userId);
    }

    async createTrip(userId, userEmail, data) {
        const { line, destination, stopName, stopId, timestamp, confirmed, paymentMethod } = data;
        
        if (!line || !destination || !stopName || stopId === undefined || !timestamp) {
            throw new BadRequestError('Datos del viaje incompletos');
        }

        const trip = await tripRepository.createTrip({
            userId,
            line,
            destination,
            stopName,
            stopId,
            timestamp,
            confirmed: confirmed ?? false,
            paymentMethod: paymentMethod || null
        });

        sendDiscordNotification(`🎫 **Viaje Validado**: \`${userEmail}\` ha validado un viaje en la **${line}** hacia **${destination}** (Parada: ${stopName})`);
        
        return trip;
    }

    async deleteTrip(tripId, userId) {
        const trip = await tripRepository.deleteTrip(tripId, userId);
        if (!trip) throw new NotFoundError('Viaje no encontrado');
        return trip;
    }

    async deleteAllTrips(userId) {
        await tripRepository.deleteAllTrips(userId);
    }
}

module.exports = new TripService();
