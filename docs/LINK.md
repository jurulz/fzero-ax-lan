# Linking cabinets (VS mode over a LAN)

## How it works

F-Zero AX keeps one **0x5A0-byte link block per cabinet** in the media board memory and expects the board firmware to mirror every cabinet's block to the others. On a real cabinet this is done over Ethernet.

In this fork (`AMMediaboard.cpp`):

- When the game sets up the link, Dolphin reads the UDP port the game asks for (`58505` for F-Zero AX) and the number of cabinets (`LINK NUM`).
- On every *SearchDevices* command, Dolphin sends **its own block** to every other unit over UDP and copies the blocks received from the others into the link memory.
- Addresses go through Dolphin's **IP address redirection table** (`Dolphin.ini`, `[Core]`, `TriforceIPRedirections`). The game uses the virtual addresses `192.168.11.1` ... `192.168.11.4` (cabinet 1 to 4); the table maps each one to the real address of the PC.

Both PCs **must run the same `Dolphin.exe`**.

## What the patcher does

For each PC you tell it which cabinet it is (1 to 4), how many cabinets there are and the real IP of each one. Then **APPLY**:

1. Patches `main.dol` (in your ISO, or in an extracted game folder) so the game starts with the right `NUMBER` and `LINK NUM` and **does not need the test menu** to set them. A copy of the original `main.dol` is kept next to the ISO (`*.main.dol.before_LAN`). Details: [PATCHES.md](PATCHES.md).
2. Writes the redirection table (`192.168.11.N=<real IP>`) into `Dolphin.ini` and removes any previous `192.168.11.x` entry.
3. Optional: renames `tribackup_*.bin` (the arcade backup memory) to `*.before_LAN_<time>` so the game starts from clean defaults. A stale backup ignores the patched defaults.
4. Optional: bypasses the *Motor Initializing* screen and the card reader *Cleaning Card* request.
5. Optional: adds keyboard keys for Test / Service / Coin on top of the gamepad ("hybrid mapping"), writing `GCPadNew.ini`.

Use **Dolphin firewall** once on each PC (it asks for administrator rights): it allows `Dolphin.exe` through the Windows firewall.

## Checking it works

Start the game on both PCs. On the *CHECKING NETWORK NOW* screen, `1 OK` and `2 OK` mean the cabinets see each other. If one stays `NG`:

- Check the IP addresses and that the PCs ping each other.
- Check that **both** PCs did APPLY, with **different** cabinet numbers.
- Check that both use the **same** `Dolphin.exe` and that the firewall rule exists.
- Reset the game save (tick the option and APPLY again).
- In Dolphin, enable the `AMMEDIABOARD_NET` log category and look for `GC-AM: link:` lines.

## Magnetic card

The game plays without a card. If Dolphin finds `User\Triforce\tricard_<id>.bin` it inserts it automatically. A crash when inserting the card during a link was seen once and went away after deleting that file on the faulty PC: **never copy a card file from one PC to another**, let each PC create its own.

## Limits

Tested with two cabinets only.
