/// An item handed to the app by the OS share sheet / "Open With".
///
/// Two transports share this type:
/// - **File** ([path] set): a temporary audio file the native side copied the
///   bytes into (e.g. an Apple Voice Memo); callers copy it into durable storage
///   promptly.
/// - **URL** ([url] set): a shared link, e.g. an Apple Music
///   `https://music.apple.com/...` track, which is resolved to a
///   `music-catalog:` recording rather than copied.
///
/// Exactly one of [path]/[url] is non-null.
class SharedAudioFile {
  /// Absolute filesystem path to the (temporary) shared file, for the file
  /// transport; null for the URL transport.
  final String? path;

  /// Shared link (e.g. an Apple Music URL), for the URL transport; null for the
  /// file transport.
  final String? url;

  /// Suggested display name, typically the original filename or link title.
  final String name;

  /// Performers/artist entered up front in the iOS share-sheet form; null for
  /// every other transport (macOS, "Open With", URL shares).
  final String? performers;

  /// True when the item arrived fully described (name + optional performers)
  /// from the iOS share-sheet form, so the app inserts it directly instead of
  /// opening the add-recording form. Only ever set for the file transport.
  final bool autosave;

  const SharedAudioFile({
    this.path,
    this.url,
    required this.name,
    this.performers,
    this.autosave = false,
  }) : assert(
         path != null || url != null,
         'a SharedAudioFile needs either a path or a url',
       );

  /// True when this is the URL transport (a shared link, not a file).
  bool get isUrl => url != null;

  static SharedAudioFile? fromMap(Map<Object?, Object?> map) {
    final performers = map['performers'];
    final autosave = map['autosave'];
    final parsedPerformers = (performers is String && performers.isNotEmpty)
        ? performers
        : null;
    final parsedAutosave = autosave is bool && autosave;

    final url = map['url'];
    if (url is String && url.isNotEmpty) {
      final name = map['name'];
      return SharedAudioFile(
        url: url,
        name: (name is String && name.isNotEmpty) ? name : url,
        performers: parsedPerformers,
        autosave: parsedAutosave,
      );
    }
    final path = map['path'];
    if (path is! String || path.isEmpty) return null;
    final name = map['name'];
    return SharedAudioFile(
      path: path,
      name: (name is String && name.isNotEmpty) ? name : path.split('/').last,
      performers: parsedPerformers,
      autosave: parsedAutosave,
    );
  }

  @override
  String toString() =>
      'SharedAudioFile(path: $path, url: $url, name: $name, '
      'performers: $performers, autosave: $autosave)';
}
