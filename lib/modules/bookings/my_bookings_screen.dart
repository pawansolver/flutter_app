import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';

// ─── App Colors ───────────────────────────────────────────────────
class _AppColors {
  static const background = Color(0xFFF9FAFB);
  static const primaryText = Color(0xFF111827);
  static const subText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const brandOrange = Color(0xFFFF6B00);
  static const brandGreen = Color(0xFF10B981);
}

// ─── Booking Model ────────────────────────────────────────────────
class BookingModel {
  final String id;
  final String serviceName;
  final String providerName;
  final String dateTime;
  final String price;
  final String status; // 'Confirmed', 'Pending', 'Completed', 'Cancelled'
  final String category;
  final bool isActive;

  const BookingModel({
    required this.id,
    required this.serviceName,
    required this.providerName,
    required this.dateTime,
    required this.price,
    required this.status,
    required this.category,
    required this.isActive,
  });
}

// ─── Dummy Data ───────────────────────────────────────────────────
final List<BookingModel> _activeBookings = [
  BookingModel(
    id: 'BK001',
    serviceName: 'AC Repair & Servicing',
    providerName: 'Ravi Electricals',
    dateTime: 'Today, 3:00 PM',
    price: '₹499',
    status: 'Confirmed',
    category: 'Electrician',
    isActive: true,
  ),
  BookingModel(
    id: 'BK002',
    serviceName: 'Home Deep Cleaning',
    providerName: 'CleanPro Services',
    dateTime: 'Tomorrow, 10:00 AM',
    price: '₹1,200',
    status: 'Pending',
    category: 'Cleaning',
    isActive: true,
  ),
  BookingModel(
    id: 'BK003',
    serviceName: 'Math Tutor – Class 10',
    providerName: 'Amit Srivastava',
    dateTime: 'Sat, 5 Jul – 5:00 PM',
    price: '₹300/hr',
    status: 'Confirmed',
    category: 'Tutor',
    isActive: true,
  ),
];

final List<BookingModel> _pastBookings = [
  BookingModel(
    id: 'BK004',
    serviceName: 'Plumbing – Pipe Leak Fix',
    providerName: 'Suresh Plumbing Co.',
    dateTime: 'Mon, 30 Jun – 11:00 AM',
    price: '₹350',
    status: 'Completed',
    category: 'Plumber',
    isActive: false,
  ),
  BookingModel(
    id: 'BK005',
    serviceName: 'Sofa Dry Cleaning',
    providerName: 'FreshHome Cleaners',
    dateTime: 'Sun, 29 Jun – 2:00 PM',
    price: '₹800',
    status: 'Completed',
    category: 'Cleaning',
    isActive: false,
  ),
  BookingModel(
    id: 'BK006',
    serviceName: 'Inverter Battery Check',
    providerName: 'PowerFix Solutions',
    dateTime: 'Fri, 27 Jun – 9:00 AM',
    price: '₹150',
    status: 'Cancelled',
    category: 'Electrician',
    isActive: false,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Active, 1 = Past

  // ─── Status Badge ──────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color textColor;

    switch (status) {
      case 'Confirmed':
        bg = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        break;
      case 'Pending':
        bg = const Color(0xFFFFEDD5);
        textColor = const Color(0xFF9A3412);
        break;
      case 'Completed':
        bg = const Color(0xFFE0F2FE);
        textColor = const Color(0xFF0369A1);
        break;
      case 'Cancelled':
        bg = const Color(0xFFFFE4E6);
        textColor = const Color(0xFF9F1239);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        textColor = _AppColors.subText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ─── Category Icon ─────────────────────────────────────────────
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Electrician':
        return Icons.electrical_services_outlined;
      case 'Cleaning':
        return Icons.cleaning_services_outlined;
      case 'Plumber':
        return Icons.plumbing_outlined;
      case 'Tutor':
        return Icons.school_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  // ─── Booking Card ──────────────────────────────────────────────
  Widget _buildBookingCard(BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Category icon + Service Name + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _AppColors.border),
                  ),
                  child: Icon(
                    _getCategoryIcon(booking.category),
                    color: _AppColors.brandOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.providerName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _AppColors.subText,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(booking.status),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: _AppColors.border),
            const SizedBox(height: 14),

            // ── Details Row: Date & Price
            Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 16, color: _AppColors.subText),
                const SizedBox(width: 6),
                Text(
                  booking.dateTime,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _AppColors.subText,
                  ),
                ),
                const Spacer(),
                Text(
                  booking.price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.primaryText,
                  ),
                ),
              ],
            ),

            // ── Action Buttons (only for active bookings)
            if (booking.isActive) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  // Call Provider
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calling provider...')),
                        );
                      },
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Call Provider'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AppColors.brandGreen,
                        side: const BorderSide(color: _AppColors.brandGreen),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Cancel Booking
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showCancelDialog(context, booking.serviceName);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9F1239),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String serviceName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to cancel "$serviceName"? This action cannot be undone.',
          style: const TextStyle(color: _AppColors.subText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Custom Tab Bar ────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        children: [
          _buildTab('Active', 0, Icons.timelapse_outlined),
          _buildTab('Past', 1, Icons.history_outlined),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: _AppColors.border)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? _AppColors.brandOrange
                    : _AppColors.subText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? _AppColors.primaryText
                      : _AppColors.subText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: _AppColors.border),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 36, color: _AppColors.subText),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Bookings Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your bookings will appear here\nonce you book a service.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _AppColors.subText),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookings =
        _selectedTab == 0 ? _activeBookings : _pastBookings;

    void handleBack() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        backgroundColor: _AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _AppColors.primaryText),
            onPressed: handleBack,
          ),
          title: const Text(
            'My Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _AppColors.primaryText,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _AppColors.border),
          ),
        ),
        body: Column(
          children: [
            _buildTabBar(),
            const SizedBox(height: 16),
            Expanded(
              child: bookings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) => _buildBookingCard(bookings[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
