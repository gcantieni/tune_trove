# Content Source Architecture

## Overview

The app is a content-agnostic platform. It ships with CC0/public-domain content active by default. Licensed content (NC-SA etc.) requires explicit user confirmation before it is searched, displayed, or counted anywhere in the UI. This is both a legal requirement and a core architectural invariant.

## The Registry

All known sources are declared in `lib/remote_tune_sources/content_source_registry.dart` as `allContentSources` — a const `List<ContentSourceMeta>`. Every source has:

| Field | Purpose |
|-------|---------|
| `id` | Stable identifier stored in SharedPreferences |
| `name` | Display name; also stored in `Tune.from` when a tune is imported |
| `license` | Human-readable license string shown in the confirmation dialog |
| `licenseUrl` | Optional link to the full license text |
| `attribution` | Full attribution line — must appear on every screen showing that source's content |
| `confirmationRequired` | `false` = always active (CC0/public domain); `true` = requires confirmation |
| `bundled` | Whether the content ships in the app binary |
| `hidden` | Fully inactive: excluded from settings UI, search, and tune display. Use when written permission is pending or the license situation is unresolved. |

**Current source classification:**

| ID | Name | Always active | Hidden |
|----|------|:---:|:---:|
| `oneills_1001` | O'Neill's 1001 | ✓ | — |
| `williamclarke` | William Clarke of Feltwell | ✓ | — |
| `pete_mac` | Pete Mac Tunebook (CC0) | ✓ | — |
| `thesession` | thesession.org | — | — |
| `norbeck` | Norbeck | — | ✓ |
| `paulhardy` | Paul Hardy Session Tunebook (CC BY-NC-SA 4.0) | — | — |

## Per-source licensing notes

### thesession.org

The data ships as a bundled static JSON asset (`assets/data/thesession_tunes.json`) sourced from [adactio/TheSession-data](https://github.com/adactio/TheSession-data). Run `scripts/update_thesession.sh` weekly to pull the latest dump.

**The license on this dump is not CC BY-NC-SA 3.0.** It is a custom license (see `assets/data/thesession_license.txt`) with two key constraints:

1. **AI use is prohibited.** "You may not use, adapt, modify, or process the material in any way with AI technologies. This includes but is not limited to training AI models, utilizing AI tools, or incorporating the material into any AI-related applications or systems." The only exception is accessibility tooling for disabled individuals.
2. **Database structure is ODbL.** The database itself (distinct from the tune contents) is licensed under the Open Database License.

The `license` field in `ContentSourceMeta` currently reads `'CC BY-NC-SA 3.0'` — this is incorrect and must be updated before shipping if we retain this source. The AI prohibition needs legal review if any AI features touch TheSession content.

### Norbeck

Henrik Norbeck's ABC Tune Collection is `hidden: true` pending written permission from the author. Key restrictions from `assets/data/norbeck_license.txt`:

- May not be used commercially.
- **The ABC files may not be made available on a web page for download without permission.** Bundling them in an app binary is analogous and requires the same permission.
- Copyright notice must be kept.

Do not un-hide this source until written permission is received from henrik@norbeck.nu.

## The Provider Chain

```
SharedPreferences  (injected in main() via ProviderScope override)
    └─ sharedPreferencesProvider
        └─ sourceConfirmationServiceProvider   (SourceConfirmationService)
            └─ confirmedSourcesProvider        (NotifierProvider<Set<String>>)
                └─ activeSourceNamesProvider   (Provider<Set<String>>)
                └─ tuneSourcesProvider         (Provider<List<TuneSource>>)
```

- **`confirmedSourcesProvider`** is the single source of truth for which sources the user has accepted. Its notifier exposes `confirm(id, license)` and `revoke(id)`.
- **`activeSourceNamesProvider`** computes the set of source *names* (matching `Tune.from`) that are currently permitted. Widgets and providers that need to gate display use this.
- **`tuneSourcesProvider`** returns only `TuneSource` instances for active sources — this gates search.

## The Display Gate

Every code path that renders tunes must filter through `isSourceNameVisible(sourceName, activeSourceNames)` from `content_source_registry.dart`.

Rules:
- `from` is null/empty → always visible (user-created tune)
- `from` matches a registry source that is active → visible
- `from` matches a registry source that is inactive → hidden
- `from` matches nothing in the registry (user-typed free text) → always visible

**Currently gated:**
- `filteredTunesProvider` — tune list and filter bar
- `availableKeysProvider` — key filter dropdown
- `visibleSetTunesProvider` — set detail and set list tune count
- `TunePickerDialog` — "In your library" results

**Never bypass the gate.** If you add a new surface that shows tunes, it must watch `activeSourceNamesProvider` and call `isSourceNameVisible`.

## Attribution

For any source with `confirmationRequired == true`, the attribution string must appear on every screen that renders that source's content. The `_SourceAttribution` widget in `tune_detail_page.dart` handles this for the detail view — it reads `Tune.from`, looks up the source in the registry, and renders `meta.attribution` if the source is not always-active.

If you add a new content display surface (e.g., a practice screen, lesson view), include attribution there too.

## Confirmation Flow

1. User taps an inactive source in Content Library (`/content_library`).
2. `showSourceConfirmationDialog` shows a **non-dismissible** modal (plain-language explanation + license link).
3. On "I Understand, Add This Source": `confirmedSourcesProvider.notifier.confirm(id, license)` writes to SharedPreferences, then updates state.
4. All watching providers rebuild immediately — the source appears in search and tune display without any app restart.

Confirmation records survive app restarts. On every launch, `SourceConfirmationService.confirmedIds()` re-reads from SharedPreferences.

## Adding a New Source

1. Add a `ContentSourceMeta` entry to `allContentSources` in `content_source_registry.dart`.
2. Add a case to `buildTuneSource()` in the same file.
3. If it is a bundled static JSON source, add the asset path to `pubspec.yaml` and provide the scraper script in `lib/remote_tune_sources/`.
4. If it requires confirmation, set `confirmationRequired: true` — the Content Library UI and all display gates pick it up automatically.
5. If it is not yet ready to surface to users, set `hidden: true` temporarily.

## Hard Rules

- **Never activate a source on first launch** if `confirmationRequired == true`.
- **Never load or display NC-SA content** without a confirmation record in SharedPreferences.
- **Never display licensed content** without `meta.attribution` visible on the same screen.
- **Never place licensed content behind a paywall** — confirmed sources must be fully accessible to all confirming users.
- **Never store confirmation only in memory** — it must persist to SharedPreferences so it survives restarts.
