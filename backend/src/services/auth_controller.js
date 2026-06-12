const authService = require('../services/auth_service');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

// In a centralized app, this pool should be imported from a db configuration file
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

class AuthController {
  async login(req, res) {
    const { email, password } = req.body;
    const deviceInfo = { userAgent: req.headers['user-agent'], ip: req.ip };

    try {
      // Retrieve user and their stored password hash
      const userResult = await pool.query('SELECT id, email, role, verified, password_hash FROM users WHERE email = $1', [email]);
      const user = userResult.rows[0];

      if (!user || !(await bcrypt.compare(password, user.password_hash))) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      // Generate Access and Refresh tokens
      const session = await authService.createSession(user, deviceInfo);
      return res.status(200).json(session);
    } catch (error) {
      return res.status(500).json({ error: 'An error occurred during login' });
    }
  }

  async refresh(req, res) {
    const { refreshToken } = req.body;
    const deviceInfo = { userAgent: req.headers['user-agent'], ip: req.ip };

    if (!refreshToken) return res.status(400).json({ error: 'Refresh token is required' });

    try {
      const newSession = await authService.refreshSession(refreshToken, deviceInfo);
      if (!newSession) {
        return res.status(401).json({ error: 'Session expired or invalid token' });
      }
      return res.status(200).json(newSession);
    } catch (error) {
      return res.status(500).json({ error: 'An error occurred during token refresh' });
    }
  }

  async logout(req, res) {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Refresh token is required' });

    try {
      await authService.logout(refreshToken);
      return res.status(204).send();
    } catch (error) {
      return res.status(500).json({ error: 'An error occurred during logout' });
    }
  }
}

module.exports = new AuthController();