// Contribution / IP-attribution report for the repo.
//
// Usage:
//   dart scripts/stats.dart
//
// Reports, per contributor, across the hand-authored source set (generated code,
// vendored libraries, platform boilerplate, raw data and DB-migration scaffolding
// excluded):
//   - Surviving lines : non-blank lines still authored by them at HEAD
//                       (git blame -w -M -C, so reformatted/moved lines stay with
//                        their original author)
//   - Churn           : total lines added+deleted over all history (effort, incl.
//                       code later rewritten)
//   - Net             : added - deleted over history
//   - Commits         : non-merge commit count
//   - Files authored  : files this person originally created
//   - IP%             : weighted average of the four percentage metrics (see weights)
// Plus a per-feature ownership breakdown of surviving lines.

// Regex patterns are kept uniformly raw for safety — so adding a `\.` to one
// later can't silently turn into an escape — even when a given pattern has no
// backslashes yet.
// ignore_for_file: unnecessary_raw_strings

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// What counts as authored IP.
// ---------------------------------------------------------------------------

const _extensions = [
  'dart', 'swift', 'kt', 'java', 'py', 'sh', 'yaml', 'yml', 'json', 'xml',
  'gradle', 'toml',
];

/// Source extensions we measure.
final _includeRe = RegExp(r'\.(' + _extensions.join('|') + r')$');

/// Everything excluded from IP attribution, OR-joined. Applied both to the
/// current file list (blame pass) and to historical `git log` paths (churn pass).
final _excludeRe = RegExp([
  // Drift / Freezed generated Dart, and the dependency lockfile.
  r'\.(g|freezed)\.dart$',
  r'pubspec\.lock',
  // Flutter platform boilerplate from `flutter create` (custom native bridges
  // CloudKitSyncBridge.swift / MusicKitBridge.swift are kept).
  r'^(android|linux|windows|web)/',
  r'^ios/(Runner/(AppDelegate|Assets\.xcassets)|RunnerTests)/',
  r'^macos/(Runner/(AppDelegate|MainFlutterWindow)|RunnerTests)/',
  // Raw tune data (JSON collections + license texts) and bundled third-party JS.
  // `^data/` is the dataset's historical location before it moved under assets/ —
  // kept so the churn pass doesn't credit the huge generated JSON to whoever
  // imported it.
  r'^(assets/(data/|abcjs/)|data/)',
  // One-time scraper scripts that generate assets/data/*.json.
  r'^lib/remote_tune_sources/[^/]+_scrape\.dart$',
  // Drift-generated artifacts: migration steps, schema snapshots (JSON + Dart).
  r'(database\.steps\.dart|drift_schema.*\.json|test/drift/.*/generated/)',
  // Hand-written DB migration scaffolding (migration tests) — boilerplate that
  // verifies schema upgrades, regenerated/extended every schema bump.
  r'(^test/drift/|migration_test\.dart$)',
].join('|'));

// ---------------------------------------------------------------------------
// IP-score weighting. The headline "IP%" column is a weighted average of the four
// percentage metrics below. Weights are relative — they're normalized to sum to 1,
// so leaving them all equal gives a plain 1/N average. Bump any weight to emphasize
// that signal (e.g. wLines = 2 to favor surviving code over raw activity). Net is
// intentionally not scored (it's directional and can be negative).
// ---------------------------------------------------------------------------
const wLines = 1.0; // surviving (blame) lines %
const wChurn = 1.0; // total churn (added+deleted) %
const wCommits = 1.0; // commit count %
const wAuthored = 1.0; // files originally authored %

late final String _repoRoot;

void main() {
  final scriptDir = File.fromUri(Platform.script).parent.path;
  _repoRoot = _git(['-C', scriptDir, 'rev-parse', '--show-toplevel']).trim();

  final files = _includedFiles();

  // Per-author metrics.
  final surviving = <String, int>{}; // surviving (blame) lines
  final added = <String, int>{};
  final deleted = <String, int>{};
  final commits = <String, int>{};
  final authored = <String, int>{}; // files originally created

  // Per-module (feature) surviving lines, and per-module per-author breakdown.
  final moduleTotal = <String, int>{};
  final moduleByAuthor = <String, Map<String, int>>{};

  _collectSurvivingLines(files, surviving, moduleTotal, moduleByAuthor);
  _collectChurnAndCommits(added, deleted, commits);
  _collectFilesAuthored(files, authored);

  final out = StringBuffer();
  _writeOverallTable(out, surviving, added, deleted, commits, authored);
  _writeFeatureTable(out, moduleTotal, moduleByAuthor, surviving);
  stdout.write(out);
}

