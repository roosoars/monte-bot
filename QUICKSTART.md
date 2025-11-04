# 🚀 Guia de Início Rápido

## Para quem tem pressa!

### 1️⃣ No seu Raspberry Pi, execute:

```bash
# Clone ou baixe este repositório
git clone <url-do-repositorio>
cd monte-bot

# Execute a instalação (vai pedir sudo)
chmod +x install.sh
sudo ./install.sh

# Reinicie
sudo reboot
```

### 2️⃣ No seu iPhone/dispositivo:

1. Vá em **Ajustes** → **WiFi**
2. Conecte na rede: **RaspberryPi-Hotspot**
3. Senha: **raspberry123**

### 3️⃣ No navegador:

Digite: **http://192.168.4.1**

Pronto! Você verá a página **HELLO WORLD**! 🎉

---

## 🎨 Personalização Rápida

### Mudar nome e senha da rede:

```bash
WIFI_SSID='MeuWiFi' WIFI_PASSWORD='MinhaSenh@123' sudo ./install.sh
```

### Editar a página web:

```bash
sudo nano /var/www/html/index.html
sudo systemctl restart nginx
```

---

## 🔧 Comandos Úteis

```bash
# Ver status dos serviços
sudo systemctl status hostapd dnsmasq nginx

# Reiniciar tudo
sudo systemctl restart hostapd dnsmasq nginx

# Verificar e corrigir problemas
sudo ./check-hotspot.sh

# Desinstalar
sudo ./uninstall.sh
```

---

## 💡 Dica Pro

Quer que seu hotspot tenha acesso à internet?

Se você tiver uma conexão Ethernet (cabo de rede) conectada, o script já configura o NAT automaticamente!

Basta conectar o cabo de rede e reiniciar:
```bash
sudo reboot
```

---

**Precisa de mais detalhes?** Leia o [README.md](README.md) completo!
