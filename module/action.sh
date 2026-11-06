#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/mode.conf"
PROP="$MODDIR/module.prop"
PD_DIR="/sys/class/usbpd/usbpd0"
BMS_NODE="/sys/class/power_supply/bms/charge_profile"

MODE="FORCE_9V"
if [ -f "$CONF" ]; then
    . "$CONF"
fi

echo "--- Quest Pro Fast Charge Manager ---"

if [ "$MODE" = "FORCE_9V" ]; then
    echo "Mode switched to: PPS DYNAMIC"
    echo "Charger will scale voltage (5V-11V) with battery."
    echo "MODE=PPS" > "$CONF"
    resetprop -n persist.vendor.pps.disallowed 0
    sed -i 's/^description=.*/description=[Mode: PPS DYNAMIC] Dynamic voltage scaling enabled. Tap Action button for 9V lock./' "$PROP" 2>/dev/null
else
    echo "Mode switched to: FORCE 9V (LOCKED)"
    echo "Enforcing 9V fixed rail to lower cable heat."
    echo "MODE=FORCE_9V" > "$CONF"
    resetprop -n persist.vendor.pps.disallowed 1
    sed -i 's/^description=.*/description=[Mode: FORCE 9V] Keeps 9V charging active while worn to minimize cable heat. Tap Action button for PPS./' "$PROP" 2>/dev/null

    if [ "$(cat "$PD_DIR/contract" 2>/dev/null)" = "explicit" ]; then
        src_id=$(cat "$PD_DIR/src_cap_id" 2>/dev/null)
        target=""
        while IFS= read -r line; do
            case "$line" in
                "PDO "*) curr="${line#PDO }" ;;
                *"Voltage:9000"*) target="$curr"; break ;;
            esac
        done < "$PD_DIR/pdo_h"

        if [ -n "$target" ] && [ -n "$src_id" ]; then
            echo "$src_id $target" > "$PD_DIR/select_pdo" 2>/dev/null
            echo "Selected 9V rail (PDO $target)"
        fi
    fi
fi

chmod 644 "$BMS_NODE" 2>/dev/null
echo 0 > "$BMS_NODE" 2>/dev/null
chmod 444 "$BMS_NODE" 2>/dev/null

echo ""
v=$(cat /sys/class/power_supply/usb/voltage_now 2>/dev/null)
i=$(cat /sys/class/power_supply/usb/input_current_now 2>/dev/null)
t=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
hmt=$(getprop sys.hmt.mounted)
echo "Status:"
echo "  USB Voltage  : $((v/1000000)).$(((v/10000)%100)) V"
echo "  Cable Current: $((i/1000000)).$(((i/10000)%100)) A"
echo "  Battery Temp : $((t/10)).$((t%10)) C"
echo "  Headset Worn : $( [ "$hmt" = "1" ] && echo "Yes" || echo "No" )"
echo "  Charge State : $(cat "$BMS_NODE" 2>/dev/null) (0=unthrottled)"
