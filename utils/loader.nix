# Bootloader fetcher for the NanoPi RK35xx family.
# Unpacks `idbloader.img` + `u-boot.itb` from the board-specific vendor zip.
#
# - `socPrefix` selects the zip inner directory (RK3566 boards use
#   `rk3566-nanopi-...`; defaults to "rk3568" for RK3568 boards).
# - `loaderModel` selects the board subdirectory inside the zip. It defaults
#   to `model`, but some vendors ship one zip for several board revisions
#   (e.g. R3S and R3S-LTS share `rk3566-nanopi-r3s/`), so a model definition
#   can override it while keeping its own name for outputs.
#
# Wiring via flake.nix `lib.mkLoader`:
#   boardLoader = boardLib.mkLoader { inherit pkgs; model = "r3s-lts"; };
# Raw derivation wiring:
#   bootLoader = import ./loader.nix {
#     inherit pkgs;
#     inherit (modelDef) model bootLoaderDownload;
#     socPrefix = modelDef.socPrefix or "rk3568";
#     loaderModel = modelDef.loaderModel or modelDef.model;
#   };
{
  pkgs,
  model,
  socPrefix ? "rk3568",
  loaderModel ? model,
  bootLoaderDownload,
}:
pkgs.stdenvNoCC.mkDerivation {
  name = "nanopi-${model}-loader";

  src = pkgs.fetchurl {
    inherit (bootLoaderDownload) url hash;
  };

  nativeBuildInputs = [ pkgs.unzip ];

  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  unpackPhase = ''
    unzip $src -d src
  '';

  installPhase = ''
    mkdir -p $out

    cp src/${socPrefix}-nanopi-${loaderModel}/base-files/idbloader.img $out/idbloader.img
    cp src/${socPrefix}-nanopi-${loaderModel}/base-files/u-boot.itb $out/u-boot.itb
  '';
}
