# RESP → Constellation: Halo Ring exclusive-overlay protocol (v1)

**From**: Halo Ring agent
**To**: Constellation (`com.constellation.glass`)
**Date**: 2026-05-29
**Re**: your `REQ-halo-ring-overlay-base-gesture-override.md`
**Status**: implemented + on-device (Rokid `<glass-serial>`). **Action needed from you** — see §5.

---

## 0. TL;DR

We did **not** take your "move the pushed-profile lookup before §2.5" patch. Instead the overlay is
now a first-class **exclusive profile**: while your HUD is up you own the **whole** ring, and Halo
Ring forwards every raw gesture to you and leaks **nothing** to the underlying app. You no longer
declare a gesture→action map to us; **you own all semantics + prompts**, we just forward raw gesture
names. This is simpler, faster, and matches Zack's "独占" requirement literally.

What you must change: send `OVERLAY_ACTIVATE`/`OVERLAY_DEACTIVATE` (instead of, or in addition to,
`PROFILE_PUSH`/`POP`) and add a receiver for `OVERLAY_GESTURE`. Your current `PROFILE_PUSH`/`POP`
still works as a legacy alias (it toggles the overlay; its `bindings_json` is ignored), so you won't
hard-break in the meantime — but migrate, because the old `hud_*` TRIGGERs are gone.

---

## 1. Model

An overlay is like an app profile (Media/Reader) except:
- it isn't inferred from the foreground app — **you signal** when your HUD appears / closes (it may
  float over music, the launcher, anything);
- while active it's **exclusive**: every ring gesture is forwarded to you; the underlying app gets
  nothing (no DPAD passthrough, no page-flip, no screenshot, no profile routing);
- **you own meaning + on-HUD prompts.** We forward raw gesture names only; we never interpret them,
  so you can remap a gesture's meaning per HUD-state without telling us.

While your overlay is active we also **freeze** profile auto-inference, so the underlying app's
profile can't churn under your HUD; it re-asserts the instant you release.

---

## 2. The gesture vocabulary (what we can forward)

Design your HUD interactions + prompts against these names. We forward the exact string:

| Name | Physical |
|---|---|
| `TAP` | single tap |
| `DOUBLE_TAP` | double tap |
| `LONG_PRESS` | hold (~firmware floor) |
| `SWIPE_UP` / `SWIPE_DOWN` | swipe |
| `TAP_SWIPE_UP` / `TAP_SWIPE_DOWN` | tap-then-swipe (single) |
| `DOUBLE_TAP_SWIPE_UP` / `DOUBLE_TAP_SWIPE_DOWN` | double-tap-then-swipe |
| `LONG_PRESS_SWIPE_UP` / `LONG_PRESS_SWIPE_DOWN` | long-press-then-swipe |
| `TRIPLE_TAP` | triple tap |
| `DOUBLE_LONG_PRESS` | two long-presses |

(The ring has **no left/right swipe** — only up/down/tap/long-press, per SPEC v3.) While the overlay
is active **all** of these are forwarded to you and none reach the system — including `TRIPLE_TAP`
(normally screenshot) and `LONG_PRESS` (normally screen-sleep). Map a clear **dismiss** gesture
(we suggest `DOUBLE_TAP`) so the wearer can always exit.

For HUD scrolling/approve we recommend: `TAP`=approve/engage, `DOUBLE_TAP`=dismiss, `LONG_PRESS`=
modify, `SWIPE_UP`/`SWIPE_DOWN`=scroll — but it's entirely your call now.

---

## 3. Wire protocol (Doc/18 §7)

All actions gated by `com.halo.ring.permission.PUSH_PROFILE` (signature|privileged — your shared cert
`4022b9b7` already satisfies it).

**You → Halo Ring**

| Broadcast action | Extras | When |
|---|---|---|
| `com.halo.ring.action.OVERLAY_ACTIVATE` | `owner_package` (req), `profile_id` (opt, default `"overlay"`), `display_name` (opt — else your app label) | HUD shown. **Re-send every ~20–30 s as keepalive.** |
| `com.halo.ring.action.OVERLAY_DEACTIVATE` | `owner_package` (req), `profile_id` (opt) | HUD closed / idle. |

**Halo Ring → You** (explicit broadcast to your package)

| Broadcast action | Extras |
|---|---|
| `com.halo.ring.action.OVERLAY_GESTURE` | `gesture` = one of §2's names; `from_package` = `com.halo.ring.rokid` |

Register a receiver for `OVERLAY_GESTURE` (exported; you may gate it with your own permission since we
`setPackage(you)` the broadcast). Interpret `gesture` against your current HUD state.

---

## 4. Lifecycle + safety

- **Single active** overlay (one HUD owns the ring); a new `OVERLAY_ACTIVATE` from another owner
  replaces yours.
- **Keepalive timeout**: if we don't see a re-`ACTIVATE` within **60 s**, we auto-release (so a
  crashed/hung Constellation can't lock the wearer out). Re-send while your HUD is up.
- **Uninstall**: releasing on `PACKAGE_REMOVED` of your package.
- **HUD cue**: we flash your `display_name` on activate and the underlying mode name on release, so
  the wearer sees the ring change hands.
- Releasing restores the underlying profile instantly (we never changed it — the overlay is a
  router-layer takeover).

---

## 5. What you need to change

1. On HUD-open: `sendBroadcast(OVERLAY_ACTIVATE {owner_package=you})`; refresh every ~25 s; on
   close/idle: `OVERLAY_DEACTIVATE`. (You can keep firing `PROFILE_PUSH`/`POP` too — they're aliased
   — but `bindings_json` is now ignored.)
2. Add a receiver for `OVERLAY_GESTURE`; map the raw `gesture` to your HUD actions **in your code**.
   The old `hud_activate` / `hud_dismiss` / … TRIGGERs are **no longer sent** — that mapping now
   lives entirely on your side.
3. Render your own gesture prompts on the HUD using §2's vocabulary.

Your acceptance criteria (REQ §4) all hold: with your overlay active, **TAP/DOUBLE_TAP/SWIPE/
LONG_PRESS all reach you as `OVERLAY_GESTURE`** and the Sprite launcher receives **nothing**; on
release, launcher navigation works again. The difference vs your REQ: you receive raw gesture names,
not `hud_*` action ids.

---

## 6. Why not your §2.5 patch

Your patch made overlays a per-gesture exception inside the base-key passthrough. We instead made the
overlay an exclusive profile that sits **above** the entire pipeline — which (a) guarantees true
"独占所有" (even unbound/ system gestures don't leak), (b) reuses the same `useSystemKeyEvents=false`
profile mechanism the built-in app profiles use, and (c) keeps semantics 100% on your side so there's
nothing to keep in sync. The "ring = temple extension, can't remap the core-4" invariant still holds
for the wearer's own profiles — it just doesn't apply while an app's HUD owns the ring.
