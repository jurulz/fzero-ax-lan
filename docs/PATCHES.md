# What the patcher changes in `main.dol`

Only the **Rev E** `main.dol` (`GFZJ8P`, 3 402 368 bytes, SHA-1 `708c0860f61cbabbaae6568fd290c400c5c37c60`) is supported. The patcher checks the DOL header size and the surrounding instructions before writing anything, and can be run again on an already patched file (it always starts from the known original instructions). A copy of the original DOL is kept the first time.

In an ISO / GCM image the DOL is read from the offset stored at `0x420` of the image header (`0x18000`), patched in place (its size does not change) and written back at the same place. RVZ / WIA / GCZ / CISO images are refused: convert them to ISO first.

## Cabinet number and number of cabinets

Three blocks of default values (file offsets `0x1786C8`, `0x1787C4`, `0x1788AC`) each end with the three instructions

```
stb r4,2(r7)   stb r4,3(r7)   stb r4,4(r7)      ; group, NUMBER, LINK NUM - 1 (all 0)
```

preceded by `li r4,0` and followed (at +12) by `li r3,0x5F`. The patcher rewrites the stores so the defaults become `NUMBER = cabinet - 1` and `LINK NUM - 1 = cabinets - 1`, using registers that already hold 0, 1, 2 (`r4`, `r5`, `r6`); when a value of 3 is needed the first instruction of the block becomes `li r0,3` and `r0` is stored. The game then starts directly in linked mode without going through the test menu.

## Motor check (*Motor Initializing*)

The setup modes form a table; `SMD_ACSETUP_MOTOR` has two function pointers (init `0x801816D8`, update `0x80181658`) at file offset `0x24B4B4`. The bypass stores the pointers of `SMD_ACSETUP_CALIBRATION` instead (init `0x801812E8`, update `0x8018114C`), so the motor mode runs the calibration functions. This is the same idea as Dolphin's *Disable Motor Setup (Rev. E)* game patch, applied statically.

## Card reader cleaning

In `SMD_ACSETUP_MAGCARD` (file offset `0x17E504`, RAM `0x80181504`), when the code concludes a cleaning card is needed it executes `li r0,2` (`0x38000002`). The patcher replaces it with `b +0xC` (`0x4800000C`), the normal exit.

## Other things the patcher writes (not in the DOL)

- `Dolphin.ini`: `[Core] TriforceIPRedirections` with `192.168.11.N=<real IP>` entries (previous `192.168.11.x` entries are removed), and `[Analytics] PermissionAsked = True` so the statistics prompt does not show.
- `GCPadNew.ini`: keyboard + gamepad expressions for `Triforce/Test`, `Triforce/Service`, `Triforce/Coin` of pad 1 (``` `DInput/0/Keyboard Mouse:T` ``` style, joined to an existing expression with `|`). A default keyboard layout is written if the file does not exist.
- Renames `User\Triforce\tribackup_*.bin` (optional).
- A firewall rule `Dolphin FZero LAN` for `Dolphin.exe`, on request (elevated `netsh`).
