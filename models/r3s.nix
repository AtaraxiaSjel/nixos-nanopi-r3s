# NanoPi R3S (RK3566) model definition.
#
# Hardware summary:
# - Native NIC: ethernet@fe010000 (Rockchip rk_gmac-dwmac, rgmii phy),
#   matched by systemd as Path=platform-fe010000.ethernet.
# - PCIe NIC: Realtek 10ec:8168 behind the platform PCIe host at 3c0000000
#   (driver r8169), matched as Path=platform-3c0000000.pcie-*.
# - Storage: SD card on mmc host at fe2b0000 (dwmmc_rockchip); no eMMC on
#   this board. Image layout keeps a 16M bootloader gap (idbloader at
#   bs=4K seek=8, u-boot.itb at seek=2048).
# - Serial console: ttyS2 at 1500000 baud.
# - Kernel: stock NixOS kernel provides rk3566-nanopi-r3s.dtb (added
#   upstream in 6.13); r3s-lts.nix reuses this DTB, see there.
# - U-Boot: vendor prebuilt zip; the inner directory is
#   rk3566-nanopi-r3s/base-files/ with idbloader.img + u-boot.itb
#   (hash prefetched with `nix store prefetch-file <url>`).
{
  model = "r3s";

  # Selects the zip inner directory: ${socPrefix}-nanopi-${loaderModel}.
  socPrefix = "rk3566";

  bootLoaderDownload = {
    url = "https://github.com/inindev/uboot-rockchip/releases/download/v2026.07/rk3566-nanopi-r3s.zip";
    hash = "sha256-1RpAv53F8wnGn6u6LUiueDncv1DMncRl/gCJxdHxi4k=";
  };

  dtb = "rockchip/rk3566-nanopi-r3s.dtb";

  nics = [
    {
      name = "wan0";
      path = "platform-fe010000.ethernet";
    }
    {
      name = "lan0";
      path = "platform-3c0000000.pcie-*";
    }
  ];
}
