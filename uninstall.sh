#!/bin/bash
# Script para remover a configuração do hotspot WiFi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Desinstalando WiFi Hotspot${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Por favor execute como root (sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}Parando serviços...${NC}"
systemctl stop hostapd
systemctl stop dnsmasq

echo -e "${GREEN}Desabilitando serviços...${NC}"
systemctl disable hostapd
systemctl disable dnsmasq

echo -e "${GREEN}Restaurando configurações...${NC}"
rm -f /etc/network/interfaces.d/wlan0
rm -f /etc/hostapd/hostapd.conf

if [ -f /etc/dnsmasq.conf.backup ]; then
    mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
fi

echo -e "${GREEN}Limpando iptables...${NC}"
iptables -t nat -F
netfilter-persistent save

echo ""
echo -e "${GREEN}Desinstalação concluída!${NC}"
echo -e "${YELLOW}Reinicie o Raspberry Pi para aplicar as mudanças: sudo reboot${NC}"
echo ""
