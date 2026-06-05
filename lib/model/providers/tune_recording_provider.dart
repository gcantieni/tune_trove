import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/accessors/tune_recording_dao.dart';
import 'package:tune_trove/model/database_provider.dart';

final linksForRecordingProvider = StreamProvider.family
    .autoDispose<List<RecordedTune>, int>((ref, recordingId) {
      final db = ref.watch(databaseProvider);
      return db.tuneRecordingDao.watchLinksForRecording(recordingId);
    });

final recordingsForTuneProvider = StreamProvider.family
    .autoDispose<List<LinkedRecording>, int>((ref, tuneId) {
      final db = ref.watch(databaseProvider);
      return db.tuneRecordingDao.watchLinksForTune(tuneId);
    });

/// Recording ids that have at least one linked tune. Backs the Recordings
/// "Has tune link" filter.
final linkedRecordingIdsProvider = StreamProvider.autoDispose<Set<int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tuneRecordingDao.watchLinkedRecordingIds();
});
