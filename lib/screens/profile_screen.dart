import 'package:flutter/material.dart';
import '../core/widgets/app_snackbar.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/user_status_service.dart';
import 'login_screen.dart';

/// Premium Profile Screen with locked Mobile & Name fields, toggleable Email editor,
/// custom pill SnackBar feedback, and confirmation-protected Account Deletion.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUpdating = false;
  bool _isDeleting = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _cityController = TextEditingController();
    _addressController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('User is not logged in.');
      }

      final profileResponse = await ApiService().fetchProfile(token: token);

      if (mounted) {
        if (profileResponse.data != null) {
          final p = profileResponse.data!;
          _nameController.text = p.name;
          _mobileController.text = p.mobile;
          _emailController.text = p.email;
          _cityController.text = p.city;
          _addressController.text = p.address;
        } else {
          final localUser = await SessionService.getUserData();
          final localMobile = await SessionService.getUserMobile();
          if (localUser is Map) {
            _nameController.text = (localUser['name'] ?? localUser['username'] ?? '').toString();
            _emailController.text = (localUser['email'] ?? '').toString();
            _mobileController.text = localMobile ?? (localUser['mobile'] ?? '').toString();
            _cityController.text = (localUser['city'] ?? localUser['place'] ?? '').toString();
            _addressController.text = (localUser['address'] ?? '').toString();
          }
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error fetching profile: $e');
      if (mounted) {
        final localMobile = await SessionService.getUserMobile();
        final localUser = await SessionService.getUserData();
        if (localMobile != null || localUser != null) {
          if (localUser is Map) {
            _nameController.text = (localUser['name'] ?? localUser['username'] ?? '').toString();
            _emailController.text = (localUser['email'] ?? '').toString();
            _cityController.text = (localUser['city'] ?? localUser['place'] ?? '').toString();
            _addressController.text = (localUser['address'] ?? '').toString();
          }
          _mobileController.text = localMobile ?? '';
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load profile details: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isUpdating = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Session token missing. Please log in again.');
      }

      final response = await ApiService().updateProfile(
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        name: _nameController.text.trim(),
        token: token,
      );

      final msg = (response is Map && response.containsKey('message'))
          ? response['message'].toString()
          : 'Your profile details have been updated successfully!';

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          title: 'Profile Updated',
          message: msg,
        );
        setState(() {
          _isEditing = false;
        });
        _loadProfile();
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Update error: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('ApiException', '').replaceAll('Exception:', '').trim();
        AppSnackBar.showError(
          context,
          title: 'Update Failed',
          message: cleanMsg.isNotEmpty ? cleanMsg : 'Unable to update profile. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _confirmAndDeleteProfile() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFC81E1E),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Account?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9B1C1C),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account and profile data? This action cannot be undone.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF4A5568), height: 1.45),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC81E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService().deleteProfile(token: token);
      }

      UserStatusService.instance.stopPeriodicCheck();
      await SessionService.clearSession();

      if (mounted) {
        AppSnackBar.showError(
          context,
          title: 'Account Deleted',
          message: 'Your account has been permanently deleted.',
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Delete error: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('ApiException', '').replaceAll('Exception:', '').trim();
        AppSnackBar.showError(
          context,
          title: 'Delete Failed',
          message: cleanMsg.isNotEmpty ? cleanMsg : 'Unable to delete profile.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A4B26), Color(0xFF1B7A44)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B7A44)),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadProfile,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B7A44),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // USER AVATAR CARD
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF0A4B26), Color(0xFF1B7A44)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text.substring(0, 1).toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
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
                                        _nameController.text.isNotEmpty
                                            ? _nameController.text
                                            : 'KMR Live User',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0C3A20),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _mobileController.text.isNotEmpty
                                            ? '+91 ${_mobileController.text}'
                                            : 'Registered Account',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // HEADER WITH EDIT TOGGLE BUTTON
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  'PROFILE DETAILS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0C3A20),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              if (!_isEditing)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1B7A44)),
                                  label: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B7A44),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFDCF2E5),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // PROFILE DISPLAY / EDIT FORM CONTAINER
                          if (!_isEditing)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProfileInfoRow(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Full Name',
                                    value: _nameController.text.isNotEmpty ? _nameController.text : 'KMR Live User',
                                    isLocked: true,
                                  ),
                                  _buildProfileInfoRow(
                                    icon: Icons.phone_android_rounded,
                                    label: 'Mobile Number',
                                    value: _mobileController.text.isNotEmpty ? '+91 ${_mobileController.text}' : 'Not provided',
                                    isLocked: true,
                                  ),
                                  _buildProfileInfoRow(
                                    icon: Icons.email_outlined,
                                    label: 'Email Address',
                                    value: _emailController.text,
                                  ),
                                  _buildProfileInfoRow(
                                    icon: Icons.location_city_rounded,
                                    label: 'City',
                                    value: _cityController.text,
                                  ),
                                  _buildProfileInfoRow(
                                    icon: Icons.home_work_outlined,
                                    label: 'Address',
                                    value: _addressController.text,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFF1B7A44), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Full Name (PERMANENTLY LOCKED)
                                  TextFormField(
                                    controller: _nameController,
                                    enabled: false,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A5568),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name (Locked)',
                                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.grey),
                                      suffixIcon: const Tooltip(
                                        message: 'Full Name cannot be edited',
                                        child: Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      fillColor: const Color(0xFFF8FAFC),
                                      filled: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Mobile Number (PERMANENTLY LOCKED)
                                  TextFormField(
                                    controller: _mobileController,
                                    enabled: false,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A5568),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Mobile Number (Locked)',
                                      prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.grey),
                                      suffixIcon: const Tooltip(
                                        message: 'Mobile number cannot be edited',
                                        child: Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      fillColor: const Color(0xFFF8FAFC),
                                      filled: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Email Input (EDITABLE ONLY WHEN EDIT CLICKED)
                                  TextFormField(
                                    controller: _emailController,
                                    enabled: true,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0C3A20),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter email address';
                                      }
                                      if (!v.contains('@') || !v.contains('.')) {
                                        return 'Please enter a valid email address';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Email Address (Editable)',
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFF1B7A44),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF1B7A44), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF1B7A44), width: 2),
                                      ),
                                      fillColor: const Color(0xFFFAFDFA),
                                      filled: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // City Input (EDITABLE WHEN EDIT CLICKED)
                                  TextFormField(
                                    controller: _cityController,
                                    enabled: true,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0C3A20),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'City (Editable)',
                                      prefixIcon: const Icon(
                                        Icons.location_city_rounded,
                                        color: Color(0xFF1B7A44),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF1B7A44), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF1B7A44), width: 2),
                                      ),
                                      fillColor: const Color(0xFFFAFDFA),
                                      filled: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Address Input (EDITABLE WHEN EDIT CLICKED)
                                  TextFormField(
                                    controller: _addressController,
                                    enabled: true,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0C3A20),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Address (Editable)',
                                      prefixIcon: const Icon(
                                        Icons.home_work_outlined,
                                        color: Color(0xFF1B7A44),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF1B7A44), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF1B7A44), width: 2),
                                      ),
                                      fillColor: const Color(0xFFFAFDFA),
                                      filled: true,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // ACTION BUTTONS (UPDATE & CANCEL)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isUpdating
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _isEditing = false;
                                                  });
                                                  _loadProfile();
                                                },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: BorderSide(color: Colors.grey.shade400),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton(
                                          onPressed: _isUpdating ? null : _updateProfile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0A4B26),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isUpdating
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.save_rounded, size: 18),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Save Profile',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 28),

                          // DANGER ZONE / DELETE PROFILE CONTAINER
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFEB2B2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.delete_forever_rounded, color: Color(0xFFC81E1E), size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete Account',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF9B1C1C),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Permanently delete your profile account and data from KMR Live.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF742A2A)),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: _isDeleting ? null : _confirmAndDeleteProfile,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFC81E1E),
                                      side: const BorderSide(color: Color(0xFFE53935), width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isDeleting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFC81E1E),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.delete_outline_rounded, size: 18),
                                              SizedBox(width: 6),
                                              Text(
                                                'Delete Account',
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLocked = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEFAF2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1B7A44), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not specified',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C3A20),
                  ),
                ),
              ],
            ),
          ),
          if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Locked',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
