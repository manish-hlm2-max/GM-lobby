import { User } from '../models/User';
import { Wallet } from '../models/Wallet';
import bcrypt from 'bcryptjs';

const INDIAN_BOTS = [
  { username: 'Aarav_Chess', elo: 2580 },
  { username: 'Aditya', elo: 2620 },
  { username: 'Vihaan', elo: 2650 },
  { username: 'Arjun_Chess', elo: 2540 },
  { username: 'Sai_Pranith', elo: 2490 },
  { username: 'Pranav_Karthik', elo: 2610 },
  { username: 'Kabir_Chess', elo: 2470 },
  { username: 'Rohan_Mehta', elo: 2530 },
  { username: 'Vivaan_Sharma', elo: 2560 },
  { username: 'Reyansh', elo: 2605 },
  { username: 'Dia_Sen', elo: 2450 },
  { username: 'Ananya_Iyer', elo: 2485 },
  { username: 'Ishaan_Gupta', elo: 2520 },
  { username: 'Krishna', elo: 2595 },
  { username: 'Shaurya_Singh', elo: 2630 },
  { username: 'Atharv_Patel', elo: 2505 },
  { username: 'Siddharth', elo: 2570 },
  { username: 'Rudransh_Verma', elo: 2465 },
  { username: 'Aarush', elo: 2515 },
  { username: 'Kavya_Reddy', elo: 2495 },
  { username: 'Mira_Nair', elo: 2480 },
  { username: 'Zoya_Khan', elo: 2525 },
  { username: 'Myra_Joshi', elo: 2510 },
  { username: 'Kiara_Bhasin', elo: 2460 },
  { username: 'Siya_Dave', elo: 2475 },
  { username: 'Saanvi_Choudhury', elo: 2545 },
  { username: 'Riya_Bose', elo: 2490 },
  { username: 'Priya', elo: 2500 },
  { username: 'Divya', elo: 2555 },
  { username: 'Nisha', elo: 2460 },
  { username: 'Aman_Verma', elo: 2510 },
  { username: 'Rahul', elo: 2600 },
  { username: 'Sumit_Chess', elo: 2515 },
  { username: 'Amit', elo: 2520 },
  { username: 'Vikram_Rathore', elo: 2585 },
  { username: 'Ravi_Kumar', elo: 2500 },
  { username: 'Rajesh', elo: 2490 },
  { username: 'Sanjay', elo: 2510 },
  { username: 'Ajay_Chess', elo: 2525 },
  { username: 'Vijay', elo: 2530 },
  { username: 'Karan', elo: 2540 },
  { username: 'Deepak', elo: 2505 },
  { username: 'Sunil', elo: 2495 },
  { username: 'Anil', elo: 2480 },
  { username: 'Manoj', elo: 2500 },
  { username: 'Sandip', elo: 2470 },
  { username: 'Rakesh', elo: 2515 },
  { username: 'Yash', elo: 2640 },
  { username: 'Dev_Chess', elo: 2575 },
  { username: 'Harsh', elo: 2550 },
];

export const seedBots = async (): Promise<void> => {
  try {
    // 1. Rename existing bots in the database to remove GM/Grandmaster suffixes
    const bots = await User.find({ isBot: true });
    for (const bot of bots) {
      let updatedUsername = bot.username
        .replace(/_GM$/i, '')
        .replace(/_Grandmaster$/i, '')
        .replace(/Grandmaster$/i, '')
        .replace(/GM$/i, '');
      
      if (updatedUsername !== bot.username) {
        // Resolve potential duplicate username collision gracefully
        const taken = await User.findOne({ 
          username: { $regex: new RegExp(`^${updatedUsername}$`, 'i') },
          _id: { $ne: bot._id }
        });
        
        if (taken) {
          let counter = 1;
          let tempUsername = updatedUsername;
          while (await User.findOne({ 
            username: { $regex: new RegExp(`^${tempUsername}$`, 'i') },
            _id: { $ne: bot._id }
          })) {
            tempUsername = `${updatedUsername}${counter}`;
            counter++;
          }
          updatedUsername = tempUsername;
        }

        console.log(`Renaming bot: ${bot.username} -> ${updatedUsername}`);
        bot.username = updatedUsername;
        bot.email = `${updatedUsername.toLowerCase()}@chessbots.com`;
        await bot.save();
      }
    }

    const botsCount = await User.countDocuments({ isBot: true });
    if (botsCount >= 50) {
      console.log('50 bots already seeded.');
      return;
    }

    console.log(`Seeding bots... Current count: ${botsCount}`);
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

    console.log('Successfully seeded 50 bots with real Indian usernames.');
  } catch (error) {
    console.error('Error seeding bots:', error);
  }
};
