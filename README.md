# iStoreOS for FMX1 Pro (RK3399)

Native-style device port of **iStoreOS** to the **FMX1 Pro** board
(RK3399, 4GB LPDDR3, 32GB eMMC, 1x GbE), following the official build flow:

- Source: official [istoreos/istoreos](https://github.com/istoreos/istoreos),
  branch `istoreos-24.10` (the actively maintained stable branch).
- Build config: the official rockchip armv8 config published on the
  koolcenter CDN (`easepi-r1` baseline: `config.buildinfo` + `feeds.conf`),
  with all pre-enabled devices turned off and only FMX1 Pro enabled.
- Device bring-up is the standard OpenWrt one, implemented in
  `device/apply-device.sh`:
  - `Device/rockchip_fmx1-pro` definition appended to
    `target/linux/rockchip/image/armv8.mk` (istoreos style: DTS in
    `target/linux/rockchip/dts/`, FIT kernel image).
  - Board DTS `device/rk3399-fmx1-pro.dts`, derived from the board's own
    Armbian DTB (`rk3399-fmx1-pro.dtb` from ophub kernel 6.18.63 — the exact
    kernel in the board's Armbian image), decompiled and with node labels
    restored from its `__symbols__` table. It round-trips to a byte-identical
    DTB size (83,675 bytes).
  - U-Boot: `fmx1-pro-rk3399` target registered in
    `package/boot/uboot-rockchip/Makefile`; defconfig +
    `rk3399-fmx1-pro-u-boot.dtsi` (standard `rk3399-u-boot.dtsi` +
    Samsung LPDDR3 4GB @1866 SDRAM parameters used by this board).

## Build

Actions → **Build iStoreOS for FMX1 Pro** → Run workflow.
The firmware is attached to the run as an artifact and published as a Release.

## Online update (device pulls from this repo)

The firmware's **update address points at this repo**, not the official
servers:

- Every build publishes a Release and refreshes `update/update.json`
  (version + asset URL + sha256) on the `main` branch.
- The firmware ships with `/usr/bin/fmx-update`. Run it in the device
  terminal: it reads the manifest, downloads the image, verifies the
  sha256, checks the board name, and runs `sysupgrade` keeping your config.
  `fmx-update check` only checks; a cron job checks every Monday 04:00 and
  leaves a note in `/tmp/fmx1-update-available`.
- The official iStoreOS **opkg feeds stay official** on purpose: app and
  kmod installs come from the official mirrors (this build's kernel vermagic
  matches upstream), and this repo does not host a package feed.

## Flash

1. Write `istoreos-rockchip-armv8-rockchip_fmx1-pro-squashfs-sysupgrade.img.gz`
   to a TF card (balenaEtcher / Rufus / `dd`), boot the board from TF first.
2. Default login: `root` / `password`. The single NIC is LAN
   (bypass-router mode): plug it into your main router and find its IP there.
3. Once verified, install to eMMC from the iStoreOS UI/terminal.

Unofficial port for personal use; firmware comes from the official iStoreOS
source tree, only the device definition is added here.
