const statService = require('../services/stat.service');

class StatController {
    async getGeneralStats(req, res, next) {
        try { res.json(await statService.getGeneralStats()); } catch (e) { next(e); }
    }
    async getUsageStats(req, res, next) {
        try { res.json(await statService.getUsageStats(req.query.period)); } catch (e) { next(e); }
    }
    async getActivityStats(req, res, next) {
        try { res.json(await statService.getActivityStats()); } catch (e) { next(e); }
    }
    async getTopStops(req, res, next) {
        try { res.json(await statService.getTopStops()); } catch (e) { next(e); }
    }
    async getPeakHours(req, res, next) {
        try { res.json(await statService.getPeakHours()); } catch (e) { next(e); }
    }
    async getDashboard(req, res, next) {
        try { res.json(await statService.getDashboard(req.query.period)); } catch (e) { next(e); }
    }
    async getPublicStats(req, res, next) {
        try { res.json(await statService.getPublicStats()); } catch (e) { next(e); }
    }
    async logAlert(req, res, next) {
        try { res.json(await statService.logAlert(req.body)); } catch (e) { next(e); }
    }
    async logWebMetric(req, res, next) {
        try { res.json(await statService.logWebMetric(req.ip, req.get('User-Agent'), req.body)); } catch (e) { next(e); }
    }
    async logInstall(req, res, next) {
        const ip = req.ip || req.headers['x-forwarded-for'];
        try { res.json(await statService.logInstall(ip, req.body.referrer)); } catch (e) { next(e); }
    }
    async logAppOpen(req, res, next) {
        const ip = req.ip || req.headers['x-forwarded-for'];
        const email = (req.user && req.user.email) ? req.user.email : 'Visitante Anónimo';
        try { res.json(await statService.logAppOpen(ip, email)); } catch (e) { next(e); }
    }
    async postContact(req, res, next) {
        try { res.json(await statService.postContact(req.ip, req.body)); } catch (e) { next(e); }
    }
}

module.exports = new StatController();
