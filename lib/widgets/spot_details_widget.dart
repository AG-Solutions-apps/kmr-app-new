import 'package:flutter/material.dart';
import '../core/utils/date_formatter.dart';
import '../models/spot_rate_model.dart';
import 'app_cached_network_image.dart';

/// Single commodity rate entry (e.g. OCT: 67.88 (+0.26))
class SpotRateRow {
  final String commodity;
  final String rate;
  final String change;
  final bool? isPositive;

  const SpotRateRow({
    required this.commodity,
    required this.rate,
    this.change = '',
    this.isPositive,
  });
}

/// Market section containing multiple rate rows (e.g. SOY OIL, SOY MEAL, SOY SEED)
class SpotMarketSection {
  final String title;
  final List<SpotRateRow> rows;
  final String? note;

  const SpotMarketSection({
    required this.title,
    required this.rows,
    this.note,
  });
}

/// Robust line-aware parser for `vendor_spot_details` with in-memory caching
class SpotDetailsParser {
  SpotDetailsParser._();

  static final List<String> _months = [
    'JAN', 'FEB', 'MAR', 'MARC', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'SEPT', 'OCT', 'NOV', 'DEC',
    'JFM', 'AMJ', 'JAS', 'OND'
  ];

  static final RegExp _doubleColonRegex = RegExp(r'^[A-Za-z\s]+:[A-Za-z0-9\.]+:?[0-9\.]+');
  static final RegExp _rateRowRegex = RegExp(
    r'^([A-Za-z0-9\/\.\-\s\*\(\)–]+?)\s*:\s*([0-9\.,]+(?:\s*[\/\-]\s*[0-9\.,]+)?(?:\s*\+[A-Za-z0-9\s\.\-]+)?)\s*(\*?\s*\([^\)]+\)|(?:\s*[\+\-][0-9\.]+))?(.*)$',
  );
  static final RegExp _signRegex = RegExp(r'^([0-9\.]+)\s*([\+\-][0-9\.]+)$');

  // Fast in-memory cache for parsed spot rate sections
  static final Map<String, List<SpotMarketSection>> _cache = {};

  /// Parses text into structured market sections. Returns empty list if completely empty.
  static List<SpotMarketSection> parse(String text, {String? defaultHeading}) {
    if (text.trim().isEmpty) return const [];

    final cacheKey = '$text||$defaultHeading';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n').map((l) => l.trim()).toList();

    List<SpotMarketSection> result;
    if (lines.length > 1) {
      result = _parseLines(lines, defaultHeading: defaultHeading);
    } else {
      result = _parseSingleLine(text.trim(), defaultHeading: defaultHeading);
    }

    // Limit cache size to 400 entries
    if (_cache.length > 400) {
      _cache.clear();
    }
    _cache[cacheKey] = result;
    return result;
  }

  static List<SpotMarketSection> _parseLines(List<String> lines, {String? defaultHeading}) {
    List<SpotMarketSection> sections = [];
    String currentSection = '';
    List<SpotRateRow> currentRows = [];
    List<String> notes = [];

    void flushSection() {
      if (currentRows.isNotEmpty || notes.isNotEmpty) {
        final secTitle = currentSection.isNotEmpty ? currentSection : (defaultHeading ?? 'Spot Rates');
        sections.add(SpotMarketSection(
          title: _cleanTitle(secTitle),
          rows: List.from(currentRows),
          note: notes.isNotEmpty ? notes.join('\n') : null,
        ));
        currentRows.clear();
        notes.clear();
      }
    }

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // Empty line means \n\n was encountered -> End of current section!
      if (line.isEmpty) {
        flushSection();
        currentSection = '';
        continue;
      }

      // Handle double colon like "CRUDE OIL:OCT:8877(-4)"
      if (_doubleColonRegex.hasMatch(line)) {
        final colonIdx = line.indexOf(':');
        final firstPart = line.substring(0, colonIdx).trim();
        final rest = line.substring(colonIdx + 1).trim();

        if (rest.contains(':')) {
          flushSection();
          currentSection = firstPart;
          final row = _parseRateRow(rest);
          if (row != null) {
            currentRows.add(row);
          }
          continue;
        }
      }

      // Check if line contains a rate with colon
      if (line.contains(':')) {
        final row = _parseRateRow(line);
        if (row != null) {
          if (currentSection.isEmpty && currentRows.isEmpty) {
            currentSection = row.commodity;
          }
          currentRows.add(row);
        } else {
          notes.add(line);
        }
      } else {
        // Line has no colon
        if (line.startsWith('(') && line.endsWith(')')) {
          notes.add(line);
        } else if (line.startsWith('*') && line.endsWith('*') && currentRows.isNotEmpty) {
          notes.add(line);
        } else {
          // If we already have rows, flush the section and start a new one!
          if (currentRows.isNotEmpty) {
            flushSection();
            currentSection = line;
          } else {
            // Combine headers (e.g. "CBOT" followed by "SOY OIL" -> "CBOT SOY OIL")
            if (currentSection.isNotEmpty) {
              currentSection = '$currentSection $line';
            } else {
              currentSection = line;
            }
          }
        }
      }
    }

