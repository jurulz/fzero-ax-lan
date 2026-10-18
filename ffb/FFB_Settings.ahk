#Requires AutoHotkey v2.0
#SingleInstance Force
; SPDX-License-Identifier: GPL-2.0-or-later
; Copyright (c) 2026 F-Zero AX LAN contributors
; ============================================================================
;  F-Zero AX force feedback: settings interface
;  Two modes:
;   - "Built into Dolphin" (default): Dolphin v8+ computes the force itself and sends it to the
;     force-feedback device (vJoy / BackForceFeeder, Logitech wheel...). This program only edits
;     <Dolphin>\User\Config\FZeroFFB.ini and shows the live state (FZeroFFB_status.txt).
;   - "External bridge": DolphinFFBBridge.exe (started and monitored here), settings in ffb_bridge.ini.
;  The sliders write the settings, which Dolphin / the bridge reload on the fly.
;  Orders (test / shock / toggle / quit) go through a *_cmd.txt file next to the settings.
; ============================================================================

global DIR := A_ScriptDir
global MODE_INI := DIR "\FFB_Settings.ini"
global INI := DIR "\ffb_bridge.ini"
global CMD := DIR "\ffb_cmd.txt"
global STATUS := DIR "\ffb_status.txt"
global BRIDGE := DIR "\DolphinFFBBridge.exe"
global DOLCFG := FindDolphinConfigDir()
global EMB_INI := DOLCFG "\FZeroFFB.ini"
global EMB_CMD := DOLCFG "\FZeroFFB_cmd.txt"
global EMB_STATUS := DOLCFG "\FZeroFFB_status.txt"
global mode := IniRead(MODE_INI, "ui", "mode", "embedded")
global bridgePid := 0
global lastText := ""

; Default values = the bridge's / Dolphin's own defaults
global DEF := Map("tcp_port", "8000", "device_name", "vJoy", "device_index", "-1", "axis", "0", "servo_scale", "50",
    "kp", "3.0", "kd", "0.12", "max_force", "0.35", "slew_per_cycle", "0.08", "curve", "1.0", "min_force", "0.0",
    "invert_force", "0", "invert_position", "0", "init_force", "0", "start_enabled", "1", "device", "")
global cur := ReadSettings()

; ============================== USER INTERFACE ==============================
g := Gui(, "F-Zero AX - Force feedback settings")
g.SetFont("s9", "Segoe UI")

; ---- left column: state, mode / bridge, devices
g.Add("GroupBox", "x10 y8 w560 h134", "State (middle of the bar = wheel centered)")
txtState := g.Add("Text", "x26 y30 w530 h22", "Starting...")
txtState.SetFont("s10 w700")
g.Add("Text", "x26 y62 w120", "Game target")
pTarget := g.Add("Progress", "x150 y63 w280 h14 Range0-100", 50)
tTarget := g.Add("Text", "x440 y62 w120", "0")
g.Add("Text", "x26 y86 w120", "Wheel position")
pPos := g.Add("Progress", "x150 y87 w280 h14 Range0-100", 50)
tPos := g.Add("Text", "x440 y86 w120", "0.00")
g.Add("Text", "x26 y110 w120", "Force sent")
pForce := g.Add("Progress", "x150 y111 w280 h14 Range0-100", 50)
tForce := g.Add("Text", "x440 y110 w120", "0.00")

g.Add("GroupBox", "x10 y148 w560 h134", "Force feedback")
bStart := g.Add("Button", "x26 y170 w125 h28", "Start bridge")
bStop := g.Add("Button", "x159 y170 w85 h28", "Stop")
bToggle := g.Add("Button", "x252 y170 w165 h28", "Cut force")
bTest := g.Add("Button", "x26 y206 w170 h28", "Test (gentle push)")
bShock := g.Add("Button", "x204 y206 w200 h28", "Shock test (max force)")
ddlMode := g.Add("DropDownList", "x26 y246 w250 Choose" (mode = "bridge" ? 2 : 1), ["Built into Dolphin (recommended)", "External bridge (DolphinFFBBridge)"])
cbSim := g.Add("Checkbox", "x286 y250", "Simulation")
cbTop := g.Add("Checkbox", "x380 y250", "Always on top")

