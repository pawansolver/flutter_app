import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/society_service.dart';
import '../../models/society_models.dart';
import 'society_dashboard_screen.dart';

class SelectSocietyScreen extends StatefulWidget {
  final bool isModal;
  final Function(SocietyProfileModel society, String flatNo, String role)? onSocietySelected;

  const SelectSocietyScreen({
    super.key,
    this.isModal = false,
    this.onSocietySelected,
  });

  @override
  State<SelectSocietyScreen> createState() => _SelectSocietyScreenState();
}

class _SelectSocietyScreenState extends State<SelectSocietyScreen> {
  final SocietyService _societyService = SocietyService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  String? _errorMessage;
  List<SocietyProfileModel> _societies = [];
  int _totalSocieties = 0;
  int _page = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchSocieties();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchSocieties(reset: true);
    });
  }

  Future<void> _fetchSocieties({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await _societyService.getSocieties(
        page: _page,
        limit: 20,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          if (reset || _page == 1) {
            _societies = res.data;
          } else {
            _societies.addAll(res.data);
          }
          _totalSocieties = res.total;
          _hasMore = _societies.length < _totalSocieties;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _openEnterpriseJoinSheet(SocietyProfileModel society) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EnterpriseJoinSheet(
        society: society,
        onJoinSuccess: (member, formattedFlatNo, role) {
          if (widget.onSocietySelected != null) {
            widget.onSocietySelected!(society, formattedFlatNo, role);
            Navigator.pop(context);
          } else {
            _showJoinStatusDialog(society, member);
          }
        },
      ),
    );
  }

  void _showJoinStatusDialog(SocietyProfileModel society, SocietyMemberModel member) {
    final isPending = member.status.toLowerCase() == 'pending';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isPending
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending ? Icons.schedule_rounded : Icons.check_circle_rounded,
                size: 44,
                color: isPending
                    ? const Color(0xFFD97706)
                    : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isPending ? 'Request Submitted' : 'Joined Successfully!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPending
                  ? 'Your join request for ${member.flatNo ?? "your unit"} at ${society.societyName} has been sent to the society management committee.'
                  : 'You now have access to ${society.societyName} as a registered resident.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (isPending) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status: Pending Admin Approval\nYou will receive a notification once verified.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietyDashboardScreen(initialSocietyId: society.id),
                    ),
                  );
                },
                child: Text(
                  isPending ? 'Go to Society Dashboard' : 'Open Dashboard',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Housing Society',
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Find your society to connect with neighbours & security',
              style: TextStyle(color: subText, fontSize: 11),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // ── Search & Filter Header ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by society name, city or locality...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: brandGreen, size: 22),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18, color: subText),
                            onPressed: () {
                              _searchCtrl.clear();
                              _fetchSocieties(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: brandGreen, width: 1.5),
                    ),
                  ),
                ),
                if (!_isLoading) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_totalSocieties societ${_totalSocieties == 1 ? "y" : "ies"} registered',
                        style: const TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.verified, size: 14, color: brandGreen),
                          SizedBox(width: 4),
                          Text(
                            'Verified Gated Communities',
                            style: TextStyle(color: brandGreen, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Society List or Empty/Loading State ──────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: brandGreen),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load societies',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: subText, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _fetchSocieties(reset: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brandGreen,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _societies.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: brandGreen.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.apartment_outlined, size: 56, color: brandGreen),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'No Societies Found',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryText),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchCtrl.text.isNotEmpty
                                        ? 'No housing societies matched "${_searchCtrl.text}". Try a different keyword.'
                                        : 'No societies are currently registered in this area.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: subText, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: brandGreen,
                            onRefresh: () => _fetchSocieties(reset: true),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _societies.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index >= _societies.length) {
                                  if (!_isLoadingMore) {
                                    _isLoadingMore = true;
                                    _page++;
                                    _fetchSocieties();
                                  }
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: brandGreen),
                                    ),
                                  );
                                }

                                final society = _societies[index];
                                return _buildSocietyCard(society);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocietyCard(SocietyProfileModel society) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    final name = society.societyName.trim().isNotEmpty
        ? society.societyName.trim()
        : 'Society #${society.id}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Center(
                  child: Icon(Icons.apartment_rounded, color: brandGreen, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    if (society.address != null && society.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: subText),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              society.address!,
                              style: const TextStyle(fontSize: 12, color: subText),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (society.totalFlats != null && society.totalFlats! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 13, color: subText),
                            const SizedBox(width: 4),
                            Text(
                              '${society.totalFlats} Units',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subText),
                            ),
                          ],
                        ),
                      ),
                    if (society.registrationNo != null && society.registrationNo!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'Reg: ${society.registrationNo}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_home_outlined, size: 15),
                label: const Text('Select & Join'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openEnterpriseJoinSheet(society),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Enterprise Join Form Bottom Sheet ─────────────────────────────────────────
class _EnterpriseJoinSheet extends StatefulWidget {
  final SocietyProfileModel society;
  final Function(SocietyMemberModel member, String formattedFlatNo, String role) onJoinSuccess;

  const _EnterpriseJoinSheet({
    required this.society,
    required this.onJoinSuccess,
  });

  @override
  State<_EnterpriseJoinSheet> createState() => _EnterpriseJoinSheetState();
}

class _EnterpriseJoinSheetState extends State<_EnterpriseJoinSheet> {
  final SocietyService _societyService = SocietyService();
  final _formKey = GlobalKey<FormState>();

  final _towerCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _intercomCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();

  // Residency Type: 'Owner' -> role 'member', 'Tenant' -> role 'tenant', 'Family Member' -> role 'member'
  String _residencyType = 'Owner';
  DateTime _moveInDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _towerCtrl.dispose();
    _flatCtrl.dispose();
    _intercomCtrl.dispose();
    _emergencyContactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitJoinRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final tower = _towerCtrl.text.trim();
      final flat = _flatCtrl.text.trim();
      final formattedFlatNo = '$tower - $flat';

      // Map residency type to backend enum ('member' or 'tenant')
      final backendRole = _residencyType.toLowerCase() == 'tenant' ? 'tenant' : 'member';

      final member = await _societyService.joinSociety(
        widget.society.id,
        flatNo: formattedFlatNo,
        role: backendRole,
      );

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        widget.onJoinSuccess(member, formattedFlatNo, backendRole);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Society Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_rounded, color: brandGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.society.societyName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        if (widget.society.address != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.society.address!,
                            style: const TextStyle(fontSize: 12, color: subText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 18),

              // ── Enterprise Field: Residency Type ────────────────────────
              const Text(
                'Residency Type *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryText),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildResidencyOption('Owner', Icons.key_rounded, 'Owner'),
                  const SizedBox(width: 8),
                  _buildResidencyOption('Tenant', Icons.business_center_outlined, 'Tenant'),
                  const SizedBox(width: 8),
                  _buildResidencyOption('Family', Icons.people_alt_outlined, 'Family Member'),
                ],
              ),
              const SizedBox(height: 18),

              // ── Enterprise Field: Tower & Flat Number ───────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tower / Block / Wing *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryText),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _towerCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          decoration: _inputDecoration(
                            hint: 'e.g. Tower B, Wing A',
                            prefixIcon: Icons.apartment_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Flat / Unit No *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryText),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _flatCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          decoration: _inputDecoration(
                            hint: 'e.g. 402, 101',
                            prefixIcon: Icons.meeting_room_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Enterprise Field: Intercom & Move-in Date ────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Intercom No (Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryText),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _intercomCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hint: 'e.g. 4021',
                            prefixIcon: Icons.phone_in_talk_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Move-in Date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryText),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _moveInDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _moveInDate = picked);
                            }
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_moveInDate.day}/${_moveInDate.month}/${_moveInDate.year}',
                                    style: const TextStyle(fontSize: 13, color: primaryText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Enterprise Field: Emergency Contact Phone (Optional) ───────
              const Text(
                'Emergency Contact Phone (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryText),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emergencyContactCtrl,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  hint: 'e.g. +91 9876543210',
                  prefixIcon: Icons.contact_emergency_outlined,
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submitJoinRequest,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Submit Join Request',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Your request will be verified by the society admin or gate security',
                  style: TextStyle(fontSize: 11, color: subText),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidencyOption(String key, IconData icon, String label) {
    final isSelected = _residencyType == label;
    const Color brandGreen = Color(0xFF10B981);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _residencyType = label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? brandGreen : const Color(0xFFD1D5DB),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? brandGreen : const Color(0xFF6B7280)),
              const SizedBox(height: 4),
              Text(
                key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? brandGreen : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF6B7280)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
