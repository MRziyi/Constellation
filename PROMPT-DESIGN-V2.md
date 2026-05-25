# Cortex Router — Prompt v0.5 (two-pass, on-demand Twin loading)

**Status**: design ⇒ implementation in progress (2026-05-25)
**Supersedes**: [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) §2 "User Prompt Template (v0.3)" + the eager-loading behaviour of `Twin.assemble_context_pack()`
**Trigger**: Zack's read of the live v0.4 prompts in the Console's prompt-inspector (`/llm/calls/<id>`). Verdict: information density is too low; the Router is shown the whole Twin every turn, most of which is unrelated to the task. "应该是作为 skill 让它按需加载."

---

## 1. The problem with v0.4

v0.4's user prompt sends, on every invoke:

```
[ identity.md         ] ~1100 tokens
[ skills/email-style  ] ~600
[ skills/code-style   ] ~500
[ skills/dispatch     ] ~500
[ skills/confirm-policies ] ~700
[ skills/pulse-feedback   ] ~400
[ skills/insight-engine   ] ~600
[ skills/twin-write-policy] ~400
[ skills/claude-code-control ] ~900
[ skills/reminder-style   ] ~300
[ people/core/jane-doe.md ] ~250
[ people/core/mike-chen.md] ~250
                               ─────
                            ≈ 6500 tokens of TWIN context
```

…shipped on **every** call. When the ask is *"how's my battery?"*, the Router still
sees the whole email-style guide. Costs:

1. **Token waste**: ~5K of irrelevant context per call ≈ measurable spend at scale.
2. **Signal-to-noise**: gpt-5.2 is demonstrably more cautious when handed long
   contexts containing irrelevant policy text. "lost in the middle" is real even
   with extended-context models.
3. **Bad pattern for growth**: at v0.4 the Twin is ~12 files. The design target
   is **hundreds** (`people/encounters.md`, `conversations/*`, `commitments/*`,
   `interests/*`, plus arbitrary user skills). Eager-load doesn't scale.
4. **Coupling**: every Twin write requires a Router re-read on the next turn.
   Insight Engine and the Implicit Learning Loop would worsen this.

Zack's seed `_system/TOC.md` already anticipates the fix — it calls itself the
"Anthropic-Skill-style hook" and provides one-line descriptions designed to let
an LLM decide "should I load this file?". v0.5 finally uses it.

---

## 2. v0.5 architecture: two-pass

```
                       ┌──────────────────────────────┐
                       │     Cortex Router (gpt-5.2)  │
   user_invoke         │                              │
       │               │  pass 1 — selector (~1.5K)   │
       ▼               │  ──────────────────────────  │
  [Cortex]  ──────────▶│  System: "pick paths from    │
       │               │   the TOC"                   │
       │               │  User: ASK + TOC table       │
       │  ┌────────────┤  →  {paths:["identity.md",   │
       │  │ {paths}    │       "skills/reminder-..."]}│
       │  ▼            │                              │
       │  twin.assemble_context_pack(paths)           │
       │  │            │  pass 2 — planner (~4–7K)    │
       │  ▼            │  ──────────────────────────  │
       └─────────────▶ │  System: same as v0.4        │
                       │  User: ASK + selected files  │
                       │                              │
                       │  → dispatch plan JSON        │
                       └──────────────────────────────┘
```

### Cost model

| Call type            | v0.4 (eager) | v0.5 (two-pass)                              |
|---|---|---|
| **Single-shot invoke**  | 1 call, ~11K tokens     | 2 calls: ~1.5K (selector) + ~4–7K (planner) = **~5.5–8.5K** |
| **Multi-step round 2+** | 1 call, ~11K + history  | 2 calls: ~2K (selector, +history) + ~5K (planner) = **~7K** |
| **Cache hit (re-run)**  | ~0 (full cache hit)     | ~0 (both layers hit)                         |

Two RTTs ≈ +2–4s wall-clock per uncached invoke. Acceptable trade for:
- 30–50% token reduction on the dominant cost (the planner)
- Linear scaling as the Twin grows (selector cost is constant in #-of-files
  because TOC is a flat table; planner cost depends on what's *picked*, not
  what *exists*)

### Why not just expand the Anthropic prompt cache?

Anthropic's automatic prompt cache works on **prefix** match. v0.4 puts the
Twin in the user message (varies with ASK), so cache rarely hits. Putting the
Twin in the system prompt would help BUT loses the per-task tailoring.
Two-pass selection is more general: each ASK gets exactly the skills it needs.

---

## 3. The selector prompt (pass 1)

