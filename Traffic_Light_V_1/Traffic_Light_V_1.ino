void setup() {
  pinMode(13, OUTPUT);
  pinMode(12, OUTPUT);
  pinMode(11, OUTPUT);

// x3 resis 220 ohm
// x3 leds (verde,13) (amarillo,12) (rojo,11)
// x7 jumper wire
// x1 BreadBoard
// x1 Arduino Uno
  
}

void loop() {
  int tiempo = 1000;
  int verde = 13;
  int amarillo = 12;
  int rojo = 11;
  
  //begin secuence in red
  digitalWrite(rojo, 1);
  delay(5000); //se espera 5s
  digitalWrite(rojo, 0); //apaga rojo
  digitalWrite(amarillo, 1); //enciende amarillo
  delay(5000);
  digitalWrite(amarillo, 0); //apaga amarillo
  digitalWrite(verde, 1); //enciende verde
  delay(10000); //espera de 10 secs con verde encendida
  digitalWrite(verde, 0); 
  delay(500);
  digitalWrite(verde, 1);
  delay(500);
  digitalWrite(verde, 0); 
  delay(500);
  digitalWrite(verde, 1);
  delay(500);
  digitalWrite(verde, 0);
  delay(500);
  digitalWrite(verde, 1);
  delay(500);
  digitalWrite(verde, 0);
  delay(500);
  digitalWrite(verde, 1);
  
  



  
  
  


  
  
  digitalWrite(13, 1);
  delay(tiempo);
  digitalWrite(13, 0);
  delay(tiempo);
}
