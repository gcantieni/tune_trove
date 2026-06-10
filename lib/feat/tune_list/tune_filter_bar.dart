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

  void _showFilterSheet(BuildContext context) {
    // Capture the container before entering the modal route so _FilterSheet
    // can subscribe reactively without needing any InheritedWidget lookups
    // inside the sheet (which triggers the "not our descendant" assertion).
    final container = ProviderScope.containerOf(context, listen: false);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _FilterSheet(container: container),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(tuneFiltersProvider);
    final notifier = ref.read(tuneFiltersProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _searchExpanded
          ? _buildSearchBar(notifier)
          : _buildFilterRow(context, filters, notifier),
    );
  }

  Widget _buildSearchBar(TuneFiltersNotifier notifier) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close search',
          visualDensity: VisualDensity.compact,
          onPressed: _toggleSearch,
        ),
        Expanded(
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
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    TuneFilters filters,
    TuneFiltersNotifier notifier,
  ) {
    final activeCount = [
      filters.genre,
      filters.type,
      filters.status,
      filters.key,
    ].where((v) => v != null).length;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search by name',
          visualDensity: VisualDensity.compact,
          onPressed: _toggleSearch,
        ),
        const Spacer(),
        _FilterButton(
          activeCount: activeCount,
          onTap: () => _showFilterSheet(context),
          onClear: filters.hasFacets ? notifier.clearFacets : null,
        ),
        const SizedBox(width: 6),
        _FilterChipMenu<TuneSort>(
          label: 'Sort',
          value: filters.sort,
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter button chip
// ---------------------------------------------------------------------------

/// Chip that opens the filter sheet on body-tap and clears facets on the X.
/// Uses ActionChip so onPressed and onDeleted have separate hit-test regions —
/// a GestureDetector(child: Chip) fires BOTH when the X is tapped.
class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterButton({
    required this.activeCount,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeCount > 0;
    final label = active ? 'Filter · $activeCount' : 'Filter';

    return InputChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: active ? scheme.onSecondaryContainer : scheme.onSurface,
        ),
      ),
      backgroundColor: active ? scheme.secondaryContainer : null,
      side: BorderSide(color: scheme.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: active ? null : const Icon(Icons.tune, size: 16),
      deleteIcon: active ? const Icon(Icons.close, size: 16) : null,
      onDeleted: onClear,
      onPressed: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bottom sheet — plain StatefulWidget, no InheritedWidget Riverpod
// lookups inside the modal (avoids the "not our descendant" assertion).
// ---------------------------------------------------------------------------

class _FilterSheet extends StatefulWidget {
  final ProviderContainer container;
  const _FilterSheet({required this.container});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TuneFilters _filters;
  late List<String> _genres;
  late List<String> _keys;
  ProviderSubscription<TuneFilters>? _sub;

  TuneFiltersNotifier get _notifier =>
      widget.container.read(tuneFiltersProvider.notifier);

  @override
  void initState() {
    super.initState();
    _filters = widget.container.read(tuneFiltersProvider);
    _genres = widget.container.read(availableGenresProvider);
    _keys = widget.container.read(availableKeysProvider);
    _sub = widget.container.listen<TuneFilters>(tuneFiltersProvider, (_, next) {
      setState(() {
        _filters = next;
        _genres = widget.container.read(availableGenresProvider);
        _keys = widget.container.read(availableKeysProvider);
      });
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = _notifier;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_filters.hasFacets)
                  TextButton(
                    onPressed: () {
                      notifier.clearFacets();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FilterChipMenu<String?>(
                  label: 'Genre',
                  value: _filters.genre,
                  displayValue: (g) => g,
                  options: [
                    const _FilterOption<String?>(value: null, label: 'Any'),
                    for (final g in _genres)
                      _FilterOption<String?>(value: g, label: g),
                  ],
                  onChanged: notifier.setGenre,
                  onClear: () => notifier.setGenre(null),
                ),
                _FilterChipMenu<TuneType?>(
                  label: 'Type',
                  value: _filters.type,
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
                  value: _filters.status,
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
                  value: _filters.key,
                  displayValue: (k) => k,
                  options: [
                    const _FilterOption<String?>(value: null, label: 'Any'),
                    for (final k in _keys)
                      _FilterOption<String?>(value: k, label: k),
                  ],
                  onChanged: notifier.setKey,
                  onClear: () => notifier.setKey(null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chip + option types
// ---------------------------------------------------------------------------

class _FilterOption<T> {
  final T value;
  final String label;
  const _FilterOption({required this.value, required this.label});
}

/// Compact chip that opens a popup menu of options.
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
