import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

/// Generic Enterprise Multi-Step Committee Builder Screen
///
/// Converts hardcoded security committee creation into a generic,
/// PBAC-driven enterprise committee builder with:
/// - Step 1: Committee Identity (Name, Category/Type, Description)
/// - Step 2: Related Operational Modules Selection
/// - Step 3: Granular Permissions Catalog (loaded dynamically from backend)
/// - Step 4: Operational Scope (Entire Society or Gate-Scoped)
/// - Step 5: Review & Final Confirmation
class SocietyCommitteeBuilderScreen extends StatefulWidget {
  final int societyId;
  final SocietyCommitteeModel? existingCommittee;

  const SocietyCommitteeBuilderScreen({
    super.key,
    required this.societyId,
    this.existingCommittee,
  });

  bool get isEditMode => existingCommittee != null;

  @override
  State<SocietyCommitteeBuilderScreen> createState() =>
      _SocietyCommitteeBuilderScreenState();
}

class _SocietyCommitteeBuilderScreenState
    extends State<SocietyCommitteeBuilderScreen> {
  final _societyService = SocietyService();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _descController;

  // Form State
  String _selectedCategory = 'security';
  String _scopeType = 'entire_society';
  int? _selectedGateId;
  String _status = 'active';

  // Backend Catalog Data
  List<Map<String, dynamic>> _availableModules = [];
  List<Map<String, dynamic>> _rawPermissions = [];
  List<Map<String, dynamic>> _categories = [];
  List<SocietyGateModel> _gates = [];

  // Selections
  final Set<String> _selectedModuleKeys = {};
  final Set<String> _selectedPermissions = {};

  @override
  void initState() {
    super.initState();
    final comm = widget.existingCommittee;
    _nameController = TextEditingController(text: comm?.name ?? '');
    _descController = TextEditingController(text: comm?.description ?? '');
    if (comm != null) {
      _selectedCategory = comm.committeeType;
      _scopeType = comm.scopeType;
      _selectedGateId = comm.scopeId;
      _status = comm.status;
      if (comm.permissions.isNotEmpty) {
        _selectedPermissions.addAll(comm.permissions);
      }
    }
    _loadCatalogAndData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _societyService.getCommitteePermissionCatalog(widget.societyId),
        _societyService.getGates(widget.societyId),
      ]);

      final catalog = results[0] as Map<String, dynamic>;
      final gates = results[1] as List<SocietyGateModel>;

      final rawMods = (catalog['modules'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final rawPerms = (catalog['permissions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final rawCats = (catalog['categories'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (mounted) {
        setState(() {
          _availableModules = rawMods;
          _rawPermissions = rawPerms;
          _categories = rawCats;
          _gates = gates;

          if (_gates.isNotEmpty && _selectedGateId == null) {
            _selectedGateId = _gates.first.id;
          }

          // If creating new committee, apply default recommended modules for default category
          if (!widget.isEditMode && _selectedModuleKeys.isEmpty) {
            _applyCategoryRecommendation(_selectedCategory);
          } else if (widget.isEditMode) {
            // Infer selected modules from existing permissions
            for (final p in _rawPermissions) {
              final code = p['code']?.toString() ?? '';
              final mod = p['module']?.toString() ?? '';
              if (_selectedPermissions.contains(code) && mod.isNotEmpty) {
                _selectedModuleKeys.add(mod);
              }
            }
            if (_selectedModuleKeys.isEmpty) {
              _applyCategoryRecommendation(_selectedCategory);
            }
          }

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

  void _applyCategoryRecommendation(String categoryKey) {
    final cat = _categories.firstWhere(
      (c) => c['key'] == categoryKey,
      orElse: () => {},
    );
    final rec = (cat['recommended_modules'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    _selectedModuleKeys.clear();
    _selectedModuleKeys.addAll(rec);

    // Auto-select essential read permissions for recommended modules
    if (!widget.isEditMode) {
      _selectedPermissions.clear();
      for (final p in _rawPermissions) {
        final mod = p['module']?.toString() ?? '';
        final code = p['code']?.toString() ?? '';
        if (_selectedModuleKeys.contains(mod)) {
          // Pre-check standard read/view permissions
          if (code.endsWith('.read') || code.endsWith('.view') || code.endsWith('.create_gate_entry')) {
            _selectedPermissions.add(code);
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPermissions {
    return _rawPermissions.where((p) {
      final mod = p['module']?.toString() ?? '';
      return _selectedModuleKeys.contains(mod);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _permissionsByModule {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in _filteredPermissions) {
      final mod = p['module']?.toString() ?? 'other';
      map.putIfAbsent(mod, () => []).add(p);
    }
    return map;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    if (_selectedModuleKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one operational module in Step 2.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one permission in Step 3.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _currentStep = 2);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();
      final perms = _selectedPermissions.toList();
      final modules = _selectedModuleKeys.toList();

      if (widget.isEditMode) {
        await _societyService.updateCommittee(
          widget.existingCommittee!.id,
          widget.societyId,
          name: name,
          description: desc,
          committeeType: _selectedCategory,
          scopeType: _scopeType,
          scopeId: _scopeType == 'gate' ? _selectedGateId : null,
          scopeGateIds: _scopeType == 'gate' && _selectedGateId != null ? [_selectedGateId!] : null,
          selectedModules: modules,
          permissions: perms,
          status: _status,
        );
      } else {
        await _societyService.createCommittee(
          widget.societyId,
          name: name,
          description: desc,
          committeeType: _selectedCategory,
          scopeType: _scopeType,
          scopeId: _scopeType == 'gate' ? _selectedGateId : null,
          scopeGateIds: _scopeType == 'gate' && _selectedGateId != null ? [_selectedGateId!] : null,
          selectedModules: modules,
          permissions: perms,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditMode
                ? 'Committee updated successfully!'
                : 'Committee created successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF6B00);
    const slateDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'Edit Society Committee' : 'Committee Builder',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: slateDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildStepIndicator(),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                      _buildBottomActionBar(primaryColor),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStepIndicator() {
    const stepTitles = ['Identity', 'Modules', 'PBAC', 'Scope', 'Review'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(stepTitles.length, (index) {
            final isPassed = _currentStep > index;
            final isCurrent = _currentStep == index;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (index > _currentStep && _currentStep == 0) {
                      if (!_formKey.currentState!.validate()) return;
                    }
                    setState(() => _currentStep = index);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFFF6B00)
                          : (isPassed ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFFF6B00)
                            : (isPassed ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? Colors.white
                                : (isPassed ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                          ),
                          alignment: Alignment.center,
                          child: isPassed
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? const Color(0xFFFF6B00) : Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stepTitles[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : (isPassed ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < stepTitles.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: isPassed ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepIdentity();
      case 1:
        return _buildStepModules();
      case 2:
        return _buildStepPermissions();
      case 3:
        return _buildStepScope();
      case 4:
        return _buildStepReview();
      default:
        return _buildStepIdentity();
    }
  }

  Widget _buildBottomActionBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaving ? null : () => setState(() => _currentStep -= 1),
                child: const Text('Back'),
              ),
            if (_currentStep > 0) const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSaving ? null : _handleNextOrSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _currentStep == 4
                          ? (widget.isEditMode ? 'Save Changes' : 'Create Committee')
                          : 'Next Step',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextOrSave() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep < 4) {
      setState(() => _currentStep += 1);
    } else {
      _handleSave();
    }
  }


  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCatalogAndData,
              child: const Text('Retry Loading Catalog'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Committee Identity ──────────────────────────────────────────────
  Widget _buildStepIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Committee Identity & Classification',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Provide committee details and classify its category. Category is organizational metadata; actual authority is governed strictly by PBAC permissions.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Committee / Team Name *',
            hintText: 'e.g. Security Operations Team or Maintenance Committee',
            border: OutlineInputBorder(),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Committee name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Committee Type / Category *',
            border: OutlineInputBorder(),
            helperText: 'Categorizes the committee (metadata only; does not grant permissions)',
          ),
          items: _categories.isNotEmpty
              ? _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['key'].toString(),
                    child: Text(c['label'].toString()),
                  );
                }).toList()
              : const [
                  DropdownMenuItem(value: 'security', child: Text('Security Committee')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance Committee')),
                  DropdownMenuItem(value: 'events', child: Text('Events Committee')),
                  DropdownMenuItem(value: 'operations', child: Text('Operations Committee')),
                  DropdownMenuItem(value: 'garden', child: Text('Garden Committee')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance Committee')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Team')),
                ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCategory = val;
                if (!widget.isEditMode) {
                  _applyCategoryRecommendation(val);
                }
              });
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Purpose & Description',
            hintText: 'Describe responsibilities, charter, and operational mandate...',
            border: OutlineInputBorder(),
          ),
        ),
        if (widget.isEditMode) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Committee Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'archived', child: Text('Archived')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _status = val);
            },
          ),
        ],
      ],
    );
  }

  // ── Step 2: Related Operational Modules ────────────────────────────────────
  Widget _buildStepModules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Select Operational Modules',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select the operational areas this committee oversees. Granular PBAC permissions in Step 3 will be filtered based on your selected modules.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only real implemented operational modules are shown. Garden & Finance modules are marked unavailable until their dedicated operational screens are implemented.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._availableModules.map((mod) {
          final key = mod['key'].toString();
          final isSelected = _selectedModuleKeys.contains(key);
          final label = mod['label']?.toString() ?? key;
          final desc = mod['description']?.toString() ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
            child: CheckboxListTile(
              value: isSelected,
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              activeColor: const Color(0xFFFF6B00),
              dense: true,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedModuleKeys.add(key);
                  } else {
                    _selectedModuleKeys.remove(key);
                    // Remove permissions of unselected module
                    final unselectedCodes = _rawPermissions
                        .where((p) => p['module'] == key)
                        .map((p) => p['code'].toString());
                    _selectedPermissions.removeAll(unselectedCodes);
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

  // ── Step 3: Granular PBAC Permissions ─────────────────────────────────────
  Widget _buildStepPermissions() {
    final grouped = _permissionsByModule;

    if (_selectedModuleKeys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.amber),
              const SizedBox(height: 12),
              const Text('No operational modules selected yet.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Go to Step 2: Select Modules'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Step 3: Assign PBAC Permissions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
            Text(
              '${_selectedPermissions.length} selected',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6B00)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Backend validated permissions master. Only permissions belonging to your selected modules are shown.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        ...grouped.entries.map((entry) {
          final modKey = entry.key;
          final perms = entry.value;
          final modInfo = _availableModules.firstWhere(
            (m) => m['key'] == modKey,
            orElse: () => {'label': modKey},
          );
          final modLabel = modInfo['label']?.toString() ?? modKey;

          final allModCodes = perms.map((p) => p['code'].toString()).toSet();
          final allChecked = allModCodes.every(_selectedPermissions.contains);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        modLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (allChecked) {
                              _selectedPermissions.removeAll(allModCodes);
                            } else {
                              _selectedPermissions.addAll(allModCodes);
                            }
                          });
                        },
                        child: Text(allChecked ? 'Clear Module' : 'Select All'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  ...perms.map((p) {
                    final code = p['code']?.toString() ?? '';
                    final label = p['label']?.toString() ?? code;
                    final desc = p['description']?.toString() ?? '';
                    final isChecked = _selectedPermissions.contains(code);

                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: isChecked,
                      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: desc.isNotEmpty
                          ? Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                          : Text(code, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      activeColor: const Color(0xFFFF6B00),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedPermissions.add(code);
                          } else {
                            _selectedPermissions.remove(code);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 4: Operational Scope ─────────────────────────────────────────────
  Widget _buildStepScope() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Operational Scope',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Define the physical boundary where committee members can exercise their permissions.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _scopeType,
          decoration: const InputDecoration(
            labelText: 'Scope Type *',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'entire_society',
              child: Text('Entire Society (All Gates & Facilities)'),
            ),
            DropdownMenuItem(
              value: 'gate',
              child: Text('Specific Gate (Gate-Scoped Enforcement)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _scopeType = val);
          },
        ),
        if (_scopeType == 'gate') ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedGateId,
            decoration: const InputDecoration(
              labelText: 'Target Gate *',
              border: OutlineInputBorder(),
              helperText: 'Actions outside this gate will be rejected with HTTP 403',
            ),
            items: _gates.isNotEmpty
                ? _gates.map((g) {
                    return DropdownMenuItem<int>(
                      value: g.id,
                      child: Text(g.gateName),
                    );
                  }).toList()
                : [
                    const DropdownMenuItem<int>(
                      value: 1,
                      child: Text('Gate 1 (Default Main Gate)'),
                    ),
                  ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedGateId = val);
            },
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: Color(0xFF475569)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scope Security Notice: Gate scope is enforced by the backend PBAC engine on each API request. Zone and Block scopes are not exposed because their resource entities are not modeled.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 5: Review & Submit ───────────────────────────────────────────────
  Widget _buildStepReview() {
    final catInfo = _categories.firstWhere(
      (c) => c['key'] == _selectedCategory,
      orElse: () => {'label': _selectedCategory},
    );
    final catLabel = catInfo['label']?.toString() ?? _selectedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 5: Review & Confirmation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Verify all committee details before publishing. PBAC cache will be invalidated immediately for all active members.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReviewRow('Committee Name', _nameController.text.trim()),
                const Divider(),
                _buildReviewRow('Category / Type', catLabel),
                const Divider(),
                _buildReviewRow('Status', _status.toUpperCase()),
                const Divider(),
                _buildReviewRow(
                  'Operational Scope',
                  _scopeType == 'gate'
                      ? 'Gate Scoped (Gate #${_selectedGateId ?? '1'})'
                      : 'Entire Society',
                ),
                const Divider(),
                _buildReviewRow('Selected Modules', '${_selectedModuleKeys.length} modules active'),
                const Divider(),
                _buildReviewRow('PBAC Permissions', '${_selectedPermissions.length} permissions granted'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Active Modules:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _selectedModuleKeys.map((key) {
            final mod = _availableModules.firstWhere(
              (m) => m['key'] == key,
              orElse: () => {'label': key},
            );
            return Chip(
              label: Text(mod['label']?.toString() ?? key, style: const TextStyle(fontSize: 12)),
              backgroundColor: const Color(0xFFFFF7ED),
              side: const BorderSide(color: Color(0xFFFF6B00)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Membership Notice:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Members can be invited after committee creation. Invitations follow strict PENDING -> Acceptance -> ACTIVE lifecycle with deep-link notifications.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
