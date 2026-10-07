import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable cached network image widget across all pages.
/// Prevents re-downloading images continuously, uses local disk & memory cache.
class AppCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Alignment alignment;

  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    return CachedNetworkImage(
      imageUrl: trimmedUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A4B26)),
                ),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Center(
        child: Image.asset(
          'assets/image/km.png',
          width: 48,
          height: 48,
          errorBuilder: (context, e, st) => const Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
            size: 32,
          ),
        ),
      ),
    );
  }
}
