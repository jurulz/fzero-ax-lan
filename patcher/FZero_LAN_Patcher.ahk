#Requires AutoHotkey v2.0
#SingleInstance Force
; SPDX-License-Identifier: GPL-2.0-or-later
; Copyright (c) 2026 F-Zero AX LAN contributors
; ============================================================================
;  F-Zero AX - LAN Patcher for Dolphin (Triforce)
;  - Patches the game's main.dol: cabinet number, number of cabinets, motor
;    check bypass and card reader cleaning bypass (each optional). Works on an
;    ISO/GCM image (modified in place) or on an extracted folder (sys\main.dol).
;  - Writes the "IP Address Redirections" table into Dolphin.ini
;  - Resets the game save (tribackup_*.bin, the old one is renamed .before_LAN)
;  - Hybrid keyboard + gamepad mapping for Test / Service / Coin
;  - Sets the firewall rule and launches the game
; ============================================================================

global CFG := A_ScriptDir "\FZeroLAN.ini"
global DOL_SIZE := 3402368
; Offsets (bytes) of the 3 default-value blocks in main.dol
global DOL_BLOCKS := [0x1786C8, 0x1787C4, 0x1788AC]
; Setup mode table (SMD_ACSETUP_MOTOR): 2 function pointers (init, update) at offset 0x24B4B4.
; Bypassing the motor check = making this mode run the functions of SMD_ACSETUP_CALIBRATION
; (same principle as the Dolphin "Disable Motor Setup (Rev. E)" patch).
global MOTOR_OFF := 0x24B4B4
global MOTOR_ORIG := [0x801816D8, 0x80181658]
global MOTOR_SKIP := [0x801812E8, 0x8018114C]
; Card reader cleaning check (mode SMD_ACSETUP_MAGCARD): when it concludes that cleaning is needed, the code
; does "li r0,2" (0x38000002); it is replaced by a jump to the normal exit "b +0xC" (0x4800000C).
global CLEAN_OFF := 0x17E504
global CLEAN_ORIG := 0x38000002
global CLEAN_SKIP := 0x4800000C

; ============================== USER INTERFACE ==============================
g := Gui(, "F-Zero AX - LAN Patcher (Dolphin)")
g.SetFont("s9", "Segoe UI")
g.Add("Text", "w580", "1) Dolphin folder (the one containing Dolphin.exe)")
eDol := g.Add("Edit", "w490 r1", PathOr(IniRead(CFG, "p", "dolphin", ""), AutoDolphin(), DolphinOk))
g.Add("Button", "x+6 w80", "Browse").OnEvent("Click", (*) => PickDir(eDol))
g.Add("Text", "xm w580", "2) The game: ISO / GCM image, or extracted folder (containing sys and files)")
eGame := g.Add("Edit", "w400 r1", PathOr(IniRead(CFG, "p", "game", ""), AutoGame(), GameOk))
g.Add("Button", "x+6 w80", "ISO file").OnEvent("Click", (*) => PickIso(eGame))
g.Add("Button", "x+6 w80", "Folder").OnEvent("Click", (*) => PickDir(eGame))

g.Add("Text", "xm y+14 w150", "This cabinet is:")
ddlMe := g.Add("DropDownList", "x+0 w170 Choose" IniRead(CFG, "p", "me", "1"),
    ["Cabinet 1 (NUMBER 0)", "Cabinet 2 (NUMBER 1)", "Cabinet 3 (NUMBER 2)", "Cabinet 4 (NUMBER 3)"])
g.Add("Text", "x+20 w130", "Number of cabinets:")
ddlN := g.Add("DropDownList", "x+0 w100 Choose" IniRead(CFG, "p", "links", "1"),
    ["2 cabinets", "3 cabinets", "4 cabinets"])

g.Add("Text", "xm y+12 w580", "Real IP of each cabinet (in number order):")
eIP := []
defIP := ["192.168.1.101", "192.168.1.102", "", ""]
Loop 4 {
    g.Add("Text", "xm w150", "Cabinet " A_Index "  (192.168.11." A_Index ") :")
    eIP.Push(g.Add("Edit", "x+0 w200 r1", IniRead(CFG, "p", "ip" A_Index, defIP[A_Index])))
}

