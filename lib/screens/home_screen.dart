import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category_model.dart';
import '../models/slider_model.dart';
import '../services/api_service.dart';
import '../services/app_update_service.dart';
import '../services/session_service.dart';
import '../services/user_status_service.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'about_us_screen.dart';
import 'profile_screen.dart';
import '../core/widgets/app_snackbar.dart';
import 'category_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final dynamic userData;

  const HomeScreen({super.key, this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<CategoryResponse> _categoriesFuture;
  late Future<SliderResponse> _slidersFuture;
  bool _hasUnreadNotifications = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkForUpdate(context);
        UserStatusService.instance.checkStatusNow();
      }
    });
  }

  void _loadData() {
    setState(() {
      _categoriesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchCategories(token: token);
      });
      _slidersFuture = SessionService.getToken().then((token) {
        return ApiService().fetchHomeSliders(token: token);
      });
    });

    _checkUnreadNotifications();
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final token = await SessionService.getToken();
      final notifResponse = await ApiService().fetchNotifications(token: token);
      final lastSeenCount = await SessionService.getLastSeenNotificationCount();
      if (mounted) {
        setState(() {
          _hasUnreadNotifications = notifResponse.data.length > lastSeenCount;
        });
      }
    } catch (e) {
      debugPrint('Error checking unread notifications: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch phone call for $phoneNumber')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // If drawer is open, close drawer first
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Press back again to exit',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0A4B26),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<UserStatusData>(
        valueListenable: UserStatusService.instance.statusNotifier,
        builder: (context, statusData, child) {
          final bool isExpired = statusData.isExpired;

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFF0F7F2),
            drawer: _buildDrawer(context, statusData),
            appBar: _buildAppBar(statusData),
            body: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: const Color(0xFF0F5A2F),
                strokeWidth: 2.5,
                onRefresh: () async {
                  UserStatusService.instance.checkStatusNow();
                  _loadData();
                  await Future.wait([_categoriesFuture, _slidersFuture]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // EXPIRED ALERT
                      if (isExpired) _buildExpiredAlert(statusData),

                      const SizedBox(height: 12),

                      // BANNER SLIDER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: _HomeBannerSlider(
                          slidersFuture: _slidersFuture,
                          screenWidth: screenWidth,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // CATEGORIES HEADER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CATEGORIES',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0C3A20),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // CATEGORIES GRID
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: _buildCategoryGrid(isExpired),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: (isExpired || statusData.daysRemaining < 7)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: _buildSubscriptionCard(statusData),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  PreferredSizeWidget _buildAppBar(UserStatusData statusData) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56.0),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A4B26), Color(0xFF1B7A44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 26),
                    onPressed: () async {
                      setState(() {
                        _hasUnreadNotifications = false;
                      });
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      );
                      _checkUnreadNotifications();
                    },
                  ),
                  if (_hasUnreadNotifications)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
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
  }



  // ============================================================
  // CATEGORIES GRID
  // ============================================================
  Widget _buildCategoryGrid(bool isExpired) {
    return FutureBuilder<CategoryResponse>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        // Loading skeleton
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: 9,
            itemBuilder: (_, i) => _skeletonCard(),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                Text(
                  'Failed to load categories\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B7A44),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
        }

        final cr = snapshot.data;
        final cats = cr?.data ?? [];

        if (cats.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No categories found.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        Widget gridContent = GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final cat = cats[i];
            final imgUrl = cr!.getFullImageUrl(cat);
            return _categoryCard(cat, imgUrl, cr.noImageUrl, isExpired);
          },
        );

        if (isExpired) {
          return IgnorePointer(
            ignoring: true,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0,      0,      0,      1, 0,
              ]),
              child: gridContent,
            ),
          );
        }

        return gridContent;
      },
    );
  }

  Widget _categoryCard(CategoryItem cat, String imgUrl, String noImgUrl, bool isExpired) {
    return InkWell(
      onTap: isExpired
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(category: cat),
                ),
              );
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDEDE4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imgUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, prog) {
                      if (prog == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1B7A44),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, e, st) => Image.network(
                      noImgUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, err, stack) => Container(
                        color: const Color(0xFFF0F7F2),
                        child: const Center(
                          child: Icon(
                            Icons.category_rounded,
                            size: 38,
                            color: Color(0xFF1B7A44),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                cat.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C3A20),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDEDE4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 55,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBSCRIPTION / TRIAL CARD (FIXED AT BOTTOM)
  // ============================================================
  Widget _buildSubscriptionCard(UserStatusData statusData) {
    final bool isExpired = statusData.isExpired || statusData.daysRemaining < 0;
    final cardBgColor = isExpired ? const Color(0xFFFDE8E8) : const Color(0xFFDCF2E5);
    final borderColor = isExpired ? const Color(0xFFF8B4B4) : const Color(0xFFBDD9C8);
    final primaryTextColor = isExpired ? const Color(0xFF9B1C1C) : const Color(0xFF0C3A20);
    final secondaryTextColor = isExpired ? const Color(0xFFC81E1E) : const Color(0xFF1B7A44);
    final buttonBgColor = isExpired ? const Color(0xFFC81E1E) : const Color(0xFF0A4B26);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge icon
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x15000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isExpired ? Icons.lock_clock_rounded : Icons.workspace_premium_rounded,
                  color: secondaryTextColor,
                  size: 26,
                ),
              ),

              const SizedBox(width: 10),

              // Days remaining
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${statusData.daysRemaining < 0 ? 0 : statusData.daysRemaining}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'Days\nRemaining',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                      height: 1.15,
                    ),
                  ),
                ],
              ),

              // Divider
              Container(
                height: 34,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: borderColor,
              ),

              // Trial period text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExpired ? 'Trial Expired' : 'Trial Period',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpired ? 'Account locked - contact us' : 'Contact us to reactivate',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Call Us button
              ElevatedButton.icon(
                onPressed: () => _makePhoneCall('9444228585'),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                label: const Text(
                  'Call Us',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBgColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Valid Until row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: isExpired ? Colors.white.withValues(alpha: 0.7) : const Color(0xFFEEFAF2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, size: 15, color: secondaryTextColor),
                const SizedBox(width: 6),
                Text(
                  isExpired
                      ? 'Expired On: ${statusData.validityDateStr.isNotEmpty ? statusData.validityDateStr : 'N/A'}'
                      : 'Valid Until: ${statusData.validityDateStr.isNotEmpty ? statusData.validityDateStr : '30 - September - 2026'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXPIRED ALERT
  // ============================================================
  Widget _buildExpiredAlert(UserStatusData statusData) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.red.shade600,
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Access Disabled - Validity Expired',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                Text(
                  'Expired on ${statusData.validityDateStr}. Contact support to reactivate.',
                  style: TextStyle(fontSize: 11.5, color: Colors.red.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DRAWER (MATCHING SCREENSHOT UIUX)
  // ============================================================
  Widget _buildDrawer(BuildContext context, UserStatusData statusData) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF4FAF6), Color(0xFFD9F4E3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER LOGO & TAGLINE USING OFFICIAL ASSET
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/image/kmrLive.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFB0D9C0), height: 1),
                  ],
                ),
              ),

              // DRAWER ITEMS LIST
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  children: [
                    _drawerItem(
                      icon: Icons.home_rounded,
                      title: 'Home',
                      isSelected: true,
                      onTap: () => Navigator.pop(context),
                    ),
                    _drawerItem(
                      icon: Icons.person_rounded,
                      title: 'My Profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.info_rounded,
                      title: 'About us',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.notifications_rounded,
                      title: 'Notification',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationScreen()),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      isLogout: true,
                      onTap: () {
                        Navigator.pop(context);
                        _handleLogout(context);
                      },
                    ),
                  ],
                ),
              ),

              // FOOTER VERSION
              const Padding(
                padding: EdgeInsets.only(bottom: 18, top: 8),
                child: Text(
                  'Version 3.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C3A20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFC81E1E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0C3A20),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of KMR Live?',
            style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC81E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B7A44)),
      ),
    );

    try {
      final token = await SessionService.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService().logoutUser(token: token);
      }
    } catch (e) {
      debugPrint('[HomeScreen] Logout API call exception: $e');
    } finally {
      UserStatusService.instance.stopPeriodicCheck();
      await SessionService.clearSession();

      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackBar.showSuccess(
          context,
          title: 'Logged Out',
          message: 'You have been successfully logged out.',
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFDCF2E5) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: isSelected ? Colors.white : const Color(0xFFE5F5EC),
          child: Icon(
            icon,
            size: 20,
            color: isLogout ? Colors.red.shade700 : const Color(0xFF0C3A20),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isLogout ? Colors.red.shade700 : const Color(0xFF0C3A20),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================
// DYNAMIC HOME BANNER CAROUSEL SLIDER
// ============================================================
class _HomeBannerSlider extends StatefulWidget {
  final Future<SliderResponse> slidersFuture;
  final double screenWidth;

  const _HomeBannerSlider({
    required this.slidersFuture,
    required this.screenWidth,
  });

  @override
  State<_HomeBannerSlider> createState() => _HomeBannerSliderState();
}

class _HomeBannerSliderState extends State<_HomeBannerSlider> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1000);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int count) {
    if (count <= 1 || _autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _launchSliderUrl(String? urlStr) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    try {
      Uri uri = Uri.parse(urlStr.trim());
      if (!uri.hasScheme) {
        uri = Uri.parse('https://${urlStr.trim()}');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching slider URL $urlStr: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bannerHeight = (widget.screenWidth * 0.44).clamp(160.0, 210.0);

    return FutureBuilder<SliderResponse>(
      future: widget.slidersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _skeletonBanner(bannerHeight);
        }

        final sliderResponse = snapshot.data;
        final sliders = sliderResponse?.data ?? [];

        if (snapshot.hasError || sliders.isEmpty) {
          return _buildStaticFallbackBanner(bannerHeight);
        }

        // Start infinite auto-scrolling timer if multiple items
        _startAutoScroll(sliders.length);

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: double.infinity,
                height: bannerHeight,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (pageIndex) {
                    setState(() {
                      _currentIndex = pageIndex % sliders.length;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = sliders[index % sliders.length];
                    final fullImgUrl = sliderResponse!.getFullImageUrl(item);

                    return GestureDetector(
                      onTap: () => _launchSliderUrl(item.url),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            fullImgUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, prog) {
                              if (prog == null) return child;
                              return Container(
                                color: const Color(0xFF156B38),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, e, st) =>
                                _buildStaticFallbackBanner(bannerHeight),
                          ),

                          // Visit Badge if URL is present
                          if (item.url != null && item.url!.isNotEmpty)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Visit',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Carousel dots indicator
            if (sliders.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  sliders.length,
                  (dotIndex) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: dotIndex == _currentIndex ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotIndex == _currentIndex
                          ? const Color(0xFF1B7A44)
                          : const Color(0xFFBDD9C8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _skeletonBanner(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1B7A44)),
        ),
      ),
    );
  }

  Widget _buildStaticFallbackBanner(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF063D1E), Color(0xFF156B38), Color(0xFF2A9657)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  flex: 58,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'KMR LIVE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A3D1F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Touch The Market "PULSE" Every Day',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Market Trends,\nReal Insights,\nSmarter Decisions',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  flex: 42,
                  child: Center(
                    child: Icon(Icons.eco_rounded, size: 42, color: Color(0xFFFFD700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
