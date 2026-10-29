# shot.ps1: upload the clipboard image (or a PNG file) to the Mac mini's ~/screenshots
# and put the remote path on the clipboard.
#   shot.ps1               upload clipboard image
#   shot.ps1 C:\x.png      upload a file
#   shot.ps1 -Quiet        no console output (used by the hotkey)
param([string]$File = "", [switch]$Quiet)

$ErrorActionPreference = "Stop"
$Key      = if ($env:SHOT_KEY)  { $env:SHOT_KEY }  else { Join-Path $env:USERPROFILE ".ssh\screenshot_drop_ed25519" }
$Ssh      = Join-Path $env:WINDIR "System32\OpenSSH\ssh.exe"
if (-not (Test-Path $Ssh)) { $Ssh = "ssh.exe" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Notify([string]$Title, [string]$Text = "") {
    # Small balloon that disappears after ~2 s.
    try {
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.Visible = $true
        $n.ShowBalloonTip(2000, $Title, $(if ($Text) { $Text } else { " " }), "None")
        Start-Sleep -Milliseconds 2200
        $n.Dispose()
    } catch {}
}
function Fail([string]$Msg) {
    if (-not $Quiet) { Write-Host "shot: $Msg" -ForegroundColor Red }
    Notify "Upload failed" $Msg
    exit 1
}

# The upload host (user@host) comes from SHOT_HOST or, for the hotkey, from the
# first non-comment line of the config file. The repo is public, so it ships no default.
$Config = Join-Path $env:APPDATA "screenshot-drop\host"
$HostName = $env:SHOT_HOST
if (-not $HostName -and (Test-Path $Config)) {
    $HostName = Get-Content $Config | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") } | Select-Object -First 1
}
if (-not $HostName) { Fail "no upload host: set SHOT_HOST=user@host or write it to $Config" }
$HostName = $HostName.Trim()
if ($HostName -notmatch '^[A-Za-z0-9._@:-]+$' -or $HostName.StartsWith("-")) { Fail "bad upload host: $HostName" }

$tmp = Join-Path $env:TEMP ("shot-" + [guid]::NewGuid().ToString("N") + ".png")
try {
    if ($File) {
        if (-not (Test-Path $File)) { Fail "no such file: $File" }
        Copy-Item $File $tmp
    } else {
        $img = [System.Windows.Forms.Clipboard]::GetImage()
        if ($null -eq $img) { Fail "no image on clipboard" }
        $img.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose()
    }
    if ((Get-Item $tmp).Length -eq 0) { Fail "image is empty" }
    if (-not (Test-Path $Key)) { Fail "key missing: $Key (run install.ps1)" }

    # Pipe the file through cmd.exe: PowerShell 5.1 pipes corrupt binary data.
    $cmdLine = "`"$Ssh`" -i `"$Key`" -o IdentitiesOnly=yes -o BatchMode=yes " +
               "-o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $HostName < `"$tmp`" 2>&1"
    $out = & cmd.exe /d /c $cmdLine
    $rc = $LASTEXITCODE
    $remote = $out | Where-Object { $_ -match '^/Users/.*\.png$' } | Select-Object -First 1
    if ($rc -ne 0 -or -not $remote) {
        $err = ($out | Where-Object { $_ -notmatch 'Pseudo-terminal' } | Select-Object -Last 1)
        Fail "$err"
    }

    [System.Windows.Forms.Clipboard]::SetText($remote.Trim())
    if (-not $Quiet) { Write-Host $remote }
    Notify "Uploaded, path copied"
} finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}
