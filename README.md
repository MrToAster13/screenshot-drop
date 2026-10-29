# screenshot-drop

Send screenshots from a laptop to the Mac mini so Hermes can look at them.

Press a hotkey. The image on your clipboard is uploaded over SSH (through Tailscale) to
`~/screenshots/` on the Mac mini (`/Users/<user>/screenshots/`), and the remote path replaces your clipboard.
Paste that path into the Hermes chat. A small notification confirms success or shows the error.

- CachyOS (Hyprland + Noctalia): `Print` → annotate in satty → `Ctrl+C` → `Super+Shift+U`
- Windows: `Win+Shift+S` → `Win+Shift+U`
- Terminal on either OS: `shot` (clipboard) or `shot file.png`

Files are named `YYYY-MM-DD_HHMMSS-<cachy|win>.png`. Files older than 30 days are deleted on each upload.

## Security model

Each OS has its own upload key without a passphrase (`~/.ssh/screenshot_drop_ed25519`), so the
hotkey never prompts. On the Mac mini the key is listed in `authorized_keys` with
`restrict,command="…/screenshot-receive <tag>"`: it cannot open a shell, run commands, or forward
ports. All it can do is store one PNG (max 50 MB) in `~/screenshots`. Remove the line from
`authorized_keys` to revoke a machine.

The receiver is [`mac/screenshot-receive`](mac/screenshot-receive). It checks the PNG signature
and the 50 MB limit, names the file, and deletes PNGs in `~/screenshots` older than 30 days.
`tests/test_receive.sh` covers those rules. To deploy it on the Mac mini:

```bash
install -m 755 mac/screenshot-receive ~/.hermes/bin/screenshot-receive
```

Before replacing a running copy, compare it with `diff ~/.hermes/bin/screenshot-receive
mac/screenshot-receive`.

## Before you start (both OSes)

1. Tailscale installed and logged in on this OS (dual-boot = each OS is its own Tailscale device).
2. MagicDNS on. Check: `ping <mac-host>`, where `<mac-host>` is the Mac mini's MagicDNS name.
3. The upload host, written as `<user>@<mac-host>`. Hermes knows it. The repo is public, so the
   scripts ship no default. They read it from `SHOT_HOST` or from a one-line config file:
   - CachyOS: `~/.config/screenshot-drop/host`
   - Windows: `%APPDATA%\screenshot-drop\host`

   The installers write that file when you run them with `SHOT_HOST` set. Lines starting with `#`
   are ignored.

## CachyOS setup

```bash
git clone https://github.com/MrToAster13/screenshot-drop ~/screenshot-drop
SHOT_HOST='<user>@<mac-host>' ~/screenshot-drop/linux/install.sh
```

The installer checks for `wl-clipboard` and `libnotify`, installs `shot` to `~/.local/bin`
(adds it to fish's PATH), creates the upload key, and prints:

- the public key: send it to Hermes
- the line to add to `~/.config/hypr/config/binds.lua`:

```lua
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/shot"))
```

Optional: if you would rather skip satty, set Noctalia settings (Super+Z) → shell → screenshot
→ copy to clipboard.

## Windows setup

1. Install AutoHotkey v2: `winget install AutoHotkey.AutoHotkey`
2. Clone and install:

```powershell
git clone https://github.com/MrToAster13/screenshot-drop $HOME\screenshot-drop
$env:SHOT_HOST = '<user>@<mac-host>'
powershell -ExecutionPolicy Bypass -File $HOME\screenshot-drop\windows\install.ps1
```

The installer creates the upload key, adds a `shot` function to your PowerShell profile, starts the
`Win+Shift+U` hotkey and adds it to Startup. Send the printed public key to Hermes.

## Updating

`git pull` in the clone. On CachyOS re-run `linux/install.sh` to copy the new `shot`.

Installs from before the host moved out of the scripts stop with "no upload host". Re-run the
installer with `SHOT_HOST` set, or write the config file by hand.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "no upload host" | Write `<user>@<mac-host>` to the config file, see "Before you start". |
| "no image on clipboard" | Copy the image first (satty: Ctrl+C). |
| "Permission denied (publickey)" | Key not added on the Mac mini yet. Send the `.pub` to Hermes. |
| "Could not resolve hostname" | Tailscale off or MagicDNS off on this OS. |
| Hotkey does nothing (CachyOS) | Run `shot` in a terminal to see the error; reload Hyprland after editing binds.lua. |
| Hotkey does nothing (Windows) | Check the AutoHotkey tray icon; run `shot` in PowerShell to see the error. |

## Tests

`bash tests/run.sh` runs every `tests/test_*.sh` with bash and the standard Unix tools, no other
dependencies. `tests/test_shot_ps1.sh` runs `windows/shot.ps1` when Windows PowerShell or pwsh is
on PATH, as in Git Bash on Windows, and skips otherwise. Without PowerShell, `shot.ps1` gets only
the static checks in `tests/test_no_host_default.sh`.
