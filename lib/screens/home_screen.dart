import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_update/in_app_update.dart';
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
import '../widgets/app_cached_network_image.dart';
import 'category_detail_screen.dart';
import '../core/utils/date_formatter.dart';

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

  Timer? _validityCheckTimer;
  bool _isValidityExpired = false;
  String _validityExpiredMessage = 'Your access has expired—contact admin for help';
  String? _apiValidityDate;

  String _getResolvedValidityDate(UserStatusData statusData) {
    if (statusData.validityDateStr.isNotEmpty && statusData.validityDateStr != 'N/A') {
      return statusData.validityDateStr;
    }
    if (_apiValidityDate != null && _apiValidityDate!.isNotEmpty && _apiValidityDate != 'N/A') {
      final formatted = AppDateFormatter.format(_apiValidityDate);
      if (formatted.isNotEmpty && formatted != 'N/A') return formatted;
      return _apiValidityDate!;
    }
    if (widget.userData != null) {
      final date = SessionService.extractValidityDate(widget.userData);
      if (date.isNotEmpty && date != 'N/A') {
        final formatted = AppDateFormatter.format(date);
        if (formatted.isNotEmpty && formatted != 'N/A') return formatted;
        return date;
      }
    }
    return '';
  }

  int _getResolvedDaysRemaining(UserStatusData statusData) {
    if (statusData.daysRemaining != 0) {
      return statusData.daysRemaining;
    }
    final rawDate = (_apiValidityDate != null && _apiValidityDate!.isNotEmpty && _apiValidityDate != 'N/A')
        ? _apiValidityDate!
        : (widget.userData != null ? SessionService.extractValidityDate(widget.userData) : '');
    if (rawDate.isNotEmpty && rawDate != 'N/A') {
      final parsed = UserStatusService.parseValidityDate(rawDate);
      return parsed.daysRemaining;
    }
    return statusData.daysRemaining;
  }

  @override
  void initState() {
    super.initState();
    _initValidityDate();
    _loadData();
    _startValidityCheckTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkForUpdate(context);
        UserStatusService.instance.checkStatusNow(directUserData: widget.userData);
      }
    });
  }

  Future<void> _initValidityDate() async {
    // 1. Check widget.userData first
    if (widget.userData != null) {
      final date = SessionService.extractValidityDate(widget.userData);
      if (date.isNotEmpty && date != 'N/A') {
        _apiValidityDate = date;
        await SessionService.saveValidityDate(date);
        UserStatusService.instance.processUserData(widget.userData);
      }
    }
    // 2. Check saved session validity date
    if (_apiValidityDate == null || _apiValidityDate!.isEmpty || _apiValidityDate == 'N/A') {
      final saved = await SessionService.getValidityDate();
      if (saved != null && saved.isNotEmpty && saved != 'N/A') {
        _apiValidityDate = saved;
        UserStatusService.instance.processUserData({'validity_date': saved});
      }
    }
    // 3. Check getUserData()
    if (_apiValidityDate == null || _apiValidityDate!.isEmpty || _apiValidityDate == 'N/A') {
      final uData = await SessionService.getUserData();
      final date = SessionService.extractValidityDate(uData);
      if (date.isNotEmpty && date != 'N/A') {
        _apiValidityDate = date;
        await SessionService.saveValidityDate(date);
        UserStatusService.instance.processUserData(uData);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _startValidityCheckTimer() {
    _validityCheckTimer?.cancel();
    // Check immediately on load
    _checkAppValidity();
    // Run every 10 seconds as required
    _validityCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAppValidity();
    });
  }

  Future<void> _checkAppValidity() async {
    try {
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) return;

      final response = await ApiService().checkValidity(token: token);

      bool isGood = false;
      String msg = '';

      if (response is Map) {
        final code = int.tryParse(response['code']?.toString() ?? '') ?? 0;
        msg = response['message']?.toString().trim() ?? '';
        // If code == 200 and message is "Yes" (case-insensitive) => all good
        if (code == 200 && msg.toLowerCase() == 'yes') {
          isGood = true;
        }
      }

      if (mounted) {
        final shouldExpire = !isGood;
        if (_isValidityExpired != shouldExpire) {
          setState(() {
            _isValidityExpired = shouldExpire;
            if (msg.isNotEmpty && msg.toLowerCase() != 'yes') {
              _validityExpiredMessage = msg;
            }
          });
        }
        UserStatusService.instance.setValidityExpired(shouldExpire);
      }
    } catch (e) {
      debugPrint('[HomeScreen] app-check-validity API notice: $e');
      if (mounted && !_isValidityExpired) {
        setState(() {
          _isValidityExpired = true;
          _validityExpiredMessage = 'Your access has expired—contact admin for help';
        });
        UserStatusService.instance.setValidityExpired(true);
      }
    }
  }

  @override
  void dispose() {
    _validityCheckTimer?.cancel();
    super.dispose();
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
              backgroundColor: const Color(0xFF0A3B73),
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
          final int resolvedDays = _getResolvedDaysRemaining(statusData);
          final bool isExpired = _isValidityExpired || statusData.isExpired || resolvedDays < 0;
          final int displayDays = (isExpired || resolvedDays < 0) ? 0 : resolvedDays;
          final bool showSubscriptionCard = isExpired || displayDays <= 7;

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
                  await _checkAppValidity();
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

                      // WRAP ENTIRE APP CONTENT: when expired, make it black and white (greyscale), dimmed opacity, and unclickable
                      IgnorePointer(
                        ignoring: isExpired,
                        child: ColorFiltered(
                          colorFilter: isExpired
                              ? const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ])
                              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                          child: Opacity(
                            opacity: isExpired ? 0.6 : 1.0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'CATEGORIES',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF061E36),
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
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: showSubscriptionCard
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: _buildSubscriptionCard(statusData),
                    ),
                  )
                : const _BottomSolidColorBar(),
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
            colors: [Color(0xFF0A3B73), Color(0xFF155799)],
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
                    backgroundColor: const Color(0xFF0A3B73),
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
          border: Border.all(color: const Color(0xFFD0E1F4), width: 1),
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
                  child: AppCachedNetworkImage(
                    imageUrl: imgUrl.isNotEmpty ? imgUrl : noImgUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: AppCachedNetworkImage(
                      imageUrl: noImgUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: const Color(0xFFF0F7F2),
                        child: const Center(
                          child: Icon(
                            Icons.category_rounded,
                            size: 38,
                            color: Color(0xFF0A3B73),
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
                  color: Color(0xFF061E36),
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
        border: Border.all(color: const Color(0xFFD0E1F4)),
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
  // ============================================================
  // SUBSCRIPTION / TRIAL CARD (FIXED AT BOTTOM)
  // ============================================================
  Widget _buildSubscriptionCard(UserStatusData statusData) {
    final String resolvedValidityDate = _getResolvedValidityDate(statusData);
    final int resolvedDays = _getResolvedDaysRemaining(statusData);

    final bool isExpired = _isValidityExpired || statusData.isExpired || resolvedDays < 0;
    final int displayDays = (isExpired || resolvedDays < 0) ? 0 : resolvedDays;

    final cardBgColor = isExpired ? const Color(0xFFFDE8E8) : const Color(0xFFEBF3FA);
    final borderColor = isExpired ? const Color(0xFFF8B4B4) : const Color(0xFFD0E1F4);
    final primaryTextColor = isExpired ? const Color(0xFF9B1C1C) : const Color(0xFF061E36);
    final secondaryTextColor = isExpired ? const Color(0xFFC81E1E) : const Color(0xFF0A3B73);
    final buttonBgColor = isExpired ? const Color(0xFFC81E1E) : const Color(0xFF0A3B73);

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

              // Days remaining (dynamically calculated from today's date)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$displayDays',
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

              // Subscription status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExpired
                          ? 'Subscription Expired'
                          : (displayDays <= 7 ? 'Expiring Soon' : 'Active Subscription'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpired
                          ? 'Account locked - contact us'
                          : (displayDays <= 7
                              ? 'Contact us to renew'
                              : 'Verified and active'),
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

          // Dynamic Validity Date / Expired Date row (from API response, not hardcoded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: isExpired ? Colors.white.withValues(alpha: 0.7) : const Color(0xFFEBF3FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, size: 15, color: secondaryTextColor),
                const SizedBox(width: 6),
                Text(
                  isExpired
                      ? (resolvedValidityDate.isNotEmpty
                          ? 'Expired On: $resolvedValidityDate'
                          : 'Expired')
                      : (resolvedValidityDate.isNotEmpty
                          ? 'Valid Until: $resolvedValidityDate'
                          : 'Active'),
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
    final String resolvedValidityDate = _getResolvedValidityDate(statusData);
    final String displayMessage = _validityExpiredMessage.isNotEmpty
        ? _validityExpiredMessage
        : (resolvedValidityDate.isNotEmpty
            ? 'Expired on $resolvedValidityDate. Contact support to reactivate.'
            : 'Your access has expired—contact admin for help');

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
                const SizedBox(height: 2),
                Text(
                  displayMessage,
                  style: TextStyle(fontSize: 11.5, color: Colors.red.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall('9444228585'),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 13),
            label: const Text('Call Us', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
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
    final String resolvedValidityDate = _getResolvedValidityDate(statusData);
    final int resolvedDays = _getResolvedDaysRemaining(statusData);
    final bool isExpired = _isValidityExpired || statusData.isExpired || resolvedDays < 0;

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FA), Color(0xFFE1EDF9)],
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
                    if (resolvedValidityDate.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isExpired ? const Color(0xFFFDE8E8) : const Color(0xFFEBF3FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isExpired ? const Color(0xFFF8B4B4) : const Color(0xFFD0E1F4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpired ? Icons.lock_clock_rounded : Icons.verified_user_rounded,
                              size: 15,
                              color: isExpired ? Colors.red : const Color(0xFF0A3B73),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isExpired
                                  ? 'Expired: $resolvedValidityDate'
                                  : 'Valid: $resolvedValidityDate ($resolvedDays days)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isExpired ? Colors.red.shade900 : const Color(0xFF0A3B73),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFD0E1F4), height: 1),
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
                      icon: Icons.refresh_rounded,
                      title: 'Refresh App Cache',
                      onTap: () => _handleClearCache(context),
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

              // FOOTER DYNAMIC VERSION & UPDATE CHECK
              const _DrawerVersionFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleClearCache(BuildContext context) async {
    Navigator.pop(context);

    // Clear Flutter's memory image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Reload all home categories, sliders and status
    _loadData();
    UserStatusService.instance.checkStatusNow();

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        title: 'Cache Cleared',
        message: 'App cache cleared & fresh data loaded.',
      );
    }
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
                  color: Color(0xFF061E36),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of KMR LiVE?',
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
        child: CircularProgressIndicator(color: Color(0xFF0A3B73)),
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
        color: isSelected ? const Color(0xFFD0E1F4) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: isSelected ? Colors.white : const Color(0xFFEBF3FA),
          child: Icon(
            icon,
            size: 20,
            color: isLogout ? Colors.red.shade700 : const Color(0xFF061E36),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isLogout ? Colors.red.shade700 : const Color(0xFF061E36),
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
                          AppCachedNetworkImage(
                            imageUrl: fullImgUrl,
                            fit: BoxFit.cover,
                            errorWidget: _buildStaticFallbackBanner(bannerHeight),
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
                          ? const Color(0xFF0A3B73)
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
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A3B73)),
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
                          'KMR LiVE',
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

// ============================================================
// BOTTOM SOLID COLOR BAR (SHOWN WHEN VALIDITY >= 7 DAYS)
// ============================================================
class _BottomSolidColorBar extends StatefulWidget {
  const _BottomSolidColorBar();

  @override
  State<_BottomSolidColorBar> createState() => _BottomSolidColorBarState();
}

class _BottomSolidColorBarState extends State<_BottomSolidColorBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double totalHeight = 44.0 + bottomPadding;

    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaveBarPainter(
              animValue: _waveController.value,
              bottomPadding: bottomPadding,
            ),
          );
        },
      ),
    );
  }
}

class _WaveBarPainter extends CustomPainter {
  final double animValue;
  final double bottomPadding;
  const _WaveBarPainter({required this.animValue, this.bottomPadding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final double waveEffectiveHeight = size.height - bottomPadding;

    // Solid base underneath so the bottom gesture area is never empty or white
    final basePaint = Paint()
      ..color = const Color(0xFF0A3B73)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, waveEffectiveHeight * 0.65, size.width, size.height - waveEffectiveHeight * 0.65),
      basePaint,
    );

    // Wave 1 — lighter, faster
    final wave1Paint = Paint()
      ..color = const Color(0xFF155799).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    final path1 = Path();
    path1.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = waveEffectiveHeight * 0.38 +
          math.sin((x / size.width * 2 * math.pi) + animValue * 2 * math.pi) *
              waveEffectiveHeight *
              0.22;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, wave1Paint);

    // Wave 2 — darker, slower, offset
    final wave2Paint = Paint()
      ..color = const Color(0xFF0A3B73).withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = waveEffectiveHeight * 0.50 +
          math.sin((x / size.width * 2 * math.pi) +
                  animValue * 2 * math.pi * 0.7 +
                  math.pi * 0.5) *
              waveEffectiveHeight *
              0.18;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, wave2Paint);
  }

  @override
  bool shouldRepaint(_WaveBarPainter old) =>
      old.animValue != animValue || old.bottomPadding != bottomPadding;
}

