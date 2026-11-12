import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category_model.dart';
import '../models/live_rate_model.dart';
import '../models/slider_model.dart';
import '../models/spot_rate_model.dart';
import '../models/news_model.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../core/widgets/app_snackbar.dart';
import '../core/utils/date_formatter.dart';
import '../widgets/app_cached_network_image.dart';
import '../widgets/spot_details_widget.dart';
import 'news_detail_screen.dart';

/// Screen displaying Category Commodity Rates supporting both 'Live' and 'Rates' modes,
/// Category Sliders, Subcategory filters, Price History dialogs, Full Rate Lists,
/// and Floating Pill Bottom Navigation matching the reference UI designs.
class CategoryDetailScreen extends StatefulWidget {
  final CategoryItem category;

  const CategoryDetailScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late Future<LiveRateResponse> _liveRatesFuture;
  late Future<LiveRateResponse> _ratesFuture;
  late Future<SpotRateResponse> _spotRatesFuture;
  late Future<NewsResponse> _newsFuture;
  late Future<SliderResponse> _categorySlidersFuture;

  int? _selectedSubCategoryId; // null = 'All'
  int _activeBottomTab = 0; // 0: Live, 1: Rates, 2: Spot, 3: News

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTabName(int index) {
    switch (index) {
      case 0:
        return 'Live Rates';
      case 1:
        return 'Rates';
      case 2:
        return 'Spot';
      case 3:
        return 'News';
      default:
        return 'Live Rates';
    }
  }

