# nixos-nanopi-r3s

NixOS board support for the FriendlyElec NanoPi R3S / R3S-LTS (Rockchip RK3566):
bootloader fetcher, board modules (device tree, serial console, initrd
drivers, firmware, stable NIC names) and a factory SD image assembler.
No user policy lives here (no users, SSH, hostnames, locales) — import the
modules from your own configuration and add those yourself.

## Flake API

```nix
{
  inputs.nixos-nanopi-r3s.url = "github:AtaraxiaSjel/nixos-nanopi-r3s";
}
```

- `nixosModules.r3s` / `nixosModules.r3s-lts` — board support only
  (device tree, `console=ttyS2,1500000n8`, initrd SD/Ethernet/PCIe drivers,
  firmware, `wan0`/`lan0` interface names). No fileSystems, no users.
- `nixosModules.register-nix-paths` — first-boot Nix store registration
  for factory images (filesystem-agnostic; no-op on nixos-install systems).
- `nixosModules.expand-root-partition` — first-boot growth of the root
  partition + filesystem to fill the SD card. Ext4-only; import together
  with `register-nix-paths`.
- `lib.mkLoader { pkgs, model; }` — bootloader derivation
  (`idbloader.img` + `u-boot.itb`).
- `lib.mkImage { pkgs, model, system, fs, imageName, ... }` — factory SD
  image from an external full system (`fs = "btrfs"` or `"ext4"`).
- `lib.mkExtraPostVM { loader, imageName; }` — dd snippet stitching the
  bootloader blobs into a disko-built `$out/<imageName>.raw`.
- `packages.nanopi-<model>-loader` — prebuilt bootloader derivations.

## Factory image layout (`lib.mkImage`)

```
0–16M   Rockchip bootloader gap (idbloader @ bs=4K seek=8, u-boot @ seek=2048)
p1      FAT32 /boot, 512M (extlinux.conf + kernel + initrd;
        a separate /boot is required — the bundled u-boot cannot read btrfs)
p2      <fs> rootfs with the store closure (flat; see below)
```

The rootfs is flat: btrfs subvolumes cannot be created offline at build
time, so a downstream layout with subvolumes must convert the rootfs in
its own initrd on first boot and snapshot a read-only blank for rollback.
Geometry defaults (`partStart`, `bootSizeMiB`, `bootLabel`, `partLabel`)
must stay in sync with the downstream disko declaration.

```nix
nix build --impure --expr '
  let cfg = builtins.getFlake "/path/to/your-config"; in
  cfg.inputs.nixos-nanopi-r3s.lib.mkImage {
    pkgs = cfg.inputs.nixpkgs.legacyPackages.x86_64-linux;
    model = "r3s-lts";
    system = cfg.nixosConfigurations.myhost;
    fs = "btrfs"; imageName = "myhost";
  }'
```

## Hardware notes

- SoC RK3566; R3S-LTS boots with the R3S device tree
  (`rk3566-nanopi-r3s.dtb` — no LTS device tree upstream yet; Ethernet,
  PCIe and SD work, LTS-specific HDMI blocks may be missing).
- NICs: native `wan0` (ethernet@fe010000, rk_gmac-dwmac), PCIe Realtek
  8168 `lan0` (r8169). Names are pinned by hardware path, independent of
  probe order.
- Serial console: ttyS2, 1500000 baud, 8N1.

## License

MIT — see [LICENSE](LICENSE).
