# QuickDrive
Instant vehicle deployment, automated fuel loading, and quick packing for Factorio 2.0.

QuickDrive lets you quickly place a vehicle from your inventory, load it with your chosen fuel, and jump straight into the driver's seat using hotkeys. When you're done driving, press the keybind again to pack the vehicle and all remaining fuel/cargo back into your inventory.

---

## Controls & Keybindings

| Keybinding | Action |
| --- | --- |
| **Ctrl + Shift + V** | Open / close the QuickDrive configuration GUI. |
| **Shift + Enter** | Deploy your selected vehicle & fuel, OR pack up your current vehicle. |
| **Esc** | Close the configuration GUI. |

*Note: Keybindings can be customized at any time in Factorio's Settings -> Controls menu.*

---

## How It Works

1. **Configure Your Setup:** Press Ctrl + Shift + V to open the GUI. Select your preferred vehicle and fuel type from items available in your inventory.
2. **Deploy & Drive:** Press Shift + Enter to instantly place the vehicle, automatically transfer available fuel, and hop inside.
3. **Save State:** QuickDrive remembers your last selection across sessions. Next time, just press Shift + Enter to deploy without opening the GUI.
4. **Pack Up:** Press Shift + Enter while inside a QuickDrive-deployed vehicle to exit, safely transfer all fuel and cargo back to your main inventory, and retrieve the vehicle item.

---

## Features

- **Automatic Fueling & Ammo:** Automatically loads your selected fuel and compatible ammo directly from inventory upon deployment.
- **Persistent Direction:** Inherits your character's exact orientation when entering and exiting vehicles.
- **Auto Launch / Initial Speed Boost:** Gives the vehicle an immediate forward speed burst on deployment.
- **Auto Headlights:** Automatically switches headlights on when deploying at night or in pitch darkness.
- **Support for All Vehicles:** Compatible with standard Factorio vehicles (Cars, Tanks, Spidertrons) as well as modded/electric vehicles.
- **Cargo-Safe Undeploy:** Safely recovers all contents (fuel, ammo, trunk cargo) before placing items back into your inventory.
- **Smart Tracking:** Only packs up vehicles that were deployed via QuickDrive, leaving player-built or automated map vehicles untouched.

---

## Installation

1. Download or copy the `quick-drive_0.1.0` folder into your Factorio mods directory:
   - **macOS:** `~/Library/Application Support/factorio/mods/`
   - **Windows:** `%APPDATA%\Factorio\mods\`
   - **Linux:** `~/.factorio/mods/`
2. Start Factorio and verify that QuickDrive is enabled in the Mods menu.
