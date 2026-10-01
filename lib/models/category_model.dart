/// Data model for individual category items returned by the API.
class CategoryItem {
  final int id;
  final String name;
  final String image;

  CategoryItem({
    required this.id,
    required this.name,
    required this.image,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['categories_name']?.toString() ?? '',
      image: json['categories_image']?.toString() ?? '',
    );
  }
}

/// Data model wrapping the categories API response.
class CategoryResponse {
  final List<CategoryItem> data;
  final String categoryBaseUrl;
  final String noImageUrl;

  CategoryResponse({
    required this.data,
    required this.categoryBaseUrl,
    required this.noImageUrl,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    List<CategoryItem> categories = [];
    if (json['data'] is List) {
      categories = (json['data'] as List)
          .map((item) => CategoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    String catBase = 'https://kmrlive.in/crmapi/public/assets/images/category_images/';
    String noImg = 'https://kmrlive.in/crmapi/public/assets/images/no_image.jpg';

    if (json['image_url'] is List) {
      for (var imgObj in json['image_url']) {
        if (imgObj is Map<String, dynamic>) {
          final imageFor = imgObj['image_for']?.toString();
          final url = imgObj['image_url']?.toString();
          if (imageFor == 'Category' && url != null && url.isNotEmpty) {
            catBase = url;
          } else if (imageFor == 'No Image' && url != null && url.isNotEmpty) {
            noImg = url;
          }
        }
      }
    }

    return CategoryResponse(
      data: categories,
      categoryBaseUrl: catBase,
      noImageUrl: noImg,
    );
  }

  /// Construct complete image URL for a given CategoryItem safely with URI encoding for filenames with spaces.
  String getFullImageUrl(CategoryItem category) {
    if (category.image.isEmpty) return noImageUrl;
    
    // Ensure base URL ends with a slash if category.image does not start with one
    String base = categoryBaseUrl;
    if (!base.endsWith('/') && !category.image.startsWith('/')) {
      base = '$base/';
    }
    
    final fullPath = '$base${category.image}';
    return Uri.encodeFull(fullPath);
  }
}
