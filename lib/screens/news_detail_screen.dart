import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_model.dart';
import '../core/widgets/app_snackbar.dart';
import '../core/utils/date_formatter.dart';

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

  Future<void> _handleOpenAttachment(BuildContext context, String attachmentUrl) async {
    final cleanUrl = attachmentUrl.trim();
    final isImage = cleanUrl.toLowerCase().endsWith('.jpg') ||
        cleanUrl.toLowerCase().endsWith('.jpeg') ||
        cleanUrl.toLowerCase().endsWith('.png') ||
        cleanUrl.toLowerCase().endsWith('.webp');

    if (isImage) {
      // Show Image preview dialog
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
                child: Image.network(
                  cleanUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
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
              onTap: () => _handleOpenAttachment(context, fullImgUrl),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 180,
                  maxHeight: 480,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEFAF2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDEDE4), width: 1),
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
                  child: Image.network(
                    fullImgUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 220,
                        color: const Color(0xFFDCF2E5),
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF1B7A44)),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: const Color(0xFFDCF2E5),
                      child: const Center(
                        child: Icon(
                          Icons.newspaper_rounded,
                          size: 60,
                          color: Color(0xFF1B7A44),
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
                  color: Color(0xFF1B7A44),
                ),
                const SizedBox(width: 6),
                Text(
                  AppDateFormatter.format(newsItem.newsCreatedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B7A44),
                  ),
                ),
                if (newsItem.newsCreatedTime.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF1B7A44),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    newsItem.newsCreatedTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B7A44),
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
                border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
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
                      color: Color(0xFF0C3A20),
                      height: 1.3,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFEEFAF2), height: 1, thickness: 1.2),
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
                    const Divider(color: Color(0xFFEEFAF2), height: 1),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleOpenAttachment(context, otherAttachmentUrl),
                        icon: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isPdf ? 'View Document (PDF)' : 'View Attachment Image',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B7A44),
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
