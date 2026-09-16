import 'package:flutter/material.dart';
import '../../services/society_service.dart';
import '../../models/society_models.dart';
import '../../services/auth_session.dart';
import 'announcement_detail_screen.dart';
import 'widgets/society_notice_form_sheet.dart';

class _C {
  static const bg = Color(0xFFF9FAFB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
}

class AnnouncementsScreen extends StatefulWidget {
  final int? societyId;
  final String? userRole;
  final int? initialAnnouncementId;

  const AnnouncementsScreen({
    super.key,
    this.societyId,
    this.userRole,
    this.initialAnnouncementId,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final SocietyService _societyService = SocietyService();

  int? _resolvedSocietyId;
  String? _userRole;
  bool _isLoading = true;
  String? _errorMessage;
  List<SocietyAnnouncementModel> _announcements = [];

  String _selectedCategory = 'all';
  String _selectedStatus = 'published'; // 'published' | 'draft'
  final TextEditingController _searchController = TextEditingController();

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  bool get _canCreateAnnouncement {
    if (_userRole == null) return true;
    final r = _userRole!.toLowerCase().trim();
    return r == 'admin' || r == 'committee' || r == 'owner' || r == 'superadmin';
  }

  final _categories = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'maintenance', 'label': 'Maintenance'},
    {'key': 'security', 'label': 'Security'},
    {'key': 'emergency', 'label': 'Emergency'},
    {'key': 'event', 'label': 'Event'},
    {'key': 'finance', 'label': 'Finance'},
    {'key': 'rules_notice', 'label': 'Rules & Notice'},
    {'key': 'general', 'label': 'General'},
  ];

