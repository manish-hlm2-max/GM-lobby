import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'secret_chess_key_12345';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: 'USER' | 'MODERATOR' | 'SUPER_ADMIN';
  };
}

export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction): void => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ success: false, error: 'Unauthorized. No token provided.' });
      return;
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET) as {
      id: string;
      email: string;
      role: 'USER' | 'MODERATOR' | 'SUPER_ADMIN';
    };

    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ success: false, error: 'Unauthorized. Invalid token.' });
  }
};

export const adminMiddleware = (req: AuthRequest, res: Response, next: NextFunction): void => {
  if (!req.user || (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'MODERATOR')) {
    res.status(403).json({ success: false, error: 'Forbidden. Admin privileges required.' });
    return;
  }
  next();
};
