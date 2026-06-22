import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../providers/game_provider.dart';
import '../game/game_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(lobbyProvider.notifier).refreshLobby();
    });
  }

  void _showCreateMatchDialog() {
    double entryFee = 0.0;
    int timeControl = 600; // default 10 minutes
    String preferredColor = 'white';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Host a Match',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entry Fee Slider
                  Text(
                    'Entry Fee: \$${entryFee.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  Slider(
                    value: entryFee,
                    min: 0,
                    max: 50,
                    divisions: 10,
                    activeColor: Colors.teal[400],
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setDialogState(() {
                        entryFee = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Time Control Dropdown
                  Text(
                    'Time Format:',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  DropdownButton<int>(
                    value: timeControl,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 180, child: Text('3 Minutes (Blitz)')),
                      DropdownMenuItem(value: 300, child: Text('5 Minutes (Blitz)')),
                      DropdownMenuItem(value: 600, child: Text('10 Minutes (Rapid)')),
                      DropdownMenuItem(value: 900, child: Text('15 Minutes (Rapid)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          timeControl = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Preferred Color Selection
                  Text(
                    'Play As:',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text('White'),
                        selected: preferredColor == 'white',
                        selectedColor: Colors.teal[400],
                        labelStyle: TextStyle(color: preferredColor == 'white' ? Colors.white : Colors.white60),
                        onSelected: (selected) {
                          if (selected) setDialogState(() => preferredColor = 'white');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Black'),
                        selected: preferredColor == 'black',
                        selectedColor: Colors.teal[400],
                        labelStyle: TextStyle(color: preferredColor == 'black' ? Colors.white : Colors.white60),
                        onSelected: (selected) {
                          if (selected) setDialogState(() => preferredColor = 'black');
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final match = await ref.read(lobbyProvider.notifier).createMatch(
                      entryFee,
                      timeControl,
                      preferredColor,
                    );
                    if (match != null && mounted) {
                      ref.read(gameProvider.notifier).initMatch(match);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[400]),
                  child: const Text('Host Lobby', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final lobbyState = ref.watch(lobbyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: RefreshIndicator(
        onRefresh: () => ref.read(lobbyProvider.notifier).refreshLobby(),
        color: Colors.teal,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal[400],
                      child: Text(
                        authState.user?.username.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${authState.user?.username ?? "Player"}',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Elo Rating: ${authState.user?.elo ?? 1200}',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${authState.wallet?.balance.toStringAsFixed(2) ?? "0.00"}',
                          style: GoogleFonts.outfit(color: Colors.teal[300], fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Wallet Balance',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (lobbyState.myActiveMatches.isNotEmpty) ...[
                Text(
                  'Your Ongoing Matches',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: lobbyState.myActiveMatches.length,
                    itemBuilder: (context, index) {
                      final match = lobbyState.myActiveMatches[index];
                      final isWhite = match.whitePlayerId == authState.user?.id;
                      final opponent = isWhite ? (match.blackUsername ?? 'Waiting...') : (match.whiteUsername ?? 'Waiting...');
                      final duration = match.timeControl ~/ 60;

                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 16, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.withOpacity(0.15),
                              Colors.teal.withOpacity(0.03),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'vs $opponent',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$durationm • Prize: \$${match.prizePool.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ref.read(gameProvider.notifier).initMatch(match);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GameScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Resume'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Lobbies',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
                    onPressed: () => ref.read(lobbyProvider.notifier).refreshLobby(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: lobbyState.openMatches.isEmpty
                    ? Center(
                        child: Text(
                          'No open matches available. Host one!',
                          style: GoogleFonts.inter(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        itemCount: lobbyState.openMatches.length,
                        itemBuilder: (context, index) {
                          final match = lobbyState.openMatches[index];
                          final duration = match.timeControl ~/ 60;
                          final isMyMatch = match.whitePlayerId == authState.user?.id ||
                                            match.blackPlayerId == authState.user?.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sports_esports_rounded, size: 36, color: Colors.teal[300]),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Host: ${match.whiteUsername ?? match.blackUsername ?? "Unknown"}',
                                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Format: $duration min • Entry: \$${match.entryFee.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Prize Pool',
                                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                                    ),
                                    Text(
                                      '\$${match.prizePool.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(color: Colors.amber[400], fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: isMyMatch
                                          ? () {
                                              ref.read(gameProvider.notifier).initMatch(match);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => const GameScreen()),
                                              );
                                            }
                                          : () async {
                                              final joinedMatch = await ref.read(lobbyProvider.notifier).joinMatch(match.id);
                                              if (joinedMatch != null && mounted) {
                                                ref.read(gameProvider.notifier).initMatch(joinedMatch);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const GameScreen()),
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isMyMatch ? Colors.teal : Colors.white10,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(isMyMatch ? 'Rejoin' : 'Play'),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMatchDialog,
        backgroundColor: Colors.teal[400],
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
