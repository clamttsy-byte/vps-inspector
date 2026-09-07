# VPS Inspector

A dependency-light, read-only inventory tool for Ubuntu and Debian VPS hosts.
It creates a human-readable Markdown report and a machine-readable JSON report.

## Safety

The tool does not install packages, modify firewall rules, restart services,
read application configuration bodies, upload data, or inspect SSH keys and
environment files. Public IPv4 addresses are masked by default.

## Run

```bash
git clone https://github.com/clamttsy-byte/vps-inspector.git
cd vps-inspector
sudo bash vps-inspector.sh
```

Reports are written to `./reports`. Use `--output DIR` to choose another
directory. `--no-public-ip` omits public-IP lookup entirely. Do not publish a
report before reviewing it.

## Exit status

- `0`: report generated
- `1`: invalid arguments or report generation failure

## Development

```bash
bash tests/run.sh
shellcheck vps-inspector.sh tests/run.sh
```
