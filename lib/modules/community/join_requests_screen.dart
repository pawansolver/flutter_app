import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/community_models.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';

class JoinRequestsScreen extends StatefulWidget {
  final int communityId;
  final String communityName;
  final CommunityRole? callerRole;

  const JoinRequestsScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.callerRole,
  });

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  final _service = CommunityService();
  final _authService = AuthService();
  bool _isLoading = true;
  List<CommunityJoinRequestModel> _requests = [];
  final Set<int> _processing = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkGuardAndLoad();
  }

  void _checkGuardAndLoad() async {
    // 1. If callerRole is admin or moderator -> Allowed immediately
    if (widget.callerRole == CommunityRole.admin ||
        widget.callerRole == CommunityRole.moderator) {
      _loadRequests();
      return;
    }

    // 2. If callerRole is explicitly member or none -> Denied immediately
    if (widget.callerRole == CommunityRole.member ||
        widget.callerRole == CommunityRole.none) {
      _denyAccess();
      return;
    }

    // 3. If callerRole is null (direct deep navigation), resolve authorization before proceeding
    final isGlobalAdmin = await _authService.isGlobalAdmin();
    if (isGlobalAdmin) {
      _loadRequests();
      return;
    }

    // 4. Query actual community details from backend to verify community role
    try {
      final details = await _service.getCommunityDetails(widget.communityId);
      if (details.myRole == CommunityRole.admin ||
          details.myRole == CommunityRole.moderator) {
        _loadRequests();
        return;
      }
    } catch (_) {}

    // 5. Default fail-closed: Deny access and NEVER call _loadRequests()
    _denyAccess();
  }

  void _denyAccess() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = 'Access Denied: Requires admin or moderator privilege.';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Requires admin or moderator privilege.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reqs = await _service.getPendingJoinRequests(widget.communityId);
      if (mounted) {
        setState(() {
          _requests = reqs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApprove(CommunityJoinRequestModel req) async {
    setState(() => _processing.add(req.id));
    try {
      await _service.approveJoinRequest(widget.communityId, req.id);
      if (mounted) {
        setState(() {
          _requests.removeWhere((item) => item.id == req.id);
          _processing.remove(req.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${req.fullName} approved to join!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing.remove(req.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(CommunityJoinRequestModel req) async {
    setState(() => _processing.add(req.id));
    try {
      await _service.rejectJoinRequest(widget.communityId, req.id);
      if (mounted) {
        setState(() {
          _requests.removeWhere((item) => item.id == req.id);
          _processing.remove(req.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined ${req.fullName}\'s request.'),
            backgroundColor: const Color(0xFF6B7280),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing.remove(req.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Join Requests',
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.communityName,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(primaryOrange, darkText),
    );
  }

  Widget _buildBody(Color primaryOrange, Color darkText) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _checkGuardAndLoad, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Pending Requests',
                style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'When neighbors request to join your private community, they will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryOrange,
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = _requests[index];

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x08000000),
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
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFFFF7ED),
                      backgroundImage: req.avatarUrl != null && req.avatarUrl!.isNotEmpty
                          ? NetworkImage(req.avatarUrl!)
                          : null,
                      child: req.avatarUrl == null || req.avatarUrl!.isEmpty
                          ? Text(
                              req.fullName.isNotEmpty ? req.fullName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: primaryOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.fullName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Requested ${DateFormat('dd MMM, hh:mm a').format(req.requestedAt)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (req.note != null && req.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      '"${req.note!}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing.contains(req.id)
                            ? null
                            : () => _handleReject(req),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _processing.contains(req.id)
                            ? null
                            : () => _handleApprove(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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
}
