/// Data model for individual notification returned by app-notification API
class NotificationItem {
  final int id;
  final String date;
  final String heading;
  final String description;
  final String image;

  NotificationItem({
    required this.id,
    required this.date,
    required this.heading,
    required this.description,
    required this.image,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      date: json['notification_date']?.toString() ?? '',
      heading: json['notification_heading']?.toString() ?? '',
      description: json['notification_description']?.toString() ?? '',
      image: json['notification_image']?.toString() ?? '',
    );
  }
}

/// Data model wrapping the app-notification API response.
class NotificationResponse {
  final List<NotificationItem> data;
  final String notificationBaseUrl;
  final String noImageUrl;

  NotificationResponse({
    required this.data,
    required this.notificationBaseUrl,
    required this.noImageUrl,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    List<NotificationItem> notifications = [];
    if (json['data'] is List) {
      notifications = (json['data'] as List)
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    String notifBase = 'https://kmrlive.in/crmapi/public/assets/images/notification_images/';
    String noImg = 'https://kmrlive.in/crmapi/public/assets/images/no_image.jpg';

    if (json['image_url'] is List) {
      for (var imgObj in json['image_url']) {
        if (imgObj is Map<String, dynamic>) {
          final imageFor = imgObj['image_for']?.toString();
          final url = imgObj['image_url']?.toString();
          if (imageFor == 'Notification' && url != null && url.isNotEmpty) {
            notifBase = url;
          } else if (imageFor == 'No Image' && url != null && url.isNotEmpty) {
            noImg = url;
          }
        }
      }
    }

    return NotificationResponse(
      data: notifications,
      notificationBaseUrl: notifBase,
      noImageUrl: noImg,
    );
  }

  /// Construct complete image URL safely with URI encoding
  String getFullImageUrl(NotificationItem item) {
    if (item.image.isEmpty) return noImageUrl;

    String base = notificationBaseUrl;
    if (!base.endsWith('/') && !item.image.startsWith('/')) {
      base = '$base/';
    }

    final fullPath = '$base${item.image}';
    return Uri.encodeFull(fullPath);
  }
}