// ---------------------------------------------------------------------------
// Data collection.
// ---------------------------------------------------------------------------

/// Tracked files that count as authored source.
List<String> _includedFiles() => _git(['ls-files'])
    .split('\n')
    .where((f) => f.isNotEmpty)
    .where((f) => _includeRe.hasMatch(f) && !_excludeRe.hasMatch(f))
    .toList();

/// Blame every included file at HEAD (whitespace/move-insensitive, blank lines
/// dropped) and tally surviving lines per author, tagged with the file's module.
void _collectSurvivingLines(
  List<String> files,
  Map<String, int> surviving,
  Map<String, int> moduleTotal,
  Map<String, Map<String, int>> moduleByAuthor,
) {
  for (final file in files) {
    final module = _moduleOf(file);
    final blame =
        _git(['blame', '--line-porcelain', '-w', '-M', '-C', 'HEAD', '--', file]);
    var author = '';
    for (final line in blame.split('\n')) {
      if (line.startsWith('author ')) {
        author = _normalize(line.substring('author '.length));
      } else if (line.startsWith('\t') && line.substring(1).trim().isNotEmpty) {
        surviving.update(author, (v) => v + 1, ifAbsent: () => 1);
        moduleTotal.update(module, (v) => v + 1, ifAbsent: () => 1);
        moduleByAuthor
            .putIfAbsent(module, () => {})
            .update(author, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }
}

/// Walk all non-merge history once for churn (added/deleted) and commit counts,
/// applying the same include/exclude filters to each numstat path.
void _collectChurnAndCommits(
  Map<String, int> added,
  Map<String, int> deleted,
  Map<String, int> commits,
) {
  const marker = '__C__';
  final log = _git(['log', '--no-merges', '--numstat', '--format=$marker%an', 'HEAD']);
  var author = '';
  for (final line in log.split('\n')) {
    if (line.startsWith(marker)) {
      author = _normalize(line.substring(marker.length));
      commits.update(author, (v) => v + 1, ifAbsent: () => 1);
      continue;
    }
    // numstat row: "<added>\t<deleted>\t<path>". Split on whitespace so the
    // last token is the new path even on "old => new" renames.
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.length < 3) continue;
    if (tokens[0] == '-') continue; // binary file
    final add = int.tryParse(tokens[0]);
    if (add == null) continue; // blank / non-numstat line
    final del = int.tryParse(tokens[1]) ?? 0;
    final path = tokens.last;
    if (!_includeRe.hasMatch(path) || _excludeRe.hasMatch(path)) continue;
    added.update(author, (v) => v + add, ifAbsent: () => add);
    deleted.update(author, (v) => v + del, ifAbsent: () => del);
  }
}

/// Attribute each file to the author of its original (oldest) add commit,
/// following renames.
void _collectFilesAuthored(List<String> files, Map<String, int> authored) {
  for (final file in files) {
    final adds = _git(
      ['log', '--follow', '--diff-filter=A', '--format=%an', '--', file],
    ).split('\n').where((l) => l.isNotEmpty).toList();
    if (adds.isEmpty) continue;
    final origin = _normalize(adds.last); // oldest add = originator
    authored.update(origin, (v) => v + 1, ifAbsent: () => 1);
  }
}

// ---------------------------------------------------------------------------
// Tables.
// ---------------------------------------------------------------------------

const _t1Widths = [20, 7, 8, 7, 8, 7, 9, 8, 8, 8, 9];
const _t1Seps = ['', ' ', '   ', ' ', '   ', ' ', ' ', '   ', ' ', '   ', ' '];

String _t1Row(List<String> cells) {
  final b = StringBuffer();
  for (var i = 0; i < cells.length; i++) {
    b.write(_t1Seps[i]);
    b.write(i == 0 ? cells[i].padRight(_t1Widths[i]) : cells[i].padLeft(_t1Widths[i]));
  }
  return b.toString();
}

void _writeOverallTable(
  StringBuffer out,
  Map<String, int> surviving,
  Map<String, int> added,
  Map<String, int> deleted,
  Map<String, int> commits,
  Map<String, int> authored,
) {
  final authors = <String>{
    ...surviving.keys,
    ...added.keys,
    ...deleted.keys,
    ...commits.keys,
    ...authored.keys,
  };

  final lt = _sum(surviving.values);
  final at = _sum(added.values);
  final dt = _sum(deleted.values);
  final ct = _sum(commits.values);
  final ft = _sum(authored.values);
  final churnTotal = at + dt;
  const wsum = wLines + wChurn + wCommits + wAuthored;

  double scoreOf(String name) {
    final lp = _pctOf(surviving[name], lt);
    final chp = _pctOf((added[name] ?? 0) + (deleted[name] ?? 0), churnTotal);
    final cp = _pctOf(commits[name], ct);
    final ap = _pctOf(authored[name], ft);
    return wsum > 0 ? (wLines * lp + wChurn * chp + wCommits * cp + wAuthored * ap) / wsum : 0;
  }

  final ranked = authors.toList()..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));

  out.writeln();
  out.writeln(_t1Row([
    'Contributor', 'IP%', 'Lines', 'Lines%', 'Churn', 'Churn%', 'Net',
    'Commits', 'Commit%', 'Authored', 'Authored%',
  ]));
  out.writeln(_t1Row([for (final w in _t1Widths) '-' * w]));
  for (final name in ranked) {
    final lc = surviving[name] ?? 0;
    final ch = (added[name] ?? 0) + (deleted[name] ?? 0);
    final net = (added[name] ?? 0) - (deleted[name] ?? 0);
    final cc = commits[name] ?? 0;
    final fc = authored[name] ?? 0;
    out.writeln(_t1Row([
      name,
      _pct(scoreOf(name)),
      '$lc', _pct(_pctOf(lc, lt)),
      '$ch', _pct(_pctOf(ch, churnTotal)),
      '$net',
      '$cc', _pct(_pctOf(cc, ct)),
      '$fc', _pct(_pctOf(fc, ft)),
    ]));
  }
  out.writeln(_t1Row([
    'TOTAL', '100%', '$lt', '100%', '$churnTotal', '100%', '${at - dt}',
    '$ct', '100%', '$ft', '100%',
  ]));
}

