#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
SCHEMA="1"
OUTPUT_DIR="./reports"
LOOKUP_PUBLIC_IP=1

usage() {
  cat <<'EOF'
VPS Inspector — read-only Ubuntu/Debian inventory
Usage: sudo bash vps-inspector.sh [--output DIR] [--no-public-ip] [--help]
Creates redacted Markdown and JSON reports locally. It changes no system state.
EOF
}

while (($#)); do
  case "$1" in
    --output) [[ $# -ge 2 ]] || { echo "--output needs a directory" >&2; exit 1; }; OUTPUT_DIR="$2"; shift 2 ;;
    --no-public-ip) LOOKUP_PUBLIC_IP=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

command_text() {
  local fallback="$1"; shift
  local result
  result="$("$@" 2>/dev/null || true)"
  [[ -n "$result" ]] && printf '%s' "$result" || printf '%s' "$fallback"
}

version_of() {
  command -v "$1" >/dev/null 2>&1 || { printf 'not installed'; return; }
  shift
  command_text "installed" "$@" | head -n 1
}

mask_ipv4() {
  sed -E 's/([0-9]{1,3}\.[0-9]{1,3}\.)[0-9]{1,3}\.[0-9]{1,3}/\1x.x/g'
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}; value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}; value=${value//$'\r'/}
  printf '%s' "$value"
}

os="$(awk -F= '$1 == "PRETTY_NAME" {value=$2; gsub(/^\"|\"$/, "", value); print value; exit}' /etc/os-release 2>/dev/null || true)"
os="${os:-unknown}"
arch="$(command_text unknown uname -m)"
kernel="$(command_text unknown uname -r)"
cpu="$(command_text unknown nproc)"
memory="$(command_text unknown free -h | awk '/^Mem:/ {print $2 " total, " $7 " available"}')"
swap="$(command_text unknown free -h | awk '/^Swap:/ {print $2 " total, " $3 " used"}')"
load="$(command_text unknown uptime | sed -E 's/^.*load average: //')"
disk="$(command_text unknown df -hP / | awk 'NR==2 {print $2 " total, " $4 " available, " $5 " used"}')"
git_v="$(version_of git git --version)"
docker_v="$(version_of docker docker --version)"
compose_v="$(command -v docker >/dev/null 2>&1 && command_text 'not installed' docker compose version || printf 'not installed')"
caddy_v="$(version_of caddy caddy version)"
nginx_v="$(command -v nginx >/dev/null 2>&1 && command_text installed nginx -v || printf 'not installed')"
time_sync="$(command_text unknown timedatectl show -p NTPSynchronized --value)"
services="$(command_text unavailable systemctl --type=service --state=running --no-pager --no-legend)"
ports="$(command_text unavailable ss -lntup)"
containers="$(command -v docker >/dev/null 2>&1 && command_text unavailable docker ps -a --format '{{.Names}} | {{.Status}} | {{.Ports}}' || printf 'Docker unavailable')"
nezha_count="$(pgrep -fc '/opt/nezha/agent/nezha-agent' 2>/dev/null || true)"
nezha_count="${nezha_count:-0}"
firewall_policy="$(command_text unavailable sh -c "nft list ruleset 2>/dev/null | awk '/hook input/ {print; exit}'")"
public_ip="omitted"
if ((LOOKUP_PUBLIC_IP)) && command -v curl >/dev/null 2>&1; then
  public_ip="$(command_text unavailable curl -4fsS --max-time 5 https://api.ipify.org | mask_ipv4)"
fi

findings=()
(( nezha_count > 1 )) && findings+=("HIGH|duplicate_nezha_agents|Found $nezha_count Nezha agent processes")
grep -q 'policy accept' <<<"$firewall_policy" && findings+=("HIGH|input_policy_accept|Firewall INPUT policy appears to accept traffic by default")
grep -Eq '(:80 |:80$|:443 |:443$)' <<<"$ports" && findings+=("MEDIUM|web_ports_in_use|Port 80 or 443 is already listening")
[[ "$docker_v" == "not installed" ]] && findings+=("MEDIUM|docker_missing|Docker is not installed")
((${#findings[@]} == 0)) && findings+=("INFO|no_immediate_conflict|No immediate conflict detected by baseline rules")

mkdir -p "$OUTPUT_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
md="$OUTPUT_DIR/vps-report-$stamp.md"
json="$OUTPUT_DIR/vps-report-$stamp.json"
[[ ! -e "$md" && ! -e "$json" ]] || { echo "Report already exists" >&2; exit 1; }
tmp_md="$md.tmp"; tmp_json="$json.tmp"
trap 'rm -f "$tmp_md" "$tmp_json"' EXIT

{
  echo "# VPS Inspection Report"
  echo
  echo "Generated: $stamp UTC | Tool: $VERSION | Schema: $SCHEMA"
  echo
  echo "## Capacity"
  echo
  echo "| Item | Value |"
  echo "|---|---|"
  printf '| OS | %s |\n' "$os"
  printf '| Architecture | %s |\n' "$arch"
  printf '| Kernel | %s |\n' "$kernel"
  printf '| CPU | %s cores |\n' "$cpu"
  printf '| Memory | %s |\n' "$memory"
  printf '| Swap | %s |\n' "$swap"
  printf '| Load | %s |\n' "$load"
  printf '| Root disk | %s |\n' "$disk"
  printf '| Public IPv4 | %s |\n' "$public_ip"
  printf '| Time synchronized | %s |\n' "$time_sync"
  echo
  echo "## Software"
  printf -- '- Git: %s\n- Docker: %s\n- Compose: %s\n- Caddy: %s\n- Nginx: %s\n' "$git_v" "$docker_v" "$compose_v" "$caddy_v" "$nginx_v"
  echo
  echo "## Findings"
  for finding in "${findings[@]}"; do
    IFS='|' read -r severity id message <<<"$finding"
    printf -- '- **%s** ' "$severity"
    # Literal backticks are intentional Markdown delimiters, not shell expansion.
    # shellcheck disable=SC2016
    printf '`%s`: %s\n' "$id" "$message"
  done
  echo
  echo "## Running services"
  printf '%s\n%s\n%s\n' '```text' "$services" '```'
  echo
  echo "## Docker containers"
  printf '%s\n%s\n%s\n' '```text' "$containers" '```'
  echo
  echo "## Listening ports"
  printf '%s\n%s\n%s\n' '```text' "$ports" '```'
} | mask_ipv4 >"$tmp_md"

{
  printf '{\n  "schema_version":"%s",\n  "tool_version":"%s",\n  "generated_at":"%s",\n' "$SCHEMA" "$VERSION" "$stamp"
  printf '  "system":{"os":"%s","architecture":"%s","kernel":"%s","cpu_cores":"%s","memory":"%s","swap":"%s","root_disk":"%s"},\n' "$(json_escape "$os")" "$(json_escape "$arch")" "$(json_escape "$kernel")" "$(json_escape "$cpu")" "$(json_escape "$memory")" "$(json_escape "$swap")" "$(json_escape "$disk")"
  printf '  "software":{"git":"%s","docker":"%s","compose":"%s","caddy":"%s","nginx":"%s"},\n' "$(json_escape "$git_v")" "$(json_escape "$docker_v")" "$(json_escape "$compose_v")" "$(json_escape "$caddy_v")" "$(json_escape "$nginx_v")"
  printf '  "public_ipv4":"%s",\n  "nezha_agent_processes":%s,\n  "findings":[' "$(json_escape "$public_ip")" "$nezha_count"
  first=1
  for finding in "${findings[@]}"; do IFS='|' read -r severity id message <<<"$finding"; ((first)) || printf ','; first=0; printf '\n    {"severity":"%s","id":"%s","message":"%s"}' "$severity" "$id" "$(json_escape "$message")"; done
  printf '\n  ]\n}\n'
} | mask_ipv4 >"$tmp_json"

mv "$tmp_md" "$md"
mv "$tmp_json" "$json"
trap - EXIT
printf 'Created:\n%s\n%s\n' "$md" "$json"
