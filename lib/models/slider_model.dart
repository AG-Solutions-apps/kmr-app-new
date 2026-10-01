/// Data model for individual slider item returned by app-home-slider API
class SliderItem {
  final int id;
  final String image;
  final String? url;

  SliderItem({
    required this.id,
    required this.image,
    this.url,
  });

  factory SliderItem.fromJson(Map<String, dynamic> json) {
    return SliderItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      image: json['slider_image']?.toString() ?? '',
      url: (json['slider_url'] != null && json['slider_url'].toString().trim().isNotEmpty)
          ? json['slider_url'].toString().trim()
          : null,
    );
  }
}

/// Data model wrapping the app-home-slider API response.
class SliderResponse {
  final List<SliderItem> data;
  final String sliderBaseUrl;
  final String noImageUrl;

  SliderResponse({
    required this.data,
    required this.sliderBaseUrl,
    required this.noImageUrl,
  });

  factory SliderResponse.fromJson(Map<String, dynamic> json) {
    List<SliderItem> sliders = [];
    if (json['data'] is List) {
      sliders = (json['data'] as List)
          .map((item) => SliderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    String sliderBase = 'https://kmrlive.in/crmapi/public/assets/images/slider_images/';
    String noImg = 'https://kmrlive.in/crmapi/public/assets/images/no_image.jpg';

    if (json['image_url'] is List) {
      for (var imgObj in json['image_url']) {
        if (imgObj is Map<String, dynamic>) {
          final imageFor = imgObj['image_for']?.toString();
          final url = imgObj['image_url']?.toString();
          if (imageFor == 'Slider' && url != null && url.isNotEmpty) {
            sliderBase = url;
          } else if (imageFor == 'No Image' && url != null && url.isNotEmpty) {
            noImg = url;
          }
        }
      }
    }

    return SliderResponse(
      data: sliders,
      sliderBaseUrl: sliderBase,
      noImageUrl: noImg,
    );
  }

  /// Construct complete image URL safely with URI encoding for filenames
  String getFullImageUrl(SliderItem slider) {
    if (slider.image.isEmpty) return noImageUrl;

    String base = sliderBaseUrl;
    if (!base.endsWith('/') && !slider.image.startsWith('/')) {
      base = '$base/';
    }

    final fullPath = '$base${slider.image}';
    return Uri.encodeFull(fullPath);
  }
}
