# island

A dynamic-island style shell for Wayland, built on [Quickshell](https://quickshell.org).
It lives at the top of the screen and grows into whatever you need:

- **Island**: clock + battery icon, now playing, track-change peek, volume / brightness OSD, notifications
- **Control center**: Wi-Fi / Bluetooth / Focus / Awake tiles, sound + display sliders, notification history
- **Power menu**: lock, log out, sleep, restart, shut down (with confirmation)
- **Launcher**: fuzzy app search with usage ranking
- **Clipboard**: searchable history (cliphist)
- **Emoji + symbols**: searchable picker with categories, recents, and math / arrows / currency / Greek
- **Calendar**: month view with week numbers, day-of-year and "in N days"
- **Tray**: StatusNotifier icons; right-click menus open inside the island
- **Wallpapers**: endless horizontal strip, plus live matugen controls (scheme, contrast, accent)

Hover the island to expand it. Everything is also reachable through IPC and keybinds.

---

## 0. Project layout

```
island/
├── shell.qml               entry point: one Island per screen + IPC
├── settings.json           all user settings (hot-reloaded)
├── config/                 Config (reads settings.json), Theme (matugen colours)
├── services/               state + system access, no UI: Apps, Clip, Clock, Controls,
│                           Media, Notifs, Osd, Power, Ui, Wallpapers, Emoji, EmojiData
├── components/             reusable bits: Txt, Icon, IconButton, Toggle, VSlider,
│                           Marquee, Art, Equalizer, View, PillToggle, HSlider, Battery, Tile, LineSlider, VSlider
├── modules/island/
│   ├── Island.qml          the window: state, timers, the morphing pill
│   └── views/              one file per thing the pill can show:
│       Idle, Media, Peek, Osd, Notif, Hub, Player,
│       Center, Power, Wallpaper, Launcher, Clipboard, Emoji, Calendar, Tray
├── ipc/                    one IPC target per file (island, launcher, clipboard, emoji, calendar, tray, center, power, wallpaper)
├── contrib/                matugen colour template
├── nix/ flake.nix package.nix   Nix packaging + NixOS / Home Manager modules
```

Adding a feature: put its logic in `services/`, its UI in a new `views/XView.qml`
(copy a small one like `OsdView.qml`), add it to `Island.qml`'s view list and
`sizes` table, and give it an IPC file if you want a keybind.

---

## 1. Install

### Nix / NixOS (recommended)

Add the flake (files must be tracked by git for flakes to see them):

```nix
inputs.island.url = "github:h4shcore/island";        # or "path:/home/you/Projects/island"
inputs.island.inputs.nixpkgs.follows = "nixpkgs";
```

**Home Manager**

```nix
imports = [ inputs.island.homeManagerModules.default ];

programs.island = {
  enable = true;
  settings = {
    wallpapers.dir = "~/Pictures/Wallpapers";
    launcher.terminal = [ "kitty" ];
    clipboard.watch = true;       # island runs the cliphist watchers for you
  };
};
```

**NixOS**

```nix
imports = [ inputs.island.nixosModules.default ];
programs.island.enable = true;     # same options as above
```

The module installs the `island` command, the fonts (Inter + Material Symbols),
and puts the runtime tools on its PATH: brightnessctl, nmcli, loginctl, cliphist,
wl-clipboard, matugen and **awww** (the swww successor, added via `extraPackages`).
The NixOS module also enables upower, installs brightnessctl's udev rules and warns
if NetworkManager or PipeWire are off.

Other useful options: `quickshellPackage` (use the quickshell flake), `extraPackages`,
`extraSettings` (raw settings.json for keys without an option), `installFonts`,
`systemd.enable` (see the note below).

### Without Nix

Install: `quickshell`, `brightnessctl`, `networkmanager`, `cliphist`, `wl-clipboard`,
`matugen`, `awww`, the fonts **Inter** and **Material Symbols Rounded**, plus PipeWire,
UPower and BlueZ for the sliders / battery / Bluetooth. Then:

```
git clone <repo> ~/.config/quickshell/island
qs -c island          # or: qs -p ~/.config/quickshell/island
```

---

## 2. First-run setup (do this once)

**a) Colours.** The shell reads `~/.config/quickshell/colors.json`, which matugen writes.
Add a template to `~/.config/matugen/config.toml`:

```toml
[templates.island]
input_path  = "~/.config/quickshell/island/contrib/quickshell-colors.json"   # Nix: config.programs.island.colorsTemplate
output_path = "~/.config/quickshell/colors.json"
```

Applying any wallpaper from the switcher regenerates it. Until then you get built-in colours.

