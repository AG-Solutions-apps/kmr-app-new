import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/app_update_service.dart';
import '../services/session_service.dart';
import '../services/user_status_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  // Placeholder URLs (Change demo google.com link to your actual URLs anytime)
  static const String _termsUrl = 'https://google.com';
  static const String _privacyUrl = 'https://google.com';

  Future<void> _launchWebUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  final TextEditingController _mobileController = TextEditingController();

  // 6 Individual Controllers and FocusNodes for 6-Box OTP PIN Input
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // Auto-scrolling controller for top 4 feature badges
  late ScrollController _badgeScrollController;
  Timer? _badgeAutoScrollTimer;

  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _isRegisteredUser = true;
  bool _agreeTerms = true; // Terms & Conditions state

  String? _verificationId;
  int? _resendToken;
  String _backendPassword = '';

  @override
  void initState() {
    super.initState();

    // Check for Google Play Store Dynamic App Update on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkForUpdate(context);
      }
    });

    // Auto-Scroll Controller for Feature Badges
    _badgeScrollController = ScrollController();
    _badgeAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (_badgeScrollController.hasClients) {
        double maxExtent = _badgeScrollController.position.maxScrollExtent;
        double currentOffset = _badgeScrollController.offset;
        double targetOffset = currentOffset + 130.0;

        if (targetOffset >= maxExtent + 40) {
          _badgeScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          );
        } else {
          _badgeScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _badgeAutoScrollTimer?.cancel();
    _badgeScrollController.dispose();
    _mobileController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// Combine 6 OTP box inputs into single code string
  String get _getOtpCode {
    return _otpControllers.map((c) => c.text.trim()).join();
  }

  /// Clear all 6 OTP boxes
  void _clearOtpBoxes() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  /// Custom Toast / SnackBar matching Image 2 UI/UX
  void _showCustomToast({
    required String title,
    required String message,
    bool isError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isError ? const Color(0xFFFFCDD2) : const Color(0xFFA7F3D0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isError ? Colors.red : const Color(0xFF047857))
                    .withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isError ? const Color(0xFFD32F2F) : const Color(0xFF047857),
                ),
                child: Icon(
                  isError ? Icons.close_rounded : Icons.check_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isError
                            ? const Color(0xFFB71C1C)
                            : const Color(0xFF064E3B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isError
                            ? const Color(0xFFC62828)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 1: Call POST app-check-mobile API and send Firebase OTP
  Future<void> _handleCheckMobileAndSendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || mobile.length < 10) {
      _showCustomToast(
        title: 'Invalid Mobile Number',
        message: 'Please enter a valid 10-digit mobile number',
        isError: true,
      );
      return;
    }

    if (!_agreeTerms) {
      _showCustomToast(
        title: 'Terms Required',
        message: 'Please agree to the Terms & Conditions to proceed',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      dynamic response;
      bool is404User = false;

      try {
        response = await _authService.checkMobileRegistered(mobile);
      } on ApiException catch (e) {
        if (e.statusCode == 404 ||
            (e.data is Map && e.data['code'] == 404)) {
          is404User = true;
          response = e.data;
        } else {
          rethrow;
        }
      }

      final int responseCode = (response is Map && response.containsKey('code'))
          ? int.tryParse(response['code'].toString()) ?? 200
          : (is404User ? 404 : 200);

      if (responseCode == 200) {
        _isRegisteredUser = true;
        if (response is Map && response.containsKey('data')) {
          _backendPassword = response['data'].toString();
        }
        final message = (response is Map && response.containsKey('message'))
            ? response['message']
            : 'OTP sent. Enter the code to proceed.';

        _showCustomToast(title: 'OTP sent', message: message);
      } else if (responseCode == 404 || is404User) {
        _isRegisteredUser = false;
        final message = (response is Map && response.containsKey('message'))
            ? response['message']
            : 'Mobile not registered. Please sign up';

        _showCustomToast(title: 'Sign Up Required', message: message, isError: false);
      }

      // Trigger Firebase Phone Auth SMS OTP
      await _authService.sendFirebaseOtp(
        phoneNumber: mobile,
        forceResendingToken: _resendToken,
        onCodeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isOtpSent = true;
              _isLoading = false;
            });
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _otpFocusNodes.isNotEmpty) {
              _otpFocusNodes[0].requestFocus();
            }
          });
        },
        onError: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          _showCustomToast(
            title: 'Firebase Error',
            message: e.message ?? e.code,
            isError: true,
          );
        },
        onAutoVerified: (PhoneAuthCredential credential) async {
          _showCustomToast(
            title: 'Auto Verified',
            message: 'OTP Auto-verified by Firebase!',
          );
          await _onOtpVerifiedSuccess(mobile);
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showCustomToast(
        title: 'Verification Failed',
        message: e.toString(),
        isError: true,
      );
    }
  }

  /// Step 2: Verify Firebase OTP Code
  Future<void> _handleVerifyOtp() async {
    final smsCode = _getOtpCode;
    final mobile = _mobileController.text.trim();

    if (smsCode.length < 6) {
      _showCustomToast(
        title: 'Incomplete OTP',
        message: 'Please enter all 6 digits of the OTP code',
        isError: true,
      );
      return;
    }

    if (_verificationId == null) {
      _showCustomToast(
        title: 'Session Expired',
        message: 'Verification session expired. Please resend OTP.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.verifyOtpCode(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _onOtpVerifiedSuccess(mobile);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showCustomToast(
        title: 'Invalid OTP',
        message: 'Invalid OTP code. Please check and try again.',
        isError: true,
      );
    }
  }

  /// Post-OTP success action (200 vs 404)
  Future<void> _onOtpVerifiedSuccess(String mobile) async {
    if (_isRegisteredUser) {
      try {
        final deviceId = await _authService.getFcmDeviceToken();

        final loginResult = await _authService.appLogin(
          mobile: mobile,
          password: _backendPassword,
          deviceId: deviceId,
        );

        setState(() {
          _isLoading = false;
        });

        // Persist User Session with credentials for status checks
        await SessionService.saveUserSession(
          userData: loginResult,
          mobile: mobile,
          password: _backendPassword,
          deviceId: deviceId,
        );

        // Start 3-Minute Periodic Status & Validity Checker
        UserStatusService.instance.startPeriodicCheck();

        _showCustomToast(
          title: 'Success',
          message: 'Logged in successfully!',
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(userData: loginResult),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showCustomToast(
          title: 'Login Error',
          message: e.toString(),
          isError: true,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });

      _showCustomToast(
        title: 'Verified',
        message: 'Mobile verified! Please complete registration.',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RegisterScreen(mobile: mobile),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      // Keyboard must NOT push the background image Ã¢â‚¬â€ image stays fixed
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Ã¢â€â‚¬Ã¢â€â‚¬ FULL-SCREEN BACKGROUND bxx.png Ã¢â‚¬â€ fixed, never moves Ã¢â€â‚¬Ã¢â€â‚¬
          Positioned.fill(
            child: Image.asset(
              'assets/image/bxx.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Ã¢â€â‚¬Ã¢â€â‚¬ SCROLLABLE CONTENT on top (keyboard-aware via padding) Ã¢â€â‚¬Ã¢â€â‚¬
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.07),

                      // Ã¢â€â‚¬Ã¢â€â‚¬ LOGO Ã¢â‚¬â€ no box, no rectangle, clean Ã¢â€â‚¬Ã¢â€â‚¬
                      Center(
                        child: Image.asset(
                          'assets/image/kmrLive.png',
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'KMR LIVE',
                              style: GoogleFonts.poppins(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: [
                                  const Shadow(color: Colors.black38, blurRadius: 8),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: size.height * 0.035),

                      // Ã¢â€â‚¬Ã¢â€â‚¬ INFINITE MARQUEE BADGE SCROLLER Ã¢â€â‚¬Ã¢â€â‚¬
                      _MarqueeBadges(),

                      SizedBox(height: size.height * 0.04),

                      // -- FORM: transparent, no box --
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                          decoration: const BoxDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WELCOME',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                  letterSpacing: 2.8,
                                ),
                              ),
                              const SizedBox(height: 6),

                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _isOtpSent ? 'Verify your\n' : 'Log in to your\n',
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
                                      text: _isOtpSent ? 'OTP' : 'account',
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
                                _isOtpSent
                                    ? 'Enter 6-digit SMS code sent to +91 ${_mobileController.text}'
                                    : 'Get real-time market updates, prices\nand insights every day.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF64748B),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Ã¢â€â‚¬Ã¢â€â‚¬ MOBILE INPUT Ã¢â€â‚¬Ã¢â€â‚¬
                              if (!_isOtpSent) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: TextField(
                                      controller: _mobileController,
                                      keyboardType: TextInputType.phone,
                                      enabled: !_isLoading,
                                      maxLength: 10,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F291E),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter User Id here...',
                                        hintStyle: GoogleFonts.poppins(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 16),
                                            const Icon(Icons.person, color: Color(0xFF0F291E), size: 22),
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 1.2,
                                              height: 20,
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _agreeTerms,
                                        activeColor: const Color(0xFF059669),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        side: const BorderSide(color: Color(0xFF0F291E), width: 1.5),
                                        onChanged: _isLoading
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _agreeTerms = value ?? false;
                                                });
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                       child: RichText(
                                         text: TextSpan(
                                           children: [
                                             TextSpan(
                                               text: 'I agree to the ',
                                               style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569)),
                                             ),
                                             TextSpan(
                                               text: 'Terms & Conditions',
                                               style: GoogleFonts.poppins(
                                                 fontSize: 12,
                                                 fontWeight: FontWeight.w600,
                                                 color: const Color(0xFF059669),
                                                 decoration: TextDecoration.underline,
                                                 decorationColor: const Color(0xFF059669),
                                               ),
                                               recognizer: TapGestureRecognizer()
                                                 ..onTap = () => _launchWebUrl(_termsUrl),
                                             ),
                                             TextSpan(
                                               text: ' & ',
                                               style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569)),
                                             ),
                                             TextSpan(
                                               text: 'Privacy Policy',
                                               style: GoogleFonts.poppins(
                                                 fontSize: 12,
                                                 fontWeight: FontWeight.w600,
                                                 color: const Color(0xFF059669),
                                                 decoration: TextDecoration.underline,
                                                 decorationColor: const Color(0xFF059669),
                                               ),
                                               recognizer: TapGestureRecognizer()
                                                 ..onTap = () => _launchWebUrl(_privacyUrl),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 20),
                              ],

                              // Ã¢â€â‚¬Ã¢â€â‚¬ 6-BOX OTP Ã¢â€â‚¬Ã¢â€â‚¬
                              if (_isOtpSent) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    return SizedBox(
                                      width: (size.width - 80 - 50) / 6,
                                      height: 52,
                                      child: TextField(
                                        controller: _otpControllers[index],
                                        focusNode: _otpFocusNodes[index],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        enabled: !_isLoading,
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF047857),
                                        ),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          contentPadding: EdgeInsets.zero,
                                          fillColor: const Color(0xFFF0FDF4),
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFA7F3D0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFA7F3D0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 2)),
                                        ),
                                        onChanged: (value) {
                                          if (value.isNotEmpty) {
                                            if (index < 5) {
                                              _otpFocusNodes[index + 1].requestFocus();
                                            } else {
                                              _otpFocusNodes[index].unfocus();
                                            }
                                            if (_getOtpCode.length == 6) {
                                              _handleVerifyOtp();
                                            }
                                          } else {
                                            if (index > 0) {
                                              _otpFocusNodes[index - 1].requestFocus();
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Ã¢â€â‚¬Ã¢â€â‚¬ GRADIENT BUTTON Ã¢â€â‚¬Ã¢â€â‚¬
                              Container(
                                height: 52,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: (_agreeTerms || _isOtpSent)
                                        ? [const Color(0xFF15803D), const Color(0xFF047857), const Color(0xFF064E3B)]
                                        : [Colors.grey.shade400, Colors.grey.shade500],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: (_agreeTerms || _isOtpSent)
                                      ? [BoxShadow(color: const Color(0xFF047857).withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 7))]
                                      : [],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: _isLoading ? null : (_isOtpSent ? _handleVerifyOtp : _handleCheckMobileAndSendOtp),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (_isLoading)
                                          const SizedBox(
                                            height: 22, width: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          )
                                        else ...[
                                          Text(
                                            _isOtpSent ? 'Verify OTP' : 'Send OTP',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Ã¢â€â‚¬Ã¢â€â‚¬ RESEND / CHANGE Ã¢â€â‚¬Ã¢â€â‚¬
                              if (_isOtpSent && !_isLoading) ...[
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 15, color: Color(0xFF047857)),
                                      label: Text('Change Number',
                                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF047857), fontWeight: FontWeight.w600)),
                                      onPressed: () {
                                        setState(() {
                                          _isOtpSent = false;
                                          _isLoading = false;
                                          _verificationId = null;
                                          _resendToken = null;
                                          _clearOtpBoxes();
                                        });
                                      },
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.refresh, size: 15, color: Color(0xFF047857)),
                                      label: Text('Resend OTP',
                                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF047857), fontWeight: FontWeight.w600)),
                                      onPressed: () {
                                        _clearOtpBoxes();
                                        _handleCheckMobileAndSendOtp();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),
                    ],
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



