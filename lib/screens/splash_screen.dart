import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../services/session_service.dart';
import '../services/user_status_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _bubbleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bubbleFloatAnimation;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Entrance animation controller for logo
    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Continuous floating ambient bubbles controller
    _bubbleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _bubbleFloatAnimation = Tween<double>(begin: -15.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _bubbleAnimationController,
        curve: Curves.easeInOutSine,
      ),
    );

    _mainAnimationController.forward();

    // 3-Second Automatic Navigation with Persistent Session Check
    _navigationTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;

      final bool isLogged = await SessionService.isLoggedIn();
      final userData = await SessionService.getUserData();

      if (!mounted) return;

      if (isLogged) {
        UserStatusService.instance.startPeriodicCheck();
      }

      final Widget targetScreen = isLogged
          ? HomeScreen(userData: userData)
          : const LoginScreen();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _mainAnimationController.dispose();
    _bubbleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final logoWidth = mediaQuery.size.width * 0.72;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: AnimatedBuilder(
        animation: _bubbleFloatAnimation,
        builder: (context, child) {
          final delta = _bubbleFloatAnimation.value;

          return Stack(
            children: [
              // Clean Base Background
              Container(
                color: AppColors.backgroundLight,
              ),

              // ==================== BUBBLE FIELD ====================
              
              // 1. Top-Right Radial Glow Bubble (Large)
              Positioned(
                top: -60 + delta,
                right: -60 - (delta * 0.4),
                child: _buildGradientBubble(
                  size: 280,
                  color1: AppColors.primaryLight.withValues(alpha: 0.12),
                  color2: AppColors.primary.withValues(alpha: 0.02),
                ),
              ),

              // 2. Top-Left Soft Cyan Bubble
              Positioned(
                top: 80 - (delta * 0.8),
                left: -35 + (delta * 0.5),
                child: _buildSolidBubble(
                  size: 160,
                  color: AppColors.secondary.withValues(alpha: 0.08),
                ),
              ),

              // 3. Top Center Subtle Accent Bubble
              Positioned(
                top: 40 + (delta * 0.6),
                left: mediaQuery.size.width * 0.45,
                child: _buildSolidBubble(
                  size: 85,
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
              ),

              // 4. Middle-Left Float Bubble
              Positioned(
                top: mediaQuery.size.height * 0.38 - (delta * 0.6),
                left: -20 - (delta * 0.3),
                child: _buildGradientBubble(
                  size: 130,
                  color1: AppColors.accent.withValues(alpha: 0.08),
                  color2: AppColors.secondary.withValues(alpha: 0.02),
                ),
              ),

              // 5. Middle-Right Soft Blue Bubble
              Positioned(
                top: mediaQuery.size.height * 0.32 + (delta * 0.7),
                right: -30 + (delta * 0.4),
                child: _buildSolidBubble(
                  size: 150,
                  color: AppColors.primaryLight.withValues(alpha: 0.07),
                ),
              ),

              // 6. Center-Right Small Accent Bubble
              Positioned(
                top: mediaQuery.size.height * 0.52 - (delta * 0.9),
                right: 30 - (delta * 0.5),
                child: _buildSolidBubble(
                  size: 70,
                  color: AppColors.secondary.withValues(alpha: 0.09),
                ),
              ),

              // 7. Center-Left Tiny Float Bubble
              Positioned(
                top: mediaQuery.size.height * 0.58 + (delta * 0.5),
                left: 40 + (delta * 0.3),
                child: _buildSolidBubble(
                  size: 55,
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
              ),

              // 8. Bottom-Left Radial Gradient Bubble (Large)
              Positioned(
                bottom: -70 - delta,
                left: -70 + (delta * 0.6),
                child: _buildGradientBubble(
                  size: 320,
                  color1: AppColors.secondary.withValues(alpha: 0.14),
                  color2: AppColors.primary.withValues(alpha: 0.03),
                ),
              ),

              // 9. Bottom-Right Medium Cyan Bubble
              Positioned(
                bottom: 110 + (delta * 0.8),
                right: -25 - (delta * 0.4),
                child: _buildSolidBubble(
                  size: 170,
                  color: AppColors.secondary.withValues(alpha: 0.08),
                ),
              ),

              // 10. Bottom Center Floating Bubble
              Positioned(
                bottom: 30 - (delta * 0.7),
                left: mediaQuery.size.width * 0.35 + (delta * 0.4),
                child: _buildGradientBubble(
                  size: 110,
                  color1: AppColors.primaryLight.withValues(alpha: 0.09),
                  color2: Colors.transparent,
                ),
              ),

              // ======================================================

              // Centered Original Image (No Circle Frame, No Text)
              SafeArea(
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Image.asset(
                        'assets/image/kmrLive.png',
                        width: logoWidth,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.business,
                            size: 100,
                            color: AppColors.primary,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Helper to build solid colored bubble
  Widget _buildSolidBubble({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  /// Helper to build radial gradient bubble
  Widget _buildGradientBubble({
    required double size,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color1, color2, Colors.transparent],
        ),
      ),
    );
  }
}