**b) Wallpaper daemon.** awww needs its daemon running before wallpapers can change.

**c) Wallpapers.** Drop images (jpg / png / webp) in `~/Pictures/Wallpapers`
(or change `wallpapers.dir`).

> **Don't start island as a systemd service** unless you know why: a service doesn't get
> your compositor's PATH, so launching apps can fail. `exec-once` is the reliable way.

---

## 3. Daily use

| Do this | How |
|---|---|
| Open the island | hover it, or any IPC call below |
| Launch an app | `launcher toggle`, type, `Enter` |
| Clipboard history | `clipboard toggle`, `Enter` copies the entry |
| Emoji from the launcher | type `:smile` (or `:smile:`) in the launcher; `:` alone shows recents; `Enter` copies |
| Emoji / symbols | `emoji toggle`, type to search, arrows / `Tab` (categories), `Enter` copies |
| Calendar | `calendar toggle`, or tap the clock on the hover state; `h j k l` days, `H L` months, `t` today |
| Tray | `tray toggle`; click = activate, right click = menu, middle click = secondary action |
| Power menu | `power toggle`, then a click, or `l` `o` `s` `r` `p`, `Enter` |
| Change wallpaper | `wallpaper toggle`, arrows / `h` `l`, `Enter` |
| Tweak colours | in the switcher press `t` (or the palette button) |
| See every IPC command | `island --ipc` (raw list) or `island ipc call island help` |

### Keys

Launcher and clipboard start in **insert** mode (just type). `Esc` goes to **normal** mode, a second `Esc` closes.
`Ctrl-n/p`, arrows and `Tab` always move.

| Normal mode | Launcher | Clipboard |
|---|---|---|
| `j` `k` / `gg` `G` / `Ctrl-d` `Ctrl-u` | move | move |
| `3j`, `5G` | counts work | counts work |
| `l` `o` `Enter` | launch | copy (`y` too) |
| `dd` / `x` | clear query | delete the entry |
| `i` `a` `A` `I` `/` `s` | back to typing | back to typing |
| `q` / `Ctrl-c` | close | close |

**Power menu**

| Key | Action |
|---|---|
| `←` `→` / `Tab` | move |
| `Enter` `Space` | run the selected tile |
| `l` `o` `s` `r` `p` | lock / log out / sleep / restart / shut down |
| `Esc` `q` | close |

Log out, restart and shut down ask twice (`power.confirm`): the first press turns the tile into **Confirm**, a second press runs it. It disarms itself after 3 s. Lock and sleep run immediately. Lock uses island's own lock screen (`ext-session-lock`, password checked with PAM); set `power.lock` to a command only if you'd rather use swaylock / hyprlock.

**Wallpaper switcher**

| Key | Action |
|---|---|
| `h` `l` / `←` `→` / `Tab` | previous / next (endless, wraps smoothly) |
| `w` `b` / `PgUp` `PgDn` | jump a screenful |
| `gg` `G` / `0` `$` | first / last |
| `Enter` `Space` `o` | apply |
| `r` / `n` `N` | random / next / previous |
| `m` | dark / light |
| `t` | open the colour panel |
| `Esc` `q` | close |

**Colour panel** (`t`): `s` / `S` scheme, `c` / `C` (or `+` `-`) contrast, `a` / `A` accent colour,
`m` mode, `x` reset, `t` or `Esc` back. Mouse: click chips and swatches, drag the contrast slider
(double-click resets it). Your choices are remembered in `~/.local/state/island/matugen.json`.

Accent **Wallpaper** = colours come from the image; picking a swatch themes from that colour instead.

### IPC reference

```
island ipc call launcher   toggle | open | close
island ipc call clipboard  toggle | open | close | wipe
island ipc call emoji      toggle | open | close | clearRecent
island ipc call calendar   toggle | open | close
island ipc call tray       toggle | open | close
island ipc call center     toggle | open | close
island ipc call wallpaper  toggle | open | close | next | prev | random | restore | refresh
island ipc call wallpaper  set /path/to/img.png
island ipc call wallpaper  mode dark | light
island ipc call wallpaper  scheme tonal-spot | content | expressive | fidelity | fruit-salad | monochrome | neutral | rainbow
island ipc call wallpaper  contrast 0.4          # -1 .. 1
island ipc call wallpaper  accent "#42A5F5"      # or: auto
island ipc call power      toggle | open | close
island ipc call power      lock | logout | suspend | reboot | poweroff   # run right away, no confirm
island ipc call lock       lock | status      # there is no unlock call, the password is the only way in
island ipc call island     brightness 5          # +5 / -5
island ipc call island     help
```

