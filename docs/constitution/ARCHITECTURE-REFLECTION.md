# Constellation — Architecture Reflection (v3, 2026-05-26)

This doc is a deliberate critique of the current Constellation architecture
written AFTER multiple rounds of building + dogfooding. Not cheerleading. The
goal is to call out what's brittle, what's unnecessary, what should be torn
down, so the next phase isn't blinded by the existing implementation.

Use this alongside [HANDOFF.md](../../HANDOFF.md) and
[IMPLEMENTATION-PLAN.md](../roadmap/IMPLEMENTATION-PLAN.md).

---

## What we built that's working

**Solid, keep**:
- **3-button contract** (Approve / Modify / Kill) — converged through several
  iterations. Maps to the always-on Glass voice channel cleanly: voice "ok"
  → Approve, voice substantive → Modify, voice "停" → Kill.
- **Classifier-routed simple vs complex** at the door. Sub-second decision
  on every invoke; complex routes to the agent path, simple to v0.5 planner.
- **Agent path** (`claude_code.agent`): CC in tmux, jsonl tail for free
  stream-json, $0 marginal cost via subscription. Multi-phase checkpoint
  pattern works (CC pauses at phase boundary, user steers via Modify, CC
  resumes via paste-into-same-tmux).
- **Modify-on-FINAL resume** (this morning's work): `claude --resume <id>`
  loads CC's prior research context; revised drafts in ~10-15s vs minutes
  for a fresh re-research.
- **HUD session model**: every user_invoke either starts or extends a
  conversation thread (file-backed JSONL). Continue button restores
  session_id. /sessions UI works on phone via mobile-stack pattern.
- **Twin v2** (this afternoon): 4-slot layout, minimal frontmatter,
  Anthropic Agent Skills format. Agent reads the README contract before
  writing — verified in practice.
- **Visual-viewport + interactive-widget=resizes-content + 100dvh** for
  iOS PWA: composer rides above keyboard, no black-chin flicker.
- **Glanceable HUD ticker**: emoji + ≤80c per row; thinking heartbeat
  carries last-tool context.

These are not just "implemented" — they survived adversarial testing
(crashes, race conditions, wrong-button flows) and are stable.

---

## What's brittle or over-engineered

### 1. Three processes for one machine

**Cortex (port 8888 WSS + 8890 HTTP), Tool Agent (port 8889 WSS), Console Edge
(port 9100 HTTP) — all on the same Mac mini.**

Tool Agent existed because of an original "tool execution is LOCAL, agent
reasoning is CLOUD" boundary. That boundary evaporated: CC now runs locally
in tmux, and the only "cloud" piece is Cortex's GPT calls for routing.

Today Tool Agent is just an extra IPC hop. Each agent dispatch is:
```
Glass → Cortex (WSS) → Tool Agent (WSS) → tmux → claude → jsonl
                  ↑           ↓
                  └── progress events ──┘
```

We've hit at least two bugs that stemmed from this split (sequential RPC
dispatch blocking agent_progress; concurrent-dispatch wiring). Each bug
took non-trivial debugging because the cause crossed processes.

**Could collapse Tool Agent into Cortex.** Cost: a GIL-contention concern
since adapter calls are sync-ish (osascript subprocess.run). Benefit: one
WSS, one log file, one restart, one mental model.

### 2. Two parallel agent paths

`_handle_user_invoke` runs the classifier, then either:
- **Simple path (v0.5)**: selector LLM → router LLM → per-subtask dispatch → card
- **Agent path**: brief assembly → claude_code.agent → CC in tmux → card

The simple path was originally the WHOLE system. Then we built the agent
path for complex asks. Then we pruned the simple-path tool catalog to
~10 bounded actions. Now the simple path runs 3 LLM calls (classifier +
selector + router) for "remind me at 5pm" — slower than it should be.

