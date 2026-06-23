import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/tournament_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(lobbyProvider.notifier).refreshLobby();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final lobbyState = ref.watch(lobbyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tournaments',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Compete in multi-round brackets for huge prizes.',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: lobbyState.tournaments.isEmpty
                  ? Center(
                      child: Text(
                        'No upcoming tournaments scheduled.',
                        style: GoogleFonts.inter(color: Colors.white24),
                      ),
                    )
                  : ListView.builder(
                      itemCount: lobbyState.tournaments.length,
                      itemBuilder: (context, index) {
                        final tourn = lobbyState.tournaments[index];
                        final isRegistered = tourn.participants.any(
                          (p) => p['userId'] == authState.user?.id,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      tourn.name,
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tourn.status == 'ACTIVE' 
                                          ? Colors.green.withOpacity(0.1) 
                                          : Colors.teal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tourn.status,
                                      style: TextStyle(
                                        color: tourn.status == 'ACTIVE' ? Colors.green[400] : Colors.teal[300],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.emoji_events_rounded, color: Colors.amber[400], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Prize Pool: ₹${tourn.totalPrize.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, color: Colors.white38, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Starts: ${tourn.scheduledStartTime.toLocal().toString().substring(0, 16)}',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                              if (tourn.status == 'ACTIVE' || tourn.status == 'COMPLETED') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Round: ${tourn.currentRound} of ${tourn.roundCount}',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                                if (tourn.type == 'LEAGUE_5_DAY' && tourn.status == 'ACTIVE' && tourn.roundStartTime != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                                      const SizedBox(width: 8),
                                      RoundCountdown(
                                        roundStartTime: tourn.roundStartTime!,
                                        durationSeconds: tourn.roundDurationSeconds,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Participants: ${tourn.participants.length}',
                                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                                  ),
                                  ElevatedButton(
                                    onPressed: isRegistered || tourn.status != 'UPCOMING'
                                        ? null
                                        : () async {
                                            final success = await ref
                                                .read(lobbyProvider.notifier)
                                                .registerTournament(tourn.id);
                                            if (success && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Registered for tournament!'),
                                                  backgroundColor: Colors.teal,
                                                ),
                                              );
                                              // Refresh wallet balance
                                              ref.read(authProvider.notifier).checkAuth();
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isRegistered ? Colors.grey[800] : Colors.teal[400],
                                      disabledBackgroundColor: Colors.teal[800]?.withOpacity(0.3),
                                    ),
                                    child: isRegistered
                                        ? Row(
                                            children: const [
                                              Icon(Icons.check_rounded, size: 16, color: Colors.white70),
                                              SizedBox(width: 4),
                                              Text('Registered', style: TextStyle(color: Colors.white70)),
                                            ],
                                          )
                                        : Text(
                                            'Join (₹${tourn.entryFee.toStringAsFixed(2)})',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                  ),
                                ],
                              ),
                              if (tourn.type == 'LEAGUE_5_DAY' && (tourn.status == 'ACTIVE' || tourn.status == 'COMPLETED')) ...[
                                const Divider(color: Colors.white10, height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showPointsTable(context, tourn),
                                      icon: const Icon(Icons.leaderboard_rounded, size: 18, color: Colors.teal),
                                      label: const Text('View Points Table / Live Leaderboard', style: TextStyle(color: Colors.teal)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPointsTable(BuildContext context, TournamentModel tourn) {
    final participants = List<dynamic>.from(tourn.participants);
    participants.sort((a, b) {
      final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
      final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tournament Leaderboard',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 8,
                      columns: [
                        DataColumn(label: Text('Rank', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Player', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Played', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('W', style: GoogleFonts.inter(color: Colors.green[400], fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('D', style: GoogleFonts.inter(color: Colors.amber[400], fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('L', style: GoogleFonts.inter(color: Colors.red[400], fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Points', style: GoogleFonts.inter(color: Colors.teal[300], fontWeight: FontWeight.bold))),
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
                            DataCell(Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(username, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text('$matchesPlayed')),
                            DataCell(Text('$wins', style: TextStyle(color: Colors.green[400]))),
                            DataCell(Text('$draws', style: TextStyle(color: Colors.amber[400]))),
                            DataCell(Text('$losses', style: TextStyle(color: Colors.red[400]))),
                            DataCell(Text(score.toStringAsFixed(1), style: TextStyle(color: Colors.teal[300], fontWeight: FontWeight.bold))),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RoundCountdown extends StatefulWidget {
  final DateTime roundStartTime;
  final int durationSeconds;

  const RoundCountdown({
    super.key,
    required this.roundStartTime,
    required this.durationSeconds,
  });

  @override
  State<RoundCountdown> createState() => _RoundCountdownState();
}

class _RoundCountdownState extends State<RoundCountdown> {
  Timer? _timer;
  late Duration _timeRemaining;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _calculateTimeRemaining();
        });
      }
    });
  }

  void _calculateTimeRemaining() {
    final endTime = widget.roundStartTime.add(Duration(seconds: widget.durationSeconds));
    _timeRemaining = endTime.difference(DateTime.now());
    if (_timeRemaining.isNegative) {
      _timeRemaining = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeRemaining == Duration.zero) {
      return const Text(
        'Round ending soon...',
        style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
      );
    }

    final hours = _timeRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      'Round Ends In: ${hours}h ${minutes}m ${seconds}s',
      style: GoogleFonts.shareTechMono(color: Colors.amber[400], fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}
