# Dvorak-QWERTY for Linux

Type in Dvorak. Hold **Ctrl, Alt or Super** and every letter/punctuation key
reverts to its QWERTY position, so `Ctrl+C` / `Ctrl+X` / `Ctrl+V` / `Ctrl+Z`
stay under the fingers you already know. This is a Linux port of the macOS
layout **Dvorak – QWERTY ⌘**.

Shift deliberately does *not* switch to QWERTY — it only capitalises, the
same as on a Mac, since otherwise capital letters would be impossible to
type.

It installs as a variant of the stock English (US) layout — `us(dvorak-qwerty)`,
the same name the [upstream submission](upstream-submission.md) proposes — so it
appears in your desktop's keyboard settings under **English (US)**, alongside
English (Dvorak) and the other US variants.

## Files

| File | Purpose |
|---|---|
| `dvorak-qwerty.types` | Defines the `DVORAK_QWERTY` key type: four levels, selected by Shift/Lock/Control/Mod1/Mod4. `preserve[]` keeps the shortcut modifiers visible to applications — without it Ctrl+C would arrive as a bare `c`. Installed as `types/dvorak-qwerty`. |
| `dvorak-qwerty.symbols` | The `xkb_symbols "dvorak-qwerty"` block: `include "us(dvorak)"` plus a four-level override per key: `[dvorak, dvorak+shift, qwerty, qwerty+shift]`. Spliced into the system `symbols/us` between two marker comments. |
| `xkb-patch.sh` | Adds/removes the variant in the xkb database (`xkb-patch.sh add\|remove [xkb-root]`). The single implementation shared by all four install paths below. |
| `install.sh` | Standalone installer for distros with no package here. Needs sudo. Works on X11 *and* Wayland. `--user` mode installs into `~/.config/xkb` instead, no root, Wayland only. |
| `build-deb.sh` | Builds `xkb-dvorak-qwerty_<version>_all.deb` with `dpkg-deb`: generates the control file, the `postinst`/`prerm` scripts that call `xkb-patch.sh`, and a dpkg trigger that re-runs it after `xkb-data` is upgraded. |
| `PKGBUILD` | Arch/`makepkg` build recipe. Packages the two data files, `xkb-patch.sh` and the hook into `/usr/share/xkb-dvorak-qwerty` (not directly into `/usr/share/X11/xkb`, which is a symlink owned by `xkeyboard-config`). |
| `xkb-dvorak-qwerty.hook` | Pacman hook: watches the xkb `rules`/`symbols`/`types` paths for install/upgrade, then runs `xkb-patch.sh add` so the variant survives an `xkeyboard-config` update. Installed as `/usr/share/libalpm/hooks/95-xkb-dvorak-qwerty.hook`. |
| `xkb-dvorak-qwerty.install` | Pacman `.install` scriptlet: runs `xkb-patch.sh add` on install/upgrade and `xkb-patch.sh remove` before removal, plus prints the "add the layout in System Settings" reminder after install. |

`install.sh` and `install.sh --user` install the *same* variant; they differ
only in where the files land and therefore which display server can see them.
Pick one, not both.

## Install — Arch, CachyOS, EndeavourOS, Manjaro

```bash
makepkg -si
```

Builds and installs a proper pacman package, including a hook that re-registers
the variant after every `xkeyboard-config` upgrade. Remove with
`sudo pacman -R xkb-dvorak-qwerty`.

The package ships its files to `/usr/share/xkb-dvorak-qwerty` and splices them into the xkb
tree from there, rather than shipping them into the tree directly. On Arch `/usr/share/X11/xkb`
is a symlink owned by `xkeyboard-config`, and a package containing that path is rejected with
`exists in filesystem (owned by xkeyboard-config)`.

## Install — Ubuntu, Kubuntu, Debian, Mint, Pop!_OS

```bash
./build-deb.sh
sudo apt install ./xkb-dvorak-qwerty_1.1.0_all.deb
```

A dpkg trigger re-registers the variant after `xkb-data` upgrades. Remove with
`sudo apt remove xkb-dvorak-qwerty`.

## Install — any other distro (or a per-user, rootless install)

```bash
chmod +x install.sh
sudo ./install.sh
```

Finds your xkb database wherever the distro put it (`find_xkb_root` checks the
common locations), then hands it to `xkb-patch.sh`, backing up every file it
edits first. On X11 you can try it immediately with
`setxkbmap us -variant dvorak-qwerty`.

There is no upgrade hook on this path, so if the variant disappears after your distro
updates `xkeyboard-config`/`xkb-data`, run the script again.

Undo with `sudo ./install.sh --uninstall`.

### Which installer (system vs. per-user)

libxkbcommon — used by KWin on Wayland — searches `~/.config/xkb` before the
system directory. The X server does not: `xkbcomp` only reads
`/usr/share/X11/xkb`. So:

* **Wayland session** → `install.sh --user`. No root, and an `xkb-data`/
  `xkeyboard-config` upgrade can't clobber it.
* **X11 session, or you want the variant available to every user and to SDDM**
  → `install.sh` (system-wide) or the packaged install above.

Check which session you're in with `echo $XDG_SESSION_TYPE`.

Rootless variant, Wayland only, no root and unaffected by package upgrades — but KDE's
settings page won't list a user-directory layout, so you'd have to select it with
`kwriteconfig6`:

```bash
./install.sh --user
```

It writes four files:

```
~/.config/xkb/symbols/us            copy of the system file + the dvorak-qwerty block
~/.config/xkb/types/dvorak-qwerty   the DVORAK_QWERTY key type
~/.config/xkb/types/complete        copy of the system file + include "dvorak-qwerty"
~/.config/xkb/rules/evdev.xml       registry entry so the variant can be listed
```

