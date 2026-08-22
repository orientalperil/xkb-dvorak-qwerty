# Upstream submission plan — Dvorak-QWERTY variant

## Targets, in priority order

| # | Project | Why | Effort |
|---|---------|-----|--------|
| 1 | **xkeyboard-config** (freedesktop.org) | The keyboard database every Linux distro ships. Landing here means it reaches Debian, Ubuntu, Fedora, Arch, openSUSE, Gentoo, Alpine, and every Wayland compositor at once. | The real work |
| 2 | ChromiumOS input methods list | Chromium keeps its own allow-list of which xkb layouts are offered to users. Even after #1 lands, ChromeOS won't show the layout until this list is updated. | Small, but only after #1 |
| 3 | AOSP key character maps (`.kcm`) | Android has a separate layout format that does not consume xkeyboard-config. | Speculative |
| 4 | `kbd` (Linux console keymaps) | `/usr/share/keymaps` is a separate database for the TTY. The console keymap format can express per-modifier mappings. | Low value |

**Do not file per-distro tickets.** Debian, Fedora, Arch et al. package xkeyboard-config
unmodified; a layout request there will be closed as "file upstream." The only legitimate
distro-level ticket is a backport request into an already-frozen release *after* the change
is merged and released upstream — and for a new feature that is normally declined anyway.

---

## Before filing anything

The maintainers will ask how many users this has. Assemble evidence first:

* macOS has shipped "Dvorak – QWERTY ⌘" as a stock layout for roughly two decades — this is
  a port of an established layout, not an invention.
* Microsoft-format ports exist (e.g. `bradfeehan/Dvorak-QWERTY-Ctrl`), as do several
  independent Linux implementations that resort to intercepting keystrokes
  (`kentonv/dvorak-qwerty` and its forks) precisely because no XKB variant exists.
* Search the issue tracker and merge requests for prior art before opening anything — the
  contributing guide asks for this explicitly.
* Publish your files in a public repo first and link it. A repo with real users is the
  strongest argument available to you.

Repo: https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config
Contributing guide: https://xkeyboard-config.freedesktop.org/doc/contributing/

---

## 1. xkeyboard-config — feature request issue

*File this first, as an issue, and let a maintainer signal interest before you spend time on
the merge request. Use their issue template.*

**Title:** `New variant: us(dvorak-qwerty) — Dvorak that reverts to QWERTY positions under modifiers`

**Body:**

> ### Summary
>
> I'd like to propose a `us` variant that behaves as standard Dvorak while typing, but maps
> the alphanumeric keys back to their QWERTY positions while a shortcut modifier (Control,
> Alt or Super) is held. This is a port of the "Dvorak – QWERTY ⌘" layout that macOS has
> shipped as a stock option for many years.
>
> ### Motivation
>
> Dvorak scatters the keys used by the most common application shortcuts. `Ctrl+X`, `Ctrl+C`
> and `Ctrl+V` sit adjacently at the bottom left on QWERTY and can be reached one-handed
> while the other hand stays on the mouse; on Dvorak they land under `B`, `I` and `.`,
> spread across both hands. The same applies to `Ctrl+Z`, `Ctrl+W`, `Ctrl+S` and `Ctrl+F`.
>
> macOS addresses this with a dedicated layout. Linux has no equivalent, so users currently
> either accept the awkward positions or run out-of-tree tools that intercept and rewrite
> key events at the evdev or X-grab level — approaches that are fragile and that generally
> do not work under Wayland at all. A layout-level solution is well within XKB's abilities
> and would remove the need for those workarounds.
>
> ### Prior art
>
> - macOS: "Dvorak – QWERTY ⌘", shipped by Apple.
> - Windows: several third-party ports using the MS Keyboard Layout Creator.
> - Linux: `kentonv/dvorak-qwerty` and derivatives, all implemented as event-rewriting
>   daemons rather than layouts.
>
> ### Proposed implementation
>
> - A new key type, since no existing type selects a shift level based on Control/Alt/Super.
> - `us(dvorak-qwerty)` in `symbols/us`, below the `// EXTRAS:` delimiter, consisting of
>   `include "us(dvorak)"` plus a four-level override per alphanumeric key.
> - Registration in `rules/base.extras.xml`.
>
> I have a working implementation that compiles cleanly under both `xkbcomp` and
> `xkbcli compile-keymap`, and I'm happy to open a merge request if this is something you'd
> consider. I'd note up front that I'm proposing this for *extras*, not the main list.
>
> ### Questions for maintainers
>
> 1. Is a new key type acceptable here? I understand these are introduced conservatively.
>    The type is the only way I can see to do this; I'd welcome a suggestion if there's an
>    existing type I've missed.
> 2. Should the type live in `types/extra` (already pulled in by `types/complete`), or in
>    its own file?
> 3. Is `dvorak-qwerty` the right variant name, or would you prefer something else?

---

## 2. xkeyboard-config — merge request

*Only after a maintainer responds positively to the issue.*

**Title:** `symbols/us: add dvorak-qwerty variant`

**Body:**

