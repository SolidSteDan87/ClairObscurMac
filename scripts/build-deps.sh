#!/bin/zsh
# Compile les bibliothèques x86_64 dont Wine a besoin.
# Les outils Apple de macOS 27 sont arm64 uniquement : on compile donc en
# natif arm64 avec -arch x86_64 (compilation croisée). Les programmes de test
# de configure tournent quand même, via Rosetta.
# Résultat : deps/x86_64/{lib,include,...}
set -euo pipefail

ROOT=${0:A:h:h}
TARBALLS=$ROOT/deps/tarballs
WORK=$ROOT/deps/work
PREFIX=$ROOT/deps/x86_64
JOBS=$(sysctl -n hw.ncpu)

export MACOSX_DEPLOYMENT_TARGET=14.0
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export CFLAGS="-O2"
export CXXFLAGS="-O2"
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib -Wl,-headerpad_max_install_names"
# Ne jamais laisser configure trouver les libs arm64 de /opt/homebrew.
export PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig
export PKG_CONFIG_PATH=
export PATH="/opt/homebrew/opt/bison/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"

HOST=x86_64-apple-darwin
mkdir -p $WORK $PREFIX

unpack() {
  local tarball=$1 dir=$2
  rm -rf $WORK/$dir
  tar -xf $TARBALLS/$tarball -C $WORK
  cd $WORK/$dir
}

step() { print -P "%F{cyan}==> $1%f" }

step "gmp"
unpack gmp-6.3.0.tar.xz gmp-6.3.0
# --host générique : pas d'assembleur spécifique au CPU détecté sous Rosetta.
./configure --prefix=$PREFIX --host=$HOST --build=$HOST --enable-shared --disable-static
make -j$JOBS && make install

step "nettle"
unpack nettle-3.10.1.tar.gz nettle-3.10.1
./configure --prefix=$PREFIX --host=$HOST --build=$HOST --enable-shared --disable-static \
  --disable-documentation --disable-openssl --libdir=$PREFIX/lib
make -j$JOBS && make install

step "gnutls"
unpack gnutls-3.8.9.tar.xz gnutls-3.8.9
./configure --prefix=$PREFIX --host=$HOST --build=$HOST --enable-shared --disable-static \
  --with-included-libtasn1 --with-included-unistring --without-p11-kit \
  --without-idn --without-zstd --without-brotli --without-tpm --without-tpm2 \
  --disable-doc --disable-tests --disable-tools --disable-cxx --disable-nls \
  --disable-guile --disable-openssl-compatibility
make -j$JOBS && make install

step "freetype"
unpack freetype-2.13.3.tar.xz freetype-2.13.3
./configure --prefix=$PREFIX --host=$HOST --build=$HOST --enable-shared --disable-static \
  --with-zlib=yes --with-bzip2=yes --with-png=no --with-harfbuzz=no --with-brotli=no
make -j$JOBS && make install

step "SDL2"
unpack SDL2-2.32.8.tar.gz SDL2-2.32.8
./configure --prefix=$PREFIX --host=$HOST --build=$HOST --enable-shared --disable-static \
  --disable-video-x11 --disable-video-wayland --disable-video-opengles
make -j$JOBS && make install

step "Vérification des architectures"
for lib in $PREFIX/lib/*.dylib(.); do
  print "$(lipo -archs $lib)  ${lib:t}"
done
print -P "%F{green}Dépendances prêtes dans $PREFIX%f"
