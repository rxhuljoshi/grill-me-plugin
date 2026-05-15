---
name: grill-me
description: Interview the user relentlessly about a plan or design until every unresolved branch of the decision tree is closed. For each question, present a strong recommended answer with reasoning and let the user confirm or override. Whenever a question is answerable by reading the codebase, explore it instead of asking. Update the plan file in place with resolved decisions. Use whenever the user asks to "grill me", "stress test this plan", "interrogate me on the design", refines an Opus/Claude-generated plan, or otherwise wants their design pressure-tested before implementation — even if they don't say "grill" explicitly, trigger on plan refinement / design review intents.
---

# grill-me

## Purpose

Most plans look fine on first read and fall apart at implementation because load-bearing decisions were never actually made — they were glossed over with vague phrasing, or made implicitly without the author noticing. This skill exists to force every such decision into the open *before* code gets written, so the implementer (often another Claude session) has zero ambiguity to fight through.

The skill runs as an interactive interview. You build a decision tree from the plan, resolve every node you can by reading the codebase, then ask the user one sharp question per turn about each remaining node — always with a recommended answer they can confirm or override. As answers come in, you rewrite the plan in place so the artifact stays the source of truth.

The user invokes this skill themselves, or another model invokes it as a follow-up step after generating a plan. Either way, your job is the same: leave the plan free of unresolved decisions.

## Inputs

You need exactly one thing to start: the path to the plan file you're grilling.

Locate it in this order:

1. **Explicit path in the current message.** If the user (or invoking model) says "grill me on `/path/to/plan.md`" or similar, use that.
2. **Active plan-mode plan.** If plan mode is active, the plan file path is in the plan-mode system message. Use it.
3. **Most recent file in `~/.claude/plans/`.** Useful when the user just exited plan mode and immediately says "grill me."
4. **Ask the user once.** If none of the above resolves, ask: "Which plan file should I grill you on?" — that single question is allowed before the interview proper begins.

Before you do anything else, confirm the path back to the user in one short line: `Grilling: <path>`. This catches mismatches early.

## Step 1: Build the decision tree

Read the entire plan file. Identify every **load-bearing decision** — see `references/decision-tree-construction.md` for the criteria and a worked example.

In short: a decision is load-bearing if reasonable engineers would disagree, if it's a one-way door, or if it depends on codebase state the plan author didn't verify. Skip cosmetic choices, framework conventions, and things the lock files / config already pin down.

Output the tree as a flat ordered list with explicit parent → child dependencies. Children must not be asked until their parents resolve, because the parent's answer may eliminate the child entirely. Example:

```
1. [parent] Auth flow: session cookie vs JWT?
2. [child of 1] If JWT — where stored: localStorage vs httpOnly cookie?
3. [parent] Migration strategy: in-place vs new table + backfill?
4. [child of 3] If new table — rename window: same PR vs follow-up?
```

Show this list to the user briefly before starting the interview so they can see the shape of the grilling and call out missing nodes. One short message is enough — no need for elaborate formatting.

## Step 2: Codebase auto-resolve pass

Before asking the user anything, walk the list once and try to resolve each decision from the codebase. The user is the expensive resource; the codebase is free.

For each decision, ask yourself: **can this be answered by reading the repo?** Examples:

- "Which logging library do we use?" → grep `package.json` / `requirements.txt` / imports
- "What's the existing migration pattern?" → list `migrations/` and read the last two
- "Does function X already exist?" → grep
- "What style do existing route handlers follow?" → read 2–3 examples

Tool choice:

- **Targeted lookup (single symbol, single file):** use `Grep` / `Read` inline
- **Cross-file or pattern question** (e.g., "how do all our API routes handle errors?"): spawn an `Explore` subagent with a focused prompt

After exploring, classify each decision:

- **Resolved (auto):** finding is unambiguous. Mark `[auto]` with a 1-line citation (`file.py:42`) and update the plan section immediately.
- **Resolved with low confidence / ambiguous:** promote to a user question with the finding as your recommended answer. Don't silently pick.
- **Not in codebase:** keep as user question, recommendation based on general best practice + plan context.

Tell the user the count: "Auto-resolved X of Y decisions from the codebase. Y−X questions remain."

## Step 3: Interview loop — one question per turn

