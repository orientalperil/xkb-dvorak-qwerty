#!/bin/bash
# Installs the "dq" keyboard layout: Dvorak that reverts to QWERTY key
# positions while Control, Alt or Super is held.
#
#     sudo ./install-dq.sh              system-wide (X11 + Wayland, shows in GUI)
#          ./install-dq.sh --user       into ~/.config/xkb (Wayland only, no root)
#     sudo ./install-dq.sh --uninstall
#          ./install-dq.sh --user --uninstall
#
# Works on any distro that ships xkeyboard-config: Arch/CachyOS, Debian/Ubuntu,
# Fedora, openSUSE, Alpine, Gentoo, NixOS (with caveats).

set -u

MODE=system
ACTION=install
for arg in "$@"; do
    case "$arg" in
        --user)      MODE=user ;;
        --uninstall) ACTION=uninstall ;;
        -h|--help)   sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

SRC="$(cd "$(dirname "$0")" && pwd)"
die() { echo "error: $*" >&2; exit 1; }
note() { echo "  $*"; }

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

XKB="$(find_xkb_root)" || die "could not find the xkb database.
  Looked in /usr/share/X11/xkb, /usr/share/xkeyboard-config-2 and others.
  Is xkeyboard-config installed? On Arch/CachyOS: sudo pacman -S xkeyboard-config"

XML="$XKB/rules/evdev.xml"
LST="$XKB/rules/evdev.lst"
SYSTYPES="$XKB/types/complete"

if [ "$MODE" = user ]; then
    DEST="${XDG_CONFIG_HOME:-$HOME/.config}/xkb"
else
    DEST="$XKB"
    [ "$(id -u)" -eq 0 ] || die "system-wide install needs root. Run: sudo $0 $*"
fi

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

# countryList is required even though the layout is English-only: several
# desktops' "Add layout" pickers default to browsing by country rather than
# language, and an entry with no countryList never shows up there.
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
        print "        <countryList>"
        print "          <iso3166Id>US</iso3166Id>"
        print "        </countryList>"
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

# --- uninstall --------------------------------------------------------------
if [ "$ACTION" = uninstall ]; then
    rm -f "$DEST/symbols/dq" "$DEST/types/dq"
    if [ "$MODE" = user ]; then
        rm -f "$DEST/types/complete" "$DEST/rules/evdev.xml"
        rmdir --ignore-fail-on-non-empty "$DEST/symbols" "$DEST/types" "$DEST/rules" "$DEST" 2>/dev/null
    else
        unpatch_types "$SYSTYPES"; unpatch_xml "$XML"; unpatch_lst "$LST"
    fi
    echo "Removed. Switch to another layout in your keyboard settings and log out."
    exit 0
fi

# --- install ----------------------------------------------------------------
for f in dq.symbols dq.types; do
    [ -f "$SRC/$f" ] || die "missing $SRC/$f (run this script from the folder it came in)"
done

echo "xkb database: $XKB"
echo "installing to: $DEST"

mkdir -p "$DEST/symbols" "$DEST/types" || die "cannot create $DEST"
install -m 644 "$SRC/dq.symbols" "$DEST/symbols/dq" || die "cannot write $DEST/symbols/dq"
install -m 644 "$SRC/dq.types"   "$DEST/types/dq"   || die "cannot write $DEST/types/dq"
note "layout and key type installed"

if [ "$MODE" = user ]; then
    mkdir -p "$DEST/rules"
    [ -f "$SYSTYPES" ] || die "no types/complete found at $SYSTYPES"
    cp "$SYSTYPES" "$DEST/types/complete"
    patch_types "$DEST/types/complete" \
        || die "could not add the type include to $DEST/types/complete.
  Add this line yourself, just inside the outermost { } of that file:
      include \"dq\""
    cat > "$DEST/rules/evdev.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xkbConfigRegistry SYSTEM "xkb.dtd">
<xkbConfigRegistry version="1.1">
  <layoutList>
    <layout>
      <configItem>
        <name>dq</name>
        <shortDescription>dq</shortDescription>
        <description>English (Dvorak, QWERTY shortcuts)</description>
        <countryList>
          <iso3166Id>US</iso3166Id>
        </countryList>
        <languageList>
          <iso639Id>eng</iso639Id>
        </languageList>
      </configItem>
      <variantList/>
    </layout>
  </layoutList>
</xkbConfigRegistry>
EOF
    note "user registry written"
else
    for f in "$SYSTYPES" "$XML" "$LST"; do
        [ -f "$f" ] && [ ! -f "$f.pre-dq" ] && cp "$f" "$f.pre-dq"
    done
    patch_types "$SYSTYPES" \
        || die "could not add the type include to $SYSTYPES.
  Add this line yourself, just inside the outermost { } of that file:
      include \"dq\""
    patch_xml "$XML" || die "could not register the layout in $XML (no </layoutList> found)"
    patch_lst "$LST"
    note "registered in the system layout list"
fi

# --- verify -----------------------------------------------------------------
if command -v xkbcli >/dev/null 2>&1; then
    if out=$(xkbcli compile-keymap --layout dq 2>&1 >/dev/null); then
        note "keymap compiles"
    else
        echo
        echo "The files are installed but the keymap did not compile:" >&2
        echo "$out" | head -20 >&2
        exit 1
    fi
else
    note "install libxkbcommon-tools (Arch: libxkbcommon) to self-check with xkbcli"
fi

cat <<EOF

Done. Add "English (Dvorak, QWERTY shortcuts)" in your keyboard settings
(KDE: System Settings > Keyboard > Layouts), remove your old Dvorak entry,
then log out and back in.

X11 only, to try it right now without logging out:  setxkbmap dq
EOF
