#!/usr/bin/env bash
# Downloads the latest TheSession JSON dump and converts it to the bundled
# asset format. Run manually or weekly via CI.
#
# Usage: scripts/update_thesession.sh [--dry-run]
#
# Requires: curl, python3

set -euo pipefail

UPSTREAM="https://raw.githubusercontent.com/adactio/TheSession-data/refs/heads/main/json/tunes.json"
OUT="assets/data/thesession_tunes.json"

cd "$(dirname "$0")/.."

echo "Fetching $UPSTREAM …"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$UPSTREAM" -o "$tmp"

echo "Transforming …"
python3 - "$tmp" "$OUT" <<'EOF'
import json, re, sys

def normalize_mode(mode):
    # upstream uses "Gmajor"/"Bminor"; we store "Gmaj"/"Bmin"
    mode = re.sub(r'major$', 'maj', mode, flags=re.IGNORECASE)
    mode = re.sub(r'minor$', 'min', mode, flags=re.IGNORECASE)
    return mode

with open(sys.argv[1]) as f:
    raw = json.load(f)

seen = set()
result = []
for entry in raw:
    tune_id = int(entry['tune_id'])
    if tune_id in seen:
        continue
    seen.add(tune_id)
    result.append({
        'id': tune_id,
        'name': entry['name'],
        'type': entry['type'],
        'key': normalize_mode(entry.get('mode', '')),
        'abc': entry['abc'],
    })

with open(sys.argv[2], 'w') as f:
    json.dump(result, f, ensure_ascii=False, separators=(',', ':'))

print(f"Wrote {len(result)} tunes → {sys.argv[2]}")
EOF
