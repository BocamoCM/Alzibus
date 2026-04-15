const authService = require('../services/auth.service');

class AuthController {
    
    // Express handler for POST /api/register
    async register(req, res, next) {
        try {
            const { email, password } = req.body;
            // Calls the core domain logic
            const result = await authService.register(email, password);
            
            // Controller's sole job: shape the HTTP response
            res.status(201).json({
                message: 'Usuario registrado. Por favor verifica tu email.',
                user: result.user,
                requiresVerification: result.requiresVerification
            });
        } catch (error) {
            // Unhandled or domain errors go to the Global Error Handler middleware
            next(error); 
        }
    }

    // Express handler for POST /api/verify-email
    async verifyEmail(req, res, next) {
        try {
            const { email, code } = req.body;
            const result = await authService.verifyEmail(email, code);
            
            res.json(result);
        } catch (error) {
            next(error);
        }
    }

    // Login and other handlers omitted for this first iteration...
}

module.exports = new AuthController();
