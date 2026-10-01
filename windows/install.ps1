# One-time setup for Windows. Run in PowerShell from this folder:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. OpenSSH client
$ssh = Join-Path $env:WINDIR "System32\OpenSSH\ssh.exe"
if (-not (Test-Path $ssh)) {
    Write-Host "OpenSSH client missing. Install it (admin PowerShell):" -ForegroundColor Yellow
    Write-Host "  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
    exit 1
}

# 2. Upload key (no passphrase; the Mac locks it to PNG upload only)
$sshDir = Join-Path $env:USERPROFILE ".ssh"
$key = Join-Path $sshDir "screenshot_drop_ed25519"
if (-not (Test-Path $key)) {
    New-Item -ItemType Directory -Force $sshDir | Out-Null
    & cmd.exe /d /c "`"$(Join-Path $env:WINDIR 'System32\OpenSSH\ssh-keygen.exe')`" -q -t ed25519 -N `"`" -C screenshot-drop-win -f `"$key`""
    Write-Host "Created upload key $key"
}

# 3. 'shot' function in the PowerShell profile
$line = "function shot { powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File `"$here\shot.ps1`" @args }"
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force $PROFILE | Out-Null }
if (-not (Select-String -Path $PROFILE -SimpleMatch "shot.ps1" -Quiet)) {
    Add-Content $PROFILE "`n$line"
    Write-Host "Added 'shot' to $PROFILE"
}

# 4. AutoHotkey hotkey at login
$ahkExe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahkExe) {
    Write-Host "AutoHotkey v2 not found. Install it:  winget install AutoHotkey.AutoHotkey" -ForegroundColor Yellow
    Write-Host "Then run this script again."
} else {
    $startup = [Environment]::GetFolderPath("Startup")
    $lnk = Join-Path $startup "screenshot-drop.lnk"
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = $ahkExe
    $s.Arguments = "`"$here\shot.ahk`""
    $s.WorkingDirectory = $here
    $s.Save()
    Start-Process $ahkExe "`"$here\shot.ahk`""
    Write-Host "Hotkey Win+Shift+U active and set to start at login."
}

Write-Host ""
Write-Host "Send this public key to Hermes (one line):" -ForegroundColor Cyan
Get-Content "$key.pub"
