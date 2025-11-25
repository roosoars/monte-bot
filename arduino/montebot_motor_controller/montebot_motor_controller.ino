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
 *   - IN1 -> Pino 7 (ENA_PIN1)
 *   - IN2 -> Pino 6 (ENA_PIN2)
 *   - ENA -> Pino 5 (PWM_LEFT) - PWM para controle de velocidade
 * 
 * Motor Direito:
 *   - IN3 -> Pino 4 (ENB_PIN1)
 *   - IN4 -> Pino 3 (ENB_PIN2)
 *   - ENB -> Pino 9 (PWM_RIGHT) - PWM para controle de velocidade
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
 * @version 1.0.0
 * @date 2024
 */

// =============================================================================
// CONFIGURAÇÃO DE PINOS - Ajuste conforme sua montagem
// =============================================================================

// Motor Esquerdo (Left Motor) - L298N IN1/IN2/ENA
#define LEFT_IN1    7   // Direção 1 do motor esquerdo
#define LEFT_IN2    6   // Direção 2 do motor esquerdo
#define LEFT_PWM    5   // Velocidade do motor esquerdo (PWM)

// Motor Direito (Right Motor) - L298N IN3/IN4/ENB
#define RIGHT_IN1   4   // Direção 1 do motor direito
#define RIGHT_IN2   3   // Direção 2 do motor direito
#define RIGHT_PWM   9   // Velocidade do motor direito (PWM)

// LED de status
#define STATUS_LED  LED_BUILTIN  // Pino 13 na maioria dos Arduinos

// =============================================================================
// CONFIGURAÇÃO DE VELOCIDADES - Ajuste conforme necessário (0-255)
// =============================================================================

#define SPEED_MAX         200   // Velocidade máxima (movimento principal)
#define SPEED_MEDIUM      150   // Velocidade média (viradas)
#define SPEED_SLOW        100   // Velocidade lenta (ajustes finos)
#define SPEED_CORRECTION   80   // Velocidade de correção de trajetória (slide)

// Tempo de rampa de aceleração (ms) - para suavizar movimentos (recurso opcional)
// Descomente updateRamp() no loop() para usar
#define RAMP_DELAY         10   // Delay entre incrementos de velocidade
#define RAMP_INCREMENT     20   // Incremento de velocidade por passo

// =============================================================================
// VARIÁVEIS GLOBAIS
// =============================================================================

// Comando atual e anterior
char currentCommand = 'P';      // Comando em execução
char lastCommand = 'P';         // Último comando recebido
char slideCommand = 'P';        // Comando de slide (E1, D1, P1)

// Velocidades atuais dos motores
int leftSpeed = 0;
int rightSpeed = 0;

// Velocidades alvo (usadas apenas com rampa de aceleração habilitada)
int targetLeftSpeed = 0;
int targetRightSpeed = 0;

// Direções dos motores
bool leftForward = true;
bool rightForward = true;

// Controle de tempo
unsigned long lastCommandTime = 0;
unsigned long lastRampTime = 0;  // Usada apenas com rampa de aceleração
const unsigned long TIMEOUT_MS = 500;  // Timeout de segurança (para comandos)

// Buffer de entrada serial
String inputBuffer = "";
bool commandComplete = false;

// =============================================================================
// FUNÇÕES DE CONTROLE DOS MOTORES
// =============================================================================

/**
 * Configura os pinos de saída para os motores
 */
void setupMotorPins() {
  pinMode(LEFT_IN1, OUTPUT);
  pinMode(LEFT_IN2, OUTPUT);
  pinMode(LEFT_PWM, OUTPUT);
  
  pinMode(RIGHT_IN1, OUTPUT);
  pinMode(RIGHT_IN2, OUTPUT);
  pinMode(RIGHT_PWM, OUTPUT);
  
  pinMode(STATUS_LED, OUTPUT);
  
  // Iniciar com motores parados
  stopMotors();
}

/**
 * Define a velocidade e direção do motor esquerdo
 * @param speed Velocidade (0-255)
 * @param forward true = frente, false = trás
 */
void setLeftMotor(int speed, bool forward) {
  leftSpeed = constrain(speed, 0, 255);
  leftForward = forward;
  
  if (leftSpeed == 0) {
    // Motor parado
    digitalWrite(LEFT_IN1, LOW);
    digitalWrite(LEFT_IN2, LOW);
    analogWrite(LEFT_PWM, 0);
  } else if (forward) {
    // Motor para frente
    digitalWrite(LEFT_IN1, HIGH);
    digitalWrite(LEFT_IN2, LOW);
    analogWrite(LEFT_PWM, leftSpeed);
  } else {
    // Motor para trás
    digitalWrite(LEFT_IN1, LOW);
    digitalWrite(LEFT_IN2, HIGH);
    analogWrite(LEFT_PWM, leftSpeed);
  }
}

/**
 * Define a velocidade e direção do motor direito
 * @param speed Velocidade (0-255)
 * @param forward true = frente, false = trás
 */
void setRightMotor(int speed, bool forward) {
  rightSpeed = constrain(speed, 0, 255);
  rightForward = forward;
  
  if (rightSpeed == 0) {
    // Motor parado
    digitalWrite(RIGHT_IN1, LOW);
    digitalWrite(RIGHT_IN2, LOW);
    analogWrite(RIGHT_PWM, 0);
  } else if (forward) {
    // Motor para frente
    digitalWrite(RIGHT_IN1, HIGH);
    digitalWrite(RIGHT_IN2, LOW);
    analogWrite(RIGHT_PWM, rightSpeed);
  } else {
    // Motor para trás
    digitalWrite(RIGHT_IN1, LOW);
    digitalWrite(RIGHT_IN2, HIGH);
    analogWrite(RIGHT_PWM, rightSpeed);
  }
}

