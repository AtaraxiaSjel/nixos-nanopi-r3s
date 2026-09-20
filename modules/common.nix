# Shared base configuration for the NanoPi R3S family (RK3566).
# Covers extlinux boot, serial console, early boot drivers and firmware.
#
# Hardware notes (verified against vendor firmware behavior):
# - Debug UART at 0xfe660000, 1500000 baud, exposed to Linux as ttyS2
#   (vendor stdout-path "serial2:1500000n8").
# - Native NIC (ethernet@fe010000): Rockchip rk_gmac-dwmac, i.e. modules
#   dwmac_rk + stmmac_platform + stmmac + pcs_xpcs.
# - PCIe NIC (Realtek 10ec:8168): driver r8169 + realtek PHY, behind the
#   RK35xx PCIe stack (pcie_rockchip_host + PHY drivers).
# - SD root via mmc host at fe2b0000 (dwmmc_rockchip), i.e. modules
#   dw_mmc_rockchip + sdhci_of_dwcmshc.
# - Display/HDMI stack (rockchipdrm, analogix_dp, dw_hdmi*, dw_mipi_dsi,
#   rockchip-rga) is kept: harmless headless, and the LTS board has HDMI
#   that a future device tree overlay may enable. Drop it if initrd size
#   ever matters (no NVMe slot on this board, so no NVMe modules).
{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = {
    hardware.firmware = [
      pkgs.linux-firmware
    ];

    boot.loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        useGenerationDeviceTree = true;
      };
      timeout = 1;
    };

    boot.kernelParams = [
      "console=tty0"
      "console=ttyS2,1500000n8"
      "earlycon=uart8250,mmio32,0xfe660000"
    ];

    boot.initrd.availableKernelModules = [
      # SD/MMC root (dwmmc_rockchip on fe2b0000.mmc)
      "sdhci_of_dwcmshc"
      "dw_mmc_rockchip"
      # Native GMAC (rk_gmac-dwmac: dwmac_rk + stmmac stack)
      "dwmac_rk"
      "stmmac_platform"
      "stmmac"
      "pcs_xpcs"
      # PCIe Realtek NIC (r8169 + realtek PHY)
      "pcie_rockchip_host"
      "phy-rockchip-pcie"
      "phy_rockchip_snps_pcie3"
      "phy_rockchip_naneng_combphy"
      "r8169"
      "realtek"
      # USB / power / thermal / watchdog
      "phy_rockchip_inno_usb2"
      "io-domain"
      "rockchip_saradc"
      "rockchip_thermal"
      "dw_wdt"
      # Display/HDMI (kept, see header note)
      "analogix_dp"
      "rockchipdrm"
      "rockchip-rga"
      "dw_hdmi"
      "dw_hdmi_cec"
      "dw_hdmi_i2s_audio"
      "dw_mipi_dsi"
    ];

    powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
  };
}
