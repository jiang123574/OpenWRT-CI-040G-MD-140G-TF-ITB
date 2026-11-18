#!/bin/bash
# 私有扩展包脚本：在 ./wrt/package/ 目录下执行
# 集成恩山帖提到的两个第三方插件：
#   1) rchen14b/luci-app-airoha-npu —— Airoha NPU/CPU/Frame Engine 状态面板
#   2) naoki66/OpenWrt_ONU_CONFIG  —— 光模块数据展示（只取 luci 展示包，
#      daemon/ponctl/pond 复用 ponwrt feed 自带版本，避免 Rust 重编译与包冲突）

# ---- 1) NPU 状态面板 ----
# 仓库根目录自带标准 luci.mk Makefile，直接克隆到 package/ 即为一个合法 luci 包。
if [ ! -d "./luci-app-airoha-npu" ]; then
	git clone --depth=1 --single-branch --branch main \
		https://github.com/rchen14b/luci-app-airoha-npu.git ./luci-app-airoha-npu
	# 清掉仓库内嵌套的同名子目录与截图，避免把嵌套 Makefile 误扫成包
	rm -rf ./luci-app-airoha-npu/luci-app-airoha-npu \
	       ./luci-app-airoha-npu/screenshots \
	       ./luci-app-airoha-npu/.github
fi

# ---- 2) 光模块数据展示（naoki66 ONU_CONFIG）----
# 只取两个纯 Luci 展示包：
#   luci-app-onu         顶级 ONU 菜单（状态/硬件身份/认证/上网/IPTV/语音/诊断）
#   luci-app-pon-status  状态页光模块指标卡片
# 依赖的 airoha-ponctl/airoha-pond 用 ponwrt feed 现有版本，不引入其 Rust daemon。
if [ ! -d "./luci-app-onu" ] || [ ! -d "./luci-app-pon-status" ]; then
	git clone --depth=1 --single-branch --branch main \
		https://github.com/naoki66/OpenWrt_ONU_CONFIG.git ./__onu_cfg_tmp
	[ -d "./__onu_cfg_tmp/luci-app-onu" ] && cp -rf ./__onu_cfg_tmp/luci-app-onu ./luci-app-onu
	[ -d "./__onu_cfg_tmp/luci-app-pon-status" ] && cp -rf ./__onu_cfg_tmp/luci-app-pon-status ./luci-app-pon-status
	rm -rf ./__onu_cfg_tmp
fi

echo "PRIVATE.sh: NPU panel + ONU optical display packages ready"
