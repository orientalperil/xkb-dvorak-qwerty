# Dvorak-QWERTY for Linux

Type in Dvorak. Hold **Ctrl, Alt or Super** and every letter/punctuation key
reverts to its QWERTY position, so `Ctrl+C` / `Ctrl+X` / `Ctrl+V` / `Ctrl+Z`
stay under the fingers you already know. This is a Linux port of the macOS
layout **Dvorak – QWERTY ⌘**.

Shift deliberately does *not* switch to QWERTY — it only capitalises, the
same as on a Mac, since otherwise capital letters would be impossible to
type.

## Files

| File | Purpose |
|---|---|
| `dq.types` | Defines the `DVORAK_QWERTY` key type: four levels, selected by Shift/Lock/Control/Mod1/Mod4. `preserve[]` keeps the shortcut modifiers visible to applications — without it Ctrl+C would arrive as a bare `c`. |
| `dq.symbols` | `include "us(dvorak)"` plus a four-level override per key: `[dvorak, dvorak+shift, qwerty, qwerty+shift]`. |
| `install-dq.sh` | Installs into `/usr/share/X11/xkb`. Needs sudo. Works on X11 *and* Wayland. `--user` mode installs into `~/.config/xkb` instead, no root, Wayland only. |
| `build-deb.sh` | Builds `xkb-dvorak-qwerty_<version>_all.deb` with `dpkg-deb`: generates the control file plus `postinst`/`postrm` scripts that patch `types/complete`, `evdev.xml` and `evdev.lst` in place, and a dpkg trigger that re-runs them after `xkb-data` is upgraded. |
| `PKGBUILD` | Arch/`makepkg` build recipe. Packages `dq.symbols`, `dq.types`, `dq-patch.sh` and `dq.hook` into `/usr/share/xkb-dvorak-qwerty` (not directly into `/usr/share/X11/xkb`, which is a symlink owned by `xkeyboard-config`). |
| `dq-patch.sh` | Adds/removes the `dq` entries in the system xkb registry (`dq-patch.sh add\|remove`). Used by the pacman hook and by `xkb-dvorak-qwerty.install`; ships inside the Arch package, copied to `/usr/share/xkb-dvorak-qwerty/dq-patch.sh`. |
| `dq.hook` | Pacman hook: watches `xkb`/`xkeyboard-config` rules and types paths for install/upgrade, then runs `dq-patch.sh add` so the layout survives an `xkeyboard-config` update. Installed as `/usr/share/libalpm/hooks/95-xkb-dvorak-qwerty.hook`. |
| `xkb-dvorak-qwerty.install` | Pacman `.install` scriptlet: runs `dq-patch.sh add` on install/upgrade and `dq-patch.sh remove` before removal, plus prints the "add the layout in System Settings" reminder after install. |

`install-dq.sh` and `install-dq.sh --user` install the *same* layout; they
differ only in where the files land and therefore which display server can
see them. Pick one, not both.

## Install — Arch, CachyOS, EndeavourOS, Manjaro

```bash
makepkg -si
```

Builds and installs a proper pacman package, including a hook that re-registers
the layout after every `xkeyboard-config` upgrade. Remove with
`sudo pacman -R xkb-dvorak-qwerty`.

The package ships its files to `/usr/share/xkb-dvorak-qwerty` and copies them into the xkb
tree from there, rather than shipping them into the tree directly. On Arch `/usr/share/X11/xkb`
is a symlink owned by `xkeyboard-config`, and a package containing that path is rejected with
`exists in filesystem (owned by xkeyboard-config)`.

## Install — Ubuntu, Kubuntu, Debian, Mint, Pop!_OS

```bash
./build-deb.sh
sudo apt install ./xkb-dvorak-qwerty_1.0.0_all.deb
```

A dpkg trigger re-registers the layout after `xkb-data` upgrades. Remove with
`sudo apt remove xkb-dvorak-qwerty`.

## Install — any other distro (or a per-user, rootless install)

```bash
chmod +x install-dq.sh
sudo ./install-dq.sh
```

Finds your xkb database wherever the distro put it (`find_xkb_root` checks the
common locations), installs the layout, and registers it in `/usr/share/X11/xkb`.
Copies both files in, adds `include "dq"` to `types/complete`, and registers the
layout in `rules/evdev.xml` and `rules/evdev.lst` — backing up every file it edits
first. On X11 you can try it immediately with `setxkbmap dq`.

There is no upgrade hook on this path, so if the layout disappears after your distro
updates `xkeyboard-config`/`xkb-data`, run the script again.

Undo with `sudo ./install-dq.sh --uninstall`.

### Which installer (system vs. per-user)

libxkbcommon — used by KWin on Wayland — searches `~/.config/xkb` before the
system directory. The X server does not: `xkbcomp` only reads
`/usr/share/X11/xkb`. So:

* **Wayland session** → `install-dq.sh --user`. No root, and an `xkb-data`/
  `xkeyboard-config` upgrade can't clobber it.
* **X11 session, or you want the layout available to every user and to SDDM**
  → `install-dq.sh` (system-wide) or the packaged install above.

Check which session you're in with `echo $XDG_SESSION_TYPE`.

Rootless variant, Wayland only, no root and unaffected by package upgrades — but KDE's
settings page won't list a user-directory layout, so you'd have to select it with
`kwriteconfig6`:

```bash
./install-dq.sh --user
```

It writes four files:

```
~/.config/xkb/symbols/dq            the layout
~/.config/xkb/types/dq              the DVORAK_QWERTY key type
~/.config/xkb/types/complete        copy of the system file + include "dq"
~/.config/xkb/rules/evdev.xml       registry entry so the layout can be listed
```

