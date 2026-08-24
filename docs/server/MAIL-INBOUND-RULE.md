# Inbound-email → HUD push + voice reply (feature setup)

**Added 2026-06-05.** A VIP emails Zack → his Mac pushes a HUD card showing the
email → Zack LONG-presses and dictates a reply ("reply to her saying…", or "look
in my memo for the poster title and tell him") → the normal STT-review →
classifier → dispatch pipeline runs with the **email body + Message-ID injected as
context**, so the agent knows exactly what it's replying to and **threads** the
reply (`reply_to_message_id`). Zack reviews the draft on the HUD and approves —
then it sends. Nothing auto-sends.

```
new VIP email
   │  Mail.app "Run AppleScript" rule
   ▼
scripts/mail_inbound_notify.py  ── POST /api/mail/inbound (msg_id, sender, subject, body, account)
   ▼
cortex  ── VIP allowlist + glasses-connected gate ──▶ push "✉ <sender>" HUD card (notification, continuable)
   │
   │  Zack LONG-presses the card → mic opens (emailreply_<cmd_id>)
   ▼
"reply saying … / look in my memo and tell him …"  → STT review → approve
   ▼
classifier (simple reply  | complex: read Twin first) → router/agent proposes
  email{ reply_to_message_id, body }  → preview card → Zack approves → SENT (threaded)
```

Design decisions (Zack 2026-06-05): **detection = Mail rule** (event-driven, runs
in the GUI login session so it has Mail's Automation/TCC — sidesteps the
launchd-TCC limitation); **scope = VIP allowlist only** (fail-closed); **push only
when the glasses are connected** (v1 — there is no server→glasses wake channel yet;
a VIP email that arrives while disconnected is simply not shown).

---

## 1. VIP allowlist

Edit `~/constellation/twin/_system/mail_vips.txt` — one email address per line
(`#` comments, blank lines ignored). **While it's empty, nothing pops** (so you're
never spammed). Read fresh on every email — no cortex restart after an edit.

```
advisor@example.edu
family@example.com
```

cortex matches on the bare address (case-insensitive), extracting it from
`Name <addr>` if needed.

## 2. The Mail.app rule

1. **Install the rule script.** A versioned source lives at
   `Constellation-Server/scripts/ConstellationInbound.applescript`. Compile it
   into Mail's scripts folder (one line — avoids retyping the `«class utf8»`
   guillemets):
   ```bash
   osacompile -o ~/Library/Application\ Scripts/com.apple.mail/ConstellationInbound.scpt \
              ~/Code/Projects/Constellation-Server/scripts/ConstellationInbound.applescript
   ```
   (Source listed below for reference.) The first time the rule fires, macOS will
   prompt to allow it to control Mail — click **Allow**.
2. **Mail ▸ Settings ▸ Rules ▸ Add Rule**:
   - Description: `Constellation HUD push`
   - Condition: **Every Message** (cortex is the real filter via the VIP list —
     one place to maintain). *Or* set `From → is equal to` your VIPs if you'd
     rather the script only runs for them.
   - Action: **Run AppleScript** → select `ConstellationInbound.scpt`.
   - Keep it ABOVE any rule that moves/deletes mail (rules stop at the first
     match that says so).
   - When Mail asks **"apply rule to existing messages?"** → choose **Don't
     Apply** (the guards below also protect you, but don't tempt fate).

The full rule source is
`Constellation-Server/scripts/ConstellationInbound.applescript` (compiled above).

> ### ⚠️ Why this script is the way it is (it froze Mail twice during dev)
> A Mail rule fires per delivery, and "apply to existing" / a bulk account sync
> hands the **whole inbox** to ONE firing. The naive version read `content of m`
> + spawned a shell **per message** → hundreds of synchronous round-trips into
> the app that was mid-rule-run → **Mail froze**. (An even earlier version piped
> the body on stdin via a heredoc, which could block forever — also a freeze.)
> The shipped script is hardened:
> - **Batch bail** — `if (count of theMessages) > 12 then return`: a bulk op is
>   detected and skipped with ZERO work.
> - **Recency gate** — only mail received in the last 15 min is acted on (a cheap
>   `date received` check; old mail is skipped without reading the body).
> - **Per-run cap** — at most 5 notifications per firing.
> - **Body via temp file, notifier launched detached** (`… </dev/null >/dev/null
>   2>&1 &`) — Mail never waits on the disk read or the network.
>
> **Verified (2026-06-06):** compiles; the batch-bail + recency logic is correct;
> a single message posts to cortex in ~0.1s and cleans up its temp file. **Not
> verified end-to-end inside Mail's live rule engine** (no way to drive a real
> delivery from a test) — so add the rule with *Don't Apply to existing* and watch
> the first couple of real emails. If Mail ever hangs again: `killall Mail`, then
> disable the rule, and consider the poller alternative in §6.

