# dq — Dvorak with QWERTY shortcut positions (Linux/XKB)

The equivalent of macOS "Dvorak – QWERTY ⌘". You type in Dvorak, but while
**Ctrl, Alt or Super** is held every letter/punctuation key reverts to its
QWERTY position, so Ctrl+C / Ctrl+X / Ctrl+V / Ctrl+Z stay under the fingers
you learned them on.

Shift deliberately does *not* switch to QWERTY — it only capitalises, since
otherwise capital letters would be impossible to type.

## Files

| File                       | Purpose |
|----------------------------|---------|
| `dq.types`           | Defines the `DVORAK_QWERTY` key type: four levels, selected by Shift/Lock/Control/Mod1/Mod4. `preserve[]` keeps the shortcut modifiers visible to applications — without it Ctrl+C would arrive as a bare `c`. |
| `dq.symbols`         | `include "us(dvorak)"` plus a four-level override per key: `[dvorak, dvorak+shift, qwerty, qwerty+shift]`. |
| `install-dq.sh`         | Installs into `/usr/share/X11/xkb`. Needs sudo. Works on X11 *and* Wayland. |
| `install-dq.sh --user`  | Installs into `~/.config/xkb`. No root. **Wayland only.** |

One script, two modes, installing the *same* layout; they differ only in where
the files land and therefore which display server can see them. Pick one, not
both.

## Which installer

libxkbcommon — used by KWin on Wayland — searches `~/.config/xkb` before the
system directory. The X server does not: `xkbcomp` only reads
`/usr/share/X11/xkb`. So:

* **Wayland session** → `install-dq.sh --user`. No root, and an `xkb-data`
  package upgrade can't clobber it.
* **X11 session, or you want the layout available to every user and to SDDM** →
  `install-dq.sh`.

Check which session you're in with `echo $XDG_SESSION_TYPE`.

## Per-user install (Wayland)

```bash
chmod +x install-dq.sh
./install-dq.sh --user
```

It writes four files:

```
~/.config/xkb/symbols/dq     the layout
~/.config/xkb/types/dq       the DVORAK_QWERTY key type
~/.config/xkb/types/complete       copy of the system file + include "dq"
~/.config/xkb/rules/evdev.xml      registry entry so the layout can be listed
```

Then System Settings → Keyboard → Layouts → Add → **English (Dvorak, QWERTY
shortcuts)**, remove the plain Dvorak entry, Apply, log out and back in.

If the KDE list doesn't offer it, set it directly and log out/in:

```bash
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList dq
kwriteconfig6 --file kxkbrc --group Layout --key VariantList ""
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ""
```

(`kwriteconfig5` on Plasma 5.) Undo everything with
`./install-dq.sh --user --uninstall`.

## System-wide install (X11 or Wayland)

```bash
chmod +x install-dq.sh
./install-dq.sh
```

Copies both files into `/usr/share/X11/xkb/`, adds `include "dq"` to
`types/complete`, and registers the layout in `rules/evdev.xml`, backing up
both files it edits. On X11 you can try it immediately with
`setxkbmap dq`. An `xkb-data` upgrade rewrites `types/complete` and
`rules/evdev.xml`, so re-run the script if the layout disappears after an
update. Undo with `./install-dq.sh --uninstall`.

## Verifying

```bash
xkbcli compile-keymap --layout dq | grep -A3 '<AB03>'   # does it build
sudo xkbcli interactive-evdev                                 # live keysyms, Wayland
xev -event keyboard                                           # live keysyms, X11
```

`<AB03>` is the physical QWERTY-C key. Expected: plain `j`, Shift `J`,
Ctrl `c` (with Ctrl still reported as pressed), Ctrl+Shift `C`, Alt `c`,
Super `c`.

## Notes

* The Dvorak dead keys on `' , . ;` (levels 3–4, only reachable if you enable a
  LevelThree/AltGr option) are replaced by the QWERTY letters.
* To stop Super from switching to QWERTY, delete every line mentioning `Mod4`
  from `dq.types` and reinstall. Same for `Mod1` if you want Alt left
  alone.
* Applications that read raw scancodes rather than keysyms — some games,
  emulators, remote-desktop clients — ignore XKB layouts entirely and are
  unaffected.
