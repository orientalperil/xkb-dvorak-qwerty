# Dvorak-QWERTY for Linux

Type in Dvorak. Hold **Ctrl, Alt or Super** and every letter key snaps back to its
QWERTY position, so `Ctrl+C`, `Ctrl+X`, `Ctrl+V` and `Ctrl+Z` stay under the fingers
you already know. This is a Linux port of the macOS layout **Dvorak – QWERTY ⌘**.

Shift is not affected — it just capitalises, the same as on a Mac.

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

## Install — any other distro

```bash
sudo ./install-dq.sh
```

Finds your xkb database wherever the distro put it, installs the layout, and registers it.
Undo with `sudo ./install-dq.sh --uninstall`.

There is no upgrade hook on this path, so if the layout disappears after your distro
updates `xkeyboard-config`, run the script again.

Rootless variant, Wayland only, no root and unaffected by package upgrades — but KDE's
settings page won't list a user-directory layout, so you'd have to select it with
`kwriteconfig6`:

```bash
./install-dq.sh --user
```

Then set the layout by hand and log out/in:

```bash
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList dq
kwriteconfig6 --file kxkbrc --group Layout --key VariantList ""
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ""
```

After any of these: add **English (Dvorak, QWERTY shortcuts)** in System Settings →
Keyboard → Layouts, remove your old Dvorak entry, and log out and back in.

## Checking it works

Open a text editor and type `hello` — you should get `hello` in Dvorak positions.
Then press `Ctrl` plus the key labelled **C** on your physical keyboard: it should copy,
not type a `j`.

For a closer look:

```bash
sudo xkbcli interactive-evdev      # Wayland
xev -event keyboard                # X11
```

## What's in the package

| Path | What it is |
|---|---|
| `/usr/share/X11/xkb/symbols/dq` | The layout: four symbols per key — Dvorak, Dvorak+shift, QWERTY, QWERTY+shift |
| `/usr/share/X11/xkb/types/dq` | The rule that picks which of those four to use, based on the modifiers held |

The package also adds three lines to files owned by `xkb-data` (`types/complete`,
`rules/evdev.xml`, `rules/evdev.lst`) so the layout shows up in your desktop's keyboard
list. A dpkg trigger re-applies those lines automatically whenever `xkb-data` is upgraded,
and removing the package strips them back out.

## Why a system package instead of `~/.config/xkb`

libxkbcommon reads per-user layouts from `~/.config/xkb`, so a user-directory install does
work on Wayland — but KDE Plasma's keyboard settings page only reads the system registry,
so the layout never appears in the list and has to be set by hand with `kwriteconfig6`.
Installing system-wide is the only way to get it listed in the GUI.

## The keyboard indicator

The layout is named `dq` because desktop keyboard indicators label themselves with the
*layout name* rather than the description — that's why the US layout shows `us`. A longer
name overflows the tray and covers neighbouring icons.

Plasma prints the name as-is, so this shows as `dq` in lowercase, matching `us`. If you'd
rather see capitals, edit the label for the entry in System Settings → Keyboard → Layouts;
that changes the displayed text only.

## Building the packages

Both install paths above build the package locally rather than fetching a prebuilt one —
`build-deb.sh` needs `dpkg-deb` (Debian/Ubuntu), `makepkg -si` needs `base-devel` (Arch).
Edit the maintainer and homepage at the top of `build-deb.sh` and `PKGBUILD` first if you
want them to reflect you rather than the placeholders.

## Known limitations

- Applications that read raw scancodes rather than keysyms — some games, emulators and
  remote-desktop clients — ignore keyboard layouts entirely and are unaffected.
- The Dvorak dead keys on `' , . ;` (only reachable with an AltGr/LevelThree option
  enabled) are replaced by the QWERTY letters.
- Only Control, Alt and Super switch to QWERTY. To drop one of them, delete the matching
  `Mod4` or `Mod1` lines from `dq.types` and rebuild.