The notifier (`mail_inbound_notify.py`) reads the body file, POSTs to
`http://<mac-host>:8890/api/mail/inbound` (override via env
`CONSTELLATION_CORTEX_HTTP`), deletes the temp file, and fails silent + exits 0 on
any error. Because it's launched detached, Mail returns in ~0.1s regardless of
whether cortex is up.

**Verified 2026-06-06**: this handler compiles (`osacompile`), runs in ~0.1s
(does not wait on the network), POSTs to cortex, and cleans up its temp file. The
earlier heredoc-on-stdin version could hang Mail and was replaced.

## 3. Using it

- Card up (✉ Sender + subject + body, scrolls): **LONG-press** to reply by voice →
  speak the instruction → it goes through the usual STT-review → classifier →
  preview, threaded to that message. **TAP / double-tap** dismisses (you read it).
- Two scenarios both work: a plain reply ("reply saying I'll be there") routes
  *simple*; "look in my memo for the poster I saw and tell him the title" routes
  *complex* (the agent reads the Twin first), then replies — same approve-to-send.

## 4. ⚠️ Sending the reply needs Mail Automation TCC (verify)

Detection runs in your GUI session (fine). But the **reply is sent by the
tool-agent**, which runs under **launchd** — and Mail/Calendar Apple-events under
launchd have historically been blocked by TCC (Reminders/Messages/Notes work).
If an approved reply errors with `-1743 / "Not authorized to send Apple events to
Mail"`, grant Automation to the tool-agent process:

- System Settings ▸ Privacy & Security ▸ **Automation** → enable the
  cortex/tool-agent entry's access to **Mail**, *or* trigger the one-time TCC
  prompt by running a Mail `osascript` from the launchd process while you're
  present to click **Allow**.

Until granted, the draft still previews on the HUD — only the final send fails.

> **Fixed 2026-06-06** while testing: the mail adapter's `_esc()` crashed with
> `'int' object has no attribute 'replace'` when a plan emitted a non-string field,
> which had been failing reply sends *before* TCC was ever reached. `_esc` now
> coerces to `str`. The actual send (real Message-ID + Mail TCC) is still the one
> step not yet exercised end-to-end — test it with a real email (below).

## 5. Testing without a phone/voice (dev)

```bash
HOST=<mac-host>
# 1) Just the push (force bypasses VIP + connected gates):
curl -sS -X POST http://$HOST:8890/api/mail/inbound -d \
  '{"message_id":"<t1@mail>","sender_email":"alice@example.com","subject":"Re: poster","body":"what poster did you see?","force":true}'

# 2) The FULL reply path (push → simulated approved voice reply → classify → plan):
curl -sS -X POST http://$HOST:8890/api/dev/email_reply -d \
  '{"message_id":"<t1@mail>","sender_name":"Alice","sender_email":"alice@example.com",
    "subject":"Re: poster","body":"what poster did you see last week?",
    "transcript":"reply to her saying I will send the title shortly"}'
# watch: cortex log `email_reply.dispatched` → classifier → `router.plan reply-email`
# → the plan carries  args.reply_to_message_id="<t1@mail>"  (threads to that message)

# 3) The Mail-rule bridge itself (body on stdin, like the rule):
printf 'hi\nwhat poster?\n' | /usr/bin/python3 \
  ~/Code/Projects/Constellation-Server/scripts/mail_inbound_notify.py \
  "<t1@mail>" "Alice <alice@example.com>" "Re: poster" "iCloud"
```

## 6. Alternative if the Mail rule stays fragile — a GUI-session poller

The Mail rule is event-driven but runs inside Mail's rule engine, which is easy to
overwhelm (see the warning in §2). If it keeps misbehaving, the more robust
detector is a small **poller** that never touches the rule engine:

- A launchd **Agent** in your GUI login session (Aqua — so it has Mail's
  Automation/TCC) runs every ~30–60 s.
- Each tick: ONE bounded osascript — `list_inbox(unread_only, limit=10)` — diff
  against a seen-set of Message-IDs, and for each *new* message POST it to
  `/api/mail/inbound` (cortex still applies the VIP gate).
- One bounded query per tick (not one per message), self-rate-limited, fully
  testable as a normal script — a storm is structurally impossible.

Trade-off vs the rule: up to one poll-interval of latency, and it only sees mail
while you're logged in. The `applescript_mail.list_inbox` adapter already exists;
this would be a ~40-line `scripts/mail_inbound_poller.py` + a LaunchAgent plist.
Not built yet — ask if you want to switch to it.

---

Code: cortex `mail_inbound.py` (VIP/body/context helpers) · `server.py`
(`handle_inbound_email`, `_pending_email_replies`, `email_reply` intent in
`_handle_audio_end`/`_route_stt_approved`/`_handle_user_decision`) · `http.py`
(`/api/mail/inbound`, `/api/dev/email_reply`) · `router.py` (reply prefers
`reply_to_message_id` when a Message-ID is in context) · Mail rule
`scripts/ConstellationInbound.applescript` + `scripts/mail_inbound_notify.py`.
Glass: unchanged (reuses the notification + continuable card + LONG→modify mic).
