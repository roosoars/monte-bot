/**
 * Monte Bot - Arduino Motor Controller
 * 
 * Firmware completo para controle de motores do robô R2D2 Monte Bot
 * Desenvolvido para Liga Acadêmica MONTE BOT - Universidade Federal de Uberlândia
 * 
 * Este código recebe comandos via Serial USB do Raspberry Pi e controla
 * os motores de acordo com o protocolo definido pelo sistema Monte Bot.
 * 
 * PROTOCOLO DE COMANDOS:
 * ----------------------
 * Comandos de movimento principal (acionados pelo joystick ou detecção automática):
 *   F  - Frente (Forward)   : Ambos os motores para frente
 *   T  - Trás (Back)        : Ambos os motores para trás
 *   E  - Esquerda (Left)    : Virar para esquerda (motor esquerdo para trás, direito para frente)
 *   D  - Direita (Right)    : Virar para direita (motor esquerdo para frente, direito para trás)
 *   P  - Parado (Stop)      : Parar todos os motores
 * 
 * Comandos de ajuste fino (acionados pelo slide horizontal):
 *   E1 - Slide Esquerda     : Ajuste leve para esquerda (usado para correção de trajetória)
 *   D1 - Slide Direita      : Ajuste leve para direita (usado para correção de trajetória)
 *   P1 - Slide Centro       : Sem ajuste lateral
 * 
 * CONEXÕES DO HARDWARE:
 * ---------------------
 * Driver L298N (ou compatível):
 * 
 * Motor Esquerdo:
 *   - IN1 -> Pino 2 (LEFT_IN1)
 *   - IN2 -> Pino 3 (LEFT_IN2)
 *   - ENA -> Jumper para +5V (velocidade máxima fixa)
 * 
 * Motor Direito:
 *   - IN3 -> Pino 4 (RIGHT_IN1)
 *   - IN4 -> Pino 5 (RIGHT_IN2)
 *   - ENB -> Jumper para +5V (velocidade máxima fixa)
 * 
 * Servo Motor:
 *   - Sinal -> Pino 9
 *   - VCC -> 5V
 *   - GND -> GND
 * 
 * Alimentação:
 *   - VCC do L298N -> Bateria (7-12V para motores)
 *   - GND do L298N -> GND da bateria e GND do Arduino
 *   - 5V do L298N -> Pode ser usado para alimentar Arduino (se jumper estiver)
 * 
 * Conexão Serial:
 *   - USB do Arduino -> USB do Raspberry Pi (/dev/ttyACM0 ou /dev/ttyUSB0)
 * 
 * LED Status:
 *   - LED_BUILTIN (pino 13) -> Pisca para indicar recebimento de comandos
 * 
 * CONFIGURAÇÃO DO BAUDRATE:
 * -------------------------
 * O baudrate padrão é 115200, compatível com montebot-serial-bridge.py
 * Pode ser alterado via variável de ambiente SERIAL_BAUDRATE no Raspberry Pi
 * 
 * @author Monte Bot Team - UFU
 * @version 1.1.0
 * @date 2024
 */

// =============================================================================
// CONFIGURAÇÃO DE PINOS - Ajuste conforme sua montagem
// =============================================================================

// Motor Esquerdo (Left Motor) - L298N IN1/IN2
// NOTA: ENA deve ser conectado via jumper a +5V para velocidade máxima fixa
#define LEFT_IN1    2   // Direção 1 do motor esquerdo
#define LEFT_IN2    3   // Direção 2 do motor esquerdo

// Motor Direito (Right Motor) - L298N IN3/IN4
// NOTA: ENB deve ser conectado via jumper a +5V para velocidade máxima fixa
#define RIGHT_IN1   4   // Direção 1 do motor direito
#define RIGHT_IN2   5   // Direção 2 do motor direito

// Servo Motor
#define SERVO_PIN        9    // Pino do servo motor
#define SERVO_LEFT_POS   60   // Posição esquerda do servo (0-180 graus)
#define SERVO_CENTER_POS 90   // Posição central do servo
#define SERVO_RIGHT_POS  120  // Posição direita do servo

