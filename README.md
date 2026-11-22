# Quest Pro Fast Charge Enforcer

A Magisk module for the Meta Quest Pro (`seacliff`) that stops the headset from throttling charging speeds while worn on your head, and forces chargers onto the 9V profile to keep cable and port temperatures down.

## Why this exists

Whenever you put the Quest Pro on, Meta's firmware detects the proximity sensor (`sys.hmt.mounted = 1`) and writes `1` to `/sys/class/power_supply/bms/charge_profile`:

```rc
on property:sys.hmt.mounted=1
    write /sys/class/power_supply/bms/charge_profile 1
```

Setting `charge_profile` to `1` instructs the Qualcomm PM8150B PMIC to drop charging voltage down to 5V. Meta did this purely to keep the cooling fans quiet while the headset is on your face.

However, if you are playing PCVR or standalone over a long Link cable or a power bank:
- Drawing 15W+ at 5V forces **3.0A to 3.6A** across the wire.
- High cable resistance causes severe voltage sag (dropping below 4.5V) and dumps **3W+ of pure heat** directly into your cable and USB-C port connector.

## How it works

1. **Locks the charge profile in memory:**  
   The module sets `/sys/class/power_supply/bms/charge_profile` to `0` and makes the node read-only (`chmod 0444`) in RAM. Android's `init` tries to write `1` when you put the headset on, fails with permission denied, and gives up. Fast charging stays active permanently.  
   *(We do not touch `sys.hmt.mounted`, so proximity sensing, displays, and tracking still sleep and wake naturally with no grey screen glitches).*

2. **Auto-latches to 9V:**  
   When a USB-PD charger or power bank is plugged in, the background daemon checks the charger's advertised PDOs. If it finds 9V (PDO 2), it requests it from the kernel PHY (`/sys/class/usbpd/usbpd0/select_pdo`). This cuts cable current from ~3.5A down to ~1.8A, dropping cable and port heat by more than 70%.

3. **Thermal-Safe 3.0A Fast Charging:**  
   Instead of uncapped 4.8A peaks that quickly overheat the uncooled rear battery pack to 45°C (causing Qualcomm JEITA thermal cutoffs and pulsing orange LEDs), the daemon caps fast charging current to a stable **3.0A (~12W)**. This allows continuous, unbroken fast charging that stays comfortably under 40°C and actually reaches 80% faster overall.

4. **Adaptive Dual-Charger 80% Float Bypass (Zero Drift & Power Bank Safe):**  
   The Quest Pro features a dual-charger architecture consisting of a primary **Qualcomm PM8150B** PMIC and a secondary **Qualcomm SMB1355** parallel booster.
   - **During Fast Charging (< 80%):** Both chargers run in tandem (`parallel_disable = 0`), splitting the current to minimize heat dissipation on each chip.
   - **At Target SOC (80%):** The daemon powers down the secondary SMB1355 booster completely (`parallel_disable = 1`) and locks the primary PM8150B into an adaptive float clamp:
     - **On Dock (Pogo Pins):** Clamped to **50 mA** (`force_main_fcc = 50000`), balancing deep-sleep idle draw almost perfectly with virtually zero overnight drift (< 0.3% over 10 hours).
     - **On USB (Power Banks):** Clamped to **100 mA** (`force_main_fcc = 100000`), keeping smart power banks awake without port shutoffs.
   - **Singularity Integration & Auto-Conflict Suppression (tested on Singularity v2.5 & v2.6):**
     - Dynamically reads your chosen `charge_limit_target` from Singularity's preferences (`singularity_prefs.xml`), defaulting to **80%** if unset.
     - Automatically suppresses Singularity's competing `charge_limit.sh` in memory (and ensures the script stays writable so Singularity never crashes when changing settings) so it never fights the hardware float clamp or causes the power LED to cycle. (I'd still recommend disable the charging limit in singularity tbh)
     - **Singularity UI Quirk:** Because `charge_limit.sh` is stopped in the background, Singularity may flip its toggle back to off and display `100%` in the UI after a while. This is purely cosmetic—your saved `charge_limit_target` in `singularity_prefs.xml` is preserved and continues to be enforced by this module.

5. **True Hardware Power Bypass (VPH_PWR):**  
   Thanks to Qualcomm's NVDC power-path architecture, the XR2 processor, displays, and tracking cameras draw power directly from the external charger via the system rail (`VPH_PWR`). When the 80% float lock is engaged, the battery sits idle behind the BATFET switch without cycling or heating up while you game for hours.

6. **Magisk Action Button Toggle:**  
   Supports two modes you can switch between by pressing the **Action** button on the module in the Magisk app:
   - **FORCE 9V (Default):** Locks 9V fixed rail on plug/replug. Ideal for long Link cables and power banks to minimize cable heat.
   - **PPS DYNAMIC:** Disables the 9V lock and lets chargers with USB-PD PPS scale voltage dynamically (5V-11V) with the battery.

7. **Night-Friendly Dim Green LED:**  
   When charging and at 75% or higher, the side power LED switches to a gentle, dim ambient green (PWM 15) so you can tell at a glance across the room that it's ready without blinding you in the dark. It turns off cleanly the moment you unplug or lift it off the dock.

## Safety

- **Never touches `/persist`**, `/boot`, or any flash partition.
- Everything runs purely in memory (RAM) and user space (`/data/adb/modules/qpro_fastcharge/`).
- Disabling or removing the module and rebooting instantly restores 100% stock behavior.

## Installation

### Magisk App
1. Download `QProFastCharge-Magisk.zip`.
2. Open Magisk Manager -> Modules -> Install from storage -> pick the zip.
3. Reboot.

### ADB
```bash
adb push QProFastCharge-Magisk.zip /data/local/tmp/
adb shell su -c "magisk --install-module /data/local/tmp/QProFastCharge-Magisk.zip"
```

## Toggling Modes

- **In Magisk Manager:** Go to Modules, find **Quest Pro Fast Charge Enforcer**, and tap the **Action** button. It will flip modes and print live voltage, current, and battery stats.
- **Via ADB:**
  ```bash
  adb shell su -c "sh /data/adb/modules/qpro_fastcharge/action.sh"
  ```

## Uninstalling

Disable or remove it in the Magisk app, or run:
```bash
adb shell su -c "rm -rf /data/adb/modules/qpro_fastcharge; chmod 644 /sys/class/power_supply/bms/charge_profile"
```

## Thx Gemini! <3
