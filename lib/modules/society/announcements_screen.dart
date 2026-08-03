import 'package:flutter/material.dart';

// ─── Colors ────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF9FAFB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
}

// ─── Model ─────────────────────────────────────────────────────────
class AnnouncementItem {
  final String category;
  final String title;
  final String description;
  final String dateTime;
  final bool isUrgent;

  const AnnouncementItem({
    required this.category,
    required this.title,
    required this.description,
    required this.dateTime,
    this.isUrgent = false,
  });
}

// ─── Dummy Data ────────────────────────────────────────────────────
final List<AnnouncementItem> dummyAnnouncements = [
  AnnouncementItem(
    category: 'Maintenance',
    title: 'Lift Maintenance Scheduled',
    description:
        'Lift maintenance is scheduled for Friday, 4 July between 2:00 PM – 5:00 PM. Please use staircases during this period. Inconvenience is regretted.',
    dateTime: 'Today, 10:30 AM',
    isUrgent: true,
  ),
  AnnouncementItem(
    category: 'General',
    title: 'Monthly RWA Meeting – July 2026',
    description:
        'All residents are cordially invited to attend the monthly RWA General Body Meeting on Sunday, 6 July at 11:00 AM in the Community Hall.',
    dateTime: 'Yesterday, 6:00 PM',
    isUrgent: false,
  ),
  AnnouncementItem(
    category: 'Security',
    title: 'New Visitor Entry Protocol',
    description:
        'Effective immediately, all visitors must register at the main gate using the smartgali app or provide a valid photo ID. Residents are requested to pre-approve their guests.',
    dateTime: '2 Jul, 9:00 AM',
    isUrgent: true,
  ),
  AnnouncementItem(
    category: 'Finance',
    title: 'Maintenance Due – Q3 2026',
    description:
        'Quarterly maintenance dues of ₹3,500 are due by 10th July 2026. Please pay via the smartgali app or bank transfer. Late fee of ₹100/day applicable after due date.',
    dateTime: '1 Jul, 12:00 PM',
    isUrgent: false,
  ),
  AnnouncementItem(
    category: 'Event',
    title: 'Independence Day Celebration',
    description:
        'Our society will celebrate Independence Day on 15th August at 8:00 AM in the main garden. Flag hoisting will be followed by breakfast and cultural performances.',
    dateTime: '30 Jun, 4:00 PM',
    isUrgent: false,
  ),
  AnnouncementItem(
    category: 'Maintenance',
    title: 'Water Tank Cleaning – Block B',
    description:
        'Water supply will be interrupted on 8th July (Tuesday) from 9 AM to 1 PM for annual tank cleaning in Block B. Please store water in advance.',
    dateTime: '29 Jun, 11:00 AM',
    isUrgent: false,
  ),
];

// ─── Screen ────────────────────────────────────────────────────────
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  // ── Category Badge
  _CategoryStyle _getCategoryStyle(String category) {
    switch (category) {
      case 'Maintenance':
        return _CategoryStyle(
          bg: const Color(0xFFFFEDD5),
          text: const Color(0xFF9A3412),
        );
      case 'Security':
        return _CategoryStyle(
          bg: const Color(0xFFFFE4E6),
          text: const Color(0xFF9F1239),
        );
      case 'Finance':
        return _CategoryStyle(
          bg: const Color(0xFFEFF6FF),
          text: const Color(0xFF1E40AF),
        );
      case 'Event':
        return _CategoryStyle(
          bg: const Color(0xFFF0FDF4),
          text: const Color(0xFF166534),
        );
      default: // General
        return _CategoryStyle(
          bg: const Color(0xFFF3F4F6),
          text: const Color(0xFF374151),
        );
    }
  }

  Widget _buildCategoryBadge(String category) {
    final style = _getCategoryStyle(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: style.text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Announcement Card
  Widget _buildCard(AnnouncementItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isUrgent ? const Color(0xFFFFF7F0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUrgent ? const Color(0xFFFFCB99) : _C.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badge + urgent icon
            Row(
              children: [
                _buildCategoryBadge(item.category),
                const Spacer(),
                if (item.isUrgent) ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: _C.orange,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Urgent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.orange,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              item.description,
              style: const TextStyle(fontSize: 13, color: _C.sub, height: 1.6),
            ),
            const SizedBox(height: 12),

            // Divider
            Container(height: 1, color: _C.border),
            const SizedBox(height: 10),

            // Timestamp
            Row(
              children: [
                const Icon(Icons.access_time_outlined, size: 14, color: _C.sub),
                const SizedBox(width: 5),
                Text(
                  item.dateTime,
                  style: const TextStyle(fontSize: 12, color: _C.sub),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Official Announcements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dummyAnnouncements.length,
        itemBuilder: (_, i) => _buildCard(dummyAnnouncements[i]),
      ),
    );
  }
}

// ─── Helper ────────────────────────────────────────────────────────
class _CategoryStyle {
  final Color bg;
  final Color text;
  const _CategoryStyle({required this.bg, required this.text});
}
