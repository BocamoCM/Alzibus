const bcrypt = require('bcrypt');
const userRepository = require('../repositories/user.repository');
const { sendDiscordNotification } = require('../../utils/discord');
const { NotFoundError, BadRequestError, UnauthorizedError } = require('../utils/errors');

class UserService {
    async heartbeat(userId) {
        await userRepository.updateLastAccess(userId);
        return { message: 'Heartbeat recibido' };
    }

    async logout(userEmail) {
        sendDiscordNotification({
            embeds: [{
                title: '🔴 Usuario Desconectado',
                description: `**${userEmail}** ha cerrado sesión`,
                color: 0xE53935
            }]
        });
        return { message: 'Logout registrado' };
    }

    async getActiveUsers() {
        const users = await userRepository.getActiveUsers(5); // last 5 minutes
        return { count: users.length, users };
    }

    async getProfileStats(userId) {
        const user = await userRepository.findById(userId);
        if (!user) throw new NotFoundError('Usuario no encontrado');

        const totalTrips = await userRepository.getTotalTrips(userId);
        const mostUsedLine = await userRepository.getMostUsedLine(userId);
        const thisMonthTrips = await userRepository.getThisMonthTrips(userId);

        return {
            id: user.id,
            email: user.email,
            createdAt: user.created_at,
            lastAccess: user.last_access,
            isPremium: user.is_premium,
            stats: {
                totalTrips: parseInt(totalTrips),
                mostUsedLine: mostUsedLine || null,
                thisMonthTrips: parseInt(thisMonthTrips),
            }
        };
    }

    async getRanking(userId, period) {
        const top20 = await userRepository.getTopRanking(period);
        const myRank = await userRepository.getUserRanking(userId, period);

        const maskEmail = (email) => {
            const [local, domain] = email.split('@');
            const visible = local.substring(0, Math.min(2, local.length));
            return `${visible}***@${domain}`;
        };

        const ranking = top20.map(r => ({
            position: parseInt(r.position),
            name: r.id === userId ? maskEmail(r.email) + ' (tú)' : maskEmail(r.email),
            trips: r.trips,
            isMe: r.id === userId,
        }));

        return {
            ranking,
            myPosition: myRank ? parseInt(myRank.position) : null,
            myTrips: myRank ? parseInt(myRank.trips) : 0,
            period,
        };
    }

    async updateEmail(userId, currentEmail, newEmail) {
        if (!newEmail) throw new BadRequestError('Email requerido');
        
        const exists = await userRepository.findByEmailExcludeId(newEmail, userId);
        if (exists) throw new BadRequestError('El email ya está en uso');

        await userRepository.updateEmail(userId, newEmail);
        sendDiscordNotification(`📧 **Usuario**: \`${currentEmail}\` ha cambiado su email a \`${newEmail}\``);
        return { message: 'Email actualizado' };
    }

    async updatePassword(userId, currentEmail, currentPassword, newPassword) {
        if (!currentPassword || !newPassword) throw new BadRequestError('Contraseñas requeridas');
        if (newPassword.length < 6) throw new BadRequestError('La contraseña debe tener al menos 6 caracteres');

        const user = await userRepository.findByIdWithPassword(userId);
        if (!user) throw new NotFoundError('Usuario no encontrado');

        const valid = await bcrypt.compare(currentPassword, user.password_hash);
        if (!valid) throw new UnauthorizedError('Contraseña actual incorrecta');

        const newHash = await bcrypt.hash(newPassword, 10);
        await userRepository.updatePassword(userId, newHash);
        
        sendDiscordNotification(`🔐 **Usuario**: \`${currentEmail}\` ha cambiado su contraseña.`);
        return { message: 'Contraseña actualizada' };
    }

    async deleteAccount(userId, email) {
        await userRepository.deleteUserTrips(userId);
        await userRepository.deleteUser(userId);
        
        console.log(`[GDPR] Usuario eliminado: ${email} (ID: ${userId})`);
        sendDiscordNotification(`🗑️ **Cuenta eliminada**: El usuario \`${email}\` ha solicitado el borrado permanente de sus datos.`);
        
        return { message: 'Tu cuenta y todos tus datos han sido eliminados correctamente.' };
    }

    async getAllUsersAdmin() {
        const users = await userRepository.getAllUsersOverview();
        return users;
    }

    async getAllUserEmails() {
        const emails = await userRepository.getAllUserEmails();
        return { text: emails.join(', ') };
    }
}

module.exports = new UserService();
