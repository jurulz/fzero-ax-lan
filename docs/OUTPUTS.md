# Cabinet outputs (lamps and wheel state)

Dolphin serves the *network outputs* protocol used by MAME and Flycast, so cabinet software such as
[BackForceFeeder](https://github.com/njz3/vJoyIOFeederWithFFB) can read the lamps and the wheel state of an emulated F-Zero AX.

## Settings

`Dolphin.ini`, section `[Core]`:

| Key | Default | Meaning |
|---|---|---|
| `TriforceOutputs` | `True` | Turn the outputs server on or off |
| `TriforceOutputsTcpPort` | `8000` | TCP port of the server (127.0.0.1 only) |
| `TriforceOutputsUdpPort` | `8001` | UDP port of the announcement (`0` = none) |

## Protocol

- While nobody is connected, Dolphin sends a UDP datagram every second to `127.0.0.1:8001`:
  `mame_start = fzeroax\rtcp = 8000\r`
- A TCP client connecting to `127.0.0.1:8000` first receives `mame_start = fzeroax`, then the current value of every output, then `<name> = <value>` on every change. **Lines end with CR+LF** (a lone CR makes .NET's `ReadLine` wait for the next byte).

## Names

| Name | Meaning |
|---|---|
| `mamerun` | `1` while the game runs |
| `LampStart` | Start button lamp (blinks on the title screen) |
| `LampView1` ... `LampView4` | View change buttons lamps |
| `LampBoost`, `LampLeader` | Boost lamp (`LampLeader` is the same bit under the name BackForceFeeder maps to its 8th output) |
| `WheelServo` | Target wheel position requested by the game, `-50` ... `+51` |
| `WheelInit` | `0` not started, `1` initializing / calibrating, `2` normal |
| `WheelCmd<N>` | Last value (`byte1 << 8 \| byte2`) of wheel command `N` (see [WHEEL_PROTOCOL.md](WHEEL_PROTOCOL.md)) |
| `WheelCnt<N>` | How many times wheel command `N` was received (all commands except the target position `4`) |

Only changes are sent. `tools/listen_dolphin_outputs.ps1` records the stream with timestamps.

## BackForceFeeder

BackForceFeeder chooses where it reads lamps from **per control set**. In its *control set editor*, for the profile used with Dolphin:

- `Exec. process name`: `Dolphin`
- `Output type`: `MAME_NET`

BackForceFeeder only connects to `127.0.0.1`, so it must run on the same PC as Dolphin. Restart BackForceFeeder if you restart Dolphin.