g.Add("GroupBox", "x10 y290 w560 h126", "Devices")
g.Add("Text", "x26 y319 w100", "Bridge device:")
eDev := g.Add("Edit", "x126 y316 w130 r1", cur["device_name"])
g.Add("Text", "x270 y319 w30", "Axis")
ddlAxis := g.Add("DropDownList", "x300 y316 w60 Choose" (ClampInt(Num("axis", 0), 0, 5) + 1), ["X", "Y", "Z", "Rx", "Ry", "Rz"])
g.Add("Text", "x376 y319 w90", "Dolphin port")
eTcp := g.Add("Edit", "x470 y316 w70 r1 Number", cur["tcp_port"])
g.Add("Text", "x26 y349 w120", "Dolphin FFB device:")
eFfbDev := g.Add("Edit", "x150 y346 w390 r1", cur["device"])
DllCall("SendMessage", "Ptr", eFfbDev.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "empty = the device of GameCube pad 1")
bList := g.Add("Button", "x26 y380 w180 h28", "List devices")
bRestart := g.Add("Button", "x214 y380 w180 h28", "Restart bridge")

g.Add("Text", "x20 y422 w550 h60 cGray",
    "Wheel on vJoy: nothing to do. Another wheel (Logitech...): pick it as the device of pad 1 in Dolphin, or type "
    . "DInput/0/<its name> above, and set its rotation range to about 270-360 degrees in the wheel driver "
    . "(otherwise raise Target scale). Weak force? See the README.")

; ---- right column: settings
g.Add("GroupBox", "x580 y8 w560 h474", "Settings (applied immediately)")
g.Add("Text", "x596 y38 w90", "Presets:")
bSoft := g.Add("Button", "x690 y32 w70 h26", "Soft")
bMid := g.Add("Button", "x766 y32 w70 h26", "Medium")
bStrong := g.Add("Button", "x842 y32 w70 h26", "Strong")
bArcade := g.Add("Button", "x918 y32 w80 h26", "Arcade")
g.Add("Text", "x596 y64 w530 cGray", "Strong and Arcade: hold the wheel firmly.")

g.Add("Text", "x596 y96 w190", "Max force")
sMax := g.Add("Slider", "x790 y90 w270 h28 Range0-100 TickInterval10", ClampInt(Num("max_force", 0.35) * 100, 0, 100))
tMax := g.Add("Text", "x1068 y96 w64")
g.Add("Text", "x596 y130 w190", "Stiffness (pulls to target)")
sKp := g.Add("Slider", "x790 y124 w270 h28 Range0-300 TickInterval30", ClampInt(Num("kp", 3) * 10, 0, 300))
tKp := g.Add("Text", "x1068 y130 w64")
g.Add("Text", "x596 y164 w190", "Damping")
sKd := g.Add("Slider", "x790 y158 w270 h28 Range0-100 TickInterval10", ClampInt(Num("kd", 0.12) * 100, 0, 100))
tKd := g.Add("Text", "x1068 y164 w64")
g.Add("Text", "x596 y198 w190", "Shake sharpness")
sSlew := g.Add("Slider", "x790 y192 w270 h28 Range1-50 TickInterval5", ClampInt(Num("slew_per_cycle", 0.08) * 100, 1, 50))
tSlew := g.Add("Text", "x1068 y198 w64")
g.Add("Text", "x596 y232 w190", "Target scale")
sScale := g.Add("Slider", "x790 y226 w270 h28 Range20-300 TickInterval20", ClampInt(Num("servo_scale", 50), 20, 300))
tScale := g.Add("Text", "x1068 y232 w64")
g.Add("Text", "x596 y266 w190", "Small-force sensitivity")
sCurve := g.Add("Slider", "x790 y260 w270 h28 Range20-100 TickInterval10", ClampInt(Num("curve", 1) * 100, 20, 100))
tCurve := g.Add("Text", "x1068 y266 w64")
g.Add("Text", "x596 y300 w190", "Minimum force")
sMin := g.Add("Slider", "x790 y294 w270 h28 Range0-50 TickInterval5", ClampInt(Num("min_force", 0) * 100, 0, 50))
tMin := g.Add("Text", "x1068 y300 w64")

cbInvF := g.Add("Checkbox", "x596 y336 w530 Checked" (cur["invert_force"] = "1"), "Invert force direction (if the wheel is pushed the wrong way)")
cbInvP := g.Add("Checkbox", "x596 y360 w530 Checked" (cur["invert_position"] = "1"), "Invert wheel axis")
cbInit := g.Add("Checkbox", "x596 y384 w530 Checked" (cur["init_force"] = "1"), "Also apply during initialization (the wheel sweeps its whole travel)")
g.Add("Text", "x596 y412 w530 h60 cGray",
    "Max force: ceiling. Stiffness: higher = pulled harder toward the game's target. Sensitivity: lower = small forces are amplified. "
    . "Minimum force: minimum power as soon as there is an order (overcomes motor friction). Target scale: game value = end stop "
    . "(50 for the arcade wheel).")

