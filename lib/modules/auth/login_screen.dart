import 'package:flutter/material.dart';
import 'otp_screen.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  // Detect if the entered value looks like an email
  bool _isEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  void _executeOtpDispatch() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    // Validate: must have both phone and email
    if (phone.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Both Phone Number and Email are required to proceed."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_isEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid email: '$email'. Please check and try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      bool isSent = await _authService.sendOtp(
        phoneNumber: phone,
        email: email,
      );
      if (isSent) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              identity: email,
              phoneNumber: phone,
            ), // Pass email & phone to OTP screen
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll("Exception: ", ""))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // --- Logo Section ---
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public, color: brandGreen, size: 36),
              ),
              const SizedBox(height: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'Smart',
                      style: TextStyle(color: Color(0xFFFF6B00)),
                    ),
                    TextSpan(
                      text: 'Gali',
                      style: TextStyle(color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
              const Text(
                'Your Digital Neighbourhood',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: brandGreen,
                ),
              ),
              const SizedBox(height: 16),

              // --- Tagline Section ---
              const Text(
                'Connect with your community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Buy, Sell, Help & Stay Updated\nall in your neighbourhood.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: subText, height: 1.4),
              ),
              const SizedBox(height: 8),

              // --- Background Image ---
              ClipPath(
                clipper: BottomCurveClipper(),
                child: Image.asset(
                  'assets/images/neighbourhood_bg.png',
                  width: double.infinity,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),

              // --- Input Section ---
              const Text(
                'Enter Mobile Number and Email', // ← updated label
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'OTP will be dispatched to your registered email address', // ← updated subtitle
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: subText),
              ),
              const SizedBox(height: 12),

              // --- FIELD 1: Mobile Input ---
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Enter your mobile number",
                  hintStyle: TextStyle(
                    color: subText.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: primaryText,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE5E7EB),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 16),

              // --- FIELD 2: Email Input ---
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,                    // ← prevents keyboard from corrupting email
                enableSuggestions: false,              // ← no autocomplete garbage
                textCapitalization: TextCapitalization.none, // ← no auto-uppercase
                onChanged: (val) {
                  // Strip leading/trailing spaces in real time
                  if (val != val.trim()) {
                    _emailController.value = _emailController.value.copyWith(
                      text: val.trim(),
                      selection: TextSelection.collapsed(offset: val.trim().length),
                    );
                  }
                },
                decoration: InputDecoration(
                  hintText: "Enter your email address",
                  hintStyle: TextStyle(
                    color: subText.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Icon(
                      Icons.email_outlined,
                      color: subText.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 16),

              // --- Continue Button ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _executeOtpDispatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Features Cards ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFeatureCard(
                    Icons.verified_user,
                    'Secure Login',
                    'Your data is 100%\nsafe with us',
                    brandGreen,
                  ),
                  _buildFeatureCard(
                    Icons.email_outlined,
                    'Email OTP',
                    'No SMS cost,\ninstant delivery',
                    brandGreen,
                  ),
                  _buildFeatureCard(
                    Icons.groups,
                    'Verified Community',
                    'Connect with trusted\nneighbours',
                    brandGreen,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Trust & Terms ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified, color: brandGreen, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Trusted by 10,000+ neighbours',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: brandGreen.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'By continuing, you agree to our Terms of Use\nand Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: subText, height: 1.5),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF9CA3AF),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
