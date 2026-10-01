import 'package:flutter/material.dart';

/// Centralized custom SnackBar builder matching the app design system.
/// Features light mint background, rounded pill layout, and solid badge icon.
class AppSnackBar {
  AppSnackBar._();

  /// Show Success SnackBar matching the uploaded design
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showCustomSnackBar(
      context: context,
      title: title,
      message: message,
      bgColor: const Color(0xFFEAF8F0),
      borderColor: const Color(0xFFC4E8D1),
      badgeColor: const Color(0xFF0F5A2F),
      badgeIcon: Icons.check_rounded,
      titleColor: const Color(0xFF0C3A20),
      messageColor: const Color(0xFF3B6E4E),
      duration: duration,
    );
  }

  /// Show Error SnackBar with soft red styling
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showCustomSnackBar(
      context: context,
      title: title,
      message: message,
      bgColor: const Color(0xFFFDE8E8),
      borderColor: const Color(0xFFF8B4B4),
      badgeColor: const Color(0xFFC81E1E),
      badgeIcon: Icons.priority_high_rounded,
      titleColor: const Color(0xFF9B1C1C),
      messageColor: const Color(0xFFC81E1E),
      duration: duration,
    );
  }

  /// Show Info SnackBar with soft green theme
  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showCustomSnackBar(
      context: context,
      title: title,
      message: message,
      bgColor: const Color(0xFFEEFAF2),
      borderColor: const Color(0xFFBDD9C8),
      badgeColor: const Color(0xFF1B7A44),
      badgeIcon: Icons.info_outline_rounded,
      titleColor: const Color(0xFF0C3A20),
      messageColor: const Color(0xFF1B7A44),
      duration: duration,
    );
  }

  /// Quick helper for single message popups
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    bool isError = false,
  }) {
    if (isError) {
      showError(context, title: title ?? 'Notice', message: message);
    } else {
      showSuccess(context, title: title ?? 'Success', message: message);
    }
  }

  static void _showCustomSnackBar({
    required BuildContext context,
    required String title,
    required String message,
    required Color bgColor,
    required Color borderColor,
    required Color badgeColor,
    required IconData badgeIcon,
    required Color titleColor,
    required Color messageColor,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        padding: EdgeInsets.zero,
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badgeIcon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Message Text
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.2,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: messageColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
