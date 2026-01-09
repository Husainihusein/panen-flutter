import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bottom_nav_controller.dart';
import '../home_screen.dart';

class CreatorRegistrationScreen extends StatefulWidget {
  const CreatorRegistrationScreen({super.key});

  @override
  State<CreatorRegistrationScreen> createState() =>
      _CreatorRegistrationScreenState();
}

class _CreatorRegistrationScreenState extends State<CreatorRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _creator;
  bool _isRejected = false;
  String? _rejectionReason;
  String? _rejectionRemark;

  final _fullNameController = TextEditingController();
  final _icNumberController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _bankAccountController = TextEditingController();

  String? _selectedBank;
  bool _isLoading = false;
  bool _isSubmitted = false;

  AnimationController? _animController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final List<String> _banks = [
    'Maybank',
    'CIMB',
    'Public Bank',
    'RHB Bank',
    'Hong Leong Bank',
    'Bank Islam',
    'BSN',
    'AmBank',
    'Affin Bank',
    'UOB',
    'OCBC Bank',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _icNumberController.dispose();
    _recipientNameController.dispose();
    _bankAccountController.dispose();
    _animController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController!, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController!, curve: Curves.easeOut));
    _animController!.forward();
    _loadCreatorApplication();
  }

  Future<void> _loadCreatorApplication() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('creators')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (res != null) {
      setState(() {
        _creator = res;
        _isRejected = res['status'] == 'rejected';
        _rejectionReason = res['rejection_reason'];
        _rejectionRemark = res['rejection_remark'];

        // Pre-fill form
        _fullNameController.text = res['full_name'] ?? '';
        _icNumberController.text = res['ic_number'] ?? '';
        _recipientNameController.text = res['recipient_name'] ?? '';
        _bankAccountController.text = res['bank_account'] ?? '';
        _selectedBank = res['bank_name'];
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = {
        'full_name': _fullNameController.text.trim(),
        'ic_number': _icNumberController.text.trim(),
        'recipient_name': _recipientNameController.text.trim(),
        'bank_account': _bankAccountController.text.trim(),
        'bank_name': _selectedBank,
        'status': 'pending',
        'rejection_reason': null,
        'rejection_remark': null,
      };

      if (_creator != null) {
        // 🔁 RESUBMIT (UPDATE)
        await supabase.from('creators').update(data).eq('user_id', user.id);
      } else {
        // 🆕 FIRST SUBMISSION
        await supabase.from('creators').insert({'user_id': user.id, ...data});
      }

      setState(() => _isSubmitted = true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return WillPopScope(
        onWillPop: () async {
          // Just go back to BottomNavController (home)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const BottomNavController(initialIndex: 0),
            ),
          );
          return false; // Prevent default back
        },
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Center(
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ✅ Your same submission success UI here
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 80,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Application Submitted!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const BottomNavController(initialIndex: 0),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Home'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF58C1D1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF58C1D1), Color(0xFF45A5B5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF58C1D1).withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Become a Creator",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Start your journey today",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
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

            // Form
            Expanded(
              child: _fadeAnimation == null
                  ? SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: Form(key: _formKey, child: _buildFormContent()),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation!,
                      child: SlideTransition(
                        position: _slideAnimation!,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: _buildFormContent(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rejection Notice
        if (_isRejected)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Application Rejected",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Reason:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _rejectionReason ?? "No reason provided",
                        style: TextStyle(fontSize: 14, color: Colors.red[700]),
                      ),
                      if (_rejectionRemark != null) ...[
                        SizedBox(height: 12),
                        Text(
                          "Additional Note:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _rejectionRemark!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Info Card
        if (!_isRejected) ...[
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF58C1D1).withOpacity(0.1),
                  Color(0xFF45A5B5).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF58C1D1).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF58C1D1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Your application will be reviewed by our admin team. You'll be notified once approved.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2C3E50),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

        // Form Fields
        _buildFormField(
          label: "Full Name (as per IC/Passport)",
          controller: _fullNameController,
          icon: Icons.person_outline,
          hint: "Enter your full name",
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),

        _buildFormField(
          label: "IC Number",
          controller: _icNumberController,
          icon: Icons.badge_outlined,
          hint: "Enter your IC number",
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your IC number';
            }
            return null;
          },
        ),

        _buildFormField(
          label: "Recipient Name",
          controller: _recipientNameController,
          icon: Icons.account_box_outlined,
          hint: "Enter the recipient name",
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the recipient name';
            }
            return null;
          },
        ),

        // Bank Dropdown
        Text(
          "Bank Name",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedBank,
            decoration: InputDecoration(
              hintText: "Select your bank",
              prefixIcon: Icon(
                Icons.account_balance_outlined,
                color: Color(0xFF58C1D1),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF58C1D1), width: 2),
              ),
            ),
            items: _banks
                .map((bank) => DropdownMenuItem(value: bank, child: Text(bank)))
                .toList(),
            onChanged: (value) => setState(() => _selectedBank = value),
            validator: (value) =>
                value == null ? 'Please select your bank' : null,
          ),
        ),
        SizedBox(height: 20),

        _buildFormField(
          label: "Bank Account Number",
          controller: _bankAccountController,
          icon: Icons.account_balance_wallet_outlined,
          hint: "Enter your bank account number",
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your bank account number';
            }
            return null;
          },
        ),

        SizedBox(height: 32),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF58C1D1),
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Color(0xFF58C1D1).withOpacity(0.4),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRejected ? Icons.refresh : Icons.send,
                        color: Colors.white,
                      ),
                      SizedBox(width: 12),
                      Text(
                        _isRejected
                            ? "Resubmit Application"
                            : "Submit Application",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Color(0xFF58C1D1)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF58C1D1), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade300),
              ),
            ),
            validator: validator,
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
