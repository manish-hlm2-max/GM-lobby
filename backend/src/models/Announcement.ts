import { Schema, model, Document } from 'mongoose';

export interface IAnnouncement extends Document {
  title: string;
  content: string;
  createdAt: Date;
}

const AnnouncementSchema = new Schema<IAnnouncement>({
  title: { type: String, required: true },
  content: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

export const Announcement = model<IAnnouncement>('Announcement', AnnouncementSchema);
