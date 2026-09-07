#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/vps-inspector.sh"
test -x "$script"
"$script" --help | grep -q "read-only"
! grep -Eiq 'apt(-get)? +install|systemctl +(stop|restart|disable)|reboot|shutdown|rm +-rf|curl.*--upload|scp ' "$script"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$script" --output "$tmp" --no-public-ip
md="$(find "$tmp" -name '*.md' -print -quit)"
json="$(find "$tmp" -name '*.json' -print -quit)"
test -s "$md"
test -s "$json"
grep -q '^# VPS Inspection Report' "$md"
python3 -m json.tool "$json" >/dev/null
! grep -Eq 'BEGIN (RSA |OPENSSH )?PRIVATE KEY|gh[opsu]_[A-Za-z0-9]+' "$tmp"/*
echo "All tests passed"
