#!/usr/bin/env bash
# build.sh — compile yubikrypt.ks to a native binary via Krypton.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Find the Krypton driver. Prefer the dev repo over a PATH install: a stale
# /usr/local/krypton can ship an older backend that miscompiles (silent
# SIGSEGV at runtime). Override with $KCC.
if [[ -n "${KCC:-}" ]]; then
    :  # honour explicit override
elif [[ -x "$HOME/Documents/GitHub/krypton/kcc.sh" ]]; then
    KCC="$HOME/Documents/GitHub/krypton/kcc.sh"
elif command -v kcc.sh >/dev/null 2>&1; then
    KCC="$(command -v kcc.sh)"
else
    echo "error: can't find kcc.sh (install Krypton or set KCC=/path/to/kcc.sh)" >&2
    exit 1
fi

bash "$KCC" yubikrypt.ks -o yubikrypt
echo "built ./yubikrypt   — run it with: ./yubikrypt"
