import { Schema, model, Document, Types } from 'mongoose';

export type TournamentStatus = 'UPCOMING' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED';

export interface ITournament extends Document {
  name: string;
  entryFee: number;
  totalPrize: number;
  status: TournamentStatus;
  scheduledStartTime: Date;
  roundCount: number;
  currentRound: number;
  participants: Array<{
    userId: Types.ObjectId;
    username: string;
    score: number;
    status: 'ACTIVE' | 'ELIMINATED';
  }>;
  brackets: Array<{
    round: number;
    matchId: Types.ObjectId;
    playerA: Types.ObjectId;
    playerB: Types.ObjectId;
    winner?: Types.ObjectId;
  }>;
  createdAt: Date;
}

const TournamentSchema = new Schema<ITournament>({
  name: { type: String, required: true },
  entryFee: { type: Number, default: 0 },
  totalPrize: { type: Number, default: 0 },
  status: { type: String, enum: ['UPCOMING', 'ACTIVE', 'COMPLETED', 'CANCELLED'], default: 'UPCOMING' },
  scheduledStartTime: { type: Date, required: true },
  roundCount: { type: Number, default: 3 },
  currentRound: { type: Number, default: 0 },
  participants: [
    {
      userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
      username: { type: String, required: true },
      score: { type: Number, default: 0 },
      status: { type: String, enum: ['ACTIVE', 'ELIMINATED'], default: 'ACTIVE' }
    }
  ],
  brackets: [
    {
      round: { type: Number, required: true },
      matchId: { type: Schema.Types.ObjectId, ref: 'Match' },
      playerA: { type: Schema.Types.ObjectId, ref: 'User' },
      playerB: { type: Schema.Types.ObjectId, ref: 'User' },
      winner: { type: Schema.Types.ObjectId, ref: 'User' }
    }
  ],
  createdAt: { type: Date, default: Date.now },
});

export const Tournament = model<ITournament>('Tournament', TournamentSchema);