// ============================================================
// DYNAMIC DRAWER VERSION & PLAY STORE UPDATE FOOTER
// ============================================================
class _DrawerVersionFooter extends StatefulWidget {
  const _DrawerVersionFooter();

  @override
  State<_DrawerVersionFooter> createState() => _DrawerVersionFooterState();
}

class _DrawerVersionFooterState extends State<_DrawerVersionFooter> {
  String _versionText = 'Version ...';
  bool _isUpdateAvailable = false;

  @override
  void initState() {
    super.initState();
    _fetchVersionAndCheckUpdate();
  }

  Future<void> _fetchVersionAndCheckUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versionStr = 'Version ${packageInfo.version}';
      
      bool updateAvailable = false;
      if (Platform.isAndroid) {
        try {
          final updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
            final availableCode = updateInfo.availableVersionCode ?? 0;
            if (availableCode > 0 && currentCode > 0 && currentCode >= availableCode) {
              updateAvailable = false;
            } else {
              updateAvailable = true;
            }
          }
        } catch (e) {
          debugPrint('[DrawerVersionFooter] Play Store check: $e');
        }
      }

      if (mounted) {
        setState(() {
          _versionText = versionStr;
          _isUpdateAvailable = updateAvailable;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _versionText = 'Version 4.0.0';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dynamic Installed App Version
          Text(
            _versionText,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF061E36),
            ),
          ),

          // Show Update Button ONLY if an update is available on Play Store
          if (_isUpdateAvailable) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => AppUpdateService.checkForUpdate(context, forceCheck: true),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A3B73), Color(0xFF155799)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330A3B73),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.system_update_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Update Available',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

