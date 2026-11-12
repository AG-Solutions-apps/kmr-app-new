import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service responsible for Google Play Store Dynamic App Update handling.
/// 
/// Accurately checks if the Google Play Store version is greater than the 
/// currently installed app version and prompts the user to update.
class AppUpdateService {
  AppUpdateService._();

  /// Session flag: tracks if the user dismissed the update prompt in the current app session
  static bool _hasDismissedThisSession = false;

  /// Package Name for Google Play Store fallback
  static String? _packageName;

  /// Main entry point to check and prompt for app update on app launch
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    // If user already dismissed during this session and check is not forced, skip
    if (_hasDismissedThisSession && !forceCheck) {
      debugPrint('[AppUpdateService] Update prompt skipped: Dismissed in current session.');
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _packageName = packageInfo.packageName;
      final currentVersion = packageInfo.version.trim();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

      if (!Platform.isAndroid) return;

      bool updateAvailable = false;
      bool isImmediate = false;
      String? playStoreVersion;

      // STEP 1: Attempt official Google Play In-App Update API
      try {
        final updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          final storeBuildNumber = updateInfo.availableVersionCode ?? 0;
          if (storeBuildNumber > currentBuildNumber || currentBuildNumber == 0) {
            updateAvailable = true;
            isImmediate = updateInfo.immediateUpdateAllowed;
            debugPrint('[AppUpdateService] Play In-App Update API found newer build: $storeBuildNumber > $currentBuildNumber');
          }
        }
      } catch (playError) {
        debugPrint('[AppUpdateService] Play Core API skipped or unavailable: $playError');
      }

      // STEP 2: Play Store Version Check fallback (guarantees detection if Play Store version > App version)
      if (!updateAvailable) {
        try {
          playStoreVersion = await _fetchPlayStoreVersion(_packageName ?? 'com.kmr.agsolutions');
          if (playStoreVersion != null && playStoreVersion.isNotEmpty) {
            final isGreater = _isStoreVersionGreater(playStoreVersion, currentVersion);
            debugPrint('[AppUpdateService] Version Comparison: Play Store ($playStoreVersion) vs Installed ($currentVersion) -> Newer: $isGreater');
            if (isGreater) {
              updateAvailable = true;
            }
          }
        } catch (fetchErr) {
          debugPrint('[AppUpdateService] Error fetching Play Store web version: $fetchErr');
        }
      }

      // STEP 3: Display Update Bar / Dialog if Play Store version is greater
      if (updateAvailable && context.mounted) {
        showThemeUpdateDialog(
          context,
          isImmediate: isImmediate,
          storeVersion: playStoreVersion,
          installedVersion: currentVersion,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Unexpected error during update check: $e');
    }
  }

  /// Fetches the latest published version string directly from the Google Play Store page
  static Future<String?> _fetchPlayStoreVersion(String packageName) async {
    try {
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$packageName&hl=en&gl=US',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;

        // Pattern 1: [[["6.0.2"]]]
        final reg1 = RegExp(r'\[\[\["([0-9]+(?:\.[0-9]+)+[^"]*)"\]');
        final match1 = reg1.firstMatch(body);
        if (match1 != null) {
          return match1.group(1);
        }

        // Pattern 2: ["6.0.2"]
        final reg2 = RegExp(r'\["([0-9]+\.[0-9]+(?:\.[0-9]+)*)"\]');
        final match2 = reg2.firstMatch(body);
        if (match2 != null) {
          return match2.group(1);
        }

        // Pattern 3: AF_dataServiceRequests version pattern
        final reg3 = RegExp(r'"([0-9]+\.[0-9]+\.[0-9]+)"');
        final matches = reg3.allMatches(body);
        for (final m in matches) {
          final ver = m.group(1);
          if (ver != null && ver != '0.0.0') {
            return ver;
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error reading Play Store page: $e');
    }
    return null;
  }

  /// Compares semantic versions (e.g. "6.0.2" vs "5.0.3")
  /// Returns true if [storeVersion] is strictly greater than [installedVersion]
  static bool _isStoreVersionGreater(String storeVersion, String installedVersion) {
    try {
      final storeClean = storeVersion.replaceAll(RegExp(r'[^0-9.]'), '');
      final currentClean = installedVersion.replaceAll(RegExp(r'[^0-9.]'), '');

      final storeParts = storeClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = storeParts.length > currentParts.length ? storeParts.length : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final storePart = i < storeParts.length ? storeParts[i] : 0;
        final currentPart = i < currentParts.length ? currentParts[i] : 0;

        if (storePart > currentPart) return true;
        if (storePart < currentPart) return false;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Version parse comparison error: $e');
    }
    return false;
  }

  /// Displays the KMR LIVE themed update popup dialog
  static void showThemeUpdateDialog(
    BuildContext context, {
    bool isImmediate = false,
    String? storeVersion,
    String? installedVersion,
  }) {
    if (_hasDismissedThisSession && !isImmediate) return;

    showDialog(
      context: context,
      barrierDismissible: !isImmediate,
      builder: (ctx) {
        return PopScope(
          canPop: !isImmediate,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop && !isImmediate) {
              _hasDismissedThisSession = true;
            }
          },
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 12,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Icon Badge
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD0E1F4), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF0A3B73),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'App Update Available',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF061E36),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'A new version of KMR LiVE is available on Google Play Store. Update now to enjoy the latest features, improvements, and bug fixes.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Version Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD0E1F4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF0A3B73)),
                        const SizedBox(width: 6),
                        Text(
                          storeVersion != null
                              ? 'New Version $storeVersion Available'
                              : 'Latest Store Build Available',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0A3B73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      // Dismiss / Later Button
                      if (!isImmediate) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              _hasDismissedThisSession = true;
                              Navigator.of(ctx).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                            child: Text(
                              'Later',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Update Now Button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF155799), Color(0xFF0A3B73), Color(0xFF052342)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0A3B73).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _performUpdate();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Update Now',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Triggers Play Store in-app update or launches the Google Play Store app page
  static Future<void> _performUpdate() async {
    try {
      if (Platform.isAndroid) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        await _openPlayStorePage();
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Immediate update failed, opening Play Store URL: $e');
      await _openPlayStorePage();
    }
  }

  /// Opens Google Play Store page directly
  static Future<void> _openPlayStorePage() async {
    final pkg = _packageName ?? 'com.kmr.agsolutions';
    final marketUri = Uri.parse('market://details?id=$pkg');
    final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error opening Play Store: $e');
    }
  }
}
