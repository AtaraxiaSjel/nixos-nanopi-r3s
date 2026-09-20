# Per-model board support: device tree + stable network interface names.
# Applied to a model definition from ../models (dtb, nics[{name,path}]).
#
# - hardware.deviceTree.name selects the board DTB for extlinux + kernel.
# - systemd.network.links pins each NIC to its name (wan0/lan0) via the
#   hardware Path, so names survive driver/probe order. The MAC can
#   optionally be pinned via `nanopi.network.interfaces.<name>.mac`.
modelData:
{ config, lib, ... }:
{
  imports = [
    ./common.nix
  ];

  options = {
    nanopi.network.interfaces = builtins.listToAttrs (
      map (
        nic:
        lib.nameValuePair nic.name {
          name = lib.mkOption {
            type = lib.types.str;
            default = nic.name;
            description = "Interface name for ${nic.name}";
          };
          mac = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Mac address for ${nic.name}, random address will be generated if unset";
          };
        }
      ) modelData.nics
    );
  };

  config = {
    hardware.deviceTree.name = modelData.dtb;
    systemd.network.links = builtins.listToAttrs (
      map (
        nic:
        let
          opts = config.nanopi.network.interfaces.${nic.name};
        in
        lib.nameValuePair "10-${nic.name}" {
          matchConfig = {
            Path = nic.path;
          };
          linkConfig = {
            Name = opts.name;
          }
          // (if (opts.mac != null) then { MACAddress = opts.mac; } else { });
        }
      ) modelData.nics
    );
  };
}
