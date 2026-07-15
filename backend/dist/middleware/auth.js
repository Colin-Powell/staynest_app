import jwt from 'jsonwebtoken';
import { env } from '../config.js';
export function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authentication required.' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const payload = jwt.verify(token, env.jwtSecret);
        req.auth = payload;
        next();
    }
    catch (error) {
        return res.status(401).json({ error: 'Invalid or expired token.' });
    }
}
export function authorize(...allowedRoles) {
    return (req, res, next) => {
        const authUser = req.auth;
        if (!authUser) {
            return res.status(401).json({ error: 'Authentication required.' });
        }
        const normalizedRole = authUser.role?.toLowerCase() ?? '';
        const normalizedAllowedRoles = allowedRoles.map((role) => role.toLowerCase());
        const isAdminAlias = normalizedRole === 'admin' || normalizedRole === 'super_admin' || normalizedRole === 'administrator';
        const isAllowed = normalizedAllowedRoles.length === 0 || normalizedAllowedRoles.includes(normalizedRole) || (normalizedAllowedRoles.includes('admin') && isAdminAlias);
        if (!isAllowed) {
            return res.status(403).json({ error: 'Insufficient permissions.' });
        }
        next();
    };
}
//# sourceMappingURL=auth.js.map