bStart.OnEvent("Click", (*) => StartBridge())
bStop.OnEvent("Click", (*) => StopBridge())
bTest.OnEvent("Click", (*) => SendCmd("test"))
bShock.OnEvent("Click", (*) => SendCmd("shock"))
bToggle.OnEvent("Click", (*) => SendCmd("toggle"))
ddlMode.OnEvent("Change", (*) => OnMode())
cbTop.OnEvent("Click", (*) => g.Opt((cbTop.Value ? "+" : "-") "AlwaysOnTop"))
bSoft.OnEvent("Click", (*) => Preset(35, 3.0, 0.12, 0.08, 1.0, 0))
bMid.OnEvent("Click", (*) => Preset(60, 5.0, 0.15, 0.15, 0.85, 0.05))
bStrong.OnEvent("Click", (*) => Preset(85, 8.0, 0.20, 0.25, 0.70, 0.10))
bArcade.OnEvent("Click", (*) => Preset(100, 15.0, 0.15, 0.50, 0.60, 0.15))
for c in [sMax, sKp, sKd, sSlew, sScale, sCurve, sMin]
    c.OnEvent("Change", (*) => Changed())
for c in [cbInvF, cbInvP, cbInit]
    c.OnEvent("Click", (*) => Changed())
for c in [eDev, eTcp, eFfbDev]
    c.OnEvent("Change", (*) => Changed())
ddlAxis.OnEvent("Change", (*) => Changed())
bList.OnEvent("Click", (*) => ListDevices())
bRestart.OnEvent("Click", (*) => RestartBridge())
g.OnEvent("Close", (*) => Quit())

UpdateLabels()
SaveNow()
g.Show("w1150 h496")
if (mode = "bridge")
    StartBridge()
else
    SilenceBridge()
SetTimer(Tick, 150)
return

; ============================== SETTINGS ====================================
ClampInt(v, lo, hi) {
    return Max(lo, Min(hi, Round(v)))
}

Num(key, default) {
    v := cur[key]
    return IsNumber(v) ? Number(v) : default
}

; Dolphin's Config folder (portable package next to this one, otherwise the user profile)
FindDolphinConfigDir() {
    portable := DIR "\..\Dolphin-FZero"
    if FileExist(portable "\portable.txt")
        return portable "\User\Config"
    pcfg := DIR "\..\FZeroLAN.ini"
    if FileExist(pcfg) {
        d := RTrim(IniRead(pcfg, "p", "dolphin", ""), "\")
        if (d != "" && FileExist(d "\portable.txt"))
            return d "\User\Config"
    }
    return EnvGet("APPDATA") "\Dolphin Emulator\Config"
}

ReadSettings() {
    s := Map()
    for k, v in DEF
        s[k] := v
    for path in [INI, EMB_INI] {
        if FileExist(path) {
            try {
                for ln in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
                    if RegExMatch(ln, "^\s*([A-Za-z_]+)\s*=\s*([^#]*?)\s*(?:#.*)?$", &m) && s.Has(StrLower(m[1]))
                        s[StrLower(m[1])] := m[2]
                }
            }
        }
    }
    return s
}

UpdateLabels() {
    tMax.Value := sMax.Value " %"
    tKp.Value := Format("{:.1f}", sKp.Value / 10)
    tKd.Value := Format("{:.2f}", sKd.Value / 100)
    tSlew.Value := Format("{:.2f}", sSlew.Value / 100)
    tScale.Value := sScale.Value
    tCurve.Value := Format("{:.2f}", sCurve.Value / 100) (sCurve.Value = 100 ? " (linear)" : "")
    tMin.Value := sMin.Value " %"
}

Changed() {
    UpdateLabels()
    SetTimer(SaveNow, -250)
}

Preset(maxPct, kp, kd, slew, curve, minForce) {
    sMax.Value := maxPct
    sKp.Value := Round(kp * 10)
    sKd.Value := Round(kd * 100)
    sSlew.Value := Round(slew * 100)
    sCurve.Value := Round(curve * 100)
    sMin.Value := Round(minForce * 100)
    Changed()
}

