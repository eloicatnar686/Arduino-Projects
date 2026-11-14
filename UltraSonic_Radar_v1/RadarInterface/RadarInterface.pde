// =====================================================
//  D-METER // RADAR  -  Radar con servo (Processing)
//  Recibe "ANGULO,DISTANCIA" por línea desde el Arduino
//  y dibuja el barrido en sincronía con el servo.
//
//  Teclas:  P = siguiente puerto   R = reconectar
//           1-9 = elegir puerto    S = línea de barrido ON/OFF
//           I = invertir sentido   C = borrar ecos
//           ESC = salir
// =====================================================

import processing.serial.*;

// ---------- CONFIGURACIÓN ----------
final int   BAUD        = 9600;
final float DIST_MAX    = 200;    // igual que en el Arduino
final float DIST_DANGER = 40;     // igual que en el Arduino
final int   PERSIST_MS  = 5000;   // cuánto dura un eco en pantalla
final int   TIMEOUT_MS  = 1500;   // sin datos => "sin señal"

// ---------- LAYOUT (diseño base 1280x720, se escala solo) ----------
final float CX = 450, CY = 650, R = 410;   // centro y radio del radar
final float PX = 900, PW = 350;            // panel derecho

// ---------- ESTADO SERIE ----------
Serial port;
String[] ports = new String[0];
int portIdx = -1;
boolean connected = false;
String statusMsg = "";

volatile int   latestAngle = 0;
volatile float latestDist  = -1;
volatile int   lastRx = 0;
volatile boolean newSample = false;
volatile int   badLines = 0;

// ---------- DATOS DEL RADAR ----------
float[] distArr  = new float[181];   // última distancia por ángulo
int[]   stampArr = new int[181];     // momento de la última medida

int lastAngle = -1;
int sweepDir = 1;
float sweepShown = 0;

boolean sweepOn = true;
boolean invert = false;

// resultados calculados cada frame
int   closestAng = -1;
float closestDist = 0, farDist = 0, avgDist = 0;
int   nPoints = 0;

PFont mono;
color cSafe, cWarn, cDanger, cOff;

// =====================================================
void setup() {
  fullScreen();            // para otro monitor: fullScreen(2);
  frameRate(60);
  mono = createFont("Monospaced", 32, true);

  cSafe   = color(0, 255, 130);
  cWarn   = color(255, 190, 0);
  cDanger = color(255, 60, 60);
  cOff    = color(130, 150, 145);

  clearScan();

  ports = Serial.list();
  println("Puertos disponibles:");
  printArray(ports);
  connectPort(autoPick());
}

void clearScan() {
  for (int i = 0; i <= 180; i++) {
    distArr[i] = -1;
    stampArr[i] = 0;
  }
}

// Elige el puerto más probable del Arduino
int autoPick() {
  if (ports.length == 0) return -1;
  for (int i = 0; i < ports.length; i++) {
    String n = ports[i].toLowerCase();
    if (n.contains("usbmodem") || n.contains("usbserial") ||
        n.contains("ttyacm") || n.contains("ttyusb")) return i;
  }
  return ports.length - 1;   // en Windows suele ser el último COM
}

void connectPort(int idx) {
  if (port != null) {
    port.stop();
    port = null;
  }
  connected = false;
  lastRx = 0;
  latestDist = -1;
  badLines = 0;
  clearScan();
  ports = Serial.list();

  if (idx < 0 || idx >= ports.length) {
    portIdx = -1;
    statusMsg = "No hay puertos serie. Conecta el Arduino y pulsa R.";
    return;
  }
  portIdx = idx;
  try {
    port = new Serial(this, ports[idx], BAUD);
    port.bufferUntil('\n');
    port.clear();
    connected = true;
    statusMsg = "";
  }
  catch (Exception e) {
    port = null;
    statusMsg = "No se pudo abrir (¿Monitor Serie abierto?). Prueba P.";
  }
}

// Se ejecuta en otro hilo cada vez que llega una línea "ANGULO,DISTANCIA"
void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;
  s = trim(s);
  if (s.length() == 0) return;

  String[] t = split(s, ',');
  if (t.length != 2) {
    badLines++;
    return;
  }
  try {
    int a = Integer.parseInt(trim(t[0]));
    float d = Float.parseFloat(trim(t[1]));
    if (a < 0 || a > 180 || Float.isNaN(d)) {
      badLines++;
      return;
    }
    distArr[a] = d;
    stampArr[a] = max(1, millis());
    latestAngle = a;
    latestDist = d;
    lastRx = millis();
    badLines = 0;
    newSample = true;
  }
  catch (NumberFormatException e) {
    badLines++;
  }
}

