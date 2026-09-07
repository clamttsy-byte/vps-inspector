#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/vps-inspector.sh"
test -x "$script"
"$script" --help | grep -q "read-only"
expected_pipe_command='curl -fsSL "$SCRIPT_URL" | sudo bash -s --'
grep -Fq "$expected_pipe_command" "$root/README.md"
if grep -Fq 'sudo bash <(' "$root/README.md"; then
  echo "README uses process substitution across sudo" >&2
  exit 1
fi
if grep -Eiq 'apt(-get)? +install|systemctl +(stop|restart|disable)|reboot|shutdown|rm +-rf|curl.*--upload|scp ' "$script"; then
  echo "Unsafe command found" >&2
  exit 1
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$script" --output "$tmp" --no-public-ip
md="$(find "$tmp" -name '*.md' -print -quit)"
json="$(find "$tmp" -name '*.json' -print -quit)"
test -s "$md"
test -s "$json"
grep -q '^# VPS Inspection Report' "$md"
python3 -m json.tool "$json" >/dev/null
if grep -Eq 'BEGIN (RSA |OPENSSH )?PRIVATE KEY|gh[opsu]_[A-Za-z0-9]+' "$tmp"/*; then
  echo "Sensitive material found in report" >&2
  exit 1
fi
echo "All tests passed"
