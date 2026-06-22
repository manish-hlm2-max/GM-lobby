import { Schema, model, Document, Types } from 'mongoose';

export interface IWallet extends Document {
  userId: Types.ObjectId;
  balance: number;        // Available cash balance
  lockedBalance: number;  // Balances locked in active games / pending withdrawals
  updatedAt: Date;
}

const WalletSchema = new Schema<IWallet>({
  userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, unique: true, index: true },
  balance: { type: Number, required: true, default: 0, min: 0 },
  lockedBalance: { type: Number, required: true, default: 0, min: 0 },
  updatedAt: { type: Date, default: Date.now },
});

WalletSchema.pre<IWallet>('save', function (this: IWallet, next: any) {
  this.updatedAt = new Date();
  next();
});

export const Wallet = model<IWallet>('Wallet', WalletSchema);
