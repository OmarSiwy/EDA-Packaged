{ pkgs, openvaf }:

pkgs.stdenv.mkDerivation rec {
  pname = "vacask";
  version = "unstable-2026";

  src = pkgs.fetchFromGitHub {
    owner = "robtaylor";
    repo = "VACASK";
    rev = "bcd48e2dd25182f5aaa3392c4e27b4e198372744";
    hash = "sha256-/x6yJ+fklipvYbtI5rHx4d5YIpC9IJ5uhHCtWC5eJJg=";
  };

  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
    python3
    bison
    flex
  ];

  buildInputs = with pkgs; [
    suitesparse
    openblas
    boost
    tomlplusplus
  ];

  postPatch = ''
    # The Darwin branch shells out to `brew --prefix` (absent in the sandbox, so it
    # expands to "") and hardcodes ''${BREW_PREFIX}/opt/{flex,bison,suite-sparse,
    # tomlplusplus,boost}. Deleting every BREW_PREFIX line drops the whole homebrew
    # block: bison/flex then come from PATH, and SuiteSparse_DIR/TOMLPP_DIR fall back
    # to the -D cache values set in cmakeFlags below.
    sed -i '/BREW_PREFIX/d' CMakeLists.txt
    # Remove Boost_NO_SYSTEM_PATHS so nix-installed boost is found.
    sed -i 's/set(Boost_NO_SYSTEM_PATHS TRUE)//' CMakeLists.txt
    # Remove version req (nixpkgs has 1.89) and drop 'system' component
    # (boost_system is header-only in boost >=1.87, no libboost_system.so).
    sed -i 's/find_package(Boost 1.88 REQUIRED COMPONENTS filesystem process system)/find_package(Boost REQUIRED COMPONENTS filesystem process)/' CMakeLists.txt
    # Fix Boost extra link dir: cmake-found lib dir instead of manual build stage path.
    sed -i 's|set(Boost_EXTRA_LINK_DIR "''${Boost_INCLUDE_DIRS}/stage/lib")|set(Boost_EXTRA_LINK_DIR "''${Boost_LIBRARY_DIRS}")|' CMakeLists.txt
    # Remove boost_system from link libs (header-only, no .so).
    sed -i 's/boost_system boost_filesystem boost_process/boost_filesystem boost_process/' CMakeLists.txt
    # nixpkgs suitesparse puts klu.h directly in include/, not include/suitesparse/
    sed -i 's|suitesparse/klu.h|klu.h|g' include/klumatrix.h
    # nixpkgs only has suitesparse 5.13, whose long API is typed SuiteSparse_long
    # (= plain `long`), not int64_t as in suitesparse >=7. VACASK instantiates its
    # matrix templates on int64_t. On linux those are the same type so the calls
    # compile; on darwin int64_t is `long long`, a distinct type of identical size,
    # and every klu_l_* taking an index array fails to resolve. Cast at the call
    # boundary: a no-op on linux, a same-width reinterpret on darwin. The 64-bit
    # entry points are klu_l_* and, for complex values, klu_zl_*; the int32 klu_*
    # and klu_z_* calls sitting right beside them take the same AP, AI argument
    # names and must keep int32_t*, so the address matches klu_l_/klu_zl_ only.
    sed -i '/klu_z\?l_/ s/AP, AI/(SuiteSparse_long *)AP, (SuiteSparse_long *)AI/' \
      lib/klumatrix.cpp lib/klubsmatrix.cpp
    # Assert no 64-bit call was left uncast. Deliberately not a count: the first
    # version of this patch hardcoded the 5 klu_l_ sites it had found by hand and
    # sailed straight past the 3 klu_zl_ ones. Linux cannot catch that -- the cast
    # is an identity there, so it compiles either way and only darwin breaks.
    if grep -n 'klu_z\?l_.*AP, AI' lib/klumatrix.cpp lib/klubsmatrix.cpp; then
      echo "postPatch: 64-bit klu call above still takes an uncast index array"
      exit 1
    fi
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DOPENVAF_DIR=${openvaf}/bin"
    "-DTOMLPP_DIR=${pkgs.tomlplusplus}"
    "-DSuiteSparse_DIR=${pkgs.suitesparse}"
  ];

  # Upstream's own install() rules stage the OSDI device models into
  # lib/vacask/mod, which is the ONLY place `load "spice/resistor.osdi"`
  # resolves from. A hand-rolled `cp simulator/vacask` installed a simulator
  # that could not load a single device, and every deck died at its first `load`.
  # cmake's `install(TARGETS sim)` already lands $out/bin/vacask.

  meta = {
    description = "VACASK: Verilog-A Circuit Analysis Kernel";
    homepage = "https://github.com/robtaylor/VACASK";
    license = pkgs.lib.licenses.gpl2Plus;
    platforms = pkgs.lib.platforms.linux ++ pkgs.lib.platforms.darwin;
  };
}
