{ pkgs, openvaf }:

# ASAP7 7 nm FinFET predictive PDK (ASU/ARM, BSD-3-Clause), as a PDK root ($ASAP7_ROOT):
#
#   models/hspice/       the PDK's own BSIM-CMG 107 cards (HSPICE, level = 72), as shipped
#   models/bsimcmg/      BSIM-CMG 111.0.0 Verilog-A (UC Berkeley, ECL-2.0), 4-terminal
#   models/cards/        the cards rewritten for that module (nix/asap7/espice.py)
#   models/espice/asap7.lib    `.lib ... tt|ff|ss` for ESPice (VerA compiles the VA, no OSDI)
#   models/ngspice/asap7.lib   the same for ngspice, with models/osdi/bsimcmg.osdi
#   cdslib/ docs/        layer maps, tech, DRM (docs/asap7_drm_201207a.pdf)
#   klayout/             asap7.drc (open KLayout DRC, from OpenROAD-flow-scripts' asap7.lydrc,
#                        BSD-2, with fixes: nix/asap7/klayout_drc.py), asap7.lyp, asap7.lyt
#
# Not here: the Calibre DRC/LVS/PEX decks (an asap.asu.edu download, not in the GitHub
# repo, whose calibre/ is only placeholder READMEs and dangling run-set links) and the
# standard cells (a 2.8 GB repo; OpenROAD-flow-scripts vendors its own copy in
# platforms/asap7).
let
  src = pkgs.fetchFromGitHub {
    owner = "The-OpenROAD-Project";
    repo = "asap7_pdk_r1p7";
    rev = "58d72c9d291e186a77468586ab0c43d8a21eda6a";
    hash = "sha256-/U+NHOPT+qL1I2h2q4WudvLYNxQmCwxtJ9KANe9PPpw=";
  };
  # OpenROAD-flow-scripts flow/platforms/asap7: KLayout DRC deck and layer/tech files
  orfs = name: hash: pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/d65ce6550b310bc54965471f1a1408cbe910b562/flow/platforms/asap7/${name}";
    inherit hash;
  };
  lydrc = orfs "drc/asap7.lydrc" "sha256-3HjM2LKzBJjyXviFwsKKnCpWXDjLMKh0YCgsijbHdl0=";
  lyp = orfs "KLayout/asap7.lyp" "sha256-F8d6vzTcKxhtItyE5eDcOBCQkTelU6hd1qrdt3kiuwQ=";
  lyt = orfs "KLayout/asap7.lyt" "sha256-wNlYemNspUJGzb297TkZp+Se/PUJBHADNUMgF6bY+6I=";
in
# stdenv, not stdenvNoCC: openvaf-r links the .osdi with cc
pkgs.stdenv.mkDerivation {
  pname = "asap7";
  version = "1.7-unstable-2024-07-18";
  inherit src;

  nativeBuildInputs = [ pkgs.python3 openvaf ];

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;   # data plus one .osdi; nothing to patchelf

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    rm -rf $out/calibre $out/Calibre_Usage_Instructions.txt
    python3 ${./asap7/espice.py} . ${openvaf.src}/integration_tests/BSIMCMG $out
    mkdir -p $out/models/osdi
    (cd $out/models/bsimcmg && openvaf-r bsimcmg.va -o $out/models/osdi/bsimcmg.osdi)
    # openvaf-r exits 0 when its link step fails, leaving only the .o files
    test -f $out/models/osdi/bsimcmg.osdi
    rm -f $out/models/osdi/bsimcmg.o $out/models/osdi/bsimcmg.o[0-9]*
    mkdir -p $out/klayout
    python3 ${./asap7/klayout_drc.py} ${lydrc} $out/klayout/asap7.drc
    cp ${lyp} $out/klayout/asap7.lyp
    cp ${lyt} $out/klayout/asap7.lyt
    runHook postInstall
  '';

  meta = {
    description = "ASAP7 predictive 7 nm FinFET PDK with BSIM-CMG models for ESPice and ngspice";
    homepage = "https://github.com/The-OpenROAD-Project/asap7_pdk_r1p7";
    # PDK: BSD-3-Clause. models/bsimcmg (and the .osdi built from it): ECL-2.0.
    # klayout/asap7.drc: BSD-2 (laurentc2); asap7.lyp/.lyt: ORFS, BSD-3.
    license = with pkgs.lib.licenses; [ bsd3 ecl20 bsd2 ];
    platforms = pkgs.lib.platforms.all;
  };
}
