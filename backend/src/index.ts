import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import dns from 'dns';
import path from 'path';
import fs from 'fs';
dns.setDefaultResultOrder('ipv4first');
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

// Serve static files from 'public' directory
app.use('/public', express.static(path.join(__dirname, '../public')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/match', matchRoutes);
app.use('/api/tournament', tournamentRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'Chess betting backend is healthy.' });
});

// App version check endpoint for OTA updates
app.get('/api/app-version', (req, res) => {
  const protocol = req.secure || req.headers['x-forwarded-proto'] === 'https' ? 'https' : 'http';
  const host = req.get('host');
  const versionFilePath = path.join(__dirname, '../public/version.json');
  
  let versionData = {
    versionCode: 3,
    versionName: "1.0.0",
    isMandatory: true
  };

  try {
    if (fs.existsSync(versionFilePath)) {
      const content = fs.readFileSync(versionFilePath, 'utf8');
      versionData = JSON.parse(content);
    }
  } catch (err) {
    console.error('Failed to read version.json, using defaults:', err);
  }

  res.status(200).json({
    success: true,
    versionCode: versionData.versionCode,
    versionName: versionData.versionName,
    apkUrl: `${protocol}://${host}/public/app-release.apk`,
    isMandatory: versionData.isMandatory
  });
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
