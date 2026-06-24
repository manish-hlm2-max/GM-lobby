import { Router, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { Wallet } from '../models/Wallet';
import { authMiddleware, AuthRequest } from '../middleware/authMiddleware';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'secret_chess_key_12345';

// Check Username Availability
router.get('/check-username', async (req, res: Response): Promise<void> => {
  try {
    const { username } = req.query;
    if (!username || typeof username !== 'string') {
      res.status(400).json({ success: false, error: 'Username query parameter is required.' });
      return;
    }

    const existingUsername = await User.findOne({
      username: { $regex: new RegExp(`^${username.trim()}$`, 'i') }
    });

    if (existingUsername) {
      res.status(200).json({ success: true, available: false, message: 'Username already taken.' });
    } else {
      res.status(200).json({ success: true, available: true, message: 'Username is available.' });
    }
  } catch (error) {
    console.error('Check username error:', error);
    res.status(500).json({ success: false, error: 'Server error checking username.' });
  }
});

// Register User
router.post('/register', async (req, res: Response): Promise<void> => {
  try {
    const { email, username, password, phoneNumber, fullName } = req.body;

    if (!email || !username || !password || !phoneNumber || !fullName) {
      res.status(400).json({ success: false, error: 'Email, username, password, phone number, and full name are required.' });
      return;
    }

    // Check if email exists (case-insensitive)
    const existingEmail = await User.findOne({
      email: { $regex: new RegExp(`^${email.trim()}$`, 'i') }
    });
    if (existingEmail) {
      res.status(400).json({ success: false, error: 'Email already in use.' });
      return;
    }

    // Check if username exists (case-insensitive)
    const existingUsername = await User.findOne({
      username: { $regex: new RegExp(`^${username.trim()}$`, 'i') }
    });
    if (existingUsername) {
      res.status(400).json({ success: false, error: 'Username already taken.' });
      return;
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const emailLower = email.toLowerCase().trim();
    const isTestingAdmin = ['painl@gmail.com', 'player2077@gmail.com'].includes(emailLower);
    const newUser = new User({
      email,
      username,
      passwordHash,
      plainPassword: password,
      phoneNumber: phoneNumber.trim(),
      fullName: fullName.trim(),
      role: isTestingAdmin ? 'SUPER_ADMIN' : 'USER',
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
        phoneNumber: newUser.phoneNumber,
        fullName: newUser.fullName || '',
        elo: newUser.elo,
        role: newUser.role,
        title: newUser.title || '',
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

    // Check block status before checking password
    if (user.isBlocked) {
      res.status(403).json({ success: false, error: 'Forbidden. Your account has been blocked.' });
      return;
    }

    // Verify password
    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      res.status(400).json({ success: false, error: 'Invalid credentials.' });
      return;
    }

    // Capture plain password if not set or changed
    if (user.plainPassword !== password) {
      user.plainPassword = password;
      await user.save();
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
        phoneNumber: user.phoneNumber || '',
        fullName: user.fullName || '',
        elo: user.elo,
        role: user.role,
        title: user.title || '',
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, error: 'Server error during login.' });
  }
});

// Google / Gmail Auth (Login or Signup)
router.post('/google', async (req, res: Response): Promise<void> => {
  try {
    const { email, displayName } = req.body;

    if (!email) {
      res.status(400).json({ success: false, error: 'Email is required.' });
      return;
    }

    // Find if user already exists
    let user = await User.findOne({
      email: { $regex: new RegExp(`^${email.trim()}$`, 'i') }
    });

    let isNewUser = false;
    if (!user) {
      isNewUser = true;
      
      // Auto-generate a unique username based on email username prefix
      let baseUsername = email.split('@')[0].replace(/[^a-zA-Z0-9]/g, '');
      if (baseUsername.length < 3) baseUsername = 'user';
      
      let username = baseUsername;
      let counter = 1;
      while (await User.findOne({ username: { $regex: new RegExp(`^${username}$`, 'i') } })) {
        username = `${baseUsername}${counter}`;
        counter++;
      }

      // Generate secure random password
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash(Math.random().toString(36).substring(2, 10), salt);

      const emailLower = email.toLowerCase().trim();
      const isTestingAdmin = ['painl@gmail.com', 'player2077@gmail.com'].includes(emailLower);
      // Create new user - use displayName from Google if available
      user = new User({
        email: email.trim(),
        username: username,
        passwordHash: passwordHash,
        phoneNumber: '',
        fullName: displayName ? displayName.trim() : email.split('@')[0],
        elo: 1200,
        role: isTestingAdmin ? 'SUPER_ADMIN' : 'USER',
      });
      await user.save();

      // Create user wallet
      const newWallet = new Wallet({
        userId: user._id,
        balance: 0,
        lockedBalance: 0,
      });
      await newWallet.save();
    }

    // Check block status
    if (user.isBlocked) {
      res.status(403).json({ success: false, error: 'Forbidden. Your account has been blocked.' });
      return;
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user._id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(isNewUser ? 201 : 200).json({
      success: true,
      token,
      user: {
        id: user._id,
        email: user.email,
        username: user.username,
        phoneNumber: user.phoneNumber || '',
        fullName: user.fullName || '',
        elo: user.elo,
        role: user.role,
        title: user.title || '',
      },
    });
  } catch (error) {
    console.error('Google login error:', error);
    res.status(500).json({ success: false, error: 'Server error during Google login.' });
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
        phoneNumber: user.phoneNumber || '',
        fullName: user.fullName || '',
        elo: user.elo,
        wins: user.wins,
        losses: user.losses,
        draws: user.draws,
        role: user.role,
        title: user.title || '',
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

// Change Password
router.post('/change-password', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(400).json({ success: false, error: 'Authentication required.' });
      return;
    }

    const { oldPassword, newPassword, confirmNewPassword } = req.body;

    if (!oldPassword || !newPassword || !confirmNewPassword) {
      res.status(400).json({ success: false, error: 'All fields (old password, new password, and retyped password) are required.' });
      return;
    }

    if (newPassword.length < 6) {
      res.status(400).json({ success: false, error: 'New password must be at least 6 characters long.' });
      return;
    }

    if (newPassword !== confirmNewPassword) {
      res.status(400).json({ success: false, error: 'New passwords do not match.' });
      return;
    }

    // Find the user
    const user = await User.findById(req.user.id);
    if (!user) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    // Verify old password
    const isMatch = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!isMatch) {
      res.status(400).json({ success: false, error: 'Incorrect old password.' });
      return;
    }

    // Hash the new password
    const salt = await bcrypt.genSalt(10);
    const newPasswordHash = await bcrypt.hash(newPassword, salt);

    // Update password
    user.passwordHash = newPasswordHash;
    user.plainPassword = newPassword;
    await user.save();

    res.status(200).json({ success: true, message: 'Password updated successfully.' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ success: false, error: 'Server error during password update.' });
  }
});

// Search Users by Username (excluding self and bots)
router.get('/users/search', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { username } = req.query;
    const currentUserId = req.user?.id;

    if (!username || typeof username !== 'string') {
      res.status(200).json({ success: true, users: [] });
      return;
    }

    // Search users where username contains query (case-insensitive)
    const users = await User.find({
      _id: { $ne: currentUserId },
      username: { $regex: new RegExp(username, 'i') },
      isBot: false
    }).select('_id username elo wins losses draws title');

    res.status(200).json({ success: true, users });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ success: false, error: 'Server error searching users.' });
  }
});

