import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import { connectDB } from './config/db';
import authRoutes from './routes/auth';
import walletRoutes from './routes/wallet';
import matchRoutes from './routes/match';
import tournamentRoutes from './routes/tournament';
import { setupGameSocket } from './sockets/gameSocket';

dotenv.config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/match', matchRoutes);
app.use('/api/tournament', tournamentRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'Chess betting backend is healthy.' });
});

// Database connection & Bootstrapping
const PORT = process.env.PORT || 3000;

const startServer = async () => {
  await connectDB();
  
  // Bind Socket connections
  setupGameSocket(io);

  server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
};

startServer().catch((error) => {
  console.error('Server boot failed:', error);
});
