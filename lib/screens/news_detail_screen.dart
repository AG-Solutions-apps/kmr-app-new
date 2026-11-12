import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_model.dart';
import '../core/widgets/app_snackbar.dart';
import '../core/utils/date_formatter.dart';
import '../widgets/app_cached_network_image.dart';

/// Screen displaying full details for a selected Commodity News item,
/// including Hero Image, Date Badge, Rich Heading & Description,
/// and View Attachment (PDF / Image) handling for news_other_image.
class NewsDetailScreen extends StatelessWidget {
  final NewsItem newsItem;
  final String categoryName;
  final NewsResponse newsResponse;

  const NewsDetailScreen({
    super.key,
    required this.newsItem,
    required this.categoryName,
    required this.newsResponse,
  });

  /// Original image preview dialog without zoom for the main news image.
  void _showOriginalImagePreview(BuildContext context, String imageUrl) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppCachedNetworkImage(
                imageUrl: cleanUrl,
                fit: BoxFit.contain,
                errorWidget: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: const Text('Failed to load image preview'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-screen zoom viewer for news other attachments.
  Future<void> _handleOpenAttachment(
    BuildContext context,
    String attachmentUrl, {
    String title = 'Attachment Image',
  }) async {
    final cleanUrl = attachmentUrl.trim();
    if (cleanUrl.isEmpty) return;

    final lower = cleanUrl.toLowerCase();
    final bool isPdf = lower.endsWith('.pdf') || lower.contains('.pdf');

    if (!isPdf) {
      // Show full-screen zoomable interactive image viewer
      showDialog(
        context: context,
        useSafeArea: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        builder: (context) => ZoomableImageViewerDialog(
          imageUrl: cleanUrl,
          title: title,
        ),
      );
    } else {
      // PDF or general document: launch URL
      final Uri uri = Uri.parse(cleanUrl);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to inAppBrowserView
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            title: 'Attachment Error',
            message: 'Unable to open attachment: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fullImgUrl = newsResponse.getFullNewsImageUrl(newsItem);
    final String? otherAttachmentUrl = newsResponse.getFullOtherAttachmentUrl(newsItem);
    final bool isPdf = otherAttachmentUrl != null &&
        (otherAttachmentUrl.toLowerCase().endsWith('.pdf') || otherAttachmentUrl.toLowerCase().contains('.pdf'));

    final titleCategory = newsItem.categoriesName.isNotEmpty ? newsItem.categoriesName : categoryName;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A3B73), Color(0xFF155799)],
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
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
                  Expanded(
                    child: Text(
                      '$titleCategory (News)',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      AppSnackBar.showInfo(
                        context,
                        title: 'Search',
                        message: 'Searching news in $titleCategory',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Adaptive Hero Image Container (Adapts naturally to Landscape or Portrait images)
            GestureDetector(
              onTap: () => _showOriginalImagePreview(context, fullImgUrl),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 180,
                  maxHeight: 480,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD0E1F4), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AppCachedNetworkImage(
                    imageUrl: fullImgUrl,
                    fit: BoxFit.contain,
                    errorWidget: Container(
                      height: 200,
                      color: const Color(0xFFD0E1F4),
                      child: const Center(
                        child: Icon(
                          Icons.newspaper_rounded,
                          size: 60,
                          color: Color(0xFF0A3B73),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Date Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Color(0xFF0A3B73),
                ),
                const SizedBox(width: 6),
                Text(
                  AppDateFormatter.format(newsItem.newsCreatedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A3B73),
                  ),
                ),
                if (newsItem.newsCreatedTime.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF0A3B73),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    newsItem.newsCreatedTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A3B73),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Main Details Content Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD0E1F4), width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading Title
                  Text(
                    newsItem.newsHeading,
                    style: const TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF061E36),
                      height: 1.3,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFEBF3FA), height: 1, thickness: 1.2),
                  const SizedBox(height: 14),

                  // Details Body Text
                  Text(
                    newsItem.newsDetails,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                      height: 1.6,
                    ),
                  ),

                  // Attachment Button for news_other_image if present
                  if (otherAttachmentUrl != null) ...[
                    const SizedBox(height: 22),
                    const Divider(color: Color(0xFFEBF3FA), height: 1),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleOpenAttachment(
                          context,
                          otherAttachmentUrl,
                          title: isPdf
                              ? 'News Document (PDF)'
                              : (newsItem.newsHeading.isNotEmpty
                                  ? '${newsItem.newsHeading} - Attachment'
                                  : 'Attachment Image'),
                        ),
                        icon: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.zoom_in_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isPdf ? 'View Document (PDF)' : 'View & Zoom Attachment Image',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A3B73),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// Full-screen zoomable interactive viewer dialog for news images and attachments.
/// Supports pinch-to-zoom, pan, double-tap to zoom, and on-screen zoom control buttons.
class ZoomableImageViewerDialog extends StatefulWidget {
  final String imageUrl;
  final String title;

  const ZoomableImageViewerDialog({
    super.key,
    required this.imageUrl,
    this.title = 'Attachment Preview',
  });

  @override
  State<ZoomableImageViewerDialog> createState() => _ZoomableImageViewerDialogState();
}

class _ZoomableImageViewerDialogState extends State<ZoomableImageViewerDialog>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;

  double _currentScale = 1.0;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.04) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0);
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale + 0.6).clamp(1.0, 6.0);
    _animateToMatrix(Matrix4.diagonal3Values(newScale, newScale, 1.0));
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale - 0.6).clamp(1.0, 6.0);
    _animateToMatrix(Matrix4.diagonal3Values(newScale, newScale, 1.0));
  }

  void _resetZoom() {
    _animateToMatrix(Matrix4.identity());
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.2) {
      _resetZoom();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 2.5;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);
      final zoomedMatrix = Matrix4.identity()
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale)
        ..setEntry(0, 3, x)
        ..setEntry(1, 3, y);
      _animateToMatrix(zoomedMatrix);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Zoom & Pan Area
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 6.0,
                  boundaryMargin: const EdgeInsets.all(120),
                  clipBehavior: Clip.none,
                  child: Center(
                    child: AppCachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: Container(
                        padding: const EdgeInsets.all(28),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 50, color: Colors.white54),
                            SizedBox(height: 12),
                            Text(
                              'Failed to load image preview',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Bar: Title & Close Button
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Bar: Floating Zoom Controls
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtle guide hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pinch or double-tap to zoom • Pan to explore',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Control Buttons Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A3B73).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom Out Button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 24),
                          tooltip: 'Zoom Out',
                          onPressed: _zoomOut,
                        ),
                        const SizedBox(width: 4),
                        // Scale / Reset Button
                        InkWell(
                          onTap: _resetZoom,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${(_currentScale * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Zoom In Button
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 24),
                          tooltip: 'Zoom In',
                          onPressed: _zoomIn,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
