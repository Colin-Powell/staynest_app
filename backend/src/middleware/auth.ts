import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config.js';

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
  return (req: Request, res: Response, next: NextFunction) => {
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
