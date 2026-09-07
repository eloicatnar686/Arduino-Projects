const int button = 4;
const int button2 = 5; //pin of button
const int led = 13; //pin of LED
const int led2 = 12;

int buttonState = LOW;
int buttonState2 = LOW;

void setup() {
  pinMode(button, INPUT);
  pinMode(button2, INPUT);
  pinMode(led, OUTPUT);
  pinMode(led2, OUTPUT);
  

}

void loop() {
  buttonState = digitalRead(button);
  buttonState2 = digitalRead(button2);

  if (buttonState == HIGH) {
    digitalWrite(led, 1);
  }
  else {
    digitalWrite(led, LOW);
  }
  if (buttonState2 == HIGH) {
    digitalWrite(led2, 1);
  }
  else {
    digitalWrite(led2, 0);
  }


}
