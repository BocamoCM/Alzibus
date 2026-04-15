const userService = require('../services/user.service');

class UserController {
    async heartbeat(req, res, next) {
        try {
            const result = await userService.heartbeat(req.user.id);
            res.json(result);
        } catch (err) { next(err); }
    }

    async logout(req, res, next) {
        try {
            const result = await userService.logout(req.user.email);
            res.json(result);
        } catch (err) { next(err); }
    }

    async getProfile(req, res, next) {
        try {
            const result = await userService.getProfileStats(req.user.id);
            res.json(result);
        } catch (err) { next(err); }
    }

    async getRanking(req, res, next) {
        try {
            const period = req.query.period === 'all' ? 'all' : 'month';
            const result = await userService.getRanking(req.user.id, period);
            res.json(result);
        } catch (err) { next(err); }
    }

    async updateEmail(req, res, next) {
        try {
            const result = await userService.updateEmail(req.user.id, req.user.email, req.body.email);
            res.json(result);
        } catch (err) { next(err); }
    }

    async updatePassword(req, res, next) {
        try {
            const { currentPassword, newPassword } = req.body;
            const result = await userService.updatePassword(req.user.id, req.user.email, currentPassword, newPassword);
            res.json(result);
        } catch (err) { next(err); }
    }

    async deleteProfile(req, res, next) {
        try {
            const result = await userService.deleteAccount(req.user.id, req.user.email);
            res.json(result);
        } catch (err) { next(err); }
    }

    // Admin
    async getActiveUsers(req, res, next) {
        try {
            const result = await userService.getActiveUsers();
            res.json(result);
        } catch (err) { next(err); }
    }

    async getAllUsers(req, res, next) {
        try {
            const result = await userService.getAllUsersAdmin();
            res.json(result);
        } catch (err) { next(err); }
    }

    async getAllUserEmails(req, res, next) {
        try {
            const result = await userService.getAllUserEmails();
            res.send(result.text);
        } catch (err) { next(err); }
    }
}

module.exports = new UserController();
