# NanoPi R3S-LTS (RK3566) model definition.
# Same SoC, NICs and bootloader as r3s.nix; only the device tree differs.
#
# DTB fallback: the stock NixOS kernel ships rk3566-nanopi-r3s.dtb but no
# rk3566-nanopi-r3s-lts.dtb (downstream distributions carry it as an
# out-of-tree patch adding LTS-specific HDMI/I2S blocks on top of the r3s
# device tree source). Until an overlay is added, the LTS boots with the
# r3s DTB: Ethernet, PCIe and SD all work; only LTS-specific HDMI
# audio/video may be missing. If the kernel ever gains the LTS device
# tree, flip `dtb` to "rockchip/rk3566-nanopi-r3s-lts.dtb".
#
# Bootloader: the vendor ships no separate LTS zip (a different defconfig
# exists, but the prebuilt archive is shared with the R3S), so
# `loaderModel` pins the shared inner directory while `model` keeps the
# LTS name for outputs.
{
  model = "r3s-lts";

  # See r3s.nix: loader path becomes ${socPrefix}-nanopi-${loaderModel}.
  socPrefix = "rk3566";
  loaderModel = "r3s";

  bootLoaderDownload = {
    url = "https://github.com/inindev/uboot-rockchip/releases/download/v2026.07/rk3566-nanopi-r3s.zip";
    hash = "sha256-1RpAv53F8wnGn6u6LUiueDncv1DMncRl/gCJxdHxi4k=";
  };

  dtb = "rockchip/rk3566-nanopi-r3s.dtb"; # fallback: no -lts.dtb upstream yet

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