Now the interview. **Strict rule: one question per assistant turn.** Batching breaks the dependency ordering — a later question's framing depends on the earlier answer, and you can't write a good follow-up until the previous one is answered.

Format each question exactly like this:

```
**Q[n] of [total]: <one-sentence decision>**

Recommended: <your strong opinion as a concrete answer>
Why: <1–2 sentences citing code paths, constraints, or trade-offs that drove the recommendation>

Confirm or override?
```

Rules for the recommendation:

- **Always give a concrete answer**, never "it depends" or "what do you think?" — the user explicitly wants conviction so they have something to react to. A wrong-but-specific recommendation is better than a vague one because it triggers a clearer correction.
- Cite real things: `voice_session.py:147`, "the existing `MongoDBStore` already does X", "Deepgram rejects values below 1000ms" (per their docs).
- If you genuinely have low confidence, say so in the Why line ("low confidence — codebase is silent on this") but still pick.

When the user responds:

1. Record the decision (you'll write it to the plan file next).
2. **Re-evaluate downstream branches.** Some children may now be moot ("we picked session cookies, so the localStorage question disappears"). Some may shift framing.
3. Edit the plan file *now* — don't wait until the end. Update the section that the decision affects so the plan stays a faithful artifact even if the session is interrupted.
4. Move to the next unresolved question.

If the user gives a partial or unclear answer, follow up with one clarifier question before moving on. Don't pile new branches on top of unstable foundations.

## Step 4: Update the plan in place

Two kinds of edits, both made as soon as a decision resolves:

1. **Inline rewrite of affected sections.** If the plan said "TBD: choose between X and Y," replace it with the chosen approach and the one-line reasoning. If the answer invalidates a section entirely (e.g., "if JWT — store where?"), delete that section and note it in the resolved-decisions log.

2. **Append to a `## Resolved Decisions` section at the bottom of the plan.** Format:

   ```
   ## Resolved Decisions

   1. **Auth flow** — Session cookies. Why: existing middleware already handles them; JWT introduces token-rotation work not in scope. (auto-resolved from `app/auth.py:23`)
   2. **Migration strategy** — New table + backfill. Why: in-place would lock the 50M-row table during deploy. (user override of "in-place" recommendation)
   ```

   Mark each entry with `(auto-resolved from <ref>)` or `(user confirmed)` / `(user override)` so future readers can see provenance.

If the section already exists from a partial earlier run, append to it rather than overwriting.

## Stop condition

The interview ends only when every node in the decision tree is resolved (auto or user). When that happens, send a short closeout:

```
Done. Resolved <total> decisions (<X> from code, <Y> from interview).
Plan updated in place: <path>.
Notable shifts from the original plan: <bullet list of 1–3 places where the answer materially changed the plan>.
```

Don't summarize every question — the resolved-decisions section in the plan file is the canonical record. The closeout is just a pointer.

## Failure modes

- **Plan file unreadable / not found.** Report the path you tried, ask the user for the right path, do not invent or guess.
- **User says "stop" / "enough" mid-interview.** Write a `## Resolved Decisions (partial)` section with what's been answered, list the remaining open questions under `## Open Questions`, then exit cleanly.
- **User repeatedly overrides your recommendations.** That's fine — adjust your priors and keep going. Don't get defensive, don't restate your reasoning, just absorb the override and proceed. The point is *their* clarity, not your win rate.
- **Plan mode is active and only the plan file is writable.** Works as designed — that file is the one you'd be editing anyway. Just confirm the path matches.
- **The plan is too vague to extract decisions from.** Tell the user: "This plan is too high-level to grill — there are no concrete decisions to interrogate. Want me to first ask you to expand sections X and Y into specifics?" Then re-enter Step 1.

## Why these invariants matter

- **One question per turn:** the dependency graph between decisions is the whole point. Batching forces you to guess the order, and a wrong guess wastes the user's time on questions that will be obsoleted by an earlier answer.
- **Always give a recommendation:** users iterate faster against a concrete proposal than an open question. The recommendation is a forcing function for *you* too — it makes you do the codebase reading and trade-off thinking, instead of punting.
- **Codebase before user:** the user's attention is the bottleneck. Every question you can kill with a grep is one they don't have to answer.
- **Edit the plan as you go:** the plan file is the deliverable. If you batch edits to the end and the session crashes, the work is gone. Incremental edits also keep you honest — you can't pretend to resolve a question if you have to actually write the answer down.
