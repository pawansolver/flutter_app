import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Privacy & Terms',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy for smartgali',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: July 2026',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '1. Data Collection',
              content:
                  'We collect information you provide directly to us when you create an account, update your profile, use our services, or communicate with us. This includes your name, contact details, address, and any local community interaction data to provide a better neighbourhood experience.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '2. User Privacy & Security',
              content:
                  'Your privacy is our utmost priority. We employ industry-standard encryption to safeguard your data. We do not sell your personal data to third parties. Information shared within your local society or neighbourhood groups is restricted to verified members to ensure community safety.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '3. Data Usage',
              content:
                  'We use the collected data to verify local residency, process society-related complaints and approvals, notify you about neighbourhood events, and improve our app\'s functionality. Location services are only used to recommend nearby communities and businesses.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '4. Terms of Service',
              content:
                  'By using smartgali, you agree to maintain a respectful environment within your digital community. Spam, harassment, or unauthorized commercial activities in neighbourhood groups will lead to account suspension.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '5. Contact Us',
              content:
                  'If you have any questions or concerns about this Privacy Policy, please contact us via the "Help & Support" section in the app.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
