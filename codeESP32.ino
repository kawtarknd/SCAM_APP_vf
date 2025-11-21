#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "MAX30105.h"
#include <HTTPClient.h> 
#include <WiFi.h>
#include <WiFiClientSecure.h> 
#include <arduino.h> 
#include <math.h> // Pour la fonction sqrt() et pow()

// Déclaration de prototypes pour la compilatio
void initMPU6050();
void lireMPU6050();
void checkMPU6050();
void checkMAX30102();
void generateVitalsFromAccel(); // 🚨 NOUVEAU
void simulateAccel(); // Reste pour l'échec total du MPU
void sendDataHTTP(); 

// ===== LCD I2C =====
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ===== MAX30102 =====
MAX30105 particleSensor;

// ===================================================
//              ÉTAPE 1 : CONFIGURATION FIREBASE (Temps Réel)
// ===================================================
const char* FIREBASE_URL_BASE = "";
const char* DATABASE_SECRET_TOKEN = "";

// ===================================================
//              ÉTAPE 2 : CONFIGURATION SUPABASE (Historique)
// ===================================================
const char* SUPABASE_URL_BASE = ""; 
const char* SUPABASE_ANON_KEY = ""; 


// ===================================================
//              ÉTAPE 3 : CONFIGURATION RENDER API 
// ===================================================

const char* RENDER_URL = "";


// ===================================================
//              VARIABLES DE CAPTEURS
// ===================================================
double avered = 0; double aveir = 0;
double sumRedRMS = 0; double sumIRRMS = 0;
int sampleCount = 0;
const int NUM_SAMPLES = 300; 
float estimatedSpO2 = 0.0; 
const double SPO2_FILTER = 0.7;

long lastBeat = 0; float bpmInstant = 0;
const int RATE_SIZE = 5; 
byte rates[RATE_SIZE] = {0};
byte rateSpot = 0;
int bpmAvg = 0; 

const long FINGER_ON = 50000;
bool doigtPresent = false;

#define MPU6050_ADDR 0x68
int16_t accelX = 0; int16_t accelY = 0; int16_t accelZ = 0; 
int16_t gyroX = 0; int16_t gyroY = 0; int16_t gyroZ = 0;
bool mpuTrouve = false;
bool maxTrouve = false;

// ===================================================
//              CONFIGURATION WIFI
// ===================================================
const char* ssid = "";
const char* password = "";

// ===================================================
//              FONCTIONS DE SIMULATION
// ===================================================

// Simule les données MPU6050 (Uniquement si MPU est totalement défaillant)
void simulateAccel() {
  accelX = random(1000, 2000); 
  accelY = random(100, 500);
  accelZ = random(15000, 16384); 
  gyroX = random(10, 50);
  gyroY = random(10, 50);
  gyroZ = random(10, 50);
}

// 🚨 GÉNÈRE BPM/SpO2 BASÉ SUR L'ACCÉLÉRATION RÉELLE (MPU)
void generateVitalsFromAccel() {
  // Calculer la magnitude de l'accélération (ACC_mag) pour déterminer le niveau d'effort
  // Note: Le MPU6050 fournit des valeurs brutes (~16384 pour 1G sur Z). 
  // La magnitude totale est utilisée pour mesurer le mouvement.
  long accMagSquared = (long)accelX*accelX + (long)accelY*accelY + (long)accelZ*accelZ;
  double accMag = sqrt(accMagSquared); // Valeur typique au repos : ~16384 (1G)
  
  // Plages basées sur votre fiche (ajustées aux valeurs brutes typiques)
  int minBPM, maxBPM, avgSpO2;
  
  if (accMag < 16500) { // Repos, très faible mouvement (proche de 1G)
    minBPM = 65; maxBPM = 75; avgSpO2 = 98;
    Serial.println("EFFORT: REPOS");
  } else if (accMag < 17500) { // Mouvement léger (marche lente)
    minBPM = 80; maxBPM = 95; avgSpO2 = 96;
    Serial.println("EFFORT: LÉGER");
  } else { // Mouvement intense (course/agitation, ACC_mag élevée)
    minBPM = 100; maxBPM = 135; avgSpO2 = 94;
    Serial.println("EFFORT: INTENSE");
  }
  
  // Générer BPM (dans la plage définie)
  bpmAvg = random(minBPM, maxBPM + 1);
  
  // Générer SpO2 (proche de la moyenne attendue, avec petite variation)
  estimatedSpO2 = random(avgSpO2 * 10, avgSpO2 * 10 + 39) / 10.0; // Ex: 94.0 à 97.9
  estimatedSpO2 = constrain(estimatedSpO2, 94.0, 99.9);
}


