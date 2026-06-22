import mongoose from 'mongoose';

// Permanently disable transactions globally to support standalone/cloud MongoDB environments.
// Atomic operations (such as findOneAndUpdate) are used instead to maintain database consistency and thread safety.
export const isTransactionSupported = false;

export const connectDB = async (): Promise<void> => {
  try {
    const mongoURI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/chess_betting';
    await mongoose.connect(mongoURI);
    console.log('MongoDB connection established successfully.');
    console.log('Database transactions are disabled globally. Using native atomic updates.');
  } catch (error) {
    console.error('Error connecting to MongoDB:', error);
    process.exit(1);
  }
};
