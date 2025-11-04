#!/bin/bash
# Script para verificar e reiniciar o hotspot se necessário

INTERFACE="wlan0"
EXPECTED_IP="192.168.4.1"

# Verificar se a interface está UP
if ! ip link show $INTERFACE | grep -q "state UP"; then
    echo "$(date): Interface $INTERFACE está DOWN, reiniciando..."
    ip link set $INTERFACE up
    sleep 2
fi

# Verificar se o IP está configurado corretamente
CURRENT_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
if [ "$CURRENT_IP" != "$EXPECTED_IP" ]; then
    echo "$(date): IP incorreto ($CURRENT_IP), reconfigurando..."
    ip addr flush dev $INTERFACE
    ip addr add $EXPECTED_IP/24 dev $INTERFACE
fi

# Verificar se hostapd está rodando
if ! systemctl is-active --quiet hostapd; then
    echo "$(date): hostapd não está rodando, iniciando..."
    systemctl start hostapd
fi

# Verificar se dnsmasq está rodando
if ! systemctl is-active --quiet dnsmasq; then
    echo "$(date): dnsmasq não está rodando, iniciando..."
    systemctl start dnsmasq
fi

# Verificar se nginx está rodando
if ! systemctl is-active --quiet nginx; then
    echo "$(date): nginx não está rodando, iniciando..."
    systemctl start nginx
fi
