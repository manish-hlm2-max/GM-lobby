import { Router, Response } from 'express';
import { Announcement } from '../models/Announcement';
import { authMiddleware, adminMiddleware, AuthRequest } from '../middleware/authMiddleware';

const router = Router();

// Get all announcements
router.get('/', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const announcements = await Announcement.find({}).sort({ createdAt: -1 });
    res.status(200).json({ success: true, announcements });
  } catch (error) {
    console.error('Fetch announcements error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching announcements.' });
  }
});

// Create an announcement (admin only)
router.post('/', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { title, content } = req.body;

    if (!title || !content) {
      res.status(400).json({ success: false, error: 'Title and content are required.' });
      return;
    }

    const newAnnouncement = new Announcement({
      title,
      content
    });

    await newAnnouncement.save();

    res.status(201).json({ success: true, announcement: newAnnouncement });
  } catch (error) {
    console.error('Create announcement error:', error);
    res.status(500).json({ success: false, error: 'Server error creating announcement.' });
  }
});

// Delete an announcement (admin only)
router.delete('/:id', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const deleted = await Announcement.findByIdAndDelete(id);

    if (!deleted) {
      res.status(404).json({ success: false, error: 'Announcement not found.' });
      return;
    }

    res.status(200).json({ success: true, message: 'Announcement deleted successfully.' });
  } catch (error) {
    console.error('Delete announcement error:', error);
    res.status(500).json({ success: false, error: 'Server error deleting announcement.' });
  }
});

export default router;
