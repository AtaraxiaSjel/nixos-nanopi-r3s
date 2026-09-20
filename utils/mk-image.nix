# Parameterized SD image assembler for downstream flakes. Takes an EXTERNAL
# toplevel + config (e.g. a full host with its own filesystem layout) and
# supports ext4 and btrfs root filesystems (built by nixpkgs
# make-ext4-fs.nix / make-btrfs-fs.nix — nothing fs-specific is vendored
# here, `fs` is just a switch).
#
# Layout (must stay interchangeable with the downstream disko declaration):
# GPT with a 16M Rockchip bootloader gap (idbloader.img at bs=4K seek=8,
# u-boot.itb at seek=2048). The bundled vendor u-boot reads ext4/FAT but
# NOT btrfs, so /boot is a separate FAT32 partition carrying extlinux.conf
# + kernel + initrd, and the rootfs holds the store closure:
#   p1: FAT32, bootSizeMiB MiB from partStart, name == bootLabel -> /boot
#   p2: <fs> rootfs filling the rest, name == partLabel          -> /
# btrfs subvolumes, if the downstream layout uses them, are created on first
# boot (offline subvolume creation is impossible: make-btrfs-fs.nix populates
# without mounting, and subvolume creation requires a mounted fs) — the
# factory rootfs is flat, the downstream initrd converts it.
# If the layout ever changes, update the disko config alongside
# (partStart/bootSizeMiB/bootLabel/partLabel must match pair-wise).
{
  pkgs,
  nixpkgs,
  modelDef,
  # Full NixOS system (must expose .config, i.e. nixosConfigurations.<host>).
  system,
  # "btrfs" or "ext4".
  fs ? "btrfs",
  # Output image base name: <imageName>.img.xz.
  imageName,
  # Total image size; null = gap + boot + rootfs + slack (see below).
  imageSize ? null,
  # Partition geometry; keep in sync with the downstream disko config.
  partStart ? "16M",
  bootSizeMiB ? 512,
  bootLabel ? "disk-main-boot",
  partLabel ? "disk-main-root",
  volumeLabel ? "NIXOS",
  bootVolumeLabel ? "BOOT",
}:
let
  lib = pkgs.lib;
  bootLoader = import ./loader.nix {
    inherit pkgs;
    inherit (modelDef) model bootLoaderDownload;
    socPrefix = modelDef.socPrefix or "rk3568";
    loaderModel = modelDef.loaderModel or modelDef.model;
  };
  toplevel = system.config.system.build.toplevel;
  populateCmd =
    (import (pkgs.path + "/nixos/modules/system/boot/loader/generic-extlinux-compatible") {
      inherit pkgs;
      config = system.config;
      lib = pkgs.lib;
    }).config.content.boot.loader.generic-extlinux-compatible.populateCmd;
  mkFs =
    if fs == "ext4" then
      {
        builder = "${toString nixpkgs}/nixos/lib/make-ext4-fs.nix";
        extraArgs = { };
        tools = with pkgs; [ e2fsprogs ];
      }
    else if fs == "btrfs" then
      {
        builder = "${toString nixpkgs}/nixos/lib/make-btrfs-fs.nix";
        extraArgs = { compressImage = false; };
        tools = with pkgs; [ btrfs-progs ];
      }
    else
      throw "mk-image.nix: unsupported fs '${fs}', want btrfs or ext4";

  # extlinux.conf + kernel + initrd, populated by
  # generic-extlinux-compatible from the external toplevel.
  bootDir = pkgs.runCommand "${imageName}-boot-files" { } ''
    mkdir -p $out
    ${populateCmd} -c ${toplevel} -d $out
  '';

  # FAT32 /boot image. Built with mkdosfs+mtools (plain userspace, no VM,
  # no mount) — the same pattern as nixpkgs sd-image.nix.
  fatImage = pkgs.runCommand "${imageName}-boot-fat" {
    nativeBuildInputs = with pkgs; [
      dosfstools
      mtools
    ];
  } ''
    truncate -s ${toString bootSizeMiB}M $out
    mkfs.vfat -F 32 -n ${bootVolumeLabel} $out
    # One mcopy per entry: a glob of the dir itself would nest it, and
    # MTOOLS_SKIP_CHECK is needed because the target is a plain file.
    for f in ${bootDir}/*; do
      MTOOLS_SKIP_CHECK=1 mcopy -s -i $out "$f" ::/
    done
  '';
in
pkgs.stdenv.mkDerivation {
  name = "${imageName}.img";

  nativeBuildInputs =
    with pkgs;
    [
      util-linux
      xz
    ]
    ++ mkFs.tools;

  inherit bootLoader fatImage;

  rootfsImage = pkgs.callPackage mkFs.builder (
    {
      storePaths = toplevel;
      # Boot files live on the FAT partition now (see fatImage below).
      # ./files must still be non-empty: make-*-fs.nix globs it without
      # nullglob, an empty dir fails the build. This note documents the
      # flat factory root for maintenance mounts (subvolid=5).
      populateImageCommands = ''
        cat > ./files/README.factory-image.txt <<EOF
        Flat factory root: the whole Nix store closure plus this note, no
        subvolumes (btrfs subvolumes cannot be created offline at image
        build time). On first boot the downstream initrd converts this
        filesystem to the subvolume layout declared in disko and snapshots
        a read-only blank for rollback. This top level is only ever mounted
        directly for maintenance; the running system mounts subvolumes
        instead, so this file is invisible to it.
        EOF
      '';
      inherit volumeLabel;
    }
    // mkFs.extraArgs
  );

  buildCommand = ''
    mkdir $out

    img=tmp.img

    # Gap in front of the first partition, in MiB (Rockchip bootloader
    # area). Must equal partStart; boot starts there, root right after it.
    gapMiB=16
    bootMiB=${toString bootSizeMiB}
    rootStartMiB=$((gapMiB + bootMiB))
    # Headroom so the rootfs has working space before the user resizes to full SD.
    slack=$((256 * 1024 * 1024))

    ${lib.optionalString (imageSize == null) ''
      rootSizeBlocks=$(du -B 512 --apparent-size $rootfsImage | awk '{ print $1 }')
      fatSizeBlocks=$(du -B 512 --apparent-size $fatImage | awk '{ print $1 }')
      imageSize=$((rootSizeBlocks * 512 + fatSizeBlocks * 512 + gapMiB * 1024 * 1024 + slack))
    ''}
    ${lib.optionalString (imageSize != null) ''
      imageSize=${toString imageSize}
    ''}
    truncate -s $imageSize $img

    # Must match the downstream disko declaration (gpt, FAT /boot from 16M,
    # rootfs right after it). sfdisk wants type GUIDs, not sgdisk aliases:
    # EBD0A0A2-... = Microsoft basic data (FAT), 0FC63DAF-... = Linux fs.
    sfdisk --no-reread --no-tell-kernel $img <<EOF
        label: gpt

        start=${partStart}, size=''${bootMiB}M, type=EBD0A0A2-B661-4348-90B3-EB4D61A08997, name="${bootLabel}"
        start=''${rootStartMiB}M, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="${partLabel}"
    EOF

    eval $(partx $img -o START,SECTORS --nr 1 --pairs)
    dd conv=notrunc if=$fatImage of=$img seek=$START count=$SECTORS

    eval $(partx $img -o START,SECTORS --nr 2 --pairs)
    dd conv=notrunc if=$rootfsImage of=$img seek=$START count=$SECTORS

    dd bs=4K seek=8 if=$bootLoader/idbloader.img of=$img conv=notrunc
    dd bs=4K seek=2048 if=$bootLoader/u-boot.itb of=$img conv=notrunc

    xz -vc $img > $out/${imageName}.img.xz
  '';
}
