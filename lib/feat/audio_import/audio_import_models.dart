/// An audio file handed to the app by the OS share sheet (e.g. an Apple Voice
/// Memo). [path] is a temporary location the native side copied the bytes into;
/// callers should copy it into durable storage promptly.
class SharedAudioFile {
  /// Absolute filesystem path to the (temporary) shared file.
  final String path;

  /// Suggested display name for the file, typically the original filename.
  final String name;

  const SharedAudioFile({required this.path, required this.name});

  static SharedAudioFile? fromMap(Map<Object?, Object?> map) {
    final path = map['path'];
    if (path is! String || path.isEmpty) return null;
    final name = map['name'];
    return SharedAudioFile(
      path: path,
      name: (name is String && name.isNotEmpty) ? name : path.split('/').last,
    );
  }

  @override
  String toString() => 'SharedAudioFile(path: $path, name: $name)';
}
