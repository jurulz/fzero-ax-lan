# F-Zero AX wheel protocol (what the game sends)

F-Zero AX talks to the force-feedback steering wheel over a serial line of the AM baseboard. Dolphin's `FZeroAXSteeringWheel` decodes the requests; this fork publishes every command it receives on the [network outputs](OUTPUTS.md) (`WheelCmd<N>`, `WheelCnt<N>`). The notes below come from recordings of real races (two cabinets, one player) and are **observations, not documentation**: the meaning of several commands is unknown.

## Request format

Each request is 3 bytes: `cmd ^ 0x80`, `byte1`, `byte2`; the 16-bit value is `(byte1 << 8) | byte2`. The reply is 4 zero bytes.

## The target position (command 4)

```
WheelServo = (s8)(0x80 - ((u8)(byte1 << 7) | byte2))
```

It is the position the game wants the wheel to take, **not a force**. Range seen in races: `-50` ... `+51` (raw values `306` = -50, `256` = 0, `77` = +51), i.e. end stop to end stop of the cabinet wheel (the real angle is not known). New values arrive about every 50-60 ms (Dolphin only publishes changes).

What it looks like in play:

- smooth ramps and small damped oscillations (bumps, curves);
- during hits and wall scraping, a fast **rattle**: the target jumps between `0` and `±50` (80 % of the samples of a rough race were exactly `0`, `+51` or `-50`);
- when the target stays at `0` and the player holds the wheel off-centre, a position servo pulls toward the centre: the "light spring" feel.

So all the force effects of the game are encoded in this single command; no separate shake / spring / damper commands were seen in races.

## Other commands (sent during initialization and state changes)

| Command | Values seen | Notes |
|---|---|---|
| `0` | `1` / `0` | Motor power. Repeated every ~50 ms during the init handshake, then once every ~3.2 s during a race as a keep-alive; goes `0,1,0,1` at the end of a race. |
| `1`, `2` | `32639`, `3156` | Sent once at init; Dolphin's code comments them "Set Maximum?". |
| `3` | `24320` (menus), `20480` (races) | Changes between menus and races: probably a servo level. |
| `4` | see above | Target position. |
| `6`, `9` | `0` then `522`; `8` then `832` | Sent at init, again after the calibration sweep. |
| `7` | `256` | Switch to normal mode (`WheelInit = 2`). |
| `10`, `11` | `4184`, `6912` | Sent once after the calibration sweep. |
| `112` | `0` | Sent repeatedly during init (poll). |
| `122` | `16`, `20`, `16` | Init. |
| `124` | `32`, `48`, `64` | Init: a ramp. |
| `125` | `0` (7 times in 0.4 s) | Seen once, when the motor first turned on. |
| `127` | `0` | Reset (`WheelInit = 1`). |

## Initialization

1. Reset (`127`), then power (`0 = 1`) and the parameter commands.
2. The game sweeps the wheel with targets `-32`, `+32`, `-8`, `0` while it reads the steering input back for calibration. Dolphin overrides the steering analog input with `servo * 512 + neutral` during this phase so the calibration succeeds without a motor.
3. More parameters, then command `7` (normal mode). The *Motor Initializing* screen lasts about 45 s.

The patcher can bypass this screen (see [PATCHES.md](PATCHES.md)), but then the game never sends orders to the wheel: do not bypass it when using force feedback.
