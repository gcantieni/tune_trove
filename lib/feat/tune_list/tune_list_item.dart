import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/tables/tunes.dart';

String tuneStatusToString(TuneStatus? status) {
  if (status == null) {
    return "";
  }

  switch (status) {
    case TuneStatus.todo:
      return "Todo";
    case TuneStatus.canPlay:
      return "Can play";
    case TuneStatus.canStart:
      return "Can start";
    case TuneStatus.inSet:
      return "In set";
    case TuneStatus.mastered:
      return "Mastered";
  }
}

int _statusDotCount(TuneStatus? status) {
  switch (status) {
    case null:
      return 0;
    case TuneStatus.todo:
      return 1;
    case TuneStatus.canPlay:
      return 2;
    case TuneStatus.canStart:
      return 3;
    case TuneStatus.inSet:
      return 4;
    case TuneStatus.mastered:
      return 5;
  }
}

Widget _buildDotRow(int filled, Color primary) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final isFilled = i < filled;
      return Container(
        width: 8,
        height: 8,
        margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFilled ? primary : Colors.transparent,
          border: Border.all(
            color: isFilled ? primary : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
      );
    }),
  );
}

Future<void> _pickStatus(BuildContext context, WidgetRef ref, Tune tune) async {
  final primary = Theme.of(context).colorScheme.primary;
  final result = await showDialog<TuneStatus>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Set status'),
      children: TuneStatus.values
          .map(
            (s) => SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(s),
              child: Row(
                children: [
                  _buildDotRow(_statusDotCount(s), primary),
                  const SizedBox(width: 12),
                  Text(tuneStatusToString(s)),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );

  if (result == null) return;

  await ref
      .read(databaseProvider)
      .tuneDao
      .updateTune(
        TunesCompanion(id: drift.Value(tune.id), status: drift.Value(result)),
      );
}

class TuneListItem extends ConsumerWidget {
  const TuneListItem({required this.tune});

  final Tune tune;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var subtitleString = "";

    if (tune.key != null) {
      subtitleString += tune.key!;
    }

    if (tune.type != null) {
      if (tune.key != null) {
        subtitleString += " ";
      }
      subtitleString += tune.type!.name;
    }

    if (tune.from != null && tune.from!.isNotEmpty) {
      if (subtitleString.isNotEmpty) subtitleString += " ";
      subtitleString += "from ${tune.from}";
    }

    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: () => context.push('/tune_list/${tune.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tune.name, style: Theme.of(context).textTheme.titleMedium),
                if (subtitleString.isNotEmpty || tune.status != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (subtitleString.isNotEmpty)
                        Expanded(
                          child: Text(
                            subtitleString,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      InkWell(
                        onTap: () => _pickStatus(context, ref, tune),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: _buildDotRow(
                            _statusDotCount(tune.status),
                            primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
