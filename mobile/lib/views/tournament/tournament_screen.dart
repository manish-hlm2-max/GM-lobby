import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/tournament_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../services/tournament_service.dart';
import 'tournament_details_screen.dart';

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
    final userId = authState.user?.id;
    final isAdmin = authState.user?.role == 'SUPER_ADMIN' || authState.user?.role == 'MODERATOR' || authState.user?.role == 'ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAdminCreateDialog(context),
              backgroundColor: Colors.teal[400],
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        color: Colors.teal,
        backgroundColor: const Color(0xFF0F172A),
        onRefresh: () => ref.read(lobbyProvider.notifier).refreshLobby(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal.withOpacity(0.3), Colors.teal.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tournaments',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Play 1 match every round. Climb the leaderboard.',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (lobbyState.tournaments.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_esports_outlined, color: Colors.white12, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No tournaments scheduled',
                        style: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check back soon!',
                        style: GoogleFonts.inter(color: Colors.white12, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tourn = lobbyState.tournaments[index];
                      final isRegistered = tourn.participants.any(
                        (p) => p['userId'] == userId,
                      );
                      return _TournamentCard(
                        tourn: tourn,
                        isRegistered: isRegistered,
                        isAdmin: isAdmin,
                        onRegister: () async {
                          final success = await ref.read(lobbyProvider.notifier).registerTournament(tourn.id);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('You\'re in! Good luck 🎯', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.teal[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            ref.read(authProvider.notifier).checkAuth();
                          }
                        },
                        onOpenDetails: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentDetailsScreen(tournamentId: tourn.id),
                            ),
                          );
                          ref.read(lobbyProvider.notifier).refreshLobby();
                        },
                        onAdminStart: () async {
                          final res = await TournamentService().adminStartTournament(tourn.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['success'] == true ? 'Tournament started!' : (res['error'] ?? 'Failed to start'),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: res['success'] == true ? Colors.teal[700] : Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            ref.read(lobbyProvider.notifier).refreshLobby();
                          }
                        },
                        onAdminEdit: () => _showAdminEditDialog(context, tourn),
                      );
                    },
                    childCount: lobbyState.tournaments.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Admin Create Tournament Dialog
  // ─────────────────────────────────────────────────────

  void _showAdminCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final entryFeeCtrl = TextEditingController(text: '0');
    final prizeCtrl = TextEditingController(text: '0');
    final roundCountCtrl = TextEditingController(text: '10');
    final roundHoursCtrl = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Create Tournament', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdminField(controller: nameCtrl, label: 'Tournament Name', icon: Icons.title_rounded),
                const SizedBox(height: 12),
                _AdminField(controller: entryFeeCtrl, label: 'Entry Fee (₹)', icon: Icons.monetization_on_rounded, isNumber: true),
                const SizedBox(height: 12),
                _AdminField(controller: prizeCtrl, label: 'Prize Pool (₹)', icon: Icons.emoji_events_rounded, isNumber: true),
                const SizedBox(height: 12),
                _AdminField(controller: roundCountCtrl, label: 'Number of Rounds', icon: Icons.repeat_rounded, isNumber: true),
                const SizedBox(height: 12),
                _AdminField(controller: roundHoursCtrl, label: 'Hours per Round', icon: Icons.timer_rounded, isNumber: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;

                final hours = int.tryParse(roundHoursCtrl.text) ?? 12;
                final roundDurationSeconds = hours * 3600;

                final res = await TournamentService().adminCreateTournament(
                  name: nameCtrl.text.trim(),
                  entryFee: double.tryParse(entryFeeCtrl.text) ?? 0,
                  totalPrize: double.tryParse(prizeCtrl.text) ?? 0,
                  scheduledStartTime: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
                  roundCount: int.tryParse(roundCountCtrl.text) ?? 10,
                  roundDurationSeconds: roundDurationSeconds,
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res['success'] == true ? 'Tournament created!' : (res['error'] ?? 'Failed'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: res['success'] == true ? Colors.teal[700] : Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  ref.read(lobbyProvider.notifier).refreshLobby();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────
  //  Admin Edit Tournament Dialog
  // ─────────────────────────────────────────────────────

  void _showAdminEditDialog(BuildContext context, TournamentModel tourn) {
    final nameCtrl = TextEditingController(text: tourn.name);
    final prizeCtrl = TextEditingController(text: tourn.totalPrize.toStringAsFixed(0));
    final roundCountCtrl = TextEditingController(text: tourn.roundCount.toString());
    final roundHoursCtrl = TextEditingController(text: (tourn.roundDurationSeconds / 3600).round().toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Tournament', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdminField(controller: nameCtrl, label: 'Tournament Name', icon: Icons.title_rounded),
                const SizedBox(height: 12),
                _AdminField(controller: prizeCtrl, label: 'Prize Pool (₹)', icon: Icons.emoji_events_rounded, isNumber: true),
                const SizedBox(height: 12),
                _AdminField(controller: roundCountCtrl, label: 'Number of Rounds', icon: Icons.repeat_rounded, isNumber: true),
                const SizedBox(height: 12),
                _AdminField(controller: roundHoursCtrl, label: 'Hours per Round', icon: Icons.timer_rounded, isNumber: true),
                const SizedBox(height: 8),
                Text(
                  'Current round duration: ${(tourn.roundDurationSeconds / 3600).round()} hours',
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final hours = int.tryParse(roundHoursCtrl.text) ?? 12;
                final roundDurationSeconds = hours * 3600;

                final res = await TournamentService().adminEditTournament(
                  tournamentId: tourn.id,
                  name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                  totalPrize: double.tryParse(prizeCtrl.text),
                  roundCount: int.tryParse(roundCountCtrl.text),
                  roundDurationSeconds: roundDurationSeconds,
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res['success'] == true ? 'Tournament updated!' : (res['error'] ?? 'Failed'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: res['success'] == true ? Colors.teal[700] : Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  ref.read(lobbyProvider.notifier).refreshLobby();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
//  Admin Text Field Widget
// ─────────────────────────────────────────────────────

class _AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;

  const _AdminField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.teal[300], size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Tournament Card Widget
// ─────────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final TournamentModel tourn;
  final bool isRegistered;
  final bool isAdmin;
  final VoidCallback onRegister;
  final VoidCallback onOpenDetails;
  final VoidCallback onAdminStart;
  final VoidCallback onAdminEdit;

  const _TournamentCard({
    required this.tourn,
    required this.isRegistered,
    required this.isAdmin,
    required this.onRegister,
    required this.onOpenDetails,
    required this.onAdminStart,
    required this.onAdminEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tourn.status == 'ACTIVE';
    final isCompleted = tourn.status == 'COMPLETED';
    final isUpcoming = tourn.status == 'UPCOMING';

    // Determine border & accent color
    Color accentColor = Colors.teal;
    if (isActive && isRegistered) {
      accentColor = const Color(0xFF10B981);
    } else if (isCompleted) {
      accentColor = Colors.blueAccent;
    }

    return GestureDetector(
      onTap: (isActive || isCompleted) && isRegistered ? onOpenDetails : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F172A),
              isActive && isRegistered
                  ? const Color(0xFF0A1628)
                  : const Color(0xFF0D1117),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive && isRegistered
                ? accentColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.06),
            width: isActive && isRegistered ? 1.5 : 1,
          ),
          boxShadow: isActive && isRegistered
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.08),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tourn.name,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.emoji_events_rounded, color: Colors.amber[400], size: 16),
                            const SizedBox(width: 5),
                            Text(
                              '₹${tourn.totalPrize.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: Colors.amber[300],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Icon(Icons.people_alt_rounded, color: Colors.white30, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              '${tourn.participants.length}',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: tourn.status),
                      // Admin edit button
                      if (isAdmin) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: onAdminEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, color: Colors.amber[400], size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.inter(color: Colors.amber[400], fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Info Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white24, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(tourn.scheduledStartTime),
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                  if (isActive || isCompleted) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Round ${tourn.currentRound}/${tourn.roundCount}',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Round Duration Info ──
            if (tourn.roundDurationSeconds > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, color: Colors.white24, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${(tourn.roundDurationSeconds / 3600).round()}h per round  •  ${tourn.roundCount} rounds',
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // ── Countdown Timer (for ALL active tournaments with roundStartTime) ──
            if (isActive && tourn.roundStartTime != null && tourn.roundDurationSeconds > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: _CountdownBanner(
                  roundStartTime: tourn.roundStartTime!,
                  durationSeconds: tourn.roundDurationSeconds,
                  currentRound: tourn.currentRound,
                ),
              ),

            // ── Action Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: _buildActionRow(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    if (tourn.status == 'UPCOMING') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isRegistered
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text('Registered', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal[300],
                      side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledForegroundColor: Colors.teal[400],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onRegister,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      tourn.entryFee > 0
                          ? 'Join Tournament  •  ₹${tourn.entryFee.toStringAsFixed(0)}'
                          : 'Join Tournament  •  Free',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
          ),
          // Admin Start button
          if (isAdmin && tourn.participants.length >= 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onAdminStart,
                icon: Icon(Icons.play_arrow_rounded, size: 18, color: Colors.green[400]),
                label: Text(
                  'Start Tournament (Admin)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green[400]),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (tourn.status == 'ACTIVE') {
      if (isRegistered) {
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: onOpenDetails,
            icon: const Icon(Icons.sports_esports_rounded, size: 20),
            label: Text(
              'OPEN TOURNAMENT',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        );
      }
      return Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Tournament In Progress',
          style: GoogleFonts.inter(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
    }

    if (tourn.status == 'COMPLETED') {
      if (isRegistered) {
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onOpenDetails,
            icon: const Icon(Icons.leaderboard_rounded, size: 18),
            label: Text(
              'View Results',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      }
      return Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Tournament Ended',
          style: GoogleFonts.inter(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} • $hour:${local.minute.toString().padLeft(2, '0')} $amPm';
  }
}

// ─────────────────────────────────────────────────────
//  Status Badge
// ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'ACTIVE':
        bgColor = const Color(0xFF10B981).withOpacity(0.12);
        textColor = const Color(0xFF34D399);
        label = '● LIVE';
        break;
      case 'COMPLETED':
        bgColor = Colors.blueAccent.withOpacity(0.1);
        textColor = Colors.blueAccent;
        label = 'ENDED';
        break;
      default:
        bgColor = Colors.teal.withOpacity(0.08);
        textColor = Colors.teal[300]!;
        label = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Countdown Banner (shown on tournament card)
// ─────────────────────────────────────────────────────

class _CountdownBanner extends StatefulWidget {
  final DateTime roundStartTime;
  final int durationSeconds;
  final int currentRound;

  const _CountdownBanner({
    required this.roundStartTime,
    required this.durationSeconds,
    required this.currentRound,
  });

  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner> {
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
    final hours = _timeRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    final isUrgent = _timeRemaining.inMinutes < 30;
    final isExpired = _timeRemaining == Duration.zero;

    final totalSeconds = widget.durationSeconds;
    final elapsed = totalSeconds - _timeRemaining.inSeconds;
    final progress = (elapsed / totalSeconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [Colors.red.withOpacity(0.12), Colors.red.withOpacity(0.04)]
              : isUrgent
                  ? [Colors.orange.withOpacity(0.12), Colors.orange.withOpacity(0.04)]
                  : [Colors.teal.withOpacity(0.10), Colors.teal.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? Colors.red.withOpacity(0.2)
              : isUrgent
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.teal.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
                color: isExpired
                    ? Colors.redAccent
                    : isUrgent
                        ? Colors.orange[300]
                        : Colors.teal[300],
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isExpired ? 'Round ending soon...' : 'Round ${widget.currentRound} ends in',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                isExpired ? '--:--:--' : '$hours:$minutes:$seconds',
                style: GoogleFonts.shareTechMono(
                  color: isExpired
                      ? Colors.redAccent
                      : isUrgent
                          ? Colors.orange[300]
                          : Colors.teal[300],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                isExpired
                    ? Colors.redAccent
                    : isUrgent
                        ? Colors.orange[400]!
                        : Colors.teal[400]!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  RoundCountdown (used by details screen)
// ─────────────────────────────────────────────────────

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
      return Text(
        'Round ending soon...',
        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
      );
    }

    final hours = _timeRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      '$hours:$minutes:$seconds',
      style: GoogleFonts.shareTechMono(color: Colors.teal[300], fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}