/**
 * Para ambos os motores imediatamente
 */
void stopMotors() {
  setLeftMotor(0, true);
  setRightMotor(0, true);
  targetLeftSpeed = 0;
  targetRightSpeed = 0;
}

/**
 * Move o robô para frente
 */
void moveForward() {
  targetLeftSpeed = SPEED_MAX;
  targetRightSpeed = SPEED_MAX;
  setLeftMotor(SPEED_MAX, true);
  setRightMotor(SPEED_MAX, true);
}

/**
 * Move o robô para trás
 */
void moveBackward() {
  targetLeftSpeed = SPEED_MAX;
  targetRightSpeed = SPEED_MAX;
  setLeftMotor(SPEED_MAX, false);
  setRightMotor(SPEED_MAX, false);
}

/**
 * Vira o robô para a esquerda (no próprio eixo)
 */
void turnLeft() {
  targetLeftSpeed = SPEED_MEDIUM;
  targetRightSpeed = SPEED_MEDIUM;
  setLeftMotor(SPEED_MEDIUM, false);  // Motor esquerdo para trás
  setRightMotor(SPEED_MEDIUM, true);  // Motor direito para frente
}

/**
 * Vira o robô para a direita (no próprio eixo)
 */
void turnRight() {
  targetLeftSpeed = SPEED_MEDIUM;
  targetRightSpeed = SPEED_MEDIUM;
  setLeftMotor(SPEED_MEDIUM, true);   // Motor esquerdo para frente
  setRightMotor(SPEED_MEDIUM, false); // Motor direito para trás
}

/**
 * Ajuste fino para esquerda (correção de trajetória)
 * Usado quando o slide horizontal é movido para esquerda
 */
void adjustLeft() {
  // Reduz velocidade do motor esquerdo para curvar suavemente
  int adjustedLeftSpeed = max(0, leftSpeed - SPEED_CORRECTION);
  setLeftMotor(adjustedLeftSpeed, leftForward);
}

/**
 * Ajuste fino para direita (correção de trajetória)
 * Usado quando o slide horizontal é movido para direita
 */
void adjustRight() {
  // Reduz velocidade do motor direito para curvar suavemente
  int adjustedRightSpeed = max(0, rightSpeed - SPEED_CORRECTION);
  setRightMotor(adjustedRightSpeed, rightForward);
}

/**
 * Remove ajustes de correção
 */
void noAdjustment() {
  // Restaura velocidades baseado no comando principal atual
  executeMainCommand(currentCommand);
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

/**
 * Função de rampa de aceleração (opcional)
 * Suaviza transições de velocidade
 */
void updateRamp() {
  if (millis() - lastRampTime < RAMP_DELAY) {
    return;
  }
  lastRampTime = millis();
  
  // Rampa para motor esquerdo
  if (leftSpeed < targetLeftSpeed) {
    leftSpeed = min(leftSpeed + RAMP_INCREMENT, targetLeftSpeed);
    analogWrite(LEFT_PWM, leftSpeed);
  } else if (leftSpeed > targetLeftSpeed) {
    leftSpeed = max(leftSpeed - RAMP_INCREMENT, targetLeftSpeed);
    analogWrite(LEFT_PWM, leftSpeed);
  }
  
  // Rampa para motor direito
  if (rightSpeed < targetRightSpeed) {
    rightSpeed = min(rightSpeed + RAMP_INCREMENT, targetRightSpeed);
    analogWrite(RIGHT_PWM, rightSpeed);
  } else if (rightSpeed > targetRightSpeed) {
    rightSpeed = max(rightSpeed - RAMP_INCREMENT, targetRightSpeed);
    analogWrite(RIGHT_PWM, rightSpeed);
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
 * Teste automático dos motores ao iniciar
 * Executa uma sequência de movimentos para verificar funcionamento
 */
void motorTest() {
  Serial.println("MOTOR_TEST:START");
  
  // Teste motor esquerdo para frente
  Serial.println("TEST:LEFT_FORWARD");
  setLeftMotor(SPEED_SLOW, true);
  delay(300);
  setLeftMotor(0, true);
  delay(200);
  
  // Teste motor esquerdo para trás
  Serial.println("TEST:LEFT_BACKWARD");
  setLeftMotor(SPEED_SLOW, false);
  delay(300);
  setLeftMotor(0, true);
  delay(200);
  
  // Teste motor direito para frente
  Serial.println("TEST:RIGHT_FORWARD");
  setRightMotor(SPEED_SLOW, true);
  delay(300);
  setRightMotor(0, true);
  delay(200);
  
  // Teste motor direito para trás
  Serial.println("TEST:RIGHT_BACKWARD");
  setRightMotor(SPEED_SLOW, false);
  delay(300);
  setRightMotor(0, true);
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
  
  // Configurar pinos dos motores
  setupMotorPins();
  
  // Mensagem de inicialização
  Serial.println("");
  Serial.println("========================================");
  Serial.println("    MONTE BOT - Motor Controller");
  Serial.println("    Liga Academica MONTE BOT - UFU");
  Serial.println("========================================");
  Serial.println("VERSION:1.0.0");
  Serial.println("BAUDRATE:115200");
  Serial.println("STATUS:READY");
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
  
  // Atualiza rampa de aceleração (opcional)
  // updateRamp();
  
  // Pequeno delay para estabilidade
  delay(1);
}

// =============================================================================
// FIM DO CÓDIGO
// =============================================================================
