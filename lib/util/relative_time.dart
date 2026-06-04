/// Formats [when] as a coarse, human-friendly "X ago" string, e.g.
/// "3 years ago", "5 months ago", "yesterday", "today". Used to hint at how
/// old a tune setting is when browsing search results.
///
/// Months are approximated as 30 days and years as 365 days — good enough for
/// a relative hint and intentionally avoids a calendar dependency.
String relativeAge(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);
  final days = diff.inDays;

  if (days < 0) return 'in the future';
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 30) {
    final weeks = days ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  if (days < 365) {
    final months = days ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  }
  final years = days ~/ 365;
  return years == 1 ? '1 year ago' : '$years years ago';
}
