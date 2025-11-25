# Monte Bot - Arduino Motor Controller

Firmware completo para controle de motores do robô R2D2 Monte Bot, desenvolvido pela Liga Acadêmica MONTE BOT da Universidade Federal de Uberlândia.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Hardware Necessário](#hardware-necessário)
- [Diagrama de Conexões](#diagrama-de-conexões)
- [Instalação](#instalação)
- [Protocolo de Comandos](#protocolo-de-comandos)
- [Configuração](#configuração)
- [Teste e Depuração](#teste-e-depuração)
- [Solução de Problemas](#solução-de-problemas)

## 🎯 Visão Geral

Este firmware recebe comandos via Serial USB do Raspberry Pi e controla os motores do robô de acordo com o protocolo definido pelo sistema Monte Bot. É 100% compatível com o servidor WebSocket (`montebot-serial-bridge.py`) que roda no Raspberry Pi.

### Fluxo de Comunicação

```
┌────────────────┐     WebSocket     ┌─────────────────┐     USB Serial    ┌─────────────┐
│  Interface Web │ ◄────────────────► │   Raspberry Pi  │ ◄────────────────► │   Arduino   │
│   (Browser)    │      :8765         │ (Serial Bridge) │    /dev/ttyACM0   │  (Motores)  │
└────────────────┘                    └─────────────────┘                    └─────────────┘
```

## 🔧 Hardware Necessário

### Componentes Básicos

| Componente | Quantidade | Observações |
|------------|------------|-------------|
| Arduino Uno/Nano/Mega | 1 | Qualquer Arduino com USB e 6+ pinos digitais |
| Driver L298N | 1 | Ou driver compatível (TB6612, BTS7960) |
| Motores DC | 2 | 6-12V, compatíveis com o driver |
| Bateria | 1 | 7-12V para alimentar os motores |
| Cabo USB | 1 | Para conectar Arduino ao Raspberry Pi |

### Opcional

| Componente | Quantidade | Observações |
|------------|------------|-------------|
| Regulador de tensão 5V | 1 | Se a bateria for maior que 12V |
| Capacitores 100µF | 2 | Para filtrar ruído dos motores |
| Fusível ou disjuntor | 1 | Proteção contra curto-circuito |

## 📊 Diagrama de Conexões

### Conexão Arduino → Driver L298N

```
                  ┌─────────────────┐
                  │     L298N       │
                  │                 │
    Arduino       │  IN1  IN2  ENA  │     Motor Esquerdo
    ────────      │  ───  ───  ───  │     ──────────────
    Pino 7  ─────►│  ●              │
    Pino 6  ─────►│       ●         │
    Pino 5  ─────►│            ●    │ ════╗    ┌─────┐
                  │                 │     ╚════│  M  │
                  │  IN3  IN4  ENB  │     ╔════│  L  │
    Arduino       │  ───  ───  ───  │     ║    └─────┘
    ────────      │  ●              │ ════╝
    Pino 4  ─────►│       ●         │
    Pino 3  ─────►│            ●    │ ════╗    ┌─────┐
    Pino 9  ─────►│                 │     ╚════│  M  │
                  │                 │     ╔════│  R  │
                  │  GND  +12V  +5V │     ║    └─────┘
                  │  ───  ────  ─── │ ════╝
                  └─────────────────┘
                     │     │     │
                     │     │     └── Para Arduino 5V (opcional)
                     │     └──────── Bateria +
                     └────────────── Bateria - e Arduino GND
```

### Tabela de Pinos

| Pino Arduino | Função | Conexão L298N |
|--------------|--------|---------------|
| 7 | LEFT_IN1 | IN1 |
| 6 | LEFT_IN2 | IN2 |
| 5 | LEFT_PWM | ENA |
| 4 | RIGHT_IN1 | IN3 |
| 3 | RIGHT_IN2 | IN4 |
| 9 | RIGHT_PWM | ENB |
| GND | Terra | GND |
| 5V | Alimentação (opcional) | +5V |

### Diagrama de Fiação Completo

```
                    ┌──────────────────┐
                    │   RASPBERRY PI   │
                    │                  │
                    │     USB ─────────┼──────┐
                    └──────────────────┘      │
                                              │ Cabo USB
                    ┌──────────────────┐      │
                    │     ARDUINO      │◄─────┘
                    │                  │
                    │  7  6  5  4  3  9│
                    │  │  │  │  │  │  ││
                    │ GND ─────────────┼──┐
                    │  5V ─────────────┼──┼──┐
                    └──────────────────┘  │  │
                       │  │  │  │  │  │   │  │
    ┌──────────────────┘  │  │  │  │  │   │  │
    │  ┌──────────────────┘  │  │  │  │   │  │
    │  │  ┌──────────────────┘  │  │  │   │  │
    │  │  │  ┌──────────────────┘  │  │   │  │
    │  │  │  │  ┌──────────────────┘  │   │  │
    │  │  │  │  │  ┌──────────────────┘   │  │
    │  │  │  │  │  │                      │  │
    ▼  ▼  ▼  ▼  ▼  ▼                      ▼  ▼
   ┌────────────────────────────────────────────┐
   │               DRIVER L298N                  │
   │                                             │
   │  IN1 IN2 ENA    IN3 IN4 ENB    +12V GND +5V│
   │   │   │   │      │   │   │       │   │   │ │
   │   ▼   ▼   ▼      ▼   ▼   ▼       │   │   │ │
   │  ┌─────────┐    ┌─────────┐      │   │   │ │
   │  │ MOTOR E │    │ MOTOR D │      │   │   │ │
   │  │ (LEFT)  │    │ (RIGHT) │      │   │   │ │
   │  └─────────┘    └─────────┘      │   │   │ │
   └──────────────────────────────────┼───┼───┼─┘
                                      │   │   │
                    ┌─────────────────┘   │   │
                    │   ┌─────────────────┘   │
                    │   │   ┌─────────────────┘
                    ▼   ▼   ▼
                   ┌─────────┐
                   │ BATERIA │
                   │ 7-12V   │
                   │  + │ -  │
                   └───┼─┼───┘
                       │ │
                       └─┴──── Comum ao GND
```

## 📥 Instalação

### Passo 1: Baixar o Código

```bash
# No computador ou Raspberry Pi
git clone https://github.com/roosoars/monte-bot.git
cd monte-bot/arduino/montebot_motor_controller
```

### Passo 2: Abrir na Arduino IDE

1. Abra a Arduino IDE
2. Vá em **Arquivo → Abrir**
3. Navegue até `monte-bot/arduino/montebot_motor_controller/`
4. Selecione `montebot_motor_controller.ino`

### Passo 3: Configurar a Placa

1. Vá em **Ferramentas → Placa** e selecione seu Arduino
2. Vá em **Ferramentas → Porta** e selecione a porta USB correta

### Passo 4: Upload

1. Clique no botão **Upload** (seta para direita)
2. Aguarde a mensagem "Upload completo"

### Passo 5: Verificar

1. Abra o **Monitor Serial** (Ctrl+Shift+M)
2. Configure para **115200 baud**
3. Você deve ver:

```
========================================
    MONTE BOT - Motor Controller
    Liga Academica MONTE BOT - UFU
========================================
VERSION:1.0.0
BAUDRATE:115200
STATUS:READY

COMMANDS:
  F=Forward, T=Back, E=Left, D=Right, P=Stop
  E1=SlideLeft, D1=SlideRight, P1=SlideCenter

WAITING_COMMANDS...
```

## 📡 Protocolo de Comandos

### Comandos Principais (Movimento)

| Comando | Descrição | Ação dos Motores |
|---------|-----------|------------------|
| `F` | Frente (Forward) | Ambos motores para frente |
| `T` | Trás (Back) | Ambos motores para trás |
| `E` | Esquerda (Left) | Motor E para trás, motor D para frente |
| `D` | Direita (Right) | Motor E para frente, motor D para trás |
| `P` | Parado (Stop) | Ambos motores parados |

### Comandos de Slide (Ajuste Fino)

| Comando | Descrição | Ação |
|---------|-----------|------|
| `E1` | Slide Esquerda | Reduz velocidade do motor esquerdo |
| `D1` | Slide Direita | Reduz velocidade do motor direito |
| `P1` | Slide Centro | Remove ajustes de slide |

### Formato de Resposta

```
CMD:<comando>:OK
```

Exemplo:
```
CMD:F:OK       # Comando F recebido com sucesso
CMD:P:OK       # Comando P recebido com sucesso
CMD:X:INVALID  # Comando inválido
TIMEOUT:SAFETY_STOP  # Parada por timeout de segurança
```

## ⚙️ Configuração

### Ajuste de Pinos

Se você usar pinos diferentes, edite as definições no início do código:

```cpp
// Motor Esquerdo
#define LEFT_IN1    7   // Mude para o pino desejado
#define LEFT_IN2    6
#define LEFT_PWM    5   // Precisa ser pino PWM (~)

// Motor Direito
#define RIGHT_IN1   4
#define RIGHT_IN2   3
#define RIGHT_PWM   9   // Precisa ser pino PWM (~)
```

### Ajuste de Velocidades

```cpp
#define SPEED_MAX         200   // Velocidade máxima (0-255)
#define SPEED_MEDIUM      150   // Velocidade de virada
#define SPEED_SLOW        100   // Velocidade lenta
#define SPEED_CORRECTION   80   // Correção de trajetória
```

### Timeout de Segurança

```cpp
const unsigned long TIMEOUT_MS = 500;  // Tempo em ms para parar se sem comandos
```

Se o Arduino não receber comandos por 500ms, ele para automaticamente os motores.

## 🧪 Teste e Depuração

### Teste Manual via Monitor Serial

1. Abra o Monitor Serial (115200 baud)
2. Digite comandos e pressione Enter:

```
F        # Motores para frente
P        # Para
E        # Virar esquerda
P        # Para
D        # Virar direita
P        # Para
T        # Para trás
P        # Para
```

### Teste Automático de Motores

Para testar todos os motores automaticamente, descomente a linha no `setup()`:

```cpp
// No setup(), descomente:
motorTest();
```

Isso executará:
1. Motor esquerdo para frente (0.3s)
2. Motor esquerdo para trás (0.3s)
3. Motor direito para frente (0.3s)
4. Motor direito para trás (0.3s)

### Teste via WebSocket (Raspberry Pi)

1. Conecte o Arduino ao Raspberry Pi via USB
2. Acesse `http://192.168.50.1/logs.html` no navegador
3. Use os botões de comando rápido para testar

## 🔍 Solução de Problemas

### Arduino não aparece no Raspberry Pi

```bash
# Verificar dispositivos USB
ls -la /dev/ttyACM* /dev/ttyUSB*

# Verificar permissões
sudo usermod -aG dialout $USER
sudo chmod 666 /dev/ttyACM0
```

### Motores não funcionam

1. **Verifique a alimentação**: O L298N precisa de alimentação externa (7-12V)
2. **Verifique o jumper do L298N**: O jumper de 5V deve estar no lugar correto
3. **Verifique as conexões**: Use um multímetro para verificar continuidade

### Motor gira na direção errada

Troque os fios do motor (+ e -) ou ajuste no código:

```cpp
// Inverter direção do motor esquerdo
void moveForward() {
  setLeftMotor(SPEED_MAX, false);  // Mudou de true para false
  setRightMotor(SPEED_MAX, true);
}
```

### Comandos não chegam ao Arduino

1. Verifique se o baudrate é 115200
2. Verifique se o serviço `montebot-serial.service` está rodando:

```bash
sudo systemctl status montebot-serial.service
sudo journalctl -u montebot-serial.service -f
```

### LED não pisca ao receber comandos

- Verifique se o LED_BUILTIN está funcionando (pino 13)
- Teste com um LED externo no pino 13

## 📄 Licença

Este projeto é desenvolvido pela Liga Acadêmica MONTE BOT da Universidade Federal de Uberlândia para fins educacionais.

## 🤝 Contribuições

Contribuições são bem-vindas! Abra uma issue ou pull request no repositório.

---

**Monte Bot Team - UFU** 🤖
