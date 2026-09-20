# Board-support flake: bootloader, board modules and an SD image assembler
# for NanoPi R3S / R3S-LTS (RK3566). The public library lives in ./lib
# (exposed as `lib`); this file only wires inputs to outputs.
{
  description = "NixOS board support for NanoPi R3S / R3S-LTS (RK3566)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      models = import ./models;
      boardLib = import ./lib { inherit nixpkgs; };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages = pkgs.lib.mapAttrs' (modelName: modelDef: {
          name = "nanopi-${modelName}-loader";
          value = boardLib.mkLoader { inherit pkgs; model = modelName; };
        }) models;
      }
    ))
    // {
      nixosModules =
        (builtins.mapAttrs (modelName: modelDef: import ./modules/model-specific.nix modelDef) models)
        // {
          register-nix-paths = import ./modules/register-nix-paths.nix;
          expand-root-partition = import ./modules/expand-root-partition.nix;
        };

      lib = boardLib;
    };
}