cbReset := g.Add("Checkbox", "xm y+12 Checked" IniRead(CFG, "p", "reset", "1"),
    "Reset the game save (recommended, the old one is renamed .before_LAN)")
cbMotor := g.Add("Checkbox", "xm Checked" IniRead(CFG, "p", "motor", "1"),
    "Bypass the motor check (Motor Initializing) - uncheck when using force feedback")
cbClean := g.Add("Checkbox", "xm Checked" IniRead(CFG, "p", "clean", "1"),
    "Skip the card reader cleaning request (Cleaning Card)")
cbHybrid := g.Add("Checkbox", "xm Checked" IniRead(CFG, "p", "hybrid", "1"),
    "Hybrid mapping: keyboard IN ADDITION to the gamepad for Test / Service / Coin")
g.Add("Text", "xm+20 w170", "Keyboard keys:   Test")
eKeyT := g.Add("Edit", "x+4 w30 r1", IniRead(CFG, "p", "keytest", "T"))
g.Add("Text", "x+14 w50", "Service")
eKeyS := g.Add("Edit", "x+4 w30 r1", IniRead(CFG, "p", "keyservice", "S"))
g.Add("Text", "x+14 w40", "Coin")
eKeyC := g.Add("Edit", "x+4 w30 r1", IniRead(CFG, "p", "keycoin", "1"))

bApply := g.Add("Button", "xm y+14 w140 Default", "APPLY")
bApply.OnEvent("Click", (*) => Apply())
g.Add("Button", "x+8 w120", "Launch game").OnEvent("Click", (*) => Launch())
g.Add("Button", "x+8 w150", "Dolphin firewall").OnEvent("Click", (*) => Firewall())
g.Add("Button", "x+8 w130", "Force feedback").OnEvent("Click", (*) => FfbUi())
eLog := g.Add("Edit", "xm y+12 w580 r13 ReadOnly")

g.OnEvent("Close", (*) => ExitApp())

g.Show()
DetectMe()
Log("Ready. Fill in the paths and click APPLY on EACH PC.")
Log("IP address(es) of this PC: " MyIPs())
return

; ---- Automatic detection (full package: Dolphin-FZero\ and Game\ next to the script)
AutoDolphin() {
    d := A_ScriptDir "\Dolphin-FZero"
    return DolphinOk(d) ? d : ""
}

AutoGame() {
    Loop Files A_ScriptDir "\Game\*.*", "F" {
        if RegExMatch(A_LoopFileName, "i)\.(iso|gcm)$")
            return A_LoopFilePath
    }
    Loop Files A_ScriptDir "\Game\*", "D" {
        if FileExist(A_LoopFilePath "\sys\main.dol")
            return A_LoopFilePath
    }
    return ""
}

DolphinOk(p) {
    return FileExist(p "\Dolphin.exe") != ""
}

GameOk(p) {
    a := FileExist(p)
    return InStr(a, "D") ? FileExist(p "\sys\main.dol") != "" : a != ""
}

; Keep the saved path if it is still valid, otherwise use the detected one
PathOr(saved, auto, isValid) {
    if (saved != "" && isValid(saved))
        return saved
    return auto != "" ? auto : saved
}

; ============================== UI HELPERS ==================================
Log(msg) {
    eLog.Value := eLog.Value msg "`r`n"
    SendMessage(0x115, 7, 0, eLog)   ; WM_VSCROLL -> bottom
}

PickDir(ctrl) {
    d := DirSelect("*" ctrl.Value, 0, "Choose the folder")
    if (d != "")
        ctrl.Value := d
}

PickIso(ctrl) {
    f := FileSelect(1, ctrl.Value, "Choose the game image", "GameCube images (*.iso; *.gcm)")
    if (f != "")
        ctrl.Value := f
}

