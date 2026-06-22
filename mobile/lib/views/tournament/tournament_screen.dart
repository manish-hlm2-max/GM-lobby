import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
}
