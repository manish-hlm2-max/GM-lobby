import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'views/auth/auth_screen.dart';
import 'views/home/lobby_shell.dart';
import 'views/version_check_wrapper.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ChessBettingApp(),
    ),
  );
}

class ChessBettingApp extends ConsumerWidget {
  const ChessBettingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Grandmaster Chess Lobby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.teal[400],
        scaffoldBackgroundColor: const Color(0xFF030712),
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.amber,
          surface: Color(0xFF0F172A),
          background: Color(0xFF030712),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: VersionCheckWrapper(
        child: authState.isLoading
            ? const Scaffold(
                backgroundColor: Color(0xFF030712),
                body: Center(
                  child: CircularProgressIndicator(color: Colors.teal),
                ),
              )
            : authState.user != null
                ? const LobbyShell()
                : const AuthScreen(),
      ),
    );
  }
}
