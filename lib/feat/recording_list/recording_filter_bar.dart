import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/recording_list/recording_filters.dart';

/// Filter/sort controls for the Recordings list: a "Has tune link" toggle and
/// a name/date sort menu. Mirrors the tune list's filter bar, scaled down.
class RecordingFilterBar extends ConsumerWidget {
  const RecordingFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(recordingFiltersProvider);
    final notifier = ref.read(recordingFiltersProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ChipMenu<TuneLinkFilter>(
            label: 'Tune link',
            value: filters.tuneLink,
            valueLabel: _tuneLinkLabel,
            isDefault: filters.tuneLink == TuneLinkFilter.any,
            options: const [
              (TuneLinkFilter.any, 'Any'),
              (TuneLinkFilter.hasTune, 'Has tune'),
              (TuneLinkFilter.noTune, 'No tune'),
            ],
            onChanged: notifier.setTuneLink,
          ),
          _ChipMenu<RecordingSort>(
            label: 'Sort',
            value: filters.sort,
            valueLabel: _sortLabel,
            isDefault: filters.sort == RecordingSort.dateAdded,
            options: const [
              (RecordingSort.dateAdded, 'Newest first'),
              (RecordingSort.nameAZ, 'Name A–Z'),
              (RecordingSort.nameZA, 'Name Z–A'),
            ],
            onChanged: notifier.setSort,
          ),
          if (filters.isActive)
            TextButton(
              onPressed: notifier.clear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }
}

String _sortLabel(RecordingSort s) => switch (s) {
  RecordingSort.dateAdded => 'Newest',
  RecordingSort.nameAZ => 'A–Z',
  RecordingSort.nameZA => 'Z–A',
};

String _tuneLinkLabel(TuneLinkFilter f) => switch (f) {
  TuneLinkFilter.any => 'Any',
  TuneLinkFilter.hasTune => 'Has tune',
  TuneLinkFilter.noTune => 'No tune',
};

/// Compact chip that opens a popup menu of options. Shows just [label] at the
/// default value; shows `label: value` and an active style otherwise.
class _ChipMenu<T> extends StatelessWidget {
  final String label;
  final T value;
  final String Function(T) valueLabel;
  final bool isDefault;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const _ChipMenu({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.isDefault,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = !isDefault;

    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final (optValue, optLabel) in options)
          PopupMenuItem<T>(
            value: optValue,
            child: Row(
              children: [
                if (optValue == value)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(optLabel),
              ],
            ),
          ),
      ],
      child: Chip(
        label: Text(active ? '$label: ${valueLabel(value)}' : label),
        labelStyle: TextStyle(
          fontSize: 13,
          color: active ? scheme.onSecondaryContainer : scheme.onSurface,
        ),
        backgroundColor: active ? scheme.secondaryContainer : null,
        side: BorderSide(color: scheme.outlineVariant),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: const Icon(Icons.arrow_drop_down, size: 18),
      ),
    );
  }
}
