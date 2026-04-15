const stopRepository = require('../repositories/stop.repository');

class StopService {
    async getAllStops() {
        return await stopRepository.getAllStops();
    }

    async createStop(data) {
        return await stopRepository.createStop(data);
    }

    async updateStop(id, data) {
        return await stopRepository.updateStop(id, data);
    }

    async deleteStop(id) {
        return await stopRepository.deleteStop(id);
    }
}

module.exports = new StopService();
