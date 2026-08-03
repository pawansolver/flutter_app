import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import 'auth_flow.dart';
import 'password_setup_screen.dart';

class EmailAuthOtpScreen extends StatefulWidget {
  const EmailAuthOtpScreen({
    super.key,
    required this.purpose,
    required this.identifier,
    this.name,
    this.mobile,
  });

  final AuthOtpPurpose purpose;
  final String identifier;
  final String? name;
  final String? mobile;

  @override
  State<EmailAuthOtpScreen> createState() => _EmailAuthOtpScreenState();
}

class _EmailAuthOtpScreenState extends State<EmailAuthOtpScreen> {
  final _otp = TextEditingController();
  final _auth = AuthService();
  Timer? _timer;
  int _seconds = 30;
  bool _loading = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the complete 6-digit code.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final token = widget.purpose == AuthOtpPurpose.signup
          ? await _auth.verifySignupOtp(
              email: widget.identifier,
              otp: _otp.text,
            )
          : await _auth.verifyResetOtp(
              identifier: widget.identifier,
              otp: _otp.text,
            );
      if (token.isEmpty) {
        throw const FormatException('Missing verification session.');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PasswordSetupScreen(purpose: widget.purpose, sessionToken: token),
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

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      if (widget.purpose == AuthOtpPurpose.signup) {
        await _auth.signup(
          name: widget.name!,
          mobile: widget.mobile!,
          email: widget.identifier,
        );
      } else {
        await _auth.forgotPassword(widget.identifier);
      }
      if (!mounted) return;
      _startTimer();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF10B981);
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 72,
                color: green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit code sent to the email associated with\n${widget.identifier}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loading ? null : _verify(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify code'),
              ),
              TextButton(
                onPressed: _seconds == 0 && !_resending ? _resend : null,
                child: _resending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _seconds == 0
                            ? 'Resend code'
                            : 'Resend in ${_seconds}s',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
