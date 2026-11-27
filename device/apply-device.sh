#!/bin/bash -e
# =============================================================================
# Add the FMX1 Pro (RK3399) device to an istoreos/istoreos source tree.
#
# Run from the root of a clean istoreos checkout (branch istoreos-24.10):
#   DEV_DIR=/path/to/device bash device/apply-device.sh
#
# What it does (standard OpenWrt device bring-up, nothing else):
#   1. Appends the Device/ definition to target/linux/rockchip/image/armv8.mk
#      (istoreos style: DTS lives in target/linux/rockchip/dts/, FIT kernel).
#   2. Installs the board DTS (derived from the Armbian DTB of this board,
#      with labels restored from its __symbols__ table).
#   3. Registers a U-Boot target in package/boot/uboot-rockchip/Makefile and
#      installs the defconfig + DTS + -u-boot.dtsi into the U-Boot sources.
# =============================================================================

DEV_DIR="${DEV_DIR:-$(cd "$(dirname "$0")" && pwd)}"

fail() { echo "::error::$*" >&2; exit 1; }

[ -f target/linux/rockchip/image/armv8.mk ] || fail "not an istoreos tree (armv8.mk missing)"
[ -f package/boot/uboot-rockchip/Makefile ] || fail "uboot-rockchip Makefile missing"

# --- 1. Device definition -----------------------------------------------------
if ! grep -q "Device/rockchip_fmx1-pro" target/linux/rockchip/image/armv8.mk; then
  cat >> target/linux/rockchip/image/armv8.mk <<'EOF'

define Device/rockchip_fmx1-pro
  DEVICE_VENDOR := Rockchip
  DEVICE_MODEL := FMX1 Pro
  SOC := rk3399
  UBOOT_DEVICE_NAME := fmx1-pro-rk3399
  DEVICE_DTS_DIR := ../dts
  DEVICE_DTS = rk3399/rk3399-fmx1-pro
  KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-rk3399-fmx1-pro.dtb
endef
TARGET_DEVICES += rockchip_fmx1-pro
EOF
  echo "device definition appended"
fi

# --- 2. Board DTS for the image builder (kernel FIT) --------------------------
mkdir -p target/linux/rockchip/dts/rk3399
cp -f "$DEV_DIR/rk3399-fmx1-pro.dts" target/linux/rockchip/dts/rk3399/rk3399-fmx1-pro.dts
echo "kernel DTS installed"

# --- 3. U-Boot ----------------------------------------------------------------
UBOOT_SRC="package/boot/uboot-rockchip/src"
mkdir -p "$UBOOT_SRC/arch/arm/dts" "$UBOOT_SRC/configs"
cp -f "$DEV_DIR/rk3399-fmx1-pro.dts"        "$UBOOT_SRC/arch/arm/dts/rk3399-fmx1-pro.dts"
cp -f "$DEV_DIR/rk3399-fmx1-pro-u-boot.dtsi" "$UBOOT_SRC/arch/arm/dts/rk3399-fmx1-pro-u-boot.dtsi"
cp -f "$DEV_DIR/fmx1-pro-rk3399_defconfig"   "$UBOOT_SRC/configs/fmx1-pro-rk3399_defconfig"
echo "u-boot dts/defconfig installed"

# Register the target in the OpenWrt uboot-rockchip Makefile.
MK="package/boot/uboot-rockchip/Makefile"
if ! grep -q "U-Boot/fmx1-pro-rk3399" "$MK"; then
  grep -q "^define U-Boot/nanopi-r4s-rk3399" "$MK" || fail "anchor (nanopi-r4s block) not found in uboot Makefile"
  awk '
    /^define U-Boot\/nanopi-r4s-rk3399/ && !done {
      print "define U-Boot/fmx1-pro-rk3399"
      print "  $(U-Boot/rk3399/Default)"
      print "  NAME:=FMX1 Pro"
      print "  BUILD_DEVICES:= \\"
      print "    rockchip_fmx1-pro"
      print "endef"
      print ""
      done=1
    }
    { print }
  ' "$MK" > "$MK.tmp" && mv "$MK.tmp" "$MK"

  grep -q "^  nanopc-t4-rk3399 \\\\$" "$MK" || fail "anchor (UBOOT_TARGETS nanopc-t4) not found in uboot Makefile"
  sed -i 's|^  nanopc-t4-rk3399 \\$|  nanopc-t4-rk3399 \\\n  fmx1-pro-rk3399 \\|' "$MK"
  echo "u-boot target registered"
fi
grep -q "U-Boot/fmx1-pro-rk3399" "$MK" || fail "u-boot registration failed"
grep -q "fmx1-pro-rk3399" "$MK"   || fail "u-boot target list update failed"

# Make sure the U-Boot build knows the board DTB (harmless if already handled
# via CONFIG_DEFAULT_DEVICE_TREE).
DTS_MK="$UBOOT_SRC/arch/arm/dts/Makefile"
if [ -f "$DTS_MK" ] && ! grep -q "rk3399-fmx1-pro.dtb" "$DTS_MK"; then
  sed -i 's|^dtb-\$(CONFIG_ROCKCHIP_RK3399) += rk3399-evb.dtb.*|&\n\tdtb-$(CONFIG_ROCKCHIP_RK3399) += rk3399-fmx1-pro.dtb|' "$DTS_MK" || true
fi

# --- 4. Rootfs overlay (fmx-update online-update tooling) ----------------------
if [ -d "$DEV_DIR/files" ]; then
  mkdir -p files
  cp -rf "$DEV_DIR/files/." files/
  chmod +x files/usr/bin/fmx-update files/etc/uci-defaults/99-fmx1-update 2>/dev/null || true
  echo "rootfs overlay installed (fmx-update)"
fi

echo "FMX1 Pro device applied OK"
