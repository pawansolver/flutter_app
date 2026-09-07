import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import '../../../widgets/custom_widgets.dart';

class CreateServiceFlowScreen extends StatefulWidget {
  const CreateServiceFlowScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<CreateServiceFlowScreen> createState() => _CreateServiceFlowScreenState();
}

class _CreateServiceFlowScreenState extends State<CreateServiceFlowScreen> {
  final _service = ServiceMarketplaceService();
  int _currentStep = 0; // 0: Basic Info, 1: Details, 2: Availability, 3: Review & Submit

  // Form Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController(text: '1 hour');

  // Selected Category
  List<ServiceCategoryModel> _categories = [];
  ServiceCategoryModel? _selectedCategory;
  bool _loadingCategories = true;

  // Availability state (Step 3)
  final Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
  String _selectedHours = '09:00 AM – 06:00 PM';
  bool _isAvailableImmediate = true;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = list;
        if (list.isNotEmpty) {
          if (widget.initialCategory != null) {
            _selectedCategory = list.firstWhere(
              (c) => c.name.toLowerCase() == widget.initialCategory!.toLowerCase(),
              orElse: () => list.first,
            );
          } else {
            _selectedCategory = list.first;
          }
        }
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showToast('Please enter a service name');
        return false;
      }
      if (_selectedCategory == null) {
        _showToast('Please select a service category');
        return false;
      }
      if (_descController.text.trim().isEmpty) {
        _showToast('Please enter a short description of what is included');
        return false;
      }
    } else if (step == 1) {
      if (_priceController.text.trim().isEmpty) {
        _showToast('Please enter the service price in ₹');
        return false;
      }
      final parsed = double.tryParse(_priceController.text.trim());
      if (parsed == null || parsed <= 0) {
        _showToast('Please enter a valid price amount');
        return false;
      }
    } else if (step == 2) {
      if (_selectedDays.isEmpty) {
        _showToast('Please select at least one available working day');
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submitService();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111827),
      ),
    );
  }

  Future<void> _submitService() async {
    setState(() => _isSubmitting = true);
    try {
      final price = double.tryParse(_priceController.text.trim());
      final created = await _service.createListing(
        title: _nameController.text.trim(),
        description: _descController.text.trim(),
        price: price,
        duration: _durationController.text.trim(),
        isAvailable: _isAvailableImmediate,
        categoryId: _selectedCategory?.id,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Success feedback dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text(
                'Service Created!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            '${created.title} has been successfully published to your neighborhood catalogue.',
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop(); // dismiss dialog
                Navigator.of(context).pop(true); // return with refresh flag
              },
              child: const Text('Back to Dashboard', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showToast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: _prevStep,
        ),
        title: const Text(
          'Create Service',
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
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator Header
            _buildStepIndicator(),
            // Step Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(),
              ),
            ),
            // Bottom Action Controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Basic Info', 'Details', 'Availability', 'Review'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isPassed = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPassed
                                  ? const Color(0xFF10B981)
                                  : isCurrent
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFE5E7EB),
                            ),
                            child: Center(
                              child: isPassed
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent ? Colors.white : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              steps[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                color: isCurrent ? const Color(0xFF111827) : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: isPassed || isCurrent
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1BasicInfo();
      case 1:
        return _buildStep2ServiceDetails();
      case 2:
        return _buildStep3Availability();
      case 3:
        return _buildStep4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Basic Information ───────────────────────────────────────────
  Widget _buildStep1BasicInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1 — Basic Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Give your service an accurate title and pick the category where neighbors can find it.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          // Service Name
          const Text(
            'Service Name *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: 'e.g. Split AC Filter Cleaning & Gas Refill',
            controller: _nameController,
          ),
          const SizedBox(height: 18),

          // Category Dropdown
          const Text(
            'Category *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          if (_loadingCategories)
            const LinearProgressIndicator(color: Color(0xFF111827))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ServiceCategoryModel>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<ServiceCategoryModel>(
                      value: cat,
                      child: Row(
                        children: [
                          const Icon(Icons.handyman_outlined, size: 18, color: Color(0xFFFF6B00)),
                          const SizedBox(width: 10),
                          Text(
                            cat.name,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (cat) {
                    if (cat != null) setState(() => _selectedCategory = cat);
                  },
                ),
              ),
            ),
          const SizedBox(height: 18),

          // Description
          const Text(
            'Description *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Explain what is included in this service, your working approach, and any tools required.',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Service Details ─────────────────────────────────────────────
  Widget _buildStep2ServiceDetails() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2 — Service Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set your standard pricing and estimated completion duration.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          // Price Field
          const Text(
            'Service Price (₹) *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ),
              hintText: '499',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Duration Field
          const Text(
            'Estimated Duration',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: 'e.g. 45 mins, 1 hour, 2-3 hours',
            controller: _durationController,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['30 mins', '1 hour', '2 hours', 'Half day'].map((dur) {
              return ActionChip(
                label: Text(dur, style: const TextStyle(fontSize: 12)),
                backgroundColor: const Color(0xFFF3F4F6),
                onPressed: () => setState(() => _durationController.text = dur),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Active Availability Switch
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Activate Immediately',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Allow neighbors to discover & request right away',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                Switch(
                  value: _isAvailableImmediate,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) => setState(() => _isAvailableImmediate = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Service Availability ────────────────────────────────────────
  Widget _buildStep3Availability() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3 — Service Availability',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select which days of the week you take appointments for this service.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          const Text(
            'Working Days *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day),
                selected: isSelected,
                selectedColor: const Color(0xFF10B981),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: const Color(0xFFF3F4F6),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const Text(
            'Operational Hours',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Color(0xFF2B7BB9)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedHours,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showHoursSelectorSheet();
                  },
                  child: const Text('Change', style: TextStyle(color: Color(0xFF2B7BB9), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF2B7BB9)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Full custom slot scheduling and holiday blocks can be fine-tuned in Provider Availability Settings.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHoursSelectorSheet() {
    final options = [
      '08:00 AM – 04:00 PM',
      '09:00 AM – 06:00 PM',
      '10:00 AM – 07:00 PM',
      'Flexible / On-Demand',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Working Hours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 16),
            ...options.map((opt) => ListTile(
              title: Text(opt),
              trailing: opt == _selectedHours ? const Icon(Icons.check, color: Color(0xFF10B981)) : null,
              onTap: () {
                setState(() => _selectedHours = opt);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ── Step 4: Review & Submit ─────────────────────────────────────────────
  Widget _buildStep4Review() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Step 4 — Review & Submit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isAvailableImmediate ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isAvailableImmediate ? 'Active' : 'Draft',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isAvailableImmediate ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Confirm all details before publishing this listing to neighbors.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const Divider(height: 28, color: Color(0xFFE5E7EB)),

              _buildReviewRow('Service Name', _nameController.text.trim()),
              const SizedBox(height: 12),
              _buildReviewRow('Category', _selectedCategory?.name ?? 'General'),
              const SizedBox(height: 12),
              _buildReviewRow('Price', '₹${_priceController.text.trim()}'),
              const SizedBox(height: 12),
              _buildReviewRow('Duration', _durationController.text.trim().isNotEmpty ? _durationController.text.trim() : 'Standard'),
              const SizedBox(height: 12),
              _buildReviewRow('Working Days', _selectedDays.join(', ')),
              const SizedBox(height: 12),
              _buildReviewRow('Hours', _selectedHours),
              const SizedBox(height: 16),

              const Text(
                'Description:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 4),
              Text(
                _descController.text.trim(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentStep == 3;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _isSubmitting ? null : _prevStep,
              child: const Text('Back', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _isSubmitting
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF111827)))
                : PrimaryButton(
                    text: isLast ? 'Create Service' : 'Continue',
                    onPressed: _nextStep,
                  ),
          ),
        ],
      ),
    );
  }
}