  @override
  void initState() {
    super.initState();
    _userRole = widget.userRole;
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    _resolvedSocietyId = await _societyService.resolveActiveSocietyId(widget.societyId);

    if (_resolvedSocietyId != null) {
      if (_userRole == null) {
        try {
          final mySoc = await _societyService.getMySociety();
          if (mySoc != null && mySoc.id == _resolvedSocietyId && mySoc.userRole != null) {
            _userRole = mySoc.userRole;
          } else {
            final currentUserId = await AuthSessionStore().readUserId();
            if (currentUserId != null) {
              final membersRes = await _societyService.getMembers(_resolvedSocietyId!, limit: 100);
              final myMember = membersRes.data.firstWhere(
                (m) => m.userId == currentUserId,
                orElse: () => const SocietyMemberModel(
                  id: 0,
                  societyId: 0,
                  userId: 0,
                  role: 'member',
                  status: 'active',
                ),
              );
              if (myMember.id > 0) {
                _userRole = myMember.role.toLowerCase();
              }
            }
          }
        } catch (_) {}
      }
      await _loadAnnouncements();

      // Deep link handling from notification
      if (widget.initialAnnouncementId != null && widget.initialAnnouncementId! > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openDetailById(widget.initialAnnouncementId!);
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnnouncements() async {
    if (_resolvedSocietyId == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _societyService.getAnnouncements(
        _resolvedSocietyId!,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        status: _selectedStatus,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        includeExpired: false,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _announcements = res.data;
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

  void _openDetail(SocietyAnnouncementModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(
          societyId: _resolvedSocietyId!,
          userRole: _userRole,
          initialAnnouncement: item,
        ),
      ),
    ).then((val) {
      if (val == true) _loadAnnouncements();
    });
  }

  void _openDetailById(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(
          societyId: _resolvedSocietyId!,
          userRole: _userRole,
          announcementId: id,
        ),
      ),
    ).then((val) {
      if (val == true) _loadAnnouncements();
    });
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'maintenance':
        return const Color(0xFF9A3412);
      case 'security':
        return const Color(0xFF9F1239);
      case 'emergency':
        return const Color(0xFFB91C1C);
      case 'event':
        return const Color(0xFF166534);
      case 'finance':
        return const Color(0xFF1E40AF);
      case 'rules_notice':
        return const Color(0xFF6B21A8);
      default:
        return const Color(0xFF374151);
    }
  }

  Color _getCategoryBg(String category) {
    switch (category.toLowerCase()) {
      case 'maintenance':
        return const Color(0xFFFFEDD5);
      case 'security':
        return const Color(0xFFFFE4E6);
      case 'emergency':
        return const Color(0xFFFEE2E2);
      case 'event':
        return const Color(0xFFF0FDF4);
      case 'finance':
        return const Color(0xFFEFF6FF);
      case 'rules_notice':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Widget _buildCategoryBadge(String category) {
    final color = _getCategoryColor(category);
    final bg = _getCategoryBg(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        category.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCard(SocietyAnnouncementModel item) {
    final date = item.effectivePublishedDate;
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : 'Recent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isUrgent ? const Color(0xFFFFF7F0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUrgent ? const Color(0xFFFFCB99) : _C.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (_selectedIds.contains(item.id)) {
                _selectedIds.remove(item.id);
              } else {
                _selectedIds.add(item.id);
              }
            });
          } else {
            _openDetail(item);
          }
        },
        onLongPress: () {
          if (_canCreateAnnouncement && !_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(item.id);
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: badge + announcement number + pinned/urgent indicator + actions
              Row(
                children: [
                  if (_isSelectionMode) ...[
                    Checkbox(
                      value: _selectedIds.contains(item.id),
                      activeColor: _C.orange,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(item.id);
                          } else {
                            _selectedIds.remove(item.id);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  _buildCategoryBadge(item.category),
                  if (item.announcementNumber.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.announcementNumber,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.sub),
                    ),
                  ],
                  if (item.isPinned) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.push_pin, size: 14, color: _C.orange),
                  ],
                  const Spacer(),
                  if (item.isUrgent) ...[
                    const Icon(Icons.warning_amber_rounded, size: 16, color: _C.orange),
                    const SizedBox(width: 4),
                    const Text(
                      'Urgent',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.orange),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (item.isDraft) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('DRAFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!_isSelectionMode && _canCreateAnnouncement)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: _C.sub),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'edit') _showEditAnnouncementFlow(item);
                        if (val == 'pin') _togglePinNotice(item);
                        if (val == 'archive') _archiveNotice(item);
                        if (val == 'delete') _deleteNotice(item);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: _C.sub),
                              SizedBox(width: 8),
                              Text('Edit Notice'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(item.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 16, color: _C.orange),
                              SizedBox(width: 8),
                              Text(item.isPinned ? 'Unpin Notice' : 'Pin to Top'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 16, color: _C.sub),
                              SizedBox(width: 8),
                              Text('Archive Notice'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Notice', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _C.text,
                ),
              ),
              const SizedBox(height: 6),

              // Short Summary or Body snippet
              Text(
                item.summary?.isNotEmpty == true ? item.summary! : item.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _C.sub, height: 1.5),
              ),

              // Attachment pill (if any)
              if (item.hasAttachments) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            '${item.attachments.length} attachment${item.attachments.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              Container(height: 1, color: _C.border),
              const SizedBox(height: 10),

              // Footer: Timestamp + Author + Tap indicator
              Row(
                children: [
                  const Icon(Icons.access_time_outlined, size: 13, color: _C.sub),
                  const SizedBox(width: 5),
                  Text(dateStr, style: const TextStyle(fontSize: 12, color: _C.sub)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.authorName,
                      style: const TextStyle(fontSize: 11, color: _C.sub, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: _C.sub),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Official Notices',
          style: const TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _C.text),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _announcements.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_announcements.map((a) => a.id));
                  }
                });
              },
              child: Text(
                _selectedIds.length == _announcements.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: _C.orange, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Delete Selected',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _selectedIds.isEmpty ? null : _bulkDeleteSelected,
            ),
          ] else if (_canCreateAnnouncement && _announcements.isNotEmpty) ...[
            IconButton(
              tooltip: 'Select Multiple',
              icon: const Icon(Icons.checklist_rounded, color: _C.sub),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Header ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notices or ANN number...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: _C.sub),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadAnnouncements();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _loadAnnouncements(),
                ),

