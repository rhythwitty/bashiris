#!/bin/bash
echo "=== MAC POWER CONFIGURATION SUMMARY ==="
echo ""
echo "1. DAILY SCHEDULE:"
pmset -g sched
echo ""
echo "2. HIBERNATION & AUTO-RECOVERY:"
pmset -g | grep -E "(hibernatemode|standbydelay|autorestart|highstandbythreshold)" | sort
echo ""
echo "3. SLEEP & WAKE SETTINGS:"
pmset -g | grep -E "(sleep|displaysleep|disksleep|ttyskeepawake)" | sort
echo ""
echo "4. NETWORK & REMOTE ACCESS:"
pmset -g | grep -E "(womp|powernap|tcpkeepalive|networkoversleep)" | sort
echo ""
echo "5. REMOTE LOGIN (SSH) STATUS:"
sshStatus=$(sudo systemsetup -getremotelogin 2>/dev/null)
if echo "$sshStatus" | grep -qi "on"; then
    echo "Remote Login: ENABLED  ($sshStatus)"
else
    echo "Remote Login: DISABLED ($sshStatus)"
fi
echo ""
echo "6. CURRENT POWER STATE:"
pmset -g ps 2>/dev/null || echo "AC Power"
