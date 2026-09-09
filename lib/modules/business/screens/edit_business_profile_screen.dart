import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class EditBusinessProfileScreen extends StatefulWidget {
  final BusinessProfileModel? profile;
  const EditBusinessProfileScreen({super.key, this.profile});

  @override
  State<EditBusinessProfileScreen> createState() => _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _hoursCtrl;
  late TextEditingController _categoryCtrl;

  bool _isSaving = false;
  bool _isDeleting = false;
  bool get isCreating => widget.profile == null;

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.businessName ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _hoursCtrl = TextEditingController(text: p?.operatingHours ?? '');
    _categoryCtrl = TextEditingController(text: p?.categoryName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _hoursCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      if (isCreating) {
        final newProfile = BusinessProfileModel(
          id: DateTime.now().millisecondsSinceEpoch,
          businessName: _nameCtrl.text.trim(),
          categoryName: _categoryCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          operatingHours: _hoursCtrl.text.trim().isNotEmpty ? _hoursCtrl.text.trim() : null,
          isVerified: false,
          isOpen: true,
        );
        await BusinessService().createBusinessProfile(newProfile);
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business profile created successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        final updated = widget.profile!.copyWith(
          businessName: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          operatingHours: _hoursCtrl.text.trim().isNotEmpty ? _hoursCtrl.text.trim() : null,
          categoryName: _categoryCtrl.text.trim(),
        );
        await BusinessService().updateBusinessProfile(updated);
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  Future<void> _deleteBusiness() async {
    if (widget.profile == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Business Profile?'),
        content: const Text(
          'Are you sure you want to delete your business profile? Your store, products, and offers will no longer be visible to neighbours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      await BusinessService().deleteBusinessProfile(widget.profile!.id);
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business profile deleted.')),
      );
      Navigator.pop(context, true);
    }
  }

  TimeOfDay _parseTime(String raw, TimeOfDay fallback) {
    try {
      final trimmed = raw.trim().toUpperCase();
      final isPm = trimmed.contains('PM');
      final isAm = trimmed.contains('AM');
      final clean = trimmed.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.isEmpty) return fallback;
      int hour = int.parse(parts[0].trim());
      int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return fallback;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.pm ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _timePickerThemeBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: _brandOrange,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _primaryDark,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _pickOperatingHours() async {
    TimeOfDay initialOpen = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay initialClose = const TimeOfDay(hour: 21, minute: 0);

    final currentText = _hoursCtrl.text.trim();
    if (currentText.contains('-')) {
      final segments = currentText.split('-');
      if (segments.length == 2) {
        initialOpen = _parseTime(segments[0], initialOpen);
        initialClose = _parseTime(segments[1], initialClose);
      }
    }

    // Step 1: Clock Dial for Opening Time
    final pickedOpen = await showTimePicker(
      context: context,
      initialTime: initialOpen,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'STEP 1: SELECT OPENING TIME (खुलने का समय)',
      confirmText: 'NEXT (CLOSING TIME)',
      cancelText: 'CANCEL',
      builder: _timePickerThemeBuilder,
    );

    if (pickedOpen == null || !mounted) return;

    // Step 2: Clock Dial for Closing Time
    final pickedClose = await showTimePicker(
      context: context,
      initialTime: initialClose,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'STEP 2: SELECT CLOSING TIME (बंद होने का समय)',
      confirmText: 'SET HOURS',
      cancelText: 'CANCEL',
      builder: _timePickerThemeBuilder,
    );

    if (pickedClose == null || !mounted) return;

    final formattedOpen = _formatTimeOfDay(pickedOpen);
    final formattedClose = _formatTimeOfDay(pickedClose);
    final result = '$formattedOpen - $formattedClose';

    setState(() {
      _hoursCtrl.text = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Operating hours set: $result'),
          ],
        ),
        backgroundColor: _brandGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  final List<String> _suggestedCategories = const [
    'Dairy & Milk',
    'Grocery & Kirana',
    'Bakery & Sweets',
    'Pharmacy & Health',
    'Fruits & Veggies',
    'Electronics',
    'Stationery',
    'Clothing & Tailor',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCreating ? 'Create Business Profile' : 'Edit Business Profile',
              style: const TextStyle(
                color: _primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              isCreating ? 'Enterprise Merchant Onboarding' : 'Storefront Configuration',
              style: const TextStyle(
                color: _subGrey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (!isCreating)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isDeleting ? null : _deleteBusiness,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCreating) _buildEnterpriseHeroBanner(),
              const SizedBox(height: 16),

              // Card 1: Storefront Identity
              _buildEnterpriseCard(
                icon: Icons.storefront_rounded,
                iconColor: _brandOrange,
                iconBg: const Color(0xFFFFF7ED),
                title: 'Storefront Identity',
                subtitle: 'Core details visible on neighbourhood search & listings',
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _buildInputDecoration(
                      labelText: 'Business / Shop Name *',
                      hintText: 'e.g., Sharma Grocery, City Fresh Dairy',
                      icon: Icons.storefront_outlined,
                      helperText: 'Official public name of your storefront',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Business Name is required' : null,
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _categoryCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: _buildInputDecoration(
                      labelText: 'Business Category *',
                      hintText: 'Select a suggestion or enter your category',
                      icon: Icons.category_outlined,
                      helperText: 'Helps customers filter by category in listings',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Category is required' : null,
                  ),
                  const SizedBox(height: 10),

                  // Category Suggestions Carousel
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _suggestedCategories.map((cat) {
                        final currentVal = _categoryCtrl.text.trim().toLowerCase();
                        final isSelected = currentVal == cat.toLowerCase() ||
                            currentVal.startsWith(cat.toLowerCase().split(' ').first);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(cat),
                            backgroundColor: isSelected ? _brandOrange : const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _categoryCtrl.text = cat;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: _buildInputDecoration(
                      labelText: 'Store Description',
                      hintText: 'Briefly describe your specialty products, home delivery service, and fresh items...',
                      icon: Icons.article_outlined,
                      helperText: 'Appears in the About tab on your storefront detail page',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card 2: Location & Contact
              _buildEnterpriseCard(
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'Location & Contact Details',
                subtitle: 'Helps neighbours navigate to your shop or place orders',
                children: [
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: _buildInputDecoration(
                      labelText: 'Store Address / Landmark *',
                      hintText: 'e.g., Shop #12, Central Market, Near Community Hall',
                      icon: Icons.location_on_outlined,
                      helperText: 'Exact physical address for local navigation',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _buildInputDecoration(
                      labelText: 'Contact Phone / WhatsApp *',
                      hintText: '98765 43210',
                      icon: Icons.phone_outlined,
                      helperText: 'Used by neighbours for direct calls and inquiries',
                      prefix: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _primaryDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Contact Phone is required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Operating Hours with Interactive Clock Dial
                  TextFormField(
                    controller: _hoursCtrl,
                    readOnly: true,
                    onTap: _pickOperatingHours,
                    decoration: _buildInputDecoration(
                      labelText: 'Store Operating Hours',
                      hintText: 'Tap to pick timings with clock dial',
                      icon: Icons.access_time_rounded,
                      helperText: 'Shows customers when your shop is open for business',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hoursCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: _subGrey),
                              tooltip: 'Clear',
                              onPressed: () => setState(() => _hoursCtrl.clear()),
                            ),
                          IconButton(
                            icon: const Icon(Icons.schedule_rounded, color: _brandOrange),
                            tooltip: 'Open Clock Dial',
                            onPressed: _pickOperatingHours,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Clock Presets & Launcher
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.access_time_filled, size: 14, color: Colors.white),
                          label: const Text('Open Clock Dial'),
                          backgroundColor: _brandOrange,
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onPressed: _pickOperatingHours,
                        ),
                        const SizedBox(width: 8),
                        ...['8:00 AM - 10:00 PM', '9:00 AM - 9:00 PM', '10:00 AM - 8:00 PM', 'Open 24 Hours'].map((preset) {
                          final isSelected = _hoursCtrl.text == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(preset),
                              backgroundColor: isSelected ? _brandOrange.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? _brandOrange : const Color(0xFF334155),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
                                ),
                              ),
                              onPressed: () {
                                setState(() => _hoursCtrl.text = preset);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trust & Discovery Banner
              _buildTrustNoticeBanner(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(isCreating ? Icons.rocket_launch_rounded : Icons.check_circle_rounded, size: 20),
              label: Text(
                isCreating ? 'Create Business Profile' : 'Save Changes',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Enterprise Hero Card ───────────────────────────────────────────────────
  Widget _buildEnterpriseHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _brandOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _brandOrange.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, color: _brandOrange, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'SMARTGALI COMMERCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _brandOrange,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Launch Your Digital Storefront',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Set up your store so neighbours and local residents can discover your products, see offers, and contact you directly.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFeaturePill(Icons.inventory_2_outlined, 'Catalog Showcase'),
              _buildFeaturePill(Icons.local_offer_outlined, 'Neighbourhood Deals'),
              _buildFeaturePill(Icons.chat_bubble_outline_rounded, 'Direct Inquiries'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Enterprise Card Layout ─────────────────────────────────────────────────
  Widget _buildEnterpriseCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: _subGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  // ── Modern Input Decoration Helper ─────────────────────────────────────────
  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
    String? helperText,
    Widget? prefix,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      prefix: prefix,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brandOrange, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  // ── Trust & Verification Banner ────────────────────────────────────────────
  Widget _buildTrustNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immediate Neighbourhood Visibility',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Once saved, your storefront is instantly discoverable by verified residents in your neighbourhood society and local listings.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF047857), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