// ===================================================
//              FONCTIONS UTILITAIRES DE LECTURE
// ===================================================

// Construit l'URL Firebase
String buildFirebaseUrl(const char* path) {
    String url = "https://";
    url += FIREBASE_URL_BASE;
    url += path; 
    url += "?auth=";
    url += DATABASE_SECRET_TOKEN;
    return url;
}

// Détection battement avancée (inchangée)
bool checkBeatAdvanced(uint32_t irValue) {
  static double irBaseline = 0;
  static bool lastBeatDetected = false;
  static unsigned long lastReset = 0;

  irBaseline = 0.95 * irBaseline + 0.05 * irValue;
  double irAC = irValue - irBaseline;

  bool beatDetected = false;
  if (irAC > 400 && !lastBeatDetected) {
    beatDetected = true;
    lastBeatDetected = true;
  } else if (irAC < 200) {
    lastBeatDetected = false;
  }

  if (millis() - lastReset > 2000) {
    irBaseline = irValue;
    lastReset = millis();
  }
  return beatDetected;
}

// 🚨 VÉRIFICATION DYNAMIQUE 1 : MPU6050
void checkMPU6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  if (Wire.endTransmission(true) != 0) {
      if (mpuTrouve) {
          Serial.println("--- MPU6050 DÉCONNECTÉ EN COURS (Simul) ---");
      }
      mpuTrouve = false;
  } else {
      mpuTrouve = true;
      lireMPU6050(); 
  }
}

// 🚨 VÉRIFICATION DYNAMIQUE 2 : MAX30102
void checkMAX30102() {
    if (!maxTrouve) {
        if (particleSensor.begin(Wire)) {
             maxTrouve = true;
             particleSensor.setup(0x60, 4, 2, 100, 411, 16384);
             Serial.println("--- MAX30102 RECONNECTÉ ---");
        } 
    }
}


// Lecture MPU6050 (inchangée, appelée par checkMPU6050)
void lireMPU6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU6050_ADDR, 14, true);

  accelX = Wire.read() << 8 | Wire.read();
  accelY = Wire.read() << 8 | Wire.read();
  accelZ = Wire.read() << 8 | Wire.read();
  Wire.read() << 8 | Wire.read(); 
  gyroX = Wire.read() << 8 | Wire.read();
  gyroY = Wire.read() << 8 | Wire.read();
  gyroZ = Wire.read() << 8 | Wire.read();
}

// Initialisation MPU6050 (inchangée, utilisée par setup)
void initMPU6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B);
  Wire.write(0);
  Wire.endTransmission(true);
  delay(100);
}

// ===================================================
//              FONCTION ENVOI SUPABASE (Historique)
// ===================================================
void sendDataSupabase(const String& payload) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;

    String url = "https://";
    url += SUPABASE_URL_BASE;
    url += "/rest/v1/capteurs_data?select=*"; 

    http.begin(client, url.c_str());
    
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", SUPABASE_ANON_KEY); 
    
    String authHeader = "Bearer ";
    authHeader += SUPABASE_ANON_KEY;
    http.addHeader("Authorization", authHeader.c_str()); 

    int httpResponseCode = http.POST(payload);
    
    if (httpResponseCode == 201) { 
        Serial.println("✅ Supabase Historique (POST) OK: 201");
    } else {
        Serial.print("❌ Supabase Historique (POST) Erreur: ");
        Serial.println(httpResponseCode);
        if (httpResponseCode > 0) {
           Serial.print("Réponse Supabase: ");
           Serial.println(http.getString());
        }
    }
    http.end();
}

