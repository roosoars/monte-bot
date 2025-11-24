# Monte Bot

Infraestrutura de rede e visão computacional para o robô R2D2 desenvolvido pelo liga academica MONTE BOT (Universidade Federal de Uberlândia) baseada em Raspberry Pi OS (Bookworm). Este repositório reúne os scripts de provisionamento necessários para disponibilizar um hotspot Wi-Fi dedicado, servir uma interface web hospedada localmente e expor um streaming HLS com sobreposições de rastreamento executadas no navegador.

## Visão geral

- `setup_hotspot.sh` instala e configura hostapd, dnsmasq, dhcpcd e nginx para criar um ponto de acesso isolado, controlando faixa de IP, roteamento e página inicial.
- `setup_camera_stream.sh` provisiona o pipeline de câmera (`rpicam-vid` + `ffmpeg`), realiza o download/atualização de assets Mediapipe e registra um serviço systemd (`rpicam-hls.service`) que publica o stream e UI de rastreamento.
- A pasta `assets/` contém versões empacotadas dos binários WebAssembly, modelos e bibliotecas JavaScript usados como fallback quando não há conexão com a internet.

## Pré-requisitos

- Raspberry Pi com câmera compatível (ex.: IMX219) e Wi-Fi integrado.
- Raspberry Pi OS Bookworm (32 ou 64 bits) atualizado.
- Acesso root (`sudo`) para aplicar mudanças em `/etc`, `/boot`, `/usr/local` e `/var/www`.
- Conexão temporária à internet durante o provisionamento para atualização de pacotes (opcional, porém recomendado).

## Instalação rápida

```bash
git clone https://github.com/<sua-organizacao>/monte-bot.git
cd monte-bot
chmod +x setup_hotspot.sh setup_camera_stream.sh
sudo ./setup_hotspot.sh
sudo ./setup_camera_stream.sh
sudo reboot
```

Após reiniciar, conecte-se ao SSID configurado (padrão: `MonteHotspot`) e acesse `http://192.168.50.1/` para validar o streaming.

## Personalização dos parâmetros

### Hotspot (`setup_hotspot.sh`)

Edite as variáveis no topo do script antes de executar para ajustar rede, segurança e captura de IPs.

| Variável              | Valor padrão        | Descrição                                             |
| --------------------- | ------------------- | ----------------------------------------------------- |
| `HOTSPOT_SSID`        | `MonteHotspot`      | Nome do ponto de acesso exibido aos dispositivos.     |
| `HOTSPOT_PASSWORD`    | `Rod2804@`          | Senha WPA2-PSK (mínimo 8 caracteres).                 |
| `HOTSPOT_CHANNEL`     | `6`                 | Canal Wi-Fi (2,4 GHz).                                |
| `HOTSPOT_COUNTRY`     | `BR`                | Código de país para regulamentos de RF.               |
| `HOTSPOT_IP`          | `192.168.50.1`      | IP fixo do Raspberry Pi na rede privada.              |
| `HOTSPOT_RANGE_START` | `192.168.50.10`     | Início da faixa DHCP entregue pelo dnsmasq.           |
| `HOTSPOT_RANGE_END`   | `192.168.50.100`    | Fim da faixa DHCP.                                    |
| `HOTSPOT_LEASE`       | `24h`               | Tempo de concessão DHCP.                              |
| `WLAN_IFACE`          | `wlan0`             | Interface Wi-Fi utilizada pelo hotspot.               |

### Streaming (`setup_camera_stream.sh`)

O binário `rpicam-hls.sh` aceita variáveis de ambiente para ajustar o stream. Crie um drop-in systemd para preservar mudanças:

```bash
sudo systemctl edit rpicam-hls.service
```

Exemplo de conteúdo:

```ini
[Service]
Environment=STREAM_FRAMERATE=24
Environment=STREAM_WIDTH=1280
Environment=STREAM_HEIGHT=720
Environment=STREAM_BITRATE=6000000
```

Recarregue e reinicie:

```bash
sudo systemctl daemon-reload
sudo systemctl restart rpicam-hls.service
```

## Execução e verificação

1. **Hotspot**  
   `sudo ./setup_hotspot.sh` aplica configurações, cria serviços auxiliares para rfkill e atualiza nginx. Confira o estado com:
   ```bash
   systemctl status hostapd dnsmasq nginx
   ip addr show wlan0
   ```
   Sugestão de teste: conectar um notebook ao SSID e verificar o IP recebido (deve estar na sub-rede `192.168.50.0/24`).

2. **Streaming da câmera**  
   `sudo ./setup_camera_stream.sh` instala `rpicam-apps`, gera o script `rpicam-hls.sh` e habilita `rpicam-hls.service`. Valide com:
   ```bash
   systemctl status rpicam-hls.service
   journalctl -u rpicam-hls.service -f
   ls /var/www/html/stream
   ```
   A página `http://192.168.50.1/` exibe o vídeo HLS e os overlays de rastreamento executados via MediaPipe no navegador.

## Configuração no robô

1. **Provisionamento inicial**  
   Execute ambos os scripts no Raspberry Pi embarcado no robô logo após instalar o sistema operacional. Eles são idempotentes: se algo falhar, rode novamente após corrigir o problema apontado.

