# grill-me

Claude Code skill that interrogates a plan or design until every load-bearing decision is resolved. Built for stress-testing plans before code is written.

## What it does

Reads a plan file, builds a decision tree of unresolved branches, explores the codebase to auto-resolve what it can, then interviews you one sharp question at a time — always with a recommended answer — and rewrites the plan in place as you confirm or override.

Use it when:

- You wrote a plan and want it pressure-tested before implementation
- An Opus/Claude session generated a plan and you want gaps surfaced
- You catch yourself saying "we'll figure that out later"

## Install (recommended — works for everyone)

Paste this one line into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/rxhuljoshi/grill-me-plugin/main/install.sh | bash
```

No git, no SSH, no GitHub account needed. Just curl (default on macOS).

Restart Claude Code after. Skill auto-loads from `~/.claude/skills/grill-me/`.

## Updating

Re-run the same install command. It backs up the old version to `.bak` and installs fresh:

```bash
curl -fsSL https://raw.githubusercontent.com/rxhuljoshi/grill-me-plugin/main/install.sh | bash
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rxhuljoshi/grill-me-plugin/main/uninstall.sh | bash
```

## Alternative install (Claude Code plugin system)

For users who prefer the official plugin manager:

```
/plugin marketplace add rxhuljoshi/grill-me-plugin
/plugin install grill-me@grill-me
```

Requires git working on the machine. If it fails with SSH/host-key errors, use the curl one-liner above instead.

## Trigger

Type `/grill-me` in Claude Code, or just say "grill me on this plan", "stress test this design", "interrogate me on this".

## Layout

```
.claude-plugin/
  plugin.json         # plugin manifest
  marketplace.json    # marketplace manifest for distribution
skills/
  grill-me/
    SKILL.md
    references/
      decision-tree-construction.md
```

## Author

Rahul Joshi 
