import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/tournament_model.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../providers/game_provider.dart';
import '../../services/match_service.dart';
import '../../services/tournament_service.dart';
import '../game/game_screen.dart';
class TournamentDetailsScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentDetailsScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends ConsumerState<TournamentDetailsScreen> {
  bool _isLaunchingMatch = false;

  @override
  void initState() {
    super.initState();
    // Refresh data every time we enter this screen
    Future.microtask(() {
      ref.read(lobbyProvider.notifier).refreshLobby();
    });
  }

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

    // Check if the user is registered in this tournament
    final isRegistered = tourn.participants.any((p) => p['userId'] == currentUserId);

    // Find user's bracket matchup for the current round
    final myBracket = tourn.brackets.cast<dynamic>().firstWhere(
      (b) => b['round'] == tourn.currentRound && (b['playerA'] == currentUserId || b['playerB'] == currentUserId),
      orElse: () => null,
    );

    // Determine match state for current round
    final hasPlayedThisRound = myBracket != null;
    final hasCompletedMatch = myBracket != null && myBracket['winner'] != null;

    // For simplicity, check if match is in brackets but without a winner and there's a match ID

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // ── Collapsing App Bar with Tournament Header ──
            SliverAppBar(
              backgroundColor: const Color(0xFF0B1329),
              elevation: 0,
              pinned: true,
              expandedHeight: tourn.status == 'ACTIVE' && tourn.roundStartTime != null ? 200 : 140,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F2027), Color(0xFF0B1329)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tournament name
                          Text(
                            tourn.name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),