Without Nix, replace `island` with `qs -c island`.

---

## 4. Settings

`settings.json` (next to `shell.qml`, or `$ISLAND_SETTINGS`) is **hot-reloaded**, so save and it applies.
Every key is optional. On Nix use `programs.island.settings.<section>.<key>` instead; it has the same names.

| Section | Keys |
|---|---|
| `look` | `font`, `iconFont`, `topGap`, `windowGap` (extra space between the island and tiled windows, `0` = just your compositor gap), `notch` (attach to the top edge), `shadow`, `shadowOpacity`, `shadowBlur`, `shadowOffset`, `shadowColor`, `sliderAccent` |
| `clock` | `timeFormat` (`"h:mm AP"` for 12 h), `dateFormat`, `shortDateFormat` (date next to the clock on the hover player) |
| `pill` | `clockWithMedia` (keep the clock while media plays), `batteryIcon` (battery as an icon only, hidden without a battery) |
| `behavior` | `hoverToExpand`, `hoverDelay`, `leaveDelay`, `mediaPeek`, `osdTimeout`, `notifTimeout`, `peekTimeout`, `ipcTimeout` |
| `hub` | `search`, `controlCenter` (launcher / control center buttons beside the clock in the hover view) |
| `controlCenter` | `showBattery` (battery readout in the notifications header) |
| `lock` | `autoLock` (lock when idle), `timeout` (seconds, default 300), `onSuspend` (lock before Sleep), `wallpaper` (blurred wallpaper behind it), `pam` (PAM service in `/etc/pam.d`, default `login`) |
| `power` | `confirm`, `lock`, `logout`, `suspend`, `reboot`, `poweroff` (each command is a list, like `launcher.terminal`) |
| `wallpapers` | `dir`, `setter`, `matugenMode`, `matugenScheme`, `matugenContrast`, `accentPresets`, `width`, `cardWidth`, `loop` |
| `launcher` | `width`, `rows`, `maxResults`, `placeholder`, `terminal` |
| `clipboard` | `width`, `rows`, `maxItems`, `placeholder`, `watch` |
| `emoji` | `width`, `columns`, `rows`, `placeholder`, `recentMax`, `typeAfterCopy` (also types the pick; needs `wtype`) |
| `calendar` | `firstDay` (0 = Sunday, 1 = Monday ...), `weekNumbers` |
| `tray` | `columns`, `hidePassive` |
| `keys` | `vim`, `launcherStartNormal` |

The default `power.logout` tries niri, then Hyprland, then sway, then `loginctl terminate-user`.
Set it to your compositor's own command if you prefer, e.g. `["niri", "msg", "action", "quit", "--skip-confirmation"]`.

Other wallpaper setters: set `wallpapers.setter` to any command, `%f` is the image path, e.g.
`["sh", "-c", "pkill swaybg; swaybg -m fill -i \"$1\" &", "sh", "%f"]`.

Files island writes: `~/.local/state/island/wallpaper` (current image),
`~/.local/state/island/matugen.json` (colour choices), `~/.local/state/island/` (launcher usage).

---

## 5. Troubleshooting

| Problem | Fix |
|---|---|
| Wallpaper won't change, header says "Setter failed" | `awww-daemon` isn't running |
| Colours never change | matugen template missing (step 2a), or `matugen` not on PATH |
| Emoji show as boxes | install a colour emoji font (`noto-fonts-color-emoji`; on Nix `fonts.packages = [ pkgs.noto-fonts-color-emoji ];`) |
| Tray is empty | the app must support StatusNotifier (many Electron apps need their tray option on) |
| Clipboard is empty | nothing feeds cliphist: set `clipboard.watch = true` or run the `wl-paste --watch` lines |
| Icons show as words / boxes | Material Symbols Rounded font missing |
| Brightness slider does nothing | no permission: install brightnessctl's udev rules / join the `video` group |
| Wi-Fi tile greyed | NetworkManager not running |
| Apps don't launch | island was started from systemd; start it from the compositor |
| `qs` says "Non-existent attached object" | an old build, update `shell.qml` (needs `import QtQuick`) |
| Lock screen rejects the right password | `lock.pam` names a PAM service that doesn't exist in `/etc/pam.d` |
| Never auto-locks | compositor lacks `ext-idle-notify`, an app is inhibiting idle, or the Awake tile is on |
| Want logs | `qs -c island` in a terminal; `qs log` for a running one |
| Calls say "no running instances" | island isn't running yet, or you're using `qs -p` with a different path |
