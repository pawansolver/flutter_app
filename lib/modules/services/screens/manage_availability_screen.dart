import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';

class DaySchedule {
  final String dayName;
  bool isAvailable;
  TimeOfDay startTime;
  TimeOfDay endTime;

  DaySchedule({
    required this.dayName,
    this.isAvailable = true,
    this.startTime = const TimeOfDay(hour: 9, minute: 0),
    this.endTime = const TimeOfDay(hour: 18, minute: 0),
  });

  DaySchedule copyWith({
    bool? isAvailable,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return DaySchedule(
      dayName: dayName,
      isAvailable: isAvailable ?? this.isAvailable,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class ManageAvailabilityScreen extends StatefulWidget {
  const ManageAvailabilityScreen({super.key, this.initialService});

  final ServiceListingModel? initialService;

  @override
  State<ManageAvailabilityScreen> createState() => _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  final _service = ServiceMarketplaceService();

  bool _loading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<ServiceListingModel> _services = [];
  ServiceListingModel? _selectedService;
  bool _currentServiceAvailable = true;

  // 7-day schedule
  final List<DaySchedule> _weeklySchedule = [
    DaySchedule(dayName: 'Monday', isAvailable: true, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0)),
    DaySchedule(dayName: 'Tuesday', isAvailable: true, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0)),
    DaySchedule(dayName: 'Wednesday', isAvailable: true, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0)),
    DaySchedule(dayName: 'Thursday', isAvailable: true, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0)),
    DaySchedule(dayName: 'Friday', isAvailable: true, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0)),
    DaySchedule(dayName: 'Saturday', isAvailable: true, startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 16, minute: 0)),
    DaySchedule(dayName: 'Sunday', isAvailable: false, startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 14, minute: 0)),
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final services = await _service.getProviderListings();
      if (!mounted) return;
      setState(() {
        _services = services;
        if (widget.initialService != null) {
          final matched = services.where((s) => s.id == widget.initialService!.id);
          _selectedService = matched.isNotEmpty ? matched.first : (services.isNotEmpty ? services.first : null);
        } else {
          _selectedService = services.isNotEmpty ? services.first : null;
        }
        _currentServiceAvailable = _selectedService?.isAvailable ?? true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    final formattedHour = hour.toString().padLeft(2, '0');
    return '$formattedHour:$minute $period';
  }

  Future<void> _pickTime(BuildContext context, DaySchedule schedule, bool isStart) async {
    final initial = isStart ? schedule.startTime : schedule.endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF111827),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          schedule.startTime = picked;
        } else {
          schedule.endTime = picked;
        }
      });
    }
  }

  void _applyMondayToWeekdays() {
    final monday = _weeklySchedule[0];
    setState(() {
      for (int i = 1; i < 5; i++) {
        _weeklySchedule[i] = _weeklySchedule[i].copyWith(
          isAvailable: monday.isAvailable,
          startTime: monday.startTime,
          endTime: monday.endTime,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Monday schedule applied to Tuesday – Friday'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyToAllDays() {
    final monday = _weeklySchedule[0];
    setState(() {
      for (int i = 1; i < _weeklySchedule.length; i++) {
        _weeklySchedule[i] = _weeklySchedule[i].copyWith(
          isAvailable: monday.isAvailable,
          startTime: monday.startTime,
          endTime: monday.endTime,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Monday schedule copied to all 7 days'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetSchedule() {
    setState(() {
      for (int i = 0; i < 5; i++) {
        _weeklySchedule[i] = _weeklySchedule[i].copyWith(
          isAvailable: true,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
        );
      }
      _weeklySchedule[5] = _weeklySchedule[5].copyWith(
        isAvailable: true,
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
      );
      _weeklySchedule[6] = _weeklySchedule[6].copyWith(
        isAvailable: false,
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 0),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Schedule reset to standard hours'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      if (_selectedService != null) {
        await _service.updateListing(
          _selectedService!.id,
          isAvailable: _currentServiceAvailable,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Availability and schedule saved successfully')),
            ],
          ),
          backgroundColor: const Color(0xFF111827),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save availability: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Manage Availability',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Set when customers can book your services',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF111827)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Failed to load services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _loadServices,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1 — Service Selection
          _buildServiceSelectionSection(),
          const SizedBox(height: 20),

          // Section 2 — Weekly Schedule
          _buildWeeklyScheduleSection(),
          const SizedBox(height: 20),

          // Section 3 — Quick Controls
          _buildQuickControlsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildServiceSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Service',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure availability rules for your listed services',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (_services.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'No services listed yet. Availability applies to your general profile.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedService?.id,
                  items: _services.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(
                        '${s.title} (${s.categoryName ?? "General"})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final chosen = _services.firstWhere((s) => s.id == val);
                      setState(() {
                        _selectedService = chosen;
                        _currentServiceAvailable = chosen.isAvailable;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedService?.title ?? 'Service Status',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentServiceAvailable ? 'Active for bookings' : 'Temporarily paused',
                        style: TextStyle(
                          fontSize: 12,
                          color: _currentServiceAvailable ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _currentServiceAvailable,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() => _currentServiceAvailable = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Weekly Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              Text(
                'Operating Hours',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _weeklySchedule.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0xFFF3F4F6)),
            ),
            itemBuilder: (context, index) {
              final day = _weeklySchedule[index];
              return _buildDayRow(day);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(DaySchedule day) {
    return Row(
      children: [
        // Day name + Available toggle
        SizedBox(
          width: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.dayName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 2),
              Text(
                day.isAvailable ? 'Available' : 'Unavailable',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: day.isAvailable ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),

        // Toggle Switch
        Switch(
          value: day.isAvailable,
          activeThumbColor: const Color(0xFF10B981),
          onChanged: (val) {
            setState(() => day.isAvailable = val);
          },
        ),
        const SizedBox(width: 4),

        // Hours Pickers (or Unavailable pill)
        Expanded(
          child: day.isAvailable
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _pickTime(context, day, true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          _formatTime(day.startTime),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('—', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
                    ),
                    InkWell(
                      onTap: () => _pickTime(context, day, false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          _formatTime(day.endTime),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                      ),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Day Off',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQuickControlsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Controls',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            onPressed: _applyMondayToWeekdays,
            icon: const Icon(Icons.date_range, size: 18, color: Color(0xFF2B7BB9)),
            label: const Text('Apply Monday schedule to weekdays (Mon–Fri)', style: TextStyle(color: Color(0xFF111827), fontSize: 13)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            onPressed: _copyToAllDays,
            icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF10B981)),
            label: const Text('Copy Monday schedule to all 7 days', style: TextStyle(color: Color(0xFF111827), fontSize: 13)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFEF4444)),
            ),
            onPressed: _resetSchedule,
            icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFEF4444)),
            label: const Text('Reset schedule to default hours', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save Availability',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
      ),
    );
  }
}
