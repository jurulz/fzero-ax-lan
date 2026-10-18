# Dolphin patches

`patches/` is a series made with `git format-patch` on top of upstream
[`dolphin-emu/dolphin`](https://github.com/dolphin-emu/dolphin) commit `66d8a892203d76a1f7349ed07526089b828e3835`.
Apply it with `git am` (see [../docs/BUILD.md](../docs/BUILD.md)).

| Patch | What it does |
|---|---|
| `0001` Common: Fix GetLocalTimeSinceJan1970 on Windows 10 before 1903 | `std::chrono::current_zone()` throws on older Windows 10 builds (for example 1809 LTSC); use the Win32 API. |
| `0002` DiscIO: Keep the recorded DOL offset of arcade games in DirectoryBlob | Booting an extracted game folder moved the DOL, which broke the reboot into the SegaBoot test menu. |
| `0003` AMMediaboard: Emulate the LAN link between Triforce cabinets over UDP | The link of F-Zero AX: [../docs/LINK.md](../docs/LINK.md). |
| `0004` F-Zero AX: Publish cabinet outputs and add built-in force feedback | Network outputs ([../docs/OUTPUTS.md](../docs/OUTPUTS.md)) and force feedback ([../docs/FFB.md](../docs/FFB.md)). |
| `0005` DolphinQt: Show the arcade function of each control in the Triforce pad window | Group titles of the pad mapping window. |
| `0006` DolphinQt: Write crash_report.txt with a module+offset call stack on Windows | Diagnostics for machines without a debugger. |

Patches 1 and 2 are independent fixes that could also be proposed to upstream.
