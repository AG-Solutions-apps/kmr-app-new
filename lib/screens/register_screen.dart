import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/widgets/app_snackbar.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/user_status_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String mobile;

  const RegisterScreen({super.key, required this.mobile});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late TextEditingController _mobileController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(text: widget.mobile);
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Handle Registration API submission
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      AppSnackBar.showError(context, title: 'Input Error', message: 'Please enter your full name');
      return;
    }
    if (mobile.isEmpty || mobile.length < 10) {
      AppSnackBar.showError(context, title: 'Input Error', message: 'Please enter a valid 10-digit mobile number');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      AppSnackBar.showError(context, title: 'Input Error', message: 'Please enter a valid email address');
      return;
    }
    if (city.isEmpty) {
      AppSnackBar.showError(context, title: 'Input Error', message: 'Please enter your city');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Call Signup API with formdata (name, mobile, email, city, address)
      final signupResult = await _authService.appSignup(
        name: name,
        mobile: mobile,
        email: email,
        city: city,
        address: address,
      );

      // 2. In background: Fetch registered user credentials via app-check-mobile API
      String backendPassword = '';
      try {
        final checkMobileResult = await _authService.checkMobileRegistered(mobile);
        if (checkMobileResult is Map && checkMobileResult.containsKey('data')) {
          backendPassword = checkMobileResult['data'].toString();
        }
      } catch (e) {
        debugPrint('[RegisterScreen] Error checking mobile post-signup: $e');
      }

      // 3. Get FCM device token
      final deviceId = await _authService.getFcmDeviceToken();

      // 4. In background: Execute app-login API with mobile, password & deviceId to obtain Auth Bearer Token
      dynamic loginPayload = signupResult;
      if (backendPassword.isNotEmpty) {
        try {
          final loginResult = await _authService.appLogin(
            mobile: mobile,
            password: backendPassword,
            deviceId: deviceId,
          );
          loginPayload = loginResult;
        } catch (e) {
          debugPrint('[RegisterScreen] Auto-login post-signup error: $e');
        }
      }

      // 5. Extract Bearer token from login payload or signup response
      final token = SessionService.extractToken(loginPayload) ?? SessionService.extractToken(signupResult);

      // 6. Persist full User Session permanently with credentials and token
      await SessionService.saveUserSession(
        userData: loginPayload,
        mobile: mobile,
        password: backendPassword,
        deviceId: deviceId,
        token: token,
      );

      // 7. Start periodic status check for user validity
      UserStatusService.instance.startPeriodicCheck();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          title: 'Welcome to KMR LIVE!',
          message: 'Account registered & logged in successfully.',
        );

        // 8. Navigate directly to HomeScreen with active login session & Bearer token
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(userData: loginPayload),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Registration failed. Please try again.';
        if (e.toString().contains('ApiException')) {
          errorMessage = e.toString().replaceAll('ApiException: ', '');
        } else if (e.toString().contains('message:')) {
          errorMessage = e.toString();
        }

        AppSnackBar.showError(
          context,
          title: 'Signup Failed',
          message: errorMessage,
        );
      }
    }
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        maxLines: maxLines,
        enabled: !_isLoading,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F291E),
        ),
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF0F291E), size: 20),
                const SizedBox(width: 10),
                Container(
                  width: 1.2,
                  height: 20,
                  color: const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
          fillColor: const Color(0xFFF0FDF4),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFA7F3D0), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFA7F3D0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Full-Screen Background Image bxx.png
          Positioned.fill(
            child: Image.asset(
              'assets/image/bxx.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Scrollable Content
          AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height - MediaQuery.of(context).padding.top,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: size.height * 0.04),

                        // Logo Header
                        Center(
                          child: Image.asset(
                            'assets/image/kmrLive.png',
                            height: 85,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                'KMR LIVE',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              );
                            },
                          ),
                        ),

                        SizedBox(height: size.height * 0.03),

                        // Green Tag
                        Text(
                          'COMPLETE SIGNUP',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                            letterSpacing: 2.8,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Title Text
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Create your\n',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F291E),
                                  height: 1.2,
                                ),
                              ),
                              TextSpan(
                                text: 'KMR LIVE ',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF00B050),
                                  height: 1.2,
                                ),
                              ),
                              TextSpan(
                                text: 'account',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F291E),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Mobile verified via OTP! Enter your details below to start.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Signup Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Name
                              _buildCustomTextField(
                                controller: _nameController,
                                hintText: 'Full Name *',
                                icon: Icons.person_outline_rounded,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Mobile
                              _buildCustomTextField(
                                controller: _mobileController,
                                hintText: 'Mobile Number *',
                                icon: Icons.phone_android_rounded,
                                keyboardType: TextInputType.phone,
                                readOnly: true,
                              ),
                              const SizedBox(height: 14),

                              // Email
                              _buildCustomTextField(
                                controller: _emailController,
                                hintText: 'Email Address *',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // City
                              _buildCustomTextField(
                                controller: _cityController,
                                hintText: 'City *',
                                icon: Icons.location_city_rounded,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your city';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Address
                              _buildCustomTextField(
                                controller: _addressController,
                                hintText: 'Address (Optional)',
                                icon: Icons.home_outlined,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 28),

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF059669),
                                        Color(0xFF00B050),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00B050).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'CREATE ACCOUNT & START',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
