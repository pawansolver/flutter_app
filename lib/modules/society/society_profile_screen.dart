import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

class SocietyProfileScreen extends StatefulWidget {
  final int societyId;
  final String userRole; // 'admin' | 'committee' | 'resident' | etc.

  const SocietyProfileScreen({
    super.key,
    required this.societyId,
    required this.userRole,
  });

  @override
  State<SocietyProfileScreen> createState() => _SocietyProfileScreenState();
}

class _SocietyProfileScreenState extends State<SocietyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _societyService = SocietyService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  SocietyProfileModel? _profile;

  late final TextEditingController _nameController;
  late final TextEditingController _regController;
  late final TextEditingController _addressController;
  late final TextEditingController _flatsController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  bool get _canEdit => widget.userRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _regController = TextEditingController();
    _addressController = TextEditingController();
    _flatsController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regController.dispose();
    _addressController.dispose();
    _flatsController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _societyService.getSocietyDetail(widget.societyId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.societyName;
          _regController.text = profile.registrationNo ?? '';
          _addressController.text = profile.address ?? '';
          _flatsController.text = profile.totalFlats != null ? profile.totalFlats.toString() : '';
          _latController.text = profile.latitude != null ? profile.latitude.toString() : '';
          _lngController.text = profile.longitude != null ? profile.longitude.toString() : '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updateData = <String, dynamic>{
        'society_name': _nameController.text.trim(),
        'registration_no': _regController.text.trim().isEmpty ? null : _regController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        if (_flatsController.text.trim().isNotEmpty)
          'total_flats': int.tryParse(_flatsController.text.trim()),
        if (_latController.text.trim().isNotEmpty)
          'latitude': double.tryParse(_latController.text.trim()),
        if (_lngController.text.trim().isNotEmpty)
          'longitude': double.tryParse(_lngController.text.trim()),
      };

      final updated = await _societyService.updateSociety(widget.societyId, updateData);
      if (mounted) {
        setState(() {
          _profile = updated;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Society profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Profile'),
        actions: [
          if (_canEdit && !_isLoading && _profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Role / Permission banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _canEdit
                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _canEdit ? Icons.admin_panel_settings : Icons.info_outline,
                                  color: _canEdit ? theme.colorScheme.primary : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _canEdit
                                        ? 'You are an authorized Society Admin. You can edit society details.'
                                        : 'View-only mode. Administrative modifications require Society Admin privileges.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _canEdit ? theme.colorScheme.primary : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Society Name
                          TextFormField(
                            controller: _nameController,
                            enabled: _canEdit,
                            decoration: const InputDecoration(
                              labelText: 'Society Name *',
                              prefixIcon: Icon(Icons.apartment),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Society name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Registration No
                          TextFormField(
                            controller: _regController,
                            enabled: _canEdit,
                            decoration: const InputDecoration(
                              labelText: 'Registration Number',
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Total Flats
                          TextFormField(
                            controller: _flatsController,
                            enabled: _canEdit,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Flats',
                              prefixIcon: Icon(Icons.holiday_village_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Address
                          TextFormField(
                            controller: _addressController,
                            enabled: _canEdit,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Full Address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Coordinates
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latController,
                                  enabled: _canEdit,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lngController,
                                  enabled: _canEdit,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Metadata card
                          if (_profile?.createdAt != null)
                            Card(
                              elevation: 0,
                              color: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Registration Info', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('Created: ${_profile!.createdAt!.toLocal().toString().split(' ')[0]}'),
                                    if (_profile!.adminUser != null)
                                      Text('Owner / Primary Admin: ${_profile!.adminUser!['userName'] ?? 'User #${_profile!.createdBy}'}'),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
