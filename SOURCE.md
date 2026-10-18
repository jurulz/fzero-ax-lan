# Source code of the binaries

Every binary in the releases of this project is built from public source code. This page says where.

## Dolphin (`Dolphin-FZero\Dolphin.exe`, `DolphinTool.exe`)

An **unofficial, modified build** of [Dolphin](https://github.com/dolphin-emu/dolphin) (GPL-2.0-or-later). Its complete corresponding source is:

- the full modified source tree: <https://github.com/jurulz/dolphin>, branch `fzero-ax-lan` (upstream commit `66d8a892203d76a1f7349ed07526089b828e3835` plus the 6 commits of the branch), tag `fzero-ax-lan-v0.9.0`;
- or, equivalently, upstream commit `66d8a89` plus the patches in [dolphin/patches/](dolphin/patches/) of this repository (`git am`), which are also inside the release zip (`dolphin-patches\`).

| Release | Dolphin source commit (branch `fzero-ax-lan`) | Patches |
|---|---|---|
| 0.9.0 | `5ce6679` (tag `fzero-ax-lan-v0.9.0`) | 0001-0006 |

How to build it, step by step: [docs/BUILD.md](docs/BUILD.md). The version text that the binary shows in its window title may name another commit than the table (it is the commit that was current when CMake was last configured); the table is the reference.

## Small programs

| In the release | Source in this repository |
|---|---|
| `FZero_LAN_Patcher.exe`, `FFB_Settings.exe` | Each one is an unmodified copy of `AutoHotkey64.exe` v2.0.30 (GPL-2.0, <https://github.com/AutoHotkey/AutoHotkey>) renamed to run the script of the same name: `patcher/FZero_LAN_Patcher.ahk`, `ffb/FFB_Settings.ahk` |
| `DolphinFFBBridge.exe` | `ffb/DolphinFFBBridge.cs` |

How to compile the C# bridge: [docs/BUILD.md](docs/BUILD.md).

## Other components

Qt 6 (unmodified DLLs, LGPL-3.0) and SDL2 (unmodified, zlib) are not modified by this project; their sources are at <https://www.qt.io/licensing> and <https://libsdl.org>. See [NOTICE.md](NOTICE.md).

## If something is missing

If you cannot get the source of a release from the places above, open an issue: the corresponding source of every release is provided on request for at least three years after that release.
