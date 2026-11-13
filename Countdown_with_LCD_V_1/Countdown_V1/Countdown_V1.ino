
#include <LiquidCrystal.h>

#define BUZZER 13

// LCD: RS, E, D4, D5, D6, D7
LiquidCrystal lcd(12, 10, 5, 4, 3, 2);

unsigned long inicio;
unsigned long ultimoPitido = 0;
unsigned long inicioPitido = 0;

bool pitando = false;
bool finalizado = false;

void setup() {

  lcd.begin(16, 2);

  pinMode(BUZZER, OUTPUT);

  lcd.setCursor(0, 0);
  lcd.print("SYSTEM");

  lcd.setCursor(0, 1);
  lcd.print("INITIALIZING...");

  delay(1500);

  lcd.clear();

  inicio = millis();
}

void loop() {

  unsigned long ahora = millis();

  unsigned long transcurrido = ahora - inicio;

  // FINAL: TONO CONTINUO DURANTE 4 SEGUNDOS
  if (transcurrido >= 20000) {

    if (!finalizado) {

      finalizado = true;

      noTone(BUZZER);

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("FINAL SIGNAL");

      tone(BUZZER, 3000);
      pinMode(8, OUTPUT);
      digitalWrite(8, HIGH);
    

      inicioPitido = ahora;
    }

    // Detener tono despues de 4 segundos
    if (ahora - inicioPitido >= 4000) {

      noTone(BUZZER);

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("TERMINATED");

      lcd.setCursor(0, 1);
      lcd.print("SEQUENCE ENDED");

      while (true) {
        noTone(BUZZER);
      }
    }

    return;
  }

  // TIEMPO RESTANTE
  unsigned long restante = 20000 - transcurrido;

  int segundos = restante / 1000;
  int milisegundos = restante % 1000;

  // MOSTRAR CONTADOR
  lcd.setCursor(0, 0);
  lcd.print("COUNTDOWN TO DET    ");

  lcd.setCursor(0, 1);

  lcd.print("   00:");

  if (segundos < 10) lcd.print("0");

  lcd.print(segundos);
  lcd.print(":");

  if (milisegundos < 100) lcd.print("0");
  if (milisegundos < 10) lcd.print("0");

  lcd.print(milisegundos);
  lcd.print(" ");

  // FRECUENCIA: GRAVE -> AGUDO
  int tono = map(transcurrido, 0, 20000, 400, 3000);

  // INTERVALO: LENTO -> RAPIDO
  int intervalo = map(transcurrido, 0, 20000, 900, 40);

  // DURACION DE CADA PITIDO
  int duracion = map(transcurrido, 0, 20000, 120, 25);

  // APAGAR PITIDO ANTERIOR
  if (pitando && ahora - inicioPitido >= (unsigned long)duracion) {

    noTone(BUZZER);
    pitando = false;
  }

  // GENERAR SIGUIENTE PITIDO
  if (!pitando && ahora - ultimoPitido >= (unsigned long)intervalo) {

    tone(BUZZER, tono);

    pitando = true;

    inicioPitido = ahora;
    ultimoPitido = ahora;
  }
}