  void _loadData({bool forceRefresh = false}) {
    setState(() {
      _liveRatesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppLive(widget.category.id, token: token);
      });
      _ratesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppRate(widget.category.id, token: token);
      });
      _spotRatesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppSpot(widget.category.id, token: token, forceRefresh: forceRefresh);
      });
      _newsFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppNews(widget.category.id, token: token);
      });
      _categorySlidersFuture = SessionService.getToken().then((token) {
        return ApiService().fetchCategorySliders(widget.category.id, token: token);
      });
    });
  }

  List<Map<String, String>> _getVendorRateRows(LiveRateItem item) {
    return [
      {
        'brand': item.vendorProduct.isNotEmpty ? item.vendorProduct : 'N/A',
        'qty': item.vendorProductSize.isNotEmpty ? item.vendorProductSize : 'N/A',
        'rate': item.vendorProductRate,
      },
    ];
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          AppSnackBar.showInfo(context, title: 'Call', message: 'Calling $phoneNumber');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, title: 'Call Error', message: '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: _isSearching
                  ? Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: const TextStyle(
                                      color: Color(0xFF0A3B73),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    cursorColor: const Color(0xFF0A3B73),
                                    cursorWidth: 2.0,
                                    decoration: InputDecoration(
                                      hintText: 'Search ${_getTabName(_activeBottomTab)}...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _searchQuery = val.trim().toLowerCase();
                                      });
                                    },
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _searchController.clear();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE2E8F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFF64748B),
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
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
                            widget.category.name,
                            style: const TextStyle(
                              fontSize: 20,
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
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0A3B73),
          backgroundColor: Colors.white,
          strokeWidth: 2.5,
          onRefresh: () async {
            _loadData(forceRefresh: true);
            await Future.wait([_liveRatesFuture, _ratesFuture, _spotRatesFuture, _newsFuture, _categorySlidersFuture]);
          },
          child: _buildBodyContent(),
        ),
      ),
      bottomNavigationBar: _buildBottomPillNavBar(),
    );
  }

  Widget _buildBodyContent() {
    return IndexedStack(
      index: _activeBottomTab,
      children: [
        _buildTabDataView(_liveRatesFuture, isLiveTab: true),
        _buildTabDataView(_ratesFuture, isLiveTab: false),
        _buildSpotTabDataView(),
        _buildNewsTabDataView(),
      ],
    );
  }

  Widget _buildTabDataView(Future<LiveRateResponse> future, {required bool isLiveTab}) {
    return FutureBuilder<LiveRateResponse>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final rateData = snapshot.data;
        final allItems = rateData?.data ?? [];

        final subFiltered = _selectedSubCategoryId == null
            ? allItems
            : allItems.where((item) => item.subCategoryId == _selectedSubCategoryId).toList();

        final filteredItems = _searchQuery.isEmpty
            ? subFiltered
            : subFiltered.where((item) {
                final q = _searchQuery;
                final vendor = item.vendorName.toLowerCase();
                final prod = item.vendorProduct.toLowerCase();
                final size = item.vendorProductSize.toLowerCase();
                final rate = item.vendorProductRate.toLowerCase();

                final rows = _getVendorRateRows(item);
                final rowMatch = rows.any((r) =>
                    r['brand']!.toLowerCase().contains(q) ||
                    r['qty']!.toLowerCase().contains(q) ||
                    r['rate']!.toLowerCase().contains(q));

                return vendor.contains(q) || prod.contains(q) || size.contains(q) || rate.contains(q) || rowMatch;
              }).toList();

        final Map<String, List<LiveRateItem>> ratesVendorGroupsMap = {};
        if (!isLiveTab) {
          for (var item in filteredItems) {
            final key = item.vendorId != 0 ? '${item.vendorId}' : item.vendorName;
            ratesVendorGroupsMap.putIfAbsent(key, () => []).add(item);
          }
        }
        final ratesVendorGroupsList = ratesVendorGroupsMap.values.toList();

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: _buildCategoryBannerSlider(),
              ),
              const SizedBox(height: 14),
              if (rateData != null && rateData.subCategories.isNotEmpty)
                _buildSubCategoryChips(rateData.subCategories),
              const SizedBox(height: 14),
              if (filteredItems.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  itemCount: isLiveTab ? filteredItems.length : ratesVendorGroupsList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return isLiveTab
                        ? _buildLiveProductRateCard(filteredItems[index], rateData!)
                        : _buildRatesVendorGroupCard(ratesVendorGroupsList[index], rateData!);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryBannerSlider() {
    return _CategoryBannerSlider(slidersFuture: _categorySlidersFuture);
  }

  Widget _buildSubCategoryChips(List<SubCategoryItem> subs) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: subs.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSubCategoryId == null;
            return ChoiceChip(
              label: const Text('All'),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedSubCategoryId = null;
                });
              },
              selectedColor: const Color(0xFF0A3B73),
              backgroundColor: const Color(0xFFEBF3FA),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF0A3B73),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0A3B73) : const Color(0xFFD0E1F4),
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            );
          }

          final sub = subs[index - 1];
          final isSelected = _selectedSubCategoryId == sub.id;

          return ChoiceChip(
            label: Text(sub.name),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedSubCategoryId = isSelected ? null : sub.id;
              });
            },
            selectedColor: const Color(0xFF0A3B73),
            backgroundColor: const Color(0xFFEBF3FA),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF0A3B73),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? const Color(0xFF0A3B73) : const Color(0xFFD0E1F4),
              ),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          );
        },
      ),
    );
  }

  Widget _buildLiveProductRateCard(LiveRateItem item, LiveRateResponse liveData) {
    final imgUrl = liveData.getFullVendorImageUrl(item);
    final diff = item.priceDifference;
    final isNegative = diff.contains('-');
    final isPositive = diff.contains('+');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0E1F4), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 85,
                height: 85,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppCachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.contain,
                      errorWidget: Container(
                        width: 85,
                        height: 85,
                        color: const Color(0xFFEBF3FA),
                        child: const Center(
                          child: Icon(Icons.opacity_rounded, color: Color(0xFF0A3B73), size: 36),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vendor Name: Full width so complete string is displayed; wraps to next line if needed
                    Text(
                      item.vendorName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF061E36),
                        height: 1.25,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    // Product & Size on the left, Price Pill neatly arranged on the right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.vendorProduct.isNotEmpty)
                                Text(
                                  item.vendorProduct,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                  softWrap: true,
                                ),
                              if (item.vendorProductSize.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.vendorProductSize,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF3FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD0E1F4), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\u20b9 ${item.vendorProductRate}' + (diff.isNotEmpty ? ' ' : ''),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0A3B73),
                                ),
                              ),
                              if (diff.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  diff,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isNegative
                                        ? const Color(0xFFE53935)
                                        : (isPositive
                                            ? const Color(0xFF00A854)
                                            : const Color(0xFF0A3B73)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEBF3FA)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF0A3B73)),
                  const SizedBox(width: 4),
                  Text(
                    AppDateFormatter.format(item.vendorProductCreatedDate),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0A3B73)),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF0A3B73)),
                  const SizedBox(width: 4),
                  Text(
                    item.vendorProductCreatedTime,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0A3B73)),
                  ),
                ],
              ),
              if (item.stocks.isNotEmpty)
                InkWell(
                  onTap: () => _showLivePriceHistoryDialog(context, item, liveData),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'View More',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A3B73),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0A3B73)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatesVendorGroupCard(List<LiveRateItem> groupItems, LiveRateResponse rateData) {
    if (groupItems.isEmpty) return const SizedBox.shrink();

    final firstItem = groupItems.first;
    final imgUrl = rateData.getFullVendorImageUrl(firstItem);
    final bool showViewMore = groupItems.length > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E1F4), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppCachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.contain,
                      errorWidget: Container(
                        width: 76,
                        height: 76,
                        color: const Color(0xFFEBF3FA),
                        child: const Center(
                          child: Icon(Icons.business_rounded, color: Color(0xFF0A3B73), size: 36),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstItem.vendorName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF061E36),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0A3B73)),
                        const SizedBox(width: 4),
                        Text(
                          AppDateFormatter.format(firstItem.vendorProductCreatedDate),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                        ),
                        const SizedBox(width: 8),
                        const Text('|', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF0A3B73)),
                        const SizedBox(width: 4),
                        Text(
                          firstItem.vendorProductCreatedTime,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (firstItem.hasValidVendorMobile)
                InkWell(
                  onTap: () => _makePhoneCall(firstItem.vendorMobile!),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEBF3FA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Color(0xFF0A3B73),
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBF3FA)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF3FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'BRAND',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'QUANTITY',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Min/Max (+/-)',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showViewMore) ...[
                  Container(
                    height: 75,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        children: groupItems.take(2).map((item) {
                          return _buildRateTableRow(
                            brand: item.vendorProduct.isNotEmpty ? item.vendorProduct : 'N/A',
                            qty: item.vendorProductSize.isNotEmpty ? item.vendorProductSize : 'N/A',
                            rate: item.vendorProductRate,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ] else ...[
                  _buildRateTableRow(
                    brand: firstItem.vendorProduct.isNotEmpty ? firstItem.vendorProduct : 'N/A',
                    qty: firstItem.vendorProductSize.isNotEmpty ? firstItem.vendorProductSize : 'N/A',
                    rate: firstItem.vendorProductRate,
                  ),
                ],
              ],
            ),
          ),
          if (showViewMore) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _showRatesDetailDialog(context, groupItems, rateData),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View More',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A3B73),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0A3B73)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateTableRow({required String brand, required String qty, required String rate}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              brand,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4A5568)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '₹ $rate',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0A3B73),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatesDetailDialog(BuildContext context, List<LiveRateItem> groupItems, LiveRateResponse rateData) {
    if (groupItems.isEmpty) return;
    final firstItem = groupItems.first;
    final imgUrl = rateData.getFullVendorImageUrl(firstItem);

    final List<LiveStockItem> allStocks = [];
    for (var item in groupItems) {
      allStocks.addAll(item.stocks);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEBF3FA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF0A3B73)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AppCachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.contain,
                              errorWidget: Container(
                                width: 90,
                                height: 90,
                                color: const Color(0xFFEBF3FA),
                                child: const Icon(Icons.business_rounded, size: 40, color: Color(0xFF0A3B73)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstItem.vendorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF061E36),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0A3B73)),
                                const SizedBox(width: 4),
                                Text(
                                  AppDateFormatter.format(firstItem.vendorProductCreatedDate),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                ),
                                const SizedBox(width: 6),
                                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                const SizedBox(width: 6),
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF0A3B73)),
                                const SizedBox(width: 4),
                                Text(
                                  firstItem.vendorProductCreatedTime,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (firstItem.hasValidVendorMobile)
                        InkWell(
                          onTap: () => _makePhoneCall(firstItem.vendorMobile!),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEBF3FA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              color: Color(0xFF0A3B73),
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD0E1F4)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEBF3FA),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'BRAND',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'QUANTITY',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Min/Max (₹)',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEBF3FA)),
                          itemBuilder: (context, idx) {
                            final item = groupItems[idx];
                            return _buildRateTableRow(
                              brand: item.vendorProduct.isNotEmpty ? item.vendorProduct : 'N/A',
                              qty: item.vendorProductSize.isNotEmpty ? item.vendorProductSize : 'N/A',
                              rate: item.vendorProductRate,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (allStocks.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Rate History',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF061E36),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD0E1F4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEBF3FA),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'BRAND / QTY',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'DATE & TIME',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'RATE (₹)',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: allStocks.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEBF3FA)),
                            itemBuilder: (context, idx) {
                              final stock = allStocks[idx];
                              final brand = stock.vendorProduct.isNotEmpty ? stock.vendorProduct : firstItem.vendorProduct;
                              final qty = stock.vendorProductSize.isNotEmpty ? stock.vendorProductSize : firstItem.vendorProductSize;
                              final brandQtyText = (qty.isNotEmpty && qty != 'N/A') ? '$brand ($qty)' : brand;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        brandQtyText,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${AppDateFormatter.format(stock.date)}\n${stock.time}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEBF3FA),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹ ${stock.rate}',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0A3B73),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLivePriceHistoryDialog(BuildContext context, LiveRateItem item, LiveRateResponse liveData) {
    final imgUrl = liveData.getFullVendorImageUrl(item);
    final diff = item.priceDifference;
    final isNegative = diff.contains('-');
    final isPositive = diff.contains('+');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEBF3FA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF0A3B73)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AppCachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.contain,
                              errorWidget: Container(
                                width: 100,
                                height: 100,
                                color: const Color(0xFFEBF3FA),
                                child: const Icon(Icons.opacity_rounded, size: 40, color: Color(0xFF0A3B73)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.vendorName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF061E36),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.vendorProduct,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (item.vendorProductSize.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF3FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.vendorProductSize,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A3B73),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD0E1F4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Price',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '₹ ${item.vendorProductRate}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0A3B73),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    diff,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isNegative
                                          ? const Color(0xFFE53935)
                                          : (isPositive
                                              ? const Color(0xFF00A854)
                                              : const Color(0xFF0A3B73)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF0A3B73)),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.vendorProductCreatedDate,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0A3B73)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF0A3B73)),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.vendorProductCreatedTime,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0A3B73)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _LivePriceSparklineCard(item: item),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Color(0xFF0A3B73), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Price History',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF061E36),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (item.stocks.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'No previous stock history recorded.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD0E1F4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEBF3FA),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Date',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Time',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Price (₹)',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '+ / -',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF061E36)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: item.stocks.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEBF3FA)),
                            itemBuilder: (context, idx) {
                              final stock = item.stocks[idx];

                              // Calculate difference against immediate previous historical stock
                              final double currentRate = double.tryParse(stock.rate) ?? 0.0;
                              double diff = 0.0;
                              if (idx + 1 < item.stocks.length) {
                                final double prevRate = double.tryParse(item.stocks[idx + 1].rate) ?? currentRate;
                                diff = currentRate - prevRate;
                              }

                              final bool isUp = diff > 0;
                              final bool isDown = diff < 0;
                              final Color diffColor = isDown
                                  ? const Color(0xFFE53935)
                                  : (isUp
                                      ? const Color(0xFF00A854)
                                      : const Color(0xFF64748B));

                              final String diffText;
                              if (diff == 0.0) {
                                diffText = '0';
                              } else {
                                final absDiff = diff.abs();
                                final String numStr = (absDiff.truncateToDouble() == absDiff)
                                    ? absDiff.toInt().toString()
                                    : absDiff.toStringAsFixed(1);
                                diffText = isUp ? '+$numStr' : '-$numStr';
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        stock.date,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        stock.time,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        stock.rate,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF061E36),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        diffText,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: diffColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPillNavBar() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A3B73), Color(0xFF155799)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A3B73).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.bar_chart_rounded, 'Live'),
            _navItem(1, Icons.sell_outlined, 'Rates'),
            _navItem(2, Icons.grid_view_rounded, 'Spot'),
            _navItem(3, Icons.newspaper_rounded, 'News'),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotTabDataView() {
    return FutureBuilder<SpotRateResponse>(
      future: _spotRatesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final spotData = snapshot.data;
        final allItems = spotData?.data ?? [];

        final subFiltered = _selectedSubCategoryId == null
            ? allItems
            : allItems.where((item) => item.subCategoryId == _selectedSubCategoryId).toList();

        final filteredItems = _searchQuery.isEmpty
            ? subFiltered
            : subFiltered.where((item) {
                final q = _searchQuery;
                final vendor = item.vendorName.toLowerCase();
                final heading = item.vendorSpotHeading.toLowerCase();
                final details = item.vendorSpotDetails.toLowerCase();
                final rate = item.vendorProductRate.toLowerCase();
                final date = item.vendorSpotCreatedDate.toLowerCase();
                return vendor.contains(q) || heading.contains(q) || details.contains(q) || rate.contains(q) || date.contains(q);
              }).toList();

        if (allItems.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildEmptyState(),
          );
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: _buildCategoryBannerSlider(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            if (spotData != null && spotData.subCategories.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSubCategoryChips(spotData.subCategories),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            if (filteredItems.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildSpotItemCard(item, spotData!),
                      );
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSpotItemCard(SpotRateItem item, SpotRateResponse spotData) {
    final imgUrl = spotData.getFullSpotImageUrl(item);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD0E1F4), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _showSpotDetailModal(context, item, spotData),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dynamic vendor image with rate-card reference dimensions (shows actual rectangle/square without fixed cropping)
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AppCachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.contain,
                              errorWidget: Container(
                                width: 80,
                                height: 80,
                                color: const Color(0xFFEBF3FA),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.vendorName.replaceAll('*', ''),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF061E36),
                                height: 1.25,
                              ),
                              softWrap: true,
                            ),
                            if (item.vendorSpotHeading.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.vendorSpotHeading,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3B73),
                                  height: 1.25,
                                ),
                                softWrap: true,
                              ),
                            ],
                            if (item.vendorProductRate.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '₹ ${item.vendorProductRate}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0A3B73),
                                ),
                                softWrap: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Line-by-line Market Rates Preview (preserves each commodity and rate on new lines)
                  if (item.vendorSpotDetails.isNotEmpty) ...[
                    SpotRateCardLineDisplay(
                      detailsText: item.vendorSpotDetails,
                      heading: item.vendorSpotHeading,
                    ),
                  ],

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFEBF3FA)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0A3B73)),
                      const SizedBox(width: 4),
                      Text(
                        AppDateFormatter.format(item.vendorSpotCreatedDate),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                      ),
                      if (item.vendorSpotCreatedTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text('|', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF0A3B73)),
                        const SizedBox(width: 4),
                        Text(
                          item.vendorSpotCreatedTime,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpotDetailModal(BuildContext context, SpotRateItem item, SpotRateResponse spotData) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return SpotMarketDetailDialog(
          item: item,
          spotData: spotData,
        );
      },
    );
  }

  Widget _buildNewsTabDataView() {
    return FutureBuilder<NewsResponse>(
      future: _newsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final newsData = snapshot.data;
        final allNews = newsData?.data ?? [];

        final filteredItems = _searchQuery.isEmpty
            ? allNews
            : allNews.where((item) {
                final q = _searchQuery;
                final heading = item.newsHeading.toLowerCase();
                final details = item.newsDetails.toLowerCase();
                final date = item.newsCreatedDate.toLowerCase();
                return heading.contains(q) || details.contains(q) || date.contains(q);
              }).toList();

        if (filteredItems.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildEmptyState(),
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: _buildCategoryBannerSlider(),
              ),
              const SizedBox(height: 14),
              // NO subcategory filter chips in News tab as requested
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                itemCount: filteredItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final newsItem = filteredItems[index];
                  return _buildNewsCard(newsItem, newsData!);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsCard(NewsItem item, NewsResponse newsData) {
    final imgUrl = newsData.getFullNewsImageUrl(item);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E1F4), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NewsDetailScreen(
                  newsItem: item,
                  categoryName: widget.category.name,
                  newsResponse: newsData,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AppCachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.contain,
                            errorWidget: Container(
                              width: 80,
                              height: 80,
                              color: const Color(0xFFEBF3FA),
                              child: const Center(
                                child: Icon(Icons.newspaper_rounded, color: Color(0xFF0A3B73), size: 36),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.newsHeading,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF061E36),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.newsDetails.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.newsDetails,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEBF3FA)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF0A3B73)),
                        const SizedBox(width: 5),
                        Text(
                          AppDateFormatter.format(item.newsCreatedDate),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                        if (item.newsCreatedTime.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Text('|', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF0A3B73)),
                          const SizedBox(width: 4),
                          Text(
                            item.newsCreatedTime,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View More',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A3B73),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0A3B73)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool isSelected = _activeBottomTab == index;

    return InkWell(
      onTap: () {
        setState(() {
          _activeBottomTab = index;
        });
      },
      borderRadius: BorderRadius.circular(25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF0A3B73) : Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0A3B73) : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Color(0xFFEBF3FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 50,
              color: Color(0xFF0A3B73),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Oops! No Data Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF061E36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No rates available for ${widget.category.name} right now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A3B73),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0E1F4)),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Failed to load rates\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A3B73),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DYNAMIC CATEGORY BANNER CAROUSEL SLIDER (AUTO-SCROLLING)
