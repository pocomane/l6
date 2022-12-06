#!/bin/sh
set -xe

skiperr(){
  echo "skipping non fatal error" 1>&2
}

PRJDIR="$(readlink -f "$(dirname "$0")")"

cd "$PRJDIR"

BUILDDIR="$PRJDIR/build"
CMAKEOPT=" -D CMAKE_SYSTEM_PREFIX_PATH='$BUILDDIR' -D CMAKE_PREFIX_PATH='$BUILDDIR' -D BOOST_ROOT:PATHNAME='$BUILDDIR' -D CMAKE_INSTALL_PREFIX='$BUILDDIR' "
export CFLAGS=" -isystem $BUILDDIR/include -O2 -Wall "
export CPPFLAGS=" -isystem $BUILDDIR/include -O2 -Wall "
export LDFLAGS=" -L$BUILDDIR/lib "

mkdir -p "$BUILDDIR"
cd "$BUILDDIR"
mkdir -p bin lib include share

cd "$BUILDDIR"
MODULE="gcc-musl"
echo "downloading $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  curl -sL https://musl.cc/x86_64-linux-musl-native.tgz --output gccmusl.tgz
  tar -xzf gccmusl.tgz
  touch "$BUILDDIR/$MODULE.download.done"
fi
export PATH="$BUILDDIR/x86_64-linux-musl-native/bin;$PATH"
export CC="$BUILDDIR/x86_64-linux-musl-native/bin/gcc  -isystem $BUILDDIR/include "
export CXX="$BUILDDIR/x86_64-linux-musl-native/bin/g++"
export STRIP="$BUILDDIR/x86_64-linux-musl-native/bin/strip"

cd "$BUILDDIR"
MODULE="lua"
echo "building $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  curl -sL https://www.lua.org/ftp/lua-5.4.4.tar.gz --output lua.tar.gz
  tar -xzf lua.tar.gz
  mv lua-* "$MODULE"/
  touch "$BUILDDIR/$MODULE.download.done"
fi
cd "$MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.build.done" 2> /dev/null)" ]; then
  cd src
  # make posix
  $CC -std=gnu99 -O2 -Wall -Wextra -DLUA_COMPAT_5_3 -DLUA_USE_POSIX -c *.c
  rm lua.o luac.o
  ar -crs liblua.a *.o
  cd ..
  cp src/lua.h src/lauxlib.h src/luaconf.h src/lualib.h "$BUILDDIR"/include || die "can not build $MODULE"
  cp src/liblua.* "$BUILDDIR"/lib || die "can not build $MODULE"
  touch "$BUILDDIR/$MODULE.build.done"
fi

cd "$BUILDDIR"
MODULE="zlib"
echo "building $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  curl -sL http://zlib.net/zlib-1.2.13.tar.gz --output zlib.tar.gz
  tar -xzf zlib.tar.gz
  mv zlib-1* "$MODULE"/
  touch "$BUILDDIR/$MODULE.download.done"
fi
cd "$MODULE"
mkdir -p build
cd build
if [ -z "$(ls "$BUILDDIR/$MODULE.prepare.done" 2> /dev/null)" ]; then
  cmake .. $CMAKEOPT
  touch "$BUILDDIR/$MODULE.prepare.done"
fi
if [ -z "$(ls "$BUILDDIR/$MODULE.build.done" 2> /dev/null)" ]; then
  make VERBOSE=1
  make install
  touch "$BUILDDIR/$MODULE.build.done"
fi

cd "$BUILDDIR"
MODULE="libpng"
echo "building $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  git clone https://github.com/glennrp/libpng
  touch "$BUILDDIR/$MODULE.download.done"
fi
cd "$MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.prepare.done" 2> /dev/null)" ]; then
  ./configure --prefix="$BUILDDIR" --host="x86_64-linux-musl"
  touch "$BUILDDIR/$MODULE.prepare.done"
fi
if [ -z "$(ls "$BUILDDIR/$MODULE.build.done" 2> /dev/null)" ]; then
  make VERBOSE=1
  make install
  touch "$BUILDDIR/$MODULE.build.done"
fi

cd "$BUILDDIR"
MODULE="eigen"
echo "building $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  git clone https://gitlab.com/libeigen/eigen
  touch "$BUILDDIR/$MODULE.download.done"
fi
cd "$MODULE"
mkdir -p build
cd build
if [ -z "$(ls "$BUILDDIR/$MODULE.prepare.done" 2> /dev/null)" ]; then
  cmake .. $CMAKEOPT
  touch "$BUILDDIR/$MODULE.prepare.done"
