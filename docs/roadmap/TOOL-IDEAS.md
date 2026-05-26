# Constellation — Tool Adapter Ideas (beyond v1 explicit list)

**Version**: v0.2 (ratified by Zack 2026-05-24)
**Status**: brainstorm → triaged. v0.2 records Zack's accept/reject/reframe verdicts inline.
**关联文档**: [SOURCE-OF-TRUTH.md](../constitution/SOURCE-OF-TRUTH.md) · [DESIGN.md](../constitution/DESIGN.md) · [TOOL-ADAPTERS.md](../server/TOOL-ADAPTERS.md) · [USE-CASE-AUDIT.md](USE-CASE-AUDIT.md)

---

## ZACK'S VERDICT (v0.2, 2026-05-24)

Skim this first. Detail in §1–§5 below.

| # | Adapter | Verdict | Note |
|---|---|---|---|
| **T1** | `fs` | ✓ **critical** | Pairs with claude_code: biggest single use = "让 Claude Code 去不同目录里看东西" |
| **T2** | `apple_notes` | ✓ **critical** | — |
| **T3** | `web_search` | ✗ **reframe** | Don't build standalone Cortex adapter. Let claude_code's own web tooling do it. Zack has a Tavily key but routing through CC is preferred. |
| **T4** | `arxiv` | ✗ **reframe** | Same as T3 — via Claude Code. |
| **T5** | `gh` | ✗ **reject** | Not needed. |
| **T6** | `system_status` | ✓ | — |
| **T7** | `apple_shortcuts` | ✓ | — |
| **T8** | `twin_query` | ✓ | — |
| **T9** | `imessage` | ✓ | — |
| **T10** | `safari_state` | ✓ | — |
| **T11** | `whisper_local` | ✗ **reject (locks new constraint)** | "我发给你的东西肯定是固定的一段文本 prompt 和一张照片。我会用眼镜或者其他手机的其他服务来进行 STT。" Cortex never receives raw audio — input shape is always `{text, image?}`. Long-form audio handled by Glass / phone / external service before Cortex sees it. |
| **T12** | `screenshot_ocr` | ✗ **reject** | Vision lives in Cortex's GPT-4V calls on the photo Glass already sends. No need for a screenshot-the-Mac tool. |
| **T13** | `zotero` | ✗ **reject** | Zack doesn't use Zotero. |
| **T14** | `commitment_extract` | ✓ | — |
| **T15** | `time_zone_aware_scheduler` | ✓ | — |
| **T16** | `weather` | ✓ | — |
| **T17** | `notification_center` | ✓ | — |
| **T18** | `linear/notion` | ✗ **reject** | Zack doesn't use Notion. |

**Two new locked constraints from this triage** (will be recorded in SOURCE-OF-TRUTH revision):

- **N-8 (new non-goal)**: Cortex never receives raw audio. Inputs are always `{text, image?}`; STT happens upstream on Glass / phone / other client surface. → strikes T11 + similar tools.
- **R-1 (new policy)**: Web search / paper search / arXiv lookup go through `claude_code` (which has its own web tools), not through dedicated Cortex adapters. → strikes T3 + T4. May revisit if CC's web tooling proves inadequate.

---

---

## 0. Frame

The v1 [TOOL-ADAPTERS.md](../server/TOOL-ADAPTERS.md) catalog lists 6 adapters because those serve
the three explicit Source-of-Truth use cases. But [SoT §4](../constitution/SOURCE-OF-TRUTH.md) is emphatic:
**the deliverable is a unified framework, not the use cases**. The use cases stress-test the
framework; the framework should accommodate more.

This doc collects tool adapter ideas that fit Zack's envision but aren't in v1. Each entry has:

- **What it unlocks** — link to a real Zack workflow (HCI researcher at UIUC, PhD context, AR
  prototype builder, Apple-ecosystem user, multi-device wearable advocate)
- **Action sketch** — minimum surface to demo the idea
- **Risk × complexity** — informs which Phase / which session to do it
- **Cross-references** — which existing promise (P1–P6) or cool example (DESIGN §5) it pulls on

The goal isn't to add all of them. The goal is to **make explicit what the framework should
be ready for**, so we don't accidentally design ourselves into a corner where adding the
14th adapter is gnarly. Zack picks which to actually build.