void _writeFeatureTable(
  StringBuffer out,
  Map<String, int> moduleTotal,
  Map<String, Map<String, int>> moduleByAuthor,
  Map<String, int> surviving,
) {
  final authors = surviving.keys.toList()
    ..sort((a, b) => (surviving[b] ?? 0).compareTo(surviving[a] ?? 0));
  final modules = moduleTotal.keys.toList()
    ..sort((a, b) => moduleTotal[b]!.compareTo(moduleTotal[a]!));

  String row(String module, String lines, List<String> cells) {
    final b = StringBuffer()
      ..write(module.padRight(22))
      ..write(' ')
      ..write(lines.padLeft(8));
    for (final c in cells) {
      b
        ..write(' ')
        ..write(c.padLeft(13));
    }
    return b.toString();
  }

  String trunc(String s) => s.length > 13 ? s.substring(0, 13) : s;

  out.writeln();
  out.writeln(row('Feature / module', 'Lines', [for (final a in authors) trunc(a)]));
  out.writeln(row('-' * 22, '-' * 8, [for (final _ in authors) '-' * 13]));
  for (final m in modules) {
    final total = moduleTotal[m]!;
    final byAuthor = moduleByAuthor[m] ?? const {};
    out.writeln(row(m, '$total', [
      for (final a in authors) _pct(_pctOf(byAuthor[a], total)),
    ]));
  }
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// Maps a repo path to its feature/module label.
String _moduleOf(String file) {
  final parts = file.split('/');
  if (file.startsWith('lib/feat/') && parts.length >= 3) return 'feat/${parts[2]}';
  if (file.startsWith('lib/')) return parts.length >= 3 ? 'lib/${parts[1]}' : 'lib/(root)';
  if (file.startsWith('test/')) return 'tests';
  if (file.startsWith('ios/') || file.startsWith('macos/')) return 'native';
  if (file.startsWith('scripts/')) return 'scripts';
  return 'other';
}

/// Collapses internal whitespace runs so a name configured with stray double
/// spaces isn't split into a separate contributor.
String _normalize(String name) => name.replaceAll(RegExp(r'\s+'), ' ').trim();

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);

double _pctOf(int? value, int total) => total > 0 ? (value ?? 0) / total * 100 : 0;

String _pct(double v) => '${v.toStringAsFixed(1)}%';

/// Runs git in the repo root and returns stdout. git's own non-zero exits (e.g.
/// blame on an unblameable file) yield empty/partial output rather than throwing.
String _git(List<String> args) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: args.first == '-C' ? null : _repoRoot,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return result.stdout as String;
}
