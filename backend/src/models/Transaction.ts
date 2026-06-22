import { Schema, model, Document, Types } from 'mongoose';

export type TransactionType = 'DEPOSIT' | 'WITHDRAWAL' | 'MATCH_ENTRY' | 'MATCH_WIN' | 'TOURNAMENT_ENTRY' | 'TOURNAMENT_PRIZE' | 'ADMIN_OVERRIDE';
export type TransactionStatus = 'PENDING' | 'SUCCESS' | 'FAILED';

export interface ITransaction extends Document {
  userId: Types.ObjectId;
  amount: number; // positive for credit, negative for debit
  type: TransactionType;
  status: TransactionStatus;
  description: string;
  referenceId?: string; // e.g. Match ID, Tournament ID, Withdrawal ref
  createdAt: Date;
}

const TransactionSchema = new Schema<ITransaction>({
  userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  amount: { type: Number, required: true },
  type: { type: String, enum: ['DEPOSIT', 'WITHDRAWAL', 'MATCH_ENTRY', 'MATCH_WIN', 'TOURNAMENT_ENTRY', 'TOURNAMENT_PRIZE', 'ADMIN_OVERRIDE'], required: true },
  status: { type: String, enum: ['PENDING', 'SUCCESS', 'FAILED'], default: 'PENDING' },
  description: { type: String, required: true },
  referenceId: { type: String },
  createdAt: { type: Date, default: Date.now },
});

export const Transaction = model<ITransaction>('Transaction', TransactionSchema);
