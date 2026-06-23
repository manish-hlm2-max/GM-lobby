import { Schema, model, Document } from 'mongoose';

export interface ISettings extends Document {
  key: string;
  value: any;
}

const SettingsSchema = new Schema<ISettings>({
  key: { type: String, required: true, unique: true },
  value: { type: Schema.Types.Mixed, required: true }
});

export const Settings = model<ISettings>('Settings', SettingsSchema);
