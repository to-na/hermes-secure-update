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
| AI security review | ❌ None | ✅ LLM scans diff for backdoors/exfil/obfuscation |
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

# AI review: pick a model, or skip it entirely
hermes-secure-update --ai-model anthropic/claude-sonnet-4
hermes-secure-update --no-ai-review
```

## Pipeline

```
1. FETCH      git fetch origin main --tags (read-only)
2. VERIFY     L1 remote URL → L2 commit signatures → L3 tag signature → L4 risk score
3. AI REVIEW  LLM scans the diff for backdoors / exfil / obfuscation → verdict
4. REVIEW     commit log, changed files, notable changes, risk + AI verdict → y/N prompt
5. APPLY      hermes update --yes (inherits rollback, syntax check, venv repair)
```

### AI security review

Phase 3 sends the diff to an LLM via `hermes chat -q` and asks it to look for:
malicious injection (reverse shells, exfil), credential harvesting, unexpected
network calls, obfuscated payloads, permission escalation, supply-chain risk,
and silent behavior changes. It returns a verdict:

- ✅ **CLEAN** — no concerns
- ⚠️ **REVIEW NEEDED** — human should look closer
- 🚨 **SUSPICIOUS** — treated as a hard signal: `--auto` refuses to apply, and
  interactive mode asks "Apply ANYWAY despite AI warning?"

The review is advisory, not a sandbox — it reads the diff only and never runs
the new code. Disable with `--no-ai-review` or `AI_REVIEW_ENABLED="false"`.

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
| `AI_REVIEW_ENABLED` | `true` | Run LLM security review of the diff |
| `AI_REVIEW_MODEL` | *(hermes default)* | Model used for the AI review |
| `AI_REVIEW_MAX_DIFF_CHARS` | `12000` | Diff truncation limit sent to the AI |
| `AI_BLOCK_ON_SUSPICIOUS` | `true` | Block `--auto` when AI flags SUSPICIOUS |

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
