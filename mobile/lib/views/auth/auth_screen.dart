import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isSignUp = false;

  Timer? _debounceTimer;
  String? _usernameError;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (!_isSignUp) return;
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _usernameError = null;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = true;
      });
      final res = await ref.read(authProvider.notifier).checkUsernameAvailability(username);
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        if (res['success'] == true && res['available'] == false) {
          _usernameError = 'Username already taken.';
        } else {
          _usernameError = null;
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_isSignUp) {
      if (_isCheckingUsername) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking username availability, please wait...'),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }
      if (_usernameError != null) return;
    }

    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authProvider.notifier);
    bool success;

    if (_isSignUp) {
      success = await notifier.register(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim(),
        fullName: _fullNameController.text.trim(),
      );
    } else {
      success = await notifier.login(
        _emailController.text.trim(), // acts as emailOrUsername
        _passwordController.text,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSignUp ? 'Registration successful!' : 'Welcome back!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF030712), Color(0xFF0B1329), Color(0xFF1F1A3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Icon
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.amber[400]!.withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber[400]!.withOpacity(0.15),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'GRANDMASTER LOBBY',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'High Stakes Real-Time Chess',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      // Glassmorphic Input Card
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isSignUp ? 'Create Account' : 'Log In',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // Full Name Field (only visible for sign up)
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _fullNameController,
                                style: const TextStyle(color: Colors.white),
                                textCapitalization: TextCapitalization.words,
                                decoration: _inputDecoration('Full Name', Icons.badge_outlined),
                                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter full name' : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Email Address', Icons.email_outlined),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter email';
                                }
                                if (_isSignUp) {
                                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Username field (only visible for sign up)
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _usernameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  'Username',
                                  Icons.person_outline,
                                  suffixIcon: _isCheckingUsername
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                            ),
                                          ),
                                        )
                                      : (_usernameController.text.trim().isNotEmpty
                                          ? (_usernameError != null
                                              ? const Icon(Icons.error_outline, color: Colors.redAccent)
                                              : const Icon(Icons.check_circle_outline, color: Colors.teal))
                                          : null),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter username';
                                  }
                                  if (_usernameError != null) {
                                    return _usernameError;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _phoneController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter phone number';
                                  }
                                  final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
                                  if (!phoneRegex.hasMatch(value.trim())) {
                                    return 'Please enter a valid phone number (10-15 digits)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
                              decoration: _inputDecoration('Password', Icons.lock_outline),
                              validator: (value) => value == null || value.length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                            if (state.error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                state.error!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Submit Button
                            ElevatedButton(
                              onPressed: state.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 5,
                              ),
                              child: state.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp ? 'SIGN UP' : 'LOG IN',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),

                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Toggle state button
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _usernameError = null;
                              _isCheckingUsername = false;
                              _emailController.clear();
                              _usernameController.clear();
                              _phoneController.clear();
                              _passwordController.clear();
                              _fullNameController.clear();
                              _debounceTimer?.cancel();
                            });
                          },
                          child: Text(
                            _isSignUp ? 'Already have an account? Log In' : "Don't have an account? Sign Up",
                            style: GoogleFonts.inter(
                              color: Colors.teal[300],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white30,
                              ),
                              textAlign: TextAlign.center,
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.teal),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  RoundedRectangleBorder RoundedCornerShape(double radius) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }

}
