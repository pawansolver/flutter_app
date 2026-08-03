import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../settings/password_validators.dart';
import 'auth_flow.dart';
import 'login_screen.dart';

class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({
    super.key,
    required this.purpose,
    required this.sessionToken,
  });

  final AuthOtpPurpose purpose;
  final String sessionToken;

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (widget.purpose == AuthOtpPurpose.signup) {
        await _auth.createPassword(
          signupSessionToken: widget.sessionToken,
          password: _password.text,
        );
      } else {
        await _auth.resetPassword(
          resetToken: widget.sessionToken,
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            message: widget.purpose == AuthOtpPurpose.signup
                ? 'Account created successfully. Please sign in.'
                : 'Password reset successfully. Please sign in.',
          ),
        ),
        (_) => false,
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
    final isSignup = widget.purpose == AuthOtpPurpose.signup;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isSignup ? 'Create password' : 'New password'),
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
                const Icon(Icons.password_rounded, size: 72, color: green),
                const SizedBox(height: 22),
                Text(
                  isSignup ? 'Secure your account' : 'Choose a new password',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use 8–72 characters with uppercase, lowercase, a number, and a special character.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscureConfirm,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      validatePasswordConfirmation(value, _password.text),
                  onFieldSubmitted: (_) => _loading ? null : _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isSignup ? 'Create account' : 'Reset password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
