#Requires AutoHotkey v2.0
#SingleInstance Force
; Win+Shift+U: upload the clipboard image to the Mac mini, path goes to clipboard.
; shot.ps1 must sit next to this file.

#+u:: {
    ps1 := A_ScriptDir "\shot.ps1"
    Run('powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' ps1 '" -Quiet', , "Hide")
}
