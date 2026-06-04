class ContentSourceMeta {
  final String id;
  final String name;

  /// Short geographic/cultural genre label shown in the Content Library UI
  /// (e.g. 'Irish', 'Scottish', 'New England / Contra').
  final String genre;

  final String license;
  final String? licenseUrl;
  final String attribution;

  /// When true the user must explicitly confirm license terms before the
  /// source is activated. Any non-CC0 / non-public-domain source sets this.
  final bool confirmationRequired;

  /// Whether the content ships bundled in the app binary (vs. fetched live).
  final bool bundled;

  /// Hidden sources are excluded from the settings UI until permission is
  /// confirmed (e.g. awaiting written permission from the content author).
  /// The source remains in the registry so existing library tunes still render.
  final bool hidden;

  const ContentSourceMeta({
    required this.id,
    required this.name,
    required this.genre,
    required this.license,
    this.licenseUrl,
    required this.attribution,
    required this.confirmationRequired,
    bool? bundled,
    this.hidden = false,
  }) : bundled = bundled ?? !hidden;

  /// Public-domain sources that are on by default (user can still disable them).
  bool get isAlwaysActive => !confirmationRequired;
}

/// Returns the [ContentSourceMeta] whose [ContentSourceMeta.name] matches
/// [sourceName], or `null` if not found.
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

/// Returns the [ContentSourceMeta] whose [ContentSourceMeta.id] matches
/// [sourceId], or `null` if not found. Used to look up attribution from the
/// id stored in the `source` column of the Tunes table.
ContentSourceMeta? metaBySourceId(
  List<ContentSourceMeta> registry,
  String? sourceId,
) {
  if (sourceId == null) return null;
  try {
    return registry.firstWhere((m) => m.id == sourceId);
  } catch (_) {
    return null;
  }
}
