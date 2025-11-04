#!/bin/bash
# Script de instalação do Hotspot WiFi para Raspberry Pi 3 B
# Sistema: Raspbian Bookworm Lite (ARM64)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Raspberry Pi WiFi Hotspot Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Por favor execute como root (sudo)${NC}"
    exit 1
fi

# Configurações padrão
SSID="${WIFI_SSID:-RaspberryPi-Hotspot}"
PASSWORD="${WIFI_PASSWORD:-raspberry123}"
INTERFACE="wlan0"
IP_ADDRESS="192.168.4.1"
DHCP_RANGE_START="192.168.4.2"
DHCP_RANGE_END="192.168.4.20"

echo -e "${YELLOW}Configurações:${NC}"
echo "  SSID: $SSID"
echo "  Senha: $PASSWORD"
echo "  Interface: $INTERFACE"
echo "  IP do AP: $IP_ADDRESS"
echo ""

# Atualizar sistema
echo -e "${GREEN}[1/7] Atualizando sistema...${NC}"
apt-get update

# Instalar pacotes necessários
echo -e "${GREEN}[2/7] Instalando pacotes necessários...${NC}"
apt-get install -y hostapd dnsmasq nginx iptables-persistent

# Parar serviços antes de configurar
echo -e "${GREEN}[3/7] Parando serviços...${NC}"
systemctl stop hostapd || true
systemctl stop dnsmasq || true
systemctl stop nginx || true

# Configurar IP estático para wlan0
echo -e "${GREEN}[4/7] Configurando interface de rede...${NC}"
mkdir -p /etc/network/interfaces.d
cat > /etc/network/interfaces.d/wlan0 << EOF
# Interface WiFi configurada como Access Point
auto wlan0
iface wlan0 inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    network 192.168.4.0
    broadcast 192.168.4.255
EOF

# Configurar hostapd
echo -e "${GREEN}[5/7] Configurando hostapd...${NC}"
cat > /etc/hostapd/hostapd.conf << EOF
# Interface WiFi
interface=$INTERFACE

# Driver nl80211 funciona na maioria dos adaptadores WiFi
driver=nl80211

# Nome da rede WiFi
ssid=$SSID

# Modo de operação (a = IEEE 802.11a, b = IEEE 802.11b, g = IEEE 802.11g)
hw_mode=g

# Canal WiFi (1-13)
channel=7

# Habilitar 802.11n
ieee80211n=1

# Habilitar WMM
wmm_enabled=1

# Aceitar todas as estações MAC
macaddr_acl=0

# Usar autenticação WPA
auth_algs=1

# Requer que clientes conheçam o nome da rede
ignore_broadcast_ssid=0

# Usar WPA2
wpa=2

# Senha da rede
wpa_passphrase=$PASSWORD

# Usar AES ao invés de TKIP
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Configurações do país (BR = Brasil)
country_code=BR
EOF

# Apontar hostapd para o arquivo de configuração
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

# Fazer backup da configuração original do dnsmasq
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

# Configurar dnsmasq (servidor DHCP e DNS)
echo -e "${GREEN}[6/7] Configurando dnsmasq...${NC}"
cat > /etc/dnsmasq.conf << EOF
# Interface para escutar
interface=$INTERFACE

# Não usar interface eth0
no-dhcp-interface=eth0

# Não ler /etc/resolv.conf
no-resolv

# Não fazer polling no /etc/resolv.conf
no-poll

# Configuração DHCP
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,24h

# DNS servers (Google DNS)
server=8.8.8.8
server=8.8.4.4

# Log queries
log-queries
log-dhcp

# Não encaminhar consultas sem domínio
domain-needed

# Não encaminhar endereços no espaço de endereço privado
bogus-priv
EOF

# Habilitar IP forwarding
echo -e "${GREEN}[7/7] Configurando IP forwarding e iptables...${NC}"
# Habilitar no kernel
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# Configurar iptables para NAT (se houver eth0 ou outra conexão)
iptables -t nat -F
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE 2>/dev/null || true
netfilter-persistent save

# Habilitar serviços para iniciar no boot
echo -e "${GREEN}Habilitando serviços...${NC}"
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl enable nginx

# Criar página HTML
echo -e "${GREEN}Criando página web...${NC}"
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raspberry Pi Hotspot</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 60px 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 600px;
            animation: fadeIn 0.8s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        h1 {
            color: #667eea;
            font-size: 3em;
            margin: 0 0 20px 0;
            font-weight: 700;
        }
        .subtitle {
            color: #666;
            font-size: 1.2em;
            margin-bottom: 30px;
        }
        .info {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            margin-top: 30px;
            text-align: left;
        }
        .info-item {
            margin: 10px 0;
            color: #333;
        }
        .info-label {
            font-weight: bold;
            color: #667eea;
        }
        .raspberry-icon {
            font-size: 4em;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="raspberry-icon">🍓</div>
        <h1>HELLO WORLD</h1>
        <p class="subtitle">Bem-vindo ao Raspberry Pi WiFi Hotspot!</p>
        <div class="info">
            <div class="info-item">
                <span class="info-label">Status:</span> Conectado com sucesso ✓
            </div>
            <div class="info-item">
                <span class="info-label">Dispositivo:</span> Raspberry Pi 3 B
            </div>
            <div class="info-item">
                <span class="info-label">Sistema:</span> Raspbian Bookworm Lite
            </div>
            <div class="info-item">
                <span class="info-label">IP:</span> <span id="ip">Carregando...</span>
            </div>
        </div>
    </div>
    <script>
        // Exibir o IP do servidor
        fetch('//')
            .then(() => {
                document.getElementById('ip').textContent = window.location.hostname || '192.168.4.1';
            })
            .catch(() => {
                document.getElementById('ip').textContent = '192.168.4.1';
            });
    </script>
</body>
</html>
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Instalação concluída com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Informações da rede:${NC}"
echo "  SSID: $SSID"
echo "  Senha: $PASSWORD"
echo "  IP do Raspberry Pi: $IP_ADDRESS"
echo "  Acesse no navegador: http://$IP_ADDRESS"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "  1. Reinicie o Raspberry Pi: sudo reboot"
echo "  2. Conecte-se à rede WiFi '$SSID'"
echo "  3. Abra o navegador e acesse: http://$IP_ADDRESS"
echo ""
echo -e "${GREEN}Para personalizar SSID e senha:${NC}"
echo "  WIFI_SSID='MeuSSID' WIFI_PASSWORD='MinhaSenh@123' sudo ./install.sh"
echo ""