    flushSection();

    if (sections.isEmpty) {
      sections.add(SpotMarketSection(
        title: _cleanTitle(defaultHeading ?? 'Spot Rates'),
        rows: const [],
        note: lines.where((l) => l.isNotEmpty).join('\n'),
      ));
    }

    return sections;
  }

  static SpotRateRow? _parseRateRow(String line) {
    final m = _rateRowRegex.firstMatch(line);

    if (m != null) {
      String key = m.group(1)?.trim() ?? '';
      String val = m.group(2)?.trim() ?? '';
      String changePart = m.group(3)?.trim() ?? '';
      String extra = m.group(4)?.trim() ?? '';

      // Check attached sign in val like 360.7-3
      if (changePart.isEmpty && (val.contains('-') || val.contains('+'))) {
        final signMatch = _signRegex.firstMatch(val);
        if (signMatch != null) {
          final v1 = double.tryParse(signMatch.group(1)!) ?? 0;
          final v2 = double.tryParse(signMatch.group(2)!.replaceAll('+', '').replaceAll('-', '')) ?? 0;
          if (!(v1 > 100 && v2 > 100 && (v1 - v2).abs() < 200)) {
            val = signMatch.group(1)!;
            changePart = signMatch.group(2)!;
          }
        }
      }

      if (extra.isNotEmpty) {
        val = '$val $extra'.trim();
      }

      String cleanChange = changePart
          .replaceAll('*', '')
          .replaceAll('(', '')
          .replaceAll(')', '')
          .trim();

      bool? isPos;
      if (cleanChange.startsWith('+')) {
        isPos = true;
      } else if (cleanChange.startsWith('-')) {
        isPos = false;
      }

      return SpotRateRow(
        commodity: key.toUpperCase(),
        rate: val,
        change: cleanChange.isNotEmpty
            ? (cleanChange.startsWith('+') || cleanChange.startsWith('-') ? cleanChange : '+$cleanChange')
            : '',
        isPositive: isPos,
      );
    }

    // Fallback simple colon split
    final parts = line.split(':');
    if (parts.length == 2) {
      return SpotRateRow(
        commodity: parts[0].trim().toUpperCase(),
        rate: parts[1].trim(),
      );
    }
    return null;
  }

  static List<SpotMarketSection> _parseSingleLine(String text, {String? defaultHeading}) {
    final tokenRegex = RegExp(
      r'([A-Za-z0-9\/\.\-\s\*\(\)]+?)\s*:\s*([0-9\.,]+(?:\s*[\/\-]\s*[0-9\.,]+)?)\s*(\*?\s*\([^\)]+\)|(?:\s*[\+\-][0-9\.]+))?',
      caseSensitive: false,
    );

    final matches = tokenRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [
        SpotMarketSection(
          title: _cleanTitle(defaultHeading ?? 'Spot Rates'),
          rows: const [],
          note: text,
        )
      ];
    }

    List<SpotMarketSection> sections = [];
    String currentSection = defaultHeading ?? 'Spot Rate';
    List<SpotRateRow> currentRows = [];

    for (var m in matches) {
      String key = m.group(1)?.trim() ?? '';
      String val = m.group(2)?.trim() ?? '';
      String changePart = m.group(3)?.trim() ?? '';

      String secName = '';
      String itemLabel = key;

      final words = key.split(RegExp(r'\s+'));
      if (words.length > 1) {
        final lastWord = words.last.toUpperCase();
        if (_months.contains(lastWord)) {
          itemLabel = lastWord;
          secName = words.sublist(0, words.length - 1).join(' ').trim();
        }
      }

      if (secName.isNotEmpty && secName.toUpperCase() != currentSection.toUpperCase()) {
        if (currentRows.isNotEmpty) {
          sections.add(SpotMarketSection(
            title: _cleanTitle(currentSection),
            rows: List.from(currentRows),
          ));
          currentRows.clear();
        }
        currentSection = secName;
      }

      String cleanChange = changePart.replaceAll('*', '').replaceAll('(', '').replaceAll(')', '').trim();
      bool? isPos;
      if (cleanChange.startsWith('+')) isPos = true;
      if (cleanChange.startsWith('-')) isPos = false;

      currentRows.add(SpotRateRow(
        commodity: itemLabel.toUpperCase(),
        rate: val,
        change: cleanChange.isNotEmpty ? (cleanChange.startsWith('+') || cleanChange.startsWith('-') ? cleanChange : '+$cleanChange') : '',
        isPositive: isPos,
      ));
    }

    if (currentRows.isNotEmpty) {
      sections.add(SpotMarketSection(
        title: _cleanTitle(currentSection),
        rows: List.from(currentRows),
      ));
    }

    return sections;
  }

  static String _cleanTitle(String title) {
    return title.replaceAll('*', '').trim();
  }
}

