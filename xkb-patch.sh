#!/bin/bash
# Adds or removes the us(dvorak-qwerty) variant in the system xkb database.
# Called by the pacman hook / dpkg trigger after xkeyboard-config (xkb-data) is
# upgraded, and by the packages' install scriptlets. Every operation is
# idempotent.
#
#     xkb-patch.sh add [xkb-root]
#     xkb-patch.sh remove [xkb-root]
#
# With no xkb-root the system database is located automatically. install.sh
# passes one explicitly so the same helpers can edit a per-user tree under
# ~/.config/xkb.
#
# The packages deliberately ship their data files to /usr/share/xkb-dvorak-qwerty
# and this script copies or splices them into the xkb tree, rather than the
# packages shipping them into the tree directly. Two reasons:
#
#   * symbols/us belongs to xkeyboard-config and holds every other us variant,
#     so the variant has to be spliced into it rather than shipped as a file;
#   * on Arch/CachyOS /usr/share/X11/xkb is a symlink owned by xkeyboard-config,
#     so a package containing that path fails with a file conflict.

set -u

MARK_BEGIN='// >>> xkb-dvorak-qwerty >>>'
MARK_END='// <<< xkb-dvorak-qwerty <<<'
DESC='English (Dvorak, QWERTY shortcuts)'

# --- locate the system xkb database -----------------------------------------
# Distros disagree on this path. Newer xkeyboard-config installs to
# share/xkeyboard-config-2; older ones to share/X11/xkb; some symlink between
# the two. Find the one that actually holds the files we need to patch.
find_xkb_root() {
    local d
    for d in /usr/share/X11/xkb \
             /usr/share/xkeyboard-config-2 \
             /usr/local/share/X11/xkb \
             /usr/share/xkeyboard-config \
             /etc/X11/xkb; do
        [ -d "$d/symbols" ] && [ -d "$d/types" ] && [ -f "$d/rules/evdev.xml" ] \
            && { readlink -f "$d"; return 0; }
    done
    return 1
}

if [ -n "${2:-}" ]; then
    XKB="$2"
else
    XKB="$(find_xkb_root)" \
        || { echo "xkb-dvorak-qwerty: xkb database not found; skipping" >&2; exit 0; }
fi

# --- patch helpers ----------------------------------------------------------
# Anchored on structure, not on any particular line, so they survive upstream
# reshuffling of the files being edited.

patch_symbols() { # $1 = path to a symbols/us to edit in place, $2 = fragment to splice in
    local f="$1" frag="$2"
    [ -f "$f" ] || return 1
    grep -q 'xkb_symbols "dvorak-qwerty"' "$f" && return 0
    cat "$frag" >> "$f"
}

