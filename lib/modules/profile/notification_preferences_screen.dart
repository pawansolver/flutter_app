import 'package:flutter/material.dart';
import 'profile_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _service = ProfileService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Section 1: Push Notifications State
  bool _isSocietyAnnouncementsEnabled = true;
  bool _isComplaintUpdatesEnabled = true;
  bool _isVisitorAlertsEnabled = true;
  bool _isEventRemindersEnabled = true;
  bool _isCommunityChatEnabled = true;
  bool _isPromotionalOffersEnabled = false;

  // Section 2: Professional & Business Alerts State
  bool _isBookingRequestsEnabled = true;
  bool _isCustomerMessagesEnabled = true;

  // Section 3: Email Notifications State
  bool _isWeeklyDigestEnabled = true;
  bool _isInvoicesReceiptsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  bool _b(dynamic v, bool fallback) => v is bool ? v : fallback;

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getNotificationPreferences();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final push = (result.data!['pushNotifications'] as Map?) ?? {};
      final pro = (result.data!['professionalAlerts'] as Map?) ?? {};
      final email = (result.data!['emailNotifications'] as Map?) ?? {};
      setState(() {
        _isSocietyAnnouncementsEnabled = _b(push['societyAnnouncements'], true);
        _isComplaintUpdatesEnabled = _b(push['complaintUpdates'], true);
        _isVisitorAlertsEnabled = _b(push['visitorAlerts'], true);
        _isEventRemindersEnabled = _b(push['eventReminders'], true);
        _isCommunityChatEnabled = _b(push['communityChat'], true);
        _isPromotionalOffersEnabled = _b(push['promotionalOffers'], false);
        _isBookingRequestsEnabled = _b(pro['bookingRequests'], true);
        _isCustomerMessagesEnabled = _b(pro['customerMessages'], true);
        _isWeeklyDigestEnabled = _b(email['weeklyDigest'], true);
        _isInvoicesReceiptsEnabled = _b(email['invoicesReceipts'], true);
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'Failed to load notification preferences';
        _loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    final result = await _service.updateNotificationPreferences({
      "pushNotifications": {
        "societyAnnouncements": _isSocietyAnnouncementsEnabled,
        "complaintUpdates": _isComplaintUpdatesEnabled,
        "visitorAlerts": _isVisitorAlertsEnabled,
        "eventReminders": _isEventRemindersEnabled,
        "communityChat": _isCommunityChatEnabled,
        "promotionalOffers": _isPromotionalOffersEnabled,
      },
      "professionalAlerts": {
        "bookingRequests": _isBookingRequestsEnabled,
        "customerMessages": _isCustomerMessagesEnabled,
      },
      "emailNotifications": {
        "weeklyDigest": _isWeeklyDigestEnabled,
        "invoicesReceipts": _isInvoicesReceiptsEnabled,
      },
    });
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to save preferences'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notification Preferences',
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadPreferences,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_saving) const LinearProgressIndicator(),
                  if (_saving) const SizedBox(height: 16),
                  _buildSectionHeader('Push Notifications'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          title: 'Society Announcements',
                          subtitle: 'Urgent notices, water supply cuts, etc.',
                          value: _isSocietyAnnouncementsEnabled,
                          onChanged: (val) => setState(
                            () => _isSocietyAnnouncementsEnabled = val,
                          ),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Complaint Updates',
                          subtitle: 'Status changes on your raised tickets.',
                          value: _isComplaintUpdatesEnabled,
                          onChanged: (val) =>
                              setState(() => _isComplaintUpdatesEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Visitor & Security Alerts',
                          subtitle:
                              'Gate check-ins, pre-approvals, and delivery updates.',
                          value: _isVisitorAlertsEnabled,
                          onChanged: (val) =>
                              setState(() => _isVisitorAlertsEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Event Reminders',
                          subtitle: 'Updates on RSVPs and local events.',
                          value: _isEventRemindersEnabled,
                          onChanged: (val) =>
                              setState(() => _isEventRemindersEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Community & Chat',
                          subtitle:
                              'Direct messages, mentions, and new posts in Joined Groups.',
                          value: _isCommunityChatEnabled,
                          onChanged: (val) =>
                              setState(() => _isCommunityChatEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Promotional Offers',
                          subtitle: 'Local business discounts and deals.',
                          value: _isPromotionalOffersEnabled,
                          onChanged: (val) =>
                              setState(() => _isPromotionalOffersEnabled = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('Professional & Business Alerts'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          title: 'Booking Requests',
                          subtitle:
                              'Instant alerts for new client/resident requests (For Providers).',
                          value: _isBookingRequestsEnabled,
                          onChanged: (val) =>
                              setState(() => _isBookingRequestsEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Customer Messages',
                          subtitle:
                              'Inquiries from neighbours about your store or services.',
                          value: _isCustomerMessagesEnabled,
                          onChanged: (val) =>
                              setState(() => _isCustomerMessagesEnabled = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('Email Notifications'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          title: 'Weekly Digest',
                          subtitle:
                              'A summary of local happenings sent to your email.',
                          value: _isWeeklyDigestEnabled,
                          onChanged: (val) =>
                              setState(() => _isWeeklyDigestEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          title: 'Invoices & Receipts',
                          subtitle:
                              'Maintenance dues and transaction histories.',
                          value: _isInvoicesReceiptsEnabled,
                          onChanged: (val) =>
                              setState(() => _isInvoicesReceiptsEnabled = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _saving ? null : _savePreferences,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Preferences',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFE5E7EB));
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: _saving ? null : onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(
              0xFFFF6B00,
            ), // Brand Orange for active state
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
          ),
        ],
      ),
    );
  }
}
