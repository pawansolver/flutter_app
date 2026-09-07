import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import 'create_service_flow_screen.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen>
    with SingleTickerProviderStateMixin {
  final _service = ServiceMarketplaceService();
  late TabController _tabController;

  bool _loading = true;
  String? _errorMessage;
  List<ServiceListingModel> _allServices = [];

  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.getProviderListings();
      if (!mounted) return;
      setState(() {
        _allServices = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  List<ServiceListingModel> _getFilteredServices(int tabIndex) {
    List<ServiceListingModel> filtered = _allServices;

    // Filter by Tab
    if (tabIndex == 1) {
      filtered = filtered.where((s) => s.isAvailable).toList();
    } else if (tabIndex == 2) {
      filtered = filtered.where((s) => !s.isAvailable).toList();
    }

    // Filter by Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((s) {
        final title = s.title.toLowerCase();
        final cat = (s.categoryName ?? '').toLowerCase();
        final desc = (s.description ?? '').toLowerCase();
        return title.contains(q) || cat.contains(q) || desc.contains(q);
      }).toList();
    }

    return filtered;
  }

  Future<void> _toggleAvailability(ServiceListingModel listing) async {
    final newStatus = !listing.isAvailable;
    final original = listing.isAvailable;

    // Optimistic UI update
    setState(() {
      _allServices = _allServices.map((s) {
        if (s.id == listing.id) {
          return s.copyWith(isAvailable: newStatus);
        }
        return s;
      }).toList();
    });

    try {
      await _service.updateListing(listing.id, isAvailable: newStatus);
      _showToast(newStatus ? 'Service marked as Active' : 'Service marked as Inactive');
    } catch (e) {
      // Revert on failure
      if (!mounted) return;
      setState(() {
        _allServices = _allServices.map((s) {
          if (s.id == listing.id) {
            return s.copyWith(isAvailable: original);
          }
          return s;
        }).toList();
      });
      _showToast('Failed to update status: $e');
    }
  }

  Future<void> _confirmDelete(ServiceListingModel listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Service Listing?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Are you sure you want to delete "${listing.title}"? Neighbors will no longer be able to request this service.',
          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteListing(listing.id);
        setState(() {
          _allServices.removeWhere((s) => s.id == listing.id);
        });
        _showToast('Service listing deleted');
      } catch (e) {
        _showToast('Failed to delete: $e');
      }
    }
  }

  void _showEditSheet(ServiceListingModel listing) {
    final titleController = TextEditingController(text: listing.title);
    final descController = TextEditingController(text: listing.description ?? '');
    final priceController = TextEditingController(text: listing.price?.toStringAsFixed(0) ?? '');
    final durationController = TextEditingController(text: listing.duration ?? '');
    bool isAvail = listing.isAvailable;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Service Listing',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Service Title *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Price (₹) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                          const Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: durationController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available to take requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Switch(
                      value: isAvail,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (val) => setSheetState(() => isAvail = val),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () async {
                      final updatedPrice = double.tryParse(priceController.text.trim());
                      Navigator.pop(ctx);
                      try {
                        final updated = await _service.updateListing(
                          listing.id,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          price: updatedPrice,
                          duration: durationController.text.trim(),
                          isAvailable: isAvail,
                        );
                        setState(() {
                          _allServices = _allServices.map((s) => s.id == listing.id ? updated : s).toList();
                        });
                        _showToast('Listing updated successfully');
                      } catch (e) {
                        _showToast('Update failed: $e');
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Services',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF111827)),
            tooltip: 'Create Service',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateServiceFlowScreen()),
              );
              if (created == true) _fetchServices();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                hintText: 'Search my services...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Tabs: All, Active, Inactive
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF111827),
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              indicatorColor: const Color(0xFF111827),
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: 'All (${_allServices.length})'),
                Tab(text: 'Active (${_allServices.where((s) => s.isAvailable).length})'),
                Tab(text: 'Inactive (${_allServices.where((s) => !s.isAvailable).length})'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Body Views
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF111827)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Unable to load services',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _fetchServices,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildListForTab(0),
        _buildListForTab(1),
        _buildListForTab(2),
      ],
    );
  }

  Widget _buildListForTab(int tabIndex) {
    final list = _getFilteredServices(tabIndex);

    if (list.isEmpty) {
      return _buildEmptyState(tabIndex);
    }

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _fetchServices,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildServiceCard(item);
        },
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    String title;
    String subtitle;
    String ctaText;

    if (_searchQuery.isNotEmpty) {
      title = 'No matches found';
      subtitle = 'Try checking for typos or searching a different keyword.';
      ctaText = 'Clear Search';
    } else if (tabIndex == 1) {
      title = 'No active services';
      subtitle = 'You have no services currently available for neighbor bookings.';
      ctaText = 'Add New Service';
    } else if (tabIndex == 2) {
      title = 'No inactive services';
      subtitle = 'All your published services are currently active.';
      ctaText = 'Add New Service';
    } else {
      title = 'No services created yet';
      subtitle = 'Start listing your trade skills to receive neighborhood requests.';
      ctaText = 'Create First Service';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.handyman_outlined, size: 36, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () async {
                if (_searchQuery.isNotEmpty) {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                } else {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateServiceFlowScreen()),
                  );
                  if (created == true) _fetchServices();
                }
              },
              child: Text(ctaText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(ServiceListingModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handyman, size: 22, color: Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.categoryName ?? 'General',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2B7BB9)),
                          ),
                        ),
                        if (item.duration != null && item.duration!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•  ${item.duration}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isAvailable ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.isAvailable ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.isAvailable ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.isAvailable ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.3),
            ),
          ],

          const Divider(height: 20, color: Color(0xFFF3F4F6)),

          // Bottom Bar: Price and Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.price != null ? '₹${item.price!.toStringAsFixed(0)}' : 'Custom Quote',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              Row(
                children: [
                  // Toggle Active/Inactive
                  IconButton(
                    icon: Icon(
                      item.isAvailable ? Icons.toggle_on : Icons.toggle_off,
                      color: item.isAvailable ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      size: 28,
                    ),
                    tooltip: item.isAvailable ? 'Deactivate' : 'Activate',
                    onPressed: () => _toggleAvailability(item),
                  ),
                  // Edit Action
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF4B5563), size: 20),
                    tooltip: 'Edit Listing',
                    onPressed: () => _showEditSheet(item),
                  ),
                  // Delete Action
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(item),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