class _BadgeItem {
  final IconData icon;
  final String label;

  const _BadgeItem({
    required this.icon,
    required this.label,
  });
}

class _MarqueeBadges extends StatefulWidget {
  const _MarqueeBadges();

  @override
  State<_MarqueeBadges> createState() => _MarqueeBadgesState();
}

class _MarqueeBadgesState extends State<_MarqueeBadges>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // ============================================================
  // BADGES
  // ============================================================

  static const List<_BadgeItem> _badges = [
    _BadgeItem(
      icon: Icons.currency_rupee_rounded,
      label: 'Rates',
    ),
    _BadgeItem(
      icon: Icons.workspace_premium_rounded,
      label: 'Spots',
    ),
    _BadgeItem(
      icon: Icons.article_outlined,
      label: 'News',
    ),
    _BadgeItem(
      icon: Icons.sensors_rounded,
      label: 'Live',
    ),
  ];

  // ============================================================
  // SIZE
  // ============================================================

  static const double _pillWidth = 112.0;
  static const double _pillHeight = 42.0;
  static const double _gap = 8.0;

  // 4 pills + 4 gaps
  //
  // 112 + 8
  // 112 + 8
  // 112 + 8
  // 112 + 8
  //
  // = 480
  static const double _singleSetWidth =
      (_pillWidth + _gap) * 4;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Check for Google Play Store Dynamic App Update on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkForUpdate(context);
      }
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // PILL
  // ============================================================

  Widget _buildPill(_BadgeItem badge) {
    return SizedBox(
      width: _pillWidth,
      height: _pillHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFA7F3D0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF047857).withValues(
                alpha: 0.08,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                badge.icon,
                size: 17,
                color: const Color(0xFF059669),
              ),

              const SizedBox(width: 7),

              Flexible(
                child: Text(
                  badge.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F291E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ONE SET
  // ============================================================

  Widget _buildSet() {
    return SizedBox(
      width: _singleSetWidth,
      height: _pillHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final badge in _badges) ...[
            _buildPill(badge),
            const SizedBox(width: _gap),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _pillHeight,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,

          builder: (context, child) {
            final double offset =
                _controller.value * _singleSetWidth;

            return OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(-offset, 0),
                child: child,
              ),
            );
          },

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SET 1
              _buildSet(),

              // SET 2
              _buildSet(),

              // SET 3
              _buildSet(),

              // SET 4
              _buildSet(),
            ],
          ),
        ),
      ),
    );
  }
}