                          // Stats row
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.emoji_events_rounded,
                                iconColor: Colors.amber,
                                label: '₹${tourn.totalPrize.toStringAsFixed(0)}',
                              ),
                              const SizedBox(width: 10),
                              _StatChip(
                                icon: Icons.people_alt_rounded,
                                iconColor: Colors.white54,
                                label: '${tourn.participants.length} Players',
                              ),
                              const SizedBox(width: 10),
                              _StatChip(
                                icon: tourn.status == 'ACTIVE'
                                    ? Icons.play_circle_rounded
                                    : tourn.status == 'COMPLETED'
                                        ? Icons.check_circle_rounded
                                        : Icons.schedule_rounded,
                                iconColor: tourn.status == 'ACTIVE'
                                    ? const Color(0xFF34D399)
                                    : tourn.status == 'COMPLETED'
                                        ? Colors.blueAccent
                                        : Colors.teal[300]!,
                                label: 'Rd ${tourn.currentRound}/${tourn.roundCount}',
                              ),
                            ],
                          ),

                          // Countdown timer
                          if (tourn.status == 'ACTIVE' && tourn.roundStartTime != null) ...[
                            const SizedBox(height: 14),
                            _DetailCountdownBar(
                              roundStartTime: tourn.roundStartTime!,
                              durationSeconds: tourn.roundDurationSeconds,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // ── Match Action Card (only for registered users) ──
            if (isRegistered)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildMatchActionCard(tourn, myBracket, hasCompletedMatch, currentUserId),
              ),

            // ── Leaderboard Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.leaderboard_rounded, color: Colors.teal[300], size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Points Table',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${tourn.participants.length} players',
                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ── Points Table ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _buildPointsTable(tourn, currentUserId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Match Action Card
  // ─────────────────────────────────────────────────────

  Widget _buildMatchActionCard(TournamentModel tourn, dynamic myBracket, bool hasCompletedMatch, String? currentUserId) {
    // ── COMPLETED Tournament ──
    if (tourn.status == 'COMPLETED') {
      // Find winner
      final participants = List<dynamic>.from(tourn.participants);
      participants.sort((a, b) {
        final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
        final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
        return scoreB.compareTo(scoreA);
      });
      final winner = participants.isNotEmpty ? participants.first : null;
      final winnerName = winner?['username'] ?? 'Unknown';
      final isUserWinner = winner != null && winner['userId'] == currentUserId;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUserWinner
                ? [const Color(0xFF134E5E).withOpacity(0.5), const Color(0xFF71B280).withOpacity(0.15)]
                : [Colors.white.withOpacity(0.03), Colors.white.withOpacity(0.01)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isUserWinner ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Icon(
              isUserWinner ? Icons.military_tech_rounded : Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              isUserWinner ? '🎉 YOU WON!' : 'TOURNAMENT CONCLUDED',
              style: GoogleFonts.outfit(
                color: isUserWinner ? const Color(0xFF4ADE80) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isUserWinner
                  ? 'Congratulations! Check the final standings below.'
                  : 'Winner: $winnerName • Final standings below.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── INACTIVE Tournament ──
    if (tourn.status != 'ACTIVE') {
      return const SizedBox.shrink();
    }

    // ── No Match Played Yet → Show PLAY button ──
    if (myBracket == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withOpacity(0.15),
              const Color(0xFF10B981).withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF34D399), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'Round ${tourn.currentRound} — Ready to Play',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              'Play your match before the round timer expires.\nOnly 1 match per round.',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 12.5, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => TournamentMatchmakingDialog(tournamentId: tourn.id),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  'PLAY MATCH NOW',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Match Completed for this round ──
    if (hasCompletedMatch) {
      final winnerId = myBracket['winner'];
      final isWinner = winnerId == currentUserId;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isWinner
                ? [const Color(0xFF134E5E).withOpacity(0.3), const Color(0xFF0D1117)]
                : [Colors.red.withOpacity(0.08), const Color(0xFF0D1117)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWinner ? Colors.green.withOpacity(0.25) : Colors.red.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isWinner ? Colors.green : Colors.red).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWinner ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isWinner ? const Color(0xFF4ADE80) : Colors.redAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWinner ? 'Round ${tourn.currentRound} — Victory! 🎉' : 'Round ${tourn.currentRound} — Defeated',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isWinner
                        ? '+1 point earned. Wait for next round.'
                        : 'Better luck next round. Keep fighting!',
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Match Ongoing (bracket exists but no winner yet) → RESUME ──
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.12),
            Colors.amber.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pending_rounded, color: Colors.amber[400], size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match In Progress',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Round ${tourn.currentRound} game is waiting.',
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLaunchingMatch ? null : () => _launchMatch(myBracket['matchId']),
              icon: _isLaunchingMatch
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                _isLaunchingMatch ? 'Loading...' : 'RESUME MATCH',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[500],
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
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
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
        // Refresh data after returning from the game
        ref.read(lobbyProvider.notifier).refreshLobby();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load match. Please try again.', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            content: Text('Error launching game: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────
  //  Points Table
  // ─────────────────────────────────────────────────────

  Widget _buildPointsTable(TournamentModel tourn, String? currentUserId) {
    final participants = List<dynamic>.from(tourn.participants);
    participants.sort((a, b) {
      final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
      final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);
      // Tiebreak: more wins first
      return 0;
    });

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_rounded, color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            Text(
              'No participants yet.',
              style: GoogleFonts.inter(color: Colors.white24),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1329).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: participants.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              // ── Table Header ──
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: Colors.white.withOpacity(0.03),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text('#', style: _headerStyle())),
                    Expanded(flex: 3, child: Text('Player', style: _headerStyle())),
                    SizedBox(width: 28, child: Text('P', style: _headerStyle(), textAlign: TextAlign.center)),
                    SizedBox(width: 28, child: Text('W', style: _headerStyle(color: Colors.green[400]), textAlign: TextAlign.center)),
                    SizedBox(width: 28, child: Text('D', style: _headerStyle(color: Colors.amber[400]), textAlign: TextAlign.center)),
                    SizedBox(width: 28, child: Text('L', style: _headerStyle(color: Colors.red[400]), textAlign: TextAlign.center)),
                    SizedBox(width: 40, child: Text('Pts', style: _headerStyle(color: Colors.teal[300]), textAlign: TextAlign.center)),
                  ],
                ),
              );
            }

            final pIndex = index - 1;
            final p = participants[pIndex];
            final userId = p['userId'];
            final username = p['username'] ?? 'Player';
            final isCurrentUser = userId == currentUserId;

            // Calculate stats from brackets
            int wins = 0;
            int matchesPlayed = 0;
            for (var b in tourn.brackets) {
              if (b['playerA'] == userId || b['playerB'] == userId) {
                final hasWinner = b['winner'] != null;
                if (hasWinner) {
                  matchesPlayed++;
                  if (b['winner'] == userId) {
                    wins++;
                  }
                }
              }
            }
            final score = (p['score'] as num?)?.toDouble() ?? 0.0;
            final draws = ((score - wins) * 2).round().clamp(0, tourn.roundCount);
            matchesPlayed += draws; // draws are counted as played matches too
            final losses = (matchesPlayed - wins - draws).clamp(0, tourn.roundCount);

            // Rank medal
            Widget rankWidget;
            if (pIndex == 0) {
              rankWidget = const Text('🥇', style: TextStyle(fontSize: 14));
            } else if (pIndex == 1) {
              rankWidget = const Text('🥈', style: TextStyle(fontSize: 14));
            } else if (pIndex == 2) {
              rankWidget = const Text('🥉', style: TextStyle(fontSize: 14));
            } else {
              rankWidget = Text(
                '${pIndex + 1}',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.teal.withOpacity(0.08) : Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
                  left: isCurrentUser
                      ? BorderSide(color: Colors.teal[400]!, width: 3)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: 32, child: rankWidget),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.inter(
                            color: isCurrentUser ? Colors.white : Colors.white70,
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'YOU',
                              style: GoogleFonts.inter(color: Colors.teal[300], fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$matchesPlayed', style: _cellStyle(), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$wins', style: _cellStyle(color: Colors.green[400]), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$draws', style: _cellStyle(color: Colors.amber[400]), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$losses', style: _cellStyle(color: Colors.red[400]), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      score.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        color: Colors.teal[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  TextStyle _headerStyle({Color? color}) {
    return GoogleFonts.inter(
      color: color ?? Colors.white38,
      fontWeight: FontWeight.bold,
      fontSize: 11,
      letterSpacing: 0.2,
    );
  }

  TextStyle _cellStyle({Color? color}) {
    return GoogleFonts.inter(
      color: color ?? Colors.white54,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
  }
}

// ─────────────────────────────────────────────────────
//  Stat Chip (used in header)
// ─────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Detail Countdown Bar (used in SliverAppBar)
// ─────────────────────────────────────────────────────

class _DetailCountdownBar extends StatefulWidget {
  final DateTime roundStartTime;
  final int durationSeconds;

  const _DetailCountdownBar({
    required this.roundStartTime,
    required this.durationSeconds,
  });

  @override
  State<_DetailCountdownBar> createState() => _DetailCountdownBarState();
}

class _DetailCountdownBarState extends State<_DetailCountdownBar> {
  Timer? _timer;
  late Duration _timeRemaining;

  @override
  void initState() {
    super.initState();
    _calculate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _calculate());
    });
  }

  void _calculate() {
    final endTime = widget.roundStartTime.add(Duration(seconds: widget.durationSeconds));
    _timeRemaining = endTime.difference(DateTime.now());
    if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _timeRemaining == Duration.zero;
    final isUrgent = _timeRemaining.inMinutes < 30;
    final hours = _timeRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');

    final totalSeconds = widget.durationSeconds;
    final elapsed = totalSeconds - _timeRemaining.inSeconds;
    final progress = (elapsed / totalSeconds).clamp(0.0, 1.0);

    final Color timerColor = isExpired
        ? Colors.redAccent
        : isUrgent
            ? Colors.orange[400]!
            : Colors.teal[300]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: timerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: timerColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_rounded, color: timerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Round ending soon...' : 'Time remaining',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            isExpired ? '--:--:--' : '$hours:$minutes:$seconds',
            style: GoogleFonts.shareTechMono(
              color: timerColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Tournament Matchmaking Dialog
// ─────────────────────────────────────────────────────

class TournamentMatchmakingDialog extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentMatchmakingDialog({
    super.key,
    required this.tournamentId,
  });

  @override
  ConsumerState<TournamentMatchmakingDialog> createState() => _TournamentMatchmakingDialogState();
}

class _TournamentMatchmakingDialogState extends ConsumerState<TournamentMatchmakingDialog>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsLeft = 20;
  MatchModel? _match;
  String _statusText = 'Finding opponent...';
  late AnimationController _pulseController;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Listen for match state changes via socket (opponent joins while waiting)
    ref.listenManual<GameState>(gameProvider, (previous, next) {
      if (_hasNavigated) return;
      final currentMatch = next.currentMatch;
      if (currentMatch != null && currentMatch.status == 'RUNNING') {
        _navigateToGame(currentMatch);
      }
    });
    _startSearch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Single atomic navigation method — ALL paths go through here
  void _navigateToGame(MatchModel match) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _timer?.cancel();

    // Ensure gameProvider has the latest match state
    ref.read(gameProvider.notifier).initMatch(match);

    if (mounted) {
      Navigator.pop(context); // pop dialog
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      ).then((_) {
        ref.read(lobbyProvider.notifier).refreshLobby();
      });
    }
  }

  void _startSearch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hasNavigated) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        _onTimeout();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasNavigated) return;
      setState(() {
        _statusText = 'Connecting to tournament lobby...';
      });

      final res = await TournamentService().matchmakeTournament(widget.tournamentId);
      if (!mounted || _hasNavigated) return;

      if (res['success'] == true) {
        final matchJson = res['match'];
        final match = MatchModel.fromJson(matchJson);
        if (match.status == 'RUNNING') {
          // Instant match found! Navigate immediately.
          _navigateToGame(match);
          return;
        }

        // Match is WAITING — store it and connect the socket
        setState(() {
          _match = match;
          _statusText = 'Waiting for another player...';
        });

        // Initialize game socket so we receive match_state updates
        ref.read(gameProvider.notifier).initMatch(match);
      } else {
        _timer?.cancel();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                res['error'] ?? 'Matchmaking failed.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    });
  }

  Future<void> _onTimeout() async {
    if (_hasNavigated) return;
    if (_match != null && _match!.status == 'WAITING') {
      setState(() {
        _statusText = 'Pairing you with a GM Bot...';
      });
      final botRes = await ref.read(lobbyProvider.notifier).forceBotJoin(_match!.id);
      if (_hasNavigated) return;
      if (mounted) {
        if (botRes['success'] == true) {
          // Bot joined — navigate via response or socket listener
          final match = botRes['match'] as MatchModel?;
          if (match != null && match.status == 'RUNNING') {
            _navigateToGame(match);
          }
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                botRes['error'] ?? 'Failed to connect to bot.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelSearch() async {
    _hasNavigated = true; // Prevent any further navigation attempts
    _timer?.cancel();
    if (_match != null) {
      await ref.read(lobbyProvider.notifier).cancelMatchmaking(_match!.id);
      ref.read(gameProvider.notifier).leaveGame();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / 20;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2332), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.teal.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.1),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated timer circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _secondsLeft > 5 ? Colors.teal[400]! : Colors.orange[400]!,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        _secondsLeft.toString().padLeft(2, '0'),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'sec',
                        style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Tournament Match',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.5 + 0.5 * _pulseController.value,
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.teal[200],
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white60,
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