### Design principles

1. **One narrow job**: just emit a path list. Don't reason about tools or plans.
2. **Bias toward fewer**: every extra path costs ~500 tokens of pass-2. Median
   good answer is 1–3 paths. Hard cap 5.
3. **No fallback into "pick everything if unsure"** — the system prompt frames
   uncertainty as "skip rather than over-include". A skipped relevant skill is
   recoverable (planner falls back on identity.md basics); an over-included
   irrelevant skill is dead tokens forever.
4. **Stable output shape**: pure JSON, single key `paths`. Validator strips
   any path that isn't in the TOC (defence vs Router hallucinating).
5. **Cheap to cache**: input doesn't include NOW (time-sensitive) so a repeat
   ASK hits cache instantly.

### Prompt body (v0.5 selector)

```
SYSTEM:
You are Cortex's Twin selector. Zack just spoke; pick which Twin files the
planner needs to plan the next action — and ONLY those.

Output JSON, nothing else: {"paths": ["identity.md", "skills/X.md", ...]}

Rules:
• Include identity.md ONLY if the ask is about Zack himself, his preferences,
  his style, or naming/addressing him. Mechanical asks (status, time) don't
  need it.
• Include people/core/<slug>.md ONLY when Zack names that person (by name or
  one of their aliases listed in the TOC).
• Include skills/X.md ONLY when X is directly relevant to the immediate ask.
  Don't pre-emptively grab adjacent skills "just in case".
• Maximum 5 paths. Median good answer is 1–3. ALL paths must be in the TOC.
• When unsure between two skills, pick the more specific one.

USER:
THE ASK
Zack said: "<text>"
[NEW PHOTO ATTACHED]              # only when an image is in the payload

[PRIOR ROUNDS (compact)]          # only on multi-step continuation
R1 — "intent" — tool.action(query) → result(120c)
R2 — Zack: feedback "..."

TWIN TOC
identity.md                     | Zack's core archive: basic info, philosophy, AI stack
skills/email-style.md           | How Zack writes emails (tone, greetings, sign-offs)
skills/reminder-style.md        | Reminder title conventions (no articles, first-name only)
skills/code-style.md            | Code review comments + PR description voice
skills/dispatch-policy.md       | Learned tool routing preferences
skills/claude-code-control.md   | Regex patterns + keys for tmux CC
skills/confirm-policies.md      | Per-tool preview/auto policy
people/core/jane-doe.md         | HCI/AR researcher at MIT; email-preferred
people/core/mike-chen.md        | Stanford CS PhD; iMessage-preferred
...

YOUR JOB
Pick. JSON only.
```

This is **~1500 tokens** total. Doesn't include any twin file *bodies*.

### Validator

`select_twin_paths()` validates the response:
- Strict JSON parse (falls back to `json_repair`)
- Must be `{paths: list[str]}`
- Each path must be in the TOC (`set` membership check)
- Cap at 5
- On any failure: fall back to `["identity.md"]` (safest default — doesn't
  block the planner from doing *something* sensible)

### What goes in the TOC

`Twin.build_toc()` produces the table by merging:

1. **Curated entries** from `~/constellation/twin/_system/TOC.md` (Zack-maintained)
2. **Auto-discovered** files in `skills/`, `people/core/`, `people/encounters.md`,
   `projects/`, `commitments/`, `interests/` that aren't in (1). For each:
   - frontmatter `description:` → use verbatim
   - else: synthesise from frontmatter (people: `relation` + `affiliation` +
     `preferred_contact`; skill: `name` + first H1)
3. **Excludes**: `receipts/*` (transient log, not context), `CHANGELOG.md`,
   `README.md`, `_system/*` itself.

Hot-reload: re-parse on each call if `_system/TOC.md` mtime changed; cheap
(< 1 ms for a couple hundred lines of markdown).

---

## 4. The planner prompt (pass 2)

Same as v0.4 SYSTEM_PROMPT (the directives + result_format + multi-step rules
+ free-form feedback + HUD body design). **No change**.

What changes: the user prompt's TWIN block now contains only the selected
paths, not all paths. Example for ask `"remind me to call mom tonight"`:

```
ZACK'S DIGITAL TWIN
=== identity.md ===
<content>
=== skills/reminder-style.md ===
<content>
```

vs v0.4 which would have included email-style, code-style, claude-code-control,
dispatch-policy, etc.

### When NO twin file is selected

`_system/TOC.md` lookups can legitimately return an empty path list — e.g.
"how's my battery". In that case the TWIN block is **omitted entirely**. The
planner sees only THE ASK + AVAILABLE TOOLS + YOUR JOB. Plan is still valid
(Router can emit a `system_status.get` dispatch without knowing anything
about Zack).

