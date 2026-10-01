library;

/// Models for Live Rates & Category Data

class LiveRateResponse {
  final List<SubCategoryItem> subCategories;
  final List<LiveRateItem> data;
  final String noImageUrl;
  final String vendorImageUrl;

  LiveRateResponse({
    required this.subCategories,
    required this.data,
    required this.noImageUrl,
    required this.vendorImageUrl,
  });

  factory LiveRateResponse.fromJson(Map<String, dynamic> json) {
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

    // Parse data (vendor products)
    final List<LiveRateItem> items = [];
    if (json['data'] is List) {
      for (var item in json['data']) {
        if (item is Map<String, dynamic>) {
          items.add(LiveRateItem.fromJson(item));
        } else if (item is Map) {
          items.add(LiveRateItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Parse image_url
    String noImg = 'https://kmrlive.in/crmapi/public/assets/images/no_image.jpg';
    String vendorImg = 'https://kmrlive.in/crmapi/public/assets/images/vendor_images/';

    if (json['image_url'] is List) {
      for (var imgObj in json['image_url']) {
        if (imgObj is Map) {
          final String forVal = imgObj['image_for']?.toString() ?? '';
          final String urlVal = imgObj['image_url']?.toString() ?? '';
          if (forVal.toLowerCase().contains('no image') && urlVal.isNotEmpty) {
            noImg = urlVal;
          } else if (forVal.toLowerCase().contains('vendor') && urlVal.isNotEmpty) {
            vendorImg = urlVal;
          }
        }
      }
    }

    return LiveRateResponse(
      subCategories: subs,
      data: items,
      noImageUrl: noImg,
      vendorImageUrl: vendorImg,
    );
  }

  String getFullVendorImageUrl(LiveRateItem item) {
    if (item.vendorImage != null && item.vendorImage!.trim().isNotEmpty) {
      final img = item.vendorImage!.trim();
      if (img.startsWith('http://') || img.startsWith('https://')) {
        return img;
      }
      return vendorImageUrl.endsWith('/') ? '$vendorImageUrl$img' : '$vendorImageUrl/$img';
    }
    return noImageUrl;
  }
}

class SubCategoryItem {
  final int id;
  final String name;

  SubCategoryItem({
    required this.id,
    required this.name,
  });

  factory SubCategoryItem.fromJson(Map<String, dynamic> json) {
    return SubCategoryItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: (json['categories_name'] ?? json['sub_categories_name'] ?? json['name'] ?? '').toString(),
    );
  }
}

class LiveRateItem {
  final int id;
  final int vendorId;
  final String vendorName;
  final String? vendorImage;
  final String? vendorMobile;
  final int categoryId;
  final String categoriesName;
  final int subCategoryId;
  final String subCategoriesName;
  final String vendorProduct;
  final String vendorProductSize;
  final String vendorProductRate;
  final String vendorProductCreatedDate;
  final String vendorProductCreatedTime;
  final String vendorProductStatus;
  final List<LiveStockItem> stocks;

  LiveRateItem({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.vendorImage,
    this.vendorMobile,
    required this.categoryId,
    required this.categoriesName,
    required this.subCategoryId,
    required this.subCategoriesName,
    required this.vendorProduct,
    required this.vendorProductSize,
    required this.vendorProductRate,
    required this.vendorProductCreatedDate,
    required this.vendorProductCreatedTime,
    required this.vendorProductStatus,
    required this.stocks,
  });

  bool get hasValidVendorMobile =>
      vendorMobile != null &&
      vendorMobile!.trim().isNotEmpty &&
      vendorMobile!.trim().toLowerCase() != 'null';

  factory LiveRateItem.fromJson(Map<String, dynamic> json) {
    final List<LiveStockItem> stockList = [];
    if (json['stocks'] is List) {
      for (var s in json['stocks']) {
        if (s is Map<String, dynamic>) {
          stockList.add(LiveStockItem.fromJson(s));
        } else if (s is Map) {
          stockList.add(LiveStockItem.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    String? parsedMobile = json['vendor_mobile']?.toString().trim();
    if (parsedMobile != null && (parsedMobile.toLowerCase() == 'null' || parsedMobile.isEmpty)) {
      parsedMobile = null;
    }

    return LiveRateItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorId: int.tryParse(json['vendor_id']?.toString() ?? '0') ?? 0,
      vendorName: (json['vendor_name'] ?? 'Vendor').toString(),
      vendorImage: json['vendor_image']?.toString(),
      vendorMobile: parsedMobile,
      categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      categoriesName: (json['categories_name'] ?? '').toString(),
      subCategoryId: int.tryParse(json['sub_category_id']?.toString() ?? '0') ?? 0,
      subCategoriesName: (json['sub_categories_name'] ?? '').toString(),
      vendorProduct: (json['vendor_product'] ?? '').toString(),
      vendorProductSize: (json['vendor_product_size'] ?? '').toString(),
      vendorProductRate: (json['vendor_product_rate'] ?? '0.00').toString(),
      vendorProductCreatedDate: (json['vendor_product_created_date'] ?? '').toString(),
      vendorProductCreatedTime: (json['vendor_product_created_time'] ?? '').toString(),
      vendorProductStatus: (json['vendor_product_status'] ?? 'Active').toString(),
      stocks: stockList,
    );
  }

  /// Calculates the price difference string (e.g. "+(-10.0)", "+(0.0)", "+(15.0)")
  String get priceDifference {
    final double currentPrice = double.tryParse(vendorProductRate) ?? 0.0;
    if (stocks.isNotEmpty) {
      final double prevPrice = double.tryParse(stocks.first.rate) ?? currentPrice;
      final double diff = currentPrice - prevPrice;
      if (diff < 0) {
        return '+(${diff.toStringAsFixed(1)})';
      } else if (diff > 0) {
        return '+(${diff.toStringAsFixed(1)})';
      }
    }
    return '+(0.0)';
  }
}

class LiveStockItem {
  final int id;
  final int vendorProductId;
  final String rate;
  final String date;
  final String time;
  final String vendorProduct;
  final String vendorProductSize;

  LiveStockItem({
    required this.id,
    required this.vendorProductId,
    required this.rate,
    required this.date,
    required this.time,
    required this.vendorProduct,
    required this.vendorProductSize,
  });

  factory LiveStockItem.fromJson(Map<String, dynamic> json) {
    return LiveStockItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorProductId: int.tryParse(json['vendor_product_id']?.toString() ?? '0') ?? 0,
      rate: (json['vendor_product_rate'] ?? '0.00').toString(),
      date: (json['vendor_product_created_date'] ?? '').toString(),
      time: (json['vendor_product_created_time'] ?? '').toString(),
      vendorProduct: (json['vendor_product'] ?? '').toString(),
      vendorProductSize: (json['vendor_product_size'] ?? '').toString(),
    );
  }
}

