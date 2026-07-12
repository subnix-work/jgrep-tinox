#!/usr/bin/env bash
# Baut jgrep und ygrep (gleiche Binärdatei, Verhalten schaltet über argv[0]).
set -euo pipefail
cd "$(dirname "$0")"

tinox build

# ygrep ist dieselbe Binärdatei unter anderem Namen
cp -f jgrep ygrep

echo "OK: $(./jgrep --version) / $(./ygrep --version)"