void keyPressed() {
  if (key == 'p' || key == 'P') {
    ports = Serial.list();
    if (ports.length > 0) connectPort((portIdx + 1) % ports.length);
    else connectPort(-1);
  } else if (key == 'r' || key == 'R') {
    ports = Serial.list();
    connectPort(portIdx >= 0 ? portIdx : autoPick());
  } else if (key == 's' || key == 'S') {
    sweepOn = !sweepOn;
  } else if (key == 'i' || key == 'I') {
    invert = !invert;
  } else if (key == 'c' || key == 'C') {
    clearScan();
  } else if (key >= '1' && key <= '9') {
    int i = key - '1';
    ports = Serial.list();
    if (i < ports.length) connectPort(i);
  }
}

// =====================================================
//  UTILIDADES DE GEOMETRÍA
//  Ángulo del servo -> posición en pantalla (0° a la derecha)
// =====================================================
float scrDeg(float servoDeg) {
  return invert ? 180 - servoDeg : servoDeg;
}

float polX(float servoDeg, float r) {
  return CX + r * cos(radians(scrDeg(servoDeg)));
}

float polY(float servoDeg, float r) {
  return CY - r * sin(radians(scrDeg(servoDeg)));
}

// arco centrado en un ángulo del servo
void arcAt(float servoDeg, float r, float halfWidthDeg) {
  float t = scrDeg(servoDeg);
  arc(CX, CY, 2 * r, 2 * r, -radians(t + halfWidthDeg), -radians(t - halfWidthDeg));
}

float fadeOf(int a) {
  if (stampArr[a] == 0) return 0;
  int age = millis() - stampArr[a];
  if (age >= PERSIST_MS) return 0;
  float f = 1 - age / (float) PERSIST_MS;
  return pow(f, 1.3);
}

color blipColor(float d) {
  if (d <= DIST_DANGER) return cDanger;
  if (d <= 100) return cWarn;
  return cSafe;
}

void computeTargets() {
  closestAng = -1;
  closestDist = 1e9;
  farDist = 0;
  nPoints = 0;
  float sum = 0;
  for (int a = 0; a <= 180; a++) {
    if (fadeOf(a) < 0.1) continue;
    float d = distArr[a];
    if (d < 0 || d > DIST_MAX) continue;
    nPoints++;
    sum += d;
    if (d < closestDist) {
      closestDist = d;
      closestAng = a;
    }
    if (d > farDist) farDist = d;
  }
  avgDist = nPoints > 0 ? sum / nPoints : 0;
}

// =====================================================
void draw() {
  if (newSample) {
    newSample = false;
    int a = latestAngle;
    if (a != lastAngle) {
      if (lastAngle >= 0) sweepDir = (a > lastAngle) ? 1 : -1;
      lastAngle = a;
    }
  }

  boolean live = connected && lastRx > 0 && millis() - lastRx < TIMEOUT_MS;
  float d = latestDist;
  int st = zone(live, d);
  color zc = zoneColor(st);

  sweepShown = lerp(sweepShown, latestAngle, 0.4);
  computeTargets();

  background(6, 14, 18);

  // Escala el diseño de 1280x720 a la pantalla, centrado
  float s = min(width / 1280.0, height / 720.0);
  pushMatrix();
  translate((width - 1280 * s) / 2, (height - 720 * s) / 2);
  scale(s);

  textFont(mono);
  drawRadar(live);
  drawHeader(live);
  drawPanel(live, d, st, zc);
  drawFooter();

  popMatrix();
}

// 0 sin señal, 1 sin eco, 2 safe, 3 caution, 4 danger
int zone(boolean live, float d) {
  if (!live) return 0;
  if (d < 0) return 1;
  if (d <= DIST_DANGER) return 4;
  if (d <= DIST_MAX) return 3;
  return 2;
}

color zoneColor(int st) {
  switch (st) {
    case 2: return cSafe;
    case 3: return cWarn;
    case 4: return cDanger;
    default: return cOff;
  }
}

