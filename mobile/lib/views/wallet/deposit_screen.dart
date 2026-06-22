import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amountController = TextEditingController();
  final _utrController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final String _merchantUpiId = 'fojimeena125-3@oksbi';

  @override
  void dispose() {
    _amountController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  void _selectAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    final utr = _utrController.text.trim();

    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum deposit amount is ₹10.')),
      );
      return;
    }

    if (utr.length != 12 || int.tryParse(utr) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 12-digit UPI Reference/UTR ID.')),
      );
      return;
    }

    final success = await ref.read(walletProvider.notifier).deposit(amount, referenceId: utr);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deposit request submitted! It will credit after admin verification.'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final err = ref.read(walletProvider).error ?? 'Failed to submit deposit request.';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light background like in the screenshot
      appBar: AppBar(
        backgroundColor: const Color(0xFFE50914), // Red color theme header
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Deposit Money',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: walletState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE50914), Color(0xFFB80710)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE50914).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AVAILABLE BALANCE',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
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
                                  color: Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Secure & Instant Credit',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Wallet decorative background icon
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Icon(
                              Icons.account_balance_wallet,
                              size: 100,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Steps Layout with vertical timeline line
                    Stack(
                      children: [
                        // Vertical Timeline Line
                        Positioned(
                          left: 17,
                          top: 24,
                          bottom: 24,
                          child: Container(
                            width: 2,
                            color: Colors.grey[300],
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step 1
                            _buildStepRow(
                              stepNumber: '1',
                              title: '1. Enter Deposit Amount',
                              subtext: 'Minimum deposit amount is ₹10',
                              isActive: true,
                              child: _buildAmountCard(),
                            ),
                            const SizedBox(height: 20),

                            // Step 2
                            _buildStepRow(
                              stepNumber: '2',
                              title: '2. Transfer via UPI',
                              subtext: 'Launch UPI app or scan scanning QR',
                              isActive: false,
                              child: _buildUpiCard(),
                            ),
                            const SizedBox(height: 20),

                            // Step 3
                            _buildStepRow(
                              stepNumber: '3',
                              title: '3. Reference ID & Submit',
                              subtext: 'Enter 12-digit payment ref ID',
                              isActive: false,
                              child: _buildSubmitCard(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Hourglass verification disclaimer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '⏳ Your deposit will be credited after admin verification',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String subtext,
    required bool isActive,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Number Circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE50914) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? const Color(0xFFE50914) : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE50914).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  stepNumber,
                  style: GoogleFonts.outfit(
                    color: isActive ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title & Subtext
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Card Content Offset
        Padding(
          padding: const EdgeInsets.only(left: 52.0, top: 12.0),
          child: child,
        ),
      ],
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Input Box
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey, size: 20),
              labelText: 'Deposit Amount (₹)',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter amount';
              final amt = double.tryParse(value);
              if (amt == null || amt < 10) return 'Minimum amount is ₹10';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Quick Select Amount:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          // Grid Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [100.0, 500.0, 1000.0, 2000.0, 5000.0].map((amt) {
              return InkWell(
                onTap: () => _selectAmount(amt),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    '₹${amt.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QR Code Card
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[100]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Premium offline custom vector QR code placeholder
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Mock grid patterns for QR code representation
                        child: CustomPaint(
                          painter: QrPatternPainter(),
                        ),
                      ),
                      // Tap to zoom overlay pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to Zoom',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan this QR code to complete payment',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Merchant UPI ID display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[150] ?? Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MERCHANT UPI ID',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _merchantUpiId,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Color(0xFFE50914), size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _merchantUpiId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI ID copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pay with UPI App Button
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('UPI apps list requested...')),
              );
            },
            icon: const Icon(Icons.flash_on, color: Colors.amber, size: 18),
            label: Text(
              'Pay with UPI App',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF94A3B8), // Grey button like screenshot
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // UTR / Transaction ID Field
          TextFormField(
            controller: _utrController,
            keyboardType: TextInputType.number,
            maxLength: 12,
            style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.receipt_long_outlined, color: Colors.grey, size: 20),
              labelText: 'UPI Transaction / UTR ID',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter 12-digit UTR ID';
              if (value.length != 12 || int.tryParse(value) == null) {
                return 'Must be a 12-digit number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Locate 12-digit UTR/Ref No. in payment details screen.',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Submit Request Button
          ElevatedButton(
            onPressed: _submitDeposit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81E2B3), // Mint green button
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: Text(
              'Submit Deposit Request',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw a modern mock QR Code vector
class QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    // Drawing outer position detection markers (top-left, top-right, bottom-left)
    _drawMarker(canvas, const Offset(10, 10), paint);
    _drawMarker(canvas, Offset(size.width - 40, 10), paint);
    _drawMarker(canvas, Offset(10, size.height - 40), paint);

    // Drawing random small grid spots representing QR payload data
    final randomSpots = [
      const Rect.fromLTWH(50, 20, 10, 10),
      const Rect.fromLTWH(65, 10, 5, 20),
      const Rect.fromLTWH(80, 25, 15, 10),
      const Rect.fromLTWH(50, 45, 25, 5),
      const Rect.fromLTWH(80, 45, 10, 20),
      const Rect.fromLTWH(10, 50, 20, 10),
      const Rect.fromLTWH(20, 70, 10, 15),
      const Rect.fromLTWH(45, 75, 15, 10),
      const Rect.fromLTWH(70, 75, 20, 10),
      const Rect.fromLTWH(100, 75, 10, 25),
      const Rect.fromLTWH(10, 95, 20, 10),
      const Rect.fromLTWH(45, 95, 25, 25),
      const Rect.fromLTWH(80, 95, 10, 10),
      const Rect.fromLTWH(80, 110, 20, 10),
    ];

    for (var rect in randomSpots) {
      canvas.drawRect(rect, paint);
    }
  }

  void _drawMarker(Canvas canvas, Offset offset, Paint paint) {
    // Outer square (30x30)
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, 30, 30), paint);
    // Inner white space (20x20)
    final whitePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(offset.dx + 5, offset.dy + 5, 20, 20), whitePaint);
    // Inner solid square (10x10)
    canvas.drawRect(Rect.fromLTWH(offset.dx + 10, offset.dy + 10, 10, 10), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
