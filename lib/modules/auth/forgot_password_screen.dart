import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'auth_flow.dart';
import 'email_auth_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final identifier = _identifier.text.trim();
    setState(() => _loading = true);
    try {
      await _auth.forgotPassword(identifier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an eligible account exists, a code has been sent to its email.',
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailAuthOtpScreen(
            purpose: AuthOtpPurpose.passwordReset,
            identifier: identifier,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
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
        title: const Text('Forgot password'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 72, color: green),
                const SizedBox(height: 24),
                const Text(
                  'Reset your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your email or mobile number. The verification code is delivered to the account email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email or mobile',
                    prefixIcon: Icon(Icons.person_search_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final valid = text.contains('@')
                        ? RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
                        : RegExp(r'^(?:\+?91)?[6-9]\d{9}$').hasMatch(text);
                    return valid
                        ? null
                        : 'Enter a valid email or Indian mobile number';
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
