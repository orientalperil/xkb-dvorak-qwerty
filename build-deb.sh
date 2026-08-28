#!/bin/bash
# Builds xkb-dvorak-qwerty_<version>_all.deb from dvorak-qwerty.symbols,
# dvorak-qwerty.types and xkb-patch.sh in the current directory.
#     ./build-deb.sh              # uses VERSION below
#     ./build-deb.sh 1.2.0        # or pass a version
#
# Needs only dpkg-deb (present on any Debian/Ubuntu box).
#
# The package ships its data to /usr/share/xkb-dvorak-qwerty and lets
# xkb-patch.sh splice it into the xkb tree, exactly as the Arch package does,
# so both distributions run the same registration code. It has to work that way
# on Debian too: the variant belongs in symbols/us, a file owned by xkb-data.

set -e
VERSION="${1:-1.1.0}"
MAINTAINER="Your Name <you@example.com>"
HOMEPAGE="https://github.com/YOURNAME/xkb-dvorak-qwerty"

SRC="$(cd "$(dirname "$0")" && pwd)"
PKG="xkb-dvorak-qwerty"
BUILD="$SRC/build/$PKG"

for f in dvorak-qwerty.symbols dvorak-qwerty.types xkb-patch.sh; do
    [ -f "$SRC/$f" ] || { echo "Missing $SRC/$f"; exit 1; }
done

rm -rf "$SRC/build"
mkdir -p "$BUILD/DEBIAN" \
         "$BUILD/usr/share/$PKG" \
         "$BUILD/usr/share/doc/$PKG"

install -m 644 "$SRC/dvorak-qwerty.symbols" "$BUILD/usr/share/$PKG/dvorak-qwerty.symbols"
install -m 644 "$SRC/dvorak-qwerty.types"   "$BUILD/usr/share/$PKG/dvorak-qwerty.types"
install -m 755 "$SRC/xkb-patch.sh"          "$BUILD/usr/share/$PKG/xkb-patch.sh"
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
 Adds the keyboard variant "English (Dvorak, QWERTY shortcuts)" to the English
 (US) layout -- us(dvorak-qwerty) -- a Linux port of the macOS "Dvorak - QWERTY
 Cmd" layout. It types as standard Dvorak, but while Control, Alt or Super is
 held every letter key reverts to its QWERTY position, so Ctrl+C, Ctrl+X,
 Ctrl+V and Ctrl+Z stay where muscle memory expects them.
 .
 After installing, select the variant in System Settings -> Keyboard ->
 Layouts under English (US), or with: setxkbmap us -variant dvorak-qwerty
EOF

# Re-apply our edits whenever xkb-data is upgraded and overwrites them.
cat > "$BUILD/DEBIAN/triggers" <<'EOF'
interest-noawait /usr/share/X11/xkb/rules
interest-noawait /usr/share/X11/xkb/symbols
interest-noawait /usr/share/X11/xkb/types
EOF

cat > "$BUILD/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

case "$1" in
    configure|triggered)
        /usr/share/xkb-dvorak-qwerty/xkb-patch.sh add
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;
esac

exit 0
EOF

# Unpatching happens in prerm, not postrm: dpkg deletes the package's files --
# xkb-patch.sh among them -- before postrm runs. Not on "upgrade", since
# postinst re-adds the variant straight afterwards.
cat > "$BUILD/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

case "$1" in
    remove|deconfigure)
        [ -x /usr/share/xkb-dvorak-qwerty/xkb-patch.sh ] \
            && /usr/share/xkb-dvorak-qwerty/xkb-patch.sh remove
        ;;
esac

exit 0
EOF

chmod 755 "$BUILD/DEBIAN/postinst" "$BUILD/DEBIAN/prerm"
chmod 644 "$BUILD/DEBIAN/control" "$BUILD/DEBIAN/triggers"

OUT="$SRC/${PKG}_${VERSION}_all.deb"
dpkg-deb --build --root-owner-group "$BUILD" "$OUT"
echo
echo "Built $OUT"
echo "Test locally with:  sudo apt install ./$(basename "$OUT")"