                // Admin Tabs (Published vs Drafts)
                if (_canCreateAnnouncement) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusTab('published', 'Published Notices'),
                      const SizedBox(width: 8),
                      _buildStatusTab('draft', 'Drafts'),
                    ],
                  ),
                ],

                const SizedBox(height: 8),
                // Category Filter Chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['key'];
                      return ChoiceChip(
                        label: Text(cat['label']!),
                        selected: isSelected,
                        selectedColor: _C.orange,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : _C.text,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedCategory = cat['key']!);
                            _loadAnnouncements();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Main Content List ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _C.orange))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 40),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: _C.sub)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: _C.orange),
                              onPressed: _loadAnnouncements,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _announcements.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadAnnouncements,
                            color: _C.orange,
                            child: ListView(
                              padding: const EdgeInsets.all(40),
                              children: [
                                const SizedBox(height: 60),
                                const Icon(Icons.campaign_outlined, size: 56, color: Color(0xFFD1D5DB)),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedStatus == 'draft'
                                      ? 'No draft announcements'
                                      : 'No announcements published yet',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _C.sub),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAnnouncements,
                            color: _C.orange,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _announcements.length,
                              itemBuilder: (ctx, index) => _buildCard(_announcements[index]),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: _canCreateAnnouncement
          ? FloatingActionButton.extended(
              backgroundColor: _C.orange,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCreateAnnouncementFlow,
            )
          : null,
    );
  }

  Widget _buildStatusTab(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return InkWell(
      onTap: () {
        if (_selectedStatus != statusKey) {
          setState(() => _selectedStatus = statusKey);
          _loadAnnouncements();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? _C.orange : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? _C.orange : _C.sub,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ENTERPRISE NOTICE CREATION FLOW
  // ─────────────────────────────────────────────────────────────────────────────
  void _showCreateAnnouncementFlow() {
    if (_resolvedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to identify active society.')),
      );
      return;
    }

    SocietyNoticeFormSheet.show(
      context: context,
      societyId: _resolvedSocietyId!,
      onSuccess: (_) => _loadAnnouncements(),
    );
  }

  void _showEditAnnouncementFlow(SocietyAnnouncementModel item) {
    if (_resolvedSocietyId == null) return;
    SocietyNoticeFormSheet.show(
      context: context,
      societyId: _resolvedSocietyId!,
      initialAnnouncement: item,
      onSuccess: (_) => _loadAnnouncements(),
    );
  }

  Future<void> _deleteNotice(SocietyAnnouncementModel item) async {
    if (_resolvedSocietyId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text('Are you sure you want to delete notice "${item.title}"? It will be archived and removed from the resident feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _societyService.deleteAnnouncement(item.id, _resolvedSocietyId!, deletedRemarks: 'Deleted by admin from card');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice deleted successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty || _resolvedSocietyId == null) return;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Notices'),
        content: Text('Are you sure you want to delete $count notice${count > 1 ? 's' : ''}? They will be archived and removed from the resident feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete $count Notice${count > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final deletedCount = await _societyService.bulkDeleteAnnouncements(
        _selectedIds.toList(),
        _resolvedSocietyId!,
        deletedRemarks: 'Bulk deleted by admin',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $deletedCount notice${deletedCount > 1 ? 's' : ''}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        await _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk delete failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePinNotice(SocietyAnnouncementModel item) async {
    if (_resolvedSocietyId == null) return;
    try {
      await _societyService.updateAnnouncement(item.id, _resolvedSocietyId!, {
        'is_pinned': !item.isPinned,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(item.isPinned ? 'Notice unpinned' : 'Notice pinned to top'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _archiveNotice(SocietyAnnouncementModel item) async {
    if (_resolvedSocietyId == null) return;
    try {
      await _societyService.archiveAnnouncement(item.id, _resolvedSocietyId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice archived successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archive failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
