#!/bin/sh

# Check if IFACE matches wireless interface pattern
case "$IFACE" in
    wlx*)
        # Continue processing for wireless interfaces
        ;;
    *)
        exit 0
        ;;
esac

if [ "$PHASE" != "post-up" ] && [ "$PHASE" != "pre-down" ]; then
    exit 0
fi

# Get udev properties for the interface
eval $(udevadm info -x --query=property --path="/sys/class/net/$IFACE" 2>/dev/null)


# Initialize TX_POWER variable
TX_POWER=""

case "$ID_USB_DRIVER" in
    "rtl88xxau_wfb")
        if [ "$PHASE" = "post-up" ]; then
            TX_POWER=-4000
        elif [ "$PHASE" = "pre-down" ]; then
            TX_POWER=-2000
        fi
        ;;
    "rtl88x2eu"|"rtl88x2cu")
        if [ "$PHASE" = "post-up" ]; then
            TX_POWER=2500
        elif [ "$PHASE" = "pre-down" ]; then
            TX_POWER=1900
        fi
        ;;
esac

# Only set txpower if TX_POWER is defined
if [ -n "$TX_POWER" ]; then
    echo "set tx power of dev $IFACE to $TX_POWER"
    iw dev "$IFACE" set txpower fixed "$TX_POWER"
fi
