import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void _handleBack() {
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

  final List<Map<String, dynamic>> _newRequests = [
    {
      'clientName': 'Rajesh Gupta',
      'distance': '0.5 km away',
      'service': 'Tap Leakage Repair',
      'dateTime': 'Tue, Jul 2 • 10:00 AM',
      'status': 'pending',
    },
    {
      'clientName': 'Sunita Devi',
      'distance': '1.2 km away',
      'service': 'Bathroom Pipe Fitting',
      'dateTime': 'Wed, Jul 3 • 02:00 PM',
      'status': 'pending',
    },
    {
      'clientName': 'Manoj Sharma',
      'distance': '0.8 km away',
      'service': 'Motor Pump Repair',
      'dateTime': 'Thu, Jul 4 • 11:30 AM',
      'status': 'pending',
    },
  ];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Map<String, bool> _availability = {
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': false,
    'Fri': true,
    'Sat': true,
    'Sun': false,
  };
  final TextEditingController _hoursController =
      TextEditingController(text: '10 AM - 6 PM');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE1EAE4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: _handleBack,
          ),
          title: const Text(
            'Provider Center',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Quick Stats Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard('Active\nBookings', '3 Requests', const Color(0xFF111827)),
                const SizedBox(width: 12),
                _buildStatCard("This Week's\nEarnings", '₹4,500', const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildStatCard('Overall\nRating', '⭐ 4.8', const Color(0xFFFF6B00)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF6B00),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              indicatorColor: const Color(0xFFFF6B00),
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'New Requests'),
                Tab(text: 'My Schedule'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewRequestsTab(),
                _buildScheduleTab(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewRequestsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _newRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final req = _newRequests[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          req['clientName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            req['distance'],
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.build_outlined, size: 14, color: Color(0xFFFF6B00)),
                        const SizedBox(width: 6),
                        Text(
                          req['service'],
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          req['dateTime'],
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          setState(() => _newRequests.removeAt(index));
                        },
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Booking accepted from ${req['clientName']}"),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        child: const Text('Accept Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Availability',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toggle days when you are available for bookings.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _days.asMap().entries.map((entry) {
                final day = entry.value;
                final isAvailable = _availability[day] ?? false;
                final isLast = entry.key == _days.length - 1;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isAvailable ? const Color(0xFF111827) : Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isAvailable ? 'Available' : 'Off',
                            style: TextStyle(
                              color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isAvailable,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() => _availability[day] = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Available Hours',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hoursController,
            decoration: InputDecoration(
              hintText: 'e.g., 10 AM - 6 PM',
              prefixIcon: const Icon(Icons.access_time, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF111827)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schedule updated successfully.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              child: const Text(
                'Save Schedule',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
