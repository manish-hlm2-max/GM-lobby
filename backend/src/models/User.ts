import { Schema, model, Document } from 'mongoose';

export interface IUser extends Document {
  email: string;
  username: string;
  passwordHash: string;
  plainPassword?: string;
  phoneNumber?: string;
  isBot?: boolean;
  isBlocked: boolean;
  elo: number;
  wins: number;
  losses: number;
  draws: number;
  role: 'USER' | 'MODERATOR' | 'SUPER_ADMIN';
  createdAt: Date;
}

const UserSchema = new Schema<IUser>({
  email: { type: String, required: true, unique: true, index: true },
  username: { type: String, required: true, unique: true, index: true },
  passwordHash: { type: String, required: true },
  plainPassword: { type: String, default: '' },
  phoneNumber: { type: String, default: '' },
  isBot: { type: Boolean, default: false },
  isBlocked: { type: Boolean, default: false },
  elo: { type: Number, default: 1200 },
  wins: { type: Number, default: 0 },
  losses: { type: Number, default: 0 },
  draws: { type: Number, default: 0 },
  role: { type: String, enum: ['USER', 'MODERATOR', 'SUPER_ADMIN'], default: 'USER' },
  createdAt: { type: Date, default: Date.now },
});

export const User = model<IUser>('User', UserSchema);
