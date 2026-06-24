import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../providers/game_provider.dart';
import '../../models/match_model.dart';
import '../game/game_screen.dart';
import '../../widgets/title_badge.dart';

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

  void _startMatchmakingFlow(double entryFee) {
    if (entryFee > 0) {
      final balance = ref.read(authProvider).wallet?.balance ?? 0.0;
      if (balance < entryFee) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Insufficient Balance',
              style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'You need at least ₹${entryFee.toStringAsFixed(2)} to play this cash match. Your current balance is ₹${balance.toStringAsFixed(2)}.',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[400]),
                child: const Text('Okay', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Otherwise, show matchmaking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return MatchmakingDialogContent(
          entryFee: entryFee,
          timeControl: 600, // 10 minutes (600 seconds)
        );
      },
    );
  }

  Widget _buildMatchCard({
    required String title,
    required String description,
    required double entryFee,
    required double prizePool,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: accentColor),
              ),
              const SizedBox(width: 16),
              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Entry & Prize info, and Play Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entryFee > 0 ? 'Entry: ₹${entryFee.toStringAsFixed(0)}' : 'Entry: FREE',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prizePool > 0 ? 'Prize: ₹${prizePool.toStringAsFixed(0)}' : 'Prize: ELO Rating',
                    style: GoogleFonts.outfit(
                      color: prizePool > 0 ? Colors.amber[400] : Colors.teal[300],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _startMatchmakingFlow(entryFee),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  entryFee > 0 ? 'Play Cash' : 'Play Free',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  buildTitleBadge(authState.user?.title, fontSize: 11, rightMargin: 6),
                                  TextSpan(
                                    text: authState.user?.username ?? 'Player',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            '₹${authState.wallet?.balance.toStringAsFixed(2) ?? "0.00"}',
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
                        final opponentTitle = isWhite ? match.blackTitle : match.whiteTitle;
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
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(text: 'vs '),
                                          if (opponentTitle != null && opponentTitle.isNotEmpty)
                                            TextSpan(
                                              text: '$opponentTitle ',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFFFD700),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          TextSpan(
                                            text: opponent,
                                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${duration}m • Prize: ₹${match.prizePool.toStringAsFixed(2)}',
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

                Text(
                  'Choose Match Mode',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Free Match Card
                _buildMatchCard(
                  title: 'Free Arena',
                  description: '1vs1 Match • 10 Mins • Practice your chess skills, increase your ELO rating, and climb the leaderboard.',
                  entryFee: 0,
                  prizePool: 0,
                  icon: Icons.sports_esports_rounded,
                  accentColor: Colors.teal[400]!,
                  gradientColors: [
                    const Color(0xFF0F172A),
                    Colors.teal.withOpacity(0.05),
                  ],
                ),
                const SizedBox(height: 16),

                // Cash Match Card (₹49)
                _buildMatchCard(
                  title: 'Cash Clash',
                  description: '1vs1 Match • 10 Mins • Test your strategy against chess champions in real-time. Double your money!',
                  entryFee: 49,
                  prizePool: 98,
                  icon: Icons.monetization_on_rounded,
                  accentColor: Colors.amber[400]!,
                  gradientColors: [
                    const Color(0xFF0F172A),
                    Colors.amber.withOpacity(0.05),
                  ],
                ),
                const SizedBox(height: 16),

                // Challengers Arena (₹99)
                _buildMatchCard(
                  title: 'Challengers Arena',
                  description: '1vs1 Match • 10 Mins • Prove your expertise, win against competitive opponents and double your stakes!',
                  entryFee: 99,
                  prizePool: 198,
                  icon: Icons.workspace_premium_rounded,
                  accentColor: Colors.blueAccent,
                  gradientColors: [
                    const Color(0xFF0F172A),
                    Colors.blueAccent.withOpacity(0.05),
                  ],
                ),
                const SizedBox(height: 16),

                // Grandmaster Showdown (₹499)
                _buildMatchCard(
                  title: 'Grandmaster Showdown',
                  description: '1vs1 Match • 10 Mins • High stakes rapid chess. Face serious challengers and top-ranked masters!',
                  entryFee: 499,
                  prizePool: 998,
                  icon: Icons.military_tech_rounded,
                  accentColor: Colors.purpleAccent,
                  gradientColors: [
                    const Color(0xFF0F172A),
                    Colors.purpleAccent.withOpacity(0.05),
                  ],
                ),
                const SizedBox(height: 16),

                // High Rollers Club (₹999)
                _buildMatchCard(
                  title: 'High Rollers Club',
                  description: '1vs1 Match • 10 Mins • Exclusively for elite strategists. Dominate the board and claim the huge prize pool.',
                  entryFee: 999,
                  prizePool: 1998,
                  icon: Icons.diamond_rounded,
                  accentColor: Colors.pinkAccent,
                  gradientColors: [
                    const Color(0xFF0F172A),
                    Colors.pinkAccent.withOpacity(0.05),
                  ],
                ),
                const SizedBox(height: 16),

                // The Crown Jewel (₹4999)
                _buildMatchCard(
                  title: 'The Crown Jewel',
                  description: '1vs1 Match • 10 Mins • Ultimate chess wager combat. Climb to the absolute peak of fortune and chess glory!',
                  entryFee: 4999,
                  prizePool: 9998,
                  icon: Icons.emoji_events_rounded,
                  accentColor: Colors.orangeAccent,
                  gradientColors: [
                    const Color(0xFF0F172A),
                    Colors.orangeAccent.withOpacity(0.05),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchmakingDialogContent extends ConsumerStatefulWidget {
  final double entryFee;
  final int timeControl;

  const MatchmakingDialogContent({
    super.key,
    required this.entryFee,
    required this.timeControl,
  });

  @override
  ConsumerState<MatchmakingDialogContent> createState() => _MatchmakingDialogContentState();
}

class _MatchmakingDialogContentState extends ConsumerState<MatchmakingDialogContent> {
  Timer? _timer;
  int _secondsLeft = 20;
  MatchModel? _match;
  String _statusText = 'Finding your match...';
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSearch() {
    // Start periodic countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        _onTimeout();
      }
    });

    // Call startMatchmaking API
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        _statusText = 'Connecting to match server...';
      });
      final res = await ref.read(lobbyProvider.notifier).startMatchmaking(widget.entryFee, widget.timeControl);
      if (!mounted) return;

      if (res['success'] == true) {
        final match = res['match'] as MatchModel;
        if (match.status == 'RUNNING') {
          _timer?.cancel();
          _hasNavigated = true;
          ref.read(gameProvider.notifier).initMatch(match);
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GameScreen()),
          );
          return;
        }

        setState(() {
          _match = match;
        });

        // Initialize game socket immediately
        ref.read(gameProvider.notifier).initMatch(match);
      } else {
        // Matchmaking request failed
        _timer?.cancel();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(res['error'] ?? 'Matchmaking failed.', style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    });
  }

  Future<void> _onTimeout() async {
    if (_match != null && _match!.status == 'WAITING') {
      setState(() {
        _statusText = 'Opponent found! Joining game...';
      });
      final botRes = await ref.read(lobbyProvider.notifier).forceBotJoin(_match!.id);
      if (mounted) {
        if (botRes['success'] != true) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(botRes['error'] ?? 'Failed to connect to opponent.', style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelSearch() async {
    _timer?.cancel();
    if (_match != null) {
      // Run cancellation backend request
      await ref.read(lobbyProvider.notifier).cancelMatchmaking(_match!.id);
      ref.read(gameProvider.notifier).leaveGame(); // disconnect socket
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch game state to see if match status changes to RUNNING (meaning a human player joined via socket)
    final gameState = ref.watch(gameProvider);
    final currentMatch = gameState.currentMatch;

    if (currentMatch != null && currentMatch.status == 'RUNNING' && !_hasNavigated) {
      // A human opponent has joined!
      _hasNavigated = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      });
    }

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulse/spinning indicator for matchmaking
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[400]!),
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    _secondsLeft.toString().padLeft(2, '0'),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Finding Opponent',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _secondsLeft > 30
                    ? 'Please wait...'
                    : 'Almost there...',
                style: GoogleFonts.inter(
                  color: _secondsLeft > 30 ? Colors.teal[300] : Colors.amber[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel Search',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
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
