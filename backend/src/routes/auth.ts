import { Router, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { Wallet } from '../models/Wallet';
import { authMiddleware, AuthRequest } from '../middleware/authMiddleware';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'secret_chess_key_12345';

// Register User
router.post('/register', async (req, res: Response): Promise<void> => {
  try {
    const { email, username, password } = req.body;

    if (!email || !username || !password) {
      res.status(400).json({ success: false, error: 'Email, username, and password are required.' });
      return;
    }

    // Check if email or username exists
    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      res.status(400).json({ success: false, error: 'User with this email or username already exists.' });
      return;
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Create user
    const newUser = new User({
      email,
      username,
      passwordHash,
    });
    await newUser.save();

    // Create user wallet
    const newWallet = new Wallet({
      userId: newUser._id,
      balance: 0,
      lockedBalance: 0,
    });
    await newWallet.save();

    // Generate JWT
    const token = jwt.sign(
      { id: newUser._id, email: newUser.email, role: newUser.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      token,
      user: {
        id: newUser._id,
        email: newUser.email,
        username: newUser.username,
        elo: newUser.elo,
        role: newUser.role,
      },
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ success: false, error: 'Server error during registration.' });
  }
});

// Login User
router.post('/login', async (req, res: Response): Promise<void> => {
  try {
    const { emailOrUsername, password } = req.body;

    if (!emailOrUsername || !password) {
      res.status(400).json({ success: false, error: 'Email/username and password are required.' });
      return;
    }

    // Find user
    const user = await User.findOne({
      $or: [{ email: emailOrUsername }, { username: emailOrUsername }],
    });

    if (!user) {
      res.status(400).json({ success: false, error: 'Invalid credentials.' });
      return;
    }

    // Verify password
    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      res.status(400).json({ success: false, error: 'Invalid credentials.' });
      return;
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user._id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(200).json({
      success: true,
      token,
      user: {
        id: user._id,
        email: user.email,
        username: user.username,
        elo: user.elo,
        role: user.role,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, error: 'Server error during login.' });
  }
});

// Get Current User Profile & Wallet Details
router.get('/me', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(400).json({ success: false, error: 'Authentication required.' });
      return;
    }

    const user = await User.findById(req.user.id).select('-passwordHash');
    if (!user) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    const wallet = await Wallet.findOne({ userId: user._id });

    res.status(200).json({
      success: true,
      user: {
        id: user._id,
        email: user.email,
        username: user.username,
        elo: user.elo,
        wins: user.wins,
        losses: user.losses,
        draws: user.draws,
        role: user.role,
      },
      wallet: wallet
        ? {
            balance: wallet.balance,
            lockedBalance: wallet.lockedBalance,
          }
        : { balance: 0, lockedBalance: 0 },
    });
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching profile.' });
  }
});

export default router;
