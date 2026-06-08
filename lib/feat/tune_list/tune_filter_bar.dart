import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/tune_list/tune_filters.dart';
import 'package:tune_trove/feat/tune_list/tune_list_item.dart'
    show tuneStatusToString;
import 'package:tune_trove/model/tables/tunes.dart';

class TuneFilterBar extends ConsumerStatefulWidget {
  const TuneFilterBar({super.key});

  @override
  ConsumerState<TuneFilterBar> createState() => _TuneFilterBarState();
}

class _TuneFilterBarState extends ConsumerState<TuneFilterBar> {
  bool _searchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Persisted query (set last session of this app run) reopens with
    // the bar so the user sees what's filtering their list.
    final initial = ref.read(tuneFiltersProvider).nameQuery;
    if (initial.isNotEmpty) {
      _searchExpanded = true;
      _searchController.text = initial;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (_searchExpanded) {
        _searchFocus.requestFocus();
      } else {
        _searchController.clear();
        ref.read(tuneFiltersProvider.notifier).setNameQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(tuneFiltersProvider);
    final notifier = ref.read(tuneFiltersProvider.notifier);
    final availableGenres = ref.watch(availableGenresProvider);
    final availableKeys = ref.watch(availableKeysProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.search_off : Icons.search),
            tooltip: _searchExpanded ? 'Close search' : 'Search by name',
            visualDensity: VisualDensity.compact,
            onPressed: _toggleSearch,
          ),
          if (_searchExpanded)
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Filter by name…',
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setNameQuery('');
                            setState(() {});
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onChanged: (v) {
                  notifier.setNameQuery(v);
                  setState(() {}); // refresh suffix icon
                },
              ),
            ),
          _FilterChipMenu<String?>(
            label: 'Genre',
            value: filters.genre,
            displayValue: (g) => g,
            options: [
              const _FilterOption<String?>(value: null, label: 'Any'),
              for (final g in availableGenres)
                _FilterOption<String?>(value: g, label: g),
            ],
            onChanged: notifier.setGenre,
            onClear: () => notifier.setGenre(null),
          ),
          _FilterChipMenu<TuneType?>(
            label: 'Type',
            value: filters.type,
            displayValue: (t) => t?.name,
            options: [
              const _FilterOption<TuneType?>(value: null, label: 'Any'),
              for (final t in TuneType.values)
                _FilterOption<TuneType?>(value: t, label: t.name),
            ],
            onChanged: notifier.setType,
            onClear: () => notifier.setType(null),
          ),
          _FilterChipMenu<TuneStatus?>(
            label: 'Status',
            value: filters.status,
            displayValue: (s) => s == null ? null : tuneStatusToString(s),
            options: [
              const _FilterOption<TuneStatus?>(value: null, label: 'Any'),
              for (final s in TuneStatus.values)
                _FilterOption<TuneStatus?>(
                  value: s,
                  label: tuneStatusToString(s),
                ),
            ],
            onChanged: notifier.setStatus,
            onClear: () => notifier.setStatus(null),
          ),
          _FilterChipMenu<String?>(
            label: 'Key',
            value: filters.key,
            displayValue: (k) => k,
            options: [
              const _FilterOption<String?>(value: null, label: 'Any'),
              for (final k in availableKeys)
                _FilterOption<String?>(value: k, label: k),
            ],
            onChanged: notifier.setKey,
            onClear: () => notifier.setKey(null),
          ),
          _FilterChipMenu<TuneSort>(
            label: 'Sort',
            value: filters.sort,
            // Always show the current sort — there's no "unset" state.
            displayValue: (s) => switch (s) {
              TuneSort.grouped => 'Grouped',
              TuneSort.newestFirst => 'Newest',
              TuneSort.oldestFirst => 'Oldest',
              TuneSort.nameAZ => 'A–Z',
              TuneSort.nameZA => 'Z–A',
              TuneSort.statusTodoFirst => 'To-do first',
              TuneSort.statusMasteredFirst => 'Mastered first',
            },
            isDefault: filters.sort == TuneSort.grouped,
            options: const [
              _FilterOption(
                value: TuneSort.grouped,
                label: 'Grouped (genre · type)',
              ),
              _FilterOption(value: TuneSort.newestFirst, label: 'Newest first'),
              _FilterOption(value: TuneSort.oldestFirst, label: 'Oldest first'),
              _FilterOption(value: TuneSort.nameAZ, label: 'Name A–Z'),
              _FilterOption(value: TuneSort.nameZA, label: 'Name Z–A'),
              _FilterOption(
                value: TuneSort.statusTodoFirst,
                label: 'Status: to-do → mastered',
              ),
              _FilterOption(
                value: TuneSort.statusMasteredFirst,
                label: 'Status: mastered → to-do',
              ),
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

class _FilterOption<T> {
  final T value;
  final String label;
  const _FilterOption({required this.value, required this.label});
}

/// Compact chip that opens a popup menu of options. Shows just the
/// label when at default ("Type"); shows label + value when active
/// ("Type: jig") with an inline clear affordance — except for filters
/// where there's no notion of "unset" (e.g. sort), in which case the
/// `isDefault` flag controls whether the chip looks active.
class _FilterChipMenu<T> extends StatelessWidget {
  final String label;
  final T value;
  final String? Function(T) displayValue;
  final List<_FilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback? onClear;
  final bool? isDefault;

  const _FilterChipMenu({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.options,
    required this.onChanged,
    this.onClear,
    this.isDefault,
  });

  bool get _isActive {
    if (isDefault != null) return !isDefault!;
    final v = displayValue(value);
    return v != null && v.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _isActive;
    final shownValue = displayValue(value);
    final chipLabel = active && shownValue != null && shownValue.isNotEmpty
        ? '$label: $shownValue'
        : label;

    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final opt in options)
          PopupMenuItem<T>(
            value: opt.value,
            child: Row(
              children: [
                if (opt.value == value)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(opt.label),
              ],
            ),
          ),
      ],
      child: Chip(
        label: Text(chipLabel),
        labelStyle: TextStyle(
          fontSize: 13,
          color: active ? scheme.onSecondaryContainer : scheme.onSurface,
        ),
        backgroundColor: active ? scheme.secondaryContainer : null,
        side: BorderSide(color: scheme.outlineVariant),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: active && onClear != null ? onClear : null,
        avatar: active ? null : const Icon(Icons.arrow_drop_down, size: 18),
      ),
    );
  }
}