// LED de status
#define STATUS_LED  LED_BUILTIN  // Pino 13 na maioria dos Arduinos

// =============================================================================
// BIBLIOTECAS
// =============================================================================

#include <Servo.h>

// =============================================================================
// VARIÁVEIS GLOBAIS
// =============================================================================

// Objeto Servo
Servo servoMotor;

// Posição atual do servo (0-180 graus)
int servoPosition = SERVO_CENTER_POS;  // Posição central inicial

// Comando atual e anterior
char currentCommand = 'P';      // Comando em execução
char lastCommand = 'P';         // Último comando recebido
char slideCommand = 'P';        // Comando de slide (E1, D1, P1)

// Direções dos motores
bool leftForward = true;
bool rightForward = true;

// Controle de tempo
unsigned long lastCommandTime = 0;
const unsigned long TIMEOUT_MS = 500;  // Timeout de segurança (para comandos)

// Buffer de entrada serial
String inputBuffer = "";
bool commandComplete = false;

// =============================================================================
// FUNÇÕES DE CONTROLE DOS MOTORES
// =============================================================================

/**
 * Configura os pinos de saída para os motores e servo
 */
void setupMotorPins() {
  pinMode(LEFT_IN1, OUTPUT);
  pinMode(LEFT_IN2, OUTPUT);
  
  pinMode(RIGHT_IN1, OUTPUT);
  pinMode(RIGHT_IN2, OUTPUT);
  
  pinMode(STATUS_LED, OUTPUT);
  
  // Configura o servo motor
  servoMotor.attach(SERVO_PIN);
  servoMotor.write(servoPosition);  // Posição inicial (centro)
  
  // Iniciar com motores parados
  stopMotors();
}

/**
 * Define a direção do motor esquerdo (sem controle PWM, velocidade fixa)
 * @param forward true = frente, false = trás
 * @param active true = motor ligado, false = motor parado
 */
void setLeftMotor(bool forward, bool active) {
  leftForward = forward;
  
  if (!active) {
    // Motor parado
    digitalWrite(LEFT_IN1, LOW);
    digitalWrite(LEFT_IN2, LOW);
  } else if (forward) {
    // Motor para frente
    digitalWrite(LEFT_IN1, HIGH);
    digitalWrite(LEFT_IN2, LOW);
  } else {
    // Motor para trás
    digitalWrite(LEFT_IN1, LOW);
    digitalWrite(LEFT_IN2, HIGH);
  }
}

/**
 * Define a direção do motor direito (sem controle PWM, velocidade fixa)
 * @param forward true = frente, false = trás
 * @param active true = motor ligado, false = motor parado
 */
void setRightMotor(bool forward, bool active) {
  rightForward = forward;
  
  if (!active) {
    // Motor parado
    digitalWrite(RIGHT_IN1, LOW);
    digitalWrite(RIGHT_IN2, LOW);
  } else if (forward) {
    // Motor para frente
    digitalWrite(RIGHT_IN1, HIGH);
    digitalWrite(RIGHT_IN2, LOW);
  } else {
    // Motor para trás
    digitalWrite(RIGHT_IN1, LOW);
    digitalWrite(RIGHT_IN2, HIGH);
  }
}

/**
 * Para ambos os motores imediatamente
 */
void stopMotors() {
  setLeftMotor(true, false);
  setRightMotor(true, false);
}

/**
 * Move o robô para frente
 */
void moveForward() {
  setLeftMotor(true, true);
  setRightMotor(true, true);
}

/**
 * Move o robô para trás
 */
void moveBackward() {
  setLeftMotor(false, true);
  setRightMotor(false, true);
}

/**
 * Vira o robô para a esquerda (no próprio eixo)
 */
void turnLeft() {
  setLeftMotor(false, true);  // Motor esquerdo para trás
  setRightMotor(true, true);  // Motor direito para frente
}

/**
 * Vira o robô para a direita (no próprio eixo)
 */
void turnRight() {
  setLeftMotor(true, true);   // Motor esquerdo para frente
  setRightMotor(false, true); // Motor direito para trás
}

/**
 * Ajuste fino para esquerda usando o servo (correção de trajetória)
 * Usado quando o slide horizontal é movido para esquerda
 */
