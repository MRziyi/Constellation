# Deploying Constellation to a (headless, SSH-only) Mac Mini

**Author**: Claude Opus 4.8 · **Written**: 2026-06-02
**Purpose**: migrate the Mac side of Constellation (Cortex + Tool-agent + data) from the **MacBook Air** (current host) to a **new Mac Mini** that has **no monitor** and is driven **only over SSH**. The hardest part is **granting macOS permission prompts (TCC) without a screen** — §4 is dedicated to it.

> TL;DR of the SSH-permission problem: **you cannot grant TCC (Automation / Full Disk Access) over plain SSH** — Apple blocks programmatic grants. The fix is to **(a) enable auto-login so a GUI session exists headless, and (b) enable Screen Sharing (VNC) so you can click the few "Allow" prompts remotely from the Air.** SSH does the shell work; Screen Sharing does the ~6 one-time clicks. See §4.

---

## 0. What actually runs on the Mac (the migration scope)

| Piece | What | Where |
|---|---|---|
| **Cortex** | The brain/orchestrator (Python asyncio; WSS :8888, HTTP :8890) | `~/Code/Projects/Constellation-Server/cortex` + its `.venv` |
| **Tool-agent** | 13 leaf adapters (Apple Notes/Reminders/Calendar/Mail/iMessage/Safari/fs/system_status/claude_code/…); WS server on `127.0.0.1:8889` that Cortex connects to | `~/Code/Projects/Constellation-Server/tool-agent` + its `.venv` |
| **Digital Twin** | Your data: identity, people, captures, memos, sessions, CHANGELOG (**20 MB**) | `~/constellation/twin/` |
| **Whisper models** | `ggml-base.bin` (partial) + `ggml-small.bin` (final) — local STT (**606 MB**) | `~/constellation/whisper-models/` |
| **InsightFace model** | `buffalo_l` (face recognition, **614 MB**) — auto-downloads on first use, or copy | `~/.insightface/models/` |
| **whisper-cli** | the STT binary (Homebrew `whisper-cpp`) | `/opt/homebrew/bin/whisper-cli` |
| **claude CLI** | the Agent SDK spawns this for complex tasks (subscription auth) | `~/.local/bin/claude` |
| **launchd jobs** | auto-start Cortex + Tool-agent on boot/login | `~/Library/LaunchAgents/com.constellation.{cortex,tool-agent}.plist` |
| **Secrets** | `OPENAI_API_KEY`, `GROQ_API_KEY` | `~/Code/Projects/Constellation-Server/tool-agent/.env` |

**Not on the Mac** (no change needed for the migration):
- **Glasses** (Android) — connect to the public Edge `edge.example.com`, which is stable.
- **Edge proxy** (Linux box) — BUT its **upstream points at the Mac's Tailscale IP**, which changes on the new Mac → see §3.7.

Networking model: glasses → public Edge (`edge.example.com`) → **Mac's Tailscale IP**. Cortex binds to that Tailscale IP (currently `<mac-host>`, the Air's). The new Mini gets a **new** Tailscale IP → update the plist (§3.6) + the Edge upstream (§3.7).

---

## 1. Assumptions
- New Mac Mini, **same username `Zack`** (keeps all the absolute paths in the plists valid — strongly recommended; a different username means editing every `~/...` path).
- Apple Silicon (so Homebrew lives at `/opt/homebrew`, and InsightFace uses the CoreML execution provider).
- You have the Air available to copy data from and to drive Screen Sharing.

---

## 2. Prerequisites on the new Mac Mini (over SSH)