fi
if [ -z "$(ls "$BUILDDIR/$MODULE.build.done" 2> /dev/null)" ]; then
  make VERBOSE=1
  make install
  touch "$BUILDDIR/$MODULE.build.done"
fi

cd "$BUILDDIR"
MODULE="boost"
echo "building $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  curl -sL https://boostorg.jfrog.io/artifactory/main/release/1.80.0/source/boost_1_80_0.tar.gz --output boost.tar.gz
  tar -xzf boost.tar.gz
  mv boost_* "$MODULE"/
  touch "$BUILDDIR/$MODULE.download.done"
fi
cd "$MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.prepare.done" 2> /dev/null)" ]; then
  ./bootstrap.sh --without-libraries=python
  cp project-config.jam project-config.jam.orig
  touch "$BUILDDIR/$MODULE.prepare.done"
fi
if [ -z "$(ls "$BUILDDIR/$MODULE.build.done" 2> /dev/null)" ]; then
  cp project-config.jam.orig project-config.jam
  echo "using gcc : my : $CXX ;" >> project-config.jam
  ./b2 -d 2 install --prefix="$BUILDDIR" --toolset=gcc-my
  touch "$BUILDDIR/$MODULE.build.done"
fi

cd "$BUILDDIR"
MODULE="libfive"
echo "building $MODULE"
if [ -z "$(ls "$BUILDDIR/$MODULE.download.done" 2> /dev/null)" ]; then
  git clone https://github.com/libfive/libfive
  cd libfive
  git checkout 6f844b12188b607d1364eb7742d905d303a5ebed
  cd ..
  set -e
  sed -i '/march=native/d' libfive/CMakeLists.txt
  echo '' >>  libfive/libfive/src/CMakeLists.txt
  echo 'add_library(libfive-static STATIC $<TARGET_OBJECTS:libfive>)' >>  libfive/libfive/src/CMakeLists.txt
  echo 'if (UNIX)' >>  libfive/libfive/src/CMakeLists.txt
  echo '  install(TARGETS libfive-static DESTINATION lib)' >>  libfive/libfive/src/CMakeLists.txt
  echo 'endif(UNIX)' >>  libfive/libfive/src/CMakeLists.txt
  echo '' >>  libfive/libfive/stdlib/CMakeLists.txt
  echo 'add_library(libfive-stdlib-static STATIC $<TARGET_OBJECTS:libfive>)' >>  libfive/libfive/stdlib/CMakeLists.txt
  echo 'if (UNIX)' >>  libfive/libfive/stdlib/CMakeLists.txt
  echo '  install(TARGETS libfive-stdlib-static DESTINATION lib)' >>  libfive/libfive/stdlib/CMakeLists.txt
  echo 'endif(UNIX)' >>  libfive/libfive/stdlib/CMakeLists.txt

  set +e
  touch "$BUILDDIR/$MODULE.download.done"
fi
cd "$MODULE"
mkdir -p build
cd build
if [ -z "$(ls "$BUILDDIR/$MODULE.prepare.done" 2> /dev/null)" ]; then
  cmake .. $CMAKEOPT -D BUILD_STUDIO_APP=OFF -D BUILD_GUILE_BINDINGS=OFF -D BUILD_PYTHON_BINDINGS=OFF
  touch "$BUILDDIR/$MODULE.prepare.done"
fi
if [ -z "$(ls "$BUILDDIR/$MODULE.build.done" 2> /dev/null)" ]; then
  make VERBOSE=1
  make install
  touch "$BUILDDIR/$MODULE.build.done"
fi

cd "$BUILDDIR"
MODULE="l6"
echo "building $MODULE"
mkdir -p "$MODULE"
cd "$MODULE"
LDFLAGS=" -static $LDFLAGS $BUILDDIR/lib/liblua.a  $BUILDDIR/lib/liblibfive-static.a  $BUILDDIR/lib/liblibfive-stdlib-static.a $BUILDDIR/lib/*.a $BUILDDIR/lib/libpng16.a $BUILDDIR/lib/libz.a -lm "
$CC $CFLAGS -g -c -o libfive_lua_bind.o "$PRJDIR"/libfive_lua_bind.c
$CC $CFLAGS -g -c -o main.o "$PRJDIR"/main.c
$CXX $CFLAGS -g -o l6.exe *.o $LDFLAGS
$STRIP l6.exe
cp l6.exe "$BUILDDIR/bin"
ls -lha "$BUILDDIR/bin/l6.exe"
ldd "$BUILDDIR/bin/l6.exe"

cd "$BUILDDIR"
MODULE="release"
echo "building $MODULE"
mkdir -p "$MODULE"
cd "$MODULE"
rm -fR *
cp ../bin/l6.exe ./l6-amd64-linux.exe

echo "all is right"

