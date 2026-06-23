import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ifscController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(walletProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _bankNameController.dispose();
    _ifscController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final holderName = _holderNameController.text.trim();
    final bankName = _bankNameController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();

    final availableBalance = ref.read(authProvider).wallet?.balance ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a positive amount.')),
      );
      return;
    }

    if (amount > availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. Available: ₹${availableBalance.toStringAsFixed(2)}')),
      );
      return;
    }

    final success = await ref.read(walletProvider.notifier).withdraw(
          amount: amount,
          bankName: bankName,
          ifscCode: ifsc,
          accountHolderName: holderName,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal request submitted! It will process after admin approval.'),
          backgroundColor: Colors.teal,
        ),
      );
      _amountController.clear();
      _holderNameController.clear();
      _bankNameController.clear();
      _ifscController.clear();
      // Reload history and profile to refresh locked balances
      ref.read(walletProvider.notifier).loadHistory();
    } else if (mounted) {
      final err = ref.read(walletProvider).error ?? 'Failed to submit withdrawal request.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final balance = authState.wallet?.balance ?? 0.0;

    // Filter transaction history for withdrawals
    final withdrawals = walletState.transactions.where((tx) => tx.type == 'WITHDRAWAL').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Withdraw Money',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: walletState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Available Balance Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.teal.withOpacity(0.15),
                            Colors.teal.withOpacity(0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.teal.withOpacity(0.2)),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.teal, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AVAILABLE BALANCE',
                                    style: GoogleFonts.inter(
                                      color: Colors.teal[300],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '₹${balance.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_clock_outlined, color: Colors.teal, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Locked on request for verification',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Icon(
                              Icons.arrow_circle_up_outlined,
                              size: 100,
                              color: Colors.teal.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter Bank Transfer Details',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Account Holder Name
                          TextFormField(
                            controller: _holderNameController,
                            style: GoogleFonts.inter(color: Colors.white),
                            textCapitalization: TextCapitalization.words,
                            decoration: _buildInputDecoration('Account Holder Name', Icons.person_outline),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Please enter account holder name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Bank Name
                          TextFormField(
                            controller: _bankNameController,
                            style: GoogleFonts.inter(color: Colors.white),
                            textCapitalization: TextCapitalization.words,
                            decoration: _buildInputDecoration('Bank Name', Icons.account_balance_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Please enter bank name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // IFSC Code
                          TextFormField(
                            controller: _ifscController,
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
                            ],
                            decoration: _buildInputDecoration('IFSC Code', Icons.numbers_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Please enter IFSC code';
                              if (value.trim().length != 11) return 'IFSC must be exactly 11 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: _buildInputDecoration('Amount to Withdraw (₹)', Icons.currency_rupee),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter withdrawal amount';
                              final amt = double.tryParse(value);
                              if (amt == null || amt <= 0) return 'Please enter a valid positive number';
                              if (amt > balance) return 'Insufficient funds in wallet';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Withdraw Action Button
                          ElevatedButton(
                            onPressed: _submitWithdrawal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[400],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            child: Text(
                              'Request Cash Withdrawal',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Withdrawal History Header
                    Text(
                      'Withdrawal History',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Withdrawal History List
                    withdrawals.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.01),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Center(
                              child: Text(
                                'No withdrawals found',
                                style: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: withdrawals.length,
                            itemBuilder: (context, index) {
                              final tx = withdrawals[index];
                              final isPending = tx.status == 'PENDING';
                              final isSuccess = tx.status == 'SUCCESS';

                              Color statusColor = Colors.grey;
                              if (isSuccess) statusColor = Colors.teal;
                              if (tx.status == 'FAILED') statusColor = Colors.redAccent;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹${tx.amount.abs().toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: statusColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            tx.status,
                                            style: GoogleFonts.inter(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (tx.bankName != null) ...[
                                      Text(
                                        'A/C Holder: ${tx.accountHolderName}',
                                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                      ),
                                      Text(
                                        'Bank: ${tx.bankName} | IFSC: ${tx.ifscCode}',
                                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                      ),
                                    ] else ...[
                                      Text(
                                        tx.description,
                                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      'Date: ${tx.createdAt.toLocal().toString().split('.')[0]}',
                                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.teal, size: 20),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.teal),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