Then set the layout by hand and log out/in:

```bash
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList dq
kwriteconfig6 --file kxkbrc --group Layout --key VariantList ""
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ""
```

(`kwriteconfig5` on Plasma 5.) Undo everything with
`./install-dq.sh --user --uninstall`.

After any of these installs: add **English (Dvorak, QWERTY shortcuts)** in System
Settings → Keyboard → Layouts, remove your old Dvorak entry, and log out and back in.

#### Why a system install instead of `~/.config/xkb`

libxkbcommon reads per-user layouts from `~/.config/xkb`, so a user-directory install does
work on Wayland — but KDE Plasma's keyboard settings page only reads the system registry,
so the layout never appears in the list and has to be set by hand with `kwriteconfig6`.
Installing system-wide (or via the distro package) is the only way to get it listed in the GUI.

## Uninstall

Switch your keyboard layout back to plain Dvorak or `us` in your desktop's keyboard
settings **first** — otherwise the session is left pointing at a layout that no longer
exists. Then use whichever line matches how you installed:

| Installed with | Remove with |
|---|---|
| `makepkg -si` | `sudo pacman -R xkb-dvorak-qwerty` |
| `sudo apt install ./xkb-dvorak-qwerty_1.0.0_all.deb` | `sudo apt remove xkb-dvorak-qwerty` |
| `sudo ./install-dq.sh` | `sudo ./install-dq.sh --uninstall` |
| `./install-dq.sh --user` | `./install-dq.sh --user --uninstall` |

All four delete `symbols/dq` and `types/dq` and strip the registry lines back out of
`types/complete`, `rules/evdev.xml` and `rules/evdev.lst`. The two package removals do
it from the pacman `pre_remove` scriptlet / dpkg `postrm`, and take the pacman hook or
dpkg trigger with them, so nothing re-registers the layout at the next
`xkeyboard-config`/`xkb-data` upgrade. Log out and back in afterwards.

The registry files are unpatched in place rather than restored from the `.pre-dq`
backups `install-dq.sh` made, so those copies are left alone — delete them yourself if
you want them gone.

`--user --uninstall` removes the four files it wrote under `~/.config/xkb` and then the
directories, if empty. It does not touch the `kwriteconfig6` settings, so reset the
layout by hand as well:

```bash
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList us
```

## Checking it works

Open a text editor and type `hello` — you should get `hello` in Dvorak positions.
Then press `Ctrl` plus the key labelled **C** on your physical keyboard: it should copy,
not type a `j`.

For a closer look:

```bash
xkbcli compile-keymap --layout dq | grep -A3 '<AB03>'   # does it build
sudo xkbcli interactive-evdev                           # live keysyms, Wayland
xev -event keyboard                                     # live keysyms, X11
```

`<AB03>` is the physical QWERTY-C key. Expected: plain `j`, Shift `J`,
Ctrl `c` (with Ctrl still reported as pressed), Ctrl+Shift `C`, Alt `c`,
Super `c`.

## What's in the package

| Path | What it is |
|---|---|
| `/usr/share/X11/xkb/symbols/dq` | The layout: four symbols per key — Dvorak, Dvorak+shift, QWERTY, QWERTY+shift |
| `/usr/share/X11/xkb/types/dq` | The rule that picks which of those four to use, based on the modifiers held |

The package also adds three lines to files owned by `xkb-data`/`xkeyboard-config`
(`types/complete`, `rules/evdev.xml`, `rules/evdev.lst`) so the layout shows up in
your desktop's keyboard list. A dpkg trigger / pacman hook re-applies those lines
automatically whenever the owning package is upgraded, and removing the package
strips them back out.

The `evdev.xml` entry declares both a `<countryList>` (`US`) and a `<languageList>`
(`eng`). Some desktops' "Add layout" picker defaults to browsing by country rather
than by language — MATE's does — and a layout with no `<countryList>` never appears
there no matter which country you pick, since it isn't filed under any of them. This
applies to any X11 desktop whose layout picker groups by country, not just MATE; the
layout is still correctly installed and selectable (e.g. via `setxkbmap dq` or your
desktop's raw layout-list setting) even before you find it in that dialog.

## The keyboard indicator

The layout is named `dq` because desktop keyboard indicators label themselves with the
*layout name* rather than the description — that's why the US layout shows `us`. A longer
name overflows the tray and covers neighbouring icons.

Plasma prints the name as-is, so this shows as `dq` in lowercase, matching `us`. If you'd
rather see capitals, edit the label for the entry in System Settings → Keyboard → Layouts;
that changes the displayed text only.

## Building the packages

Both packaged install paths above build the package locally rather than fetching a
prebuilt one — `build-deb.sh` needs `dpkg-deb` (Debian/Ubuntu), `makepkg -si` needs
`base-devel` (Arch). Edit the maintainer and homepage at the top of `build-deb.sh`
and `PKGBUILD` first if you want them to reflect you rather than the placeholders.

## Notes / known limitations

* Applications that read raw scancodes rather than keysyms — some games, emulators
  and remote-desktop clients — ignore XKB layouts entirely and are unaffected.
* The Dvorak dead keys on `' , . ;` (levels 3–4, only reachable if you enable a
  LevelThree/AltGr option) are replaced by the QWERTY letters.
* Only Control, Alt and Super switch to QWERTY. To drop one of them, delete every
  line mentioning the matching `Mod4` (Super) or `Mod1` (Alt) from `dq.types` and
  reinstall/rebuild.
