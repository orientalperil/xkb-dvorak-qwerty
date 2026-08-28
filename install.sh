#!/bin/bash
# Installs the us(dvorak-qwerty) keyboard variant: Dvorak that reverts to
# QWERTY key positions while Control, Alt or Super is held.
#
#     sudo ./install.sh              system-wide (X11 + Wayland, shows in GUI)
#          ./install.sh --user       into ~/.config/xkb (Wayland only, no root)
#     sudo ./install.sh --uninstall
#          ./install.sh --user --uninstall
#
# Works on any distro that ships xkeyboard-config: Arch/CachyOS, Debian/Ubuntu,
# Fedora, openSUSE, Alpine, Gentoo, NixOS (with caveats).
#
# The actual editing is done by xkb-patch.sh, the same script the Arch and
# Debian packages ship; this script only decides which tree it is pointed at
# and, for --user, builds that tree first.

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
PATCH="$SRC/xkb-patch.sh"
die() { echo "error: $*" >&2; exit 1; }
note() { echo "  $*"; }

[ -x "$PATCH" ] || die "missing $PATCH (run this script from the folder it came in)"

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

if [ "$MODE" = user ]; then
    DEST="${XDG_CONFIG_HOME:-$HOME/.config}/xkb"
else
    DEST="$XKB"
    [ "$(id -u)" -eq 0 ] || die "system-wide install needs root. Run: sudo $0 $*"
fi

# --- uninstall --------------------------------------------------------------
if [ "$ACTION" = uninstall ]; then
    if [ "$MODE" = user ]; then
        rm -f "$DEST/symbols/us" "$DEST/types/dvorak-qwerty" \
              "$DEST/types/complete" "$DEST/rules/evdev.xml"
        rmdir --ignore-fail-on-non-empty "$DEST/symbols" "$DEST/types" "$DEST/rules" "$DEST" 2>/dev/null
    else
        "$PATCH" remove "$XKB"
    fi
    echo "Removed. Switch to another layout in your keyboard settings and log out."
    exit 0
fi

# --- install ----------------------------------------------------------------
for f in dvorak-qwerty.symbols dvorak-qwerty.types; do
    [ -f "$SRC/$f" ] || die "missing $SRC/$f (run this script from the folder it came in)"
done

echo "xkb database: $XKB"
echo "installing to: $DEST"

if [ "$MODE" = user ]; then
    # A per-user file replaces the system one rather than merging with it, so
    # the tree has to start as copies of the system symbols/us and
    # types/complete, which are then edited in place.
    mkdir -p "$DEST/symbols" "$DEST/types" "$DEST/rules" || die "cannot create $DEST"
    [ -f "$XKB/symbols/us" ]   || die "no symbols/us found under $XKB"
    [ -f "$XKB/types/complete" ] || die "no types/complete found under $XKB"
    cp "$XKB/symbols/us"     "$DEST/symbols/us"
    cp "$XKB/types/complete" "$DEST/types/complete"
    # A minimal registry: xkb-patch.sh fills the empty variantList in.
    cat > "$DEST/rules/evdev.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xkbConfigRegistry SYSTEM "xkb.dtd">
<xkbConfigRegistry version="1.1">
  <layoutList>
    <layout>
      <configItem>
        <name>us</name>
        <shortDescription>en</shortDescription>
        <description>English (US)</description>
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
    note "user copies of symbols/us and types/complete written"
else
    for f in "$XKB/symbols/us" "$XKB/types/complete" "$XKB/rules/evdev.xml" "$XKB/rules/evdev.lst"; do
        [ -f "$f" ] && [ ! -f "$f.pre-dvorak-qwerty" ] && cp "$f" "$f.pre-dvorak-qwerty"
    done
fi

"$PATCH" add "$DEST" || die "could not register the variant under $DEST"
note "variant and key type installed"

# --- verify -----------------------------------------------------------------
if command -v xkbcli >/dev/null 2>&1; then
    if out=$(xkbcli compile-keymap --layout us --variant dvorak-qwerty 2>&1 >/dev/null); then
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

Done. Add "English (Dvorak, QWERTY shortcuts)" in your keyboard settings --
it is listed under English (US) -- remove your old Dvorak entry, then log out
and back in.

X11 only, to try it right now without logging out:
    setxkbmap us -variant dvorak-qwerty
EOF
