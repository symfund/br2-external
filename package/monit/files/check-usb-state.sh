#!/bin/sh
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

# 1. Bypass check during manual restarts
if [ -f /var/run/monit_bypass.lock ]; then
    exit 0
fi

# 2. Check core process state
if [ ! -f /var/run/adbd.pid ]; then
    exit 1
fi

ADBD_PID=$(cat /var/run/adbd.pid)
if [ -z "$ADBD_PID" ] || ! kill -0 "$ADBD_PID" 2>/dev/null; then
    exit 1
fi

# 3. CRITICAL HARDWARE PROBE: Check physical controller state.
# Even when silent to udev, dwc2 tracks hardware status inside debugfs/class.
UDC_NAME=$(ls /sys/class/udc 2>/dev/null | head -n 1)

if [ -n "$UDC_NAME" ]; then
    # Look for the hardware connection state variable
    if [ -f "/sys/class/udc/$UDC_NAME/state" ]; then
        HW_STATE=$(cat "/sys/class/udc/$UDC_NAME/state" 2>/dev/null)
        # If the driver registers "not attached", "powered", or loses "configured",
        # the physical cable has been pulled out.
        if [ "$HW_STATE" != "configured" ]; then
            exit 1
        fi
    fi

    # Alternative deep check: Probe the raw dwc2 hardware state registers if debugfs is mounted
    if [ -f "/sys/kernel/debug/usb/$UDC_NAME/state" ]; then
        DEBUG_STATE=$(cat "/sys/kernel/debug/usb/$UDC_NAME/state" 2>/dev/null)
        if echo "$DEBUG_STATE" | grep -q "Disconnected" || echo "$DEBUG_STATE" | grep -q "Suspended"; then
            exit 1
        fi
    fi
fi

# 4. Check network socket fallback loops
if ! netstat -an | grep -q "5037.*LISTEN"; then
    exit 1
fi

# Everything is working perfectly and the cable is connected
exit 0
