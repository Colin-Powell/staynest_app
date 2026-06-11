import { Router } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { query } from '../db.js';
import { env } from '../config.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
// Register new user
router.post('/register', async (req, res, next) => {
    try {
        const { name, email, password, phone, role } = req.body;
        if (!name || !email || !password || !phone) {
            return res.status(400).json({ error: 'Name, email, phone and password are required.' });
        }
        const normalizedEmail = email.trim().toLowerCase();
        const normalizedPhone = phone.trim();
        const exists = await query('SELECT id FROM users WHERE email = $1 LIMIT 1', [normalizedEmail]);
        if ((exists.rowCount ?? 0) > 0) {
            return res.status(409).json({ error: 'Email already registered.' });
        }
        const hash = await bcrypt.hash(password, 10);
        const userRole = (typeof role === 'string' && ['tenant', 'landlord', 'host'].includes(role)) ? role : 'tenant';
        const result = await query(`INSERT INTO users (name, email, phone, password_hash, role)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, phone, role, verified`, [name.trim(), normalizedEmail, normalizedPhone, hash, userRole]);
        const created = result.rows[0];
        // If landlord, store business fields
        if (userRole === 'landlord') {
            const businessData = req.body.businessFields || req.body;
            const { business_name, business_type, business_description, tax_id, years_in_business } = businessData;
            if (business_name || business_type || business_description || tax_id || years_in_business) {
                await query(`UPDATE users SET business_name = $1, business_type = $2, business_description = $3, tax_id = $4, years_in_business = $5 WHERE id = $6`, [
                    business_name?.trim() || null,
                    business_type?.trim() || null,
                    business_description?.trim() || null,
                    tax_id?.trim() || null,
                    years_in_business ? Number(years_in_business) : null,
                    created.id,
                ]);
            }
        }
        const token = jwt.sign({
            id: created.id,
            email: created.email,
            role: created.role,
            verified: created.verified,
        }, env.jwtSecret, { expiresIn: '6h' });
        return res.status(201).json({ data: { token, ...created } });
    }
    catch (error) {
        next(error);
    }
});
router.post('/verify', requireAuth, async (req, res, next) => {
    try {
        const { code } = req.body;
        if (!code || code.trim() === '') {
            return res.status(400).json({ error: 'Verification code is required.' });
        }
        const normalizedCode = code.trim();
        if (normalizedCode != '624108') {
            return res.status(400).json({ error: 'Invalid verification code.' });
        }
        const result = await query(`UPDATE users
       SET verified = true
       WHERE id = $1
       RETURNING id, name, email, role, avatar, verified`, [req.auth.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        return res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
router.post('/login', async (req, res, next) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required.' });
        }
        const result = await query('SELECT id, name, email, phone, avatar, password_hash, role, verified FROM users WHERE email = $1 LIMIT 1', [email.trim().toLowerCase()]);
        const user = result.rows[0];
        if (!user || !user.password_hash) {
            return res.status(401).json({ error: 'Invalid credentials.' });
        }
        const isValid = await bcrypt.compare(password, user.password_hash);
        if (!isValid) {
            return res.status(401).json({ error: 'Invalid credentials.' });
        }
        const token = jwt.sign({
            id: user.id,
            email: user.email,
            role: user.role,
            verified: user.verified,
        }, env.jwtSecret, { expiresIn: '6h' });
        return res.json({
            data: {
                token,
                id: user.id, name: user.name, email: user.email,
                phone: user.phone, avatar: user.avatar,
                role: user.role, verified: user.verified
            } });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=auth.js.map