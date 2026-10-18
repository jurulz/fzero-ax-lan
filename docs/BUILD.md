# Building

## Dolphin (Windows)

Requirements: Visual Studio 2022 with the *Desktop development with C++* workload (it includes CMake and Ninja), Git. See also Dolphin's own build instructions.

```
git clone https://github.com/dolphin-emu/dolphin.git
cd dolphin
git checkout 66d8a892203d76a1f7349ed07526089b828e3835
git submodule update --init --recursive
git am ../fzero-ax-lan/dolphin/patches/*.patch          # Git Bash; or one file at a time
```

Then, from a *x64 Native Tools Command Prompt for VS 2022*:

```
cmake --preset ninja-release-x64
cmake --build --preset ninja-build-release-x64
```

The result is `build\release\x64\Binaries\Dolphin.exe`. For a portable install put an empty `portable.txt` next to it (the patcher then uses `User\` next to the exe).

Notes:

- The patches apply to upstream commit `66d8a89` (3 August 2026). Newer upstream commits may need the patches to be rebased.
- If you change `Source/Core/Core/HW/Triforce/FZeroAX.h`, also touch `Source/Core/Core/HW/SI/SI_DeviceAMBaseboard.cpp` before building: Ninja did not track that dependency in our build, and a stale object file (wrong `sizeof` of the I/O adapter) causes heap corruption a few seconds after start.
- Keep the PDB that matches each binary you distribute: `crash_report.txt` (written next to `Dolphin.exe`) contains module + offset call stacks that can be resolved with it.

## Force feedback bridge (optional)

```
csc /platform:x64 /optimize+ /out:DolphinFFBBridge.exe ffb\DolphinFFBBridge.cs
```

(`csc.exe` of the .NET Framework 4.x, C# 5 is enough.) Put the x64 `SDL2.dll` (2.0.x) next to the exe.

## Scripts

`patcher\FZero_LAN_Patcher.ahk` and `ffb\FFB_Settings.ahk` need [AutoHotkey v2](https://www.autohotkey.com). The release zip also contains copies of `AutoHotkey64.exe` renamed to the script names (an AutoHotkey exe runs the `.ahk` with the same name next to it), so the cabinet PCs do not need an AutoHotkey install.
