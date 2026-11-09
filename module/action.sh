#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/mode.conf"
PROP="$MODDIR/module.prop"
PD_DIR="/sys/class/usbpd/usbpd0"
BMS_NODE="/sys/class/power_supply/bms/charge_profile"
FCC_NODE="/sys/class/power_supply/main/force_main_fcc"
PARALLEL_NODE="/sys/class/power_supply/battery/parallel_disable"
LED_RED="/sys/class/leds/red/brightness"
LED_GREEN="/sys/class/leds/green/brightness"
LED_BLUE="/sys/class/leds/blue/brightness"

MODE="FORCE_9V"
if [ -f "$CONF" ]; then
    . "$CONF"
fi

echo "========================================="
echo "   Quest Pro Fast Charge Manager"
echo "========================================="

if [ "$MODE" = "FORCE_9V" ]; then
    echo "MODE: [ PPS DYNAMIC ]"
    echo "PPS enabled. Charger will dynamically"
    echo "scale voltage (5V-11V) with battery."
    echo "MODE=PPS" > "$CONF"
    resetprop -n persist.vendor.pps.disallowed 0
    sed -i 's/^description=.*/description=[Mode: PPS DYNAMIC] Dynamic voltage scaling enabled. Float bypass active at 80%, Dim Green LED at 75%+./' "$PROP" 2>/dev/null
else
    echo "MODE: [ FORCE 9V (LOCKED) ]"
    echo "Enforcing 9V fixed rail for lowest"
    echo "cable amperage and minimal cable heat."
    echo "MODE=FORCE_9V" > "$CONF"
    resetprop -n persist.vendor.pps.disallowed 1
    sed -i 's/^description=.*/description=[Mode: FORCE 9V] Auto-locks 9V rail to minimize cable heat. Float bypass active at 80%, Dim Green LED at 75%+./' "$PROP" 2>/dev/null

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
            echo "-> Latch triggered: Selected 9V (PDO $target)!"
        fi
    fi
fi

# Re-assert BMS profile 0
chmod 644 "$BMS_NODE" 2>/dev/null
echo 0 > "$BMS_NODE" 2>/dev/null
chmod 444 "$BMS_NODE" 2>/dev/null

echo "-----------------------------------------"
echo " Live Telemetry:"
v=$(cat /sys/class/power_supply/usb/voltage_now 2>/dev/null)
i=$(cat /sys/class/power_supply/usb/input_current_now 2>/dev/null)
bv=$(cat /sys/class/power_supply/battery/voltage_now 2>/dev/null)
bi=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)
t=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
fcc=$(cat "$FCC_NODE" 2>/dev/null)
p_dis=$(cat "$PARALLEL_NODE" 2>/dev/null)
hmt=$(getprop sys.hmt.mounted)
dc_pres=$(cat /sys/class/power_supply/dc/present 2>/dev/null)
usb_on=$(cat /sys/class/power_supply/usb/online 2>/dev/null)

is_charging=0
[ "$usb_on" = "1" ] && is_charging=1
[ "$dc_pres" = "1" ] && is_charging=1

# Battery power in mW
bat_mw=0
if [ -n "$bv" ] && [ -n "$bi" ]; then
    bat_mw=$(( (bv / 1000) * (bi / 1000) / 1000 ))
fi

echo " Battery Level: ${cap}%"
if [ "$dc_pres" = "1" ]; then
    echo " Power Source : CHARGING DOCK (Pogo Pins)"
    echo " Battery Rate : $((bat_mw/1000)).$(((bat_mw%1000)/100)) W (+$((bi/1000)) mA)"
elif [ "$usb_on" = "1" ]; then
    echo " Power Source : USB-C CABLE"
    echo " USB Voltage  : $((v/1000000)).$(((v/10000)%100)) V"
    echo " Cable Current: $((i/1000000)).$(((i/10000)%100)) A"
    echo " Battery Rate : $((bat_mw/1000)).$(((bat_mw%1000)/100)) W (+$((bi/1000)) mA)"
else
    echo " Power Source : ON BATTERY (Discharging)"
    dis_mw=$(( -bat_mw ))
    echo " Battery Drain: $((dis_mw/1000)).$(((dis_mw%1000)/100)) W ($((bi/1000)) mA)"
fi
echo " Battery Temp : $((t/10)).$((t%10)) °C"
echo " Headset Worn : $( [ "$hmt" = "1" ] && echo "YES" || echo "NO" )"
if [ "$p_dis" = "1" ] && [ "$fcc" -le 100000 ]; then
    echo " Bypass State : 80% FLOAT BYPASS (Locked: $((fcc/1000))mA)"
else
    echo " Bypass State : FULL FAST CHARGE"
fi
if [ "$is_charging" = "1" ] && [ "$cap" -ge 75 ]; then
    echo " Power LED    : DIM GREEN (Target Reached >= 75%)"
elif [ "$is_charging" = "1" ]; then
    echo " Power LED    : ORANGE (Charging < 75%)"
else
    echo " Power LED    : UNPLUGGED"
fi
echo "========================================="
