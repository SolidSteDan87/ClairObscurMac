#!/bin/zsh
# Compile Wine (sources CrossOver 26.3.0 / Wine 11.0) pour x86_64, en mode wow64.
#  1. outils de compilation de Wine (widl, winebuild, wrc...) en arm64 natif
#  2. Wine lui-même en x86_64 par compilation croisée, avec ces outils
# Résultat : dist/wine
set -euo pipefail

ROOT=${0:A:h:h}
SRC=$ROOT/src/sources/wine
DEPS=$ROOT/deps/x86_64
TOOLS=$ROOT/build/wine-tools
BUILD=$ROOT/build/wine-x86_64
DIST=$ROOT/dist/wine
JOBS=$(sysctl -n hw.ncpu)

export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MACOSX_DEPLOYMENT_TARGET=14.0

step() { print -P "%F{cyan}==> $1%f" }

step "Correctifs maison (patches/)"
for p in $ROOT/patches/*.patch(N); do
  if patch -p0 -N --dry-run -s -d $SRC < $p >/dev/null 2>&1; then
    patch -p0 -N -s -d $SRC < $p && print "  appliqué : ${p:t}"
  else
    print "  déjà appliqué : ${p:t}"
  fi
done

step "Outils Wine (arm64 natif)"
mkdir -p $TOOLS && cd $TOOLS
# sfnt2fon (polices bitmap .fon) a besoin de FreeType arm64 : brew install freetype
if ! grep -q "^#define SONAME_LIBFREETYPE" include/config.h 2>/dev/null; then
  env -u CC -u CFLAGS PKG_CONFIG_LIBDIR=/nonexistent \
    FREETYPE_CFLAGS="-I/opt/homebrew/opt/freetype/include/freetype2" \
    FREETYPE_LIBS="-L/opt/homebrew/opt/freetype/lib -lfreetype" \
    $SRC/configure --disable-tests --without-mingw --without-x --with-freetype \
      --without-gnutls --without-sdl --without-vulkan --without-opencl --without-cups \
      --without-gstreamer --without-ffmpeg --without-pcap --without-unwind
  rm -f tools/sfnt2fon/sfnt2fon tools/sfnt2fon/sfnt2fon.o
fi
make -j$JOBS __tooldeps__

step "Wine x86_64 (compilation croisée)"
mkdir -p $BUILD && cd $BUILD
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export CFLAGS="-O2"
export CROSSCFLAGS="-O2"
export LDFLAGS="-Wl,-headerpad_max_install_names -Wl,-rpath,@loader_path/../../../lib"
export PKG_CONFIG_LIBDIR=$DEPS/lib/pkgconfig
export PKG_CONFIG_PATH=
# En compilation croisée, configure cherche x86_64-apple-darwin-pkg-config :
# on lui donne explicitement le pkg-config de Homebrew (qui ne voit que $DEPS).
export PKG_CONFIG=/opt/homebrew/bin/pkg-config

if [[ ! -f Makefile || ${RECONFIGURE:-0} == 1 ]]; then
  $SRC/configure \
    --host=x86_64-apple-darwin --build=aarch64-apple-darwin \
    --with-wine-tools=$TOOLS \
    --prefix=$DIST \
    --enable-archs=i386,x86_64 \
    --disable-tests \
    --with-mingw --with-coreaudio --with-freetype --with-gnutls --with-sdl \
    --without-cups \
    --without-x --without-wayland --without-alsa --without-pulse --without-oss \
    --without-capi --without-dbus --without-fontconfig --without-gphoto \
    --without-gssapi --without-krb5 --without-gstreamer --without-ffmpeg \
    --without-inotify --without-netapi --without-pcap --without-pcsclite \
    --without-sane --without-udev --without-unwind --without-usb --without-v4l2 \
    --without-vulkan --without-opencl \
    2>&1 | tee $ROOT/logs/wine-configure.log
fi

make -j$JOBS
make install
# Wine 11 installe le lanceur dans lib/wine/x86_64-unix/ : raccourci bin/wine
ln -sf ../lib/wine/x86_64-unix/wine $DIST/bin/wine

step "Bibliothèques x86_64 embarquées"
mkdir -p $DIST/lib
cp -a $DEPS/lib/*.dylib $DIST/lib/
# Rend les bibliothèques déplaçables (autre Mac, autre dossier) : leurs chemins
# internes pointent vers deps/ ; on les remplace par @loader_path.
for lib in $DIST/lib/*.dylib(.); do
  install_name_tool -id @loader_path/${lib:t} $lib 2>/dev/null
  for dep in $(otool -L $lib | awk -v d="$DEPS/lib/" 'index($1, d) == 1 {print $1}'); do
    install_name_tool -change $dep @loader_path/${dep:t} $lib 2>/dev/null
  done
  codesign -f -s - $lib 2>/dev/null
done

print -P "%F{green}Wine installé dans $DIST%f"
$DIST/bin/wine --version || true
