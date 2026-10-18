# Changelog

## 0.9.0 (pre-release)

First public version.

- Linked cabinets (VS mode) over UDP, patcher for `main.dol` (cabinet number, number of cabinets), IP redirection table, firewall rule.
- Patch an ISO / GCM in place (a copy of the original `main.dol` is kept) or an extracted folder.
- Optional bypass of the *Motor Initializing* screen and of the card reader cleaning request.
- Cabinet outputs (lamps, wheel state and every wheel command) on the MAME / Flycast network outputs protocol, usable by BackForceFeeder.
- Force feedback built into Dolphin (constant force to vJoy / a DirectInput wheel) with a settings window; optional external bridge.
- Hybrid keyboard + gamepad mapping for Test / Service / Coin; arcade function shown in the group titles of the Triforce pad window.
- Windows 10 1809 fix for the local time; `crash_report.txt` on crashes.
- Known limits: tested with two cabinets; force feedback tested with vJoy + BackForceFeeder only.
