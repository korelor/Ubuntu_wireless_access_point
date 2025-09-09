#!/bin/bash
set -e

# CONFIGURATION
DNS_ADDR="192.168.173.4"
WIFI_IFACE="wlp2s0"
INET_IFACE="enp3s0"
WIFI_IP="192.168.10.1"
SSID="MyUbuntuHotspot"
PASSPHRASE="1234rewq"


echo "[+] Stopping interfering services..."
systemctl stop hostapd
systemctl stop dnsmasq

echo "[+] Configuring static IP on $WIFI_IFACE..."
ip link set $WIFI_IFACE up
ip addr flush dev $WIFI_IFACE
ip addr add ${WIFI_IP}/24 dev $WIFI_IFACE

echo "[+] Writing hostapd config..."
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wmm_enabled=1
auth_algs=1
wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

#echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

echo "[+] Configuring dnsmasq..."
mv -f /etc/dnsmasq.conf /etc/dnsmasq.conf.bak || true
cat > /etc/dnsmasq.conf <<EOF
port=0
interface=$WIFI_IFACE
dhcp-range=192.168.10.10,192.168.10.24,12h
#dhcp-option=3,$WIFI_IP       # gateway
dhcp-option=6,$DNS_ADDR
EOF

echo "[+] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-hotspot.conf
sysctl --system

echo "[+] Setting up NAT with iptables..."
iptables -t nat -A POSTROUTING -o $INET_IFACE -j MASQUERADE
iptables -A FORWARD -i $INET_IFACE -o $WIFI_IFACE -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WIFI_IFACE -o $INET_IFACE -j ACCEPT
netfilter-persistent save

echo "[+] Enabling and starting services..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl restart hostapd
systemctl restart dnsmasq

echo "[+] Hotspot setup complete. SSID: $SSID, Pass: $PASSPHRASE"

