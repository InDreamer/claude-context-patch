---
name: claude-context-patch
description: Patch Anthropic Claude Code CLI internals to override context limits and compaction behavior. Trigger when the user asks to patch/modify/reverse Claude Code, tune context window, tune effective window, tune autocompact threshold, set 272k/258400/244800 values, fix frequent compaction, patch cli.js, patch native claude binary, generate one-click patch scripts, or verify/rollback context-related binary patches.
---

# Claude Context Patch

Force Claude Code defaults to:
- context window: 272000
- effective window: 95% (258400)
- auto-compact threshold: 90% (244800)

## Run

Use the bundled patcher:

```bash
bash scripts/patch_claude_context_272k.sh
```

Use an explicit target when needed:

```bash
bash scripts/patch_claude_context_272k.sh /opt/homebrew/Caskroom/claude-code/<version>/claude
```

## Verify

Run:

```bash
claude -p --model sonnet --debug-file /tmp/claude_debug.log "ping"
rg "autocompact:" /tmp/claude_debug.log
```

Expect `threshold=244800` and `effectiveWindow=258400` in the debug line.

## Rollback

Use the rollback command printed by the script (it points to the timestamped backup).

## Implementation Notes

- Auto-detect JS `cli.js` vs native Mach-O binary.
- Create a timestamped backup before patching.
- Use equal-length replacements for native binary patching.
- Keep `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` logic intact.
- If output says unknown build, inspect runtime patterns and update script matchers before retrying.