A per-user file *replaces* the system one rather than merging with it, which is why
`symbols/us` and `types/complete` are copied whole and then edited. That also means
these copies go stale: after an `xkeyboard-config` upgrade adds or changes other US
variants, re-run the script to pick them up.

Then set the layout by hand and log out/in:

```bash
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList us
kwriteconfig6 --file kxkbrc --group Layout --key VariantList dvorak-qwerty
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ""
```

(`kwriteconfig5` on Plasma 5.) Undo everything with
`./install.sh --user --uninstall`.

After any of these installs: add **English (Dvorak, QWERTY shortcuts)** in System
Settings → Keyboard → Layouts (it is listed under English (US)), remove your old
Dvorak entry, and log out and back in.

#### Why a system install instead of `~/.config/xkb`

libxkbcommon reads per-user layouts from `~/.config/xkb`, so a user-directory install does
work on Wayland — but KDE Plasma's keyboard settings page only reads the system registry,
so the variant never appears in the list and has to be set by hand with `kwriteconfig6`.
Installing system-wide (or via the distro package) is the only way to get it listed in the GUI.

## Uninstall

Switch your keyboard layout back to plain Dvorak or `us` in your desktop's keyboard
settings **first** — otherwise the session is left pointing at a variant that no longer
exists. Then use whichever line matches how you installed:

| Installed with | Remove with |
|---|---|
| `makepkg -si` | `sudo pacman -R xkb-dvorak-qwerty` |
| `sudo apt install ./xkb-dvorak-qwerty_1.1.0_all.deb` | `sudo apt remove xkb-dvorak-qwerty` |
| `sudo ./install.sh` | `sudo ./install.sh --uninstall` |
| `./install.sh --user` | `./install.sh --user --uninstall` |

All four delete `types/dvorak-qwerty` and strip our additions back out of `symbols/us`,
`types/complete`, `rules/evdev.xml` and `rules/evdev.lst`. The two package removals do
it from the pacman `pre_remove` scriptlet / dpkg `prerm`, and take the pacman hook or
dpkg trigger with them, so nothing re-registers the variant at the next
`xkeyboard-config`/`xkb-data` upgrade. Log out and back in afterwards.

The edited files are unpatched in place rather than restored from the `.pre-dvorak-qwerty`
backups `install.sh` made, so those copies are left alone — delete them yourself if
you want them gone.

`--user --uninstall` removes the four files it wrote under `~/.config/xkb` and then the
directories, if empty. It does not touch the `kwriteconfig6` settings, so reset the
layout by hand as well:

```bash
kwriteconfig6 --file kxkbrc --group Layout --key VariantList ""
```

## Checking it works

Open a text editor and type `hello` — you should get `hello` in Dvorak positions.
Then press `Ctrl` plus the key labelled **C** on your physical keyboard: it should copy,
not type a `j`.

For a closer look:

```bash
xkbcli compile-keymap --layout us --variant dvorak-qwerty | grep -A3 '<AB03>'
sudo xkbcli interactive-evdev                           # live keysyms, Wayland
xev -event keyboard                                     # live keysyms, X11
```

`<AB03>` is the physical QWERTY-C key. Expected: plain `j`, Shift `J`,
Ctrl `c` (with Ctrl still reported as pressed), Ctrl+Shift `C`, Alt `c`,
Super `c`.

## What's in the package

| Path | What it is |
|---|---|
| `/usr/share/xkb-dvorak-qwerty/dvorak-qwerty.symbols` | The variant: four symbols per key — Dvorak, Dvorak+shift, QWERTY, QWERTY+shift |
| `/usr/share/xkb-dvorak-qwerty/dvorak-qwerty.types` | The rule that picks which of those four to use, based on the modifiers held |
| `/usr/share/xkb-dvorak-qwerty/xkb-patch.sh` | Splices the two into the xkb database, and strips them back out |

`xkb-patch.sh` copies the key type to `types/dvorak-qwerty` and then edits four files
owned by `xkb-data`/`xkeyboard-config`:

| File | Edit |
|---|---|
| `symbols/us` | the `xkb_symbols "dvorak-qwerty"` block is appended, wrapped in `// >>> xkb-dvorak-qwerty >>>` / `// <<< xkb-dvorak-qwerty <<<` marker comments so it can be removed again |
| `types/complete` | `include "dvorak-qwerty"` |
| `rules/evdev.xml` | a `<variant>` entry inside the existing `us` layout's `<variantList>` |
| `rules/evdev.lst` | one line under `! variant` |

Every edit is idempotent, and a dpkg trigger / pacman hook re-applies them automatically
whenever the owning package is upgraded. That matters more than it used to: the variant
itself now lives in `symbols/us`, so an upgrade wipes the layout, not just its
registration.

The variant is registered inside the `us` layout, so it inherits that layout's
`<countryList>` (`US`) and `<languageList>` (`eng`) and declares neither of its own.
This is what makes it appear in desktop layout pickers that browse by country rather
than by language — MATE's does — where a top-level layout with no `<countryList>` is
filed under no country at all and never shows up.

## The keyboard indicator

Desktop keyboard indicators label themselves with the *layout* name, not the variant
or the description, so this shows as `us` — the same as plain English (US), and
indistinguishable from it at a glance if you have both enabled. Plasma also draws its
flag from that name, so the entry gets the US flag like any other US variant.

If you want to tell them apart, edit the label for the entry in System Settings →
Keyboard → Layouts; that changes the displayed text only.

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
  line mentioning the matching `Mod4` (Super) or `Mod1` (Alt) from
  `dvorak-qwerty.types` and reinstall/rebuild.
