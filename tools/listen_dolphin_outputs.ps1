# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2026 F-Zero AX LAN contributors
# Listens to Dolphin's outputs (lamps + wheel) on 127.0.0.1:8000 and records them with a timestamp.
# Usage: right-click > Run with PowerShell (or: powershell -ExecutionPolicy Bypass -File listen_dolphin_outputs.ps1)
# Start it before or after Dolphin and the game, it does not matter. Stop with Ctrl+C.
# Files written (next to the script, new lines are APPENDED to existing files):
#   dolphin_outputs_all.txt    = everything
#   dolphin_outputs_useful.txt = everything EXCEPT the LampStart blinking
#   dolphin_outputs_wheel.txt  = ONLY the wheel commands other than the target position
#                                (WheelCmd<N>, WheelCnt<N>, WheelInit): the file to look at to search
#                                for unknown effects (boost shake, off-road, hits...)
param(
    [int]$Port = 8000,
    [int]$Seconds = 3600,
    [string]$Out = (Join-Path $PSScriptRoot "dolphin_outputs_all.txt"),
    [string]$OutUseful = (Join-Path $PSScriptRoot "dolphin_outputs_useful.txt"),
    [string]$OutWheel = (Join-Path $PSScriptRoot "dolphin_outputs_wheel.txt")
)

$start = Get-Date
"Listening to Dolphin on 127.0.0.1:$Port ... (Ctrl+C to stop)"
"  everything         : $Out"
"  without LampStart  : $OutUseful"
"  wheel (other cmds) : $OutWheel"
while (((Get-Date) - $start).TotalSeconds -lt $Seconds) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect("127.0.0.1", $Port)
    } catch {
        $client.Close()
        Start-Sleep -Seconds 1
        continue
    }
    "Connected to Dolphin."
    $reader = New-Object System.IO.StreamReader($client.GetStream())
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.Length -eq 0) { continue }
            $text = "{0} {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $line
            Add-Content -Path $Out -Value $text
            if ($line -notmatch '^LampStart ') {
                Add-Content -Path $OutUseful -Value $text
            }
            if ($line -match '^(WheelCnt\d+|WheelInit|WheelCmd(?!4 )\d+) ') {
                $text
                Add-Content -Path $OutWheel -Value $text
            }
        }
    } catch {
        # connection lost: try again
    }
    $client.Close()
    "Disconnected, trying again..."
}
