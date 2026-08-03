import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/permission_guidance.dart';
import 'profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfileModel? profile;
  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProfileService();
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  double? _uploadProgress;
  String? _avatarUrl;
  Uint8List? _avatarPreview;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  _LocationStatus _locationStatus = _LocationStatus.detecting;
  String _locationMessage = 'Detecting your current location…';

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _hydrate(widget.profile!);
      _loading = false;
    } else {
      _fetch();
    }
    unawaited(_detectLocation());
  }

  void _hydrate(UserProfileModel p) {
    _nameController.text = p.fullName;
    _emailController.text = p.email ?? '';
    _phoneController.text = p.phone ?? '';
    _bioController.text = p.bio ?? '';
    _avatarUrl = p.avatarUrl;
    if (_locationStatus != _LocationStatus.detected) {
      _locationName = p.locationName;
      _latitude = p.latitude;
      _longitude = p.longitude;
    }
  }

  Future<void> _fetch() async {
    final result = await _service.getMe();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      _hydrate(result.data!);
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_uploadingAvatar) {
      _showError('Please wait for the avatar upload to finish.');
      return;
    }

    setState(() => _saving = true);
    final result = await _service.updateProfile(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      bio: _bioController.text.trim(),
      locationName: _locationName,
      latitude: _latitude,
      longitude: _longitude,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile Updated Successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to update profile'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showAvatarSourcePicker() async {
    if (_uploadingAvatar) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;

      final preview = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarPreview = preview;
        _uploadingAvatar = true;
        _uploadProgress = 0;
      });

      final result = await _service.uploadAvatar(
        image,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = sent / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _uploadProgress = null;
        if (result.isSuccess) {
          _avatarUrl = result.data;
          _avatarPreview = null;
        } else {
          _avatarPreview = null;
        }
      });
      if (!result.isSuccess) {
        _showError(result.error ?? 'Failed to upload avatar');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _uploadProgress = null;
        _avatarPreview = null;
      });
      if (isMediaPermissionError(error)) {
        await showPermissionSettingsDialog(
          context,
          title: source == ImageSource.camera
              ? 'Camera access needed'
              : 'Photo access needed',
          message: source == ImageSource.camera
              ? 'Allow camera access in app settings to take a profile photo.'
              : 'Allow photo access in app settings to choose a profile photo.',
        );
        return;
      }
      _showError('Could not open or read that image.');
    }
  }

  Future<void> _detectLocation() async {
    if (mounted) {
      setState(() {
        _locationStatus = _LocationStatus.detecting;
        _locationMessage = 'Detecting your current location…';
      });
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationFailure(
          _LocationStatus.serviceDisabled,
          'Location services are turned off.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationFailure(
          _LocationStatus.denied,
          'Location permission was denied.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationFailure(
          _LocationStatus.deniedForever,
          'Location permission is permanently denied.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final locationName = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (locationName.isEmpty) {
        throw StateError('No readable address found for this position');
      }
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationName = locationName;
        _locationStatus = _LocationStatus.detected;
        _locationMessage = locationName;
      });
    } on TimeoutException {
      _setLocationFailure(
        _LocationStatus.error,
        'Location detection timed out. Please try again.',
      );
    } catch (_) {
      _setLocationFailure(
        _LocationStatus.error,
        'Could not detect a readable location. Please try again.',
      );
    }
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'lat': lat, 'lon': lon, 'format': 'json'},
        options: Options(headers: {'User-Agent': 'smartgali/1.0'}),
      );
      final addr = resp.data['address'];
      if (addr == null) return '';
      final parts = <String>[
        if (addr['neighbourhood'] != null) addr['neighbourhood'].toString(),
        if (addr['suburb'] != null && addr['neighbourhood'] == null)
          addr['suburb'].toString(),
        if (addr['city'] != null)
          addr['city'].toString()
        else if (addr['town'] != null)
          addr['town'].toString(),
        if (addr['state'] != null) addr['state'].toString(),
      ];
      return parts.toSet().join(', ');
    } catch (_) {
      return '';
    }
  }

  void _setLocationFailure(_LocationStatus status, String message) {
    if (!mounted) return;
    setState(() {
      _locationStatus = status;
      _locationMessage = message;
    });
  }

  Future<void> _runLocationAction() async {
    if (_locationStatus == _LocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    if (_locationStatus == _LocationStatus.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    await _detectLocation();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _showAvatarSourcePicker,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFE5E7EB),
                              backgroundImage: _avatarImage(),
                              child: _avatarImage() == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            if (_uploadingAvatar)
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: Color(0x88000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: _uploadProgress,
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 17,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _uploadingAvatar
                          ? 'Uploading avatar…'
                          : 'Tap to change photo',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildFlatTextField(
                      label: 'Full Name',
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) {
                          return 'Full name is required';
                        }
                        if (name.length < 2) {
                          return 'Enter at least 2 characters';
                        }
                        if (name.length > 80) {
                          return 'Use 80 characters or fewer';
                        }
                        if (!RegExp(
                          r"^[\p{L}][\p{L}\p{M} .'-]*$",
                          unicode: true,
                        ).hasMatch(name)) {
                          return 'Enter a valid full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFlatTextField(
                      label: 'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return null;
                        }
                        if (email.length > 254) {
                          return 'Email address is too long';
                        }
                        if (!RegExp(
                          r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
                        ).hasMatch(email)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFlatTextField(
                      label: 'Phone Number',
                      controller: _phoneController,
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 16),
                    _buildFlatTextField(
                      label: 'Bio / About',
                      controller: _bioController,
                      maxLines: 3,
                      maxLength: 300,
                      textInputAction: TextInputAction.newline,
                      validator: (value) {
                        if ((value?.trim().length ?? 0) > 300) {
                          return 'Use 300 characters or fewer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLocationCard(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: (_saving || _uploadingAvatar) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlatTextField({
    required String label,
    required TextEditingController controller,
    bool isReadOnly = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(
            color: isReadOnly ? Colors.grey.shade600 : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isReadOnly ? const Color(0xFFF3F4F6) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isReadOnly
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF111827),
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider? _avatarImage() {
    if (_avatarPreview != null) return MemoryImage(_avatarPreview!);
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  Widget _buildLocationCard() {
    final detecting = _locationStatus == _LocationStatus.detecting;
    final detected = _locationStatus == _LocationStatus.detected;
    final settingsAction =
        _locationStatus == _LocationStatus.serviceDisabled ||
        _locationStatus == _LocationStatus.deniedForever;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(
              detected ? Icons.location_on : Icons.location_off_outlined,
              color: detected
                  ? const Color(0xFF10B981)
                  : Colors.orange.shade700,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Location',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _locationMessage,
                  style: const TextStyle(color: Color(0xFF6B7280), height: 1.3),
                ),
                if (!detecting && !detected) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _runLocationAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      settingsAction ? Icons.settings : Icons.refresh,
                      size: 18,
                    ),
                    label: Text(settingsAction ? 'Open settings' : 'Try again'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _LocationStatus {
  detecting,
  detected,
  serviceDisabled,
  denied,
  deniedForever,
  error,
}
