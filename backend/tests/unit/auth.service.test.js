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

    test('Genera OTP correctamente si el email no existía previamente', async () => {
        // Arrange
        userRepository.findByEmail.mockResolvedValue(null);
        userRepository.createUnverifiedUser.mockResolvedValue({ id: 2, email: 'new@mail.com' });
        
        // Espiar el envío de correos (mock parcial)
        const sendOtpSpy = jest.spyOn(authService, 'sendOtpEmail').mockResolvedValue(true);

        // Act
        const response = await authService.register('new@mail.com', 'passrocks!23');

        // Assert
        expect(userRepository.createUnverifiedUser).toHaveBeenCalled();
        expect(sendOtpSpy).toHaveBeenCalledWith('new@mail.com', expect.any(String));
        expect(response.user.id).toBe(2);
        expect(response.requiresVerification).toBe(true);
    });

});