---

## 1. TL;DR — the shortlist

Ordered by **leverage / specificity-to-Zack** ratio. Top half: high-leverage, ready-to-build;
bottom half: speculative or platform-dependent.

| # | Adapter | One-line | Risk | Effort | Phase fit |
|---|---|---|---|---|---|
| **T1** | `fs` | Read/write/grep arbitrary files (spec already exists). Unlocks Twin-adjacent files (Code/Projects/ notes) + UC1 attachments. | low | 0.5 d | 2 |
| **T2** | `apple_notes` | Notes.app via AppleScript. Quick capture > Reminders for prose; aligns with Zack's "Drop a thought" Quick Shortcut. | low | 0.3 d | 2 |
| **T3** | `web_search` | Tavily/Brave Search API. HCI researcher must look things up; Cortex needs this for "did anyone publish on X?" intents. | low | 0.5 d | 2-3 |
| **T4** | `arxiv` | arxiv.org search + paper metadata + PDF fetch. Zack reads papers daily; Twin's `interests/` becomes alive when Cortex can match new arXiv → interests. | low | 0.5 d | 2-3 |
| **T5** | `gh` | GitHub CLI wrapper. List/comment PRs+issues, fetch PR diffs. Pairs with [D1](../constitution/DESIGN.md) reverse-wake ("Your PR got reviewed") and UC2 supervision style. | low | 0.5 d | 3 |
| **T6** | `system_status` | battery / focus_mode / current_app / network / time-of-day. Router uses for **routing decisions** (don't pulse in DND; prefer SMS over email if commuting). | low | 0.3 d | 2 |
| **T7** | `apple_shortcuts` | Invoke any user-defined Apple Shortcut. **Massive leverage** — Zack's existing Shortcuts library becomes Cortex-callable for free. | low | 0.5 d | 2-3 |
| **T8** | `twin_query` | Semantic grep over Twin (grep + LLM synthesis). [INTERFACE-CONTRACTS §5.1](../server/INTERFACE-CONTRACTS.md) lists this for MCP; same engine should serve Cortex internally for [B2/B3](../constitution/DESIGN.md). | med | 1 d | 3 |
| T9 | `imessage` | iMessage read/send via Messages.app DB + AppleScript. Same shape as mail but more frequent traffic. | med (auth) | 1 d | 4 |
| T10 | `safari_state` | Current tab / browsing history (last 24h) via Safari AppleScript + History DB. Lets "I want to save this page" voice intent work. | med | 1 d | 4 |
| T11 | `whisper_local` | Whisper.cpp wrapper for ambient transcription. Enables UC3-D (parked) and B-class cool examples that need long-form audio. | med | 1-2 d | 5-6 |
| T12 | `screenshot_ocr` | Capture frontmost screen → GPT-4V OCR / scene-describe. Pairs with C3 "white-board archive" cool example. | low | 0.3 d | 3-4 |
| T13 | `zotero` | Zotero local library access (SQLite + better-bibtex). Needed for serious paper / citation workflows. | med | 1-2 d | 5+ |
| T14 | `commitment_extract` | Cortex-internal "find new commitments in this conversation" tool. Feeds `commitments/` for P6. | low | 0.5 d | 7 |
| T15 | `time_zone_aware_scheduler` | Add `tz` field to calendar/meeting flows; resolve "10am Jane time" against people/core/jane-doe.md's `tz:`. | low | 0.3 d | 4 |
| T16 | `weather` | Trivial fetch. Combine with `system_status` for "bring umbrella" P6 pulse. Token cost: nothing. | low | 0.1 d | 7 |
| T17 | `notification_center` | Read pending macOS notifications. Cortex can summarize / dismiss / promote them. | med | 1 d | speculative |
| T18 | `linear` / `notion` | If Zack uses these for projects. Currently he uses Claude Code + repos directly, so deferred. | low | 0.5 d each | speculative |

**Heuristic**: a tool earns its place if it (a) maps to a *concrete* moment in Zack's day,
or (b) unlocks one of the ★ cool examples in [DESIGN §5](../constitution/DESIGN.md). Tools that fit neither
are speculative.

---

## 2. By category — why each cluster matters

### 2.1 File + capture (T1, T2, T12)

Voice intents like "save this paper to my reading list", "snap that whiteboard and write
the key points to Twin", "log this thought" need a write target that's not Reminders or
Calendar. Notes.app is the right home for prose; `fs` writes to project repos / Twin
sidecar; OCR turns image-capture into Twin-writable text.

This cluster makes the Glass + voice combo actually useful for **knowledge capture**, which
is currently the gap between UC1 (email) and UC3 (faces). Without it, the Glass is mostly an
output device.

### 2.2 Research workflow (T3, T4, T13)

Zack reads papers. The `interests/` Twin folder is designed for P6 to surface "new arXiv
papers on RL" — but that requires `arxiv` adapter. `web_search` is the broader fallback
("did anyone study haptic feedback in waveguide displays?"). Zotero is the heavy version
once paper management gets serious.

Without these, [B1 "承诺履约监控" pulses](../constitution/DESIGN.md#5) can fire but Cortex has nothing to
*surface that's actually new*. Twin becomes a static profile instead of a living signal.

### 2.3 Cross-app supervision (T5, T9, T10, T17)

The bidirectional supervision pattern (P4) generalizes well past Claude Code. Same
mechanism can wake Zack for: GitHub PR comments arrived, iMessage from a `people/core/`
contact, browser tab matched an `interests/` topic, OS notification queue piling up.
Each is a small adapter; all share the reverse-wake infrastructure built for `claude_code`.

This is where [Q-2 Insight Engine + simple LLM evaluation](../constitution/DESIGN.md#4) earns its keep —
without diverse signal sources, the Insight Engine has nothing to evaluate.

### 2.4 Cortex's own self-knowledge (T6, T14, T15)

`system_status` is small but high-leverage: Router becomes context-aware. If Focus mode is
"Deep Work", suppress P6 pulses. If battery is < 20%, defer image-heavy vision tasks.
If location is "office" (via Tailscale + Wi-Fi heuristic), prefer Mac-mini-side tools over
Glass-side. These are decisions Cortex *should* make but can't without input.

`commitment_extract` and `time_zone_aware_scheduler` are similar — small Cortex-internal
tools that elevate the planning quality, especially as Twin grows.

### 2.5 Glass-side leverage extensions (T7)

`apple_shortcuts` deserves its own callout: Zack likely already has a dozen Shortcuts that
do useful things (HomeKit scenes, batch image processing, focus toggles, etc.). The cost
of exposing them as Cortex-callable tools is one adapter that runs `shortcuts run "X" -i
<json>` and parses output. Suddenly the framework absorbs Zack's existing automation
without rebuilding any of it.

This is exactly the "**在已有工具栈之上加智能**" line from [identity.md](../../../Constellation-Server/twin-seed/identity.md)
made concrete.

### 2.6 Long-form audio (T11)

UC3-D (ambient conversation transcription) was parked because Glass v1 Voice Invoke is
short utterance + VAD-stop, not a long-form recording mode. `whisper_local` is the Mac-side
piece: once Glass can stream long audio (Phase 5+), Cortex processes it locally to feed
`conversations/`. Without this, the entire "and what did we talk about last week" question
class stays unanswerable.

---

## 3. What I'm explicitly NOT proposing (and why)

Worth marking the boundary so future-me doesn't re-litigate these.

- **Cloud Office (Google Docs / Office 365 / Slack / Discord)**: Zack's stack is
  Mac + iCloud + Anthropic + OpenAI. Adding broad SaaS adapters bloats AVAILABLE TOOLS in
  the Router prompt without serving anyone. Add if Zack adopts one.
- **A general "shell run" tool**: dangerous + redundant with `claude_code` + `fs` + Apple
  Shortcuts. SoT C-9/C-10 (HITL non-negotiable) makes arbitrary shell painful UX anyway.
- **A "browser_automation" tool (Playwright/Puppeteer)**: high complexity, high risk; Zack
  prefers his real browser. If web automation is needed for a real demo, build Apple
  Shortcut wrappers first.
- **Music / Spotify / HomeKit / Smart Home**: cool but veers Constellation toward "personal
  assistant" rather than HCI research prototype. Different product surface. Defer until
  framework is mature enough that drift doesn't matter.

---

## 4. Cross-cutting infra these will need

Several ideas above pressure-test the same parts of the framework. Worth noting so we know
what to harden in the spine:

| Need | Triggered by | Notes |
|---|---|---|
| **Streaming RPC** | T11 (whisper transcript stream) | Today's `RPCResult` is a single response. Long jobs need chunked / progress updates. Phase 5 spine work. |
| **Adapter-side LLM calls** | T8 (twin_query), T12 (screenshot_ocr) | Tool Agent currently never calls LLM. If we let some adapters call GPT (for OCR or RAG), need to thread the API key + budget tracking. |
| **TCC permission UX** | T2, T9, T10, T17 (Notes, Messages, Safari, NC) | Each new osascript-touching app re-prompts TCC. Document the list; consider a `./scripts/grant-tcc.sh` helper that pre-fires no-op queries to all needed apps. |
| **Context-aware Router prompt** | T6 (system_status injected into USER STATE) | Currently `_build_user_prompt` injects `now` + `active_devices=[glass]` only. Add slots for focus_mode, location, battery — keep small to control prompt bloat. |
| **Per-adapter token budgets** | T8, T11, T12 | LLM-calling adapters need quota; otherwise a runaway prompt blows the monthly $100 cap from the risk register. |
| **Adapter capability filter by context** | All of them | When Twin grows to 30 adapters, dumping all into AVAILABLE TOOLS bloats every Router call. Pair with the [DATA-MODEL §11](../server/DATA-MODEL.md) two-pass context_pack — first GPT picks tools + Twin slices to load, then second call dispatches. |

---

## 5. Suggested ordering across remaining v1 phases

Below: what I'd weave in given the [IMPLEMENTATION-PLAN](IMPLEMENTATION-PLAN.md) phasing.
Not a commitment — Zack decides.

| Phase | Already planned | Add from this list (post-triage) |
|---|---|---|
| Phase 2 Slice C wrap | claude_code, applescript_mail (✓ done), applescript_calendar (✓ done) | **T1 fs** ★, **T2 apple_notes** ★, **T6 system_status**, **T7 apple_shortcuts** |
| Phase 2 polish | feedback loop polish, two-pass context_pack | — |
| Phase 3 (Android phone) | Glass client | — |
| Phase 5 (UC2 reverse-wake) | claude_code reverse-wake | **T9 imessage**, **T10 safari_state**, **T17 notification_center** — same reverse-wake mechanism, more signal sources |
| Phase 6 (UC3 faces) | face recognition | — (T12 rejected) |
| Phase 7 (Insight Engine + learning) | P6 + implicit learning | **T8 twin_query**, **T14 commitment_extract**, **T15 time_zone_aware_scheduler**, **T16 weather** |
| Phase 8 (MCP) | MCP read-only | T8 twin_query reused on MCP read path |
| Phase 9 (dogfood) | dogfood week | — (audio handled upstream per N-8) |

---

## 6. Concrete asks for Zack

Reading this, the kinds of feedback that would help:

1. **Strike-throughs**: which of the 18 above are wrong-shaped for your envision? (e.g. "I don't actually use Notes.app, kill T2")
2. **Promotions**: which speculative ones are actually high-leverage I missed? (e.g. "T13 Zotero is higher than you ranked — I'd use it daily")
3. **Whole new clusters**: what dimension of your day did I miss entirely? (e.g. "I'd want Cortex to know my workout state from Apple Watch")
4. **Anti-clusters**: anything I should commit to *never* building because it'd warp the framework? (e.g. "no, never go near my finance apps")

This file is meant to be edited / version-bumped as the envision sharpens.

---

*v0.1 — written during Slice C session 2026-05-24 in response to Zack's prompt:*
*"我不只是我前面提到的几个用例中的那些功能。你还要考虑一些其他的、我可能没提到但也很重要的功能…根据我的 envision，还有我的这个使用场景，来想一些其他可能要完成的工具。"*

*v0.2 — same session, after Zack's triage. Two new SoT-level constraints captured*
*(N-8 audio-never-raw, R-1 web-search-via-CC). Build order: T1 + T2 next, both critical.*
