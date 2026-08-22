# Maintainer: Your Name <you@example.com>
#
# Build and install on Arch/CachyOS:
#
#     makepkg -si
#
# Expects dq.symbols, dq.types, dq-patch.sh and dq.hook beside this PKGBUILD.
#
# Note: this package installs nothing into /usr/share/X11/xkb. On Arch that
# path is a symlink owned by xkeyboard-config, and a package containing it
# fails with "exists in filesystem (owned by xkeyboard-config)". Instead the
# data files live in /usr/share/xkb-dvorak-qwerty and dq-patch.sh copies them
# into whichever directory the symlink actually points at, re-running after
# every xkeyboard-config upgrade via the pacman hook.

pkgname=xkb-dvorak-qwerty
pkgver=1.0.0
pkgrel=3
pkgdesc="Dvorak keyboard layout that reverts to QWERTY key positions under Ctrl/Alt/Super"
arch=('any')
url="https://github.com/YOURNAME/xkb-dvorak-qwerty"
license=('MIT')
depends=('xkeyboard-config')
optdepends=('libxkbcommon: lets the install hook verify the keymap compiles')
source=('dq.symbols' 'dq.types' 'dq-patch.sh' 'dq.hook')
sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP')
install="${pkgname}.install"

package() {
    install -Dm644 "$srcdir/dq.symbols"  "$pkgdir/usr/share/$pkgname/dq.symbols"
    install -Dm644 "$srcdir/dq.types"    "$pkgdir/usr/share/$pkgname/dq.types"
    install -Dm755 "$srcdir/dq-patch.sh" "$pkgdir/usr/share/$pkgname/dq-patch.sh"
    install -Dm644 "$srcdir/dq.hook"     "$pkgdir/usr/share/libalpm/hooks/95-$pkgname.hook"
}
