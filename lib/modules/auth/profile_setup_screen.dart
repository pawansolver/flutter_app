import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_config.dart';
import '../../services/authenticated_dio.dart';
import '../../shared/permission_guidance.dart';
import 'permissions_prompt_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String? initialRole;

  const ProfileSetupScreen({super.key, this.initialRole});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String _selectedRole = 'Resident';
  String _locationStatus = '';
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  double? _latitude;
  double? _longitude;

  final List<String> _availabilityDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final Set<String> _selectedDays = {};

  final _fullNameCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _operatingHoursCtrl = TextEditingController();
  final _serviceCategoryCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _societyNameCtrl = TextEditingController();
  final _towerBlockCtrl = TextEditingController();
  final _flatNumberCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();

  String? _bannerUrl; // URL returned by backend after upload
  bool _isUploadingBanner = false;

  final _dio = AuthenticatedDio().dio;

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null) {
      final role = widget.initialRole!;
      if (role == 'Service Provider' || role == 'Provider') {
        _selectedRole = 'Provider';
      } else if (role == 'Business Owner' || role == 'Shopkeeper') {
        _selectedRole = 'Business Owner';
      } else if (role == 'Society Admin') {
        _selectedRole = 'Society Admin';
      } else {
        _selectedRole = 'Resident';
      }
    }
  }

  // ── Pick image from gallery and upload to backend (Web + Mobile safe) ─────
  Future<void> _pickAndUploadBanner() async {
    final picker = ImagePicker();

    // On Web: ImageSource.gallery opens the browser file picker
    // On Mobile: opens device gallery
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
    } catch (error) {
      if (!mounted) return;
      if (isMediaPermissionError(error)) {
        await showPermissionSettingsDialog(
          context,
          title: 'Photo access needed',
          message:
              'Allow photo access in app settings to choose a profile banner.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open or read that image.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (picked == null) return;

    setState(() {
      _isUploadingBanner = true;
    });

    try {
      // Web doesn't have a real file path — readAsBytes() works on ALL platforms
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'banner': MultipartFile.fromBytes(bytes, filename: picked.name),
      });

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/user-profile/upload-banner',
        data: formData,
      );

      final url = response.data['data']['bannerUrl'] as String;
      setState(() {
        _bannerUrl = url;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Banner uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.response?.data?['message'] ?? e.message}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBanner = false;
        });
      }
    }
  }

  Future<void> _detectLocation(String loadingText, String resultText) async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = loadingText;
    });

    try {
      // Request permission first (works on both Mobile & Web)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission was denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Please enable it from Settings.',
        );
      }

      // Use modern LocationSettings API (works cross-platform: Mobile + Web)
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isLoadingLocation = false;
          // Temporarily show coordinates while reverse geocoding
          _locationStatus = '📍 Fetching address...';
        });
      }

      // Reverse Geocode: Nominatim API (OpenStreetMap) - works on Web + Mobile
      try {
        final geoResponse = await Dio().get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': position.latitude,
            'lon': position.longitude,
            'format': 'json',
            'addressdetails': 1,
            'zoom': 18, // Street level accuracy
          },
          options: Options(headers: {'User-Agent': 'smartgali/1.0'}),
        );

        if (mounted) {
          final data = geoResponse.data as Map<String, dynamic>;

          // display_name is pre-formatted by Nominatim: e.g.
          // "Fraser Road, Patna Rural, Patna, Bihar, 803210, India"
          // Remove PIN code and "India" suffix to keep it compact
          String displayName = data['display_name']?.toString() ?? '';
          if (displayName.isNotEmpty) {
            // Remove ", India" at end and any 6-digit PIN code
            displayName = displayName
                .replaceAll(RegExp(r',\s*\d{6}'), '') // remove PIN
                .replaceAll(RegExp(r',\s*India\s*$'), '') // remove India
                .trim();
          }

          final readableAddress = displayName.isNotEmpty
              ? displayName
              : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

          setState(() {
            _locationStatus = '📍 $readableAddress';
          });
        }
      } catch (_) {
        // Fallback to precise coordinates if Nominatim API fails
        if (mounted) {
          setState(() {
            _locationStatus =
                '📍 ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          });
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = '❌ Failed to detect location';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _submitProfile() async {
    if (_fullNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Full Name')),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please detect your location')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final roleKey = _selectedRole.toLowerCase() == 'business owner'
          ? 'business'
          : (_selectedRole.toLowerCase() == 'society admin' ? 'society_admin' : _selectedRole.toLowerCase());

      final Map<String, dynamic> data = {
        "role": roleKey,
        "fullName": _fullNameCtrl.text,
        "latitude": _latitude,
        "longitude": _longitude,
      };

      if (_selectedRole.toLowerCase() == 'shopkeeper' || _selectedRole.toLowerCase() == 'business owner') {
        data["businessName"] = _businessNameCtrl.text;
        data["operatingHours"] = _operatingHoursCtrl.text;
        if (_bannerUrl != null) data["bannerUrl"] = _bannerUrl;
      } else if (_selectedRole.toLowerCase() == 'provider' || _selectedRole.toLowerCase() == 'service provider') {
        data["serviceCategory"] = _serviceCategoryCtrl.text;
        data["hourlyRate"] = double.tryParse(_hourlyRateCtrl.text) ?? 0.0;
        data["availabilityDays"] = _selectedDays.toList();
      } else if (_selectedRole.toLowerCase() == 'society admin') {
        data["societyName"] = _societyNameCtrl.text;
        data["towerBlock"] = _towerBlockCtrl.text;
        data["flatNumber"] = _flatNumberCtrl.text;
        data["designation"] = _designationCtrl.text;
      }

      final response = await _dio.put(
        '${ApiConfig.baseUrl}/user-profile/complete-setup',
        data: data,
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PermissionsPromptScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('API Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- Top Header with Background & Icon ---
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipPath(
                clipper: _BottomCurveClipper(),
                child: Image.asset(
                  'assets/images/neighbourhood_bg.png',
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 0,
                left: 8,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF111827),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              // Center Icon
              Positioned(
                bottom: -20,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.manage_accounts_rounded,
                      color: Color(0xFF10B981),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Title ---
                  const Text(
                    'Profile Setup',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: brandGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Complete your profile details below',
                    style: TextStyle(fontSize: 13, color: subText),
                  ),
                  const SizedBox(height: 32),

                  // --- Role Selector ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoleChip('Resident', Icons.home_rounded),
                        const SizedBox(width: 12),
                        _buildRoleChip('Business Owner', Icons.storefront_rounded),
                        const SizedBox(width: 12),
                        _buildRoleChip('Provider', Icons.handyman_rounded),
                        const SizedBox(width: 12),
                        _buildRoleChip('Society Admin', Icons.admin_panel_settings_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Dynamic Form Based on Role ---
                  _buildDynamicForm(),

                  const SizedBox(height: 32),

                  // --- Trust Badge ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: brandGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your information is safe with us',
                                style: TextStyle(
                                  color: brandGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We respect your privacy and\nnever share your data.',
                                style: TextStyle(
                                  color: subText,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified_user,
                          color: brandGreen.withValues(alpha: 0.6),
                          size: 48,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // --- Continue Button ---
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Enter smartgali',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, IconData icon) {
    bool isSelected = _selectedRole.toLowerCase() == label.toLowerCase();
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = label;
          _locationStatus = ''; // Reset location on tab change
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? brandGreen : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? brandGreen : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : brandGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : primaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: brandGreen, size: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicForm() {
    switch (_selectedRole.toLowerCase()) {
      case 'shopkeeper':
      case 'business owner':
        return _buildShopkeeperForm();
      case 'provider':
      case 'service provider':
        return _buildProviderForm();
      case 'society admin':
        return _buildSocietyAdminForm();
      case 'resident':
      default:
        return _buildResidentForm();
    }
  }

  // --- Styled Input Field ---
  Widget _buildStyledInput(
    String label,
    String hint,
    IconData icon, {
    TextEditingController? controller,
  }) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: brandGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: brandGreen.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: brandGreen, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: brandGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: subText.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Beautiful Location Button ---
  Widget _buildLocationCard({
    required String label,
    required String subtitle,
    required String loadingText,
    required String resultText,
  }) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return GestureDetector(
      onTap: _isLoadingLocation
          ? null
          : () => _detectLocation(loadingText, resultText),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: _locationStatus.isNotEmpty
              ? Border.all(color: brandGreen, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: brandGreen,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoadingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationStatus.isNotEmpty ? _locationStatus : label,
                    style: TextStyle(
                      color: _locationStatus.isNotEmpty
                          ? brandGreen
                          : primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoadingLocation
                        ? loadingText
                        : (_locationStatus.isNotEmpty
                              ? 'Tap to update location'
                              : subtitle),
                    style: const TextStyle(
                      color: subText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: brandGreen, size: 16),
          ],
        ),
      ),
    );
  }

  // --- Resident Form ---
  Widget _buildResidentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyledInput(
          'Full Name',
          'e.g., Pawan Kumar',
          Icons.person_outline,
          controller: _fullNameCtrl,
        ),
        const SizedBox(height: 24),
        _buildLocationCard(
          label: 'Detect My Location',
          subtitle: 'Tap to detect your live GPS location',
          loadingText: 'Fetching GPS coordinates...',
          resultText: '',
        ),
      ],
    );
  }

  // --- Shopkeeper Form ---
  Widget _buildShopkeeperForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyledInput(
          'Full Name',
          'e.g., Pawan Kumar',
          Icons.person_outline,
          controller: _fullNameCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Business Name',
          'e.g., Verma Stores',
          Icons.storefront,
          controller: _businessNameCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Operating Hours',
          'e.g., 9 AM - 9 PM',
          Icons.access_time,
          controller: _operatingHoursCtrl,
        ),
        const SizedBox(height: 24),
        // ── Live Banner Upload Widget ───────────────────────────────────
        GestureDetector(
          onTap: _isUploadingBanner ? null : _pickAndUploadBanner,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: _bannerUrl != null
                  ? Colors.transparent
                  : const Color(0xFFF9FAFB),
              border: Border.all(
                color: _bannerUrl != null
                    ? const Color(0xFF10B981)
                    : Colors.grey.shade300,
                width: _bannerUrl != null ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isUploadingBanner
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF10B981),
                          strokeWidth: 2,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : _bannerUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(_bannerUrl!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload Shop Banner',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to choose from gallery',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
        _buildLocationCard(
          label: 'Detect Shop Location',
          subtitle: 'Tap to detect your live shop GPS location',
          loadingText: 'Fetching GPS coordinates...',
          resultText: '',
        ),
      ],
    );
  }

  // --- Provider Form ---
  Widget _buildProviderForm() {
    const Color primaryText = Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyledInput(
          'Full Name',
          'e.g., Pawan Kumar',
          Icons.person_outline,
          controller: _fullNameCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Service Category',
          'e.g., Plumber, Tutor',
          Icons.handyman_outlined,
          controller: _serviceCategoryCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Hourly Rate',
          'e.g., ₹200 / hr',
          Icons.payments_outlined,
          controller: _hourlyRateCtrl,
        ),
        const SizedBox(height: 24),
        const Text(
          'Manage Availability Days',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availabilityDays.map((day) {
            final isSelected = _selectedDays.contains(day);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF10B981) : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE5E7EB),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    color: isSelected ? Colors.white : primaryText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildLocationCard(
          label: 'Detect Base Location',
          subtitle: 'Tap to detect your live GPS location',
          loadingText: 'Fetching GPS coordinates...',
          resultText: '',
        ),
      ],
    );
  }

  // --- Society Admin Form ---
  Widget _buildSocietyAdminForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyledInput(
          'Society / RWA Name',
          'e.g., Green Valley Apartments, Palm Heights',
          Icons.apartment_rounded,
          controller: _societyNameCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Tower / Wing / Block',
          'e.g., Tower B, Phase 2, Wing A',
          Icons.domain_rounded,
          controller: _towerBlockCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Flat / Office Unit Number',
          'e.g., Flat 402, Admin Office Ground Floor',
          Icons.meeting_room_outlined,
          controller: _flatNumberCtrl,
        ),
        const SizedBox(height: 16),
        _buildStyledInput(
          'Committee Role / Designation',
          'e.g., President, Secretary, Facility Manager',
          Icons.badge_outlined,
          controller: _designationCtrl,
        ),
        const SizedBox(height: 24),
        _buildLocationCard(
          label: 'Detect Society GPS Location',
          subtitle: 'Required to anchor society operations & residents',
          loadingText: 'Detecting society boundary location...',
          resultText: '',
        ),
      ],
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 40,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
