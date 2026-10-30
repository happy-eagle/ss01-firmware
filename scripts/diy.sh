#!/bin/bash
# ============================================================
# ImmortalWrt 定制脚本 - 京东云亚瑟 AX1800 Pro (jdcloud_re-ss-01)
#   目标: qualcommax / ipq60xx   内核: 6.18
#   需求: 无 WiFi、OpenClash(内置 mihomo 内核)、满血 PPE 硬件加速
# ============================================================
set -euo pipefail

cd "${OPENWRT_DIR:-$PWD}"

# ------------------------------------------------------------
# 0. 插件清单（改这里就行）
# ------------------------------------------------------------
PKGS="
luci-app-openclash
luci-theme-argon
luci-app-argon-config
luci-app-ttyd
luci-app-filetransfer
luci-app-commands
luci-app-cpufreq
luci-app-nlbwmon
luci-app-wol
luci-app-ddns
luci-app-upnp
dnsmasq-full
htop
nano
curl
ca-bundle
unzip
openssh-sftp-server
zoneinfo-asia
"

# 明确剔除的 WiFi / 冗余包
NEG_PKGS="
wpad-openssl
wpad-basic-mbedtls
wpad-basic-wolfssl
hostapd-common
kmod-ath11k
kmod-ath11k-ahb
kmod-ath11k-pci
ath11k-firmware-ipq6018
ath11k-firmware-ipq6018-ddwrt
ipq-wifi-jdcloud_re-ss-01
kmod-nss-wifi-drv
nss-firmware
nss-firmware-ipq60xx
dnsmasq
"

echo "=============================================="
echo ">>> 1/6 配置 feeds"
echo "=============================================="
add_feed() {
  local name="$1" url="$2"
  grep -q "src-git ${name} " feeds.conf.default || echo "src-git ${name} ${url}" >> feeds.conf.default
}
add_feed openclash  "https://github.com/vernesong/OpenClash.git;master"
add_feed argon      "https://github.com/jerrykuku/luci-theme-argon.git;master"
add_feed argoncfg   "https://github.com/jerrykuku/luci-app-argon-config.git;master"

cat feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

echo "=============================================="
echo ">>> 2/6 过滤不存在的插件（避免编译到一半炸）"
echo "=============================================="
./scripts/feeds list -n | tr ' ' '\n' | sed '/^$/d' | sort -u > /tmp/avail.txt
: > /tmp/final_pkgs.txt
for p in $PKGS; do
  if grep -qx "$p" /tmp/avail.txt || [ -d "package/$p" ]; then
    echo "  [OK]   $p"
    echo "$p" >> /tmp/final_pkgs.txt
  else
    echo "  [SKIP] $p  <-- 该源里没有这个包"
  fi
done

echo "=============================================="
echo ">>> 3/6 生成 .config"
echo "=============================================="
cat > .config <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y
EOF
make defconfig

# 显式打开
while read -r p; do
  [ -n "$p" ] && echo "CONFIG_PACKAGE_${p}=y" >> .config
done < /tmp/final_pkgs.txt

# 显式关闭
for p in $NEG_PKGS; do
  echo "# CONFIG_PACKAGE_${p} is not set" >> .config
done

# 固件特性
{
  echo "CONFIG_DEVEL=y"
  echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
  echo "CONFIG_TARGET_ROOTFS_EXT4FS=n"
  echo "CONFIG_ALL=n"
  echo "CONFIG_ALL_KMODS=n"
  echo "CONFIG_ALL_NONSHARED=n"
  echo "CONFIG_SIGNED_PACKAGES=n"
} >> .config

make defconfig

echo "=============================================="
echo ">>> 4/6 校验：设备 / 插件 / WiFi 是否已剔除"
echo "=============================================="
FAIL=0
check_on() {
  if grep -qx "CONFIG_PACKAGE_$1=y" .config; then
    echo "  [OK]   $1 已启用"
  else
    echo "  [FAIL] $1 未启用"
    FAIL=1
  fi
}
check_off() {
  if grep -qx "CONFIG_PACKAGE_$1=y" .config; then
    echo "  [FAIL] $1 仍在，剔除失败"
    FAIL=1
  else
    echo "  [OK]   $1 已剔除"
  fi
}

grep -q 'CONFIG_TARGET_PROFILE="DEVICE_jdcloud_re-ss-01"' .config \
  && echo "  [OK]   设备 = jdcloud_re-ss-01" \
  || { echo "  [FAIL] 设备选错"; FAIL=1; }

check_on  luci-app-openclash
check_on  dnsmasq-full
check_off wpad-openssl
check_off kmod-ath11k
check_off kmod-nss-wifi-drv
check_off ipq-wifi-jdcloud_re-ss-01

echo "  --- PPE 硬件加速开关（来自 ipq60xx/config-default）---"
grep -q '^CONFIG_QCOM_EDMA=y'          target/linux/qualcommax/ipq60xx/config-default && echo "  [OK]   QCOM_EDMA=y"
grep -q '^CONFIG_QCOM_80211AX_PPE=y'   target/linux/qualcommax/ipq60xx/config-default && echo "  [OK]   QCOM_80211AX_PPE=y (满血 PPE，内建)"

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "!!! 校验未通过，停止编译。请检查上面的 FAIL 项。"
  exit 1
fi

echo "=============================================="
echo ">>> 5/6 内置 mihomo 内核到固件"
echo "=============================================="
mkdir -p files/etc/openclash/core
API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
MZ_URL=$(curl -fsSL "$API" \
  | grep -oE 'https://[^"]*mihomo-linux-arm64-v[0-9.]+\.gz' \
  | head -1)
if [ -z "$MZ_URL" ]; then
  echo "  [WARN] 未取到 mihomo 下载地址，改用直连 latest 下载"
  MZ_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-arm64-compat.gz"
fi
echo "  下载: $MZ_URL"
curl -fL --retry 3 "$MZ_URL" -o /tmp/mihomo.gz
gunzip -f /tmp/mihomo.gz
mv /tmp/mihomo files/etc/openclash/core/clash_meta
chmod 0755 files/etc/openclash/core/clash_meta
file files/etc/openclash/core/clash_meta
SZ=$(stat -c%s files/etc/openclash/core/clash_meta)
[ "$SZ" -gt 8000000 ] || { echo "!!! mihomo 文件异常，大小 ${SZ}"; exit 1; }
echo "  mihomo 已内置: $(du -h files/etc/openclash/core/clash_meta | cut -f1)"

echo "=============================================="
echo ">>> 6/6 写入开机默认配置"
echo "=============================================="
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-ss01-defaults <<'UCI'
#!/bin/sh
# OpenClash 内核权限（squashfs 里可能丢执行位）
[ -f /etc/openclash/core/clash_meta ] && chmod 0755 /etc/openclash/core/clash_meta

# 满血 PPE：开启软件 + 硬件 flow offload
if uci -q get firewall.@defaults[0] >/dev/null 2>&1; then
  uci -q set firewall.@defaults[0].flow_offloading='1'
  uci -q set firewall.@defaults[0].flow_offloading_hw='1'
  uci -q commit firewall
fi

# 无 WiFi 驱动，移除无线配置避免报错
rm -f /etc/config/wireless

exit 0
UCI
chmod 0755 files/etc/uci-defaults/99-ss01-defaults

echo ""
echo ">>> 定制完成，最终选中的插件："
cat /tmp/final_pkgs.txt
echo ""
echo ">>> 内核参数："
grep -E 'CONFIG_QCOM_(EDMA|80211AX_PPE)' target/linux/qualcommax/ipq60xx/config-default
