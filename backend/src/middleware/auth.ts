import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config.js';
import { query } from '../db.js';
import { hasPersistedRoleAccess } from './role_access.js';

export interface AuthUser {
  id: string;
  email: string;
  role: string;
  verified: boolean;
}

declare global {
  namespace Express {
    interface Request {
      auth?: AuthUser;
    }
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, env.jwtSecret) as AuthUser;
    req.auth = payload;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
}

export function authorize(...allowedRoles: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const authUser = req.auth;
    if (!authUser) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    const normalizedAllowedRoles = allowedRoles.map((role) => role.toLowerCase());
    const tokenRole = authUser.role?.toLowerCase() ?? '';
    const isAdminAlias = tokenRole === 'admin' || tokenRole === 'super_admin' || tokenRole === 'administrator';
    if (normalizedAllowedRoles.length === 0 ||
        (normalizedAllowedRoles.includes('admin') && isAdminAlias)) {
      return next();
    }

    try {
      const userResult = await query(
        'SELECT role, roles, landlord_verified FROM users WHERE id = $1 LIMIT 1',
        [authUser.id],
      );
      const user = userResult.rows[0] as
        | { role?: string; roles?: string[]; landlord_verified?: boolean }
        | undefined;
      if (!user) return res.status(401).json({ error: 'Account not found.' });

      const isAllowed = hasPersistedRoleAccess(user, normalizedAllowedRoles);

      if (!isAllowed) {
        return res.status(403).json({ error: 'Insufficient permissions.' });
      }
      return next();
    } catch (error) {
      return next(error);
    }
  };
}
