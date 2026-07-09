---
name: doctor
description: Diagnose the media plugin — native build, read/control paths, fallbacks, permissions — and suggest fixes. Use when media commands fail, return nothing, or the user asks to troubleshoot media control.
allowed-tools: Bash
---

Diagnosis report:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" doctor`

Interpret the report for the user:

1. Lead with the `verdict:` line in plain words.
2. For any item marked `FAILED` or `missing`, explain the fix in one line each
   (the report text already contains the exact command, e.g.
   `xcode-select --install`).
3. If the verdict suggests a rebuild — or the user asks for one — run with Bash:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" doctor --rebuild
```

and summarize the new verdict.

Keep the summary short; do not re-print the raw report (the user already sees it).