```bash
# 2.1 Homebrew (if not present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2.2 System packages
brew install python@3.12 whisper-cpp git
#   whisper-cpp → /opt/homebrew/bin/whisper-cli (the STT binary Cortex shells out to)

# 2.3 Tailscale — gives the Mini its tailnet IP that Cortex binds to.
#   ⚠️ HEADLESS: install it as a SYSTEM DAEMON, not the GUI app. The GUI app only
#   starts after a user logs in, and it does NOT auto-reconnect reliably across a
#   reboot — so after a reboot Tailscale is DOWN, the bind IP is missing, and
#   Cortex can't serve (observed 2026-06-02). The system daemon comes up at BOOT,
#   before login, so Cortex can always bind. Use the CLI build:
brew install tailscale
sudo tailscaled install-system-daemon       # starts tailscaled at boot, no login needed
sudo tailscale up                            # log into the same tailnet (prints a URL)
# Get the Mini's tailnet IP — WRITE IT DOWN, you need it in §3.6 + §3.7:
tailscale ip -4
# (If you instead keep the GUI app: every reboot you must `open -a Tailscale` + re-run
#  scripts/start.sh, because Cortex's bind fails while Tailscale is still down.)

# 2.4 claude CLI (Agent SDK spawns it). Install per code.claude.com, ends up at ~/.local/bin/claude
#     Then log in with your SUBSCRIPTION (Pro/Max) — NOT an API key (see §3.5):
claude   # run once; use /login — it prints a URL; open it in the Air's browser, paste the code back
```

---

## 3. Migration steps

### 3.1 Copy the repos
The server lives in one repo. From the **Air** (or `git clone` if pushed):
```bash
# from the Air, rsync the server repo to the Mini (replace mini-host with its Tailscale name/IP):
rsync -avz --exclude '.venv' --exclude '__pycache__' \
  ~/Code/Projects/Constellation-Server/  zack@<mini>:~/Code/Projects/Constellation-Server/
```
> Exclude the `.venv`s — they contain absolute paths + compiled arch-specific wheels; recreate them on the Mini (§3.3). The Glass/Console repos don't run on the Mini (they build on the Air / deploy to Edge), so they're optional to copy.

### 3.2 Copy the data (Twin + models)
```bash
# from the Air:
rsync -avz ~/constellation/twin/            zack@<mini>:~/constellation/twin/
rsync -avz ~/constellation/whisper-models/  zack@<mini>:~/constellation/whisper-models/
# InsightFace model: copy it OR let it re-download on first recall (~326 MB pull).
rsync -avz ~/.insightface/                  zack@<mini>:~/.insightface/
```
> The Twin (`~/constellation/twin`) is your real data — people, captures, memos, sessions. Copy it. The face gallery lives inside it (`people/_faces/index.json` + `people/encounters/*.md`), so it migrates with the Twin.

### 3.3 Recreate the Python venvs + deps (on the Mini)
```bash
# Cortex
cd ~/Code/Projects/Constellation-Server/cortex
python3.12 -m venv .venv
./.venv/bin/pip install -e .          # pyproject pulls everything incl. insightface/onnxruntime/opencv-python/numpy

# Tool-agent
cd ~/Code/Projects/Constellation-Server/tool-agent
python3.12 -m venv .venv
./.venv/bin/pip install -e .          # (or `pip install -r requirements.txt` if that's the shape)
```
> First `pip install` of `insightface` builds a small Cython ext — needs Xcode Command Line Tools (`xcode-select --install`). `onnxruntime` ships a wheel with the CoreML EP for arm64 macOS.

### 3.4 Copy secrets (`.env`)
```bash
# from the Air — the keys (OPENAI_API_KEY, GROQ_API_KEY):
rsync -avz ~/Code/Projects/Constellation-Server/tool-agent/.env \
  zack@<mini>:~/Code/Projects/Constellation-Server/tool-agent/.env
```
> Cortex's `main._load_env()` searches `<repo>/.env`, `cortex/.env`, then `tool-agent/.env` (first wins). Both processes read the keys from there. (GROQ_API_KEY powers the fast classifier; OPENAI_API_KEY powers the planner.)

