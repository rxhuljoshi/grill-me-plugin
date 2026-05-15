# Decision tree construction

This is the part of `grill-me` that determines whether the interview is useful or noise. Get this step wrong and you'll spend the user's attention on cosmetic choices while letting the real risks slip through.

## What counts as a load-bearing decision

A decision is worth grilling if **at least one** of these is true:

1. **Reasonable engineers would disagree.** If two competent people could look at the plan and pick different answers based on their experience, it's a real decision. Examples: optimistic vs pessimistic locking, REST vs RPC, monolith vs split service.

2. **It's a one-way door.** The cost of changing the answer later is much higher than the cost of choosing carefully now. Examples: database schema choices, public API shapes, file/folder layout that other code will import from, choice of primary key strategy.

3. **It depends on codebase state the plan author didn't verify.** The plan says "we'll reuse the existing auth helper" — but does that helper exist? Does it do what the plan assumes? Anything where the plan asserts a fact about the repo that hasn't been double-checked is fair game.

4. **It's a security, data-integrity, or correctness boundary.** Authn/authz, input validation, retry semantics, idempotency, race conditions. Even when the plan looks complete here, ask — these are the places where "looked fine in review" most often becomes "broke in prod."

5. **It has a performance or cost cliff.** N+1 queries, unbounded loops, choice of index, cache TTLs, function memory/timeout. If the answer affects whether the feature scales, surface it.

## What to skip

Not every choice deserves a question. Skip:

- **Things the lock file / framework already settled.** "Which test runner do we use?" — read `package.json`. Don't ask.
- **Cosmetic choices with no downstream effect.** Variable naming inside a function, whether to use `for` or `forEach`, exact wording of log messages. Unless the plan explicitly raises one of these as contentious, leave it alone.
- **Decisions already made in the plan with sufficient reasoning.** If the plan says "we'll use Postgres because X, Y, Z" and the reasoning is sound, don't re-litigate.
- **Things that will obviously be discovered in implementation.** "What's the exact return type of this function?" — let the implementer figure it out from context.

The user's attention is the budget. Spend it on things that change outcomes.

## Parent → child dependencies

Some decisions only matter if a parent decision goes a certain way. Always order the tree so parents come first.

Example chain:

```
Parent: Does the lead-status sync happen sync or async?
  If sync:
    Child: How do we handle the third-party API timing out? (retry inline vs fail fast)
  If async:
    Child: Which queue do we use? (existing SQS vs new Redis stream)
    Child: How do we handle the retry budget? (max attempts, backoff)
```

If the user picks "sync," the two async children disappear entirely. Asking them upfront wastes their time and confuses the conversation.

Mark dependencies explicitly when you present the tree:

```
1. Sync vs async lead-status update
2. [if sync] Third-party timeout handling
3. [if async] Queue choice (SQS vs Redis)
4. [if async] Retry policy
```

## When to merge questions, when to split

- **Merge** if two questions have only one sensible joint answer (e.g., "TLS version" and "cipher suite" — picking a modern TLS version implies a sensible cipher list).
- **Split** if a single sentence in the plan is hiding multiple decisions (e.g., "we'll add a rate limiter" hides: per-IP vs per-user? sliding window vs token bucket? in-memory vs Redis-backed?).

Err toward splitting. The user can answer a granular question quickly with one word; an over-merged question gets a vague answer that you'll have to re-interview to disambiguate.

## Worked example

Plan excerpt:

> Add a `/api/leads/import` endpoint that takes a CSV upload, validates rows, and writes valid leads to the database. Invalid rows go to an errors log. The endpoint should be reasonably fast for files up to ~10MB.

Decisions extracted:

```
1. Auth: who can call this endpoint?
   Why grill: plan is silent; security boundary.

2. Sync vs async processing:
   Why grill: 10MB CSV is borderline — sync may timeout, async needs job infra.

3. [if sync] Request timeout / max processing time:
   Why grill: one-way door — wrong value either drops large files or hangs workers.

4. [if async] Job storage (existing queue vs new):
   Why grill: depends on codebase — auto-check.

5. Validation: per-row or all-or-nothing?
   Why grill: changes user mental model; security implication (partial commit on invalid input).

6. Where does the "errors log" go? File? DB table? Returned in response?
   Why grill: plan is vague; affects UX and ops visibility.

7. Duplicate handling: skip, error, or upsert?
   Why grill: one-way door for the data model.

8. Auth header / CSRF for file uploads:
   Why grill: usually a footgun; auto-check existing upload routes if any.

Skipped:
- Exact CSV parsing library — likely already in deps, auto-resolve from imports.
- Endpoint URL — already specified in plan.
- HTTP method — POST is obvious for upload.
```

After the codebase pass: items 4 and 8 auto-resolve (queue exists in `app/queue.py`, no CSRF needed because we use bearer tokens — found in `app/auth.py`). Items 1, 2, 3-or-not, 5, 6, 7 go to the user — six questions, asked one at a time, with the dependency on #2 controlling whether #3 even gets asked.

That's the shape of a well-constructed tree: comprehensive on what matters, ruthless about what doesn't, and ordered so each answer informs the next.
