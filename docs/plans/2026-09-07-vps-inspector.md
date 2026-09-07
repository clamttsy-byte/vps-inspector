# VPS Inspector Implementation Plan

> **For implementer:** Use TDD throughout. Write failing test first. Watch it fail. Then implement.

**Goal:** Build a dependency-light, read-only Ubuntu/Debian VPS inspection tool that produces redacted Markdown and JSON reports.

**Architecture:** A Bash entrypoint coordinates small collection and rendering libraries. Collectors emit normalized key/value and list data, redaction happens before persistence, and renderers create human-readable Markdown plus machine-readable JSON. Tests run in fixture mode so development never depends on or changes the host system.

**Tech Stack:** Bash 4+, standard Linux utilities, optional `jq`, Git, GitHub Actions with Ubuntu.

---

### Task 1: Project safety contract and test runner

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `tests/run.sh`
- Create: `tests/test_safety.sh`

**Step 1: Write the failing test**

Create `tests/test_safety.sh` to assert that the entrypoint exists, contains no package installation, service mutation, firewall mutation, deletion, upload, or reboot commands, and supports `--help`.

**Step 2: Run test — confirm it fails**

Command: `bash tests/run.sh`

Expected: FAIL because `vps-inspector.sh` does not exist.

**Step 3: Write minimal implementation**

Create an executable `vps-inspector.sh` with strict mode, help text, a read-only safety statement, and argument parsing for `--output`, `--format`, `--no-public-ip`, and `--fixture-dir`. Add README usage and an MIT license.

**Step 4: Run test — confirm it passes**

Command: `bash tests/run.sh`

Expected: PASS for safety and help checks.

**Step 5: Commit**

```bash
git add README.md LICENSE .gitignore vps-inspector.sh tests
git commit -m "chore: establish inspector safety contract"
```

### Task 2: Redaction before persistence

**Files:**
- Create: `lib/redact.sh`
- Create: `tests/test_redact.sh`

**Step 1: Write the failing test**

Test masking for IPv4 addresses, IPv6 addresses, bearer tokens, common secret assignments, GitHub tokens, private-key blocks, and URLs containing credentials. Assert that loopback addresses may remain visible while public addresses are masked by default.

**Step 2: Run test — confirm it fails**

Command: `bash tests/run.sh`

Expected: FAIL because redaction functions are undefined.

**Step 3: Write minimal implementation**

Implement `redact_text`, `redact_ipv4`, and `redact_file_stream`. Redaction must run in memory or a pipeline before report content is written to disk. Never read `.env`, SSH private keys, shell history, agent configuration bodies, or arbitrary application files.

**Step 4: Run test — confirm it passes**

Command: `bash tests/run.sh`

Expected: PASS with no original fixture secret present in test output.

**Step 5: Commit**

```bash
git add lib/redact.sh tests/test_redact.sh
git commit -m "feat: redact sensitive inspection output"
```

### Task 3: Read-only system collectors

**Files:**
- Create: `lib/collect.sh`
- Create: `tests/fixtures/ubuntu/`
- Create: `tests/test_collect.sh`

**Step 1: Write the failing test**

Using fixture command outputs, assert normalized collection of OS, kernel, architecture, CPU count, memory, swap, load, filesystem capacity, time synchronization, installed tool versions, running services, Docker inventory, listening ports, firewall policy, network summary, and Nezha process count.

**Step 2: Run test — confirm it fails**

Command: `bash tests/run.sh`

Expected: FAIL because collectors are undefined.

**Step 3: Write minimal implementation**

Implement command wrappers that use fixture files when `--fixture-dir` is set and real read-only commands otherwise. Missing commands must produce `unavailable`, not terminate the report. Privileged checks may use non-interactive `sudo -n`; if unavailable, record `permission_required` without prompting.

**Step 4: Run test — confirm it passes**

Command: `bash tests/run.sh`

Expected: PASS on Ubuntu fixtures and missing-command fixtures.

**Step 5: Commit**

```bash
git add lib/collect.sh tests/fixtures tests/test_collect.sh
git commit -m "feat: collect read-only VPS inventory"
```

### Task 4: Risk analysis rules

**Files:**
- Create: `lib/analyze.sh`
- Create: `tests/test_analyze.sh`

**Step 1: Write the failing test**