WriteFile(path, text) {
    try {
        tmp := path ".tmp"
        f := FileOpen(tmp, "w", "UTF-8-RAW")
        f.Write(text)
        f.Close()
        FileMove(tmp, path, 1)
    }
}

; Writes the settings (temporary file then replace: nobody ever reads a half-written file).
; ffb_bridge.ini is used by the external bridge, FZeroFFB.ini by Dolphin; "enabled" tells which one is active.
SaveNow() {
    lines := ["# Force feedback settings (written by FFB_Settings). Decimal point notation.",
        "tcp_port = " (Trim(eTcp.Value) = "" ? "8000" : Trim(eTcp.Value)),
        "device_name = " Trim(eDev.Value),
        "device_index = " cur["device_index"],
        "axis = " (ddlAxis.Value - 1),
        "servo_scale = " sScale.Value,
        "kp = " Format("{:.1f}", sKp.Value / 10),
        "kd = " Format("{:.2f}", sKd.Value / 100),
        "max_force = " Format("{:.2f}", sMax.Value / 100),
        "slew_per_cycle = " Format("{:.2f}", sSlew.Value / 100),
        "curve = " Format("{:.2f}", sCurve.Value / 100),
        "min_force = " Format("{:.2f}", sMin.Value / 100),
        "invert_force = " cbInvF.Value,
        "invert_position = " cbInvP.Value,
        "init_force = " cbInit.Value,
        "start_enabled = " cur["start_enabled"]]
    text := ""
    for ln in lines
        text .= ln "`r`n"
    WriteFile(INI, text)
    try DirCreate(DOLCFG)
    WriteFile(EMB_INI, text "enabled = " (mode = "embedded" ? 1 : 0) "`r`n"
        . "device = " Trim(eFfbDev.Value) "`r`n"
        . "output = Constant`r`n")
}

OnMode() {
    global mode
    mode := (ddlMode.Value = 2) ? "bridge" : "embedded"
    IniWrite(mode, MODE_INI, "ui", "mode")
    if (mode = "embedded")
        StopBridge()
    SaveNow()
    if (mode = "bridge")
        StartBridge()
    lastTextReset()
}

lastTextReset() {
    global lastText
    lastText := ""
}

; ============================== COMMUNICATION ===============================
CmdPath() {
    return (mode = "embedded") ? EMB_CMD : CMD
}

StatusPath() {
    return (mode = "embedded") ? EMB_STATUS : STATUS
}

SendCmd(word) {
    try FileAppend(word "`n", CmdPath(), "UTF-8-RAW")
}

ReadStatusFile(path) {
    if !FileExist(path)
        return ""
    m := Map()
    try {
        age := DateDiff(A_Now, FileGetTime(path, "M"), "Seconds")
        for ln in StrSplit(FileRead(path), "`n", "`r") {
            if RegExMatch(ln, "^(\w+)=(.*)$", &r)
                m[r[1]] := r[2]
        }
    } catch {
        return ""
    }
    m["age"] := age
    return m
}

ReadStatus() {
    return ReadStatusFile(StatusPath())
}

StatusAlive(st := unset) {
    if !IsSet(st)
        st := ReadStatus()
    return (st != "" && st.Has("alive") && st["alive"] = "1" && st["age"] <= 2)
}

OwnProcessRunning() {
    return bridgePid && ProcessExist(bridgePid)
}

; ============================== EXTERNAL BRIDGE =============================
StartBridge() {
    global bridgePid
    if (mode != "bridge")
        return
    if (StatusAlive() || OwnProcessRunning())
        return
    if !FileExist(BRIDGE) {
        MsgBox("DolphinFFBBridge.exe was not found in:`n" DIR, "Force feedback", 0x10)
        return
    }
    SaveNow()
    try FileDelete(STATUS)
    try FileDelete(CMD)
    Run('"' BRIDGE '"' (cbSim.Value ? " --dry --keep" : ""), DIR, "Hide", &pid)
    bridgePid := pid
}

StopBridge() {
    global bridgePid
    ; the bridge always listens to its own order file, whatever the current mode
    try FileAppend("quit`n", CMD, "UTF-8-RAW")
    Loop 25 {
        st := ReadStatusFile(STATUS)
        alive := (st != "" && st.Has("alive") && st["alive"] = "1" && st["age"] <= 2)
        if !(alive || OwnProcessRunning())
            break
        Sleep(100)
    }
    if OwnProcessRunning()
        ProcessClose(bridgePid)
    bridgePid := 0
}

