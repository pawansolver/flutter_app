import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import '../../services/society_service.dart';
import '../../models/society_models.dart';

// ─── Colors ────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF9FAFB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
}

class AnnouncementsScreen extends StatefulWidget {
  final int? societyId;
  const AnnouncementsScreen({super.key, this.societyId});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final SocietyService _societyService = SocietyService();

  int? _resolvedSocietyId;
  bool _isLoading = true;
  String? _errorMessage;
  List<SocietyAnnouncementModel> _announcements = [];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    _resolvedSocietyId = await _societyService.resolveActiveSocietyId(widget.societyId);

    if (_resolvedSocietyId != null) {
      await _loadAnnouncements();
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

  // ── Category Badge
  _CategoryStyle _getCategoryStyle(String category) {
    switch (category.toLowerCase()) {
      case 'maintenance':
        return const _CategoryStyle(
          bg: Color(0xFFFFEDD5),
          text: Color(0xFF9A3412),
        );
      case 'security':
        return const _CategoryStyle(
          bg: Color(0xFFFFE4E6),
          text: Color(0xFF9F1239),
        );
      case 'finance':
        return const _CategoryStyle(
          bg: Color(0xFFEFF6FF),
          text: Color(0xFF1E40AF),
        );
      case 'event':
        return const _CategoryStyle(
          bg: Color(0xFFF0FDF4),
          text: Color(0xFF166534),
        );
      default: // General
        return const _CategoryStyle(
          bg: Color(0xFFF3F4F6),
          text: Color(0xFF374151),
        );
    }
  }

  Widget _buildCategoryBadge(String category) {
    final style = _getCategoryStyle(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: style.text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Announcement Card
  Widget _buildCard(SocietyAnnouncementModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isUrgent ? const Color(0xFFFFF7F0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUrgent ? const Color(0xFFFFCB99) : _C.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badge + urgent icon + pinned
            Row(
              children: [
                _buildCategoryBadge(item.category),
                if (item.isPinned) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.push_pin, size: 14, color: _C.orange),
                ],
                const Spacer(),
                if (item.isUrgent) ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: _C.orange,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Urgent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.orange,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              item.message,
              style: const TextStyle(fontSize: 13, color: _C.sub, height: 1.6),
            ),
            const SizedBox(height: 12),

            // Divider
            Container(height: 1, color: _C.border),
            const SizedBox(height: 10),

            // Timestamp
            Row(
              children: [
                const Icon(Icons.access_time_outlined, size: 14, color: _C.sub),
                const SizedBox(width: 5),
                Text(
                  item.createdAt != null
                      ? '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}'
                      : 'Recent',
                  style: const TextStyle(fontSize: 12, color: _C.sub),
                ),
                const Spacer(),
                Text(
                  item.authorName,
                  style: const TextStyle(fontSize: 11, color: _C.sub, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementModal() {
    if (_resolvedSocietyId == null) return;
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    String priority = 'medium';
    bool isPinned = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                  const Text('Publish Notice',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Notice Title',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notice Message',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => priority = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Checkbox(
                        activeColor: _C.orange,
                        value: isPinned,
                        onChanged: (val) => setModalState(() => isPinned = val ?? false),
                      ),
                      const Text('Pin Notice', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final msg = messageController.text.trim();
                          if (title.isEmpty || msg.isEmpty) return;

                          setModalState(() => isSubmitting = true);
                          try {
                            await _societyService.createAnnouncement(
                              _resolvedSocietyId!,
                              title: title,
                              message: msg,
                              priority: priority,
                              category: categoryController.text.trim().toLowerCase(),
                              isPinned: isPinned,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAnnouncements();
                          } catch (_) {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Publish Announcement',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        floatingActionButton: FloatingActionButton(
          backgroundColor: _C.orange,
          elevation: 0,
          onPressed: _showCreateAnnouncementModal,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _C.text),
            onPressed: handleBack,
          ),
          title: const Text(
            'Official Announcements',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _C.text,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _C.border),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _C.orange))
            : RefreshIndicator(
                color: _C.orange,
                onRefresh: _loadAnnouncements,
                child: Column(
                  children: [
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _announcements.isEmpty
                          ? const Center(
                              child: Text(
                                'No announcements published yet',
                                style: TextStyle(color: _C.sub, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                              itemCount: _announcements.length,
                              itemBuilder: (_, i) => _buildCard(_announcements[i]),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Helper ────────────────────────────────────────────────────────
class _CategoryStyle {
  final Color bg;
  final Color text;
  const _CategoryStyle({required this.bg, required this.text});
}
