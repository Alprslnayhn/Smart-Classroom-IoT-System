#include <WiFi.h>
#include <WebSocketsClient.h>
#include <Preferences.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>
#include <HardwareSerial.h>
#include <MHZ19.h>

// ==========================================
// 🔥 AYARLAR: BU 2. CİHAZ
// ==========================================
#define SENSOR_ID 2
// ==========================================

Preferences preferences;
WebSocketsClient webSocket;

// --- PIN AYARLARI (Sadece CO2 Var) ---
#define RX_PIN_MHZ19 16  
#define TX_PIN_MHZ19 17  
// PMS (Toz) Pinleri KALDIRILDI

// --- NESNELER ---
Adafruit_BME280 bme;
MHZ19 myMHZ19;
HardwareSerial SerialMHZ(2); 
// SerialPMS ve PMS struct'ları KALDIRILDI

// Config Değişkenleri
String ssid = "";
String pass = "";
String server_ip = "";
bool configurated = false;
bool response_received = false;
String config_buffer = "";
const int boot_button = 0; 

// WebSocket Durumları
bool ws_first_request = false;
bool ws_first_connection = false;
bool ws_configuration = false;

// --- AYAR YÖNETİMİ (AYNI) ---
void configuration_setup() {
    preferences.begin("config", false);
    ssid = preferences.getString("ssid", "");
    pass = preferences.getString("pass", "");
    server_ip = preferences.getString("ip", "");
    preferences.end();

    Serial.begin(115200);
    Serial.setRxBufferSize(4096);
    Serial.setTimeout(2000);

    // Sensör Başlatma
    if (!bme.begin(0x76)) Serial.println("⚠️ BME280 Yok!");
    
    SerialMHZ.begin(9600, SERIAL_8N1, RX_PIN_MHZ19, TX_PIN_MHZ19);
    myMHZ19.begin(SerialMHZ);
    myMHZ19.autoCalibration(false);
    
    // PMS Başlatma Kodu KALDIRILDI

    pinMode(boot_button, INPUT_PULLUP);

    if (ssid == "") {
        configurated = false;
        Serial.println("AYAR YOK! Lutfen Seri Porttan gonderin: SSID|SIFRE|IP");
    } else {
        configurated = true;
        Serial.println("Ayarlar Yuklendi: " + ssid);
    }
}

void configuration_loop() {
    static unsigned long last_notify = 0;
    if (!response_received && millis() - last_notify > 2000) {
        Serial.print("AYAR BEKLENIYOR... Format: SSID|SIFRE|IP \n");
        last_notify = millis();
    }

    if (Serial.available() > 0) {
        String input = Serial.readStringUntil('\n');
        input.trim();
        int firstSplit = input.indexOf('|');
        int secondSplit = input.indexOf('|', firstSplit + 1);

        if (firstSplit > 0 && secondSplit > 0) {
            ssid = input.substring(0, firstSplit);
            pass = input.substring(firstSplit + 1, secondSplit);
            server_ip = input.substring(secondSplit + 1);

            preferences.begin("config", false);
            preferences.putString("ssid", ssid);
            preferences.putString("pass", pass);
            preferences.putString("ip", server_ip);
            preferences.end();

            configurated = true;
            Serial.println("Ayarlar Kaydedildi! Yeniden baslatiliyor...");
            delay(1000);
            ESP.restart();
        } else {
            Serial.println("HATALI FORMAT! Ornek: HavaKalitesi|12345678|10.42.0.1");
        }
    }
}

void reset_config() {
    if (digitalRead(boot_button) == LOW) {
        unsigned long start_time = millis();
        Serial.println("SIFIRLAMAK ICIN 3 SN BASILI TUT...");
        while (digitalRead(boot_button) == LOW) {
            if (millis() - start_time > 3000) {
                preferences.begin("config", false);
                preferences.clear();
                preferences.end();
                Serial.println("AYARLAR SILINDI! Yeniden baslatiliyor...");
                delay(500);
                ESP.restart();
            }
        }
    }
}

// ==========================================
// VERİ GÖNDERME (Toz Sensörü Yok - 0 Gönderilir)
// ==========================================
void sendData() {
    float toplamSicaklik = 0;
    float toplamNem = 0;
    long toplamCO2 = 0;
    
    // Gürültü Filtresi (10 Örnek)
    int ornekSayisi = 10; 
    for(int i=0; i<ornekSayisi; i++) {
        toplamSicaklik += bme.readTemperature();
        toplamNem += bme.readHumidity();
        
        int anlikCO2 = myMHZ19.getCO2();
        if(anlikCO2 < 400) anlikCO2 = 400; 
        toplamCO2 += anlikCO2;
        
        delay(50); 
    }

    float avgTemp = toplamSicaklik / ornekSayisi;
    float avgHum = toplamNem / ornekSayisi;
    int avgCO2 = toplamCO2 / ornekSayisi;

    // --- TOZ VERİSİ ---
    // Bu cihazda toz sensörü olmadığı için sunucu formatını bozmamak adına
    // sabit 0 gönderiyoruz.
    int pm25 = 0; 

    if (isnan(avgTemp)) avgTemp = 0;
    if (isnan(avgHum)) avgHum = 0;

    // Format: \x1F + ID + | + Temp + | + Hum + | + CO2 + | + PM25
    String message = "\x1F" + String(SENSOR_ID) + "|" + String(avgTemp) + "|" + String(avgHum) + "|" + String(avgCO2) + "|" + String(pm25);
    
    webSocket.sendTXT(message);
    Serial.println("Gonderildi [ID:" + String(SENSOR_ID) + " - NO DUST]: " + message);
}

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_DISCONNECTED: Serial.println("[WS] Koptu!"); break;
        case WStype_CONNECTED: Serial.println("[WS] Baglandi!"); break;
        case WStype_TEXT: Serial.printf("[WS] Mesaj: %s\n", payload); break;
    }
}

void webSocketLoop() {
    if (!ws_first_request) {
        WiFi.begin(ssid.c_str(), pass.c_str());
        Serial.print("Wifi Baglaniyor...");
        ws_first_request = true;
    }
    if (!ws_first_connection) {
        if (WiFi.status() == WL_CONNECTED) {
            ws_first_connection = true;
            Serial.println("\nWifi OK! IP: " + WiFi.localIP().toString());
        }
    } else if (!ws_configuration) {   
        webSocket.begin(server_ip.c_str(), 3001, "/");
        webSocket.onEvent(webSocketEvent);
        webSocket.setReconnectInterval(5000);
        ws_configuration = true;
    }
}

void setup() { configuration_setup(); }

void loop() {
    if (!configurated) { configuration_loop(); } 
    else { 
        webSocketLoop(); 
        reset_config(); 
    }
    if (ws_configuration) {
        webSocket.loop();
        static unsigned long last_sent = 0;
        if(millis() - last_sent > 2000) { 
            sendData();
            last_sent = millis();
        }
    }
}
