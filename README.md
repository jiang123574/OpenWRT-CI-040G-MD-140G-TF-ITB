# OpenWRT-CI-040G-MD-140G-TF-ITB

> 专用云编译仓库：一次编译同时产出以下两款机型的 **UBI / sysupgrade.itb**（FIT 格式，fitblk 解包），
> 适用于网页 U-Boot / UBI 分区刷机体系。产物从 **Actions → BUILD-ITB-040G-MD-140G-TF → Run workflow** 触发，
> 编译完成后在对应 Release 下载。

| 机型 | 源码设备定义 | 产物文件名（含） | WAN | USB |
| ---- | ------------ | ---------------- | --- | --- |
| Nokia Bell XG-040G-MD (UBI) | `nokia_xg-040g-md-ubi` | `nokia_xg-040g-md-ubi-...sysupgrade-...itb` | pon0 | 支持 |
| Nokia Bell XG-140G-TF (UBI) | `nokia_xg-140g-tf-ubi`（本仓库补丁新增） | `nokia_xg-140g-tf-ubi-...sysupgrade-...itb` | pon0 | 无 |

## 编译线

- 源码：`https://github.com/pbs05/ponwrt.git`，分支 `master`
- 配置：`Config/AIROHA-ONU.txt`（已勾选 040G-MD/040G-TF 的 UBI 设备）
- 触发：`.github/workflows/BUILD-ITB.yml`（仅 workflow_dispatch，避免 fork 定时任务被禁用）

## 本仓库相对上游的补丁（均在 `Scripts/Settings.sh`）

1. 新增 `an7581-nokia_xg-140g-tf-ubi.dts` 与 `Device/nokia_xg-140g-tf-ubi`，
   DTS 复用 `an7581-nokia_xg-040g-tf-common.dtsi` + `an758x-nokia_xg-040g-ubi-parts.dtsi`，
   model 为 `Nokia Bell XG-140G-TF (UBI)`，compatible 为 `nokia,xg-140g-tf-ubi`。
2. `02_network` 增加 `nokia,xg-140g-tf-ubi)` 分支（4LAN + pon0），否则网口不初始化。
3. 补齐 LAN DHCP 地址池 `start=100 / limit=150 / leasetime=12h`
   （ponwrt base-files 的 config_generate 不生成 dhcp 段，避免必须设静态 IP 才能进管理页）。
4. 禁用 `XRAY_CORE_NAIVE`，绕开 cronet-go 的 cgo LDFLAGS 编译错误。

## 刷机前必读

刷机前必须备份所有原厂分区，特别是 **ri** 和 **bosa** 分区，否则无法恢复光校准与 MAC 地址。
日常升级只用 `*-sysupgrade-*.itb`，不要用 factory / recovery.itb / BL2 / FIP。

详细说明见原帖：https://www.right.com.cn/forum/thread-8453612-1-1.html

---

# 以下为上游模板原始 README

# OpenWRT-CI

贝尔040G系列，全面升级6.18内核  
刷机前必须备份所有原厂分区，特别是ri和bosa分区

详细说明  
https://www.right.com.cn/forum/thread-8453612-1-1.html

支持设备： 四个固件通用，设备名称只是区分不同功能 

| 设备 | WAN 定义 | USB 支持 | UBOOT |
| ---- | -------- | -------- | ------ |
| XG-040G-MD | pon0 | USB2 USB3 | tcboot |
| XG-140G-MD | pon0 | USB2 USB3 | tcboot |
| XG-040G-TF | pon0 | NA | tcboot |
| XG-140G-TF | pon0 | NA | tcboot |

## 恢复MAC地址说明
刷机前必须备份所有原厂分区，特别是ri和bosa分区，参考详细说明刷回备份


## 固件简要说明

固件每天早上5点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

贝尔040系列，140系列。

## 目录简要说明

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置
