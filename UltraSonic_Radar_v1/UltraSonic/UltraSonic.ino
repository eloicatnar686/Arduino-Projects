
#include <LiquidCrystal.h>
#include <Servo.h>

// =====================================
// CONFIGURACION
// =====================================

// LCD
LiquidCrystal lcd(12, 10, 5, 4, 3, 2);

// SENSOR ULTRASONICO
#define TRIG 8
#define ECHO 9

// BUZZER
#define BUZZER 13

// SERVO
#define SERVO_PIN 6

Servo radarServo;

// =====================================
// CONFIGURACION DEL RADAR
// =====================================

const int ANGULO_MINIMO = 0;
const int ANGULO_MAXIMO = 180;

const int PASO_ANGULO = 2;

// Tiempo para estabilizar el servo
const int TIEMPO_SERVO = 15;

// =====================================
// CONFIGURACION DE DISTANCIA
// =====================================

const float DISTANCIA_MAXIMA = 200.0;
const float DISTANCIA_PELIGRO = 40.0;

// =====================================
// VARIABLES
// =====================================

float distancia = -1;

int angulo = ANGULO_MINIMO;
int direccion = 1;

unsigned long ultimoPitido = 0;

int modoActual = -1;

bool tonoAgudo = false;

// =====================================
// INICIALIZACION
// =====================================

void setup() {

  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);
  pinMode(BUZZER, OUTPUT);

  // Inicializar LCD
  lcd.begin(16, 2);

  // Comunicacion con Processing
  Serial.begin(9600);

  // Inicializar servo
  radarServo.attach(SERVO_PIN);

  radarServo.write(ANGULO_MINIMO);

  digitalWrite(TRIG, LOW);

  lcd.setCursor(0, 0);
  lcd.print("D-METER SYSTEM");

  lcd.setCursor(0, 1);
  lcd.print("Iniciando...");

  delay(1000);

  lcd.clear();

  delay(500);
}

// =====================================
// MEDIR DISTANCIA
// =====================================

float medirDistancia() {

  digitalWrite(TRIG, LOW);
  delayMicroseconds(2);

  digitalWrite(TRIG, HIGH);
  delayMicroseconds(10);

  digitalWrite(TRIG, LOW);

  unsigned long duracion = pulseIn(ECHO, HIGH, 25000);

  if (duracion == 0) {
    return -1;
  }

  float resultado = (duracion * 0.0343) / 2.0;

  if (resultado <= 0 || resultado > 400) {
    return -1;
  }

  return resultado;
}

// =====================================
// ACTUALIZAR LCD
// =====================================

void actualizarLCD() {

  lcd.setCursor(0, 0);

  if (distancia < 0) {

    lcd.print("DIST: NO ECHO   ");

  } else {

    lcd.print("DIST: ");
    lcd.print(distancia, 1);
    lcd.print(" cm     ");
  }

  lcd.setCursor(0, 1);

  if (distancia < 0) {

    lcd.print("NO SIGNAL       ");

  } else if (distancia <= DISTANCIA_PELIGRO) {

    lcd.print("DANGER          ");

  } else if (distancia <= DISTANCIA_MAXIMA) {

    lcd.print("CAUTION         ");

  } else {

    lcd.print("SAFE            ");
  }
}

// =====================================
// CONTROL DEL BUZZER
// =====================================

void actualizarBuzzer() {

  int nuevoModo;

  if (distancia < 0) {

    nuevoModo = 0;

  } else if (distancia <= DISTANCIA_PELIGRO) {

    nuevoModo = 2;

  } else if (distancia <= DISTANCIA_MAXIMA) {

    nuevoModo = 1;

  } else {

    nuevoModo = 0;
  }

  // Detectar cambio de modo

  if (nuevoModo != modoActual) {

    noTone(BUZZER);

    modoActual = nuevoModo;

    ultimoPitido = millis();

    tonoAgudo = false;
  }

  unsigned long ahora = millis();

  // MODO 0: SILENCIO

  if (modoActual == 0) {

    noTone(BUZZER);

    return;
  }

  // MODO 2: PELIGRO
  // Alternancia rapida de tonos

  if (modoActual == 2) {

    if (ahora - ultimoPitido >= 150) {

      ultimoPitido = ahora;

      tonoAgudo = !tonoAgudo;

      if (tonoAgudo) {

        tone(BUZZER, 3000);

      } else {

        tone(BUZZER, 300);
      }
    }

    return;
  }

  // MODO 1: ALERTA PROGRESIVA

  if (modoActual == 1) {

    int intervalo = map(
      (int)distancia,
      40,
      200,
      80,
      900
    );

    int frecuencia = map(
      (int)distancia,
      40,
      200,
      2800,
      500
    );

    intervalo = constrain(intervalo, 80, 900);

    frecuencia = constrain(frecuencia, 500, 2800);

    if (ahora - ultimoPitido >= (unsigned long)intervalo) {

      ultimoPitido = ahora;

      tone(BUZZER, frecuencia, 55);
    }
  }
}

// =====================================
// ENVIAR DATOS A PROCESSING
// =====================================

void enviarDatos() {

  // Formato: ANGULO,DISTANCIA

  Serial.print(angulo);
  Serial.print(",");

  if (distancia < 0) {

    Serial.println(-1.0, 1);

  } else {

    Serial.println(distancia, 1);
  }
}

// =====================================
// CONTROL DEL SERVO
// =====================================

void controlarServo() {

  // Mover servo al angulo actual

  radarServo.write(angulo);

  // Esperar a que se estabilice

  delay(TIEMPO_SERVO);

  // Medir distancia en esa posicion

  distancia = medirDistancia();

  // Enviar angulo y distancia

  enviarDatos();

  // Actualizar LCD y alarma

  actualizarLCD();

  actualizarBuzzer();

  // Preparar siguiente angulo

  angulo += PASO_ANGULO * direccion;

  // Llegar a 180 grados

  if (angulo >= ANGULO_MAXIMO) {

    angulo = ANGULO_MAXIMO;

    direccion = -1;
  }

  // Volver a 0 grados

  else if (angulo <= ANGULO_MINIMO) {

    angulo = ANGULO_MINIMO;

    direccion = 1;
  }
}

// =====================================
// LOOP PRINCIPAL
// =====================================

void loop() {

  controlarServo();
}
