#!/usr/bin/env bash
# Download SoundFonts for ABC MIDI playback into assets/abcjs/soundfonts/.
# The files are gitignored — re-run this script after a fresh clone.
#
# Layout produced (one folder per instrument; abcjs fetches per-note .mp3):
#   assets/abcjs/soundfonts/<instrument>-mp3/{C0..B8}.mp3

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/assets/abcjs/soundfonts"
BASE="https://paulrosen.github.io/midi-js-soundfonts/FluidR3_GM"

INSTRUMENTS=(
  acoustic_grand_piano
)

NOTES=(C Db D Eb E F Gb G Ab A Bb B)
OCTAVES=(0 1 2 3 4 5 6 7 8)

for inst in "${INSTRUMENTS[@]}"; do
  out="$DEST/${inst}-mp3"
  mkdir -p "$out"
  echo "→ $inst"
  ok=0
  miss=0
  for oct in "${OCTAVES[@]}"; do
    for note in "${NOTES[@]}"; do
      file="${note}${oct}.mp3"
      if [[ -f "$out/$file" ]]; then
        ok=$((ok + 1))
        continue
      fi
      if curl -sSf -o "$out/$file" "$BASE/${inst}-mp3/$file" 2>/dev/null; then
        ok=$((ok + 1))
      else
        rm -f "$out/$file"
        miss=$((miss + 1))
      fi
    done
  done
  echo "  ok=$ok missing=$miss (missing notes outside the instrument's range are expected)"
done
