import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  final FirebaseAuth? _customFirebaseAuth;
  final FirebaseMessaging? _customFirebaseMessaging;

  FirebaseAuth get _firebaseAuth =>
      _customFirebaseAuth ?? FirebaseAuth.instance;

  FirebaseMessaging? get _firebaseMessaging =>
      _customFirebaseMessaging ?? (Firebase.apps.isNotEmpty ? FirebaseMessaging.instance : null);

  AuthService({
    ApiService? apiService,
    FirebaseAuth? firebaseAuth,
    FirebaseMessaging? firebaseMessaging,
  })  : _apiService = apiService ?? ApiService(),
        _customFirebaseAuth = firebaseAuth,
        _customFirebaseMessaging = firebaseMessaging;

  /// 1. Check if Mobile is registered via backend POST app-check-mobile API
  Future<dynamic> checkMobileRegistered(String mobile) async {
    try {
      developer.log('Checking mobile registration for: $mobile', name: 'AuthService');
      final response = await _apiService.post(
        ApiConstants.appCheckMobile,
        data: {'mobile': mobile},
      );
      return response;
    } catch (e) {
      developer.log('checkMobileRegistered error: $e', name: 'AuthService', error: e);
      rethrow;
    }
  }

  /// 2. Get Firebase FCM Device Token for `device_id` field
  Future<String> getFcmDeviceToken() async {
    try {
      if (Firebase.apps.isNotEmpty && _firebaseMessaging != null) {
        String? token = await _firebaseMessaging!.getToken();
        if (token != null && token.isNotEmpty) {
          developer.log('FCM Token retrieved successfully', name: 'AuthService');
          return token;
        }
      }
    } catch (e) {
      developer.log('Error fetching FCM token: $e', name: 'AuthService', error: e);
    }
    // Fallback device ID if FCM token retrieval is unavailable in web/testing
    return 'fallback_device_id_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 3. Send Firebase SMS OTP to specified phone number
  Future<void> sendFirebaseOtp({
    required String phoneNumber,
    int? forceResendingToken,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
    required Function(String verificationId) onCodeAutoRetrievalTimeout,
  }) async {
    if (Firebase.apps.isEmpty) {
      developer.log('Firebase not initialized on this platform.', name: 'AuthService');
      onError(FirebaseAuthException(
        code: 'no-app',
        message: 'Firebase is not initialized on this platform.',
      ));
      return;
    }

    // Ensure standard +91 or country code formatting if needed
    final formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';

    developer.log('Sending Firebase OTP to: $formattedPhone', name: 'AuthService');

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        developer.log('Firebase Auto-Verification completed', name: 'AuthService');
        onAutoVerified(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        developer.log('Firebase Verification failed: ${e.message}', name: 'AuthService', error: e);
        onError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        developer.log('Firebase Code sent. VerificationId: $verificationId', name: 'AuthService');
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        developer.log('Firebase Auto Retrieval Timeout', name: 'AuthService');
        onCodeAutoRetrievalTimeout(verificationId);
      },
      timeout: const Duration(seconds: 60),
    );
  }

  /// 4. Verify Firebase OTP Code entered by User
  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-app',
        message: 'Firebase is not initialized on this platform.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      developer.log('Firebase OTP Verification Successful!', name: 'AuthService');
      return userCredential;
    } catch (e) {
      developer.log('Error verifying OTP code: $e', name: 'AuthService', error: e);
      rethrow;
    }
  }

  /// 5. Execute Backend App Login via POST app-login API
  /// Body fields: mobile, password, device_id (FCM token)
  Future<dynamic> appLogin({
    required String mobile,
    required String password,
    required String deviceId,
  }) async {
    try {
      developer.log(
        'Calling backend POST app-login for mobile: $mobile with device_id: $deviceId',
        name: 'AuthService',
      );
      final response = await _apiService.post(
        ApiConstants.appLogin,
        data: {
          'mobile': mobile,
          'password': password,
          'device_id': deviceId,
        },
      );
      return response;
    } catch (e) {
      developer.log('appLogin backend error: $e', name: 'AuthService', error: e);
      rethrow;
    }
  }

  /// 6. Execute Backend User Signup via POST signup API
  /// Formdata fields: name, mobile, email, city, address
  Future<dynamic> appSignup({
    required String name,
    required String mobile,
    required String email,
    required String city,
    String? address,
  }) async {
    try {
      developer.log(
        'Calling backend POST signup for name: $name, mobile: $mobile, email: $email, city: $city',
        name: 'AuthService',
      );
      return await _apiService.signupUser(
        name: name,
        mobile: mobile,
        email: email,
        city: city,
        address: address,
      );
    } catch (e) {
      developer.log('appSignup backend error: $e', name: 'AuthService', error: e);
      rethrow;
    }
  }
}
