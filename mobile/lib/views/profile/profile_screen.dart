import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final wins = user?.wins ?? 0;
    final losses = user?.losses ?? 0;
    final draws = user?.draws ?? 0;
    final totalGames = wins + losses + draws;
    final winrate = totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // User Avatar Card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.teal[400],
                    child: Text(
                      user?.username.substring(0, 1).toUpperCase() ?? 'U',
                      style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.username ?? 'Grandmaster',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user?.email ?? 'player@chess.com',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // User stats box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance stats',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('Matches', '$totalGames'),
                      _statItem('Wins', '$wins', color: Colors.green[400]),
                      _statItem('Losses', '$losses', color: Colors.red[400]),
                      _statItem('Winrate', '$winrate%', color: Colors.teal[300]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Log Out Button
            ElevatedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text('Log Out', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}
