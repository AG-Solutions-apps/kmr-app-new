import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages persistent user login session storage.
/// 
/// Holds session state until user explicitly clicks Logout or clears app cache/data.
class SessionService {
  SessionService._();

  static const String _keyIsLoggedIn = 'kmr_is_logged_in';
  static const String _keyUserData = 'kmr_user_data';
  static const String _keyUserMobile = 'kmr_user_mobile';
  static const String _keyUserPassword = 'kmr_user_password';
  static const String _keyDeviceId = 'kmr_device_id';
  static const String _keyToken = 'kmr_token';
  static const String _keyCompanyDetails = 'kmr_company_details';
  static const String _keyLastSeenNotificationCount = 'kmr_last_seen_notif_count';

  /// Saves company details permanently
  static Future<void> saveCompanyDetails(dynamic companyData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (companyData != null) {
        await prefs.setString(_keyCompanyDetails, jsonEncode(companyData));
      }
    } catch (e) {
      debugPrint('[SessionService] Error saving company details: $e');
    }
  }

  /// Retrieves stored company details
  static Future<Map<String, dynamic>?> getCompanyDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyCompanyDetails);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[SessionService] Error retrieving company details: $e');
    }
    return null;
  }

  /// Saves last seen notification count
  static Future<void> saveLastSeenNotificationCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastSeenNotificationCount, count);
    } catch (e) {
      debugPrint('[SessionService] Error saving last seen notification count: $e');
    }
  }

  /// Retrieves last seen notification count
  static Future<int> getLastSeenNotificationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyLastSeenNotificationCount) ?? 0;
    } catch (e) {
      debugPrint('[SessionService] Error retrieving last seen notification count: $e');
      return 0;
    }
  }

  /// Saves successful user login session permanently to SharedPreferences
  static Future<void> saveUserSession({
    required dynamic userData,
    String? mobile,
    String? password,
    String? deviceId,
    String? token,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);

      if (mobile != null && mobile.isNotEmpty) {
        await prefs.setString(_keyUserMobile, mobile);
      }

      if (password != null && password.isNotEmpty) {
        await prefs.setString(_keyUserPassword, password);
      }

      if (deviceId != null && deviceId.isNotEmpty) {
        await prefs.setString(_keyDeviceId, deviceId);
      }

      if (userData != null) {
        final jsonString = jsonEncode(userData);
        await prefs.setString(_keyUserData, jsonString);

        if (userData is Map) {
          final comp = userData['company_detils'] ?? userData['company_details'];
          if (comp != null) {
            await prefs.setString(_keyCompanyDetails, jsonEncode(comp));
          }
        }

        // Auto extract token if not explicitly provided
        token ??= extractToken(userData);
      }

      if (token != null && token.isNotEmpty) {
        await prefs.setString(_keyToken, token);
      }

      debugPrint('[SessionService] User login session saved successfully.');
    } catch (e) {
      debugPrint('[SessionService] Error saving user session: $e');
    }
  }

  /// Saves Bearer token explicitly
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
    } catch (e) {
      debugPrint('[SessionService] Error saving token: $e');
    }
  }

  /// Retrieves Bearer token, falling back to extracting from stored user data if necessary
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_keyToken);
      if (savedToken != null && savedToken.isNotEmpty) {
        return savedToken;
      }
      final userData = await getUserData();
      final extracted = extractToken(userData);
      if (extracted != null && extracted.isNotEmpty) {
        await saveToken(extracted);
        return extracted;
      }
    } catch (e) {
      debugPrint('[SessionService] Error retrieving token: $e');
    }
    return null;
  }

  /// Helper to extract Bearer token from various backend JSON response formats
  static String? extractToken(dynamic userData) {
    if (userData == null) return null;
    try {
      if (userData is Map) {
        if (userData['token'] != null && userData['token'].toString().isNotEmpty) {
          return userData['token'].toString();
        }
        if (userData['access_token'] != null && userData['access_token'].toString().isNotEmpty) {
          return userData['access_token'].toString();
        }
        if (userData['bearer_token'] != null && userData['bearer_token'].toString().isNotEmpty) {
          return userData['bearer_token'].toString();
        }
        if (userData['data'] is Map) {
          final data = userData['data'];
          if (data['token'] != null && data['token'].toString().isNotEmpty) {
            return data['token'].toString();
          }
          if (data['access_token'] != null && data['access_token'].toString().isNotEmpty) {
            return data['access_token'].toString();
          }
          if (data['user'] is Map && data['user']['token'] != null) {
            return data['user']['token'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('[SessionService] Error extracting token: $e');
    }
    return null;
  }

  /// Checks if a valid logged-in session exists
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('[SessionService] Error checking login session: $e');
      return false;
    }
  }

  /// Retrieves saved user profile data
  static Future<dynamic> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyUserData);
      if (jsonString != null && jsonString.isNotEmpty) {
        return jsonDecode(jsonString);
      }
    } catch (e) {
      debugPrint('[SessionService] Error retrieving user data: $e');
    }
    return null;
  }

  /// Retrieves saved mobile number
  static Future<String?> getUserMobile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserMobile);
    } catch (e) {
      debugPrint('[SessionService] Error retrieving mobile number: $e');
      return null;
    }
  }

  /// Retrieves saved user password
  static Future<String?> getUserPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserPassword);
    } catch (e) {
      debugPrint('[SessionService] Error retrieving password: $e');
      return null;
    }
  }

  /// Retrieves saved device ID
  static Future<String?> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyDeviceId);
    } catch (e) {
      debugPrint('[SessionService] Error retrieving device ID: $e');
      return null;
    }
  }

  /// Clears user session on explicit Logout or Cache Clear
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserData);
      await prefs.remove(_keyUserMobile);
      await prefs.remove(_keyUserPassword);
      await prefs.remove(_keyDeviceId);
      await prefs.remove(_keyToken);
      debugPrint('[SessionService] User session cleared on logout.');
    } catch (e) {
      debugPrint('[SessionService] Error clearing user session: $e');
    }
  }
}