// ===================================================
//              FONCTION D'ENVOI GLOBALE
// ===================================================

void sendDataHTTP() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi non connecté.");
    return;
  }
  
  // VÉRIFICATION CRITIQUE D'ENVOI
  if (bpmAvg == 0 || estimatedSpO2 == 0.0) {
    Serial.println("⚠️ Données Vitals absentes/non stables. Envoi ignoré.");
    return;
  }

  // 1. Payload Firebase (Temps Réel)
  String payloadRTDB = "{";
  payloadRTDB += "\"bpm\":" + String(bpmAvg) + ",";
  payloadRTDB += "\"spo2\":" + String(estimatedSpO2, 1) + ",";
  payloadRTDB += "\"accel\":[" + String(accelX) + "," + String(accelY) + "," + String(accelZ) + "],";
  // 🚨 INCLUSION GYROSCOPE
  payloadRTDB += "\"gyro\":[" + String(gyroX) + "," + String(gyroY) + "," + String(gyroZ) + "]";
  payloadRTDB += "}";

  // 2. Payload Supabase (Historique)
  String payloadSupabase = "{";
  payloadSupabase += "\"bpm\":" + String(bpmAvg) + ",";
  payloadSupabase += "\"spo2\":" + String((int)estimatedSpO2) + ","; 
  payloadSupabase += "\"accel_x\":" + String(accelX) + ","; 
  payloadSupabase += "\"accel_y\":" + String(accelY) + ","; 
  payloadSupabase += "\"accel_z\":" + String(accelZ) + ",";
  // 🚨 INCLUSION GYROSCOPE
  payloadSupabase += "\"gyro_x\":" + String(gyroX) + ",";
  payloadSupabase += "\"gyro_y\":" + String(gyroY) + ",";
  payloadSupabase += "\"gyro_z\":" + String(gyroZ);
  payloadSupabase += "}";


  // --- REQUÊTE 1 : FIREBASE (TEMPS RÉEL) ---
  {
      WiFiClientSecure client;
      client.setInsecure();
      HTTPClient http;
      String urlRT = buildFirebaseUrl("/vitals.json");
      http.begin(client, urlRT.c_str()); 
      http.addHeader("Content-Type", "application/json");

      int httpResponseCode = http.PUT(payloadRTDB);
      if (httpResponseCode == 200 || httpResponseCode == 204) {
          Serial.println("✅ RTDB Vitals (PUT) OK: 200");
      } else {
          Serial.print("❌ RTDB Vitals (PUT) Erreur: ");
          Serial.println(httpResponseCode);
      }
      http.end();
  }

  // --- REQUÊTE 2 : SUPABASE (HISTORIQUE) ---
  sendDataSupabase(payloadSupabase);
}



  void sendDataRender() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi non connecté, impossible d'envoyer à Render.");
    return;
  }

  // Vérification que les données sont stables
  if (bpmAvg == 0 || estimatedSpO2 == 0.0) {
    Serial.println("⚠️ Données Vitals absentes/non stables. Envoi Render ignoré.");
    return;
  }

  // --- Préparer le JSON à envoyer ---
  String payload = "{";
  payload += "\"bpm\":" + String(bpmAvg) + ",";
  payload += "\"spo2\":" + String(estimatedSpO2, 1) + ",";
  payload += "\"accel_x\":" + String(accelX) + ",";
  payload += "\"accel_y\":" + String(accelY) + ",";
  payload += "\"accel_z\":" + String(accelZ) + ",";
  payload += "\"gyro_x\":" + String(gyroX) + ",";
  payload += "\"gyro_y\":" + String(gyroY) + ",";
  payload += "\"gyro_z\":" + String(gyroZ);
  payload += "}";

  // --- Envoi POST HTTPS ---
  WiFiClientSecure client;
  client.setInsecure(); // pour test uniquement, enlever en prod
  HTTPClient https;

  https.begin(client, RENDER_URL);
  https.addHeader("Content-Type", "application/json");

  int httpResponseCode = https.POST(payload);

  if (httpResponseCode > 0) {
    String response = https.getString();
    Serial.println("✅ Render OK: " + String(httpResponseCode));
    Serial.println("Réponse: " + response);
  } else {
    Serial.print("❌ Erreur HTTP Render: ");
    Serial.println(httpResponseCode);
  }

  https.end();
}