; IPv4 addresses of this PC (read from ipconfig)
MyIPList() {
    ips := []
    try {
        out := ComObject("WScript.Shell").Exec(A_ComSpec " /c ipconfig").StdOut.ReadAll()
        pos := 1
        while (pos := RegExMatch(out, "IPv4[^\r\n:]*:\s*(\d{1,3}(?:\.\d{1,3}){3})", &m, pos)) {
            ips.Push(m[1])
            pos += m.Len
        }
    }
    return ips
}

MyIPs() {
    txt := ""
    for ip in MyIPList()
        txt .= (txt = "" ? "" : "  ") ip
    return txt = "" ? "(none detected)" : txt
}

DetectMe() {
    mine := MyIPList()
    Loop 4 {
        ip := Trim(eIP[A_Index].Value)
        if (ip = "")
            continue
        for m in mine {
            if (m = ip) {
                ddlMe.Choose(A_Index)
                return
            }
        }
    }
}

SaveCfg() {
    IniWrite(eDol.Value, CFG, "p", "dolphin")
    IniWrite(eGame.Value, CFG, "p", "game")
    IniWrite(ddlMe.Value, CFG, "p", "me")
    IniWrite(ddlN.Value, CFG, "p", "links")
    IniWrite(cbReset.Value, CFG, "p", "reset")
    IniWrite(cbMotor.Value, CFG, "p", "motor")
    IniWrite(cbClean.Value, CFG, "p", "clean")
    IniWrite(cbHybrid.Value, CFG, "p", "hybrid")
    IniWrite(Trim(eKeyT.Value), CFG, "p", "keytest")
    IniWrite(Trim(eKeyS.Value), CFG, "p", "keyservice")
    IniWrite(Trim(eKeyC.Value), CFG, "p", "keycoin")
    Loop 4
        IniWrite(Trim(eIP[A_Index].Value), CFG, "p", "ip" A_Index)
}

; ============================== ACTIONS =====================================
Apply() {
    try {
        SaveCfg()
        dolDir := RTrim(eDol.Value, "\")
        gamePath := RTrim(eGame.Value, "\")
        number := ddlMe.Value - 1
        links := ddlN.Value + 1
        if !DolphinOk(dolDir)
            throw Error("Dolphin.exe not found in: " dolDir)
        if !GameOk(gamePath)
            throw Error("Game not found (ISO/GCM, or a folder containing sys\main.dol): " gamePath)
        if (number >= links)
            throw Error("The number of this cabinet (" number + 1 ") exceeds the number of cabinets (" links ").")
        ips := []
        Loop links {
            ip := Trim(eIP[A_Index].Value)
            if !RegExMatch(ip, "^\d{1,3}(\.\d{1,3}){3}$")
                throw Error("Invalid IP for cabinet " A_Index ": '" ip "'")
            ips.Push(ip)
        }

        ; 1) main.dol (inside the ISO, or in the extracted folder)
        what := PatchGame(gamePath, number, links, cbMotor.Value, cbClean.Value)
        Log("[OK] " what " patched: LINK NUM = " links ", NUMBER = " number " (Cabinet " number + 1 ")")
        Log("[OK] Motor check: " (cbMotor.Value ? "bypassed" : "original"))
        Log("[OK] Card reader cleaning: " (cbClean.Value ? "skipped" : "original"))

        ; 2) Dolphin configuration folders
        if FileExist(dolDir "\portable.txt")
            userDir := dolDir "\User"
        else
            userDir := EnvGet("APPDATA") "\Dolphin Emulator"
        cfgDir := userDir "\Config"
        triDir := userDir "\Triforce"
        DirCreate(cfgDir)
        DirCreate(triDir)

        ; 3) IP redirection table
        iniPath := cfgDir "\Dolphin.ini"
        text := FileExist(iniPath) ? FileRead(iniPath, "UTF-8-RAW") : ""
        existing := IniGet(text, "Core", "TriforceIPRedirections")
        text := IniSet(text, "Core", "TriforceIPRedirections", BuildRedirections(existing, ips))
        text := IniSet(text, "Analytics", "PermissionAsked", "True")
        WriteText(iniPath, text)
        Log("[OK] IP redirections written to " iniPath)
        for k, ip in ips
            Log("      192.168.11." k " -> " ip)

        ; 4) hybrid keyboard + gamepad mapping (Test / Service / Coin buttons)
        if cbHybrid.Value {
            padPath := cfgDir "\GCPadNew.ini"
            padText := FileExist(padPath) ? FileRead(padPath, "UTF-8-RAW") : DefaultPad()
            WriteText(padPath, HybridMap(padText, Trim(eKeyT.Value), Trim(eKeyS.Value), Trim(eKeyC.Value)))
            Log("[OK] Hybrid mapping written to " padPath " (Test=" Trim(eKeyT.Value) ", Service=" Trim(eKeyS.Value) ", Coin=" Trim(eKeyC.Value) ")")
        }

        ; 5) game save
        if cbReset.Value {
            n := 0
            Loop Files triDir "\tribackup_*.bin" {
                FileMove(A_LoopFilePath, A_LoopFilePath ".before_LAN_" A_Now, 1)
                n++
            }
            Log("[OK] Game save reset (" n " file(s) renamed)")
        }
        if !FileExist(triDir "\segaboot.gcm")
            Log("[!] segaboot.gcm not found in " triDir " (only needed for the test menus)")
        Log("DONE. Click 'Launch game' and run the calibration (arrows, W, Q, Enter).")
    } catch as err {
        Log("[ERROR] " err.Message)
    }
}