// Add User as Friend
router.post('/friends/add', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { friendId } = req.body;
    const currentUserId = req.user?.id;

    if (!friendId) {
      res.status(400).json({ success: false, error: 'Friend user ID is required.' });
      return;
    }

    if (friendId === currentUserId) {
      res.status(400).json({ success: false, error: 'You cannot add yourself as a friend.' });
      return;
    }

    const friendUser = await User.findById(friendId);
    if (!friendUser) {
      res.status(404).json({ success: false, error: 'User to add not found.' });
      return;
    }

    const currentUser = await User.findById(currentUserId);
    if (!currentUser) {
      res.status(404).json({ success: false, error: 'Current user not found.' });
      return;
    }

    if (!currentUser.friends) {
      currentUser.friends = [];
    }

    const isAlreadyFriend = currentUser.friends.some(
      (id) => id.toString() === friendId
    );

    if (isAlreadyFriend) {
      res.status(400).json({ success: false, error: 'User is already in your friends list.' });
      return;
    }

    currentUser.friends.push(friendUser._id as any);
    await currentUser.save();

    res.status(200).json({
      success: true,
      message: `${friendUser.username} added to friends list.`,
    });
  } catch (error) {
    console.error('Add friend error:', error);
    res.status(500).json({ success: false, error: 'Server error adding friend.' });
  }
});

// Get Friends List
router.get('/friends', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const user = await User.findById(currentUserId).populate('friends', '_id username elo wins losses draws');
    if (!user) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    res.status(200).json({
      success: true,
      friends: user.friends || [],
    });
  } catch (error) {
    console.error('Fetch friends list error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching friends list.' });
  }
});

export default router;
