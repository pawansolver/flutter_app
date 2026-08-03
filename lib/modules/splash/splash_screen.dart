import 'package:flutter/material.dart';
import 'dart:async';
import '../auth/login_screen.dart';
import '../../services/auth_service.dart';
import '../dashboard/main_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for at least 2 seconds so the splash screen is visible
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        // User is already logged in → go to Main Dashboard (with bottom nav)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainDashboard()),
        );
      } else {
        // No token found, go to Login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logosmartgali.png',
              width: 150,
              height: 200,
              // If the logo image is not found, fallback to an icon for now
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.location_on,
                size: 150,
                color: Color(0xFFFF6B00),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'smartgali',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'India\'s neighbourhood Network',
              style: TextStyle(fontSize: 16, color: Color(0xFF10B981)),
            ),
          ],
        ),
      ),
    );
  }
}
