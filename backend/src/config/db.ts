import mongoose from 'mongoose';

export let isTransactionSupported = true;

export const connectDB = async (): Promise<void> => {
  try {
    const mongoURI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/chess_betting';
    await mongoose.connect(mongoURI);
    console.log('MongoDB connection established successfully.');

    // Detect standalone vs replica set topology
    try {
      const adminDb = mongoose.connection.db?.admin();
      const helloResult = await adminDb?.command({ hello: 1 }).catch(() => null) || 
                          await adminDb?.command({ isMaster: 1 }).catch(() => null);
      
      const isRepl = !!(helloResult && (helloResult.setName || helloResult.setName === ''));
      isTransactionSupported = isRepl;
      
      if (isRepl) {
        console.log('MongoDB Transactions are supported (Replica Set detected).');
      } else {
        console.warn('MongoDB Transactions are NOT supported (Standalone server detected). Running database commands without transactions.');
      }
    } catch (err) {
      isTransactionSupported = false;
      console.warn('Error detecting replica set status, disabling transactions:', err);
    }
  } catch (error) {
    console.error('Error connecting to MongoDB:', error);
    process.exit(1);
  }
};
