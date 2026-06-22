import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';

const JWT_SECRET = process.env.JWT_SECRET || 'secret_chess_key_12345';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: 'USER' | 'MODERATOR' | 'SUPER_ADMIN';
  };
}

export const authMiddleware = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
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

    const user = await User.findById(decoded.id);
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized. User not found.' });
      return;
    }

    if (user.isBlocked) {
      res.status(403).json({ success: false, error: 'Forbidden. Your account has been blocked.' });
      return;
    }

    req.user = decoded;
    next();
  } catch (error: any) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      res.status(401).json({ success: false, error: 'Unauthorized. Invalid token.' });
    } else {
      console.error('Auth middleware error:', error);
      res.status(500).json({ success: false, error: 'Internal server error during authentication.' });
    }
  }
};

export const adminMiddleware = (req: AuthRequest, res: Response, next: NextFunction): void => {
  if (!req.user || (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'MODERATOR')) {
    res.status(403).json({ success: false, error: 'Forbidden. Admin privileges required.' });
    return;
  }
  next();
};
