import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/wallet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/socket_service.dart';
import 'home_screen.dart';
import '../wallet/wallet_screen.dart';
import '../tournament/tournament_screen.dart';
import '../results/results_screen.dart';
import '../profile/profile_screen.dart';

class LobbyShell extends ConsumerStatefulWidget {
  const LobbyShell({super.key});

  @override
  ConsumerState<LobbyShell> createState() => _LobbyShellState();
}

class _LobbyShellState extends ConsumerState<LobbyShell> {
  int _currentIndex = 0;
  final SocketService _socketService = SocketService();

  final List<Widget> _pages = [
    const HomeScreen(),
    const WalletScreen(),
    const TournamentScreen(),
    const ResultsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || userId.isEmpty) return;

    _socketService.connect(userId, onConnect: () {
      print('Lobby socket connected for wallet updates');
    });

    // Listen for real-time wallet updates from admin actions
    _socketService.onWalletUpdated((data) {
      final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
      final lockedBalance = (data['lockedBalance'] as num?)?.toDouble() ?? 0.0;

      // Update the wallet balance in auth provider instantly
      ref.read(authProvider.notifier).updateWallet(
        WalletModel(balance: balance, lockedBalance: lockedBalance),
      );

      // Reload transaction history so the wallet screen reflects changes
      ref.read(walletProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _socketService.off('wallet_updated');
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.teal[400],
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_rounded),
            label: 'Tournaments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Results',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
