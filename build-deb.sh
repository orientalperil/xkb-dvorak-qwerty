#!/bin/bash
# Builds xkb-dvorak-qwerty_<version>_all.deb from dq.symbols and dq.types
# in the current directory.
#     ./build-deb.sh              # uses VERSION below
#     ./build-deb.sh 1.1.0        # or pass a version
#
# Needs only dpkg-deb (present on any Debian/Ubuntu box).
#
# The layout is named "dq" so that desktop keyboard indicators show a short
# label, the same way the US layout shows "us". Plasma labels the indicator with
# the layout name, not the description, so a long name overflows the tray.

set -e
VERSION="${1:-1.0.0}"
MAINTAINER="Your Name <you@example.com>"
HOMEPAGE="https://github.com/YOURNAME/xkb-dvorak-qwerty"

SRC="$(cd "$(dirname "$0")" && pwd)"
PKG="xkb-dvorak-qwerty"
BUILD="$SRC/build/$PKG"

for f in dq.symbols dq.types; do
    [ -f "$SRC/$f" ] || { echo "Missing $SRC/$f"; exit 1; }
done

rm -rf "$SRC/build"
mkdir -p "$BUILD/DEBIAN" \
         "$BUILD/usr/share/X11/xkb/symbols" \
         "$BUILD/usr/share/X11/xkb/types" \
         "$BUILD/usr/share/doc/$PKG"

install -m 644 "$SRC/dq.symbols"              "$BUILD/usr/share/X11/xkb/symbols/dq"
install -m 644 "$SRC/dq.types"                "$BUILD/usr/share/X11/xkb/types/dq"
[ -f "$SRC/README.md" ] && install -m 644 "$SRC/README.md" "$BUILD/usr/share/doc/$PKG/README.md"

cat > "$BUILD/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: x11
Priority: optional
Architecture: all
Depends: xkb-data
Maintainer: $MAINTAINER
Homepage: $HOMEPAGE
Description: Dvorak layout with QWERTY shortcut key positions
 Adds the keyboard layout "English (Dvorak, QWERTY shortcuts)", a Linux port
 of the macOS "Dvorak - QWERTY Cmd" layout. It types as standard Dvorak, but
 while Control, Alt or Super is held every letter key reverts to its QWERTY
 position, so Ctrl+C, Ctrl+X, Ctrl+V and Ctrl+Z stay where muscle memory
 expects them.
 .
 The layout is named "dq", so the keyboard indicator shows a short "DQ" label.
 .
 After installing, select the layout in System Settings -> Keyboard ->
 Layouts, or with: setxkbmap dq
EOF

# Re-apply our registry edits whenever xkb-data is upgraded and overwrites them.
cat > "$BUILD/DEBIAN/triggers" <<'EOF'
interest-noawait /usr/share/X11/xkb/rules
interest-noawait /usr/share/X11/xkb/types
EOF

cat > "$BUILD/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

XKB=/usr/share/X11/xkb
XML="$XKB/rules/evdev.xml"
LST="$XKB/rules/evdev.lst"
TYPES="$XKB/types/complete"

# xkb-data owns evdev.xml, evdev.lst and types/complete, so we cannot ship our
# own copies -- we patch them in place. Every patch is idempotent and is
# re-applied by a dpkg trigger when xkb-data is upgraded.

patch_types() {
    grep -q '^[[:space:]]*include "dq"' "$TYPES" && return 0
    sed -i '0,/include "basic"/s//include "basic"\n    include "dq"/' "$TYPES"
}

# countryList is required even though the layout is English-only: several
# desktops' "Add layout" pickers default to browsing by country rather than
# language, and an entry with no countryList never shows up there.
patch_xml() {
    grep -q '<name>dq</name>' "$XML" && return 0
    tmp=$(mktemp)
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
    ' "$XML" > "$tmp"
    cat "$tmp" > "$XML"
    rm -f "$tmp"
}

patch_lst() {
    grep -q '^  dq ' "$LST" && return 0
    tmp=$(mktemp)
    awk '
      /^! layout$/ { inlayout = 1; print; next }
      inlayout && /^$/ && !done {
        print "  dq              English (Dvorak, QWERTY shortcuts)"
        done = 1
        inlayout = 0
      }
      /^! variant$/ { invariant = 1; print; next }
      invariant && /^$/ && !vdone {
        print "  basic           dq: Default"
        vdone = 1
        invariant = 0
      }
      { print }
    ' "$LST" > "$tmp"
    cat "$tmp" > "$LST"
    rm -f "$tmp"
}

case "$1" in
    configure|triggered)
        [ -f "$TYPES" ] && patch_types
        [ -f "$XML" ]   && patch_xml
        [ -f "$LST" ]   && patch_lst
        if command -v xkbcli >/dev/null 2>&1; then
            xkbcli compile-keymap --layout dq >/dev/null 2>&1 \
                || echo "xkb-dvorak-qwerty: warning: keymap did not compile" >&2
        fi
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;
esac

exit 0
EOF

cat > "$BUILD/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e

XKB=/usr/share/X11/xkb
XML="$XKB/rules/evdev.xml"
LST="$XKB/rules/evdev.lst"
TYPES="$XKB/types/complete"

case "$1" in
    remove|purge)
        [ -f "$TYPES" ] && sed -i '/^[[:space:]]*include "dq"/d' "$TYPES"
        [ -f "$LST" ]   && sed -i '/^  dq /d;/^  basic           dq: /d' "$LST"
        if [ -f "$XML" ]; then
            tmp=$(mktemp)
            awk '
              /<layout>/ { buf = $0; n = 1; next }
              n {
                buf = buf "\n" $0
                if (/<name>dq<\/name>/) drop = 1
                if (/<\/layout>/) {
                  if (!drop) print buf
                  n = 0; drop = 0; buf = ""
                }
                next
              }
              { print }
            ' "$XML" > "$tmp"
            cat "$tmp" > "$XML"
            rm -f "$tmp"
        fi
        ;;
esac

exit 0
EOF

chmod 755 "$BUILD/DEBIAN/postinst" "$BUILD/DEBIAN/postrm"
chmod 644 "$BUILD/DEBIAN/control" "$BUILD/DEBIAN/triggers"

OUT="$SRC/${PKG}_${VERSION}_all.deb"
dpkg-deb --build --root-owner-group "$BUILD" "$OUT"
echo
echo "Built $OUT"
echo "Test locally with:  sudo apt install ./$(basename "$OUT")"
