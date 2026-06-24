import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/match_model.dart';
import '../../services/match_service.dart';
import '../../providers/auth_provider.dart';
import 'match_result_details_screen.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  final MatchService _matchService = MatchService();
  List<MatchModel>? _matches;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final history = await _matchService.getMatchHistory();
      setState(() {
        _matches = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load match history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          'Match Results',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.tealAccent),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _matches == null || _matches!.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: Colors.tealAccent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _matches!.length,
                    itemBuilder: (context, index) {
                      final match = _matches![index];
                      return _buildMatchCard(match, currentUserId);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            'No completed matches yet',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Play a 1vs1 match to view your match results here.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchModel match, String? currentUserId) {
    final isWhite = match.whitePlayerId == currentUserId;
    final opponentName = isWhite ? (match.blackUsername ?? 'Bot') : (match.whiteUsername ?? 'Bot');
    final opponentTitle = isWhite ? match.blackTitle : match.whiteTitle;
    
    // Determine winner details
    bool isWinner = false;
    bool isDraw = match.result == 'DRAW';
    if (!isDraw) {
      if (match.result == 'WHITE_WIN' && isWhite) isWinner = true;
      if (match.result == 'BLACK_WIN' && !isWhite) isWinner = true;
    }

    final entryFee = match.entryFee;
    final timeControlMinutes = match.timeControl ~/ 60;

    final moveCount = match.moveHistory.length;

    Color badgeColor;
    String badgeText;
    if (isDraw) {
      badgeColor = Colors.white24;
      badgeText = 'DRAW';
    } else if (isWinner) {
      badgeColor = Colors.green[400]!;
      badgeText = 'WON';
    } else {
      badgeColor = Colors.red[400]!;
      badgeText = 'LOST';
    }

    final eloChange = isWhite ? match.whiteEloChange : match.blackEloChange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchResultDetailsScreen(match: match),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon or status badge
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withOpacity(0.2), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (eloChange != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          eloChange > 0 ? '+$eloChange' : '$eloChange',
                          style: GoogleFonts.outfit(
                            color: eloChange > 0
                                ? const Color(0xFF4ADE80)
                                : (eloChange < 0 ? const Color(0xFFF87171) : Colors.white38),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Match details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'vs '),
                            if (opponentTitle != null && opponentTitle.isNotEmpty)
                              TextSpan(
                                text: '$opponentTitle ',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            TextSpan(
                              text: opponentName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            '${timeControlMinutes}m',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.grid_3x3_rounded, size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            '$moveCount moves',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Stake & Navigate Icon
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entryFee > 0 ? '₹${entryFee.toStringAsFixed(0)}' : 'Free',
                      style: GoogleFonts.outfit(
                        color: entryFee > 0 ? Colors.tealAccent : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
