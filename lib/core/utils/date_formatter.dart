class AppDateFormatter {
  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Formats any date string (YYYY-MM-DD or ISO string) to "DD - Month - YYYY"
  /// Example: "2026-10-05" -> "05 - October - 2026"
  static String format(String? rawDateStr) {
    if (rawDateStr == null || rawDateStr.trim().isEmpty) return 'N/A';
    final str = rawDateStr.trim();

    try {
      final parsed = DateTime.parse(str);
      final day = parsed.day.toString().padLeft(2, '0');
      final month = _months[parsed.month - 1];
      final year = parsed.year.toString();
      return '$day - $month - $year';
    } catch (_) {
      if (str.contains('-')) {
        final parts = str.split('-');
        if (parts.length == 3 && parts[0].length == 4) {
          final year = parts[0];
          final monthIdx = int.tryParse(parts[1]) ?? 1;
          final day = parts[2].padLeft(2, '0');
          final month = (monthIdx >= 1 && monthIdx <= 12) ? _months[monthIdx - 1] : parts[1];
          return '$day - $month - $year';
        }
      }
      return str;
    }
  }
}
