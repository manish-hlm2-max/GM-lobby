import { Schema, model, Document, Types } from 'mongoose';

export type MatchStatus = 'WAITING' | 'RUNNING' | 'COMPLETED' | 'ABORTED';
export type MatchResult = 'WHITE_WIN' | 'BLACK_WIN' | 'DRAW';

export interface IMatch extends Document {
  whitePlayerId?: Types.ObjectId;
  blackPlayerId?: Types.ObjectId;
  whiteUsername?: string;
  blackUsername?: string;
  entryFee: number;
  prizePool: number;
  timeControl: number; // in seconds (e.g. 600 for 10 minutes)
  status: MatchStatus;
  boardFen: string;    // authoritative board position
  moveHistory: Array<{
    from: string;
    to: string;
    promotion?: string;
    san: string;
    createdAt: Date;
  }>;
  result?: MatchResult;
  winnerId?: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const MatchSchema = new Schema<IMatch>({
  whitePlayerId: { type: Schema.Types.ObjectId, ref: 'User' },
  blackPlayerId: { type: Schema.Types.ObjectId, ref: 'User' },
  whiteUsername: { type: String },
  blackUsername: { type: String },
  entryFee: { type: Number, default: 0 },
  prizePool: { type: Number, default: 0 },
  timeControl: { type: Number, required: true }, // e.g. 300, 600
  status: { type: String, enum: ['WAITING', 'RUNNING', 'COMPLETED', 'ABORTED'], default: 'WAITING' },
  boardFen: { type: String, default: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' },
  moveHistory: [
    {
      from: { type: String, required: true },
      to: { type: String, required: true },
      promotion: { type: String },
      san: { type: String, required: true },
      createdAt: { type: Date, default: Date.now }
    }
  ],
  result: { type: String, enum: ['WHITE_WIN', 'BLACK_WIN', 'DRAW'] },
  winnerId: { type: Schema.Types.ObjectId, ref: 'User' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

MatchSchema.pre<IMatch>('save', function (this: IMatch, next: any) {
  this.updatedAt = new Date();
  next();
});

export const Match = model<IMatch>('Match', MatchSchema);
