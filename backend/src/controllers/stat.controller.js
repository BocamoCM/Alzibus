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
        try {
            res.json(await statService.logAppOpen(ip, email, req.get('User-Agent'), req.body || {}));
        } catch (e) { next(e); }
    }
    async getTelemetry(req, res, next) {
        try { res.json(await statService.getTelemetry(req.query.period)); } catch (e) { next(e); }
    }
    async getRetention(req, res, next) {
        try { res.json(await statService.getRetention()); } catch (e) { next(e); }
    }
    async getHeatmap(req, res, next) {
        try { res.json(await statService.getTripHeatmap(req.query.period)); } catch (e) { next(e); }
    }
    async getPayments(req, res, next) {
        try { res.json(await statService.getPaymentSplit(req.query.period)); } catch (e) { next(e); }
    }
    async getRoutes(req, res, next) {
        try { res.json(await statService.getRoutes(req.query.period)); } catch (e) { next(e); }
    }
    async getPremium(req, res, next) {
        try { res.json(await statService.getPremiumStats()); } catch (e) { next(e); }
    }
    async getGame(req, res, next) {
        try { res.json(await statService.getGameStats()); } catch (e) { next(e); }
    }
    async getLiveShare(req, res, next) {
        try { res.json(await statService.getLiveShareStats(req.query.period)); } catch (e) { next(e); }
    }
    async getSupport(req, res, next) {
        try { res.json(await statService.getSupportStats(req.query.period)); } catch (e) { next(e); }
    }
    async getWebApp(req, res, next) {
        try { res.json(await statService.getWebAppStats(req.query.period)); } catch (e) { next(e); }
    }
    async postContact(req, res, next) {
        try { res.json(await statService.postContact(req.ip, req.body)); } catch (e) { next(e); }
    }
}

module.exports = new StatController();
