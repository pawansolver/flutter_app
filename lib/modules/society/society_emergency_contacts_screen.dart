import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

class SocietyEmergencyContactsScreen extends StatefulWidget {
  final int societyId;
  final String userRole; // 'admin' | 'committee' | 'resident'

  const SocietyEmergencyContactsScreen({
    super.key,
    required this.societyId,
    required this.userRole,
  });

  @override
  State<SocietyEmergencyContactsScreen> createState() => _SocietyEmergencyContactsScreenState();
}

class _SocietyEmergencyContactsScreenState extends State<SocietyEmergencyContactsScreen> {
  final _societyService = SocietyService();

  bool _isLoading = true;
  String? _errorMessage;
  List<SocietyEmergencyContactModel> _contacts = [];
  String _selectedCategory = 'all';

  bool get _canManage =>
      widget.userRole.toLowerCase() == 'admin' ||
      widget.userRole.toLowerCase() == 'committee';
  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  final _categories = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'security', 'label': 'Security'},
    {'key': 'medical', 'label': 'Ambulance / Medical'},
    {'key': 'police', 'label': 'Police'},
    {'key': 'fire', 'label': 'Fire'},
    {'key': 'management', 'label': 'Office / Manager'},
    {'key': 'electrician', 'label': 'Electrician'},
    {'key': 'plumber', 'label': 'Plumber'},
    {'key': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _societyService.getEmergencyContacts(
        widget.societyId,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _contacts = list;
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

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot place call to $phone')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    final nameCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final altPhoneCtrl = TextEditingController();
    String category = 'security';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desigCtrl,
                  decoration: const InputDecoration(labelText: 'Designation / Service (e.g. Guard Gate 1)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Alternate Phone (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories.where((c) => c['key'] != 'all').map((c) {
                    return DropdownMenuItem(value: c['key'], child: Text(c['label']!));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name and Phone are required')),
                  );
                  return;
                }
                try {
                  await _societyService.createEmergencyContact(
                    widget.societyId,
                    name: nameCtrl.text.trim(),
                    designation: desigCtrl.text.trim().isEmpty ? null : desigCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    altPhone: altPhoneCtrl.text.trim().isEmpty ? null : altPhoneCtrl.text.trim(),
                    category: category,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      _loadContacts();
    }
  }

  Future<void> _deleteContact(SocietyEmergencyContactModel contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
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
        await _societyService.deleteEmergencyContact(contact.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted'), backgroundColor: Colors.green),
          );
          _loadContacts();
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

  Future<void> _showBroadcastAlertDialog() async {
    final titleCtrl = TextEditingController(text: 'EMERGENCY ALERT');
    final msgCtrl = TextEditingController();
    String severity = 'high';

    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Broadcast Alert'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CRITICAL: This will broadcast an immediate push notification alert to ALL registered residents of this society.',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Alert Title *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Message *',
                    hintText: 'e.g. Fire alarm triggered in Block B. Please evacuate immediately.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('HIGH SEVERITY')),
                    DropdownMenuItem(value: 'critical', child: Text('CRITICAL / LIFE SAFETY')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => severity = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Title and message are required')),
                  );
                  return;
                }
                try {
                  await _societyService.broadcastEmergencyAlert(
                    widget.societyId,
                    title: titleCtrl.text.trim(),
                    message: msgCtrl.text.trim(),
                    severity: severity,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('SEND BROADCAST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert broadcasted to society residents!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              tooltip: 'Broadcast Emergency Alert',
              onPressed: _showBroadcastAlertDialog,
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add_call),
              label: const Text('Add Contact'),
            )
          : null,
      body: Column(
        children: [
          // Category filter bar
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      _loadContacts();
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadContacts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: _contacts.isEmpty
                            ? const Center(
                                child: Text('No emergency contacts listed for this category',
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _contacts.length,
                                separatorBuilder: (_, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final c = _contacts[index];
                                  return Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _getCategoryColor(c.category).withValues(alpha: 0.15),
                                        child: Icon(_getCategoryIcon(c.category), color: _getCategoryColor(c.category)),
                                      ),
                                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (c.designation != null && c.designation!.isNotEmpty)
                                            Text(c.designation!, style: const TextStyle(fontSize: 12)),
                                          Text('Phone: ${c.phone}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          if (c.altPhone != null && c.altPhone!.isNotEmpty)
                                            Text('Alt: ${c.altPhone}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.phone, color: Colors.green),
                                            tooltip: 'Call',
                                            onPressed: () => _makeCall(c.phone),
                                          ),
                                          if (_canManage)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteContact(c),
                                            ),
                                        ],
                                      ),
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'security':
        return Icons.security;
      case 'medical':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire':
        return Icons.local_fire_department;
      case 'management':
        return Icons.business;
      case 'electrician':
        return Icons.electrical_services;
      case 'plumber':
        return Icons.plumbing;
      default:
        return Icons.contact_phone;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'security':
        return Colors.indigo;
      case 'medical':
        return Colors.red;
      case 'police':
        return Colors.blue;
      case 'fire':
        return Colors.deepOrange;
      case 'management':
        return Colors.teal;
      case 'electrician':
        return Colors.amber.shade800;
      case 'plumber':
        return Colors.cyan;
      default:
        return Colors.grey.shade700;
    }
  }
}
