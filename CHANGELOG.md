# Changelog

All notable changes to Tune Trove are documented here. Versions correspond to
the `version` field in `pubspec.yaml`. The newest release is listed first.

## 1.0.33 — 2026-06-10

### Added

- Playback card now shows transport controls when a track is playing: skip back 10 seconds, skip forward 10 seconds, and play/pause.
- Loop and play/pause buttons move to the transport row at the bottom of the expanded card, with the collapsed card showing only the play button.

## 1.0.32 - 2026-06-09

### Changed

- Compact app bar and bottom navigation bar to reclaim vertical screen space.
- Tune search modal is now full-screen with an explicit close button, giving
  sheet music previews and long tune names more room.
- Swipe from the left edge of the screen now triggers back navigation instead
  of opening the side drawer; the drawer remains accessible via the menu button.

## 1.0.31 — 2026-06-09

### Changed

- App icon refinements.

## 1.0.30 — 2026-06-08

### Added

- Export a full backup of your library as a ZIP file from Settings.

### Changed

- Tunes are now grouped by genre and type by default.

## 1.0.29 — 2026-06-08

### Added

- Apple Music links now open directly in the Music app.

### Changed

- Improved cross-tab navigation: navigating to a tab you're already on returns
  to the top of that tab rather than doing nothing.
- Simplified navigation with a hamburger menu for secondary destinations.

### Fixed

- Loop playback no longer snaps to an incorrect position when restarting.

## 1.0.28 — 2026-06-04

### Changed

- Bug fixes and performance improvements.

## 1.0.27 — 2026-06-04

### Added

- Tune search now lets you browse and audition every available match before
  importing: results from all sources appear in one list as expandable cards
  with rendered notation, a play button, and a tempo slider. For thesession.org,
  each alternate setting is shown separately, sorted oldest-first with a
  publishing-age hint, so you can pick the version you like best.
- The Recordings list can now be filtered to those linked to a tune and sorted
  by name (A–Z / Z–A) or most recently added.

## 1.0.24 — 2026-06-01

- Voice memo imports on iOS now keep the original recording's filename.
- Share extension refinements and bug fixes.

## 1.0.23 — 2026-06-01

### Added

- Swipe-to-delete for tunes and recordings.

### Changed

- iCloud sync reliability improvements.
- Expanded unit test coverage.
- Bug fixes (including a random crash addressed by pinning the SQLite version).

## 1.0.22 — 2026-06-01

### Added

- Audio import: drag-and-drop on macOS, file import on iOS, and system Share
  sheet support via iOS and macOS Share Extensions (with App Group integration).
- Share audio from the Voice Memos and Apple Music apps.
- Reorderable set lists and an improved set-deletion experience.
- Genres support plus assorted UI and editing improvements.
- Stats scripting for tracking project metrics.

### Changed

- UI polish for the synth/player and play buttons.
- Migration fixes.

## 1.0.21 — 2026-05-28

### Added

- Basic MIDI player with tempo control.

### Changed

- Navbar reordering and updated license information.

## 1.0.20 — 2026-05-28

### Added

- Many new tune collections (Nelson's New England tunes, Meikle, Mulholland,
  Ryan's Mammoth, Pringle, O'Neill's 1850, and more).
- Content library search ordering synced across devices.

### Changed

- Improved bundling defaults and updated licenses.
- Bug fixes.

## 1.0.19 — 2026-05-28

- Re-release after an interrupted upload.

## 1.0.18 — 2026-05-28

### Added

- Source confirmation sync.
- Numerous additional tune sources (Aird, Neil Gow, Fraser, Edinburgh
  Repository of Music, Kidson, NEFR, Athole) with per-source toggles and
  source types.
- Copyright feedback email link.

### Changed

- Recording picker refactor; collections alphabetized.

## 1.0.17 — 2026-05-26

### Added

- Last-write-wins conflict resolution for CloudKit sync.

### Changed

- Navigation renamed and sizing fixes.

## 1.0.16 — 2026-05-25

### Added

- Pull-to-sync gesture.

## 1.0.15 — 2026-05-25

### Added

- iCloud/CloudKit sync with piecewise, dirty-marker-based syncing (including
  deletions).
- Settings page with content-source selection and copyright display; tunes from
  inactive sources are hidden.
- More tune collections, sourced from raw TheSession data on GitHub.
- Key picker on the tune details page; zoomable, dark-themed sheet music.
- App drawer (hamburger) navigation and green theme color.

### Changed

- Migrated to `flutter_inappwebview` and removed the CocoaPods dependency
  entirely.
- Normalized search.

## 1.0.14 — 2026-05-22

### Added

- Alternative keys for tunes within sets.

## 1.0.13 — 2026-05-22

### Added

- Saving and loading of loop timestamps.
- Floating play/pause button.
- Per-tune-recording performed-key tracking.
- High-fidelity (1/100s) playback and loop tracking.

## 1.0.12 — 2026-05-21

- Maintenance release.

## 1.0.11 — 2026-05-21

- Maintenance release.

## 1.0.10 — 2026-05-21

### Added

- Apple Music support on iOS and macOS via the MusicKit entitlement.

### Changed

- Flutter upgrade and launch reference fix.

## 1.0.9 — 2026-05-21

### Added

- Release app icon and updated chest interior artwork.

## 1.0.7 — 2026-05-21

### Added

- Launch image / launch screen.

## 1.0.6 — 2026-05-20

### Added

- App icon and Android icons.

## 1.0.5 — 2026-05-13

- Maintenance release.

## 1.0.4 — 2026-05-13

### Added

- Delete button for recordings; name entry in the recording picker.

### Changed

- Upgraded `just_audio` and Riverpod; audio session updates.
- Privacy declarations (photo library usage, non-exempt encryption).
- Bug fixes.

## 1.0.0 — 2025-07-11

Initial release. Core foundation built out over the project's early development:

### Added

- Tune catalog backed by a Drift (SQLite) database with reactive Riverpod
  providers and schema migrations.
- Tune entry, detail (read/edit toggle), and list views with filter, search,
  sort, and inline status editing.
- ABC notation rendering as sheet music.
- Recordings with URL launching, and bidirectional tune↔recording linking with
  editable timestamp markers.
- Set list management referencing tunes.
- Audio playback with looping (bounded, two-thumb loop control), playback-speed
  control, and local file playback behind a pluggable music-player interface.
- TheSession.org tune scraping/import with debounced autocomplete.
- GoRouter-based navigation with a bottom navbar and directional slide
  transitions; OS theme support.
- Apple Music (MusicKit) integration (initially mocked pending entitlement).
- Rebranded to Tune Trove.
