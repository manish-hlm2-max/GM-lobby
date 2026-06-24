import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import 'match_replay_screen.dart';

class MatchResultDetailsScreen extends ConsumerWidget {
  final MatchModel match;
  
  const MatchResultDetailsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).user?.id;
    final isWhite = match.whitePlayerId == currentUserId;
    final isDraw = match.result == 'DRAW';
    
    bool isWinner = false;
    if (!isDraw) {
      if (match.result == 'WHITE_WIN' && isWhite) isWinner = true;
      if (match.result == 'BLACK_WIN' && !isWhite) isWinner = true;
    }

    String titleText;
    Color statusColor;
    IconData statusIcon;
    List<Color> gradientColors;

    if (isDraw) {
      titleText = 'DRAW';
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.handshake_rounded;
      gradientColors = [const Color(0xFF2C3E50), const Color(0xFF3498DB)];
    } else if (isWinner) {
      titleText = 'VICTORY';
      statusColor = const Color(0xFF4ADE80);
      statusIcon = Icons.emoji_events_rounded;
      gradientColors = [const Color(0xFF134E5E), const Color(0xFF71B280)];
    } else {
      titleText = 'DEFEAT';
      statusColor = Colors.redAccent;
      statusIcon = Icons.trending_down_rounded;
      gradientColors = [const Color(0xFF430000), const Color(0xFF9E1010)];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Hero Status
                Icon(statusIcon, size: 80, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  titleText,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Players & Elo card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Player vs Player
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildPlayerColumn(
                                match.whiteUsername ?? 'White',
                                match.whiteTitle,
                                match.whiteElo,
                                match.whiteEloChange,
                                true,
                              ),
                              Text(
                                'VS',
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildPlayerColumn(
                                match.blackUsername ?? 'Black',
                                match.blackTitle,
                                match.blackElo,
                                match.blackEloChange,
                                false,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 24),
                          
                          // Advanced Stats
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Match Details',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildStatRow(
                            'Date',
                            match.createdAt != null 
                                ? DateFormat('MMM d, yyyy, HH:mm').format(DateTime.parse(match.createdAt!).toLocal())
                                : 'Unknown',
                            Icons.calendar_today_rounded,
                          ),
                          _buildStatRow(
                            'Time Control',
                            '${match.timeControl ~/ 60} min',
                            Icons.timer_rounded,
                          ),
                          _buildStatRow(
                            'Total Moves',
                            '${match.moveHistory.length}',
                            Icons.grid_3x3_rounded,
                          ),
                          if (match.entryFee > 0)
                            _buildStatRow(
                              'Entry Fee',
                              '₹${match.entryFee.toStringAsFixed(0)}',
                              Icons.monetization_on_rounded,
                            ),
                          if (match.prizePool > 0)
                            _buildStatRow(
                              'Prize Pool',
                              '₹${match.prizePool.toStringAsFixed(0)}',
                              Icons.emoji_events_rounded,
                            ),

                          const SizedBox(height: 40),
                          
                          // Action Buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: statusColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: statusColor.withOpacity(0.5),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MatchReplayScreen(match: match),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_circle_fill_rounded),
                              label: Text(
                                'Watch Replay',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Back',
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn(String name, String? title, int? elo, int? eloChange, bool isWhite) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isWhite ? Colors.white : const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: Border.all(
              color: isWhite ? Colors.grey[300]! : Colors.grey[800]!,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.person,
              size: 40,
              color: isWhite ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty) ...[
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              name,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${elo ?? '?'}',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
            if (eloChange != null) ...[
              const SizedBox(width: 4),
              Text(
                eloChange >= 0 ? '(+$eloChange)' : '($eloChange)',
                style: GoogleFonts.inter(
                  color: eloChange >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
