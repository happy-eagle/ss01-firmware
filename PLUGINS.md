# 亚瑟 AX1800 Pro (jdcloud_re-ss-01) 固件插件清单

## 编译目标

| 项目 | 值 |
|---|---|
| 源码 | `VIKINGYFY/immortalwrt` 分支 `owrt`（默认分支） |
| 内核 | 6.18 |
| 目标 | `qualcommax` / `ipq60xx` |
| 设备 | `jdcloud_re-ss-01`（京东云无线宝 AX1800 Pro，代号亚瑟） |
| 硬件 | IPQ6000 四核 A53 / 512MB RAM / 64GB eMMC |
| WiFi | **不编译**（wpad、ath11k 驱动、ath11k 固件、BDF 全部剔除） |
| 硬件加速 | `CONFIG_QCOM_EDMA=y` + `CONFIG_QCOM_80211AX_PPE=y`（内核内建，满血 PPE） |

## 一、必装插件（会编进固件）

| 插件 | 作用 | 说明 |
|---|---|---|
| `luci-app-openclash` | 代理客户端 | 主需求，来自 vernesong/OpenClash 源 |
| `dnsmasq-full` | DNS/DHCP | 替换默认 dnsmasq，OpenClash 的 ipset/nftset 依赖它 |
| `luci-theme-argon` | 主题 | jerrykuku 源 |
| `luci-app-argon-config` | 主题设置 | 同上 |
| `luci-app-ttyd` | 网页终端 | 免 SSH 客户端 |
| `luci-app-filetransfer` | 网页文件管理 | 上传/下载/删除 |
| `luci-app-commands` | 自定义命令 | 存常用 shell 快捷方式 |
| `luci-app-cpufreq` | CPU 调频 | IPQ6000 四核，可降频省电/超频 |
| `luci-app-nlbwmon` | 分设备流量统计 | 旁路由查谁在跑流量 |
| `luci-app-ddns` | 动态域名 | 公网访问 |
| `luci-app-upnp` | 端口自动映射 | BT/PT 必备 |
| `htop` / `nano` / `curl` / `ca-bundle` / `unzip` | CLI 工具 | 基础运维 |
| `openssh-sftp-server` | SFTP | WinSCP 传文件 |
| `zoneinfo-asia` | 时区 | 上海时区 |

## 二、内置内核

| 项目 | 说明 |
|---|---|
| mihomo（Clash.Meta） | 编译时下载最新 arm64 版，落到 `/etc/openclash/core/clash_meta`，权限 0755 |
| 好处 | 刷完即用，OpenClash 不需要联网下载内核（很多人卡在这一步） |

## 三、明确剔除的包

| 包 | 原因 |
|---|---|
| `wpad-openssl` / `hostapd-common` | 无 WiFi，不需要 |
| `kmod-ath11k` / `-ahb` / `-pci` | 无 WiFi 驱动 |
| `ath11k-firmware-ipq6018-ddwrt` | 无 WiFi 固件 |
| `ipq-wifi-jdcloud_re-ss-01` | 无 WiFi 校准数据(BDF) |
| `kmod-nss-wifi-drv` | NSS 固件宿主驱动，只为 WiFi 卸载服务，有线不依赖它 |
| `nss-firmware` / `nss-firmware-ipq60xx` | 同上，无 WiFi 时是纯浪费（约 10MB + 占内存） |
| `dnsmasq` | 被 `dnsmasq-full` 替换 |

## 四、可选（需要就加进 `scripts/diy.sh` 的 PKGS）

| 插件 | 作用 | 建议 |
|---|---|---|
| `luci-app-samba4` | 64G eMMC 做 NAS 共享 | 想当轻 NAS 就加 |
| `kmod-usb-storage-uas` + `kmod-fs-exfat` | USB 硬盘支持 | 外接硬盘才加 |
| `luci-app-smartdns` | DNS 分流加速 | 和 OpenClash 的 DNS 逻辑冲突，不建议 |
| `luci-app-sqm` | 抗 bufferbloat | **会关掉 PPE 硬件加速**，和"满血"目标冲突，不建议 |

## 五、不装的重复方案

`luci-app-ssr-plus`、`luci-app-passwall`、`luci-app-mosdns`、`luci-app-vssr`、`luci-app-zerotier` —— 代理方案只留 OpenClash，同时装会抢 53 端口和 nft 规则；zerotier 按需求不装。

## 六、产物

| 文件 | 用途 |
|---|---|
| `immortalwrt-qualcommax-ipq60xx-jdcloud_re-ss-01-squashfs-factory.bin` | 首次刷机，uboot Web 界面直接刷 |
| `immortalwrt-qualcommax-ipq60xx-jdcloud_re-ss-01-squashfs-sysupgrade.bin` | 系统内升级（sysupgrade tar） |

## 七、已知风险

1. **刷机门槛**：亚瑟是 eMMC 机型，需要先刷第三方 uboot（TTL 或免拆漏洞），再刷 factory.bin。这一步和固件无关，但绕不开。
2. **rootfs 分区大小**：默认 104MB，插件全装大约 60–80MB，够用。若要吃满 64G eMMC，得单独改分区表，另说。
3. **首次编译时间**：GitHub 免费 runner 4 核，约 2.5–4 小时，接近 6 小时上限。失败会自动重跑 `make -j1 V=s` 打印真实错误。
