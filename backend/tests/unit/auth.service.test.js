const authService = require('../../src/services/auth.service');
const userRepository = require('../../src/repositories/user.repository');
const { BadRequestError } = require('../../src/utils/errors');

// Mockear el repositorio para NO tocar la base de datos real en los tests
jest.mock('../../src/repositories/user.repository');
// Mockear notificaciones para no spam en discord durante los tests
jest.mock('../../utils/discord', () => ({
    sendDiscordNotification: jest.fn()
}));

describe('AuthService - TDD Suite', () => {
    
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('El registro falla si falta el email o la contraseña', async () => {
        // Arrange & Act & Assert
        await expect(authService.register('', 'password123')).rejects.toThrow(BadRequestError);
        await expect(authService.register('user@mail.com', '')).rejects.toThrow(BadRequestError);
    });

    test('El registro falla si el usuario ya existe y ya está verificado', async () => {
        // Arrange
        userRepository.findByEmail.mockResolvedValue({ id: 1, email: 'test@mail.com', is_verified: true });

        // Act & Assert
        await expect(authService.register('test@mail.com', 'pass123')).rejects.toThrow(BadRequestError);
        expect(userRepository.findByEmail).toHaveBeenCalledWith('test@mail.com');
    });

    test('Crea cuenta sin enviar OTP en registro (verificación diferida al primer login)', async () => {
        // Arrange
        userRepository.findByEmail.mockResolvedValue(null);
        userRepository.createUnverifiedUser.mockResolvedValue({ id: 2, email: 'new@mail.com' });

        // Espiar el envío de correos — no debe llamarse en el nuevo flujo.
        const sendOtpSpy = jest.spyOn(authService, 'sendOtpEmail').mockResolvedValue(true);

        // Act
        const response = await authService.register('new@mail.com', 'passrocks!23');

        // Assert
        expect(userRepository.createUnverifiedUser).toHaveBeenCalled();
        // El registro YA NO envía OTP — la verificación se hace en el primer login.
        expect(sendOtpSpy).not.toHaveBeenCalled();
        expect(response.user.id).toBe(2);
        expect(response.requiresVerification).toBe(false);
    });

    test('Re-registrar un email no verificado actualiza la contraseña sin crear duplicado', async () => {
        // Arrange: usuario existente pero sin verificar
        userRepository.findByEmail.mockResolvedValue({ id: 7, email: 'pending@mail.com', is_verified: false });
        userRepository.updateExistingUnverifiedUser.mockResolvedValue(undefined);
        const sendOtpSpy = jest.spyOn(authService, 'sendOtpEmail').mockResolvedValue(true);

        // Act
        const response = await authService.register('pending@mail.com', 'newpass!23');

        // Assert
        expect(userRepository.updateExistingUnverifiedUser).toHaveBeenCalledWith(7, expect.any(String));
        expect(userRepository.createUnverifiedUser).not.toHaveBeenCalled();
        expect(sendOtpSpy).not.toHaveBeenCalled();
        expect(response.user.id).toBe(7);
    });

});