---

## 5. Multi-step semantics

For round N>1, the selector also receives a **compact prior-round digest**
(top of the user prompt). This lets the selector adjust paths as the task
evolves — e.g. round 1 found Mike's email, round 2 may now need email-style
to draft a reply.

The selector's per-round cost is bounded:
- Round 1: ~1.5K tokens
- Round 5: ~2.5K tokens (slightly more history)
- Total selector cost across 5-round task: ~10K, vs ~30K for the planner
  alone (5 × ~6K planner with picks ≈ 30K)

---

## 6. Telemetry & inspector integration

Both passes go through `cached_chat_create()` with distinct `purpose` tags:

| purpose | call shape                          |
|---|---|
| `selector` | small system + ASK + TOC; emits JSON `{paths: [...]}` |
| `router`   | large system + ASK + selected twin + TOOLS; emits dispatch plan |

The Console's `/llm` route already lists by call_id; the prompt-inspector
detail view shows full prompts. With v0.5 you'll see TWO entries per invoke
(selector then router) — that's intentional and useful for debugging selector
quality ("did it pick the right skill?").

---

## 7. Failure modes & fallbacks

| Failure                                  | Fallback                                       |
|---|---|
| Selector JSON parse error                | Retry once via `json_repair`; else `["identity.md"]` |
| Selector picks path not in TOC           | Drop silently + log warning                    |
| Selector returns empty list              | Honour it — TWIN block omitted                 |
| Selector LLM API error                   | Fall back to `["identity.md"]` + skill files matching keyword overlap with ASK (cheap regex over TOC) |
| Selector hits cache                      | Skip directly to planner (already 0-RTT)       |
| Planner schema validation fail           | Same v0.4 behaviour: `router_fallback` card    |

The defence-in-depth principle: the selector being WRONG just makes the planner
slightly less informed; the planner being wrong is a real UX miss. So the
selector errs aggressively toward "give me less to read" — the planner can
always do something reasonable with just identity.md.

---

## 8. Migration

- **No schema change** to the Glass / Tool Agent / Twin file format.
- **`Twin.assemble_context_pack()`** keeps its signature but the default
  changes: returns `{"identity.md": ...}` only when called with no args.
  New required call site: pass an explicit `paths=` list.
- **`router.route()`** unchanged externally; internal: gets a smaller
  context_pack passed in.
- **`router.select_twin_paths()`** new public async fn.
- **`server.py`** _handle_user_invoke + _advance_task: insert one
  `await select_twin_paths(...)` before the existing route call.
- **Caching**: both passes use the same diskcache; no migration needed.
- **Backward compat**: `--use-stub-router` still bypasses both passes.

---

## 9. Success criteria

Verified by extending `/private/tmp/comprehensive_test.py`:

1. **Token reduction**: median planner-call `prompt_chars` drops from ~40K
   (v0.4) to ≤ 20K (v0.5).
2. **Behaviour parity**: all 9 paradigms (A–J) that PASSed in v0.4 still PASS.
3. **Selector quality** (manual review of inspector):
   - "remind me to call jane at 3pm" → picks `identity.md`, `people/core/jane-doe.md`, `skills/reminder-style.md`. **Not** email-style, **not** code-style.
   - "how's my battery" → picks `[]` (no twin files needed).
   - "draft an email to mike about CHI" → picks `identity.md`, `people/core/mike-chen.md`, `skills/email-style.md`.

If selector picks wrong on a real ask, that's a prompt-tuning iteration on
the selector — quick to fix without touching the planner.

---

## 10. Out of scope (this revision)

- **TOC auto-maintenance** (cortex periodically rewrites `_system/TOC.md` from
  disk state). Manual TOC + auto-discover for now.
- **Hierarchical loading** (selector picks a directory, planner reads
  index, picks file). Defer — current Twin is flat enough.
- **Selector-as-classifier** (router emits an intent label, lookup table
  maps label → skills). More efficient but less flexible; defer to v0.6 if
  selector LLM cost becomes the bottleneck.
- **Streaming the planner response** while still generating. Latency win but
  the dispatch plan needs to be complete before Cortex can act on it.

---

*End of PROMPT-DESIGN-V2 — implementation in `cortex/cortex/router.py` (`select_twin_paths`), `cortex/cortex/twin.py` (`build_toc`, path-filtered `assemble_context_pack`), `cortex/cortex/server.py` (two-pass wiring).*