Launch() {
    try {
        SaveCfg()
        exe := RTrim(eDol.Value, "\") "\Dolphin.exe"
        game := RTrim(eGame.Value, "\")
        if !FileExist(exe)
            throw Error("Dolphin.exe not found.")
        if !GameOk(game)
            throw Error("Game not found.")
        if InStr(FileExist(game), "D")
            game .= "\sys\main.dol"
        Run('"' exe '" -e "' game '"', RTrim(eDol.Value, "\"))
        Log("Dolphin launched.")
    } catch as err {
        Log("[ERROR] " err.Message)
    }
}

Firewall() {
    try {
        exe := RTrim(eDol.Value, "\") "\Dolphin.exe"
        if !FileExist(exe)
            throw Error("Dolphin.exe not found.")
        bat := A_Temp "\fzero_fw.bat"
        try FileDelete(bat)
        f := FileOpen(bat, "w", "UTF-8-RAW")
        f.Write("@chcp 65001 >nul`r`n"
            . 'netsh advfirewall firewall delete rule name="Dolphin FZero LAN" >nul 2>&1' "`r`n"
            . 'netsh advfirewall firewall add rule name="Dolphin FZero LAN" dir=in action=allow program="' exe '" enable=yes profile=any' "`r`n"
            . 'netsh advfirewall firewall add rule name="Dolphin FZero LAN" dir=out action=allow program="' exe '" enable=yes profile=any' "`r`n"
            . "@pause`r`n")
        f.Close()
        Run('*RunAs "' bat '"')
        Log("Firewall rule requested (accept the UAC prompt).")
    } catch as err {
        Log("[ERROR] " err.Message)
    }
}

; Force feedback settings (bridge to vJoy / BackForceFeeder)
FfbUi() {
    exe := A_ScriptDir "\FFB\FFB_Settings.exe"
    if !FileExist(exe) {
        Log("[ERROR] FFB\FFB_Settings.exe not found.")
        return
    }
    Run('"' exe '"', A_ScriptDir "\FFB")
}

; ============================== GAME PATCH ==================================
; Patches main.dol: the sys\main.dol file of an extracted folder, or the main.dol inside an ISO/GCM image
; (offset read from the image header at 0x420; the size does not change, so it is modified in place).
; The original is kept once (.before_LAN). Returns "ISO" or "main.dol".
PatchGame(path, number, links, motorBypass := 0, cleanBypass := 0) {
    if InStr(FileExist(path), "D")
        path := RTrim(path, "\") "\sys\main.dol"
    if !FileExist(path)
        throw Error("File not found: " path)
    isDol := (StrLower(SubStr(path, -3)) = "dol")
    f := FileOpen(path, "rw")
    if !IsObject(f)
        throw Error("Cannot open for writing: " path "`r`n(read-only file, or in use by Dolphin?)")
    try {
        base := 0
        if isDol {
            if (f.Length != DOL_SIZE)
                throw Error("Unexpected main.dol size (" f.Length " bytes): this is not the F-Zero AX Rev E main.dol.")
        } else {
            base := DolOffsetInImage(f)
        }
        buf := Buffer(DOL_SIZE)
        f.Pos := base
        if (f.RawRead(buf, DOL_SIZE) != DOL_SIZE)
            throw Error("Incomplete read of main.dol.")
        if (DolHeaderSize(buf) != DOL_SIZE)
            throw Error("The main.dol found is not the F-Zero AX Rev E one (size " DolHeaderSize(buf) ").")
        PatchDolBuffer(buf, number, links, motorBypass, cleanBypass, &orig)
        bak := isDol ? path ".before_LAN" : path ".main.dol.before_LAN"
        if !FileExist(bak) {
            b := FileOpen(bak, "w")
            b.RawWrite(orig, DOL_SIZE)
            b.Close()
        }
        f.Pos := base
        f.RawWrite(buf, DOL_SIZE)
    } finally {
        f.Close()
    }
    return isDol ? "main.dol" : "ISO"
}

; Offset of main.dol inside an uncompressed GameCube/Triforce image
DolOffsetInImage(f) {
    hdr := Buffer(0x440)
    f.Pos := 0
    if (f.RawRead(hdr, 0x440) != 0x440)
        throw Error("File too small: this is not a game image.")
    if (ReadU32(hdr, 0x1C) != 0xC2339F3D)
        throw Error("This file is not an uncompressed ISO/GCM image (RVZ, WIA, GCZ, CISO are not supported).`r`n"
            . "In Dolphin: right-click the game > Properties > Convert File, format ISO.")
    if (StrGet(hdr, 3, "UTF-8") != "GFZ")
        throw Error("This image is not F-Zero AX (ID '" StrGet(hdr, 6, "UTF-8") "').")
    off := ReadU32(hdr, 0x420)
    if (off < 0x2440 || Mod(off, 4) != 0 || off + DOL_SIZE > f.Length)
        throw Error("Invalid main.dol offset in the image (" Format("0x{:X}", off) ").")
    return off
}

; Size of a DOL according to its header (end of the furthest section)
DolHeaderSize(buf) {
    last := 0
    Loop 18 {
        size := ReadU32(buf, 0x90 + 4 * (A_Index - 1))
        if size
            last := Max(last, ReadU32(buf, 4 * (A_Index - 1)) + size)
    }
    return last
}

; Replaces, in the 3 default-value blocks, the 3 instructions:
;   stb r4,2(r7) | stb r4,3(r7) | stb r4,4(r7)      (group, number, cabinets-1)
; Values available in registers: r4=0, r5=1, r6=2; r0 receives 3 when needed.
; Idempotent: can be replayed on an already patched DOL. 'orig' receives a copy of the buffer before changes.
PatchDolBuffer(buf, number, links, motorBypass, cleanBypass, &orig) {
    if (links < 2 || links > 4)
        throw Error("Invalid number of cabinets (2 to 4).")
    if (number < 0 || number >= links)
        throw Error("Invalid cabinet number.")
    orig := Buffer(buf.Size)
    DllCall("RtlMoveMemory", "Ptr", orig, "Ptr", buf, "UPtr", buf.Size)
    l1 := links - 1
    for off in DOL_BLOCKS {
        if (ReadU32(buf, off - 4) != 0x38800000 || ReadU32(buf, off + 12) != 0x3860005F)
            throw Error("Code context mismatch (block " Format("0x{:X}", off) "): unrecognised main.dol.")
        PutU32(buf, off,     0x98870002)
        PutU32(buf, off + 4, 0x98870003)
        PutU32(buf, off + 8, 0x98870004)
        needR0 := (l1 = 3 || number = 3)
        if needR0
            PutU32(buf, off, 0x38000003)                       ; li r0,3
        PutU32(buf, off + 4, number = 3 ? StbR7(0, 3) : StbR7(RegFor(number), 3))
        PutU32(buf, off + 8, l1 = 3 ? StbR7(0, 4) : StbR7(RegFor(l1), 4))
    }
    ; motor check
    w1 := ReadU32(buf, MOTOR_OFF), w2 := ReadU32(buf, MOTOR_OFF + 4)
    known := (w1 = MOTOR_ORIG[1] && w2 = MOTOR_ORIG[2]) || (w1 = MOTOR_SKIP[1] && w2 = MOTOR_SKIP[2])
    if !known
        throw Error("Code context mismatch (motor check): unrecognised main.dol.")
    pair := motorBypass ? MOTOR_SKIP : MOTOR_ORIG
    PutU32(buf, MOTOR_OFF, pair[1])
    PutU32(buf, MOTOR_OFF + 4, pair[2])
    ; card reader cleaning check
    wc := ReadU32(buf, CLEAN_OFF)
    if (wc != CLEAN_ORIG && wc != CLEAN_SKIP)
        throw Error("Code context mismatch (reader cleaning): unrecognised main.dol.")
    PutU32(buf, CLEAN_OFF, cleanBypass ? CLEAN_SKIP : CLEAN_ORIG)
}

; Default keyboard pad (port 1), used only if GCPadNew.ini does not exist yet.
DefaultPad() {
    return "[GCPad1]`n"
        . "Device = DInput/0/Keyboard Mouse`n"
        . "Buttons/A = ``X```n"
        . "Buttons/B = ``Z```n"
        . "Buttons/X = ``C```n"
        . "Buttons/Y = ``V```n"
        . "Buttons/Z = ``D```n"
        . "Buttons/Start = ``RETURN```n"
        . "Main Stick/Up = ``UP```n"
        . "Main Stick/Down = ``DOWN```n"
        . "Main Stick/Left = ``LEFT```n"
        . "Main Stick/Right = ``RIGHT```n"
        . "Triggers/L = ``Q```n"
        . "Triggers/R = ``W```n"
        . "D-Pad/Up = ``R```n"
        . "D-Pad/Down = ``G```n"
        . "D-Pad/Left = ``F```n"
        . "D-Pad/Right = ``H```n"
}

; ============================== HYBRID MAPPING ==============================
; For the Triforce Test / Service / Coin buttons of port 1, adds a keyboard input designated by its
; device ("DInput/0/Keyboard Mouse:T"): it works even when the default device is a gamepad
; (vJoy...). An existing expression (gamepad button) is kept, joined with "|" (OR).
HybridExpr(current, key) {
    key := Trim(key)
    if (key = "")
        return Trim(current)
    kb := "``DInput/0/Keyboard Mouse:" key "``"
    cur := Trim(current)
    if (cur = "")
        return kb
    if InStr(cur, "Keyboard Mouse:" key)
        return cur                              ; already hybrid
    bare := Trim(cur, "``")
    if (StrUpper(bare) = StrUpper(key))
        return kb                               ; old bare key: unusable when the default device is a gamepad
    return cur " | " kb
}

HybridMap(text, keyTest, keyService, keyCoin) {
    for pair in [["Triforce/Test", keyTest], ["Triforce/Service", keyService], ["Triforce/Coin", keyCoin]] {
        cur := IniGet(text, "GCPad1", pair[1])
        text := IniSet(text, "GCPad1", pair[1], HybridExpr(cur, pair[2]))
    }
    return text
}

RegFor(v) {            ; 0 -> r4, 1 -> r5, 2 -> r6
    return v = 0 ? 4 : (v = 1 ? 5 : 6)
}

StbR7(reg, disp) {     ; stb reg,disp(r7)
    return 0x98000000 | (reg << 21) | (7 << 16) | disp
}

ReadU32(buf, off) {
    return (NumGet(buf, off, "UChar") << 24) | (NumGet(buf, off + 1, "UChar") << 16)
         | (NumGet(buf, off + 2, "UChar") << 8) | NumGet(buf, off + 3, "UChar")
}

PutU32(buf, off, v) {
    NumPut("UChar", (v >> 24) & 0xFF, buf, off)
    NumPut("UChar", (v >> 16) & 0xFF, buf, off + 1)
    NumPut("UChar", (v >> 8) & 0xFF, buf, off + 2)
    NumPut("UChar", v & 0xFF, buf, off + 3)
}

; ============================== TEXT INI ====================================
DefaultEntries() {
    return [
        "192.168.29.150:5000-5008=127.0.0.1:5000-5008 MarioKart Seat #1 Static",
        "192.168.29.151:5000-5008=127.0.0.1:5010-5018 MarioKart Seat #2 Static",
        "192.168.29.152:5000-5008=127.0.0.1:5020-5028 MarioKart Seat #3 Static",
        "192.168.29.153:5000-5008=127.0.0.1:5030-5038 MarioKart Seat #4 Static",
        "192.168.29.150=127.0.0.1:50000-50999 MarioKart Seat #1 Ephemeral",
        "192.168.29.151=127.0.0.1:51000-51999 MarioKart Seat #2 Ephemeral",
        "192.168.29.152=127.0.0.1:52000-52999 MarioKart Seat #3 Ephemeral",
        "192.168.29.153=127.0.0.1:53000-53999 MarioKart Seat #4 Ephemeral",
        "192.168.29.104-107=127.0.0.1 MarioKart namcam2",
        "192.168.13.0/24=127.0.0.1 The Key of Avalon",
        "192.168.150.0/24=127.0.0.1 ALL.Net"
    ]
}

BuildRedirections(existing, ips) {
    entries := []
    if (Trim(existing) = "")
        entries := DefaultEntries()
    else
        for e in StrSplit(existing, ",") {
            e := Trim(e)
            ; drop everything covering 192.168.11.x (old setting, default CyCraft line)
            if (e != "" && !RegExMatch(e, "^192\.168\.11\."))
                entries.Push(e)
        }
    for k, ip in ips
        entries.Push("192.168.11." k "=" ip " Fzero" k)
    out := ""
    for e in entries
        out .= (out = "" ? "" : ",") e
    return out
}

SplitLines(text) {
    return StrSplit(StrReplace(text, "`r`n", "`n"), "`n")
}

JoinLines(lines) {
    out := ""
    for ln in lines
        out .= ln "`n"
    return RTrim(out, "`n") "`n"
}

IniGet(text, section, key) {
    lines := SplitLines(text)
    inSec := false
    for ln in lines {
        t := Trim(ln)
        if (SubStr(t, 1, 1) = "[") {
            inSec := (StrLower(t) = "[" StrLower(section) "]")
            continue
        }
        if (inSec && RegExMatch(ln, "i)^\s*" key "\s*=\s*(.*)$", &m))
            return RTrim(m[1], "`r")
    }
    return ""
}

IniSet(text, section, key, value) {
    lines := SplitLines(text)
    start := 0
    for i, ln in lines {
        if (StrLower(Trim(ln)) = "[" StrLower(section) "]") {
            start := i
            break
        }
    }
    if (!start) {
        while (lines.Length && Trim(lines[lines.Length]) = "")
            lines.Pop()
        if lines.Length
            lines.Push("")
        lines.Push("[" section "]")
        lines.Push(key " = " value)
        return JoinLines(lines)
    }
    stop := lines.Length + 1
    j := start + 1
    while (j <= lines.Length) {
        if (SubStr(Trim(lines[j]), 1, 1) = "[") {
            stop := j
            break
        }
        j++
    }
    j := start + 1
    while (j < stop) {
        if RegExMatch(lines[j], "i)^\s*" key "\s*=") {
            lines[j] := key " = " value
            return JoinLines(lines)
        }
        j++
    }
    lines.InsertAt(start + 1, key " = " value)
    return JoinLines(lines)
}

WriteText(path, text) {
    f := FileOpen(path, "w", "UTF-8-RAW")
    f.Write(text)
    f.Close()
}
