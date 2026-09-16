import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';
import 'widgets/society_notice_form_sheet.dart';

class _C {
  static const bg = Color(0xFFF9FAFB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
}

class AnnouncementDetailScreen extends StatefulWidget {
  final int? announcementId;
  final SocietyAnnouncementModel? initialAnnouncement;
  final int societyId;
  final String? userRole;

  const AnnouncementDetailScreen({
    super.key,
    this.announcementId,
    this.initialAnnouncement,
    required this.societyId,
    this.userRole,
  });

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final SocietyService _societyService = SocietyService();

  late int _announcementId;
  SocietyAnnouncementModel? _announcement;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isActionRunning = false;

  bool get _canManage {
    final r = (widget.userRole ?? '').toLowerCase().trim();
    return r == 'admin' || r == 'committee' || r == 'owner' || r == 'superadmin';
  }

  @override
  void initState() {
    super.initState();
    _announcement = widget.initialAnnouncement;
    _announcementId = widget.announcementId ?? widget.initialAnnouncement?.id ?? 0;

    if (_announcement != null && _announcementId > 0) {
      _isLoading = false;
      // Refresh in background
      _fetchAnnouncement();
    } else if (_announcementId > 0) {
      _fetchAnnouncement();
    } else {
      _isLoading = false;
      _errorMessage = 'Invalid announcement ID';
    }
  }

  Future<void> _fetchAnnouncement() async {
    try {
      final res = await _societyService.getAnnouncement(_announcementId, widget.societyId);
      if (mounted) {
        setState(() {
          _announcement = res;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && _announcement == null) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePin() async {
    if (_announcement == null || _isActionRunning) return;
    setState(() => _isActionRunning = true);
    final nextPin = !_announcement!.isPinned;
    try {
      final updated = await _societyService.updateAnnouncement(
        _announcement!.id,
        widget.societyId,
        {'is_pinned': nextPin},
      );
      if (mounted) {
        setState(() {
          _announcement = updated;
          _isActionRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextPin ? 'Notice pinned' : 'Notice unpinned'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _archiveNotice() async {
    if (_announcement == null || _isActionRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Notice?'),
        content: const Text('This notice will be archived and hidden from the resident active feed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      final archived = await _societyService.archiveAnnouncement(_announcement!.id, widget.societyId);
      if (mounted) {
        setState(() {
          _announcement = archived;
          _isActionRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice archived successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteNotice() async {
    if (_announcement == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: Text('Are you sure you want to delete "${_announcement!.title}"? It will be archived and removed from the active notice feed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Notice', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      await _societyService.deleteAnnouncement(_announcement!.id, widget.societyId, deletedRemarks: 'Deleted by admin from detail view');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openAttachment(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open attachment URL')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'maintenance':
        return const Color(0xFFEA580C);
      case 'security':
        return const Color(0xFFDC2626);
      case 'emergency':
        return const Color(0xFFB91C1C);
      case 'event':
        return const Color(0xFF16A34A);
      case 'finance':
        return const Color(0xFF2563EB);
      case 'rules_notice':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Color _getCategoryBg(String category) {
    switch (category.toLowerCase()) {
      case 'maintenance':
        return const Color(0xFFFFF7ED);
      case 'security':
        return const Color(0xFFFEF2F2);
      case 'emergency':
        return const Color(0xFFFEE2E2);
      case 'event':
        return const Color(0xFFF0FDF4);
      case 'finance':
        return const Color(0xFFEFF6FF);
      case 'rules_notice':
        return const Color(0xFFF5F3FF);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _C.text),
        title: Text(
          _announcement?.announcementNumber.isNotEmpty == true
              ? _announcement!.announcementNumber
              : 'Society Notice',
          style: const TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_canManage && _announcement != null) ...[
            IconButton(
              tooltip: _announcement!.isPinned ? 'Unpin' : 'Pin',
              icon: Icon(
                _announcement!.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _announcement!.isPinned ? _C.orange : _C.sub,
              ),
              onPressed: _isActionRunning ? null : _togglePin,
            ),
            IconButton(
              tooltip: 'Edit Notice',
              icon: const Icon(Icons.edit_outlined, color: _C.sub),
              onPressed: _isActionRunning
                  ? null
                  : () {
                      SocietyNoticeFormSheet.show(
                        context: context,
                        societyId: widget.societyId,
                        initialAnnouncement: _announcement,
                        onSuccess: (updated) {
                          setState(() => _announcement = updated);
                        },
                      );
                    },
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'archive') _archiveNotice();
                if (val == 'delete') _deleteNotice();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, size: 18, color: _C.sub),
                      SizedBox(width: 8),
                      Text('Archive Notice'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Notice', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.orange),
      );
    }

    if (_errorMessage != null && _announcement == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: _C.sub)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _C.orange),
                onPressed: _fetchAnnouncement,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _announcement!;
    final catColor = _getCategoryColor(item.category);
    final catBg = _getCategoryBg(item.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Badges Row ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: catColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  item.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.announcementNumber.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.announcementNumber,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                  ),
                ),
              const Spacer(),
              if (item.isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text('URGENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              if (item.isDraft) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('DRAFT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ── Notice Title ──────────────────────────────────────────────────
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // ── Metadata Bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFFFEDD5),
                  child: Icon(Icons.person, size: 16, color: _C.orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.authorName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _C.text),
                      ),
                      Text(
                        item.effectivePublishedDate != null
                            ? 'Published ${item.effectivePublishedDate!.day}/${item.effectivePublishedDate!.month}/${item.effectivePublishedDate!.year}'
                            : 'Recently published',
                        style: const TextStyle(fontSize: 11, color: _C.sub),
                      ),
                    ],
                  ),
                ),
                if (item.expiresAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('EXPIRES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _C.sub)),
                      Text(
                        '${item.expiresAt!.day}/${item.expiresAt!.month}/${item.expiresAt!.year}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Short Summary (if available) ───────────────────────────────────
          if (item.summary != null && item.summary!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                item.summary!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Important Instructions / Action Text Callout ───────────────────
          if (item.actionText != null && item.actionText!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'IMPORTANT INSTRUCTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.actionText!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Notice Body Content ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notice Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _C.sub, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _C.text,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Attachments Section ───────────────────────────────────────────
          if (item.attachments.isNotEmpty) ...[
            const Text(
              'Attachments & Circulars',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _C.text),
            ),
            const SizedBox(height: 8),
            ...item.attachments.map((att) => _buildAttachmentCard(att)),
            const SizedBox(height: 16),
          ],

          // ── Audience Pill ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline, size: 15, color: _C.sub),
                const SizedBox(width: 6),
                Text(
                  'Target Audience: ${item.audience == 'entire_society' ? 'Entire Society' : item.audience}',
                  style: const TextStyle(fontSize: 11, color: _C.sub, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(AnnouncementAttachmentModel att) {
    IconData icon = Icons.insert_drive_file_outlined;
    Color iconColor = const Color(0xFF6B7280);

    if (att.isPdf) {
      icon = Icons.picture_as_pdf;
      iconColor = const Color(0xFFDC2626);
    } else if (att.isImage) {
      icon = Icons.image_outlined;
      iconColor = const Color(0xFF2563EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          att.fileName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: att.formattedSize.isNotEmpty
            ? Text(att.formattedSize, style: const TextStyle(fontSize: 11, color: _C.sub))
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new, size: 18, color: _C.orange),
          onPressed: () => _openAttachment(att.fileUrl),
          tooltip: 'Open attachment',
        ),
        onTap: () => _openAttachment(att.fileUrl),
      ),
    );
  }
}
