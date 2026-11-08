#!/system/bin/sh
chmod 644 /sys/class/power_supply/bms/charge_profile 2>/dev/null
echo 0 > /sys/class/power_supply/battery/parallel_disable 2>/dev/null
echo 4800000 > /sys/class/power_supply/main/force_main_fcc 2>/dev/null
echo 0 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
resetprop -n persist.vendor.pps.disallowed 0 2>/dev/null
