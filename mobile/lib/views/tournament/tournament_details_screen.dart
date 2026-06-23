import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/tournament_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../providers/game_provider.dart';
import '../../services/match_service.dart';
import '../game/game_screen.dart';
import 'tournament_screen.dart';

class TournamentDetailsScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentDetailsScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends ConsumerState<TournamentDetailsScreen> {
  bool _isLaunchingMatch = false;

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(lobbyProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    // Find the tournament in the lobby list
    final TournamentModel? tourn = lobbyState.tournaments.cast<TournamentModel?>().firstWhere(
          (t) => t?.id == widget.tournamentId,
          orElse: () => null,
        );

    if (tourn == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030712),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    // Find user's bracket matchup for the current round
    final myBracket = tourn.brackets.firstWhere(
      (b) => b['round'] == tourn.currentRound && (b['playerA'] == currentUserId || b['playerB'] == currentUserId),
      orElse: () => null,
    );

    final hasCompletedMatch = myBracket != null && myBracket['winner'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1329),
        elevation: 0,
        title: Text(
          tourn.name,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Stats/Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: const Color(0xFF0B1329),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status: ${tourn.status}',
                        style: GoogleFonts.inter(
                          color: tourn.status == 'ACTIVE' ? Colors.green[400] : Colors.teal[300],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Round: ${tourn.currentRound} of ${tourn.roundCount}',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  if (tourn.status == 'ACTIVE' && tourn.roundStartTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        RoundCountdown(
                          roundStartTime: tourn.roundStartTime!,
                          durationSeconds: tourn.roundDurationSeconds,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Match controller section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMatchActionCard(tourn, myBracket, hasCompletedMatch),
            ),

            // Live Standings header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Live Leaderboard',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Points Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _buildPointsTable(tourn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchActionCard(TournamentModel tourn, dynamic myBracket, bool hasCompletedMatch) {
    if (tourn.status == 'COMPLETED') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Text(
              'TOURNAMENT CONCLUDED',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Thank you for playing! View the final points table below.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (tourn.status != 'ACTIVE') {
      return const SizedBox.shrink();
    }

    if (myBracket == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No match pair found for you in Round ${tourn.currentRound}. Please contact support.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (hasCompletedMatch) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 32),
            const SizedBox(height: 8),
            Text(
              'MATCH COMPLETED',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Your Round ${tourn.currentRound} match is complete. Please wait for the next round to start.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withOpacity(0.12),
            Colors.teal.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Your Round ${tourn.currentRound} Match is Ready!',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Play your match now before the round timer expires.',
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLaunchingMatch ? null : () => _launchMatch(myBracket['matchId']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLaunchingMatch
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'PLAY MATCH NOW',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMatch(String matchId) async {
    setState(() {
      _isLaunchingMatch = true;
    });

    try {
      final match = await MatchService().getMatchDetails(matchId);
      if (!mounted) return;

      setState(() {
        _isLaunchingMatch = false;
      });

      if (match != null) {
        ref.read(gameProvider.notifier).initMatch(match);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load match. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLaunchingMatch = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching game: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildPointsTable(TournamentModel tourn) {
    final participants = List<dynamic>.from(tourn.participants);
    participants.sort((a, b) {
      final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
      final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    if (participants.isEmpty) {
      return Center(
        child: Text(
          'No participants registered yet.',
          style: GoogleFonts.inter(color: Colors.white24),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 8,
            columns: [
              DataColumn(label: Text('Rank', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Player', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Played', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('W', style: GoogleFonts.inter(color: Colors.green[400], fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('D', style: GoogleFonts.inter(color: Colors.amber[400], fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('L', style: GoogleFonts.inter(color: Colors.red[400], fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Points', style: GoogleFonts.inter(color: Colors.teal[300], fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: List<DataRow>.generate(participants.length, (index) {
              final p = participants[index];
              final userId = p['userId'];
              final username = p['username'] ?? 'Player';

              int wins = 0;
              int matchesPlayed = 0;
              for (var b in tourn.brackets) {
                if (b['playerA'] == userId || b['playerB'] == userId) {
                  final round = b['round'] as int;
                  final hasWinner = b['winner'] != null;
                  if (round < tourn.currentRound || hasWinner) {
                    matchesPlayed++;
                  }
                  if (b['winner'] == userId) {
                    wins++;
                  }
                }
              }
              final score = (p['score'] as num?)?.toDouble() ?? 0.0;
              final draws = ((score - wins) * 2).round().clamp(0, 10);
              final losses = (matchesPlayed - wins - draws).clamp(0, 10);

              return DataRow(
                cells: [
                  DataCell(Text('#${index + 1}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                  DataCell(Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                  DataCell(Text('$matchesPlayed', style: const TextStyle(color: Colors.white70))),
                  DataCell(Text('$wins', style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold))),
                  DataCell(Text('$draws', style: TextStyle(color: Colors.amber[400], fontWeight: FontWeight.bold))),
                  DataCell(Text('$losses', style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold))),
                  DataCell(Text(score.toStringAsFixed(1), style: TextStyle(color: Colors.teal[300], fontWeight: FontWeight.bold))),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
