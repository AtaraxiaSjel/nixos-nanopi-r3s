# Public library of this flake (exposed as `lib`).
# Parameterized by `nixpkgs` (flake input), which the image assembler needs
# to reference nixpkgs builders by store path.
{ nixpkgs }:
let
  models = import ../models;

  modelDefFor = model: models.${model} or (throw "nixos-nanopi-r3s: unknown model '${model}', known: ${builtins.concatStringsSep ", " (builtins.attrNames models)}");

  mkLoaderFor =
    pkgs: modelDef:
    import ../utils/loader.nix {
      inherit pkgs;
      inherit (modelDef) model bootLoaderDownload;
      socPrefix = modelDef.socPrefix or "rk3568";
      loaderModel = modelDef.loaderModel or modelDef.model;
    };

  mkImageFor =
    {
      pkgs,
      modelDef,
      system,
      fs ? "btrfs",
      imageName,
      imageSize ? null,
      partStart ? "16M",
      bootSizeMiB ? 512,
      bootLabel ? "disk-main-boot",
      partLabel ? "disk-main-root",
      volumeLabel ? "NIXOS",
      bootVolumeLabel ? "BOOT",
    }:
    import ../utils/mk-image.nix {
      inherit
        pkgs
        nixpkgs
        modelDef
        system
        fs
        imageName
        imageSize
        partStart
        bootSizeMiB
        bootLabel
        partLabel
        volumeLabel
        bootVolumeLabel
        ;
    };

  mkBootloaderCmds =
    {
      loader,
      image,
      bs ? "4K",
      idbloaderSeek ? 8,
      ubootSeek ? 2048,
    }:
    ''
      dd if=${loader}/idbloader.img of=${image} conv=notrunc bs=${bs} seek=${toString idbloaderSeek}
      dd if=${loader}/u-boot.itb of=${image} conv=notrunc bs=${bs} seek=${toString ubootSeek}
    '';
in
{
  inherit models;

  mkLoader =
    { pkgs, model }:
    mkLoaderFor pkgs (modelDefFor model);

  mkExtraPostVM =
    { loader, imageName }:
    mkBootloaderCmds {
      inherit loader;
      image = "$out/${imageName}.raw";
    };

  # Factory SD image from an EXTERNAL full system (must expose .config,
  # i.e. nixosConfigurations.<host>). `fs` is "btrfs" or "ext4" (rootfs
  # built by nixpkgs, nothing fs-specific is vendored here). Layout: 16M
  # bootloader gap, FAT32 /boot, <fs> rootfs (see ../utils/mk-image.nix
  # header). Geometry defaults mirror the downstream disko declaration —
  # keep them in sync.
  # The external system should import nixosModules.register-nix-paths for
  # first-boot store registration; ext4 images should additionally import
  # nixosModules.expand-root-partition to grow into the SD card.
  # If the downstream layout uses btrfs subvolumes, its initrd must convert
  # the flat factory rootfs on first boot (subvolumes cannot be created
  # offline at image build time).
  mkImage =
    {
      pkgs,
      model,
      system,
      fs ? "btrfs",
      imageName,
      imageSize ? null,
      partStart ? "16M",
      bootSizeMiB ? 512,
      bootLabel ? "disk-main-boot",
      partLabel ? "disk-main-root",
      volumeLabel ? "NIXOS",
      bootVolumeLabel ? "BOOT",
    }:
    mkImageFor {
      inherit
        pkgs
        system
        fs
        imageName
        imageSize
        partStart
        bootSizeMiB
        bootLabel
        partLabel
        volumeLabel
        bootVolumeLabel
        ;
      modelDef = modelDefFor model;
    };
}
