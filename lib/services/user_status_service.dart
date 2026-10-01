import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'session_service.dart';
import '../screens/login_screen.dart';

/// Class representing current user account status and subscription validity state.
class UserStatusData {
  final String status;
  final String validityDateStr;
  final DateTime? validityDate;
  final int daysRemaining;
  final bool isExpired;
  final bool isChecking;
  final String? userName;
  final String? mobile;

  UserStatusData({
    this.status = 'Active',
    this.validityDateStr = '',
    this.validityDate,
    this.daysRemaining = 0,
    this.isExpired = false,
    this.isChecking = false,
    this.userName,
    this.mobile,
  });

  UserStatusData copyWith({
    String? status,
    String? validityDateStr,
    DateTime? validityDate,
    int? daysRemaining,
    bool? isExpired,
    bool? isChecking,
    String? userName,
    String? mobile,
  }) {
    return UserStatusData(
      status: status ?? this.status,
      validityDateStr: validityDateStr ?? this.validityDateStr,
      validityDate: validityDate ?? this.validityDate,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isExpired: isExpired ?? this.isExpired,
      isChecking: isChecking ?? this.isChecking,
      userName: userName ?? this.userName,
      mobile: mobile ?? this.mobile,
    );
  }
}

/// UserStatusService manages periodic (every 3 mins) user status verification,
/// automatic logout on 'Inactive' status, and validity date expiration tracking.
class UserStatusService {
  UserStatusService._privateConstructor();
  static final UserStatusService instance = UserStatusService._privateConstructor();

  /// Global NavigatorKey to enable navigation & dialogs from background timer callbacks
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final AuthService _authService = AuthService();
  Timer? _statusTimer;

  /// ValueNotifier holding real-time user status & validity information
  final ValueNotifier<UserStatusData> statusNotifier = ValueNotifier<UserStatusData>(UserStatusData());

