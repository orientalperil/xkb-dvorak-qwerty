# Maintainer: Your Name <you@example.com>
#
# Build and install on Arch/CachyOS:
#
#     makepkg -si
#
# Expects dvorak-qwerty.symbols, dvorak-qwerty.types, xkb-patch.sh and
# xkb-dvorak-qwerty.hook beside this PKGBUILD.
#
# Note: this package installs nothing into /usr/share/X11/xkb. The variant has
# to be spliced into symbols/us, which belongs to xkeyboard-config; and on Arch
# that path is a symlink owned by xkeyboard-config, so a package containing it
# fails with "exists in filesystem (owned by xkeyboard-config)". Instead the
# data files live in /usr/share/xkb-dvorak-qwerty and xkb-patch.sh splices them
# into whichever directory the symlink actually points at, re-running after
# every xkeyboard-config upgrade via the pacman hook.

pkgname=xkb-dvorak-qwerty
pkgver=1.1.0
pkgrel=1
pkgdesc="Dvorak keyboard variant that reverts to QWERTY key positions under Ctrl/Alt/Super"
arch=('any')
url="https://github.com/YOURNAME/xkb-dvorak-qwerty"
license=('MIT')
depends=('xkeyboard-config')
optdepends=('libxkbcommon: lets the install hook verify the keymap compiles')
source=('dvorak-qwerty.symbols' 'dvorak-qwerty.types' 'xkb-patch.sh' 'xkb-dvorak-qwerty.hook')
sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP')
install="${pkgname}.install"

package() {
    install -Dm644 "$srcdir/dvorak-qwerty.symbols" "$pkgdir/usr/share/$pkgname/dvorak-qwerty.symbols"
    install -Dm644 "$srcdir/dvorak-qwerty.types"   "$pkgdir/usr/share/$pkgname/dvorak-qwerty.types"
    install -Dm755 "$srcdir/xkb-patch.sh"          "$pkgdir/usr/share/$pkgname/xkb-patch.sh"
    install -Dm644 "$srcdir/xkb-dvorak-qwerty.hook" "$pkgdir/usr/share/libalpm/hooks/95-$pkgname.hook"
}
