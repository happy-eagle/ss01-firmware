# 亚瑟 AX1800 Pro 固件云编译

京东云无线宝 AX1800 Pro（代号亚瑟，`jdcloud_re-ss-01`）的 ImmortalWrt 自动编译。

- 源码：`VIKINGYFY/immortalwrt` 分支 `owrt`（内核 6.18，带满血 PPE）
- 无 WiFi，只做有线路由 / 旁路由
- OpenClash 内置 mihomo 内核，刷完即用

## 怎么用

1. 在 GitHub 新建一个**公开**仓库（公开仓库 Actions 不扣额度），名字随意，比如 `ss01-firmware`。
2. 把本目录的 `.github/`、`scripts/`、`PLUGINS.md` 传上去。
3. 进 Actions → `Build ImmortalWrt - JDCloud RE-SS-01` → Run workflow。
4. 等 2.5～4 小时，在 run 页面的 Artifacts 里下 `immortalwrt-ss01-<序号>.zip`。

## 改插件

只改 `scripts/diy.sh` 顶部的 `PKGS` 列表，push 后自动触发编译。
想剔除的包加进 `NEG_PKGS`。

## 产物说明

| 文件 | 用途 |
|---|---|
| `*-squashfs-factory.bin` | 首次刷机，第三方 uboot Web 界面刷 |
| `*-squashfs-sysupgrade.bin` | 系统内升级 |

## 注意

- 亚瑟是 eMMC 机型，必须先刷第三方 uboot 才能刷 factory.bin，这一步和本固件无关但绕不开。
- 默认 rootfs 分区 104MB，当前插件组合约 60–80MB，不要无脑加包。
- 编译失败时 workflow 会自动用 `make -j1 V=s` 重跑一遍，日志里能直接看到真实报错行。