String zoneName(int st) {
  switch (st) {
    case 1: return "NO ECHO";
    case 2: return "SAFE";
    case 3: return "CAUTION";
    case 4: return "DANGER";
    default: return "NO SIGNAL";
  }
}

// =====================================================
//  RADAR
// =====================================================
void drawRadar(boolean live) {
  ellipseMode(CENTER);
  float rd = R * DIST_DANGER / DIST_MAX;

  // fondo del semicírculo
  noStroke();
  fill(8, 26, 28);
  arc(CX, CY, 2 * R, 2 * R, PI, TWO_PI, PIE);

  // zona de peligro
  fill(255, 50, 50, 30);
  arc(CX, CY, 2 * rd, 2 * rd, PI, TWO_PI, PIE);

  // anillos de distancia
  noFill();
  stroke(0, 150, 90, 140);
  strokeWeight(1.5);
  for (int i = 1; i <= 4; i++) {
    float r = R * i / 4;
    arc(CX, CY, 2 * r, 2 * r, PI, TWO_PI);
  }

  // líneas radiales cada 30 grados
  stroke(0, 120, 75, 110);
  strokeWeight(1);
  for (int a = 0; a <= 180; a += 30) {
    float t = radians(a);
    line(CX, CY, CX + R * cos(t), CY - R * sin(t));
  }

  // línea base y borde exterior
  stroke(0, 180, 105);
  strokeWeight(2);
  line(CX - R - 10, CY, CX + R + 10, CY);
  stroke(0, 220, 120);
  strokeWeight(2.5);
  arc(CX, CY, 2 * R, 2 * R, PI, TWO_PI);

  // borde de la zona de peligro
  stroke(255, 70, 70, 200);
  strokeWeight(1.5);
  arc(CX, CY, 2 * rd, 2 * rd, PI, TWO_PI);

  // etiquetas de ángulo
  noStroke();
  fill(80, 170, 130);
  textSize(12);
  textAlign(CENTER, CENTER);
  for (int a = 0; a <= 180; a += 30) {
    float t = radians(a);
    float lx, ly;
    if (a == 0 || a == 180) {
      lx = CX + (a == 0 ? R : -R);
      ly = CY + 16;
    } else {
      lx = CX + (R + 20) * cos(t);
      ly = CY - (R + 20) * sin(t);
    }
    text((invert ? 180 - a : a) + "°", lx, ly);
  }

  // etiquetas de distancia (sobre el eje vertical)
  fill(0, 230, 130);
  textAlign(LEFT, BOTTOM);
  for (int i = 1; i <= 4; i++) {
    text((i * 50) + " cm", CX + 8, CY - R * i / 4 - 4);
  }
  fill(255, 90, 90);
  textAlign(RIGHT, BOTTOM);
  text(int(DIST_DANGER) + " cm", CX - 8, CY - rd - 4);

  // ---- ecos guardados (se apagan con el tiempo) ----
  noFill();
  for (int a = 0; a <= 180; a++) {
    float f = fadeOf(a);
    if (f <= 0.02) continue;
    float d = distArr[a];
    if (d < 0 || d > DIST_MAX) continue;
    float r = R * d / DIST_MAX;
    color c = blipColor(d);
    stroke(c, 70 * f);
    strokeWeight(14);
    arcAt(a, r, 1.4);
    stroke(c, 255 * f);
    strokeWeight(5);
    arcAt(a, r, 1.3);
  }

  // ---- línea de barrido con estela ----
  if (sweepOn && live) {
    strokeWeight(4);
    for (int i = 0; i < 70; i++) {
      float ang = sweepShown - sweepDir * i * 0.5;
      if (ang < 0 || ang > 180) continue;
      stroke(0, 255, 130, map(i, 0, 70, 140, 0));
      line(CX, CY, polX(ang, R), polY(ang, R));
    }
    stroke(150, 255, 200);
    strokeWeight(2);
    line(CX, CY, polX(sweepShown, R), polY(sweepShown, R));
  }

  // ---- pulso en la medida actual ----
  if (live && latestDist >= 0 && latestDist <= DIST_MAX) {
    float r = R * latestDist / DIST_MAX;
    float x = polX(latestAngle, r);
    float y = polY(latestAngle, r);
    color c = blipColor(latestDist);
    float p = (millis() % 800) / 800.0;
    noFill();
    stroke(c, (1 - p) * 200);
    strokeWeight(2);
    ellipse(x, y, 12 + p * 40, 12 + p * 40);
    noStroke();
    fill(c);
    ellipse(x, y, 10, 10);
  }

  // ---- objetivo más cercano ----
  if (closestAng >= 0) {
    float r = R * closestDist / DIST_MAX;
    float x = polX(closestAng, r);
    float y = polY(closestAng, r);
    noFill();
    stroke(255, 255, 255, 200);
    strokeWeight(1.5);
    ellipse(x, y, 28, 28);
    noStroke();
    fill(255);
    textSize(13);
    if (x > CX) {
      textAlign(RIGHT, BOTTOM);
      text(nf(closestDist, 0, 1) + " cm", x - 16, y - 12);
    } else {
      textAlign(LEFT, BOTTOM);
      text(nf(closestDist, 0, 1) + " cm", x + 16, y - 12);
    }
  }

  // emisor
  noStroke();
  fill(0, 255, 130);
  ellipse(CX, CY, 14, 14);
  fill(6, 14, 18);
  ellipse(CX, CY, 6, 6);
}