// ===================================================
//              SETUP
// ===================================================
void setup() {
  Serial.begin(115200);
  randomSeed(analogRead(0)); 
  delay(1000);
  Serial.println("=== SYSTEME HYBRIDE (ROBUSTESSE DYNAMIQUE) ===");

  Wire.begin(25, 26);
  delay(100); 

  // LCD (Initialisation inchangée)
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0,0);
  lcd.print("Initialisation...");
  delay(1000);

  // WiFi (Connexion inchangée)
  WiFi.begin(ssid, password);
  lcd.setCursor(0,1);
  lcd.print("Connexion WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi Connecté");
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("WiFi Connecté");

  // MPU6050 (Vérification initiale)
  Wire.beginTransmission(MPU6050_ADDR);
  if (Wire.endTransmission() == 0) {
    mpuTrouve = true;
    initMPU6050();
    Serial.println("✅ MPU6050 OK");
  } else {
    Serial.println("❌ MPU6050 NON TROUVE");
  }

  // MAX30102 (Vérification initiale)
  if (particleSensor.begin(Wire)) {
    maxTrouve = true;
    particleSensor.setup(0x60, 4, 2, 100, 411, 16384);
    particleSensor.setPulseAmplitudeRed(0x60);
    particleSensor.setPulseAmplitudeIR(0x60);
    Serial.println("✅ MAX30102 OK");
  } else {
    Serial.println("❌ MAX30102 NON TROUVE");
  }

  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Placez votre doigt");
}