void adjustLeft() {
  // Move o servo para a esquerda
  servoPosition = SERVO_LEFT_POS;
  servoMotor.write(servoPosition);
}

/**
 * Ajuste fino para direita usando o servo (correção de trajetória)
 * Usado quando o slide horizontal é movido para direita
 */
void adjustRight() {
  // Move o servo para a direita
  servoPosition = SERVO_RIGHT_POS;
  servoMotor.write(servoPosition);
}

/**
 * Remove ajustes de correção (centraliza o servo)
 */
void noAdjustment() {
  // Centraliza o servo
  servoPosition = SERVO_CENTER_POS;
  servoMotor.write(servoPosition);
}

// =============================================================================
// PROCESSAMENTO DE COMANDOS
// =============================================================================

/**
 * Executa o comando principal de movimento
 * @param cmd Caractere do comando (F, T, E, D, P)
 */
void executeMainCommand(char cmd) {
  switch (cmd) {
    case 'F':  // Frente (Forward)
      moveForward();
      break;
      
    case 'T':  // Trás (Backward)
      moveBackward();
      break;
      
    case 'E':  // Esquerda (Left)
      turnLeft();
      break;
      
    case 'D':  // Direita (Right)
      turnRight();
      break;
      
    case 'P':  // Parado (Stop)
    default:
      stopMotors();
      break;
  }
}

/**
 * Executa o comando de slide (ajuste fino)
 * @param cmd String do comando (E1, D1, P1)
 */
void executeSlideCommand(String cmd) {
  if (cmd == "E1") {
    slideCommand = 'L';  // Left adjustment
    adjustLeft();
  } else if (cmd == "D1") {
    slideCommand = 'R';  // Right adjustment
    adjustRight();
  } else if (cmd == "P1") {
    slideCommand = 'P';  // No adjustment
    noAdjustment();
  }
}

/**
 * Processa o comando recebido via Serial
 * @param command String do comando recebido
 */
void processCommand(String command) {
  command.trim();
  command.toUpperCase();
  
  if (command.length() == 0) {
    return;
  }
  
  // Atualiza timestamp do último comando
  lastCommandTime = millis();
  
  // Pisca LED para indicar recebimento de comando
  digitalWrite(STATUS_LED, HIGH);
  
  // Log do comando recebido
  Serial.print("CMD:");
  Serial.print(command);
  Serial.print(":OK");
  
  // Comandos de slide (2 caracteres)
  if (command.length() == 2 && (command[1] == '1')) {
    executeSlideCommand(command);
    Serial.println();
    return;
  }
  
  // Comandos principais (1 caractere)
  if (command.length() == 1) {
    char cmd = command.charAt(0);
    
    // Verifica se é um comando válido
    if (cmd == 'F' || cmd == 'T' || cmd == 'E' || cmd == 'D' || cmd == 'P') {
      lastCommand = currentCommand;
      currentCommand = cmd;
      executeMainCommand(cmd);
    } else {
      Serial.print(":INVALID");
    }
  } else {
    Serial.print(":UNKNOWN");
  }
  
  Serial.println();
  
  // Apaga LED após processar
  digitalWrite(STATUS_LED, LOW);
}

// =============================================================================
// FUNÇÕES DE SEGURANÇA
// =============================================================================

/**
 * Verifica timeout de comando
 * Para os motores se não receber comandos por TIMEOUT_MS
 */
void checkCommandTimeout() {
  if (currentCommand != 'P' && (millis() - lastCommandTime) > TIMEOUT_MS) {
    // Timeout! Para os motores por segurança
    Serial.println("TIMEOUT:SAFETY_STOP");
    currentCommand = 'P';
    stopMotors();
  }
}

// =============================================================================
// FUNÇÃO DE LEITURA SERIAL
// =============================================================================

/**
 * Lê dados da porta serial e processa comandos
 */
