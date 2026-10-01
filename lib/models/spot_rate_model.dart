library;

import 'live_rate_model.dart';

/// Models for Spot Rates Data fetched from app-spot/{category_id}
class SpotRateResponse {
  final List<SubCategoryItem> subCategories;
  final List<SpotRateItem> data;
  final String noImageUrl;
  final String spotImageUrl;

  SpotRateResponse({
    required this.subCategories,
    required this.data,
    required this.noImageUrl,
    required this.spotImageUrl,
  });

  factory SpotRateResponse.fromJson(Map<String, dynamic> json) {
    // Parse sub_categories
    final List<SubCategoryItem> subs = [];
    if (json['sub_categories'] is List) {
      for (var item in json['sub_categories']) {
        if (item is Map<String, dynamic>) {
          subs.add(SubCategoryItem.fromJson(item));
        } else if (item is Map) {
          subs.add(SubCategoryItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Parse data items
    final List<SpotRateItem> items = [];
    if (json['data'] is List) {
      for (var item in json['data']) {
        if (item is Map<String, dynamic>) {
          items.add(SpotRateItem.fromJson(item));
        } else if (item is Map) {
          items.add(SpotRateItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    String noImg = 'https://kmrlive.in/crmapi/public/assets/images/no_image.jpg';
    String spotImg = 'https://kmrlive.in/crmapi/public/assets/images/vendor_images/';

    if (json['image_url'] is List) {
      for (var imgObj in json['image_url']) {
        if (imgObj is Map) {
          final String forVal = imgObj['image_for']?.toString() ?? '';
          final String urlVal = imgObj['image_url']?.toString() ?? '';
          if (forVal.toLowerCase().contains('no image') && urlVal.isNotEmpty) {
            noImg = urlVal;
          } else if (forVal.toLowerCase().contains('vendor') ||
              forVal.toLowerCase().contains('spot') ||
              forVal.toLowerCase().contains('news')) {
            if (urlVal.isNotEmpty) spotImg = urlVal;
          }
        }
      }
    }

    return SpotRateResponse(
      subCategories: subs,
      data: items,
      noImageUrl: noImg,
      spotImageUrl: spotImg,
    );
  }

  String getFullSpotImageUrl(SpotRateItem item) {
    if (item.vendorImage != null && item.vendorImage!.trim().isNotEmpty) {
      final img = item.vendorImage!.trim();
      if (img.startsWith('http://') || img.startsWith('https://')) {
        return img;
      }
      return spotImageUrl.endsWith('/') ? '$spotImageUrl$img' : '$spotImageUrl/$img';
    }
    return noImageUrl;
  }
}

class SpotRateItem {
  final int id;
  final int categoryId;
  final String categoriesName;
  final int subCategoryId;
  final String subCategoriesName;
  final int vendorId;
  final String vendorName;
  final String? vendorImage;
  final String? vendorMobile;
  final String vendorSpotHeading;
  final String vendorSpotDetails;
  final String vendorSpotCreatedDate;
  final String vendorSpotCreatedTime;
  final String vendorSpotStatus;
  final String vendorProductRate;
  final String priceDifference;
  final List<SpotStockItem> stocks;

  SpotRateItem({
    required this.id,
    required this.categoryId,
    required this.categoriesName,
    required this.subCategoryId,
    required this.subCategoriesName,
    required this.vendorId,
    required this.vendorName,
    this.vendorImage,
    this.vendorMobile,
    required this.vendorSpotHeading,
    required this.vendorSpotDetails,
    required this.vendorSpotCreatedDate,
    required this.vendorSpotCreatedTime,
    required this.vendorSpotStatus,
    required this.vendorProductRate,
    required this.priceDifference,
    required this.stocks,
  });

  factory SpotRateItem.fromJson(Map<String, dynamic> json) {
    final List<SpotStockItem> stockList = [];
    if (json['stocks'] is List) {
      for (var s in json['stocks']) {
        if (s is Map<String, dynamic>) {
          stockList.add(SpotStockItem.fromJson(s));
        } else if (s is Map) {
          stockList.add(SpotStockItem.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    String? parsedMobile = json['vendor_mobile']?.toString().trim();
    if (parsedMobile != null && (parsedMobile.toLowerCase() == 'null' || parsedMobile.isEmpty)) {
      parsedMobile = null;
    }

    String heading = (json['vendor_spot_heading'] ?? json['vendor_product'] ?? json['news_heading'] ?? '').toString();
    String details = (json['vendor_spot_details'] ?? json['vendor_product_size'] ?? json['news_details'] ?? '').toString();
    String dateStr = (json['vendor_spot_created_date'] ?? json['vendor_product_created_date'] ?? json['news_created_date'] ?? '').toString();
    String timeStr = (json['vendor_spot_created_time'] ?? json['vendor_product_created_time'] ?? json['news_created_time'] ?? '').toString();
    String statusStr = (json['vendor_spot_status'] ?? json['vendor_product_status'] ?? json['news_status'] ?? 'Active').toString();
    String rateStr = (json['vendor_product_rate'] ?? json['rate'] ?? '').toString();

    String diff = (json['price_difference'] ?? json['diff'] ?? '').toString();

    return SpotRateItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      categoriesName: (json['categories_name'] ?? '').toString(),
      subCategoryId: int.tryParse(json['sub_category_id']?.toString() ?? '0') ?? 0,
      subCategoriesName: (json['sub_categories_name'] ?? '').toString(),
      vendorId: int.tryParse((json['vendor_id'] ?? json['id'] ?? '0').toString()) ?? 0,
      vendorName: (json['vendor_name'] ?? heading ?? 'Vendor Spot').toString(),
      vendorImage: (json['vendor_image'] ?? json['news_image'])?.toString(),
      vendorMobile: parsedMobile,
      vendorSpotHeading: heading,
      vendorSpotDetails: details,
      vendorSpotCreatedDate: dateStr,
      vendorSpotCreatedTime: timeStr,
      vendorSpotStatus: statusStr,
      vendorProductRate: rateStr,
      priceDifference: diff,
      stocks: stockList,
    );
  }

  bool get hasValidVendorMobile =>
      vendorMobile != null &&
      vendorMobile!.trim().isNotEmpty &&
      vendorMobile!.trim().toLowerCase() != 'null';

  DateTime get dateTime {
    try {
      final d = vendorSpotCreatedDate.trim();
      final t = vendorSpotCreatedTime.trim();
      if (d.isNotEmpty) {
        if (t.isNotEmpty) {
          return DateTime.parse('$d $t');
        }
        return DateTime.parse(d);
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class SpotStockItem {
  final int id;
  final String rate;
  final String date;
  final String time;

  SpotStockItem({
    required this.id,
    required this.rate,
    required this.date,
    required this.time,
  });

  factory SpotStockItem.fromJson(Map<String, dynamic> json) {
    return SpotStockItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      rate: (json['vendor_product_rate'] ?? json['rate'] ?? '0.00').toString(),
      date: (json['vendor_product_created_date'] ?? json['date'] ?? '').toString(),
      time: (json['vendor_product_created_time'] ?? json['time'] ?? '').toString(),
    );
  }
}
