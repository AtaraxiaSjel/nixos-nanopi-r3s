# First-boot Nix store registration for factory SD images.
# Filesystem-agnostic: factory images with any root filesystem import this
# module (`nixosModules.register-nix-paths`). Fully guarded by
# ConditionPathExists=/nix-path-registration, so it is a no-op on
# live-installed systems that already went through nixos-install.
{
  config,
  lib,
  ...
}:
{
  config = {
    systemd.services.register-nix-paths = {
      description = "Register Nix Store Paths";
      unitConfig = {
        DefaultDependencies = false;
        ConditionPathExists = "/nix-path-registration";
      };
      wantedBy = [ "sysinit.target" ];
      before = [
        "sysinit.target"
        "shutdown.target"
        "nix-daemon.socket"
        "nix-daemon.service"
      ];
      after = [ "local-fs.target" ];
      conflicts = [ "shutdown.target" ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.getExe' config.nix.package.out "nix-store"} --load-db < /nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${lib.getExe' config.nix.package.out "nix-env"} -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration
      '';
    };
  };
}
