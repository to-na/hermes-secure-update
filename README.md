# hermes-secure-update

Secure update wrapper for [Hermes Agent](https://github.com/NousResearch/hermes-agent).

`hermes update` does `git fetch → pull → pip install` with syntax-check rollback, but has **no commit/tag signature verification, no diff review gate, and no risk scoring**. This tool adds a **Fetch → Verify → Review → Apply** pipeline with a human approval gate.

## Why

| Risk | `hermes update` | `hermes-secure-update` |
|------|----------------|----------------------|
| Remote URL tampering | ❌ Not checked | ✅ Blocks if origin ≠ NousResearch |
| Unsigned commits | ❌ Silent | ⚠️ Counted + warned |
| Unknown authors | ❌ Silent | ⚠️ Flagged against maintainer list |
| Diff review | ❌ None | ✅ Commit log + file stats + notable changes |
| Risk scoring | ❌ None | ✅ low/medium/high from diff analysis |
| Human approval | ❌ Auto-applies | ✅ y/N prompt (or `--auto` with threshold) |
| Tag signature | ❌ Not checked | ⚠️ Checked + warned |
| Rollback on failure | ✅ Built-in | ✅ Delegates to `hermes update` |

## Install

```bash
git clone https://github.com/to-na/hermes-secure-update.git
cd hermes-secure-update
make install    # symlinks to ~/.local/bin/
```

## Usage

```bash
# Interactive: fetch → verify → review → approve → apply
hermes-secure-update

# Preview only (no apply)
hermes-secure-update --dry-run

# Update to a specific release tag
hermes-secure-update --tag v2026.7.20

# Non-interactive (cron/gateway): auto-approve low risk, block high
hermes-secure-update --auto

# Full file list in review
hermes-secure-update --verbose

# Custom config
hermes-secure-update --config /path/to/my.conf
```

## Pipeline

```
1. FETCH    git fetch origin main --tags (read-only)
2. VERIFY   L1 remote URL → L2 commit signatures → L3 tag signature → L4 risk score
3. REVIEW   commit log, changed files, notable changes, risk level → y/N prompt
4. APPLY    hermes update --yes (inherits rollback, syntax check, venv repair)
```

## Configuration

Edit `config/default.conf` or set `HERMES_SECURE_UPDATE_CONFIG=/path/to/conf`.

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_REPO` | `~/.hermes/hermes-agent` | Path to hermes-agent checkout |
| `EXPECTED_REMOTE_PATTERN` | `github\.com[:/]NousResearch/hermes-agent` | Regex for origin URL |
| `AUTO_APPROVE_BELOW` | `low` | Max risk for `--auto` approval |
| `BLOCK_ABOVE` | `high` | Risk level that always blocks |
| `SHOW_DIFF` | `true` | Show file stats in review |
| `PREFER_TAGS` | `false` | Prefer tags over main HEAD |

Known maintainer emails: `config/maintainers.txt` (one per line).

## Current limitations

- **Upstream doesn't sign commits/tags** — signature verification is warn-only, not blocking. When Nous Research starts signing, set `require_signed_tags: true` in config.
- **No dependency hash verification** — `uv.lock` changes are counted in risk scoring but not hash-verified.
- **Apply delegates to `hermes update`** — this tool does not replace the update logic; it wraps it with verification.

## Tests

```bash
make test
```

## License

MIT
