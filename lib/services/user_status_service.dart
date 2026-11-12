import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'session_service.dart';
import '../screens/login_screen.dart';
import '../core/utils/date_formatter.dart';

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

  /// Update validity expiration state (called by 10s app-check-validity API)
  void setValidityExpired(bool expired) {
    if (statusNotifier.value.isExpired != expired) {
      statusNotifier.value = statusNotifier.value.copyWith(isExpired: expired);
    }
  }

  /// Executes user status & validity check via API or stored session
  Future<void> checkStatusNow({dynamic directUserData}) async {
    final bool loggedIn = await SessionService.isLoggedIn();
    if (!loggedIn && directUserData == null) {
      stopPeriodicCheck();
      return;
    }

    statusNotifier.value = statusNotifier.value.copyWith(isChecking: true);

    try {
      final savedValidity = await SessionService.getValidityDate();

      // Process direct user data immediately if passed
      if (directUserData != null) {
        processUserData(directUserData, fallbackValidityDate: savedValidity);
      }

      final mobile = await SessionService.getUserMobile();
      final password = await SessionService.getUserPassword();
      final deviceId = await SessionService.getDeviceId();
      dynamic userData = directUserData ?? await SessionService.getUserData();

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
          debugPrint('[UserStatusService] Network notice during status refresh: $apiError. Using current session data.');
        }
      }

      // Process and extract user object details
      final currentSaved = await SessionService.getValidityDate() ?? savedValidity;
      if (userData != null) {
        processUserData(userData, fallbackValidityDate: currentSaved);
      } else if (currentSaved != null && currentSaved.isNotEmpty && currentSaved != 'N/A') {
        processUserData({'validity_date': currentSaved});
      }
    } catch (e) {
      debugPrint('[UserStatusService] Error checking status: $e');
    } finally {
      statusNotifier.value = statusNotifier.value.copyWith(isChecking: false);
    }
  }

  /// Deep search for validity_date in any response structure
  static String extractValidityDate(dynamic data) {
    final extracted = SessionService.extractValidityDate(data);
    if (extracted.isNotEmpty && extracted != 'N/A') {
      return extracted;
    }
    if (data is Map) {
      for (final key in ['validity_date', 'validity', 'valid_until', 'expiry_date', 'expire_date']) {
        if (data[key] != null) {
          final val = data[key].toString().trim();
          if (val.isNotEmpty && val != 'null' && val != 'N/A') {
            return val;
          }
        }
      }
    }
    return '';
  }

  /// Processes user data payload and dynamically calculates remaining days from today's date
  void processUserData(dynamic userData, {String? fallbackValidityDate}) {
    if (userData == null && (fallbackValidityDate == null || fallbackValidityDate.isEmpty)) return;

    Map<String, dynamic> userMap = {};

    if (userData is Map) {
      if (userData['data'] is Map && (userData['data'] as Map)['user'] is Map) {
        userMap = Map<String, dynamic>.from((userData['data'] as Map)['user']);
      } else if (userData['data'] is Map) {
        userMap = Map<String, dynamic>.from(userData['data']);
      } else if (userData['user'] is Map) {
        userMap = Map<String, dynamic>.from(userData['user']);
      } else {
        userMap = Map<String, dynamic>.from(userData);
      }
    }

    final String status = userMap['status']?.toString() ?? 'Active';
    String validityDateRaw = userMap['validity_date']?.toString() ?? '';
    if (validityDateRaw.trim().isEmpty || validityDateRaw.trim() == 'N/A') {
      validityDateRaw = extractValidityDate(userData);
    }
    if (validityDateRaw.trim().isEmpty || validityDateRaw.trim() == 'N/A') {
      validityDateRaw = SessionService.extractValidityDate(userData);
    }
    if ((validityDateRaw.trim().isEmpty || validityDateRaw.trim() == 'N/A') &&
        fallbackValidityDate != null &&
        fallbackValidityDate.trim().isNotEmpty &&
        fallbackValidityDate.trim() != 'N/A') {
      validityDateRaw = fallbackValidityDate.trim();
    }
    if (validityDateRaw.trim().isNotEmpty && validityDateRaw.trim() != 'N/A') {
      SessionService.saveValidityDate(validityDateRaw.trim());
    }

    final String name = userMap['name']?.toString() ??
        (userData is Map && userData['data'] is Map
            ? (userData['data'] as Map)['name']?.toString() ?? ''
            : '');
    final String mobile = userMap['mobile']?.toString() ??
        (userData is Map && userData['data'] is Map
            ? (userData['data'] as Map)['mobile']?.toString() ?? ''
            : '');

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
    // 2. DYNAMIC VALIDITY DATE CHECK: Calculate remaining days from today's date
    // ============================================================
    if (validityDateRaw.trim().isNotEmpty && validityDateRaw.trim() != 'N/A') {
      final parsedValidity = parseValidityDate(validityDateRaw);

      statusNotifier.value = UserStatusData(
        status: status,
        validityDateStr: parsedValidity.dateString,
        validityDate: parsedValidity.date,
        daysRemaining: parsedValidity.daysRemaining,
        isExpired: parsedValidity.isExpired,
        isChecking: false,
        userName: name.isNotEmpty ? name : statusNotifier.value.userName,
        mobile: mobile.isNotEmpty ? mobile : statusNotifier.value.mobile,
      );

      debugPrint(
        '[UserStatusService] Parsed validity_date: "$validityDateRaw" -> '
        'Formatted: ${parsedValidity.dateString} | Days Remaining from today: ${parsedValidity.daysRemaining} | Expired: ${parsedValidity.isExpired}',
      );
    } else {
      statusNotifier.value = statusNotifier.value.copyWith(
        status: status,
        userName: name.isNotEmpty ? name : statusNotifier.value.userName,
        mobile: mobile.isNotEmpty ? mobile : statusNotifier.value.mobile,
        isChecking: false,
      );
    }
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

  /// Helper to safely parse YYYY-MM-DD, DD-MM-YYYY, or ISO validity dates
  /// and dynamically compute days remaining compared to today's date
  static _ParsedValidity parseValidityDate(String rawDateStr) {
    if (rawDateStr.trim().isEmpty || rawDateStr.trim() == 'N/A') {
      return _ParsedValidity(dateString: '', daysRemaining: 0, isExpired: false);
    }

    final cleanStr = rawDateStr.trim();
    DateTime? parsedDate;

    // 1. Try ISO8601 / YYYY-MM-DD
    try {
      parsedDate = DateTime.parse(cleanStr);
    } catch (_) {}

    // 2. Try DD-MM-YYYY or DD/MM/YYYY
    if (parsedDate == null) {
      final sep = cleanStr.contains('-') ? '-' : (cleanStr.contains('/') ? '/' : null);
      if (sep != null) {
        final parts = cleanStr.split(sep);
        if (parts.length == 3) {
          if (parts[2].length == 4) {
            // DD-MM-YYYY
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? DateTime.now().year;
            parsedDate = DateTime(year, month, day);
          } else if (parts[0].length == 4) {
            // YYYY-MM-DD
            final year = int.tryParse(parts[0]) ?? DateTime.now().year;
            final month = int.tryParse(parts[1]) ?? 1;
            final day = int.tryParse(parts[2]) ?? 1;
            parsedDate = DateTime(year, month, day);
          }
        }
      }
    }

    if (parsedDate == null) {
      final formatted = AppDateFormatter.format(cleanStr);
      return _ParsedValidity(
        dateString: formatted.isNotEmpty && formatted != 'N/A' ? formatted : cleanStr,
        daysRemaining: 0,
        isExpired: false,
      );
    }

    // Dynamic difference calculation: validityDate minus today (midnight comparison)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    final int daysRemaining = expDate.difference(today).inDays;
    final bool isExpired = daysRemaining < 0;

    final String formattedStr = AppDateFormatter.format(cleanStr);

    return _ParsedValidity(
      dateString: formattedStr.isNotEmpty && formattedStr != 'N/A' ? formattedStr : cleanStr,
      date: expDate,
      daysRemaining: daysRemaining,
      isExpired: isExpired,
    );
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
