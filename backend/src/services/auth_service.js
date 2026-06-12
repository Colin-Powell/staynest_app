const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { Pool } = require('pg');

// In a real production app, the pool should be shared across services.
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5,
  idleTimeoutMillis: 30000,
});

class AuthService {
  constructor() {
    this.accessTokenSecret = process.env.JWT_SECRET || 'staynest-access-secret';
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET || 'staynest-refresh-secret';
    
    this.accessTokenTTL = '15m'; // Short-lived security
    this.refreshTokenTTLDays = 30; // Long-lived session
  }

  /**
   * Generates a new Session (Access + Refresh Tokens)
   */
  async createSession(user, deviceInfo = {}) {
    const payload = {
      id: user.id,
      email: user.email,
      role: user.role,
      verified: user.verified
    };

    const accessToken = jwt.sign(payload, this.accessTokenSecret, { expiresIn: this.accessTokenTTL });
    const refreshToken = jwt.sign({ id: user.id }, this.refreshTokenSecret, { expiresIn: `${this.refreshTokenTTLDays}d` });

    const tokenHash = this._hashToken(refreshToken);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + this.refreshTokenTTLDays);

    // Store hashed refresh token in DB
    await pool.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, device_info, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [user.id, tokenHash, JSON.stringify(deviceInfo), expiresAt]
    );

    return { accessToken, refreshToken };
  }

  /**
   * Handles Token Rotation: Validates old refresh token, revokes it, and issues a new pair.
   */
  async refreshSession(oldRefreshToken, deviceInfo = {}) {
    try {
      // 1. Verify JWT signature
      const decoded = jwt.verify(oldRefreshToken, this.refreshTokenSecret);
      const oldHash = this._hashToken(oldRefreshToken);

      // 2. Check DB for active token
      const result = await pool.query(
        `SELECT * FROM refresh_tokens 
         WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > NOW()`,
        [oldHash]
      );

      if (result.rows.length === 0) {
        throw new Error('Invalid session or token revoked');
      }

      const record = result.rows[0];

      // 3. Rotation: Revoke current token immediately
      await pool.query('UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1', [record.id]);

      // 4. Issue new tokens for the user
      const userRes = await pool.query('SELECT id, email, role, verified FROM users WHERE id = $1', [record.user_id]);
      if (userRes.rows.length === 0) throw new Error('User not found');

      return await this.createSession(userRes.rows[0], deviceInfo);
    } catch (err) {
      console.error('[AuthService] Refresh failed:', err.message);
      return null;
    }
  }

  /**
   * Clean logout by revoking the specific session
   */
  async logout(refreshToken) {
    const hash = this._hashToken(refreshToken);
    await pool.query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1',
      [hash]
    );
  }

  /**
   * Security: Never store raw refresh tokens in the database.
   */
  _hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
  }
}

module.exports = new AuthService();