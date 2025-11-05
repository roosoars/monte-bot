#!/usr/bin/env bash
set -euo pipefail

# Configuration values; adjust if you need a different SSID, passphrase, or IP range.
HOTSPOT_SSID="MonteHotspot"
HOTSPOT_PASSWORD="Rod2804@"
HOTSPOT_CHANNEL="6"
HOTSPOT_COUNTRY="BR"
HOTSPOT_IP="192.168.50.1"
HOTSPOT_NET="192.168.50.0"
HOTSPOT_RANGE_START="192.168.50.10"
HOTSPOT_RANGE_END="192.168.50.100"
HOTSPOT_ROUTER="192.168.50.1"
HOTSPOT_LEASE="24h"
WLAN_IFACE="wlan0"

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] Run this script as root (sudo)." >&2
    exit 1
  fi
}

check_operating_system() {
  local os_id
  os_id=$(awk -F= '/^ID=/{gsub(/"/, ""); print $2}' /etc/os-release)
  local version
  version=$(awk -F= '/^VERSION_ID=/{gsub(/"/, ""); print $2}' /etc/os-release)
  if [[ ${os_id} != "raspbian" && ${os_id} != "debian" ]]; then
    echo "[WARNING] This script was written for Raspberry Pi OS (Bookworm). Proceed with caution." >&2
  fi
  if [[ ${version} != "12" ]]; then
    echo "[WARNING] Detected VERSION_ID=${version}. Expected 12 (Bookworm)." >&2
  fi
}

mask_rfkill() {
  systemctl mask rfkill.service rfkill-block@${WLAN_IFACE}.service >/dev/null 2>&1 || true
  systemctl mask rfkill-block@.service >/dev/null 2>&1 || true
  rfkill unblock all || true
}

disable_wpa_supplicant() {
  systemctl disable --now wpa_supplicant.service wpa_supplicant@${WLAN_IFACE}.service >/dev/null 2>&1 || true
  pkill -f wpa_supplicant || true
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends hostapd dnsmasq nginx rfkill
  systemctl stop hostapd || true
  systemctl stop dnsmasq || true
  systemctl stop nginx || true
}

configure_dhcpcd() {
  local marker_begin="# hotspot-setup begin"
  local marker_end="# hotspot-setup end"
  local dhcpcd_conf="/etc/dhcpcd.conf"

  sed -i "/${marker_begin}/,/${marker_end}/d" "${dhcpcd_conf}"
  cat <<EOF >>"${dhcpcd_conf}"
${marker_begin}
interface ${WLAN_IFACE}
static ip_address=${HOTSPOT_IP}/24
nohook wpa_supplicant
${marker_end}
EOF
}

configure_sysctl() {
  local sysctl_conf="/etc/sysctl.d/99-hotspot.conf"
  cat <<EOF >"${sysctl_conf}"
net.ipv4.ip_forward=0
EOF
  sysctl -w net.ipv4.ip_forward=0 >/dev/null
}

configure_dnsmasq() {
  local dnsmasq_conf="/etc/dnsmasq.d/hotspot.conf"
  mkdir -p /etc/dnsmasq.d
  cat <<EOF >"${dnsmasq_conf}"
interface=${WLAN_IFACE}
dhcp-range=${HOTSPOT_RANGE_START},${HOTSPOT_RANGE_END},255.255.255.0,${HOTSPOT_LEASE}
dhcp-option=option:router,${HOTSPOT_ROUTER}
dhcp-option=option:dns-server,${HOTSPOT_ROUTER}
address=/gw/${HOTSPOT_IP}
log-queries
log-dhcp
EOF
  sed -i 's/^conf-dir=/#&/' /etc/dnsmasq.conf
  if ! grep -q '^conf-dir=/etc/dnsmasq.d' /etc/dnsmasq.conf; then
    echo 'conf-dir=/etc/dnsmasq.d' >>/etc/dnsmasq.conf
  fi
}

configure_hostapd() {
  local hostapd_conf="/etc/hostapd/hostapd.conf"
  cat <<EOF >"${hostapd_conf}"
country_code=${HOTSPOT_COUNTRY}
interface=${WLAN_IFACE}
ssid=${HOTSPOT_SSID}
hw_mode=g
channel=${HOTSPOT_CHANNEL}
wmm_enabled=0
ieee80211n=1
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${HOTSPOT_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
  sed -i 's|^#*\s*DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
}

configure_nginx() {
  local doc_root="/var/www/html"
  mkdir -p "${doc_root}"
  cat <<'EOF' >"${doc_root}/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Hello</title>
  <style>
    body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #111; color: #0f0; }
    h1 { font-size: 4rem; letter-spacing: 0.2rem; }
  </style>
</head>
<body>
  <h1>HELLO</h1>
</body>
</html>
EOF
  chown -R www-data:www-data "${doc_root}"
  chmod -R 755 "${doc_root}"
  systemctl enable nginx
  systemctl restart nginx
}

restore_services() {
  systemctl unmask hostapd || true
  systemctl enable hostapd dnsmasq
  systemctl restart dhcpcd
  systemctl restart dnsmasq
  systemctl restart hostapd
}

main() {
  require_root
  check_operating_system
  mask_rfkill
  disable_wpa_supplicant
  install_packages
  configure_dhcpcd
  configure_sysctl
  configure_dnsmasq
  configure_hostapd
  configure_nginx
  restore_services
  echo "[INFO] Hotspot setup complete. Reboot to ensure all settings persist." >&2
}

main "$@"
