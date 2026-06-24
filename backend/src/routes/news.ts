import { Router, Response } from 'express';
import fs from 'fs';
import path from 'path';
import { News } from '../models/News';
import { authMiddleware, adminMiddleware, AuthRequest } from '../middleware/authMiddleware';

const router = Router();

// Get all news
router.get('/', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const newsItems = await News.find({}).sort({ createdAt: -1 });
    res.status(200).json({ success: true, news: newsItems });
  } catch (error) {
    console.error('Fetch news error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching news.' });
  }
});

// Create a news item (admin only)
router.post('/', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { title, content, imageBase64 } = req.body;

    if (!title || !content) {
      res.status(400).json({ success: false, error: 'Title and content are required.' });
      return;
    }

    let imageUrl = '';

    if (imageBase64) {
      // Decode base64 and save as file
      const matches = imageBase64.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
      let buffer: Buffer;

      if (matches && matches.length === 3) {
        buffer = Buffer.from(matches[2], 'base64');
      } else {
        buffer = Buffer.from(imageBase64, 'base64');
      }

      // Create uploads directory if it doesn't exist
      const uploadsDir = path.join(__dirname, '../../public/uploads/news');
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }

      // Write news image
      const filename = `news_${Date.now()}.png`;
      const filePath = path.join(uploadsDir, filename);
      fs.writeFileSync(filePath, buffer);

      imageUrl = `/public/uploads/news/${filename}`;
    }

    const newNews = new News({
      title,
      content,
      imageUrl: imageUrl || undefined
    });

    await newNews.save();

    res.status(201).json({ success: true, news: newNews });
  } catch (error) {
    console.error('Create news error:', error);
    res.status(500).json({ success: false, error: 'Server error creating news.' });
  }
});

// Delete a news item (admin only)
router.delete('/:id', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const newsItem = await News.findById(id);

    if (!newsItem) {
      res.status(404).json({ success: false, error: 'News item not found.' });
      return;
    }

    // Delete image file if it exists
    if (newsItem.imageUrl) {
      const filename = newsItem.imageUrl.split('/').pop();
      if (filename) {
        const filePath = path.join(__dirname, '../../public/uploads/news', filename);
        if (fs.existsSync(filePath)) {
          try {
            fs.unlinkSync(filePath);
          } catch (err) {
            console.error('Failed to delete news image:', err);
          }
        }
      }
    }

    await News.findByIdAndDelete(id);

    res.status(200).json({ success: true, message: 'News item deleted successfully.' });
  } catch (error) {
    console.error('Delete news error:', error);
    res.status(500).json({ success: false, error: 'Server error deleting news.' });
  }
});

export default router;