// ============================================================
class _CategoryBannerSlider extends StatefulWidget {
  final Future<SliderResponse> slidersFuture;

  const _CategoryBannerSlider({required this.slidersFuture});

  @override
  State<_CategoryBannerSlider> createState() => _CategoryBannerSliderState();
}

class _CategoryBannerSliderState extends State<_CategoryBannerSlider> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1000);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int count) {
    if (count <= 1 || _autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _launchSliderUrl(String? urlStr) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    try {
      Uri uri = Uri.parse(urlStr.trim());
      if (!uri.hasScheme) {
        uri = Uri.parse('https://${urlStr.trim()}');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching category slider URL $urlStr: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double bannerHeight =
            (constraints.maxWidth * 0.44).clamp(160.0, 210.0);

        return FutureBuilder<SliderResponse>(
          future: widget.slidersFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.data.isNotEmpty) {
              final sliders = snapshot.data!.data;
              final sliderRes = snapshot.data!;

              _startAutoScroll(sliders.length);

              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: bannerHeight,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (pageIndex) {
                          setState(() {
                            _currentIndex = pageIndex % sliders.length;
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = sliders[index % sliders.length];
                          final imgUrl = sliderRes.getFullImageUrl(item);
                          return GestureDetector(
                            onTap: () => _launchSliderUrl(item.url),
                            child: AppCachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorWidget: const SizedBox.shrink(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              if (sliders.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    sliders.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: dotIndex == _currentIndex ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dotIndex == _currentIndex
                            ? const Color(0xFF0A3B73)
                            : const Color(0xFFD0E1F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        }
        return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

/// Dynamic sparkline graph card displayed in the Live Price History dialog,
/// taking previous 3-4 historical stock prices + current price to render
/// an interactive financial trendline with green (raise) / red (fall) styling,
/// change indicator badge, and live pulse dot.
class _LivePriceSparklineCard extends StatelessWidget {
  final LiveRateItem item;

  const _LivePriceSparklineCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final double currentPrice = double.tryParse(item.vendorProductRate) ?? 0.0;

    // Collect up to 4 previous prices in chronological order (oldest -> newest)
    final List<double> prices = [];
    final int countToTake = item.stocks.length >= 4 ? 4 : item.stocks.length;
    for (int i = countToTake - 1; i >= 0; i--) {
      final rate = double.tryParse(item.stocks[i].rate);
      if (rate != null) {
        prices.add(rate);
      }
    }
    // Append the current live price as the latest point
    prices.add(currentPrice);

    // Calculate increase/decrease against immediate previous price
    final double prevPrice = item.stocks.isNotEmpty
        ? (double.tryParse(item.stocks.first.rate) ?? currentPrice)
        : currentPrice;
    final double diffVal = currentPrice - prevPrice;

    final bool isUp = diffVal > 0;
    final bool isDown = diffVal < 0;

    // Aesthetic color scheme
    final Color trendColor = isUp
        ? const Color(0xFF00A854)
        : (isDown ? const Color(0xFFE53935) : const Color(0xFF0A3B73));
    final Color badgeBg = isUp
        ? const Color(0xFFE8F5E9)
        : (isDown ? const Color(0xFFFFEBEE) : const Color(0xFFEBF3FA));
    final Color borderColor = isUp
        ? const Color(0xFFA5D6A7)
        : (isDown ? const Color(0xFFEF9A9A) : const Color(0xFFD0E1F4));

    final IconData trendIcon = isUp
        ? Icons.trending_up_rounded
        : (isDown ? Icons.trending_down_rounded : Icons.trending_flat_rounded);

    // Formatted difference text (e.g. "+5", "-5", "0")
    String diffFormatted;
    if (isUp) {
      diffFormatted = '+${diffVal.toStringAsFixed(diffVal.truncateToDouble() == diffVal ? 0 : 1)}';
    } else if (isDown) {
      diffFormatted = diffVal.toStringAsFixed(diffVal.truncateToDouble() == diffVal ? 0 : 1);
    } else {
      diffFormatted = '0';
    }

    final String tooltipMessage = prices.length > 1
        ? 'Trend: ${prices.map((p) => '₹${p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 1)}').join(' → ')} ($diffFormatted)'
        : 'Live Price: ₹${currentPrice.toStringAsFixed(1)}';

    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      child: Container(
        width: 106,
        height: 70,
        padding: const EdgeInsets.fromLTRB(7, 6, 7, 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: trendColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge row: Trend icon + Change text & Live indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 12, color: trendColor),
                      const SizedBox(width: 2),
                      Text(
                        diffFormatted,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: BoxDecoration(
                        color: trendColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: trendColor.withValues(alpha: 0.4),
                            blurRadius: 3,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Dynamic Sparkline Graph
            Expanded(
              child: CustomPaint(
                painter: _SparklineGraphPainter(
                  prices: prices,
                  lineColor: trendColor,
                  fillColor: trendColor.withValues(alpha: 0.18),
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering a smooth monotonic Bézier sparkline curve
/// with vertical gradient fill and live current-price endpoint marker.
class _SparklineGraphPainter extends CustomPainter {
  final List<double> prices;
  final Color lineColor;
  final Color fillColor;

  _SparklineGraphPainter({
    required this.prices,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty || size.width <= 0 || size.height <= 0) return;

    if (prices.length == 1) {
      final y = size.height / 2;
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
      canvas.drawCircle(Offset(size.width - 4, y), 3.0, Paint()..color = lineColor);
      return;
    }

    double minVal = prices.first;
    double maxVal = prices.first;
    for (final p in prices) {
      if (p < minVal) minVal = p;
      if (p > maxVal) maxVal = p;
    }

    const double paddingX = 4.0;
    const double paddingTop = 4.0;
    const double paddingBottom = 4.0;
    final double drawWidth = size.width - (paddingX * 2);
    final double drawHeight = size.height - paddingTop - paddingBottom;
    final double range = maxVal - minVal;

    final List<Offset> points = [];
    for (int i = 0; i < prices.length; i++) {
      final double x = paddingX + (drawWidth / (prices.length - 1)) * i;
      final double y = range == 0
          ? (size.height / 2)
          : (paddingTop + drawHeight - (((prices[i] - minVal) / range) * drawHeight));
      points.add(Offset(x, y));
    }

    // Build smooth curved path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final double controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(
          controlX,
          p0.dy,
          controlX,
          p1.dy,
          p1.dx,
          p1.dy,
        );
      }
    }

    // Area fill under curve with gradient fading to transparent
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor,
          fillColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Smooth stroke line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Live endpoint marker for current price (halo + white ring + center dot)
    final lastPoint = points.last;
    canvas.drawCircle(
      lastPoint,
      4.5,
      Paint()..color = lineColor.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      lastPoint,
      2.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      lastPoint,
      1.5,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklineGraphPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.prices.length != prices.length) {
      return true;
    }
    for (int i = 0; i < prices.length; i++) {
      if (prices[i] != oldDelegate.prices[i]) return true;
    }
    return false;
  }
}

