import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service responsible for Google Play Store Dynamic App Update handling.
/// 
/// Behavior:
/// - Checks Google Play Store for new version availability on launch (Login & Home pages).
/// - Shows KMR LIVE themed update popup when an update is available.
/// - If the user dismisses/cancels the dialog ("Later"), it suppresses further prompts during the current app session.
/// - On app restart (next app launch), the session flag resets and will prompt the user again.
class AppUpdateService {
  AppUpdateService._();

  /// Session flag: tracks if the user dismissed the update prompt in the current app session
  static bool _hasDismissedThisSession = false;

  /// Package Name for Google Play Store URL fallback
  static String? _packageName;

  /// Main entry point to check and prompt for app update on app launch
  static Future<void> checkForUpdate(BuildContext context, {bool forceCheck = false, bool enableDebugFallback = true}) async {
    // If user already dismissed during this session and not forced, skip prompt
    if (_hasDismissedThisSession && !forceCheck) {
      debugPrint('[AppUpdateService] Update prompt skipped: User dismissed update during current session.');
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _packageName = packageInfo.packageName;

      if (Platform.isAndroid) {
        bool showUpdate = false;
        bool isImmediate = false;

        try {
          // 1. Check official Google Play In-App Update API
          final updateInfo = await InAppUpdate.checkForUpdate();

          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            showUpdate = true;
            isImmediate = updateInfo.immediateUpdateAllowed;
          } else {
            debugPrint('[AppUpdateService] Play Store reports app is up to date.');
          }
        } catch (playError) {
          debugPrint('[AppUpdateService] Play Store API notice (Debug/Sideloaded build): $playError');
          // In debug builds or sideloaded APKs, Play Store API will throw error.
          // Enable fallback popup demonstration if configured
          if (kDebugMode && enableDebugFallback && !forceCheck) {
            showUpdate = true;
          }
        }

        if (showUpdate && context.mounted) {
          showThemeUpdateDialog(context, isImmediate: isImmediate);
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking update: $e');
    }
  }

  /// Displays the KMR LIVE themed update dialog matching app styling
  static void showThemeUpdateDialog(BuildContext context, {bool isImmediate = false}) {
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
                  // Top Emerald Icon Badge
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF059669),
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
                      color: const Color(0xFF0F291E),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'A new version of KMR LIVE is available on Google Play Store. Update now for the latest features, enhanced speed, and security updates.',
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
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Text(
                          'Latest Store Build Available',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      // Cancel / Later Button (if not forced immediate)
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
                              colors: [Color(0xFF15803D), Color(0xFF047857), Color(0xFF064E3B)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF047857).withValues(alpha: 0.3),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
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

  /// Triggers Play Store update or opens Play Store app page
  static Future<void> _performUpdate() async {
    try {
      if (Platform.isAndroid) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        await _openPlayStorePage();
      }
    } catch (e) {
      debugPrint('[AppUpdateService] InAppUpdate failed, falling back to Play Store URL: $e');
      await _openPlayStorePage();
    }
  }

  /// Opens Google Play Store app page for the application
  static Future<void> _openPlayStorePage() async {
    final pkg = _packageName ?? 'com.kmr.kmr_new';
    final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
    final marketUrl = Uri.parse('market://details?id=$pkg');

    try {
      if (await canLaunchUrl(marketUrl)) {
        await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(playStoreUrl)) {
        await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error launching Play Store: $e');
    }
  }
}
