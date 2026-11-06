#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/service.log"
CONF="$MODDIR/mode.conf"
BMS_NODE="/sys/class/power_supply/bms/charge_profile"
PD_DIR="/sys/class/usbpd/usbpd0"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Wait for boot completion
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Wait for hardware daemons to stabilize
sleep 5

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Quest Pro Fast Charge Enforcer Daemon started" > "$LOG"

# Helper to find which PDO is 9000 mV (9V)
get_9v_pdo() {
    target=""
    if [ -f "$PD_DIR/pdo_h" ]; then
        while IFS= read -r line; do
            case "$line" in
                "PDO "*) curr="${line#PDO }" ;;
                *"Voltage:9000"*) target="$curr"; break ;;
            esac
        done < "$PD_DIR/pdo_h"
    fi
    echo "$target"
}

# Helper to get currently requested PDO index from RDO
get_active_pdo() {
    active=""
    if [ -f "$PD_DIR/rdo_h" ]; then
        while IFS= read -r line; do
            case "$line" in
                *"Obj Pos:"*)
                    pos="${line#*Obj Pos:}"
                    active="${pos%% *}"
                    break
                    ;;
            esac
        done < "$PD_DIR/rdo_h"
    fi
    echo "$active"
}

# Daemon loop
while true; do
    # Check if disabled or removed in Magisk
    if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
        log_msg "Module disabled or removed; exiting."
        chmod 644 "$BMS_NODE" 2>/dev/null
        exit 0
    fi

    # 1. Enforce BMS charge_profile 0 (prevent headset-worn throttling)
    if [ -e "$BMS_NODE" ]; then
        val=$(cat "$BMS_NODE" 2>/dev/null)
        if [ "$val" != "0" ]; then
            chmod 644 "$BMS_NODE" 2>/dev/null
            echo 0 > "$BMS_NODE" 2>/dev/null
            chmod 444 "$BMS_NODE" 2>/dev/null
            log_msg "BMS charge_profile reset to 0 (was $val)"
        fi
    fi

    # 2. Read mode (default is FORCE_9V)
    MODE="FORCE_9V"
    if [ -f "$CONF" ]; then
        . "$CONF"
    fi

    if [ "$MODE" = "FORCE_9V" ]; then
        # Ensure PPS is disabled in memory
        if [ "$(getprop persist.vendor.pps.disallowed)" != "1" ]; then
            resetprop -n persist.vendor.pps.disallowed 1
        fi

        # Check if USB-PD contract is active
        contract=$(cat "$PD_DIR/contract" 2>/dev/null)
        if [ "$contract" = "explicit" ]; then
            target=$(get_9v_pdo)
            active=$(get_active_pdo)
            src_id=$(cat "$PD_DIR/src_cap_id" 2>/dev/null)

            if [ -n "$target" ] && [ -n "$src_id" ] && [ "$active" != "$target" ]; then
                echo "$src_id $target" > "$PD_DIR/select_pdo" 2>/dev/null
                log_msg "Auto-forced 9V PDO ($target) with src_id $src_id (was PDO $active)"
            fi
        fi
    else
        # PPS mode: allow dynamic PPS in memory
        if [ "$(getprop persist.vendor.pps.disallowed)" != "0" ]; then
            resetprop -n persist.vendor.pps.disallowed 0
        fi
    fi

    sleep 2
done
