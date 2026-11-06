# Quest Pro Fast Charge Enforcer (`qpro_fastcharge`)

A lightweight Magisk module for the **Meta Quest Pro (`seacliff`)** that prevents preemptive charging throttling while the headset is worn, maintains unthrottled fast charging, and provides an automatic **9V Rail Auto-Lock** with an interactive **Magisk Action Button** toggle.

---

## ⚡ The Problem

1. **Preemptive Worn-State Throttling:**  
   In stock firmware, whenever you wear the headset (proximity sensor `sys.hmt.mounted = 1`), `/vendor/etc/init/hw/init.kona.rc` reacts by executing:
   ```rc
   on property:sys.hmt.mounted=1
       write /sys/class/power_supply/bms/charge_profile 1
   ```
   Setting `charge_profile` to `1` instructs the Qualcomm PMIC (`PM8150B / SMB5`) to throttle down charging to ~5V so the headset's cooling fans stay quiet near your face.

2. **The "High Amperage Cable Burn" Issue:**  
   If you use a long (3m–5m) link cable or a power bank with cable resistance ($R \approx 0.3\,\Omega - 0.5\,\Omega$):
   - Pulling ~15W at **5V** forces **3.0A – 3.65A** through the wire!
   - By Joule's law ($P_{\text{loss}} = I^2 \times R$), high amperage causes severe voltage drop (sagging to ~4.5V) and dissipates **~3 to 5 Watts of pure heat** directly into your cable and USB-C port pins!

---

## 🚀 The Solution

1. **In-Memory Charge Profile Lock:**  
   The module writes `0` to `/sys/class/power_supply/bms/charge_profile` and sets permissions to `0444` (read-only in RAM). Android `init` is blocked with `open() failed: Permission denied`, keeping fast charging permanently active without touching the proximity sensor or affecting the VR display (zero grey screen issues).

2. **Two Operating Modes (Toggled via Magisk Action Button):**

   | Mode | Behavior | Best For |
   | :--- | :--- | :--- |
   | **`FORCE 9V (LOCKED)`** *(Default)* | Background daemon detects USB-PD hotplug/replug and commands the kernel PHY (`select_pdo`) to lock onto the **9V fixed rail (PDO 2)**. Voltage jumps to ~8.9V and cable current drops to **~1.8A**, reducing cable heat by **over 70%**! | Long link cables, power banks, preventing port and cable heat. |
   | **`PPS DYNAMIC`** | Disables the 9V lock and allows standard USB-PD PPS dynamic voltage modulation (5V–11V) with the battery. | Users who prefer lower internal motherboard conversion heat on short/thick cables. |

3. **Live Magisk Action Button Integration:**  
   Tapping the **Action** button on the module card in Magisk Manager toggles between **FORCE 9V** and **PPS DYNAMIC**, updates the card description in real-time, and prints live telemetry (USB Voltage, Cable Amps, Battery Temp, Profile).

---

## 🛡️ Absolute Safety & Reversibility

- **NEVER touches `/persist`**, `/boot`, `/vendor`, or flash partitions.
- Operates 100% in volatile memory (RAM) and user space (`/data/adb/modules/qpro_fastcharge/`).
- Disabling the module or uninstalling it immediately restores 100% stock firmware behavior on reboot.

---

## 📦 Project Structure

```
QProFastCharge/
├── module/
│   ├── META-INF/com/google/android/
│   │   ├── update-binary          # Standard Magisk installer binary
│   │   └── updater-script         # Magisk dummy script
│   ├── action.sh                  # Interactive Magisk Action button toggle & status
│   ├── customize.sh               # Module installer hook
│   ├── module.prop                # Module ID, name, version, and dynamic description
│   ├── service.sh                 # Background late_start daemon (charge profile & 9V lock)
│   └── uninstall.sh               # Clean uninstallation hook (restores sysfs 0644)
├── package.py                     # Python packaging script (builds flashable zip)
├── QProFastCharge-Magisk.zip       # Pre-built flashable Magisk module zip
├── .gitignore
└── README.md
```

---

## 🛠️ Installation

### Method 1: Via Magisk App (On Headset)
1. Copy [`QProFastCharge-Magisk.zip`](./QProFastCharge-Magisk.zip) to your headset storage (e.g. `/sdcard/Download/`).
2. Open **Magisk Manager** (or Singularity app).
3. Navigate to **Modules** &rarr; **Install from storage** &rarr; select `QProFastCharge-Magisk.zip`.
4. Reboot the headset.

### Method 2: Via ADB (One-Liner)
```powershell
adb push QProFastCharge-Magisk.zip /data/local/tmp/
adb shell su -c "magisk --install-module /data/local/tmp/QProFastCharge-Magisk.zip"
```

---

## 🎮 How to Toggle Modes

### Via Magisk App UI:
Open Magisk Manager &rarr; Modules &rarr; tap the **Action** button on **Quest Pro Fast Charge Enforcer**.

### Via ADB:
```powershell
adb shell su -c "sh /data/adb/modules/qpro_fastcharge/action.sh"
```

Output:
```text
=========================================
   Quest Pro Fast Charge Manager
=========================================
MODE SWITCH: [ FORCE 9V (LOCKED) ]
Enforcing 9V fixed rail for lowest
cable amperage and minimal cable heat.
-> Latch triggered: Selected 9V (PDO 2)!
-----------------------------------------
 Live Telemetry:
 USB Voltage  : 8.93 V
 Cable Current: 1.82 A
 Battery Temp : 27.5 °C
 Headset Worn : YES
 BMS Profile  : 0 (0=Fast)
=========================================
```

---

## 🗑️ How to Uninstall / Revert

- **Via Magisk App:** Toggle module OFF or tap **Remove**, then reboot.
- **Via ADB:**
  ```powershell
  adb shell su -c "rm -rf /data/adb/modules/qpro_fastcharge; chmod 644 /sys/class/power_supply/bms/charge_profile"
  ```

## Thx Gemini! < 3
