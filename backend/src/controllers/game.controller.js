// ==========================================
// src/controllers/game.controller.js
// ==========================================
const gameService = require('../services/game.service');

class GameController {
    async getState(req, res, next) {
        try {
            const state = await gameService.getState(req.user.id);
            res.json(state);
        } catch (err) { next(err); }
    }

    async syncCoins(req, res, next) {
        try {
            const result = await gameService.syncCoins(req.user.id, req.body?.coins);
            res.json(result);
        } catch (err) { next(err); }
    }

    async syncSkins(req, res, next) {
        try {
            const result = await gameService.syncOwnedSkins(req.user.id, req.body?.ownedSkins);
            res.json(result);
        } catch (err) { next(err); }
    }
}

module.exports = new GameController();