void readSerialData() {
  while (Serial.available() > 0) {
    char inChar = (char)Serial.read();
    
    // Fim de linha = comando completo
    if (inChar == '\n' || inChar == '\r') {
      if (inputBuffer.length() > 0) {
        processCommand(inputBuffer);
        inputBuffer = "";
      }
    } else {
      // Acumula caracteres no buffer
      inputBuffer += inChar;
      
      // Proteção contra buffer overflow
      if (inputBuffer.length() > 10) {
        inputBuffer = "";
      }
    }
  }
}

// =============================================================================
// FUNÇÃO DE TESTE DOS MOTORES
// =============================================================================

/**
 * Teste automático dos motores e servo ao iniciar
 * Executa uma sequência de movimentos para verificar funcionamento
 */
void motorTest() {
  Serial.println("MOTOR_TEST:START");
  
  // Teste motor esquerdo para frente
  Serial.println("TEST:LEFT_FORWARD");
  setLeftMotor(true, true);
  delay(300);
  setLeftMotor(true, false);
  delay(200);
  
  // Teste motor esquerdo para trás
  Serial.println("TEST:LEFT_BACKWARD");
  setLeftMotor(false, true);
  delay(300);
  setLeftMotor(true, false);
  delay(200);
  
  // Teste motor direito para frente
  Serial.println("TEST:RIGHT_FORWARD");
  setRightMotor(true, true);
  delay(300);
  setRightMotor(true, false);
  delay(200);
  
  // Teste motor direito para trás
  Serial.println("TEST:RIGHT_BACKWARD");
  setRightMotor(false, true);
  delay(300);
  setRightMotor(true, false);
  delay(200);
  
  // Teste servo motor
  Serial.println("TEST:SERVO_LEFT");
  servoMotor.write(SERVO_LEFT_POS);
  delay(500);
  Serial.println("TEST:SERVO_CENTER");
  servoMotor.write(SERVO_CENTER_POS);
  delay(500);
  Serial.println("TEST:SERVO_RIGHT");
  servoMotor.write(SERVO_RIGHT_POS);
  delay(500);
  Serial.println("TEST:SERVO_CENTER");
  servoMotor.write(SERVO_CENTER_POS);
  delay(200);
  
  Serial.println("MOTOR_TEST:COMPLETE");
}

// =============================================================================
// FUNÇÕES PRINCIPAIS DO ARDUINO
// =============================================================================

/**
 * Configuração inicial (executada uma vez)
 */
void setup() {
  // Inicializa comunicação serial
  Serial.begin(115200);
  
  // Aguarda porta serial estar pronta (com timeout de 3 segundos)
  // Necessário para placas com USB nativo (Leonardo, Micro, etc.)
  // Para Arduino Uno/Nano, isso retorna imediatamente
  unsigned long serialWaitStart = millis();
  while (!Serial && (millis() - serialWaitStart) < 3000) {
    ; // Aguarda conexão USB ou timeout
  }
  
  // Configurar pinos dos motores e servo
  setupMotorPins();
  
  // Mensagem de inicialização
  Serial.println("");
  Serial.println("========================================");
  Serial.println("    MONTE BOT - Motor Controller");
  Serial.println("    Liga Academica MONTE BOT - UFU");
  Serial.println("========================================");
  Serial.println("VERSION:1.1.0");
  Serial.println("BAUDRATE:115200");
  Serial.println("STATUS:READY");
  Serial.println("");
  Serial.println("PINS:");
  Serial.println("  Motors: 2,3,4,5 (ENA/ENB jumper to +5V)");
  Serial.println("  Servo: 9");
  Serial.println("");
  Serial.println("COMMANDS:");
  Serial.println("  F=Forward, T=Back, E=Left, D=Right, P=Stop");
  Serial.println("  E1=SlideLeft, D1=SlideRight, P1=SlideCenter");
  Serial.println("");
  
  // Executar teste de motores (descomente para testar)
  // motorTest();
  
  Serial.println("WAITING_COMMANDS...");
}

/**
 * Loop principal (executado continuamente)
 */
void loop() {
  // Lê e processa comandos seriais
  readSerialData();
  
  // Verifica timeout de segurança
  checkCommandTimeout();
  
  // Pequeno delay para estabilidade
  delay(1);
}

// =============================================================================
// FIM DO CÓDIGO
// =============================================================================
