# F-Zero AX LAN for Dolphin

Run **F-Zero AX** (Triforce arcade board) on [Dolphin](https://dolphin-emu.org) with **linked cabinets** (VS mode over a LAN), **lamp outputs** and **force feedback**.

This repository contains:

| Folder | What it is |
|---|---|
| [`dolphin/`](dolphin/) | Patches for Dolphin (network link between cabinets, cabinet outputs, built-in force feedback, a few fixes). Applied on top of upstream commit `66d8a89`. |
| [`patcher/`](patcher/) | `FZero_LAN_Patcher.ahk`: patches the game's `main.dol` (cabinet number, number of cabinets, motor / card reader checks) **inside your own ISO**, writes the Dolphin configuration, sets the firewall rule. |
| [`ffb/`](ffb/) | Force feedback settings window (`FFB_Settings.ahk`) and an optional external bridge (`DolphinFFBBridge.cs`). |
| [`tools/`](tools/) | `listen_dolphin_outputs.ps1`: records the lamp / wheel outputs of Dolphin (diagnostics). |
| [`docs/`](docs/) | How the link works, the outputs protocol, force feedback, wheel protocol notes, `main.dol` patch details, build instructions. |

> **No game and no firmware are included, and none will be.** You need your own legally obtained dump of
> *F-Zero AX (Japan) (Rev E)* (`GFZJ8P`). The service-menu firmware `segaboot.gcm` is optional and you must supply it yourself.
> This project is not affiliated with or endorsed by Sega, Nintendo, Namco or the Dolphin team.

## Status

Tested on two cabinet PCs (Windows 10 LTSC 1809, Chrome Remote Desktop for access):

- Works: linked VS mode between two cabinets, lamps in BackForceFeeder, force feedback through vJoy + BackForceFeeder, motor-check and card-reader-cleaning bypass, test menu, patching an ISO in place.
- **Not tested**: force feedback on a traditional USB wheel (Logitech, Thrustmaster, Fanatec...), three or four linked cabinets, Windows 11, the arcade labels of the Triforce pad window (compiled in, not checked on screen).
- The patch offsets are for the **Rev E** `main.dol` only (SHA-1 `708c0860f61cbabbaae6568fd290c400c5c37c60`).

## Quick start

1. Download the latest release zip (it contains a ready-to-run Dolphin build, the patcher and the tools) and unzip it **on each cabinet PC** (same build everywhere).
2. Put your ISO in `Game\`.
3. Run `FZero_LAN_Patcher.exe` (or the `.ahk` with [AutoHotkey v2](https://www.autohotkey.com)):
   - *This cabinet is*: Cabinet 1 on the first PC, Cabinet 2 on the second one...
   - *Number of cabinets* and the **real IP address of each one** (PCs on the same network).
   - **APPLY**, then **Dolphin firewall** (once), then **Launch game**.
4. On the *CHECKING NETWORK* screen, `1 OK` and `2 OK` mean the cabinets see each other.

Details, options and troubleshooting: [docs/LINK.md](docs/LINK.md).

## Controls

Dolphin drives the Triforce baseboard through a GameCube pad mapping. This is what each control does in F-Zero AX (the titles of the groups in the Triforce pad window say the same):

| GameCube control (mapper) | Arcade function | Default key |
|---|---|---|
| Control Stick, X axis | Steering wheel | Left / Right |
| R trigger (analog) | Accelerator pedal | `W` |
| L trigger (analog) | Brake pedal | `Q` |
| A | Boost button | `X` |
| X | Left paddle | `C` |
| Y | Right paddle | `V` |
| Start | Start button | `Enter` |
| D-Pad Right / Left / Up / Down | View change 1 / 2 / 3 / 4 | `H` / `F` / `R` / `G` |
| "Triforce" group: Test | Test button (service menu) | `T` |
| "Triforce" group: Service | Service button | `S` |
| "Triforce" group: Coin | Coin / credit | `1` |

Not used by the game: B, Z, C-Stick, Control Stick Y. The patcher can add the keyboard keys for Test / Service / Coin **on top of** a gamepad or vJoy device ("hybrid mapping").

## Force feedback

Dolphin (this fork) computes a force from the position the game asks the wheel to take and the real wheel position (Control Stick X of pad 1), and sends it as a *constant force* effect to a force-feedback device: vJoy (driven by BackForceFeeder), or a real wheel through DirectInput. Open `FFB\FFB_Settings.exe` to turn it on and tune it (presets, stiffness, damping, test pushes, live state).

- In the patcher, **uncheck "Bypass the motor check"**: otherwise the game never initializes the wheel and sends no order.
- A separate bridge (`DolphinFFBBridge.exe`) is still available as an alternative mode.

Everything, including how to use a Logitech-style USB wheel and what to do when the force is too weak: [docs/FFB.md](docs/FFB.md).

## Lamps and cabinet software

Dolphin serves the same *network outputs* protocol as MAME / Flycast on `127.0.0.1:8000` (lamps, wheel state). [BackForceFeeder](https://github.com/njz3/vJoyIOFeederWithFFB) can use it: in its control set editor use `Exec. process name = Dolphin` and `Output type = MAME_NET`. Protocol and names: [docs/OUTPUTS.md](docs/OUTPUTS.md).

## Building

Dolphin itself (Visual Studio 2022, CMake) and the small tools: [docs/BUILD.md](docs/BUILD.md). Short version:

```
git clone https://github.com/dolphin-emu/dolphin.git && cd dolphin
git checkout 66d8a892203d76a1f7349ed07526089b828e3835
git submodule update --init --recursive
git am ../fzero-ax-lan/dolphin/patches/*.patch      # in Git Bash
cmake --preset ninja-release-x64 && cmake --build --preset ninja-build-release-x64
```

## How it works / notes

- [docs/LINK.md](docs/LINK.md): how the link between cabinets works and how the patcher sets it up.
- [docs/WHEEL_PROTOCOL.md](docs/WHEEL_PROTOCOL.md): what the game sends to the force-feedback wheel (measured on real races).
- [docs/PATCHES.md](docs/PATCHES.md): exactly which bytes of `main.dol` the patcher changes and why.

## License

The Dolphin patches and everything else in this repository are licensed under **GPL-2.0-or-later** (see [LICENSE](LICENSE)), like Dolphin. Third-party components shipped in the release zip and their licenses are listed in [NOTICE.md](NOTICE.md).