// =====================================================
//  CABECERA
// =====================================================
void drawHeader(boolean live) {
  noStroke();
  textAlign(LEFT, BASELINE);
  fill(0, 255, 130);
  textSize(26);
  text("D-METER // RADAR", 30, 44);
  fill(100, 170, 150);
  textSize(12);
  text("HC-SR04 · SERVO · ARDUINO · " + BAUD + " baud", 30, 66);

  // lista de puertos
  fill(100, 170, 150);
  textSize(11);
  text("PUERTOS SERIE", 30, 100);
  textSize(12);
  if (ports.length == 0) {
    fill(cOff);
    text("(ninguno detectado)", 30, 120);
  }
  for (int i = 0; i < min(ports.length, 6); i++) {
    boolean sel = (i == portIdx);
    fill(sel ? cSafe : cOff);
    text((sel ? "> " : "  ") + "[" + (i + 1) + "] " + shortName(ports[i]), 30, 120 + i * 18);
  }

  // indicador de conexión (arriba a la derecha)
  boolean badFormat = connected && !live && badLines > 3;
  String msg;
  color c;
  if (live) {
    msg = "EN VIVO  " + (portIdx >= 0 ? shortName(ports[portIdx]) : "");
    c = cSafe;
  } else if (badFormat) {
    msg = "FORMATO NO RECONOCIDO";
    c = cWarn;
  } else if (connected) {
    msg = "CONECTADO · SIN DATOS";
    c = cWarn;
  } else {
    msg = "SIN CONEXIÓN";
    c = cDanger;
  }
  textSize(13);
  textAlign(RIGHT, BASELINE);
  float w = textWidth(msg);
  fill(c);
  text(msg, PX + PW, 44);
  float pulse = live ? 150 + 105 * sin(millis() * 0.008) : 255;
  fill(red(c), green(c), blue(c), pulse);
  ellipse(PX + PW - w - 14, 39, 10, 10);

  fill(cWarn);
  textSize(11);
  if (badFormat) {
    text("Se esperaba ANGULO,DISTANCIA (¿sketch antiguo?)", PX + PW, 62);
  } else if (statusMsg.length() > 0) {
    text(statusMsg, PX + PW, 62);
  }
}

String shortName(String s) {
  if (s.length() > 28) return "…" + s.substring(s.length() - 27);
  return s;
}

// =====================================================
//  PANEL DERECHO
// =====================================================
void card(float x, float y, float w, float h, color border) {
  fill(10, 28, 32);
  stroke(border);
  strokeWeight(1);
  rect(x, y, w, h, 10);
  noStroke();
}

void label(String s, float x, float y) {
  fill(100, 170, 150);
  textSize(11);
  textAlign(LEFT, BASELINE);
  text(s, x, y);
}

