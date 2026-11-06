#!/system/bin/sh
BMS_NODE="/sys/class/power_supply/bms/charge_profile"
if [ -e "$BMS_NODE" ]; then
    chmod 644 "$BMS_NODE" 2>/dev/null
fi
resetprop -n persist.vendor.pps.disallowed 0 2>/dev/null
