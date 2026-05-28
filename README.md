# Tune Trove

> record, learn, and master traditional folk tunes ❤️ 🪕

## Development

### First-time setup

ABC MIDI playback uses per-note SoundFont MP3s that are too noisy to track in git. Fetch them once after cloning (or any time the `assets/abcjs/soundfonts/` folder is empty):

```sh
make deps
```

`make deps` runs `flutter pub get` and `scripts/fetch_soundfonts.sh` (idempotent — re-runs skip already-downloaded notes). To pull SoundFonts alone, run the script directly.

### Generated Code

To generate companion classes to go along with `drift` tables, we use the dart `build_runner` dev requirement. This bash command you can set up in a terminal on the side and just leave on. It will watch for changes and make updates to the companion classes accordingly.

```bash
dart run build_runner watch
```

### Linting Standards

- The line `package:lint/strict.yaml` in `analysis_options.yaml` adds some opinionated Dart linting standards so we can have consistent styles in our codebase and help us learn good syntax for this new language. 😊
- The VSCode `markdownlint` extension gives some easy auto-formatting (Option+Shift+F): [https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)

### Database

Make the migrations auto don't do it manually that's bad.

```sh
dart run drift_dev make-migrations
```

#### Location

Finding the database to clear it is a bit of a pain. In the future, a 'clear' database button could be added, or a flag or some other switch to toggle the use of an in-memory database.
For you copy-and-paste convenience, on MacOS this should work to clear the database:

```sh
rm "$HOME/Library/Containers/com.gcantieni.tuneTrove/Data/Library/Application Support/com.gcantieni.tuneTrove/my_database.sqlite"
```

## Goals

- [x] Tune List
  - [x] store tunes
  - [x] fetch data about tunes from tune repositories (names, ABC of different versions, key, type, etc.)
  - [x] associate the tune entries with sections of recordings
  - [ ] provide practicing assistance for committing tunes to memory
- [ ] Set lists
  - [ ] create set lists that reference tunes from tune list
  - [ ] provide practicing assistance for committing sets to memory and practicing transitions
- [ ] Recorder
  - [ ] record audio
  - [ ] (stretch goal) identify tunes
- [-] Recording list
  - [x] track recordings from remote sources like Spotify and YouTube
  - [x] associate those recordings with tunes from tune list
  - [ ] track personal recordings

## Architecture

### Conceptual layout

```text
Presentation layer
┌─────────────────────┐
│                     │
│   Widgets           │
│                     │
│   States            │
│                     │
│   Controllers       │
│                     │
└─────────┬───────────┘
          │
          │
          ▼
 Application Layer
┌─────────────────────┐
│                     │
│ Services            │
│                     │
└─────────────────────┘
          ▲
          │
          │
  Data layer
┌─────────────────────┐
│                     │
│  Model              │
│                     │
│  Database           │
│                     │
└─────────────────────┘
```

### Architectural layout

By separating the business logic from the user interface, we can prevent direct code dependence of business logic on UI elements. The ViewModel presents a programming interface for separating the data manipulation and modification concerns from UI elements that are rendered, interacted with, and updated.

By separating the business logic from the data contained in the model itself, we simplify the code that represents the data to just CRUD operations on the data we manage.

![Model-View-ViewModel architecture](mvvm.png)

Source: [Code with Andrea](https://codewithandrea.com/articles/comparison-flutter-app-architectures/)

References:

- <https://www.xavor.com/blog/bloc-vs-riverpod/>
- <https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/>
- <https://riverpod.dev/>
- <https://github.com/fluttergems/awesome-open-source-flutter-apps>
