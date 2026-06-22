import { User } from '../models/User';
import { Wallet } from '../models/Wallet';
import bcrypt from 'bcryptjs';

const INDIAN_BOTS = [
  { username: 'Aarav_Chess', elo: 2580 },
  { username: 'Aditya_GM', elo: 2620 },
  { username: 'Vihaan_Grandmaster', elo: 2650 },
  { username: 'Arjun_Chess_GM', elo: 2540 },
  { username: 'Sai_Pranith_GM', elo: 2490 },
  { username: 'Pranav_Karthik_GM', elo: 2610 },
  { username: 'Kabir_Chess_GM', elo: 2470 },
  { username: 'Rohan_Mehta_GM', elo: 2530 },
  { username: 'Vivaan_Sharma_GM', elo: 2560 },
  { username: 'Reyansh_GM', elo: 2605 },
  { username: 'Dia_Sen_GM', elo: 2450 },
  { username: 'Ananya_Iyer_GM', elo: 2485 },
  { username: 'Ishaan_Gupta_GM', elo: 2520 },
  { username: 'Krishna_GM', elo: 2595 },
  { username: 'Shaurya_Singh_GM', elo: 2630 },
  { username: 'Atharv_Patel_GM', elo: 2505 },
  { username: 'Siddharth_GM', elo: 2570 },
  { username: 'Rudransh_Verma_GM', elo: 2465 },
  { username: 'Aarush_GM', elo: 2515 },
  { username: 'Kavya_Reddy_GM', elo: 2495 },
  { username: 'Mira_Nair_GM', elo: 2480 },
  { username: 'Zoya_Khan_GM', elo: 2525 },
  { username: 'Myra_Joshi_GM', elo: 2510 },
  { username: 'Kiara_Bhasin_GM', elo: 2460 },
  { username: 'Siya_Dave_GM', elo: 2475 },
  { username: 'Saanvi_Choudhury_GM', elo: 2545 },
  { username: 'Riya_Bose_GM', elo: 2490 },
  { username: 'Priya_GM', elo: 2500 },
  { username: 'Divya_Grandmaster', elo: 2555 },
  { username: 'Nisha_GM', elo: 2460 },
  { username: 'Aman_Verma_GM', elo: 2510 },
  { username: 'Rahul_Grandmaster', elo: 2600 },
  { username: 'Sumit_Chess_GM', elo: 2515 },
  { username: 'Amit_GM', elo: 2520 },
  { username: 'Vikram_Rathore_GM', elo: 2585 },
  { username: 'Ravi_Kumar_GM', elo: 2500 },
  { username: 'Rajesh_GM', elo: 2490 },
  { username: 'Sanjay_GM', elo: 2510 },
  { username: 'Ajay_Chess_GM', elo: 2525 },
  { username: 'Vijay_GM', elo: 2530 },
  { username: 'Karan_GM', elo: 2540 },
  { username: 'Deepak_GM', elo: 2505 },
  { username: 'Sunil_GM', elo: 2495 },
  { username: 'Anil_GM', elo: 2480 },
  { username: 'Manoj_GM', elo: 2500 },
  { username: 'Sandip_GM', elo: 2470 },
  { username: 'Rakesh_GM', elo: 2515 },
  { username: 'Yash_Grandmaster', elo: 2640 },
  { username: 'Dev_Chess_GM', elo: 2575 },
  { username: 'Harsh_GM', elo: 2550 },
];

export const seedBots = async (): Promise<void> => {
  try {
    const botsCount = await User.countDocuments({ isBot: true });
    if (botsCount >= 50) {
      console.log('50 Grandmaster bots already seeded.');
      return;
    }

    console.log(`Seeding GM bots... Current count: ${botsCount}`);
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash('bot_no_pass_login_xyz_123', salt);

    for (let i = 0; i < INDIAN_BOTS.length; i++) {
      const bot = INDIAN_BOTS[i];
      const email = `${bot.username.toLowerCase()}@chessbots.com`;

      const existingBot = await User.findOne({ username: bot.username });
      if (existingBot) {
        if (!existingBot.isBot) {
          existingBot.isBot = true;
          await existingBot.save();
        }
        continue;
      }

      const wins = Math.floor(Math.random() * 200) + 150;
      const losses = Math.floor(Math.random() * 50) + 20;
      const draws = Math.floor(Math.random() * 30) + 10;

      const newUser = new User({
        email,
        username: bot.username,
        passwordHash,
        plainPassword: 'bot_player_no_password_access',
        phoneNumber: '+919999999999',
        elo: bot.elo,
        wins,
        losses,
        draws,
        isBot: true,
        role: 'USER',
      });
      await newUser.save();

      const newWallet = new Wallet({
        userId: newUser._id,
        balance: 100000,
        lockedBalance: 0,
      });
      await newWallet.save();
    }

    console.log('Successfully seeded 50 Grandmaster bots with real Indian usernames.');
  } catch (error) {
    console.error('Error seeding bots:', error);
  }
};