/// Structured Section Card for the View More Dialog (3-Column Table: Commodity | Rate | Change)
class SpotMarketSectionCard extends StatelessWidget {
  final SpotMarketSection section;

  const SpotMarketSectionCard({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBF5), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2EBF5), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A3B73),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF061E36),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 3-Column Table Header: Commodity | Rate | Change
          if (section.rows.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFEBF3FA),
              child: const Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Commodity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A3B73),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Rate',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A3B73),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Change',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A3B73),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3-Column Data Rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: section.rows.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final row = section.rows[index];
                  final isEven = index % 2 == 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEven ? Colors.white : const Color(0xFFFAFCFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        // Commodity
                        Expanded(
                          flex: 4,
                          child: Text(
                            row.commodity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                            softWrap: true,
                          ),
                        ),
                        // Rate
                        Expanded(
                          flex: 3,
                          child: Text(
                            row.rate,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0A3B73),
                            ),
                          ),
                        ),
                        // Change
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: row.change.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: row.isPositive == true
                                          ? const Color(0xFFE8F8F0)
                                          : (row.isPositive == false
                                              ? const Color(0xFFFFEAEA)
                                              : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      row.change,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: row.isPositive == true
                                            ? const Color(0xFF10B981)
                                            : (row.isPositive == false
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '-',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // Note if present
          if (section.note != null && section.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  section.note!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Line-by-line display for the Spot Card in the list view (shows each section & rate on new lines)
class SpotRateCardLineDisplay extends StatelessWidget {
  final String detailsText;
  final String heading;

  const SpotRateCardLineDisplay({
    super.key,
    required this.detailsText,
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    final sections = SpotDetailsParser.parse(detailsText, defaultHeading: heading);

    if (sections.isEmpty) return const SizedBox.shrink();

    final hasRows = sections.any((s) => s.rows.isNotEmpty);    if (!hasRows) {
      // Preserved plain text fallback: show only 1 line of data in main card!
      final lines = detailsText
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final firstLine = lines.isNotEmpty ? lines.first : detailsText;
      final remainingCount = lines.length > 1 ? lines.length - 1 : 0;

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              firstLine,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
                height: 1.35,
              ),
              softWrap: true,
            ),
            if (remainingCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD0E1F4), width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '+$remainingCount more',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A3B73),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View More',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A3B73),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0A3B73)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Show ONLY ONE SECTION in the main card!
    final firstSec = sections.first;
    final int remainingSections = sections.length - 1;
    final int totalRows = sections.fold(0, (sum, sec) => sum + sec.rows.length);
    final int remainingRates = totalRows > 1 ? totalRows - 1 : 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First Section Header
          Row(
            children: [
              Container(
                width: 3.5,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A3B73),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  firstSec.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0A3B73),
                    letterSpacing: 0.2,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Show ONLY ONE DATA (the first rate row) in the main card with responsive multi-line wrap
          if (firstSec.rows.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final firstRow = firstSec.rows.first;
                final bool isSameAsTitle = firstRow.commodity.trim().toUpperCase() ==
                    firstSec.title.trim().toUpperCase();
                final bool showCommodity = !isSameAsTitle && firstRow.commodity.isNotEmpty;
                final String commodityText = showCommodity ? (firstRow.commodity.length > 28 ? firstRow.commodity.substring(0, 25) + '...: ' : firstRow.commodity + ': ') : (isSameAsTitle && firstRow.rate.isNotEmpty ? 'Rate: ' : '');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (commodityText.isNotEmpty)
                          TextSpan(
                            text: commodityText,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        TextSpan(
                          text: firstRow.rate,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A3B73),
                          ),
                        ),
                        if (firstRow.change.isNotEmpty) ...[
                          const WidgetSpan(child: SizedBox(width: 6)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: firstRow.isPositive == true
                                    ? const Color(0xFFE8F8F0)
                                    : (firstRow.isPositive == false
                                        ? const Color(0xFFFFEAEA)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                firstRow.change,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: firstRow.isPositive == true
                                      ? const Color(0xFF10B981)
                                      : (firstRow.isPositive == false
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    softWrap: true,
                  ),
                );
              },
            ),
          ] else if (firstSec.note != null && firstSec.note!.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final noteLine = firstSec.note!.split('\n').first.trim();
                final bool isLong = noteLine.length > 55;
                final String displayNote = isLong ? noteLine.substring(0, 52) + '...' : noteLine;
                return Text(
                  displayNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                );
              },
            ),
          ],

          // Remaining items prompt at bottom
          const SizedBox(height: 10),
          if (remainingRates > 0 || remainingSections > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0E1F4), width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A3B73),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${remainingRates > 0 ? remainingRates : remainingSections} more',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remainingSections > 0
                          ? '${sections.skip(1).map((s) => s.title).take(2).join(', ')}${sections.length > 3 ? '...' : ''}'
                          : 'More rates in this section',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A3B73),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View More',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A3B73),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0A3B73)),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0E1F4), width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Full Market Table',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A3B73),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View More',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A3B73),
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0A3B73)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Full Modal Dialog displaying the Spot Market Rates in a structured 3-Column Table
class SpotMarketDetailDialog extends StatelessWidget {
  final SpotRateItem item;
  final SpotRateResponse spotData;

