library;

/// Model for Commodity News fetched from app-news/{category_id}
class NewsResponse {
  final List<NewsItem> data;
  final String noImageUrl;
  final String newsImageUrl;

  NewsResponse({
    required this.data,
    required this.noImageUrl,
    required this.newsImageUrl,
  });

  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    final List<NewsItem> items = [];
    if (json['data'] is List) {
      for (var item in json['data']) {
        if (item is Map<String, dynamic>) {
          items.add(NewsItem.fromJson(item));
        } else if (item is Map) {
          items.add(NewsItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    String noImg = 'https://kmrlive.in/crmapi/public/assets/images/no_image.jpg';
    String newsImg = 'https://kmrlive.in/crmapi/public/assets/images/news_images/';

    if (json['image_url'] is List) {
      for (var imgObj in json['image_url']) {
        if (imgObj is Map) {
          final String forVal = imgObj['image_for']?.toString() ?? '';
          final String urlVal = imgObj['image_url']?.toString() ?? '';
          if (forVal.toLowerCase().contains('no image') && urlVal.isNotEmpty) {
            noImg = urlVal;
          } else if (forVal.toLowerCase().contains('news') && urlVal.isNotEmpty) {
            newsImg = urlVal;
          }
        }
      }
    }

    return NewsResponse(
      data: items,
      noImageUrl: noImg,
      newsImageUrl: newsImg,
    );
  }

  String getFullNewsImageUrl(NewsItem item) {
    if (item.newsImage != null && item.newsImage!.trim().isNotEmpty && item.newsImage != 'null') {
      final img = item.newsImage!.trim();
      if (img.startsWith('http://') || img.startsWith('https://')) {
        return img;
      }
      return newsImageUrl.endsWith('/') ? '$newsImageUrl$img' : '$newsImageUrl/$img';
    }
    return noImageUrl;
  }

  String? getFullOtherAttachmentUrl(NewsItem item) {
    if (item.newsOtherImage != null && item.newsOtherImage!.trim().isNotEmpty && item.newsOtherImage != 'null') {
      final img = item.newsOtherImage!.trim();
      if (img.startsWith('http://') || img.startsWith('https://')) {
        return img;
      }
      return newsImageUrl.endsWith('/') ? '$newsImageUrl$img' : '$newsImageUrl/$img';
    }
    return null;
  }
}

class NewsItem {
  final int id;
  final int categoryId;
  final String categoriesName;
  final String newsHeading;
  final String newsDetails;
  final String? newsImage;
  final String? newsOtherImage;
  final String newsCreatedDate;
  final String newsCreatedTime;
  final String newsStatus;

  NewsItem({
    required this.id,
    required this.categoryId,
    required this.categoriesName,
    required this.newsHeading,
    required this.newsDetails,
    this.newsImage,
    this.newsOtherImage,
    required this.newsCreatedDate,
    required this.newsCreatedTime,
    required this.newsStatus,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      categoriesName: json['categories_name']?.toString() ?? '',
      newsHeading: json['news_heading']?.toString() ?? '',
      newsDetails: json['news_details']?.toString() ?? '',
      newsImage: json['news_image']?.toString(),
      newsOtherImage: json['news_other_image']?.toString(),
      newsCreatedDate: json['news_created_date']?.toString() ?? '',
      newsCreatedTime: json['news_created_time']?.toString() ?? '',
      newsStatus: json['news_status']?.toString() ?? 'Active',
    );
  }

  bool get hasOtherAttachment =>
      newsOtherImage != null && newsOtherImage!.trim().isNotEmpty && newsOtherImage != 'null';
}
