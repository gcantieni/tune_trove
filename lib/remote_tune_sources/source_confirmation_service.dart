import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _keyPrefix = 'confirmed_source_';

/// Persists and queries which content sources the user has explicitly
/// confirmed. Uses SharedPreferences so confirmations survive app restarts.
///
/// Each confirmation is stored as a JSON object containing:
///   - sourceId
///   - confirmedAt (ISO 8601)
///   - licenseAcknowledged (the license string shown at confirmation time)
class SourceConfirmationService {
  final SharedPreferences _prefs;

  SourceConfirmationService(this._prefs);

  bool isConfirmed(String sourceId) =>
      _prefs.containsKey('$_keyPrefix$sourceId');

  Set<String> confirmedIds() {
    return _prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => k.substring(_keyPrefix.length))
        .toSet();
  }

  Future<void> confirm(String sourceId, String license) async {
    final payload = jsonEncode({
      'sourceId': sourceId,
      'confirmedAt': DateTime.now().toIso8601String(),
      'licenseAcknowledged': license,
    });
    await _prefs.setString('$_keyPrefix$sourceId', payload);
  }

  Future<void> revoke(String sourceId) async {
    await _prefs.remove('$_keyPrefix$sourceId');
  }
}
