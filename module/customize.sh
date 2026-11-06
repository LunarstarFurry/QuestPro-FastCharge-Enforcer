ui_print "- Installing Quest Pro Fast Charge Enforcer"
ui_print "- Target: Quest Pro (seacliff)"
ui_print "- Setting script permissions..."
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

ui_print "- Initializing default mode: FORCE_9V"
echo "MODE=FORCE_9V" > "$MODPATH/mode.conf"

ui_print "- Applying initial fast charging profile in RAM..."
if [ -e "/sys/class/power_supply/bms/charge_profile" ]; then
    chmod 644 /sys/class/power_supply/bms/charge_profile 2>/dev/null
    echo 0 > /sys/class/power_supply/bms/charge_profile 2>/dev/null
    chmod 444 /sys/class/power_supply/bms/charge_profile 2>/dev/null
fi
ui_print "- Done! Fast charging & Auto-9V ready."
