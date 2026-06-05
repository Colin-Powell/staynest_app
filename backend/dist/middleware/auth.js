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
        if (allowedRoles.length > 0 && !allowedRoles.includes(authUser.role)) {
            return res.status(403).json({ error: 'Insufficient permissions.' });
        }
        next();
    };
}
//# sourceMappingURL=auth.js.map