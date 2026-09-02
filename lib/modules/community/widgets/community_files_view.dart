import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/community_models.dart';

class CommunityFilesView extends StatelessWidget {
  final List<CommunityDocumentModel> documents;
  final VoidCallback? onUploadDocument;
  final Function(CommunityDocumentModel doc)? onDeleteDocument;
  final bool isMember;
  final bool canManage;

  const CommunityFilesView({
    super.key,
    required this.documents,
    this.onUploadDocument,
    this.onDeleteDocument,
    this.isMember = false,
    this.canManage = false,
  });

  String _formatFileSize(String? rawSize) {
    if (rawSize == null || rawSize.trim().isEmpty) return '1.2 MB';
    final trimmed = rawSize.trim();
    if (trimmed.toLowerCase().contains('b')) return trimmed;
    final bytes = int.tryParse(trimmed);
    if (bytes != null) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return trimmed;
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFFF6B00);
    }
  }

  Future<void> _downloadAndOpen(
    BuildContext context,
    CommunityDocumentModel document,
  ) async {
    final url = document.fileUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This document has no download URL')),
      );
      return;
    }

    final uri = Uri.tryParse(url);

    // On Flutter Web: Open document URL directly in a new tab or external viewer
    if (kIsWeb) {
      if (uri != null) {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open document link')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open document: $e')),
            );
          }
        }
      }
      return;
    }

    // On Native Platforms (Android, iOS, Desktop): Download locally & open with default app
    try {
      final directory = await getApplicationDocumentsDirectory();
      final parsedPath = Uri.tryParse(url)?.path ?? '';
      final fileName = p.basename(parsedPath).isNotEmpty
          ? p.basename(parsedPath)
          : (document.title.endsWith('.pdf')
              ? document.title
              : '${document.title}.${document.fileType}');
      final path = p.join(directory.path, fileName);
      await Dio().download(url, path);
      await OpenFilex.open(path);
    } catch (error) {
      // Graceful fallback to url_launcher if native open/download throws
      if (uri != null) {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $error')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, CommunityDocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Document'),
          ],
        ),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onDeleteDocument?.call(doc);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);

    if (documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 54,
                color: Colors.grey,
              ),
              const SizedBox(height: 14),
              const Text(
                'No Documents or Files Yet',
                style: TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Community bylaws, rules, registration forms and circulars will be listed here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              if ((isMember || canManage) && onUploadDocument != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onUploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Upload Document'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Action Header Bar for adding more files
        if ((isMember || canManage) && onUploadDocument != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${documents.length} ${documents.length == 1 ? 'Document' : 'Documents'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onUploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Document',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // Documents List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = documents[index];
              final fileColor = _getFileColor(doc.fileType);
              final fileIcon = _getFileIcon(doc.fileType);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: fileColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(fileIcon, color: fileColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: darkText,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                _formatFileSize(doc.fileSize),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                ' • ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy').format(doc.uploadedAt),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: primaryOrange,
                      ),
                      tooltip: 'Download File',
                      onPressed: () => _downloadAndOpen(context, doc),
                    ),
                    if (canManage && onDeleteDocument != null)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                        tooltip: 'Delete Document',
                        onPressed: () => _confirmDelete(context, doc),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

