# Notices

## This project

Copyright (c) 2026 F-Zero AX LAN contributors. Licensed under **GPL-2.0-or-later** (see [LICENSE](LICENSE)).

The Dolphin changes in `dolphin/patches/` modify [Dolphin](https://github.com/dolphin-emu/dolphin) (GPL-2.0-or-later, Copyright the Dolphin Emulator Project). The corresponding source of every `Dolphin.exe` in a release is the upstream commit named in the release notes (`66d8a892203d76a1f7349ed07526089b828e3835` for the first release) plus the patches of this repository, which are attached to the release as well.

## Third-party components in the release zip

| Component | Used for | License |
|---|---|---|
| Dolphin (modified build) | Emulator | GPL-2.0-or-later. See `Dolphin-FZero\COPYING` and `Dolphin-FZero\Licenses\`. |
| Qt 6 (DLLs, unmodified) | Dolphin's interface | LGPL-3.0, <https://www.qt.io/licensing> |
| Microsoft Visual C++ runtime DLLs (`msvcp140*.dll`, `vcruntime140*.dll`, ...) | Dolphin | Microsoft redistributable license |
| SDL2 2.0.12 (`ffb\SDL2.dll`) | External force feedback bridge | zlib (below) |
| AutoHotkey v2.0.30 (`AutoHotkey64.exe`, copied under the names of the scripts) | Runs `FZero_LAN_Patcher.ahk` and `FFB_Settings.ahk` | GPL-2.0, source: <https://github.com/AutoHotkey/AutoHotkey> |

SDL2 license (zlib):

> Copyright (C) 1997-2020 Sam Lantinga <slouken@libsdl.org>
>
> This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
>
> Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
>
> 1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
> 2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
> 3. This notice may not be removed or altered from any source distribution.

## Not included, not affiliated

- The game *F-Zero AX*, its `main.dol`, any ISO and the Triforce service firmware `segaboot.gcm` are **not** part of this project and are not distributed. You need your own legally obtained copies.
- [BackForceFeeder](https://github.com/njz3/vJoyIOFeederWithFFB) and [vJoy](https://github.com/jshafer817/vJoy) are separate projects used for cabinet lamps and force feedback; nothing of them is included.
- F-Zero, GameCube, Triforce and the other names are trademarks of their respective owners. This project is not affiliated with or endorsed by Sega, Nintendo, Namco, the Dolphin team or the authors of the software above.
