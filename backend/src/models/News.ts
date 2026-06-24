import { Schema, model, Document } from 'mongoose';

export interface INews extends Document {
  title: string;
  content: string;
  imageUrl?: string;
  createdAt: Date;
}

const NewsSchema = new Schema<INews>({
  title: { type: String, required: true },
  content: { type: String, required: true },
  imageUrl: { type: String, required: false },
  createdAt: { type: Date, default: Date.now }
});

export const News = model<INews>('News', NewsSchema);
