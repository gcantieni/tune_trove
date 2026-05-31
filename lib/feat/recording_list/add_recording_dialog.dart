import 'package:flutter/material.dart';

import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';

/// Shows the "Add recording" dialog with the [RecordingFormWidget], optionally
/// pre-filled with [initialUrl] / [initialName] (used when a file is shared into
/// the app). Shared by the Recordings FAB and the app-root import controller, so
/// it must work from any [context] under a [Navigator] (e.g. the root navigator).
Future<void> showAddRecordingDialog(
  BuildContext context, {
  String? initialUrl,
  String? initialName,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: SizedBox(
        width: 600,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add recording',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                RecordingFormWidget(
                  initialUrl: initialUrl,
                  initialName: initialName,
                  onSubmitted: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
