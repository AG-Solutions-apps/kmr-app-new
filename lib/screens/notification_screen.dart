import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// Redesigned premium Notification Screen with top-to-bottom gradient header
/// and reference UI matching notification cards with expand modal functionality.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<NotificationResponse> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = SessionService.getToken().then((token) {
        return ApiService().fetchNotifications(token: token);
      });
    });
  }

  /// Display full notification detail bottom sheet modal on card / arrow click
  void _showNotificationDetailModal(BuildContext context, NotificationItem item, String displayImgUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle Pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 190,
                      color: const Color(0xFFF0F7F2),
                      child: Image.network(
                        displayImgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) => const Center(
                          child: Icon(Icons.notifications_active_rounded, color: Color(0xFF1B7A44), size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tag Row: Product Update + Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEFAF2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBDD9C8), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.campaign_rounded, size: 14, color: Color(0xFF1B7A44)),
                            SizedBox(width: 6),
                            
                          ],
                        ),
                      ),
                      if (item.date.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFAF2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBDD9C8), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF1B7A44)),
                              const SizedBox(width: 6),
                              Text(
                                item.date,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B7A44),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    item.heading,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F291E),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFFEEFAF2), height: 1),
                  const SizedBox(height: 12),

                  // Full Long Description
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A4B26), Color(0xFF1B7A44)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  FutureBuilder<NotificationResponse>(
                    future: _notificationsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.data.isNotEmpty) {
                        final count = snapshot.data!.data.length;
                        return Container(
                          margin: const EdgeInsets.only(right: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$count Updates',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F5A2F),
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        onRefresh: () async {
          _loadNotifications();
          await _notificationsFuture;
        },
        child: FutureBuilder<NotificationResponse>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (context, index) => _skeletonCard(),
              );
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE8E8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          size: 44,
                          color: Color(0xFFC81E1E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0C3A20),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _loadNotifications,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B7A44),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final notifResponse = snapshot.data;
            final items = notifResponse?.data ?? [];

            if (items.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF2E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B7A44).withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 52,
                          color: Color(0xFF1B7A44),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Notifications Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0C3A20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          'You are all caught up! New market announcements and daily pulse updates will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Persist that notifications have been seen
            SessionService.saveLastSeenNotificationCount(items.length);

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final item = items[i];
                final fullImgUrl = notifResponse!.getFullImageUrl(item);
                return _notificationCard(item, fullImgUrl, notifResponse.noImageUrl);
              },
            );
          },
        ),
      ),
    );
  }

  /// Notification Card matching the reference UI
  Widget _notificationCard(NotificationItem item, String imgUrl, String noImgUrl) {
    final bool hasImage = item.image.isNotEmpty;
    final displayImgUrl = hasImage ? imgUrl : noImgUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showNotificationDetailModal(context, item, displayImgUrl),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2F1E8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Image with "New" Badge Overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 110,
                      height: 105,
                      child: Image.network(
                        displayImgUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, prog) {
                          if (prog == null) return child;
                          return Container(
                            color: const Color(0xFFF0F7F2),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1B7A44),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, err, stack) => Container(
                          color: const Color(0xFFEEFAF2),
                          child: const Center(
                            child: Icon(Icons.notifications_active_rounded, color: Color(0xFF1B7A44), size: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // "New" Badge Overlay
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B050),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'New',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Right Side Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row: Product Update Tag + Date Tag
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEFAF2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.campaign_rounded, size: 13, color: Color(0xFF1B7A44)),
                                SizedBox(width: 4),
                                
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        if (item.date.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEFAF2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 12, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.date,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B7A44),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Heading / Title
                    Text(
                      item.heading,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F291E),
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Description + Circular Arrow Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Circular Chevron Right Button
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEFAF2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF1B7A44),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDEDE4)),
      ),
      child: Row(
        children: [
          Container(
            width: 110,
            height: 105,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 70,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 130,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
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
