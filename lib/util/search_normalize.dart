const _quoteMap = {
  '‘': "'", // left single quotation mark
  '’': "'", // right single quotation mark / curly apostrophe
  '`': "'", // grave accent / backtick
  'ʼ': "'", // modifier letter apostrophe
  '′': "'", // prime
};

String normalizeForSearch(String s) {
  final buf = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_quoteMap[ch] ?? ch);
  }
  return buf.toString();
}
