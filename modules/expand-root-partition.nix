# First-boot root partition growth for ext4 factory images.
# Extends the last partition to fill the SD card and resizes the ext4
# filesystem (resize2fs) on first boot. Import together with
# register-nix-paths.nix; both are guarded by
# ConditionPathExists=/nix-path-registration, so they only run on factory
# images and are no-ops on live-installed systems.
# Ext4-only: btrfs factory images grow differently (or declare the full
# size up front) and must NOT import this module.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = {
    systemd.services.expand-root-partition = {
      description = "Grow the root partition and filesystem to fill the SD card";
      unitConfig = {
        DefaultDependencies = false;
        ConditionPathExists = "/nix-path-registration";
      };
      wantedBy = [ "sysinit.target" ];
      before = [
        "sysinit.target"
        "shutdown.target"
        "register-nix-paths.service"
      ];
      after = [ "local-fs.target" ];
      conflicts = [ "shutdown.target" ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Figure out device names for the boot device and root filesystem.
        rootPart=$(${lib.getExe' pkgs.util-linux "findmnt"} -n -o SOURCE /)
        bootDevice=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo PKNAME $rootPart)
        partNum=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo MAJ:MIN $rootPart | ${lib.getExe pkgs.gawk} -F: '{print $2}')

        # Resize the root partition and the filesystem to fit the disk
        echo ",+," | ${lib.getExe' pkgs.util-linux "sfdisk"} -N$partNum --no-reread $bootDevice
        ${lib.getExe' pkgs.parted "partprobe"}
        ${lib.getExe' pkgs.e2fsprogs "resize2fs"} $rootPart
      '';
    };
  };
}
