import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_config.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

class DocumentsScreen extends StatefulWidget {
  final int? societyId;
  final String? userRole; // 'admin' | 'committee' | 'resident'

  const DocumentsScreen({
    super.key,
    this.societyId,
    this.userRole,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _societyService = SocietyService();
  final _searchController = TextEditingController();

  int? _activeSocietyId;
  String _userRole = 'resident';
  bool _isLoading = true;
  String? _errorMessage;

  List<SocietyDocumentModel> _documents = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';

  bool get _canManage =>
      _userRole.toLowerCase() == 'admin' || _userRole.toLowerCase() == 'committee';

  final _categories = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'bye_laws', 'label': 'Bye-Laws'},
    {'key': 'agm_minutes', 'label': 'AGM Minutes'},
    {'key': 'financial_report', 'label': 'Financial'},
    {'key': 'noc_rules', 'label': 'NOC & Rules'},
    {'key': 'circular', 'label': 'Circulars'},
    {'key': 'other', 'label': 'General'},
  ];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _activeSocietyId = widget.societyId ?? await _societyService.resolveActiveSocietyId();
      _userRole = widget.userRole ?? 'resident';

      if (_activeSocietyId == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No active society found. Please join or register a society first.';
            _isLoading = false;
          });
        }
        return;
      }

      await _fetchDocuments();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDocuments() async {
    if (_activeSocietyId == null) return;

    try {
      final res = await _societyService.getDocuments(
        _activeSocietyId!,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _documents = res.data;
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

  List<SocietyDocumentModel> get _filteredDocuments {
    if (_searchQuery.trim().isEmpty) return _documents;
    final q = _searchQuery.trim().toLowerCase();
    return _documents.where((d) {
      return d.title.toLowerCase().contains(q) ||
          (d.description ?? '').toLowerCase().contains(q) ||
          d.categoryDisplayName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openDocument(SocietyDocumentModel doc) async {
    final rawUrl = doc.fileUrl;
    final normalized = ApiConfig.normalizeMediaUrl(rawUrl) ?? rawUrl;
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid document URL')),
      );
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open document: $normalized')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<void> _showUploadSheet() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'bye_laws';
    String? pickedPath;
    String? pickedName;

    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Upload Society Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Document Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                  items: _categories.where((c) => c['key'] != 'all').map((c) {
                    return DropdownMenuItem(value: c['key'], child: Text(c['label']!));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 16),

                // File picker button
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg'],
                    );
                    final file = res.firstOrNull;
                    if (file != null) {
                      setModalState(() {
                        pickedPath = file.path;
                        pickedName = file.name;
                      });
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(pickedName ?? 'Choose Document File *'),
                ),
                if (pickedName != null) ...[
                  const SizedBox(height: 4),
                  Text('Selected: $pickedName', style: const TextStyle(fontSize: 12, color: Colors.green)),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a document title')),
                        );
                        return;
                      }
                      if (pickedPath == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please select a file to upload')),
                        );
                        return;
                      }

                      try {
                        await _societyService.createDocument(
                          _activeSocietyId!,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          category: category,
                          filePath: pickedPath!,
                          fileName: pickedName,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Upload Document'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (uploaded == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully'), backgroundColor: Colors.green),
        );
        _fetchDocuments();
      }
    }
  }

  Future<void> _deleteDocument(SocietyDocumentModel doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _societyService.deleteDocument(doc.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted'), backgroundColor: Colors.green),
          );
          _fetchDocuments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Documents'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDocuments),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _showUploadSheet,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
            )
          : null,
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents by title or category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['key'];
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedCategory = cat['key']!);
                      _fetchDocuments();
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _initAndLoad,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchDocuments,
                        child: _filteredDocuments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder_open, size: 56, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No documents matching "$_searchQuery"'
                                          : 'No documents uploaded yet',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    if (_canManage && _searchQuery.isEmpty) ...[
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _showUploadSheet,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Upload First Document'),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredDocuments.length,
                                separatorBuilder: (_, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final doc = _filteredDocuments[index];
                                  return Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.orange.shade50,
                                        child: Icon(
                                          (doc.fileType ?? '').contains('pdf')
                                              ? Icons.picture_as_pdf
                                              : Icons.description,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                      title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (doc.description != null && doc.description!.isNotEmpty)
                                            Text(doc.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  doc.categoryDisplayName,
                                                  style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (doc.fileSize != null)
                                                Text('${(doc.fileSize! / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new, color: Colors.blue),
                                            tooltip: 'Open / Download',
                                            onPressed: () => _openDocument(doc),
                                          ),
                                          if (_canManage)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteDocument(doc),
                                            ),
                                        ],
                                      ),
                                      onTap: () => _openDocument(doc),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
