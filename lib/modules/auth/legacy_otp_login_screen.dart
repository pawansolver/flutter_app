import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'otp_screen.dart';

class LegacyOtpLoginScreen extends StatefulWidget {
  const LegacyOtpLoginScreen({super.key});

  @override
  State<LegacyOtpLoginScreen> createState() => _LegacyOtpLoginScreenState();
}

class _LegacyOtpLoginScreenState extends State<LegacyOtpLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final mobile = _mobile.text.replaceAll(RegExp(r'\D'), '');
    final email = _email.text.trim().toLowerCase();
    try {
      await _auth.sendOtp(phoneNumber: mobile, email: email);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(identity: email, phoneNumber: mobile),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF10B981);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Login with email OTP'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: green,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Legacy OTP login',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Existing OTP-only accounts can continue here. You can set a password later from Profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[6-9]\d{9}$',
                      ).hasMatch(value?.replaceAll(RegExp(r'\D'), '') ?? '')
                      ? null
                      : 'Enter a valid 10-digit Indian mobile number',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a valid email',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
