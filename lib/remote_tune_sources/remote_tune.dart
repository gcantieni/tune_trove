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

  /// For sources that expose multiple transcriptions ("settings") of the same
  /// tune (thesession.org), the id of this particular setting. Distinguishes
  /// otherwise-identical results sharing a [sourceId].
  final int? settingId;

  /// When this setting/transcription was published, if the source records it.
  /// Used to sort and to show an "X years ago" hint in the picker.
  final DateTime? date;

  /// Who contributed this setting, if the source records it.
  final String? contributor;

  const RemoteTune({
    required this.name,
    required this.sourceName,
    this.type,
    this.key,
    this.genre,
    this.sourceId,
    this.abc,
    this.url,
    this.settingId,
    this.date,
    this.contributor,
  });
}
