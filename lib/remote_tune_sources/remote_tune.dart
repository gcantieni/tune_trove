import 'package:tune_trove/model/tables/tunes.dart';

class RemoteTune {
  final String name;
  final TuneType? type;
  final String? key;
  final String? genre;
  final String sourceName;
  final String? sourceId;
  final String? abc;
  final String? url;

  const RemoteTune({
    required this.name,
    required this.sourceName,
    this.type,
    this.key,
    this.genre,
    this.sourceId,
    this.abc,
    this.url,
  });
}