unpatch_symbols() { # $1 = path to a symbols/us to edit in place
    local f="$1"
    [ -f "$f" ] || return 0
    grep -qF "$MARK_BEGIN" "$f" || return 0
    local tmp; tmp=$(mktemp)
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
      index($0, b) == 1 { drop = 1; next }
      index($0, e) == 1 { drop = 0; next }
      !drop { print }
    ' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}

patch_types() {   # $1 = path to a types/complete file to edit in place
    local f="$1"
    grep -q '^[[:space:]]*include "dvorak-qwerty"' "$f" && return 0
    local tmp; tmp=$(mktemp)
    awk '
      !done && /xkb_types[[:space:]]+"complete"/ && /\{/ { print; print "    include \"dvorak-qwerty\""; done=1; next }
      !done && /xkb_types[[:space:]]+"complete"/ { print; brace=1; next }
      brace && /\{/ { print; print "    include \"dvorak-qwerty\""; done=1; brace=0; next }
      { print }
    ' "$f" > "$tmp"
    grep -q '^[[:space:]]*include "dvorak-qwerty"' "$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" > "$f"; rm -f "$tmp"
}

unpatch_types() { [ -f "$1" ] && sed -i '/^[[:space:]]*include "dvorak-qwerty"/d' "$1"; return 0; }

# The variant is registered inside the existing "us" layout, so it inherits that
# layout's countryList (US) and languageList (eng) and needs neither of its own.
# Matching the us layout means matching the *first* <name> inside a <layout>:
# several other layouts carry a variant that is itself named "us".
patch_xml() {     # $1 = path to an evdev.xml to edit in place
    local f="$1"
    grep -q '<name>dvorak-qwerty</name>' "$f" && return 0
    local tmp; tmp=$(mktemp)
    awk -v desc="$DESC" '
      function emit() {
        print "        <variant>"
        print "          <configItem>"
        print "            <name>dvorak-qwerty</name>"
        print "            <description>" desc "</description>"
        print "          </configItem>"
        print "        </variant>"
        done = 1
      }
      /<layout>/ { inl = 1; seen = 0; isus = 0 }
      inl && !seen && match($0, /<name>[^<]*<\/name>/) {
        seen = 1
        if (substr($0, RSTART + 6, RLENGTH - 13) == "us") isus = 1
      }
      isus && !done && /<variantList[[:space:]]*\/>/ {
        print "      <variantList>"; emit(); print "      </variantList>"
        next
      }
      isus && !done && /<\/variantList>/ { emit() }
      /<\/layout>/ { inl = 0; isus = 0 }
      { print }
    ' "$f" > "$tmp"
    grep -q '<name>dvorak-qwerty</name>' "$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" > "$f"; rm -f "$tmp"
}

unpatch_xml() {
    local f="$1"
    [ -f "$f" ] || return 0
    grep -q '<name>dvorak-qwerty</name>' "$f" || return 0
    local tmp; tmp=$(mktemp)
    awk '
      function flush() { if (/<name>dvorak-qwerty<\/name>/) drop = 1
                         if (/<\/variant>/) { if (!drop) print buf; n = 0; drop = 0; buf = "" } }
      !n && /<variant>/ { buf = $0; n = 1; flush(); next }
      n { buf = buf "\n" $0; flush(); next }
      { print }
    ' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}

patch_lst() {
    local f="$1"
    [ -f "$f" ] || return 0
    grep -q '^  dvorak-qwerty ' "$f" && return 0
    local tmp; tmp=$(mktemp)
    awk -v desc="$DESC" '
      /^! variant$/ { inv = 1; print; next }
      inv && /^$/ && !done { printf "  %-15s %s: %s\n", "dvorak-qwerty", "us", desc; done = 1; inv = 0 }
      { print }
    ' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}

unpatch_lst() { [ -f "$1" ] && sed -i '/^  dvorak-qwerty  *us: /d' "$1"; return 0; }


DATA="$(dirname "$(readlink -f "$0")")"
SYMBOLS="$XKB/symbols/us"
XML="$XKB/rules/evdev.xml"
LST="$XKB/rules/evdev.lst"
SYSTYPES="$XKB/types/complete"

case "${1:-add}" in
    add)
        install -Dm644 "$DATA/dvorak-qwerty.types" "$XKB/types/dvorak-qwerty" \
            || echo "xkb-dvorak-qwerty: could not write $XKB/types/dvorak-qwerty" >&2
        patch_symbols "$SYMBOLS" "$DATA/dvorak-qwerty.symbols" \
            || echo "xkb-dvorak-qwerty: could not patch $SYMBOLS" >&2
        patch_types "$SYSTYPES" || echo "xkb-dvorak-qwerty: could not patch $SYSTYPES" >&2
        patch_xml "$XML"        || echo "xkb-dvorak-qwerty: could not patch $XML" >&2
        patch_lst "$LST"
        if command -v xkbcli >/dev/null 2>&1; then
            xkbcli compile-keymap --layout us --variant dvorak-qwerty >/dev/null 2>&1 \
                || echo "xkb-dvorak-qwerty: warning: keymap did not compile" >&2
        fi
        ;;
    remove)
        unpatch_symbols "$SYMBOLS"; unpatch_types "$SYSTYPES"
        unpatch_xml "$XML"; unpatch_lst "$LST"
        rm -f "$XKB/types/dvorak-qwerty"
        ;;
    *) echo "usage: $0 add|remove [xkb-root]" >&2; exit 2 ;;
esac