The simple path also still carries R-3 multi-step machinery that's
functionally dead (the pruned catalog can't express multi-step asks).
That's vestigial code that confuses readers + adds bug surface.

**Two ways to simplify**:
- (a) Keep both paths but rip out R-3 from the simple path; it's dead.
- (b) Collapse to a single agent path. Classifier still chooses, but
  "simple" goes through claude_code.agent with a `fast_mode=true` flag
  that ALSO uses bounded brief + ≤2-tool-call budget + 30s timeout.
  Pro: one code path. Con: every simple ask pays ~8s tmux cold-start.

Recommendation: do (a) now. Reconsider (b) if/when CC TUI spawn cost drops.

### 3. CC tmux cold-start tax (~8s per dispatch)

Each agent dispatch spawns a new tmux session, launches claude, dismisses
the bypass-permissions safety screen, pastes the brief, then tails the
jsonl. Cold start: ~5-8 seconds.

For multi-turn HUD sessions (invoke → modify → modify → modify), we eat
this cold start 3+ times. Modify-on-FINAL spawns a fresh tmux to
--resume — also pays cold start.

**Real fix**: keep ONE long-lived tmux per HUD session. The first invoke
spawns it; every subsequent turn (modify, fresh invoke that "continues
this session") pastes into the same tmux. Session end (user clicks New /
Kill / TTL fires) kills tmux.

Risk: long-lived tmux + CC accumulates jsonl over weeks → memory growth +
attention dilution (CC's prior turns become noise). Mitigation: cap at
e.g. 24h or 20 turns per tmux; auto-cycle when threshold hit.

**Latency win**: 8s → 0.5s per turn after the first. Big UX upgrade.

### 4. No prompt caching

Agent brief is ~4 KB. ~95% is identical across invokes (Twin pointer, rules,
Mail-perf tip, Apple ecosystem section). The 5% that varies is the ASK +
NOW timestamp.

CC supports Anthropic's prompt-caching. If we structured the brief so the
stable parts come first + are flagged for caching, repeated dispatches
within 5 min get cache hits on the ~95% static prefix. Practically: lower
latency + lower cost (in API-mode, doesn't matter for subscription mode).

Doesn't help latency on subscription-mode but reduces token utilization
quota. Future-relevant if subscription quotas tighten.

### 5. Sessions grow forever

`~/constellation/twin/_system/sessions/ses_*.jsonl` is append-only. No
archive, no rotation. After 6 months of daily use → ~200 files. Not a
crisis but no plan.

**Fix shape**: rotate sessions older than 30 days into
`_system/sessions/archive/YYYY-MM/` (read-only at HUD UI; still on disk
for forensic queries).

### 6. No undo / no rollback

Receipts are an audit log. They don't support "undo this reminder.add" or
"rollback this fs_write". The HUD's Kill button kills future work, not
past work.

**For Apple side effects**: not our problem — Reminders.app has its own
undo. Same for Calendar / Mail-drafted (drafts stay drafts).

**For fs.write under twin/**: every write should be CHANGELOG.md-logged
(it is) AND the prior content should be saved in `_system/twin_history/`
so an "undo" is mechanical. Currently overwrite is irreversible.

### 7. Heavy CC lock-in

Constellation depends on:
- CC's `--session-id` semantics
- CC's `--resume <id>` semantics
- CC's jsonl write format (paths, event types)
- CC's bypass-permissions safety prompt UX
- Tmux as the IPC surface

Anthropic could change any of these in a CC update and break us. We hit
TWO breakages in this conversation alone:
- v2.1.150 added the "Bypass Permissions" safety screen
- `--session-id` semantics differ from `--resume`

**Mitigation**: pin CC version explicitly. Document expected behavior.
When CC updates, run our smoke tests before assuming compat.

### 8. The classifier is still gpt-5.2

We documented a swap-to-haiku follow-up. Still pending; needs Anthropic
API key plumbed. Each invoke pays ~$0.001 for the classifier. Over a year
of daily use (~3-5 invokes/day): ~$1-2. Not financial pain; not urgent.

### 9. Apple TCC fragility

First Mail.app / Calendar.app osascript invocation needs user-Allow in
System Settings. Subsequent invocations are silent. But macOS Software
Updates can wipe TCC grants. There's no graceful prompt — the agent just
hangs.

**Mitigation**: detection script that runs Mail.app/Calendar.app/Reminders
osascripts on cortex startup, surfaces "TCC required" card if any fails.
Not urgent but eventually annoying.

### 10. The HUD is the only client *(superseded 2026-05-26 by v2.1 pivot)*

~~We have a phone-friendly PWA. No Glass client.~~

**Status now**: Phase 3b Glass client (`Constellation-Glass` repo, branch
`pivot/baremetal-v2.1`) is well underway. After getting most of v2.0 done
(CXR-L bridge path) we discovered CXR-L is actually a phone-side SDK; the
correct path is bare-metal Android Go directly on the R08 glass. Code
was reworked into `glass` + `phoneDebug` product flavors with a clean
`HudPlatformAdapter` abstraction. Both flavors compile; phoneDebug
verifies the protocol on a regular phone (OnePlus 9). Real-device deploy
on R08 is gated on getting a dev-cable (P1.5 in TODO.md).

The "abstraction creak" we were worried about (multi-client WSS protocol
written for one client) actually paid off: the same Cortex code serves
both web HUD and Glass with no per-client branching.

---

## What's vestigial / can be deleted

- **`_system/TOC.md` and `_system/schema.md`** — already deleted today (twin v2).
- **R-3 multi-step machinery in cortex/server.py + cortex/router.py** —
  `_advance_task`, `task_continues`, `task_history`. The pruned simple-path
  catalog can't express multi-step asks anymore. Dead code that confuses.
- **`Twin.assemble_context_pack`** — only used by v0.5 router. Agent path
  doesn't use it. If we keep simple path and don't touch v0.5, leave it.
  If we delete v0.5, this goes too.
- **Legacy `_send_keys` / `_run_interactive` / `_start_watcher` actions**
  in claude_code adapter — pre-Phase-5 reverse-wake stuff. Still loaded
  but no callers from the new agent path. Could be marked deprecated.
- **`echo` adapter** — Phase-1 stub for testing the spine. Still in
  adapters.yaml. Harmless but vestigial.
- **`route_stub`** in router.py — Phase-1 echo router. Path remains for
  `--use-stub-router` flag. Could be removed.

---

## What's worth tearing down + rebuilding

These are bigger calls; flagged for discussion before action:

### A. Collapse Tool Agent into Cortex
- **Pros**: one process, one log, fewer IPC bugs, simpler restart
- **Cons**: GIL contention if any adapter does CPU-heavy work; not currently true
- **Verdict**: probably yes. Schedule as a focused refactor turn.

### B. Replace v0.5 simple path with a single-tool fast lane
- **Pros**: kills R-3 dead code, fewer LLM calls per simple ask, one
  agent code path
- **Cons**: simple asks pay CC tmux cold-start
- **Verdict**: defer until (C) lands — long-lived tmux per session would
  make this acceptable

### C. Long-lived CC per HUD session
- **Pros**: massive latency win (8s → 0.5s per follow-up turn), aligns
  with CC's resume semantics naturally
- **Cons**: state management for tmux lifecycle; jsonl bloat per session;
  attention dilution
- **Verdict**: yes, with TTL + per-session limits. Highest UX-leverage item.

### D. Move stable brief sections into a CLAUDE.md the agent loads
- **Pros**: prompt caching, smaller per-invoke brief, separates "this
  ask" from "always-true context"
- **Cons**: requires `--system-prompt-file` or similar; one more file
  to keep in sync
- **Verdict**: lower priority than (C). Worth a half-day later.

---

## Distiller — just built, untested at scale

The auto-distiller was added in this conversation
([cortex.distiller.Distiller](../../../Constellation-Server/cortex/cortex/distiller.py)). It's wired
into the Modify decision path; triggers when ≥ 2 unprocessed Modifies
have accumulated AND cooldown (30 min) has passed. Runs in background;
surfaces a preview_action card only when it finds a non-trivial pattern.

**Untested at scale.** Does it find real patterns or hallucinate? Does
it propose useful Twin updates or noise? Will only know after a week of
dogfooding. Tuning knobs: cooldown, min-modify threshold, lookback
window.

This is THE feature that closes the implicit-learning loop — if it
works, the Twin grows organically; if it doesn't, the queue is just data
collection with no payoff.

---

## Bottom line

The current architecture works. It's not optimal. The two biggest
levers — **(C) long-lived CC** and **(A) merge tool_agent into cortex** —
together would simplify ~30% of the codebase + improve latency by
~5-10× for follow-up turns.

The smaller fixes (rip out R-3, prune vestigial actions, archive old
sessions, swap classifier to haiku, TCC self-check, prompt caching) are
all 1-2 hour items individually.

The real product gap was **the Glass client**. Phase 3b is now mid-flight
on branch `pivot/baremetal-v2.1` in `Constellation-Glass`. After v2.1
real-device deploy (P1.5), the gap closes.

---

*Written 2026-05-26 after multiple dogfooding sessions revealed where
the abstractions creak. Annotated 2026-05-26 (same day) post-v2.1 pivot.
Re-read before any next-phase refactor.*