  const SpotMarketDetailDialog({
    super.key,
    required this.item,
    required this.spotData,
  });

  @override
  Widget build(BuildContext context) {
    final sections = SpotDetailsParser.parse(
      item.vendorSpotDetails,
      defaultHeading: item.vendorSpotHeading,
    );

    final String heading = item.vendorSpotHeading.isNotEmpty
        ? item.vendorSpotHeading
        : item.vendorName.replaceAll('*', '');

    final String formattedDate = AppDateFormatter.format(item.vendorSpotCreatedDate);

    // Dynamic vendor image from API response
    final String vendorImgUrl = spotData.getFullSpotImageUrl(item);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header Banner with vendor image from API response (no static banner)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2EBF5), width: 1.2)),
            ),
            child: Row(
              children: [
                // Dynamic vendor image with rate reference dimensions (preserves natural rectangle or square aspect ratio)
                SizedBox(
                  width: 65,
                  height: 65,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppCachedNetworkImage(
                        imageUrl: vendorImgUrl,
                        fit: BoxFit.contain,
                        errorWidget: Container(
                          width: 65,
                          height: 65,
                          color: const Color(0xFFEBF3FA),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Heading & Date (wraps naturally to next line)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        heading,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A3B73),
                          letterSpacing: 0.2,
                          height: 1.25,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF1B7A44)),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B7A44),
                            ),
                          ),
                          if (item.vendorSpotCreatedTime.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              item.vendorSpotCreatedTime,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Close button 'X'
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3-Column Structured Table Section Cards (Commodity | Rate | Change)
                  if (sections.isNotEmpty && sections.any((s) => s.rows.isNotEmpty)) ...[
                    ...sections.map((sec) => SpotMarketSectionCard(section: sec)),
                  ] else ...[
                    // Preserved original text if entries cannot be parsed into a table
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.notes_rounded, size: 16, color: Color(0xFF0A3B73)),
                              SizedBox(width: 6),
                              Text(
                                'Spot Rate Details',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3B73),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final l in item.vendorSpotDetails.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'))
                            if (l.trim().isEmpty)
                              const SizedBox(height: 8)
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  l.trim(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