; In built-in mode, make sure no external bridge left over from a previous session is still pushing the wheel
SilenceBridge() {
    st := ReadStatusFile(STATUS)
    if (st != "" && st.Has("alive") && st["alive"] = "1" && st["age"] <= 2)
        try FileAppend("quit`n", CMD, "UTF-8-RAW")
}

RestartBridge() {
    if (mode != "bridge")
        return
    SaveNow()
    StopBridge()
    Sleep(300)
    StartBridge()
}

ListDevices() {
    if !FileExist(BRIDGE) {
        MsgBox("DolphinFFBBridge.exe was not found.", "Force feedback", 0x10)
        return
    }
    try {
        out := ComObject("WScript.Shell").Exec('"' BRIDGE '" --list').StdOut.ReadAll()
        MsgBox(out "`nIn Dolphin, a device is written DInput/0/<name> (see the device list of the pad 1 window).", "Game devices", 0x40)
    } catch as err {
        MsgBox("Unable to list the devices:`n" err.Message, "Force feedback", 0x10)
    }
}

Quit() {
    SetTimer(Tick, 0)
    if bridgePid
        StopBridge()
    ExitApp()
}

; ============================== LIVE STATE ==================================
SetState(text, color) {
    global lastText
    if (text = lastText)
        return
    lastText := text
    txtState.Value := text
    txtState.SetFont("c" color)
}

Tick() {
    st := ReadStatus()
    alive := StatusAlive(st)
    emb := (mode = "embedded")
    running := alive || OwnProcessRunning()
    bStart.Enabled := !emb && !running
    bStop.Enabled := !emb && running
    bRestart.Enabled := !emb
    cbSim.Enabled := !emb
    bTest.Enabled := alive
    bShock.Enabled := alive
    bToggle.Enabled := alive

    if alive {
        servo := IsNumber(st["servo"]) ? Number(st["servo"]) : 0
        pos := IsNumber(st["pos"]) ? Number(st["pos"]) : 0
        force := IsNumber(st["force"]) ? Number(st["force"]) : 0
        peak := (st.Has("peak") && IsNumber(st["peak"])) ? Number(st["peak"]) : 0
        scale := Max(1, sScale.Value)
        pTarget.Value := Round(50 + 50 * Max(-1, Min(1, servo / scale)))
        pPos.Value := Round(50 + 50 * Max(-1, Min(1, pos)))
        pForce.Value := Round(50 + 50 * Max(-1, Min(1, force)))
        tTarget.Value := servo
        tPos.Value := Format("{:.2f}", pos)
        tForce.Value := Format("{:.2f}", force) "  (peak " Format("{:.2f}", peak) ")"
        bToggle.Text := (st["enabled"] = "1") ? "Cut force" : "Restore force"
        if (emb && st.Has("device") && st["device"] = "0") {
            nm := st.Has("device_name") ? st["device_name"] : ""
            SetState("No force feedback device found" (nm != "" ? ": " nm : " (set it in 'Dolphin FFB device')"), "C00000")
            return
        }
        switch Integer(st["state"]) {
            case 0: SetState("Dolphin not connected (start the game)", "B06000")
            case 1: SetState(emb ? "Waiting for the game (no data from the arcade board)" : "Game stopped", "808080")
            case 2: SetState("Wheel initializing (force off)", "B06000")
            case 3: SetState("Motor off by the game (normal on the title screen)", "808080")
            case 4: SetState("FORCE ACTIVE", "008000")
            case 5: SetState("Force cut by you", "C00000")
            case 6: SetState("TEST running", "0050C0")
            case 7: SetState("Built-in force feedback is off (external bridge mode)", "808080")
        }
        return
    }
    pTarget.Value := 50
    pPos.Value := 50
    pForce.Value := 50
    tTarget.Value := "0"
    tPos.Value := "0.00"
    tForce.Value := "0.00"
    bToggle.Text := "Cut force"
    if emb
        SetState("Waiting for Dolphin (start the game): built-in force feedback is ready", "808080")
    else if OwnProcessRunning()
        SetState("Starting the bridge...", "808080")
    else if (st != "" && st.Has("error"))
        SetState(st["error"], "C00000")
    else
        SetState("Bridge stopped (click Start bridge)", "808080")
}