// ===================================================
//              LOOP
// ===================================================
void loop() {
  static unsigned long dernierAffichage = 0;
  static unsigned long lastHTTP = 0; 
  uint32_t irValue = 0;

  // 🚨 ÉTAPE 1 : MPU6050 - VÉRIFICATION DYNAMIQUE
  checkMPU6050(); 

  // 🚨 ÉTAPE 2 : MAX30102 - VÉRIFICATION DYNAMIQUE
  checkMAX30102();

  // 🚨 ÉTAPE 3 : GÉRER LA SIMULATION PERSISTANTE
  if (!mpuTrouve) {
      simulateAccel(); // Simulation MPU persistante
      Serial.println("DEBUG: Simulation ACCEL/GYRO ON");
  } else {
      // Si MPU est OK, mais que la lecture n'a pas été faite (ne devrait pas arriver ici si checkMPU6050() est bien fait)
      // On s'assure juste que si mpuTrouve est vrai, lireMPU6050 a été appelé dans checkMPU6050.
  }
  
  if (!maxTrouve) {
      // 🚨 Si MAX est en panne, nous utilisons la simulation basée sur l'accélération
      generateVitalsFromAccel(); 
      doigtPresent = true; // Forcer l'affichage/envoi en mode simulation
      Serial.println("DEBUG: Simulation BPM/SPO2 ON (basé sur ACC)");
  } else {
    // Lecture des données MAX30102 si disponible (Réel)
    particleSensor.check();
    while (particleSensor.available()) {
      uint32_t red = particleSensor.getFIFORed();
      irValue = particleSensor.getFIFOIR();

      bool doigtActuel = irValue >= FINGER_ON;
      if (doigtActuel != doigtPresent) {
        doigtPresent = doigtActuel;
        lcd.clear();
        if (!doigtPresent) {
          lcd.setCursor(0,0); lcd.print("Remplacez votre");
          lcd.setCursor(0,1); lcd.print("doigt");
        }
      }

      if (doigtPresent) {
        // Logique de filtrage et calcul (inchangée)
        avered = 0.95*avered + 0.05*red;
        aveir = 0.95*aveir + 0.05*irValue;
        double acRed = red - avered;
        double acIR = irValue - aveir;
        sumRedRMS += acRed*acRed;
        sumIRRMS += acIR*acIR;
        sampleCount++;

        if (checkBeatAdvanced(irValue)) {
          long delta = millis() - lastBeat;
          lastBeat = millis();
          bpmInstant = 60000.0 / delta;
          if (bpmInstant > 40 && bpmInstant < 180) {
            rates[rateSpot++] = (byte)bpmInstant;
            rateSpot %= RATE_SIZE;
            bpmAvg = 0;
            for (byte i=0;i<RATE_SIZE;i++) bpmAvg += rates[i];
            bpmAvg /= RATE_SIZE;
          }
        }

        if (sampleCount >= NUM_SAMPLES && aveir != 0 && avered != 0) {
          double R = (sqrt(sumRedRMS)/avered) / (sqrt(sumIRRMS)/aveir);
          double spO2 = -23.3*(R-0.4)+100;
          estimatedSpO2 = SPO2_FILTER*estimatedSpO2 + (1-SPO2_FILTER)*spO2;
          estimatedSpO2 = constrain(estimatedSpO2,70,100);
          sumRedRMS = sumIRRMS = 0;
          sampleCount = 0;
        }
      }
      particleSensor.nextSample();
    }
  }
  
  // Affichage LCD
  if (millis() - dernierAffichage > 500) {
    dernierAffichage = millis();
    lcd.clear(); 

    lcd.setCursor(0,0);
    
    // Affichage Accel/Gyro
    if (mpuTrouve) {
      lcd.print("AX:"); lcd.print(accelX/1000);
      lcd.print(" AY:"); lcd.print(accelY/1000);
    } else {
      lcd.print("MPU SIMULE");
    }

    lcd.setCursor(0,1);
    // Affichage Vitals (Simulés ou Réels)
    if (!maxTrouve) {
        // MAX en panne (Vitals simulés basés sur Accel)
        lcd.print("BPM:"); lcd.print(bpmAvg);
        lcd.print(" SpO2:"); lcd.print(estimatedSpO2, 1);
        lcd.print(" [SIMUL]");
    } else if (maxTrouve && !doigtPresent) {
        lcd.print("PLACEZ DOIGT");
    } else {
        // MAX OK et Doigt Présent
        lcd.print("BPM:");
        if (bpmAvg>0) lcd.print(bpmAvg); else lcd.print("---");
        lcd.print(" SpO2:");
        if (estimatedSpO2>0) lcd.print(estimatedSpO2,1); else lcd.print("---");
    }
  }


  // Affichage série (débogage)
  Serial.print("IR:"); Serial.print(irValue);
  Serial.print(maxTrouve ? " (MAX OK)" : " (MAX FAIL)");
  if (bpmAvg > 0) { 
    Serial.print(" | BPM:"); Serial.print(bpmAvg);
    Serial.print(" | SpO2:"); Serial.print(estimatedSpO2,1);
  }
  Serial.print(mpuTrouve ? " | Acc: REAL" : " | Acc: SIMUL");
  Serial.print(" [AX:"); Serial.print(accelX); Serial.print("]");
  Serial.print(" | GyroX:"); Serial.print(gyroX);
  Serial.println();

  // Envoi HTTP vers Firebase/Supabase toutes les 5s
  if (millis() - lastHTTP > 5000) {
    lastHTTP = millis();
    sendDataHTTP();
    sendDataRender();  
  }
  delay(500); 
}