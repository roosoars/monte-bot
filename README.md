# 🍓 Raspberry Pi 3 B - WiFi Hotspot Automático

Este projeto transforma seu Raspberry Pi 3 B em um **hotspot WiFi automático** que inicia junto com o sistema, permitindo que você conecte seu iPhone ou qualquer outro dispositivo e acesse uma página web simples.

## 📋 Características

- ✅ Hotspot WiFi criado automaticamente ao ligar o Raspberry Pi
- ✅ Funciona com Raspbian Bookworm Lite (ARM64)
- ✅ Servidor DHCP integrado (dnsmasq)
- ✅ Servidor web (nginx) com página HTML "Hello World"
- ✅ Funciona online e offline
- ✅ Compatível com iPhone, Android e qualquer dispositivo WiFi
- ✅ Configuração personalizável (SSID e senha)
- ✅ Scripts de verificação automática dos serviços

## 🔧 Requisitos

- Raspberry Pi 3 B
- Sistema: Raspbian Bookworm Lite (ARM64)
- Cartão SD com sistema instalado
- Acesso SSH ou teclado/monitor conectado

## 🚀 Instalação Rápida

### 1. Clone o repositório ou copie os arquivos para seu Raspberry Pi

```bash
git clone <seu-repositorio>
cd monte-bot
```

### 2. Execute o script de instalação

```bash
chmod +x install.sh
sudo ./install.sh
```

### 3. Reinicie o Raspberry Pi

```bash
sudo reboot
```

## 📱 Como Usar

Após a reinicialização:

1. **No seu iPhone ou dispositivo móvel:**
   - Abra as configurações de WiFi
   - Procure pela rede: `RaspberryPi-Hotspot`
   - Conecte usando a senha: `raspberry123`

2. **Acesse a página web:**
   - Abra o navegador (Safari, Chrome, etc.)
   - Digite: `http://192.168.4.1`
   - Você verá a página "HELLO WORLD"

## ⚙️ Configurações Personalizadas

### Alterar SSID e Senha

Você pode personalizar o nome da rede (SSID) e a senha durante a instalação:

```bash
WIFI_SSID='MeuRaspberry' WIFI_PASSWORD='MinhaSenh@Forte123' sudo ./install.sh
```

### Configurações Padrão

- **SSID:** RaspberryPi-Hotspot
- **Senha:** raspberry123
- **IP do Raspberry Pi:** 192.168.4.1
- **Range DHCP:** 192.168.4.2 - 192.168.4.20
- **Canal WiFi:** 7
- **Interface:** wlan0

## 🔍 Verificação e Diagnóstico

### Verificar status dos serviços

```bash
sudo systemctl status hostapd
sudo systemctl status dnsmasq
sudo systemctl status nginx
```

### Script de verificação automática

Um script de verificação está incluído para garantir que todos os serviços estejam rodando:

```bash
chmod +x check-hotspot.sh
sudo ./check-hotspot.sh
```

### Ver logs

```bash
# Logs do hostapd (WiFi AP)
sudo journalctl -u hostapd -f

# Logs do dnsmasq (DHCP)
sudo journalctl -u dnsmasq -f

# Logs do nginx (Web server)
sudo journalctl -u nginx -f
```

## 🔧 Solução de Problemas

### O WiFi não aparece

1. Verifique se o hostapd está rodando:
   ```bash
   sudo systemctl status hostapd
   ```

2. Reinicie o serviço:
   ```bash
   sudo systemctl restart hostapd
   ```

3. Verifique se a interface wlan0 está ativa:
   ```bash
   ip link show wlan0
   ```

### Não consigo conectar à rede

1. Verifique se o dnsmasq está rodando:
   ```bash
   sudo systemctl status dnsmasq
   ```

2. Verifique as configurações de IP:
   ```bash
   ip addr show wlan0
   ```

### A página não carrega

1. Verifique se o nginx está rodando:
   ```bash
   sudo systemctl status nginx
   ```

2. Teste o acesso local:
   ```bash
   curl http://192.168.4.1
   ```

## 📝 Estrutura de Arquivos

```
monte-bot/
├── install.sh           # Script principal de instalação
├── uninstall.sh        # Script para remover a configuração
├── check-hotspot.sh    # Script de verificação dos serviços
└── README.md           # Este arquivo
```

### Arquivos criados pela instalação:

- `/etc/hostapd/hostapd.conf` - Configuração do Access Point
- `/etc/dnsmasq.conf` - Configuração do servidor DHCP/DNS
- `/etc/network/interfaces.d/wlan0` - Configuração de rede
- `/var/www/html/index.html` - Página web Hello World

## 🗑️ Desinstalação

Para remover a configuração do hotspot:

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
sudo reboot
```

## 🌐 Personalizar a Página Web

A página HTML está localizada em `/var/www/html/index.html`. Para personalizá-la:

```bash
sudo nano /var/www/html/index.html
```

Após editar, reinicie o nginx:

```bash
sudo systemctl restart nginx
```

## 🔒 Segurança

**⚠️ IMPORTANTE:** As configurações padrão usam uma senha simples. Para uso em produção:

1. Altere a senha para algo mais forte
2. Considere configurar um firewall (ufw)
3. Configure regras de iptables adequadas

Exemplo de senha forte:
```bash
WIFI_PASSWORD='Senh@Forte!123XYZ' sudo ./install.sh
```

## 📊 Especificações Técnicas

- **Hostapd:** Cria o Access Point WiFi
- **Dnsmasq:** Servidor DHCP e DNS local
- **Nginx:** Servidor web leve e eficiente
- **Iptables:** Configuração de NAT (se necessário)
- **Systemd:** Gerenciamento de serviços

## 🤝 Contribuindo

Sinta-se à vontade para contribuir com melhorias:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto é de código aberto. Use livremente!

## 💡 Dicas

- Use o hotspot para projetos IoT
- Adicione sensores e monitore via web
- Crie um portal captivo personalizado
- Integre com APIs e serviços externos

## 🆘 Suporte

Se encontrar problemas:

1. Verifique os logs dos serviços
2. Execute o script de verificação
3. Revise as configurações em `/etc/`
4. Consulte a documentação oficial do Raspberry Pi

---

**Desenvolvido para Raspberry Pi 3 B com Raspbian Bookworm Lite** 🍓