2. **Serviços no boot**  
   Os comandos já habilitam automaticamente:
   ```bash
   sudo systemctl enable hostapd dnsmasq nginx rpicam-hls.service
   ```
   Confirme após reiniciar usando `systemctl --type=service --state=running | grep -E 'hostapd|dnsmasq|rpicam'`.

3. **Rede do robô**  
   O computador de bordo, controladores auxiliares ou tablets de operação devem conectar-se ao SSID definido, recebendo IP via DHCP. Certifique-se de que módulos adicionais do robô (ex.: ROS, controle de motores) utilizem o gateway `192.168.50.1` ou comuniquem-se diretamente via IP estático.

4. **Interface de rastreamento**  
   Abra `http://192.168.50.1/` a partir do dispositivo de controle do robô. Utilize o botão “Ativar Rastreamento” para capturar a referência visual da pessoa-alvo. O script JavaScript embutido fornece sugestões textuais de movimento (ex.: “virar para a direita”) que podem ser consumidas pelo seu software de navegação.

5. **Sincronização com software do robô**  
   - Para consumir os comandos de movimento, exponha uma API no robô que monitore os logs do navegador ou crie um canal WebSocket a partir da página.  
   - Opcionalmente, adapte `update_web_page()` no script para enviar os dados via REST/ROSBridge, caso deseje automação total.

## Atualização e manutenção

- **Atualizar pacotes**: rerode os scripts após grandes atualizações do sistema para garantir reinstalação de dependências.  
- **Regerar assets**: delete os arquivos baixados em `/var/www/html/static` e rerode `setup_camera_stream.sh` para baixar versões mais novas.  
- **Reverter hotspot**: execute `systemctl disable --now hostapd dnsmasq nginx` e restaure `/etc/dhcpcd.conf`/`/etc/hostapd/hostapd.conf` a partir dos backups que você mantiver.

## Solução de problemas

### Hotspot não inicia automaticamente ao ligar

Se o hotspot WiFi não estiver iniciando automaticamente quando o Raspberry Pi é ligado:

1. **Ver logs do serviço de startup:**
   ```bash
   sudo journalctl -u hotspot-startup.service -b
   ```

2. **Ver logs do hostapd:**
   ```bash
   sudo journalctl -u hostapd -b
   ```

3. **Reiniciar o serviço de hotspot manualmente:**
   ```bash
   sudo systemctl restart hotspot-startup.service
   ```

4. **Ou reiniciar serviços individualmente:**
   ```bash
   sudo systemctl restart dhcpcd
   sudo systemctl restart dnsmasq
   sudo systemctl restart hostapd
   sudo systemctl restart nginx
   ```

5. **Verificar status de todos os serviços:**
   ```bash
   systemctl status hostapd dnsmasq nginx dhcpcd hotspot-startup.service
   ```

### Outros problemas comuns

- **Hotspot não aparece**: verifique se `rfkill list` está liberado. O script já mascara serviços relacionados; execute `sudo rfkill unblock all` como medida adicional.  
- **Serviço `hostapd` falha**: revise `/etc/hostapd/hostapd.conf` para conferir SSID/senha válidos e execute `sudo journalctl -u hostapd -b`.  
- **Stream sem vídeo**: confirme que a câmera está detectada (`libcamera-hello`). Erros comuns aparecem em `journalctl -u rpicam-hls.service`.  
- **Interface web sem UI**: valide se os assets foram copiados para `/var/www/html/static`. Em ambientes sem internet, garanta que a pasta `assets/` permaneça intacta antes da execução do script.

## Novas funcionalidades

### Interface web aprimorada

O sistema agora inclui duas páginas web para controle do robô:

1. **Página de configuração** (`/index.html`)
   - Menu principal com acesso às funcionalidades do sistema
   - Acesso rápido ao modo Live, Configurações e Calibração
   - Exibe informações de rede e IP do robô

2. **Página Live** (`/live.html`)
   - Interface de controle em tempo real otimizada para smartphones em modo paisagem
   - Stream de vídeo HLS em tela cheia
   - Controle por slide horizontal para ajustes direcionais precisos
   - Joystick virtual para movimentação completa (frente, trás, esquerda, direita)
   - Detecção automática de pessoas usando MediaPipe
   - Indicador de status que mostra o movimento sugerido baseado na posição da pessoa detectada
   - Lógica de parada automática quando a pessoa está a aproximadamente 2 metros (área maior que 20% do quadro)
   - Overlays visuais mostrando a caixa delimitadora da pessoa detectada

### Melhorias no startup do hotspot

O script `setup_hotspot.sh` agora inclui um serviço de inicialização sequenciado (`hotspot-startup.service`) que:
- Aguarda o sistema estar completamente pronto antes de iniciar os serviços
- Inicia os serviços na ordem correta: dhcpcd → dnsmasq → hostapd → nginx
- Adiciona delays entre cada inicialização para garantir estabilidade
- Previne falhas de inicialização causadas por condições de corrida

## Estrutura do repositório

```
assets/                     # Bibliotecas, modelos e WASM empacotados para uso offline
setup_hotspot.sh            # Script de provisionamento do hotspot / nginx
setup_camera_stream.sh      # Script de streaming HLS e interface web
create_web_pages.sh         # Script para criação das páginas web do sistema
```

Mantenha o repositório versionado juntamente com a configuração do robô para facilitar auditoria e replicação do ambiente em novas unidades.
