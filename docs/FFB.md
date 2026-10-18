# Force feedback

Two modes, one settings window (`ffb/FFB_Settings.ahk`, or `FFB_Settings.exe` in the release zip).

1. **Built into Dolphin** (default, no extra program). Dolphin reads the real wheel position (the Control Stick X of pad 1, i.e. your wheel axis) and the position the game wants (`WheelServo`, `-50` ... `+51` = end stop to end stop) and computes

   ```
   force = Kp x (target - position) - Kd x velocity
   ```

   which it sends as a *Constant* force effect to a force-feedback device: the device of GameCube pad 1 by default (vJoy / BackForceFeeder, or a real wheel through DirectInput). Settings live in `User\Config\FZeroFFB.ini` (written by the window, reloaded on the fly, so it keeps working without the window once `enabled = 1`).
2. **External bridge** (`DolphinFFBBridge`, built from `ffb/DolphinFFBBridge.cs`, needs `SDL2.dll`). Same maths in a separate program that reads Dolphin's [network outputs](OUTPUTS.md) and writes to vJoy through SDL2. Settings in `ffb_bridge.ini`. Never run both at once (the window switches one off when you pick the other).

## To do once

- **vJoy**: enable force feedback on the device (vJoyConf > *Enable Effects*, tick *Constant Force*) and run BackForceFeeder with FFB active.
- **Patcher**: *uncheck* "Bypass the motor check", otherwise the game does not initialize the wheel and sends no order. The *Motor Initializing* screen then lasts about 45 seconds.

## Using it

Start BackForceFeeder, start the settings window, start the game. Force is applied **only** when the wheel is initialized and the game has turned the motor on (not on the title screen: insert a coin, press Start, pick a course).

- *Test (gentle push)*: the wheel pushes right then left for 2 s. If it goes the wrong way, tick *Invert force direction* (Dolphin's constant effects push left for a positive value; the code flips it, but devices differ).
- *Shock test (max force)*: full force right then left (0.25 s each). Start with a low *Max force* and your hands on the wheel.
- *Cut force* is an emergency stop.

## A traditional USB wheel (Logitech, Thrustmaster, Fanatec...)

*Not tested on real hardware.* It should work with the built-in mode if the wheel offers DirectInput force feedback (constant force):

- Install the vendor driver and close programs that control the wheel exclusively.
- In Dolphin: Controllers > Port 1 (Triforce baseboard) > Configure. Choose the **DirectInput** device `DInput/0/<your wheel>`. Map Control Stick left/right to the steering axis, R / L triggers to the pedals, buttons as you like.
- The arcade wheel has a limited rotation (a fraction of a turn each way; the exact angle is not known). Set the wheel's rotation range to a similar value in the driver (270–360° lock to lock is a reasonable start). With 900° the same order feels far too small; raise *Target scale* instead (100–150).
- Leave *Dolphin FFB device* empty to use the device of pad 1, or type `DInput/0/<name>` to send the force to another device.
- Dolphin switches the wheel's own centering spring off while the game runs.

## Settings

| Setting | Meaning |
|---|---|
| Max force | Ceiling. Start low (35 %). |
| Stiffness (`kp`) | Higher = the wheel is pulled harder toward the game's target (0–30). |
| Damping (`kd`) | Higher = fewer oscillations. |
| Shake sharpness (`slew_per_cycle`) | Maximum force change every 10 ms. Keep it at 0.3+ to feel the game's fast rattles. |
| Target scale (`servo_scale`) | `WheelServo` value matching the end stop: 50 for the arcade wheel. Raise it for a wide-range wheel. |
| Small-force sensitivity (`curve`) | 1.00 = linear; lower amplifies small forces. |
| Minimum force (`min_force`) | Minimum power as soon as there is an order; overcomes motor friction. |
| Invert force / wheel axis | Fix a wrong direction. |
| Also apply during initialization | The wheel then sweeps its whole travel: avoid. |

`FZeroFFB.ini` also accepts `enabled`, `device` (`DInput/0/...`, empty = pad 1) and `output` (default `Constant`). Orders go through `FZeroFFB_cmd.txt` (`test`, `shock`, `enable`, `disable`, `toggle`) and the state is written to `FZeroFFB_status.txt` every 250 ms.

## If the force is too weak

1. Max force 100 %, then *Shock test*. If the hit is weak, the limit is **after** Dolphin: in BackForceFeeder, the FFB tuning tab (global gain, **power law = 1.2 by default which weakens small forces**: use 1.0 or lower, dead band) and the application / hardware tab (global gain, global saturation); with a real wheel, its driver's strength setting.
2. If the hit is strong, only the game's orders need strengthening: *Arcade* preset, then raise stiffness and lower small-force sensitivity. Watch *Force sent (peak ...)* during a race.

## Safety

The force is capped by *Max force* and ramped. It drops to zero if the game stops, if the game turns the motor off, on exit and with *Cut force*. This has not been tried by its authors on every kind of hardware: start low, hands on the wheel.