Assert warnings for duplicate Nezha agents, occupied 80/443 ports, multiple reverse proxies, low available memory, low disk space, Docker absence, input firewall policy `accept`, publicly bound application ports, clock drift, and conflicting services. Assert stable severity ordering: high, medium, low, info.

**Step 2: Run test — confirm it fails**

Command: `bash tests/run.sh`

Expected: FAIL because analyzer rules are undefined.

**Step 3: Write minimal implementation**

Implement deterministic analysis over normalized collector data. Thresholds must be constants documented in the README and labeled as advisory rather than absolute deployment decisions.

**Step 4: Run test — confirm it passes**

Command: `bash tests/run.sh`

Expected: PASS for healthy and risky fixtures.

**Step 5: Commit**

```bash
git add lib/analyze.sh tests/test_analyze.sh README.md
git commit -m "feat: analyze VPS deployment risks"
```

### Task 5: Markdown and JSON reports

**Files:**
- Create: `lib/render.sh`
- Create: `tests/test_render.sh`

**Step 1: Write the failing test**

Assert that Markdown contains a summary, capacity table, software inventory, port conflicts, findings, and next checks. Validate JSON syntax with `jq` when available and Python as a test-only fallback. Assert both formats contain the same finding identifiers.

**Step 2: Run test — confirm it fails**

Command: `bash tests/run.sh`

Expected: FAIL because renderers are undefined.

**Step 3: Write minimal implementation**

Implement atomic report writes through temporary files in the selected output directory. Default filenames are timestamped. Include tool version and report schema version. Never overwrite an existing report unless `--overwrite` is explicitly supplied.

**Step 4: Run test — confirm it passes**

Command: `bash tests/run.sh`

Expected: PASS and fixture reports contain no secrets.

**Step 5: Commit**

```bash
git add lib/render.sh tests/test_render.sh vps-inspector.sh
git commit -m "feat: render Markdown and JSON reports"
```

### Task 6: End-to-end fixture execution

**Files:**
- Create: `tests/test_e2e.sh`
- Modify: `README.md`

**Step 1: Write the failing test**

Run the complete tool against the Ubuntu fixture and assert exit code zero, two reports, expected duplicate-agent finding, masked public IP, no fixture secret, and no modified fixture files.

**Step 2: Run test — confirm it fails**

Command: `bash tests/run.sh`

Expected: FAIL until the entrypoint connects collectors, analyzer, redaction, and renderers.

**Step 3: Write minimal implementation**

Wire the modules together, create a temporary working directory with a cleanup trap, and document local execution, rootless limitations, report sharing, and verification.

**Step 4: Run test — confirm it passes**

Command: `bash tests/run.sh`

Expected: all tests PASS.

**Step 5: Commit**

```bash
git add vps-inspector.sh README.md tests/test_e2e.sh
git commit -m "feat: complete VPS inspection workflow"
```

### Task 7: Continuous integration and release readiness

**Files:**
- Create: `.github/workflows/test.yml`
- Create: `CHANGELOG.md`

**Step 1: Write the failing check**

Run ShellCheck locally when available and verify the workflow file invokes `tests/run.sh` on Ubuntu.

**Step 2: Run check — confirm current gap**

Command: `bash tests/run.sh`

Expected: project tests pass, but no CI workflow exists yet.

**Step 3: Write minimal implementation**

Add GitHub Actions for ShellCheck and fixture tests. Add changelog entry for v0.1.0. Do not add automatic SSH deployment or any secret-dependent workflow.

**Step 4: Run verification**

Commands:

```bash
bash tests/run.sh
shellcheck vps-inspector.sh lib/*.sh tests/*.sh
```

Expected: all tests and lint checks PASS.

**Step 5: Commit**

```bash
git add .github CHANGELOG.md
git commit -m "ci: verify inspector on Ubuntu"
```

### Task 8: Private GitHub repository

**Files:**
- No source changes expected.

**Step 1: Verify local repository**

Commands:

```bash
git status --short
git log --oneline --decorate -10
```

Expected: clean worktree with reviewed commits.

**Step 2: Create private remote**

Command: `gh repo create vps-inspector --private --source . --remote origin --push`

Expected: repository created under the authenticated account and `main` pushed.

**Step 3: Verify remote**

Commands:

```bash
git remote -v
gh repo view --json nameWithOwner,visibility,url
```

Expected: `clamttsy-byte/vps-inspector`, visibility `PRIVATE`, and clean local status.

