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

  void _loadData() {
    setState(() {
      _liveRatesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppLive(widget.category.id, token: token);
      });
      _ratesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppRate(widget.category.id, token: token);
      });
      _spotRatesFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppSpot(widget.category.id, token: token);
      });
      _newsFuture = SessionService.getToken().then((token) {
        return ApiService().fetchAppNews(widget.category.id, token: token);
      });
      _categorySlidersFuture = SessionService.getToken().then((token) {
        return ApiService().fetchCategorySliders(widget.category.id, token: token);
      });
    });
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
                                      color: Color(0xFF0A4B26),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    cursorColor: const Color(0xFF0A4B26),
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
          color: const Color(0xFF0F5A2F),
          backgroundColor: Colors.white,
          strokeWidth: 2.5,
          onRefresh: () async {
            _loadData();
            await Future.wait([_liveRatesFuture, _ratesFuture, _spotRatesFuture, _newsFuture, _categorySlidersFuture]);
          },
          child: _buildBodyContent(),
        ),
      ),
      bottomNavigationBar: _buildBottomPillNavBar(),
    );
  }

  Widget _buildBodyContent() {
    switch (_activeBottomTab) {
      case 0:
        return _buildTabDataView(_liveRatesFuture, isLiveTab: true);
      case 1:
        return _buildTabDataView(_ratesFuture, isLiveTab: false);
      case 2:
        return _buildSpotTabDataView();
      case 3:
        return _buildNewsTabDataView();
      default:
        return _buildTabDataView(_liveRatesFuture, isLiveTab: true);
    }
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

                final rows = _getVendorRateRows(item, rateData!);
                final rowMatch = rows.any((r) =>
                    r['brand']!.toLowerCase().contains(q) ||
                    r['qty']!.toLowerCase().contains(q) ||
                    r['rate']!.toLowerCase().contains(q));

                return vendor.contains(q) || prod.contains(q) || size.contains(q) || rate.contains(q) || rowMatch;
              }).toList();

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
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return isLiveTab
                        ? _buildLiveProductRateCard(item, rateData!)
                        : _buildRatesVendorCard(item, rateData!);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryBannerSlider() {
    return FutureBuilder<SliderResponse>(
      future: _categorySlidersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.data.isNotEmpty) {
          final sliders = snapshot.data!.data;
          final sliderRes = snapshot.data!;

          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 165,
              child: PageView.builder(
                itemCount: sliders.length,
                itemBuilder: (context, index) {
                  final s = sliders[index];
                  final imgUrl = sliderRes.getFullImageUrl(s);
                  return Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  );
                },
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
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
              selectedColor: const Color(0xFF1B7A44),
              backgroundColor: const Color(0xFFDCF2E5),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1B7A44),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1B7A44) : const Color(0xFFBDD9C8),
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
            selectedColor: const Color(0xFF1B7A44),
            backgroundColor: const Color(0xFFDCF2E5),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF1B7A44),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? const Color(0xFF1B7A44) : const Color(0xFFBDD9C8),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 85,
                  height: 85,
                  child: Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF0F7F2),
                      child: const Center(
                        child: Icon(Icons.opacity_rounded, color: Color(0xFF1B7A44), size: 36),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.vendorName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C3A20),
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFAF2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBDD9C8), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹ ${item.vendorProductRate}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0A4B26),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                diff,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isNegative ? const Color(0xFFE53935) : const Color(0xFF1B7A44),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.vendorProduct,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (item.vendorProductSize.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.vendorProductSize,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEFAF2)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF1B7A44)),
                  const SizedBox(width: 4),
                  Text(
                    item.vendorProductCreatedDate,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1B7A44)),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF1B7A44)),
                  const SizedBox(width: 4),
                  Text(
                    item.vendorProductCreatedTime,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1B7A44)),
                  ),
                ],
              ),
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
                          color: Color(0xFF1B7A44),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF1B7A44)),
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

  List<Map<String, String>> _getVendorRateRows(LiveRateItem item, LiveRateResponse rateData) {
    final List<Map<String, String>> rows = [];
    final Set<String> seenKeys = {};

    final vendorProducts = rateData.data
        .where((v) => v.vendorId == item.vendorId || (v.vendorId == 0 && v.vendorName == item.vendorName))
        .toList();

    final itemsToProcess = vendorProducts.isNotEmpty ? vendorProducts : [item];

    for (var p in itemsToProcess) {
      final key = '${p.vendorProduct}_${p.vendorProductSize}_${p.vendorProductRate}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        rows.add({
          'brand': p.vendorProduct.isNotEmpty ? p.vendorProduct : 'N/A',
          'qty': p.vendorProductSize.isNotEmpty ? p.vendorProductSize : 'N/A',
          'rate': p.vendorProductRate,
        });
      }

      for (var stk in p.stocks) {
        final stkBrand = stk.vendorProduct.isNotEmpty ? stk.vendorProduct : p.vendorProduct;
        final stkQty = stk.vendorProductSize.isNotEmpty ? stk.vendorProductSize : p.vendorProductSize;
        final stkKey = '${stkBrand}_${stkQty}_${stk.rate}';
        if (!seenKeys.contains(stkKey)) {
          seenKeys.add(stkKey);
          rows.add({
            'brand': stkBrand.isNotEmpty ? stkBrand : 'N/A',
            'qty': stkQty.isNotEmpty ? stkQty : 'N/A',
            'rate': stk.rate,
          });
        }
      }
    }

    return rows;
  }

  Widget _buildRatesVendorCard(LiveRateItem item, LiveRateResponse rateData) {
    final imgUrl = rateData.getFullVendorImageUrl(item);
    final dynamicRows = _getVendorRateRows(item, rateData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF0F7F2),
                      child: const Center(
                        child: Icon(Icons.business_rounded, color: Color(0xFF1B7A44), size: 36),
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0C3A20),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF1B7A44)),
                        const SizedBox(width: 4),
                        Text(
                          item.vendorProductCreatedDate,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                        ),
                        const SizedBox(width: 8),
                        const Text('|', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF1B7A44)),
                        const SizedBox(width: 4),
                        Text(
                          item.vendorProductCreatedTime,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.hasValidVendorMobile)
                InkWell(
                  onTap: () => _makePhoneCall(item.vendorMobile!),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCF2E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Color(0xFF0F5A2F),
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
              border: Border.all(color: const Color(0xFFEEFAF2)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEFAF2),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'BRAND',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'QUANTITY',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Min/Max (+/-)',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                        ),
                      ),
                    ],
                  ),
                ),
                ...dynamicRows.take(2).map(
                      (r) => _buildRateTableRow(
                        brand: r['brand']!,
                        qty: r['qty']!,
                        rate: r['rate']!,
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showRatesDetailDialog(context, item, rateData),
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
                        color: Color(0xFF1B7A44),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF1B7A44)),
                  ],
                ),
              ),
            ),
          ),
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
                  color: const Color(0xFFEEFAF2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '₹ $rate',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0A4B26),
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

  void _showRatesDetailDialog(BuildContext context, LiveRateItem item, LiveRateResponse rateData) {
    final imgUrl = rateData.getFullVendorImageUrl(item);
    final rateRows = _getVendorRateRows(item, rateData);

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
                            color: Color(0xFFDCF2E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF1B7A44)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF0F7F2),
                              child: const Icon(Icons.business_rounded, size: 40, color: Color(0xFF1B7A44)),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0C3A20),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.vendorProductCreatedDate,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                ),
                                const SizedBox(width: 6),
                                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                const SizedBox(width: 6),
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.vendorProductCreatedTime,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDEDE4)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEFAF2),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'BRAND',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'QUANTITY',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Min/Max (₹)',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rateRows.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F7F2)),
                          itemBuilder: (context, idx) {
                            final row = rateRows[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      row['brand']!,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row['qty']!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A5568)),
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
                                          color: const Color(0xFFEEFAF2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '₹ ${row['rate']}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0A4B26),
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
                            color: Color(0xFFDCF2E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF1B7A44)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF0F7F2),
                              child: const Icon(Icons.opacity_rounded, size: 40, color: Color(0xFF1B7A44)),
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
                                color: Color(0xFF0C3A20),
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
                                  color: const Color(0xFFDCF2E5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.vendorProductSize,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B7A44),
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
                      color: const Color(0xFFEAF8F0),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFC4E8D1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
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
                                    color: Color(0xFF0A4B26),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  diff,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isNegative ? const Color(0xFFE53935) : const Color(0xFF1B7A44),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.vendorProductCreatedDate,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1B7A44)),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.vendorProductCreatedTime,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1B7A44)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            size: 38,
                            color: Color(0xFF1B7A44),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Color(0xFF1B7A44), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Price History',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0C3A20),
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
                        border: Border.all(color: const Color(0xFFDDEDE4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEFAF2),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Date',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Time',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Price (₹)',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C3A20)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: item.stocks.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F7F2)),
                            itemBuilder: (context, idx) {
                              final stock = item.stocks[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        stock.date,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5568)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        stock.time,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5568)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        stock.rate,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0C3A20),
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
            colors: [Color(0xFF0A4B26), Color(0xFF1B7A44)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A4B26).withValues(alpha: 0.35),
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

        // Group items by vendorId or vendorName
        final Map<String, List<SpotRateItem>> groupedMap = {};
        for (var item in filteredItems) {
          final groupKey = item.vendorId != 0 ? '${item.vendorId}' : item.vendorName;
          groupedMap.putIfAbsent(groupKey, () => []).add(item);
        }

        // Sort items inside each group by dateTime descending (latest first)
        for (var list in groupedMap.values) {
          list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }

        final groupedList = groupedMap.values.toList();

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
              if (spotData != null && spotData.subCategories.isNotEmpty)
                _buildSubCategoryChips(spotData.subCategories),
              const SizedBox(height: 14),
              if (filteredItems.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  itemCount: groupedList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final groupItems = groupedList[index];
                    return _buildSpotGroupCard(groupItems, spotData!);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpotGroupCard(List<SpotRateItem> groupItems, SpotRateResponse spotData) {
    // Show latest item first
    final latestItem = groupItems.first;
    final imgUrl = spotData.getFullSpotImageUrl(latestItem);

    // Rule: If group has > 1 data items, show View More button; if only 1 item, hide View More.
    final bool showViewMore = groupItems.length > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF0F7F2),
                      child: const Center(
                        child: Icon(Icons.grid_view_rounded, color: Color(0xFF1B7A44), size: 36),
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
                      latestItem.vendorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0C3A20),
                        height: 1.2,
                      ),
                    ),
                    if (latestItem.vendorSpotHeading.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        latestItem.vendorSpotHeading,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B7A44),
                        ),
                      ),
                    ],
                    if (latestItem.vendorSpotDetails.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        latestItem.vendorSpotDetails,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (latestItem.vendorProductRate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '₹ ${latestItem.vendorProductRate}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A4B26),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showViewMore)
                InkWell(
                  onTap: () => _showSpotDetailModal(context, groupItems, spotData),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFAF2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View More',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B7A44),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF1B7A44)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEEFAF2)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF1B7A44)),
              const SizedBox(width: 4),
              Text(
                latestItem.vendorSpotCreatedDate,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
              ),
              const SizedBox(width: 8),
              const Text('|', style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(width: 8),
              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF1B7A44)),
              const SizedBox(width: 4),
              Text(
                latestItem.vendorSpotCreatedTime,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSpotDetailModal(BuildContext context, List<SpotRateItem> groupItems, SpotRateResponse spotData) {
    final latestItem = groupItems.first;
    final imgUrl = spotData.getFullSpotImageUrl(latestItem);

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
                            color: Color(0xFFDCF2E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF1B7A44)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 85,
                          height: 85,
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF0F7F2),
                              child: const Icon(Icons.grid_view_rounded, size: 40, color: Color(0xFF1B7A44)),
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
                              latestItem.vendorName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0C3A20),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'History & Rate Updates',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0C3A20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = groupItems[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFDFA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDEDE4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.vendorSpotHeading,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0C3A20),
                                    ),
                                  ),
                                ),
                                if (item.vendorProductRate.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEFAF2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '₹ ${item.vendorProductRate}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0A4B26),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.vendorSpotDetails.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.vendorSpotDetails,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.vendorSpotCreatedDate,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                ),
                                const SizedBox(width: 8),
                                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                const SizedBox(width: 8),
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF1B7A44)),
                                const SizedBox(width: 4),
                                Text(
                                  item.vendorSpotCreatedTime,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
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
        border: Border.all(color: const Color(0xFFDDEDE4), width: 1.1),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF0F7F2),
                            child: const Center(
                              child: Icon(Icons.newspaper_rounded, color: Color(0xFF1B7A44), size: 36),
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
                              color: Color(0xFF0C3A20),
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
                const Divider(height: 1, color: Color(0xFFEEFAF2)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF1B7A44)),
                        const SizedBox(width: 5),
                        Text(
                          item.newsCreatedDate,
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
                          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF1B7A44)),
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
                            color: Color(0xFF1B7A44),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF1B7A44)),
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
              color: isSelected ? const Color(0xFF0A4B26) : Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0A4B26) : Colors.white.withValues(alpha: 0.85),
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
              color: Color(0xFFDCF2E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 50,
              color: Color(0xFF1B7A44),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Oops! No Data Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0C3A20),
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
            label: const Text('Refresh Rates'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B7A44),
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
          border: Border.all(color: const Color(0xFFDDEDE4)),
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
                backgroundColor: const Color(0xFF1B7A44),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