  /// Starts 3-minute periodic backend status check for logged-in users
  void startPeriodicCheck() {
    stopPeriodicCheck(); // Cancel any existing timer
    
    debugPrint('[UserStatusService] Starting 3-minute periodic status check...');
    
    // Check immediately on startup/login
    checkStatusNow();

    // Run every 3 minutes (180 seconds)
    _statusTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      debugPrint('[UserStatusService] 3-minute timer fired. Checking user status...');
      checkStatusNow();
    });
  }

  /// Stops background timer on logout
  void stopPeriodicCheck() {
    if (_statusTimer != null) {
      _statusTimer!.cancel();
      _statusTimer = null;
      debugPrint('[UserStatusService] Stopped periodic status timer.');
    }
  }

  /// Executes user status & validity check via API or stored session
  Future<void> checkStatusNow() async {
    final bool loggedIn = await SessionService.isLoggedIn();
    if (!loggedIn) {
      stopPeriodicCheck();
      return;
    }

    statusNotifier.value = statusNotifier.value.copyWith(isChecking: true);

    try {
      final mobile = await SessionService.getUserMobile();
      final password = await SessionService.getUserPassword();
      final deviceId = await SessionService.getDeviceId();
      dynamic userData = await SessionService.getUserData();

      // If credentials exist, re-call appLogin API to fetch fresh user status & validity_date
      if (mobile != null && mobile.isNotEmpty && password != null && password.isNotEmpty) {
        try {
          final effectiveDeviceId = (deviceId != null && deviceId.isNotEmpty)
              ? deviceId
              : await _authService.getFcmDeviceToken();

          final freshResponse = await _authService.appLogin(
            mobile: mobile,
            password: password,
            deviceId: effectiveDeviceId,
          );

          if (freshResponse != null) {
            userData = freshResponse;
            await SessionService.saveUserSession(
              userData: freshResponse,
              mobile: mobile,
              password: password,
              deviceId: effectiveDeviceId,
            );
          }
        } catch (apiError) {
          debugPrint('[UserStatusService] Network error during status refresh: $apiError. Falling back to cached session data.');
        }
      }

      // Process and extract user object details
      _processUserData(userData);
    } catch (e) {
      debugPrint('[UserStatusService] Error checking status: $e');
    } finally {
      statusNotifier.value = statusNotifier.value.copyWith(isChecking: false);
    }
  }

  /// Helper to extract user details from response structure
  void _processUserData(dynamic userData) {
    if (userData == null) return;

    Map<String, dynamic>? userMap;

    // Handle nested json payload formats:
    // { "data": { "user": { "status": "Active", "validity_date": "2030-09-28" } } }
    if (userData is Map) {
      if (userData['data'] is Map && userData['data']['user'] is Map) {
        userMap = Map<String, dynamic>.from(userData['data']['user']);
      } else if (userData['user'] is Map) {
        userMap = Map<String, dynamic>.from(userData['user']);
      } else if (userData['status'] != null || userData['validity_date'] != null) {
        userMap = Map<String, dynamic>.from(userData);
      }
    }

    if (userMap == null) return;

    final String status = userMap['status']?.toString() ?? 'Active';
    final String validityDateRaw = userMap['validity_date']?.toString() ?? '';
    final String name = userMap['name']?.toString() ?? '';
    final String mobile = userMap['mobile']?.toString() ?? '';

    // ============================================================
    // 1. STATUS CHECK: If status is not "Active", force automatic logout!
    // ============================================================
    final bool isActive = _checkIsActive(status);

    if (!isActive) {
      debugPrint('[UserStatusService] User status is "$status" (Inactive). Triggering automatic logout!');
      _handleInactiveLogout(status);
      return;
    }

    // ============================================================
    // 2. VALIDITY DATE CHECK: Calculate remaining days & expired state
    // ============================================================
    final parsedValidity = _parseValidityDate(validityDateRaw);

    statusNotifier.value = UserStatusData(
      status: status,
      validityDateStr: parsedValidity.dateString,
      validityDate: parsedValidity.date,
      daysRemaining: parsedValidity.daysRemaining,
      isExpired: parsedValidity.isExpired,
      isChecking: false,
      userName: name,
      mobile: mobile,
    );

    debugPrint(
      '[UserStatusService] Status: $status | Validity: ${parsedValidity.dateString} '
      '| Days Remaining: ${parsedValidity.daysRemaining} | Expired: ${parsedValidity.isExpired}',
    );
  }

  /// Checks if status string represents "Active"
  bool _checkIsActive(String status) {
    final s = status.trim().toLowerCase();
    if (s.isEmpty) return true;
    return s == 'active' || s == '1' || s == 'true';
  }

  /// Handles automatic logout when account status is set to Inactive
  Future<void> _handleInactiveLogout(String currentStatus) async {
    stopPeriodicCheck();

    final BuildContext? currentContext = navigatorKey.currentContext;
    final scaffoldMessenger = (currentContext != null && currentContext.mounted)
        ? ScaffoldMessenger.maybeOf(currentContext)
        : null;

    await SessionService.clearSession();

    if (scaffoldMessenger != null) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Account Status is "$currentStatus". You have been automatically logged out.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Helper to safely parse YYYY-MM-DD or ISO validity dates
  _ParsedValidity _parseValidityDate(String rawDateStr) {
    if (rawDateStr.trim().isEmpty) {
      return _ParsedValidity(dateString: 'N/A', daysRemaining: 0, isExpired: false);
    }

    final cleanStr = rawDateStr.trim();
    try {
      DateTime parsedDate = DateTime.parse(cleanStr);
      final now = DateTime.now();
      
      // Compare calendar dates (midnight)
      final today = DateTime(now.year, now.month, now.day);
      final expDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      final int daysRemaining = expDate.difference(today).inDays;
      final bool isExpired = daysRemaining < 0;

      final String formattedStr =
          "${expDate.year}-${expDate.month.toString().padLeft(2, '0')}-${expDate.day.toString().padLeft(2, '0')}";

      return _ParsedValidity(
        dateString: formattedStr,
        date: expDate,
        daysRemaining: daysRemaining,
        isExpired: isExpired,
      );
    } catch (e) {
      debugPrint('[UserStatusService] Failed to parse validity date "$rawDateStr": $e');
      return _ParsedValidity(dateString: cleanStr, daysRemaining: 0, isExpired: false);
    }
  }
}

class _ParsedValidity {
  final String dateString;
  final DateTime? date;
  final int daysRemaining;
  final bool isExpired;

  _ParsedValidity({
    required this.dateString,
    this.date,
    required this.daysRemaining,
    required this.isExpired,
  });
}
