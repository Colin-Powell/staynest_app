import { Request, Response, NextFunction } from 'express';

export function errorHandler(
  error: Error,
  _req: Request,
  res: Response,
  _next: NextFunction,
) {

  console.error('API error:', error);
  res.status(500).json({ error: 'Internal server error.' });
}
