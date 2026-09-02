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

class ParkingScreen extends StatefulWidget {
  final int? societyId;
  const ParkingScreen({super.key, this.societyId});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  final SocietyService _societyService = SocietyService();

  int? _resolvedSocietyId;
  int _selectedTab = 0; // 0: Resident Parking, 1: Visitor Parking
  bool _isLoading = true;
  String? _errorMessage;

  List<SocietyParkingModel> _myVehicles = [];
  List<SocietyParkingModel> _visitorParkings = [];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    _resolvedSocietyId = await _societyService.resolveActiveSocietyId(widget.societyId);

    if (_resolvedSocietyId != null) {
      await _loadParkingData();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadParkingData() async {
    if (_resolvedSocietyId == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resResident = await _societyService.getParkings(
        _resolvedSocietyId!,
        isVisitorParking: false,
        limit: 50,
      );
      final resVisitor = await _societyService.getParkings(
        _resolvedSocietyId!,
        isVisitorParking: true,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _myVehicles = resResident.data;
          _visitorParkings = resVisitor.data;
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

  // ── Custom Tab Bar
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          _buildTab('Resident Vehicles', 0, Icons.directions_car_outlined),
          _buildTab('Visitor Parking', 1, Icons.people_outline),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final sel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? _C.border : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: sel ? _C.orange : _C.sub),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? _C.text : _C.sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vehicle Card
  Widget _buildVehicleCard(SocietyParkingModel v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCB99)),
            ),
            child: Icon(
              v.is4Wheeler
                  ? Icons.directions_car_outlined
                  : Icons.two_wheeler_outlined,
              color: _C.orange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.vehicleModel ?? 'Vehicle (${v.vehicleType})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.border),
                      ),
                      child: Text(
                        v.vehicleNo,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _C.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_parking, size: 14, color: _C.sub),
                    const SizedBox(width: 4),
                    Text(
                      'Slot: ${v.parkingSlotNo}',
                      style: const TextStyle(fontSize: 12, color: _C.sub),
                    ),
                    if (v.ownerName.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.person_outline, size: 14, color: _C.sub),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          v.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _C.sub),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Allocate Parking Dialog
  void _showAllocateParkingDialog({bool isVisitor = false}) {
    if (_resolvedSocietyId == null) return;
    final slotController = TextEditingController();
    final plateController = TextEditingController();
    final modelController = TextEditingController();
    String vehicleType = '4_wheeler';
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
                  Text(
                    isVisitor ? 'Request Visitor Parking' : 'Allocate Parking Slot',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _C.text),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: _C.sub), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: slotController,
                decoration: InputDecoration(
                  labelText: 'Parking Slot Number',
                  hintText: 'e.g., B-102 or P-14',
                  filled: true,
                  fillColor: _C.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateController,
                decoration: InputDecoration(
                  labelText: 'Vehicle License Plate',
                  hintText: 'e.g., DL 01 AB 1234',
                  filled: true,
                  fillColor: _C.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Model (Optional)',
                  hintText: 'e.g., Honda City',
                  filled: true,
                  fillColor: _C.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: vehicleType,
                decoration: InputDecoration(
                  labelText: 'Vehicle Type',
                  filled: true,
                  fillColor: _C.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: '4_wheeler', child: Text('4-Wheeler (Car/SUV)')),
                  DropdownMenuItem(value: '2_wheeler', child: Text('2-Wheeler (Bike/Scooter)')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => vehicleType = val);
                },
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
                          final slot = slotController.text.trim();
                          final plate = plateController.text.trim();
                          final model = modelController.text.trim();
                          if (slot.isEmpty || plate.isEmpty) return;

                          setModalState(() => isSubmitting = true);
                          try {
                            await _societyService.allocateParking(
                              _resolvedSocietyId!,
                              parkingSlotNo: slot,
                              vehicleType: vehicleType,
                              vehicleNo: plate,
                              vehicleModel: model.isEmpty ? null : model,
                              isVisitorParking: isVisitor,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadParkingData();
                          } catch (err) {
                            setModalState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(err.toString()), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          isVisitor ? 'Book Visitor Slot' : 'Allocate Slot',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
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

    final items = _selectedTab == 0 ? _myVehicles : _visitorParkings;

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF111827),
          elevation: 0,
          onPressed: () => _showAllocateParkingDialog(isVisitor: _selectedTab == 1),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            _selectedTab == 0 ? 'Allocate Vehicle' : 'Book Visitor Slot',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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
            'Parking Manager',
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
        body: Column(
          children: [
            _buildTabBar(),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _C.orange))
                  : RefreshIndicator(
                      color: _C.orange,
                      onRefresh: _loadParkingData,
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                _selectedTab == 0
                                    ? 'No resident parking slots registered'
                                    : 'No visitor parking records',
                                style: const TextStyle(color: _C.sub, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: items.length,
                              itemBuilder: (_, i) => _buildVehicleCard(items[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
