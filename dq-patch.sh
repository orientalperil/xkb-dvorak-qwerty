#!/bin/bash
# Adds or removes the "dq" layout's entries in the system xkb registry.
# Called by the pacman hook after xkeyboard-config is upgraded, and by the
# package's .install script. Every operation is idempotent.
#
#     dq-patch.sh add
#     dq-patch.sh remove
#
# The package deliberately ships its data files to /usr/share/xkb-dvorak-qwerty
# and this script copies them into the xkb tree, rather than the package
# shipping them into the tree directly. On Arch/CachyOS /usr/share/X11/xkb is a
# symlink owned by xkeyboard-config, so a package containing that path fails
# with a file conflict.

set -u

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

XKB="$(find_xkb_root)" || { echo "xkb-dvorak-qwerty: xkb database not found; skipping" >&2; exit 0; }

# --- patch helpers ----------------------------------------------------------
# Anchored on structure, not on any particular include line, so they survive
# upstream reshuffling of types/complete.

patch_types() {   # $1 = path to a types/complete file to edit in place
    local f="$1"
    grep -q '^[[:space:]]*include "dq"' "$f" && return 0
    local tmp; tmp=$(mktemp)
    awk '
      !done && /xkb_types[[:space:]]+"complete"/ && /\{/ { print; print "    include \"dq\""; done=1; next }
      !done && /xkb_types[[:space:]]+"complete"/ { print; brace=1; next }
      brace && /\{/ { print; print "    include \"dq\""; done=1; brace=0; next }
      { print }
    ' "$f" > "$tmp"
    grep -q '^[[:space:]]*include "dq"' "$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" > "$f"; rm -f "$tmp"
}

unpatch_types() { [ -f "$1" ] && sed -i '/^[[:space:]]*include "dq"/d' "$1"; return 0; }

patch_xml() {     # $1 = path to an evdev.xml to edit in place
    local f="$1"
    grep -q '<name>dq</name>' "$f" && return 0
    grep -q '</layoutList>' "$f" || return 1
    local tmp; tmp=$(mktemp)
    awk '
      /<\/layoutList>/ && !done {
        print "    <layout>"
        print "      <configItem>"
        print "        <name>dq</name>"
        print "        <shortDescription>dq</shortDescription>"
        print "        <description>English (Dvorak, QWERTY shortcuts)</description>"
        print "        <languageList>"
        print "          <iso639Id>eng</iso639Id>"
        print "        </languageList>"
        print "      </configItem>"
        print "      <variantList/>"
        print "    </layout>"
        done = 1
      }
      { print }
    ' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}

unpatch_xml() {
    local f="$1"
    [ -f "$f" ] || return 0
    grep -q '<name>dq</name>' "$f" || return 0
    local tmp; tmp=$(mktemp)
    awk '
      /<layout>/ { buf = $0; n = 1; next }
      n {
        buf = buf "\n" $0
        if (/<name>dq<\/name>/) drop = 1
        if (/<\/layout>/) { if (!drop) print buf; n = 0; drop = 0; buf = "" }
        next
      }
      { print }
    ' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}

patch_lst() {
    local f="$1"
    [ -f "$f" ] || return 0
    grep -q '^  dq ' "$f" && return 0
    local tmp; tmp=$(mktemp)
    awk '
      /^! layout$/ { inl = 1; print; next }
      inl && /^$/ && !done { print "  dq              English (Dvorak, QWERTY shortcuts)"; done = 1; inl = 0 }
      /^! variant$/ { inv = 1; print; next }
      inv && /^$/ && !vdone { print "  basic           dq: Default"; vdone = 1; inv = 0 }
      { print }
    ' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}

unpatch_lst() { [ -f "$1" ] && sed -i '/^  dq /d;/^  basic           dq: /d' "$1"; return 0; }


DATA="$(dirname "$(readlink -f "$0")")"
XML="$XKB/rules/evdev.xml"
LST="$XKB/rules/evdev.lst"
SYSTYPES="$XKB/types/complete"

case "${1:-add}" in
    add)
        install -Dm644 "$DATA/dq.symbols" "$XKB/symbols/dq" \
            || echo "xkb-dvorak-qwerty: could not write $XKB/symbols/dq" >&2
        install -Dm644 "$DATA/dq.types" "$XKB/types/dq" \
            || echo "xkb-dvorak-qwerty: could not write $XKB/types/dq" >&2
        patch_types "$SYSTYPES" || echo "xkb-dvorak-qwerty: could not patch $SYSTYPES" >&2
        patch_xml "$XML"        || echo "xkb-dvorak-qwerty: could not patch $XML" >&2
        patch_lst "$LST"
        if command -v xkbcli >/dev/null 2>&1; then
            xkbcli compile-keymap --layout dq >/dev/null 2>&1 \
                || echo "xkb-dvorak-qwerty: warning: keymap did not compile" >&2
        fi
        ;;
    remove)
        unpatch_types "$SYSTYPES"; unpatch_xml "$XML"; unpatch_lst "$LST"
        rm -f "$XKB/symbols/dq" "$XKB/types/dq"
        ;;
    *) echo "usage: $0 add|remove" >&2; exit 2 ;;
esac
