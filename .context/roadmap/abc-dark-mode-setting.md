# Roadmap: Optional White-on-Black Sheet Music in Dark Theme

> **Status: Implemented.** Stored as the `invertNotationInDarkMode` key in the
> synced `app_settings` table (`AppSettings` / `AppSettingsDao`), exposed via
> `invertNotationInDarkModeProvider`, toggled from the Settings page, and read by
> `AbcView`. Defaults to on. Remember to deploy the `AppSetting` CloudKit record
> type to Production before the next release.

## Background

ABC notation is rendered via `abcjs` → SVG, then displayed using `flutter_svg`. In dark mode, `AbcView` (`lib/feat/abc_render/abc_view.dart`) applies a `ColorFilter.matrix` that remaps the SVG's black notation and white background to `colorScheme.onSurface` and `colorScheme.surface` respectively, so the sheet music matches the app theme.

This filter is currently applied unconditionally whenever the system is in dark mode.

## Goal

Make the white-on-black (inverted) sheet music rendering optional — some users may prefer to keep the traditional black-on-white notation even in dark mode.

## Proposed Approach

Add a user preference (stored via the existing settings/persistence layer) that controls whether the notation color filter is applied in dark mode. The `AbcView` widget reads this preference and skips the `ColorFiltered` wrapper when disabled.

The setting should default to **on** (i.e. follow the theme), preserving the current behaviour for existing users.

## Implementation Sketch

1. Add a boolean preference key (e.g. `invertNotationInDarkMode`, default `true`) to the settings store.
2. Expose it via a Riverpod provider so `AbcView` can watch it.
3. In `AbcView._maybeinvert`, gate the `ColorFiltered` wrapper on both `brightness == dark` AND the preference.
4. Add a toggle to the settings/preferences UI.

## Open Questions

- Where does this live in the settings UI? A dedicated "Notation" section, or folded into a general display section?
