class ContentSourceMeta {
  final String id;
  final String name;
  final String license;
  final String? licenseUrl;
  final String attribution;

  /// When true the user must explicitly confirm license terms before the
  /// source is activated. Any non-CC0 / non-public-domain source sets this.
  final bool confirmationRequired;

  /// Whether the content ships bundled in the app binary (vs. fetched live).
  final bool bundled;

  const ContentSourceMeta({
    required this.id,
    required this.name,
    required this.license,
    this.licenseUrl,
    required this.attribution,
    required this.confirmationRequired,
    this.bundled = false,
  });

  bool get isAlwaysActive => !confirmationRequired;
}

/// Returns the [ContentSourceMeta] whose [ContentSourceMeta.name] matches
/// [sourceName], or `null` if not found. Used to look up attribution from
/// the name stored in the `from` column of the Tunes table.
ContentSourceMeta? metaBySourceName(
  List<ContentSourceMeta> registry,
  String? sourceName,
) {
  if (sourceName == null) return null;
  try {
    return registry.firstWhere((m) => m.name == sourceName);
  } catch (_) {
    return null;
  }
}