> Closes #NNN.
>
> Adds `us(dvorak-qwerty)`: standard Dvorak for typing, QWERTY key positions while Control,
> Alt or Super is held, matching the macOS "Dvorak – QWERTY ⌘" layout. Placed in *extras*.
>
> ### Changes
>
> - `types/extra`: new `DVORAK_QWERTY` type. Four levels — Dvorak, Dvorak+shift, QWERTY,
>   QWERTY+shift — selected by `Shift+Lock+Control+Mod1+Mod4`.
> - `symbols/us`: new variant below `// EXTRAS:`, `include "us(dvorak)"` plus a four-level
>   override per alphanumeric key, sorted by keycode name.
> - `rules/base.extras.xml`: registry entry, description "English (Dvorak, QWERTY
>   shortcuts)", `shortDescription` `en`, `languageList` `eng`.
>
> ### Design notes
>
> **Shift does not switch to QWERTY.** Only Control, Mod1 and Mod4 do. Including Shift would
> make capital letters unreachable. macOS behaves the same way — only ⌘ triggers the switch.
>
> **`preserve[]` on every shortcut modifier.** This is the crux of the change. Without it
> the modifier is consumed by level selection and applications receive a bare keysym, so
> `Ctrl+C` would insert a `c` instead of copying. Each mapping preserves whichever of
> Control/Mod1/Mod4 selected the level. Shift is left unpreserved, matching `ALPHABETIC`.
>
> **Caps Lock** follows `ALPHABETIC` semantics: Shift XOR Lock selects the upper level, so
> Caps+Shift yields lowercase.
>
> **`level3(ralt_switch)` is not included.** Guideline 8 recommends it for variants using
> more than two levels, but levels 3 and 4 here are not AltGr levels — they are unreachable
> via `LevelThree`, and `Mod5` is deliberately absent from the type's modifier list so that
> AltGr behaviour on other keys is unaffected. Happy to revisit if you'd prefer otherwise.
>
> **Dead keys.** `us(dvorak)` defines level 3/4 dead keys on `AD01`–`AD03` and `AB01`; those
> levels are reused here for the QWERTY letters. Only affects users who have enabled a
> LevelThree option. Called out in a comment in the symbols file.
>
> ### Testing
>
> - `xkbcli compile-keymap --layout us --variant dvorak-qwerty` — clean.
> - `setxkbmap -print … | xkbcomp` — clean, warnings identical to baseline.
> - Behavioural check against libxkbcommon on `<AB03>` (QWERTY-C position):
>
>   | Modifiers | Keysym | Control reported |
>   |---|---|---|
>   | none | `j` | — |
>   | Shift | `J` | — |
>   | Caps | `J` | — |
>   | Control | `c` | active, **not consumed** |
>   | Control+Shift | `C` | active, **not consumed** |
>   | Alt | `c` | — |
>   | Super | `c` | — |
>
>   Control is reported unconsumed under both `XKB_CONSUMED_MODE_XKB` and
>   `XKB_CONSUMED_MODE_GTK`, so GTK and Qt accelerator matching both see a real `Ctrl+C`.
>
> ### On the "this breaks applications" concern
>
> Existing Linux implementations of this layout are event-rewriting daemons, and their
> authors have reported that an XKB-based version exposed bugs in applications. I believe
> that is the consumed-modifier problem above: an implementation without `preserve[]`
> produces exactly the symptom of shortcuts silently typing letters. I'd welcome testing
> from anyone who hit those bugs previously.

---

## 3. ChromiumOS — after upstream lands

**Title:** `Add Dvorak-QWERTY (us(dvorak-qwerty)) to the available keyboard layouts`

**Body:**

> `us(dvorak-qwerty)` was added upstream in xkeyboard-config <version> (<link to MR>). It
> behaves as Dvorak while typing and as QWERTY while Control/Alt/Super is held, matching the
> macOS "Dvorak – QWERTY ⌘" layout that Chrome users coming from macOS will expect.
>
> ChromeOS maintains its own list of exposed xkb layouts, so the variant will not appear to
> users until it is added there. Requesting that it be included alongside the existing
> Dvorak entries.

---

## 4. AOSP / kbd — only if there's demand

Both need the layout re-expressed in a different format, so don't start until #1 is merged
and you have users asking. For `kbd`, the console keymap format can express per-modifier
mappings directly, so a `dvorak-qwerty.map` in `/usr/share/keymaps` is feasible. For AOSP,
a `.kcm` key character map would be needed; check first whether the `.kcm` format can
express modifier-dependent character output at all, since it may not.

---

## Style checklist before opening the MR

- [ ] Key mappings sorted alphabetically by keycode name (`AB01`, `AB02`, … `AE12`) — the
      working file groups them by row instead and must be re-sorted.
- [ ] Variant placed after the `// EXTRAS:` delimiter in `symbols/us`.
- [ ] Registered in `rules/base.extras.xml`, not `base.xml`.
- [ ] Group 1 only.
- [ ] `pre-commit run --all` passes.
- [ ] Built and tested against a local `meson install` prefix, not the system database.

---

*Note on naming: the local package uses the layout name `dq` so that desktop keyboard
indicators show a short "DQ" label. Upstream this becomes the variant `us(dvorak-qwerty)`
instead, where the indicator inherits the `us` label, so the short name is not needed there.*
