#!/usr/bin/env bash
# P1.8 / Phase α — capture memory / CPU / battery / power state from
# Constellation-Glass running on Rokid Glasses (default) or any adb device.
#
# Usage:
#   ./scripts/glass-profile.sh <label>          # one-shot capture
#   ADB_DEV=854afb6b ./scripts/glass-profile.sh cold-start-oneplus
#
# Output:
#   profile-out/<label>-<TS>/{meminfo,top,battery,power,wakelock,process}.txt
#
# Companion design: docs/glass/P1.8-MEMORY-ENERGY-PROFILE.md
set -euo pipefail

DEV=${ADB_DEV:-<glass-serial>}
PKG=${PKG:-com.constellation.glass}
LABEL=${1:-snapshot}
TS=$(date +%Y%m%d-%H%M%S)
OUT_ROOT=${PROFILE_OUT_DIR:-profile-out}
OUT="$OUT_ROOT/$LABEL-$TS"

mkdir -p "$OUT"

# Sanity: is the device reachable + the app installed?
if ! adb -s "$DEV" shell true 2>/dev/null; then
    echo "ERROR: adb device '$DEV' not reachable. Plug in or set ADB_DEV=" >&2
    exit 1
fi
PID=$(adb -s "$DEV" shell pidof "$PKG" 2>/dev/null | tr -d '\r' || true)
if [ -z "$PID" ]; then
    echo "WARN: package '$PKG' has no running process — capturing what we can" >&2
fi

echo "[$LABEL] device=$DEV pkg=$PKG pid=${PID:-n/a} → $OUT/"

# === Memory ===
echo "  ▸ dumpsys meminfo"
adb -s "$DEV" shell "dumpsys meminfo $PKG" > "$OUT/meminfo.txt" 2>&1 || echo "FAIL (no process?)" > "$OUT/meminfo.txt"

# === CPU / process snapshot (5 samples) ===
if [ -n "$PID" ]; then
    echo "  ▸ top samples × 5"
    adb -s "$DEV" shell "top -n 5 -d 1 -b -p $PID" > "$OUT/top.txt" 2>&1 || true
else
    echo "no PID — skipped" > "$OUT/top.txt"
fi

# === Battery ===
echo "  ▸ dumpsys battery"
adb -s "$DEV" shell "dumpsys battery" > "$OUT/battery.txt" 2>&1 || true

# === Power + wakelocks ===
echo "  ▸ dumpsys power (top 200 lines)"
adb -s "$DEV" shell "dumpsys power" 2>&1 | head -200 > "$OUT/power.txt" || true

echo "  ▸ wakelocks containing 'Constellation'"
adb -s "$DEV" shell "dumpsys power" 2>&1 \
    | grep -A2 -E "Constellation|com.constellation" > "$OUT/wakelock.txt" || \
    echo "(no Constellation wakelocks)" > "$OUT/wakelock.txt"

# === App process info ===
echo "  ▸ activity processes (Constellation rows)"
adb -s "$DEV" shell "dumpsys activity processes" 2>&1 \
    | grep -A 30 "$PKG" > "$OUT/process.txt" || \
    echo "(not running)" > "$OUT/process.txt"

# === Quick summary ===
{
    echo "# P1.8 profile snapshot — $LABEL @ $TS"
    echo
    echo "Device: $DEV (pkg=$PKG, pid=${PID:-n/a})"
    echo
    echo "## meminfo extract"
    grep -E "TOTAL PSS|Java Heap|Native Heap|Code|Stack|Graphics|Private Other" "$OUT/meminfo.txt" || true
    echo
    echo "## battery"
    grep -E "level|status|temperature|voltage|current" "$OUT/battery.txt" || true
    echo
    echo "## top CPU (last sample)"
    tail -20 "$OUT/top.txt"
} > "$OUT/summary.md"

echo "Saved → $OUT/"
echo "Quick view:"
echo "  cat $OUT/summary.md"
