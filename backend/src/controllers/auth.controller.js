const authService = require('../services/auth.service');

class AuthController {
    
    async register(req, res, next) {
        try {
            const { email, password } = req.body;
            const result = await authService.register(email, password);
            
            res.status(201).json({
                message: 'Usuario registrado. Por favor verifica tu email.',
                user: result.user,
                requiresVerification: result.requiresVerification
            });
        } catch (error) {
            next(error); 
        }
    }

    async verifyEmail(req, res, next) {
        try {
            const { email, code } = req.body;
            const result = await authService.verifyEmail(email, code);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    async login(req, res, next) {
        try {
            const { email, password, biometric } = req.body;
            const ipAddress = req.ip || req.headers['x-forwarded-for'];
            
            const result = await authService.login(email, password, biometric, ipAddress);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    async verifyLogin(req, res, next) {
        try {
            const { email, code } = req.body;
            const ipAddress = req.ip || req.headers['x-forwarded-for'];
            
            const result = await authService.verifyLogin(email, code, ipAddress);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    async resendOtp(req, res, next) {
        try {
            const { email } = req.body;
            const result = await authService.resendOtp(email);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    async forgotPassword(req, res, next) {
        try {
            const { email } = req.body;
            const result = await authService.forgotPassword(email);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    async resetPassword(req, res, next) {
        try {
            const { email, code, newPassword } = req.body;
            const result = await authService.resetPassword(email, code, newPassword);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    async adminLogin(req, res, next) {
        try {
            const { password } = req.body;
            const ipAddress = req.ip || req.headers['x-forwarded-for'];
            const result = await authService.adminLogin(password, ipAddress);
            res.json(result);
        } catch (error) {
            next(error);
        }
    }
}

module.exports = new AuthController();