### 3.5 Claude subscription auth (NOT an API key)
The complex-agent path spawns `claude` and **must auth via the Keychain subscription** (Pro/Max), never a paid API key. So:
- Ensure **no `ANTHROPIC_API_KEY`** anywhere in the env/plist (the cortex plist deliberately omits it).
- Run `claude` → `/login` once on the Mini (over SSH it prints a URL; open it in the Air's browser, paste the code back). This stores the subscription token in the **login Keychain** — which is why **auto-login matters** (§4): the Keychain unlocks at GUI login.

### 3.6 Install + fix the launchd plists
Copy the two plists, then **edit the Tailscale IP** in the cortex plist to the **Mini's** IP from §2.3:
```bash
rsync -avz ~/Library/LaunchAgents/com.constellation.cortex.plist \
           ~/Library/LaunchAgents/com.constellation.tool-agent.plist \
  zack@<mini>:~/Library/LaunchAgents/
# On the Mini — set the new Tailscale IP in the cortex plist (replace BOTH --host and --http-host):
#   <string>--host</string><string><mac-host></string>  →  the Mini's IP
# (edit the file directly; it's plain XML)
```
**Verify the tool-agent plist paths** (this exact bug bit us on the Air): all four references must be `Constellation-Server/tool-agent`, not `Constellation/tool-agent`:
```bash
plutil -lint ~/Library/LaunchAgents/com.constellation.tool-agent.plist
grep -o 'Constellation[^<]*tool-agent' ~/Library/LaunchAgents/com.constellation.tool-agent.plist  # must all say Constellation-Server
mkdir -p ~/Code/Projects/Constellation-Server/tool-agent/logs   # StandardOut/ErrorPath need this dir
```
Load them:
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.constellation.tool-agent.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.constellation.cortex.plist
launchctl list | grep constellation   # col1 = PID (not -), col2 = 0
```
Recipes you'll reuse:
- restart cortex after a code change: `launchctl kickstart -k gui/$(id -u)/com.constellation.cortex`
- full reset if a port is stuck: `launchctl bootout gui/$(id -u)/com.constellation.<svc>; launchctl bootstrap gui/$(id -u) <plist>`
- logs: `/tmp/cortex.out.log` `/tmp/cortex.err.log` · tool-agent: `~/Code/Projects/Constellation-Server/tool-agent/logs/`

### 3.7 Point the Edge at the new Mac
The Linux Edge (`edge.example.com`) forwards upstream to the Mac's Tailscale IP. Update its upstream to the **Mini's** IP and redeploy:
- In `Constellation-Console` (the Edge config / `deploy/`), change the upstream host `<mac-host>` → the Mini's Tailscale IP, then `./deploy/deploy-edge.sh`.
- ⚠️ Redeploying Edge **logs out all clients** → re-scan the pairing QR on the glasses afterward.

### 3.8 Don't let the Mini sleep (it's a server)
```bash
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 womp 1   # never sleep; wake-on-network on
sudo pmset -a autorestart 1                                # auto-restart after power loss
```

---

## 4. ⭐ Permissions on a headless / SSH-only Mac (the TCC problem)

**The core constraint:** macOS **TCC** (Privacy & Security: Automation, Full Disk Access, …) **cannot be granted from the command line.** There is no `tccutil grant`. `tccutil` can only **reset** (re-prompt). The TCC database is SIP-protected, so you can't edit it directly either. A grant **requires a click in a GUI session.** So a pure-SSH box can't authorize the Apple tools.

**The working setup for headless:**

### 4.1 Auto-login (so a GUI session exists at boot, with no monitor)
launchd **`gui/`** agents (both our services) and the Keychain subscription token need a **logged-in user (Aqua) session**. With no monitor + no auto-login, a reboot leaves the Mini at the login window → no GUI session → services may not run + Keychain locked + no way to grant TCC. Enable auto-login:
- Easiest: once (via Screen Sharing, §4.2) in **System Settings → Users & Groups → Automatically log in as → Zack**.
- Or over SSH: `sudo sysadminctl -autologin set -userName Zack -password <password>` (sets the encoded `kcpassword`).

### 4.2 Screen Sharing (VNC) — the click surface
Enable it so you can drive the GUI from the Air for the one-time permission clicks:
```bash
# over SSH on the Mini:
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on -restart -agent -privs -all
# also flip on the Screen Sharing service:
sudo launchctl enable system/com.apple.screensharing
sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
```
Then from the **Air**: Finder → ⌘K → `vnc://<mini-tailscale-ip>` (or the Screen Sharing app). Now you have a remote desktop to click prompts.

> **Optional but recommended: a ~$8 HDMI "dummy plug" (headless display emulator).** With zero displays attached, WindowServer can run at a tiny virtual resolution and Screen Sharing/GPU can be flaky. A dummy plug makes the Mini behave like it has a real monitor → smooth Screen Sharing.

### 4.3 Which permissions to grant, and how
Grant these **once** (via Screen Sharing). The cleanest way to surface each prompt is to **trigger the tool** while watching the screen, then click **Allow**.

| Permission | Why | Attaches to (important for §4.5) | How |
|---|---|---|---|
| **Automation** (Apple Events) | Reminders / Calendar / Mail / Notes / Shortcuts / Messages-send / Safari are driven by the adapters shelling out to **`/usr/bin/osascript`** | **`osascript`** — a stable, Apple-signed system binary (NOT the venv python) | a prompt **"osascript wants to control «Reminders»"** pops the first time each app is touched → **Allow**. One per target app. |
| **Full Disk Access** | the `imessage` adapter reads `~/Library/Messages/chat.db` **in-process via python's sqlite3** (no prompt — FDA silently fails until granted) | the **base python interpreter** (the venv `python` is a symlink → `…/python3.x`; TCC keys the resolved real binary) | System Settings → Privacy & Security → **Full Disk Access** → **+** → add the resolved interpreter (find it: `readlink -f …/tool-agent/.venv/bin/python`; ⌘⇧G to paste the path). Toggle on. No prompt — you add it manually. |
| **Contacts** | only if you resolve people by name from Contacts | osascript | prompt on first use → Allow |

**Not needed on the Mac:** Camera, Microphone (those live on the glasses, not the Mini).

#### One-shot procedure — flush every prompt in a single Screen-Sharing sitting
Do this once, right after the services are up, with a Screen Sharing window open so you can click each **Allow**. Trigger each Apple tool **through the running (launchd) services** — NOT from a plain SSH shell — because the launchd "responsible process" context differs from a terminal, so a grant obtained in Terminal won't apply to the launchd-run tool (this is exactly what left Mail/Calendar unauthorized on the Air).

```bash
MINI=<mini-ip>
# 0) sanity — needs NO TCC, confirms the tool path is alive:
curl -sS http://$MINI:8890/api/system/status

# 1) Fire one task per Apple app so each "osascript wants to control X" prompt appears.
#    Use /api/test/invoke with text the router sends to that tool; click Allow on each popup.
curl -sS -XPOST http://$MINI:8890/api/test/invoke -d '{"text":"what is on my calendar today"}'      # → Calendar
curl -sS -XPOST http://$MINI:8890/api/test/invoke -d '{"text":"add a reminder to test TCC at 5pm"}'   # → Reminders
curl -sS -XPOST http://$MINI:8890/api/test/invoke -d '{"text":"list my notes"}'                       # → Notes
curl -sS -XPOST http://$MINI:8890/api/test/invoke -d '{"text":"check my inbox"}'                       # → Mail
curl -sS -XPOST http://$MINI:8890/api/test/invoke -d '{"text":"what tab am I on in Safari"}'           # → Safari
curl -sS -XPOST http://$MINI:8890/api/test/invoke -d '{"text":"list my recent messages"}'             # → Messages (send path = Automation)

# 2) Full Disk Access (iMessage chat.db) — NO popup; add it by hand in System Settings (Screen Sharing):
readlink -f ~/Code/Projects/Constellation-Server/tool-agent/.venv/bin/python   # ← add THIS path to Full Disk Access
```
> Each `/api/test/invoke` runs the real classifier→router→tool path; the router may need a moment. Watch the Screen-Sharing desktop and click **Allow** as the "osascript wants to control …" prompts appear. After the round, every Apple tool is authorized for good (see §4.5).

If a grant ends up wrong/denied, reset and re-trigger:
```bash
tccutil reset AppleEvents              # clears ALL Automation grants → re-prompts on next run
tccutil reset SystemPolicyAllFiles     # clears Full Disk Access entries
```

### 4.5 Is it one-time? When do you have to re-authorize?
**For normal operation — no. It's effectively one-time per machine.** The grants live in the on-disk TCC database and are keyed to a **binary's identity**, and the binaries our grants attach to are stable:

| Thing you do | Re-authorize? | Why |
|---|---|---|
| Restart a service — `kickstart`, `bootout`+`bootstrap`, KeepAlive crash-restart | **No** | same binary; TCC.db unchanged |
| Edit the plist / change the bind IP / `git pull` + redeploy code | **No** | the code that runs is still the same `osascript` / python binary |
| Reboot the Mac | **No** | TCC.db persists (just needs the auto-login GUI session back, §4.1) |
| **Recreate the venv** (`rm -rf .venv && python -m venv …`) with the same base python | **No** | the venv `python` is a *symlink* to the base interpreter; TCC keys the resolved real binary, which didn't change. And Automation attaches to **osascript**, untouched by venv work. |
| Upgrade / reinstall the **base python** (`brew upgrade python`, reinstall miniconda) | **FDA: likely yes** (re-add python once). **Automation: no** (osascript unchanged) | the python binary's content-hash changed → its FDA grant no longer matches |
| macOS **major** upgrade | **Sometimes** | Apple occasionally resets parts of TCC across major versions |
| Move to a **new Mac** (this migration) | **Yes, once** | TCC.db is machine-local + does not transfer; re-run §4.3 once |

**Bottom line for you:** redeploying, killing-and-rerunning, rebooting — **none of those re-prompt.** The Automation grants ride on `/usr/bin/osascript` (a system binary that never changes outside a macOS upgrade), so they're rock-solid. The only routine action that can force a re-grant is **upgrading the Python interpreter itself** (and only the Full-Disk-Access entry, which you just re-add). If you want even that to never happen, **pin the base python** (don't auto-upgrade brew/conda python on the server).

