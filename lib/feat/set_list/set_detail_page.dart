import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/set_list/set_tune_card.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/sets_provider.dart';
import 'package:tune_trove/routing/cross_tab_nav.dart';
import 'package:tune_trove/shared_widgets/tune_picker_dialog.dart';

class SetDetailPage extends ConsumerStatefulWidget {
  const SetDetailPage({required this.setId, this.returnTo, super.key});

  final int setId;

  /// When opened from another tab via a cross-tab link, the origin location its
  /// back arrow returns to. Null when reached within the Sets tab.
  final String? returnTo;

  @override
  ConsumerState<SetDetailPage> createState() => _SetDetailPageState();
}

class _SetDetailPageState extends ConsumerState<SetDetailPage> {
  late final TextEditingController _nameController;
  Timer? _debounce;
  bool _nameInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref
          .read(databaseProvider)
          .setDao
          .updateSet(
            TuneSetsCompanion(
              id: Value(widget.setId),
              name: Value(_nameController.text),
              modifiedAt: Value(DateTime.now()),
            ),
          );
    });
  }

  void _showAddTuneDialog(BuildContext context) {
    final dao = ref.read(databaseProvider);
    showDialog<void>(
      context: context,
      builder: (_) => TunePickerDialog(
        title: 'Add tune to set',
        onLibraryTune: (tune) {
          dao.setTuneDao.addTuneToSet(widget.setId, tune.id);
        },
        onRemoteTune: (companion) async {
          final tuneId = await dao.tuneDao.insertTune(
            companion.copyWith(createdAt: Value(DateTime.now())),
          );
          await dao.setTuneDao.addTuneToSet(widget.setId, tuneId);
        },
        onCreateNew: (name) async {
          final tuneId = await dao.tuneDao.insertTune(
            TunesCompanion.insert(name: name, createdAt: DateTime.now()),
          );
          await dao.setTuneDao.addTuneToSet(widget.setId, tuneId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(singleSetProvider(widget.setId));
    final tunesAsync = ref.watch(visibleSetTunesProvider(widget.setId));

    return setAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (tuneSet) {
        if (tuneSet == null) {
          return const Scaffold(body: Center(child: Text('Set not found')));
        }

        if (!_nameInitialized) {
          _nameInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _nameController.text = tuneSet.name;
          });
        }

        return Scaffold(
          appBar: AppBar(
            leading: originAwareLeading(context, widget.returnTo),
            title: TextField(
              controller: _nameController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Set name',
              ),
            ),
          ),
          body: tunesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tunes) => SyncRefreshIndicator(
              child: tunes.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.width * 0.25,
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text('No tunes yet — tap + to add one.'),
                          ),
                        ),
                      ],
                    )
                  : ReorderableListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16 + MediaQuery.of(context).size.width * 0.25,
                      ),
                      itemCount: tunes.length,
                      itemBuilder: (context, index) {
                        final entry = tunes[index];
                        return SetTuneCard(
                          key: ValueKey(entry.link.id),
                          entry: entry,
                          index: index,
                          onDelete: () => ref
                              .read(databaseProvider)
                              .setTuneDao
                              .removeTuneFromSet(entry.link.id),
                          onKeyChanged: (key) => ref
                              .read(databaseProvider)
                              .setTuneDao
                              .updateKey(entry.link.id, key),
                        );
                      },
                      onReorderItem: (oldIndex, newIndex) {
                        ref
                            .read(databaseProvider)
                            .setTuneDao
                            .reorderTune(widget.setId, oldIndex, newIndex);
                      },
                    ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add tune',
            onPressed: () => _showAddTuneDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