void drawPanel(boolean live, float d, int st, color zc) {
  color normal = color(0, 90, 60);
  boolean valid = live && d >= 0;

  // --- distancia actual ---
  card(PX, 90, PW, 130, normal);
  label("DISTANCIA ACTUAL", PX + 18, 114);
  String big = valid ? nf(d, 0, 1) : "---";
  fill(valid ? zc : cOff);
  textAlign(LEFT, BASELINE);
  textSize(68);
  text(big, PX + 18, 186);
  float bw = textWidth(big);
  textSize(22);
  fill(150, 190, 175);
  text("cm", PX + 18 + bw + 10, 186);
  textSize(11);
  fill(100, 170, 150);
  text("rango radar 0 - " + int(DIST_MAX) + " cm", PX + 18, 210);

  // --- ángulo (izquierda) ---
  card(PX, 235, 170, 80, normal);
  label("ÁNGULO", PX + 14, 257);
  fill(live ? color(220) : cOff);
  textSize(34);
  textAlign(LEFT, BASELINE);
  text(live ? latestAngle + "°" : "--", PX + 14, 299);

  // --- estado (derecha) ---
  card(PX + 180, 235, 170, 80, st == 4 ? cDanger : normal);
  label("ESTADO", PX + 194, 257);
  float alpha = (st == 4) ? 160 + 95 * sin(millis() * 0.015) : 255;
  fill(red(zc), green(zc), blue(zc), alpha);
  textSize(21);
  textAlign(LEFT, BASELINE);
  text(zoneName(st), PX + 194, 298);

  // --- objetivo más cercano ---
  card(PX, 330, PW, 72, normal);
  label("OBJETIVO MÁS CERCANO", PX + 18, 352);
  textAlign(LEFT, BASELINE);
  textSize(22);
  if (closestAng >= 0) {
    fill(blipColor(closestDist));
    text(nf(closestDist, 0, 1) + " cm  @ " + closestAng + "°", PX + 18, 388);
  } else {
    fill(cOff);
    text("--", PX + 18, 388);
  }

  // --- estadísticas del barrido ---
  card(PX, 417, PW, 70, normal);
  String[] names = {"PUNTOS", "MEDIA", "MÁS LEJANO"};
  String[] vals = {
    str(nPoints),
    nPoints > 0 ? nf(avgDist, 0, 1) : "--",
    nPoints > 0 ? nf(farDist, 0, 1) : "--"
  };
  for (int i = 0; i < 3; i++) {
    float x = PX + 18 + i * (PW - 20) / 3.0;
    label(names[i], x, 439);
    fill(220);
    textSize(20);
    textAlign(LEFT, BASELINE);
    text(vals[i], x, 473);
  }

  // --- perfil distancia / ángulo ---
  card(PX, 502, PW, 188, normal);
  label("PERFIL POR ÁNGULO", PX + 18, 524);
  float px = PX + 42, py = 538, pw = PW - 60, ph = 130;

  // rejilla
  textSize(10);
  for (int v = 0; v <= 200; v += 50) {
    float y = py + ph - ph * v / DIST_MAX;
    stroke(0, 70, 50);
    strokeWeight(1);
    line(px, y, px + pw, y);
    noStroke();
    fill(100, 170, 150);
    textAlign(RIGHT, CENTER);
    text(v, px - 6, y);
  }
  fill(100, 170, 150);
  textAlign(CENTER, TOP);
  text("0°", px, 672);
  text("90°", px + pw / 2, 672);
  text("180°", px + pw, 672);

  // umbral de peligro
  float yd = py + ph - ph * DIST_DANGER / DIST_MAX;
  stroke(255, 70, 70, 170);
  strokeWeight(1);
  line(px, yd, px + pw, yd);

  // ángulo actual
  if (live) {
    float xa = px + pw * latestAngle / 180.0;
    stroke(255, 255, 255, 110);
    line(xa, py, xa, py + ph);
  }

  // puntos
  noStroke();
  for (int a = 0; a <= 180; a++) {
    float f = fadeOf(a);
    if (f <= 0.02) continue;
    float dv = distArr[a];
    if (dv < 0 || dv > DIST_MAX) continue;
    fill(blipColor(dv), 255 * f);
    ellipse(px + pw * a / 180.0, py + ph - ph * dv / DIST_MAX, 5, 5);
  }
}

// =====================================================
void drawFooter() {
  noStroke();
  fill(100, 150, 130);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text("[P] puerto    [R] reconectar    [1-9] elegir puerto    [S] barrido: "
       + (sweepOn ? "ON" : "OFF") + "    [I] invertir sentido: "
       + (invert ? "ON" : "OFF") + "    [C] borrar    [ESC] salir", 30, 708);
}
