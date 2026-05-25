import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';

abstract class TuneSource {
  String get name;

  Future<List<RemoteTune>> search(String query, {String? type, String? key});

  Future<TunesCompanion> resolve(RemoteTune tune);
}
