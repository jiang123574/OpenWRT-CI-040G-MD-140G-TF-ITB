#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

#调整网口顺序
sed -i 's/ucidef_set_interface_lan "lan1 lan2 lan3 lan4"/ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "lan4"/g' target/linux/airoha/an7581/base-files/etc/board.d/02_network
sed -i 's/interrupts.*//g' target/linux/airoha/dts/an7581-nokia_xg-040g-md-common.dtsi

###############################################################################
# XG-040G-MD / XG-140G-TF UBI (sysupgrade.itb) 定制补丁
# 源码：bingoguo93/immortalwrt @ 6.18，配置 AIROHA-MAIN
###############################################################################

# 禁用 XRAY 的 NaiveProxy 出站：cronet-go 在 musl/arm64 下的 #cgo LDFLAGS
# 含 "-l:libcronet.a"，被 Go 安全校验拒绝导致 xray-core 编译失败。
echo "# CONFIG_XRAY_CORE_NAIVE is not set" >> .config

if [ -d target/linux/airoha ]; then
	# 6.18 的 02_network 已预留 nokia,xg-140g-tf-ubi（4LAN + pon0），
	# 这里仅作幂等兜底：万一未预留则补上。
	NW="target/linux/airoha/an7581/base-files/etc/board.d/02_network"
	if [ -f "$NW" ] && ! grep -q "nokia,xg-140g-tf-ubi" "$NW"; then
		sed -i 's/nokia,xg-040g-tf-ubi)/nokia,xg-040g-tf-ubi |\\\n\tnokia,xg-140g-tf-ubi)/' "$NW"
		# 若连 040g-tf-ubi 都没有，退而绑定到 040g-md-ubi
		if ! grep -q "nokia,xg-140g-tf-ubi" "$NW"; then
			sed -i 's/nokia,xg-040g-md-ubi)/nokia,xg-040g-md-ubi |\\\n\tnokia,xg-140g-tf-ubi)/' "$NW"
		fi
		echo "patched 02_network for nokia,xg-140g-tf-ubi"
	fi

	# 140G-TF 的 UBI DTS：复用 TF 公共 DTSI（已基于 UBI 线 md-common）
	# + 040G 系列的 UBI 分区表。compatible 与 02_network 预留项一致。
	DTS="target/linux/airoha/dts/an7581-nokia_xg-140g-tf-ubi.dts"
	if [ ! -f "$DTS" ]; then
		cat > "$DTS" <<'WRT_DTS'
// SPDX-License-Identifier: GPL-2.0-only OR MIT

#include "an7581-nokia_xg-040g-tf-common.dtsi"
#include "an758x-nokia_xg-040g-ubi-parts.dtsi"

/ {
	model = "Nokia XG-140G-TF (UBI)";
	compatible = "nokia,xg-140g-tf-ubi", "airoha,an7581",
		     "airoha,en7581";
};
WRT_DTS
		echo "added dts an7581-nokia_xg-140g-tf-ubi.dts"
	fi

	# 设备定义：继承 nokia_xg-040g-tf-common（无 USB 包，带 PON 包），
	# 复用 6.18 现成的 nokia_xg-040g-md-ubi-images 镜像宏（含 recovery.itb），
	# 与 040G-MD 的 UBI 构建方式完全一致。
	MK="target/linux/airoha/image/an7581.mk"
	if [ -f "$MK" ] && ! grep -q "Device/nokia_xg-140g-tf-ubi" "$MK"; then
		cat >> "$MK" <<'WRT_MK'

define Device/nokia_xg-140g-tf-ubi
  $(call Device/nokia_xg-040g-tf-common)
  DEVICE_MODEL := XG-140G-TF
  DEVICE_VARIANT := (UBI)
  DEVICE_DTS := an7581-nokia_xg-140g-tf-ubi
  $(call Device/nokia_xg-040g-md-ubi-images)
endef
TARGET_DEVICES += nokia_xg-140g-tf-ubi
WRT_MK
		echo "added Device/nokia_xg-140g-tf-ubi"
	fi

	# 让 140G-TF-ubi 设备符号进入 .config（make defconfig 之前执行）。
	# AIROHA-MAIN 默认只勾 040G-MD-ubi，这里补上 140G-TF-ubi。
	echo "CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-140g-tf-ubi=y" >> .config

	# LAN DHCP 兜底：immortalwrt 官方 config_generate 本就生成 dhcp-range，
	# 这里仅在配置缺项时补齐，幂等，避免再次出现必须静态 IP 的问题。
	UDEF_DIR="package/base-files/files/etc/uci-defaults"
	mkdir -p "$UDEF_DIR"
	cat > "$UDEF_DIR/99-fix-dhcp-lan" <<'WRT_UCI'
#!/bin/sh
[ -f /etc/config/dhcp ] || touch /etc/config/dhcp
uci -q get dhcp.lan >/dev/null 2>&1 || uci set dhcp.lan=dhcp
uci -q get dhcp.lan.interface >/dev/null 2>&1 || uci set dhcp.lan.interface=lan
uci -q get dhcp.lan.start >/dev/null 2>&1 || uci set dhcp.lan.start='100'
uci -q get dhcp.lan.limit >/dev/null 2>&1 || uci set dhcp.lan.limit='150'
uci -q get dhcp.lan.leasetime >/dev/null 2>&1 || uci set dhcp.lan.leasetime='12h'
uci -q get dhcp.lan.dhcpv4 >/dev/null 2>&1 || uci set dhcp.lan.dhcpv4='server'
uci changes dhcp >/dev/null 2>&1 && uci commit dhcp
exit 0
WRT_UCI
	chmod +x "$UDEF_DIR/99-fix-dhcp-lan"
	echo "added uci-defaults 99-fix-dhcp-lan"
fi