---

## 5. Verification checklist (all over SSH)

```bash
# services up
launchctl list | grep constellation                       # both have a PID, status 0
# cortex healthy + bound to the Mini's tailnet IP
curl -sS http://<mini-ip>:8890/api/health | python3 -m json.tool   # status ok
# tool-agent reachable (forces the lazy connect): returns real data → tool_conn works
curl -sS http://<mini-ip>:8890/api/system/status
# face model present / loads
grep -a "face" /tmp/cortex.out.log | tail
# whisper present
/opt/homebrew/bin/whisper-cli --help >/dev/null && echo "whisper ok"
# claude subscription auth (NOT api): no ANTHROPIC_API_KEY in env
launchctl print gui/$(id -u)/com.constellation.cortex | grep -i anthropic   # → nothing
```
Then end-to-end: re-scan the pairing QR on the glasses (Edge was redeployed), fire a simple task (reminder) and a complex one, and do an enroll/recall.

---

## 6. Gotchas (carried over from the Air)
- **`tool_conn:False` right after a cortex restart is normal** — Cortex connects to the tool-agent **lazily**, on the first tool dispatch. Fire one simple task and it goes True.
- **The tool-agent is a *server* on `127.0.0.1:8889`; Cortex connects to it.** If a stale instance holds the port, the launchd one crash-loops with `Errno 48`. One instance only.
- **Plist Tailscale IP** must match the Mini's actual tailnet IP, or Cortex binds nothing reachable (KeepAlive + ThrottleInterval=10 will just retry).
- **Keychain must be unlocked** for the `claude` subscription token → needs the auto-login GUI session (§4.1). A locked Keychain = the SDK agent can't auth.
- **Subscription billing**: never set `ANTHROPIC_API_KEY` (that switches `claude -p` to paid API). The plist omits it on purpose.
- **Sleep**: a sleeping Mini drops the WSS + launchd timers. §3.8 disables sleep.
- **Glasses need no change** — only the Edge upstream IP (§3.7) + a re-scan after the Edge redeploy.

*If the username on the Mini differs from `Zack`, every `~/...` path above (plists, venv, twin, models) must be updated — keeping the username identical is by far the easiest migration.*
