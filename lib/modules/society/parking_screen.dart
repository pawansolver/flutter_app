import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';

// ─── Colors ────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF9FAFB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
  static const green = Color(0xFF10B981);
}

// ─── Models ────────────────────────────────────────────────────────
class VehicleItem {
  final String name;
  final String plate;
  final String slot;
  final bool isCar;

  const VehicleItem({
    required this.name,
    required this.plate,
    required this.slot,
    this.isCar = true,
  });
}

class VisitorRequest {
  final String visitorName;
  final String vehicleNo;
  final String expectedDate;
  final String status; // 'Approved' | 'Pending'
  final String requestedOn;

  const VisitorRequest({
    required this.visitorName,
    required this.vehicleNo,
    required this.expectedDate,
    required this.status,
    required this.requestedOn,
  });
}

// ─── Dummy Data ────────────────────────────────────────────────────
final List<VehicleItem> _myVehicles = [
  VehicleItem(
    name: 'Maruti Swift Dzire',
    plate: 'BR 01 XX 1234',
    slot: 'Basement – B4',
    isCar: true,
  ),
  VehicleItem(
    name: 'Honda Activa 6G',
    plate: 'BR 01 AB 9876',
    slot: 'Parking Lot – P12',
    isCar: false,
  ),
];

final List<VisitorRequest> _visitorRequests = [
  VisitorRequest(
    visitorName: 'Rahul Verma (Brother)',
    vehicleNo: 'DL 3C AB 5566',
    expectedDate: 'Today, 4:00 PM',
    status: 'Approved',
    requestedOn: '3 Jul 2026',
  ),
  VisitorRequest(
    visitorName: 'Delivery – Flipkart',
    vehicleNo: 'UP 32 GH 2211',
    expectedDate: 'Tomorrow, 12:00 PM',
    status: 'Pending',
    requestedOn: '3 Jul 2026',
  ),
  VisitorRequest(
    visitorName: 'Priya Sharma (Friend)',
    vehicleNo: 'BR 04 CD 4433',
    expectedDate: '28 Jun, 7:00 PM',
    status: 'Approved',
    requestedOn: '27 Jun 2026',
  ),
  VisitorRequest(
    visitorName: 'Plumber – Suresh',
    vehicleNo: 'BR 06 KL 7788',
    expectedDate: '25 Jun, 11:00 AM',
    status: 'Approved',
    requestedOn: '24 Jun 2026',
  ),
];

// ─── Screen ────────────────────────────────────────────────────────
class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  int _selectedTab = 0;

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
          _buildTab('My Vehicles', 0, Icons.directions_car_outlined),
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
              Icon(icon,
                  size: 16,
                  color: sel ? _C.orange : _C.sub),
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

  // ── Status Badge
  Widget _buildStatusBadge(String status) {
    final isApproved = status == 'Approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isApproved
              ? const Color(0xFF065F46)
              : const Color(0xFF9A3412),
        ),
      ),
    );
  }

  // ── Vehicle Card
  Widget _buildVehicleCard(VehicleItem v) {
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
          // Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCB99)),
            ),
            child: Icon(
              v.isCar
                  ? Icons.directions_car_outlined
                  : Icons.two_wheeler_outlined,
              color: _C.orange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Plate badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.border),
                      ),
                      child: Text(
                        v.plate,
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
                    const Icon(Icons.local_parking,
                        size: 14, color: _C.sub),
                    const SizedBox(width: 4),
                    Text(
                      v.slot,
                      style: const TextStyle(
                          fontSize: 12, color: _C.sub),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Edit icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: const Icon(Icons.edit_outlined,
                size: 16, color: _C.sub),
          ),
        ],
      ),
    );
  }

  // ── Visitor Card
  Widget _buildVisitorCard(VisitorRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _C.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(Icons.person_outline,
                    size: 20, color: _C.sub),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.visitorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.vehicleNo,
                      style: const TextStyle(
                          fontSize: 12, color: _C.sub),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(r.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _C.border),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 14, color: _C.sub),
              const SizedBox(width: 5),
              Text(r.expectedDate,
                  style:
                      const TextStyle(fontSize: 12, color: _C.sub)),
              const Spacer(),
              Text(
                'Requested ${r.requestedOn}',
                style:
                    const TextStyle(fontSize: 11, color: _C.sub),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Add Vehicle Dialog
  void _showAddVehicleDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add Vehicle feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Request Guest Slot (FAB action)
  void _showRequestGuestSlot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Request Guest Slot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _C.text,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _C.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.border),
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: _C.sub),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _inputField('Visitor Name', 'e.g., Rahul Verma'),
              const SizedBox(height: 14),
              _inputField(
                  'Vehicle Number', 'e.g., BR 01 XX 1234'),
              const SizedBox(height: 14),
              _inputField(
                  'Expected Date & Time', 'e.g., 5 Jul, 4:00 PM'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Guest slot requested successfully!'),
                        backgroundColor: _C.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Submit Request'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.text)),
        const SizedBox(height: 6),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: _C.sub),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _C.text),
            ),
          ),
        ),
      ],
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
            'Parking Management',
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showRequestGuestSlot,
          backgroundColor: _C.orange,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.add),
          label: const Text(
            'Request Guest Slot',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        body: Column(
          children: [
            _buildTabBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedTab == 0
                  ? _buildMyVehiclesTab()
                  : _buildVisitorTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyVehiclesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        ..._myVehicles.map(_buildVehicleCard),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showAddVehicleDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Vehicle'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.text,
            side: const BorderSide(color: _C.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitorTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _visitorRequests.length,
      itemBuilder: (_, i) =>
          _buildVisitorCard(_visitorRequests[i]),
    );
  }
}
