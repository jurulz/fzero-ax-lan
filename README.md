# F-Zero AX LAN for Dolphin

**English** | [Français](README.fr.md)

Run **F-Zero AX** (Triforce arcade board) on a modified [Dolphin](https://dolphin-emu.org) with **linked cabinets** (VS mode over a LAN), **lamp outputs** and **force feedback**.

> **Unofficial modified Dolphin.** The `Dolphin.exe` in the releases is a **modified, unofficial build of [Dolphin](https://dolphin-emu.org)** (GPL-2.0-or-later): upstream commit `66d8a892203d76a1f7349ed07526089b828e3835` plus the patches in [`dolphin/patches/`](dolphin/patches/) (release 0.9.0 = tag [`fzero-ax-lan-v0.9.0`](https://github.com/jurulz/dolphin/tree/fzero-ax-lan-v0.9.0) of the fork, see [SOURCE.md](SOURCE.md)). It is not made, supported or endorsed by the Dolphin Emulator Project: **do not report problems with this build to them**, open an issue here instead. Please do not use it for netplay or anything else that expects an official build.

## TL;DR

You need your own **F-Zero AX (Japan) (Rev E)** ISO (game ID `GFZJ8P`, SHA-1 `73f3ddec23c85bc65ae51ed2ce8973231dadaeb1`, details [below](#which-iso)) and two or more Windows PCs on the same network.

1. Download [the release zip](https://github.com/jurulz/fzero-ax-lan/releases) (current release: **0.9.0**) and unzip it on **each** PC.
2. Copy your ISO into `Game\`.
3. Run `FZero_LAN_Patcher.exe` on each PC: pick *This cabinet is* (1 on the first PC, 2 on the second...), the number of cabinets and the real IP of each one, then **APPLY**, **Dolphin firewall** (once) and **Launch game**.
4. First start: the game asks for a calibration (see [below](#first-start-calibration)).
5. On the *CHECKING NETWORK* screen, `1 OK` and `2 OK` mean you are linked.

The test / service menu (key `T`) is optional and needs your own `segaboot.gcm` in `Dolphin-FZero\User\Triforce\` (see [below](#optional-the-test--service-menu-segabootgcm)). Everything else works without it.

Force feedback and lamps are optional: see [START_HERE.txt](START_HERE.txt) (one page) or the sections below.

## What's in the release zip

The zip of release 0.9.0 (`FZero_LAN-v0.9.0-win64.zip`, 31.9 MB) unzips to one folder, `FZero_LAN\`:

| In the zip | What it is |
|---|---|
| `Dolphin-FZero\` | The modified, portable Dolphin (`Dolphin.exe`, `DolphinTool.exe`, Qt and Visual C++ runtime DLLs, `Sys\`, licenses). `User\Triforce\` holds a placeholder for the optional `segaboot.gcm`. |
| `FZero_LAN_Patcher.exe` / `.ahk` | The patcher (the `.exe` is a copy of AutoHotkey that runs the `.ahk` next to it). |
| `FFB\` | `FFB_Settings.exe` / `.ahk` (force feedback settings), `DolphinFFBBridge.exe` (optional external bridge), `SDL2.dll`, `ffb_bridge.ini`. |
| `Game\` | Put your ISO here (`PUT_ISO_HERE.txt`). |
| `Tools\` | `listen_dolphin_outputs.ps1` (records the lamp / wheel outputs, diagnostics). |
| `docs\` | The documents of this repository's `docs/` folder. |
| `dolphin-patches\` | The 6 Dolphin patches (`0001` to `0006`): the same as [`dolphin/patches/`](dolphin/patches/). |
| `START_HERE.txt`, `README.md`, `CHANGELOG.md`, `LICENSE`, `NOTICE.md` | One-page guide, readme, changes, license and third-party notices. |

To check your download: `Get-FileHash -Algorithm SHA256 FZero_LAN-v0.9.0-win64.zip` in PowerShell must give `30f9a468a0a2eaa730a6ff6ce05a5b41fb62a882a11c9f8bdd57014e6d6ad133` (also in `SHA256SUMS.txt` on the release page).

## What's here

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

## Which ISO?

Exactly this dump (uncompressed `.iso` / `.gcm`), **before** you patch it:

| | |
|---|---|
| Name | **F-Zero AX (Japan) (Rev E)** |
| Game ID | `GFZJ8P` (first 6 bytes of the file) |
| Size | 435 995 904 bytes |
| SHA-1 | `73f3ddec23c85bc65ae51ed2ce8973231dadaeb1` |
| MD5 | `9070d5677e0950ceb086bced1f8cc423` |
| CRC32 | `9b1aebaf` |

Check it with `Get-FileHash -Algorithm SHA1 "F-Zero AX (Japan) (Rev E).iso"` in PowerShell. These hashes are those of the **original** file: APPLY modifies the ISO in place (a copy of the original `main.dol` is kept next to it), so its hash changes afterwards.

Other revisions or variants are **not supported** and the patcher refuses them (it checks the game ID, the `main.dol` size and the code around every patched place). Compressed images (RVZ, WIA, GCZ, CISO) must be converted to ISO first (Dolphin: right-click the game > Properties > Convert File). An extracted folder (`sys\` and `files\`) of the same version also works.

## Optional: the test / service menu (`segaboot.gcm`)

The cabinet's test and service menus are provided by the Triforce boot firmware, `segaboot.gcm`. It is **not included and not distributed here**: you must supply your own copy and put it in `Dolphin-FZero\User\Triforce\segaboot.gcm` (the release zip has a placeholder file in that folder). Then press `T` once the game is loaded (the patcher's hybrid mapping lets you use the keyboard for it).

Without it the game itself, the link, the lamps and force feedback are not affected; only the test / service menus are unavailable (the patcher logs a hint when the file is missing).

## Status

Tested on two cabinet PCs (Windows 10 LTSC 1809, Chrome Remote Desktop for access):

- Works: linked VS mode between two cabinets, lamps in BackForceFeeder, force feedback through vJoy + BackForceFeeder, motor-check and card-reader-cleaning bypass, test menu, patching an ISO in place.
- **Not tested**: force feedback on a traditional USB wheel (Logitech, Thrustmaster, Fanatec...), three or four linked cabinets, Windows 11, the arcade labels of the Triforce pad window (compiled in, not checked on screen).
- The patch offsets are for the **Rev E** `main.dol` only (SHA-1 `708c0860f61cbabbaae6568fd290c400c5c37c60`).

## Quick start

1. Download the latest release zip (it contains a ready-to-run Dolphin build, the patcher, the force feedback tools and the docs) and unzip it **on each cabinet PC** (same build everywhere).
2. Put your ISO in `Game\`.
3. Run `FZero_LAN_Patcher.exe` (or the `.ahk` with [AutoHotkey v2](https://www.autohotkey.com)):
   - *This cabinet is*: Cabinet 1 on the first PC, Cabinet 2 on the second one...
   - *Number of cabinets* and the **real IP address of each one** (PCs on the same network).
   - **APPLY**, then **Dolphin firewall** (once), then **Launch game**.
4. On the *CHECKING NETWORK* screen, `1 OK` and `2 OK` mean the cabinets see each other.

Details, options and troubleshooting: [docs/LINK.md](docs/LINK.md).

## First start: calibration

The first time the game starts it shows a calibration screen (*Please carry out adjustment of a handle and a brake*, with `HANDLE UP / DOWN / LEFT / RIGHT`). With the default keyboard mapping: **Left / Right** arrows for the wheel, **W** for the accelerator, **Q** for the brake, then **Enter**. The screen also lists *up* and *down* for the handle: use the **Up / Down** arrow keys for those (a real wheel only has the left / right axis, and the up / down axis is not used in a race). Keep the controls untouched for a few seconds when the screen appears, then move them.

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

Not used by the game: B, Z, C-Stick. Control Stick Y: not used in a race; only the calibration screen lists *up* / *down* for the handle (keyboard arrows are enough for it). The patcher can add the keyboard keys for Test / Service / Coin **on top of** a gamepad or vJoy device ("hybrid mapping").

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

## Source code

The complete source of every binary in the releases, with the exact commit, is listed in [SOURCE.md](SOURCE.md). The modified Dolphin is the branch `fzero-ax-lan` of <https://github.com/jurulz/dolphin>; the same changes are in [dolphin/patches/](dolphin/patches/).

## License

The Dolphin patches and everything else in this repository are licensed under **GPL-2.0-or-later** (see [LICENSE](LICENSE)), like Dolphin. Third-party components shipped in the release zip and their licenses are listed in [NOTICE.md](NOTICE.md).
