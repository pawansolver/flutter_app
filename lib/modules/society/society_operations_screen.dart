import 'package:flutter/material.dart';

class SocietyOperationsScreen extends StatefulWidget {
  final int initialTab;
  const SocietyOperationsScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<SocietyOperationsScreen> createState() => _SocietyOperationsScreenState();
}

class _SocietyOperationsScreenState extends State<SocietyOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Complaints Data ---
  final List<Map<String, dynamic>> _complaints = [
    {'title': 'Street light not working', 'category': 'Electrical', 'date': 'Jun 28, 2025', 'status': 'Open'},
    {'title': 'Water leakage in Block B corridor', 'category': 'Plumbing', 'date': 'Jun 25, 2025', 'status': 'Resolved'},
    {'title': 'Stray dogs near main gate', 'category': 'Security', 'date': 'Jun 22, 2025', 'status': 'Open'},
    {'title': 'Lift not working on 5th floor', 'category': 'Maintenance', 'date': 'Jun 20, 2025', 'status': 'Resolved'},
  ];

  // --- Visitors Data ---
  final List<Map<String, dynamic>> _visitors = [
    {'name': 'Amazon Delivery', 'type': 'Delivery', 'time': 'Today, 02:00 PM', 'status': 'At Gate'},
    {'name': 'Ravi Sharma (Uncle)', 'type': 'Guest', 'time': 'Today, 05:30 PM', 'status': 'Expected'},
    {'name': 'Zomato Delivery', 'type': 'Delivery', 'time': 'Today, 07:15 PM', 'status': 'Expected'},
    {'name': 'Dr. Meena (Doctor)', 'type': 'Service', 'time': 'Tomorrow, 10:00 AM', 'status': 'Pre-Approved'},
  ];

  // --- Polls Data ---
  final List<Map<String, dynamic>> _polls = [
    {
      'question': 'What color should we paint the community hall?',
      'voted': false,
      'selectedOption': null,
      'options': ['Sky Blue', 'Warm Beige', 'Olive Green', 'Classic White'],
      'votes': [12, 34, 8, 21],
    },
    {
      'question': 'Should we install CCTV at the back gate?',
      'voted': true,
      'selectedOption': 'Yes, Immediately',
      'options': ['Yes, Immediately', 'Yes, but next month', 'No'],
      'votes': [67, 18, 5],
    },
    {
      'question': 'Which day suits best for monthly RWA meeting?',
      'voted': false,
      'selectedOption': null,
      'options': ['First Sunday', 'Last Saturday', 'Second Saturday'],
      'votes': [23, 45, 12],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFE1EAE4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Society Operations',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF6B00),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            indicatorColor: const Color(0xFFFF6B00),
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Complaints'),
              Tab(text: 'Visitors'),
              Tab(text: 'Polls'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildComplaintsTab(),
            _buildVisitorsTab(),
            _buildPollsTab(),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: COMPLAINTS ────────────────────────────────────────────────────
  Widget _buildComplaintsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6B00),
        elevation: 0,
        onPressed: () => _showNewComplaintModal(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _complaints.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _complaints[index];
          final isOpen = c['status'] == 'Open';
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFFF6B00).withOpacity(0.1)
                            : const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c['status'],
                        style: TextStyle(
                          color: isOpen ? const Color(0xFFFF6B00) : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c['category'],
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      c['date'],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNewComplaintModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Log New Complaint',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            _modalField('Complaint Title', 'e.g., Street light not working'),
            const SizedBox(height: 14),
            _modalField('Category', 'Electrical, Plumbing, Security...'),
            const SizedBox(height: 14),
            _modalField('Description', 'Describe the issue in detail...', maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complaint logged!'), backgroundColor: Color(0xFF10B981)),
                  );
                },
                child: const Text('Submit Ticket',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: VISITORS ─────────────────────────────────────────────────────
  Widget _buildVisitorsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        onPressed: () {},
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text('Pre-Approve Guest',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _visitors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final v = _visitors[index];
          final atGate = v['status'] == 'At Gate';
          final statusColor = atGate
              ? const Color(0xFFFF6B00)
              : v['status'] == 'Pre-Approved'
                  ? const Color(0xFF10B981)
                  : Colors.grey;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: atGate ? const Color(0xFFFF6B00) : const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(
                        v['type'] == 'Delivery' ? Icons.local_shipping_outlined : Icons.person_outline,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF111827))),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(v['time'],
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(v['status'],
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (atGate) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {},
                          child: const Text('Deny Entry'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Visitor approved!'),
                                  backgroundColor: Color(0xFF10B981)),
                            );
                          },
                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── TAB 3: POLLS ────────────────────────────────────────────────────────
  Widget _buildPollsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _polls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final poll = _polls[index];
        final List<String> options = List<String>.from(poll['options']);
        final List<int> votes = List<int>.from(poll['votes']);
        final int totalVotes = votes.fold(0, (a, b) => a + b);
        final bool hasVoted = poll['voted'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Active Poll',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (hasVoted) ...[
                    const SizedBox(width: 8),
                    const Text('• You voted',
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                poll['question'],
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              ...List.generate(options.length, (i) {
                final pct = totalVotes == 0 ? 0.0 : votes[i] / totalVotes;
                if (hasVoted) {
                  final isSelected = poll['selectedOption'] == options[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(options[i],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFFFF6B00)
                                        : const Color(0xFF111827))),
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? const Color(0xFFFF6B00)
                                        : Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isSelected
                                  ? const Color(0xFFFF6B00)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFFFF6B00),
                    title: Text(options[i],
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
                    value: options[i],
                    groupValue: poll['selectedOption'],
                    onChanged: (val) {
                      setState(() {
                        _polls[index]['selectedOption'] = val;
                        _polls[index]['voted'] = true;
                        _polls[index]['votes'][i] = votes[i] + 1;
                      });
                    },
                  );
                }
              }),
              if (!hasVoted)
                Text('$totalVotes votes cast',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (hasVoted)
                Text('${totalVotes + 1} votes cast',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _modalField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF111827))),
          ),
        ),
      ],
    );
  }
}
