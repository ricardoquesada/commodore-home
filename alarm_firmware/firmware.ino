/****************************************************************************
http://retro.moe/c64-home

Copyright 2016 Ricardo Quesada

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
****************************************************************************/

// based on http://www.esp8266.com/viewtopic.php?f=29&t=2222


#define COMMODORE_HOME_ALARM_VERSION "v0.1.0"

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266httpUpdate.h>
#include <ESP8266mDNS.h>
#include <WiFiUDP.h>
#include <EEPROM.h>

extern "C" {
  #include "user_interface.h"
}

static const int INTERNAL_LED = D0; // Amica has two internals LEDs: D0 and D4

static const char* __ssid_ap = "commodore_home_alarm";       // SSID for Access Point
static const char __signature[] = "c=h";
static const char __default_uni_ip_address[] = "192.168.1.4\0";

enum {
    // possible errors. Use nubmer >=2
    ERROR_CANNOT_CONNECT = 2,
    ERROR_MDNS_FAIL = 3,
    ERROR_UDP_FAIL = 4,
};

enum {
    MODE_AP = 0,        // AP, creates the Commodore Home Alarm wifi network
    MODE_STA = 1,       // STA, tries to connect to SSID. If it fails, then AP
    MODE_WPS = 2,       // WPS, tries to connect to SSID. If it fails, then WPS, if it fails AP.
};

static const uint8_t DEFAULT_MODE = MODE_AP;

static const unsigned int UNI_PORT = 6464;     // local port to listen for UDP packets
static IPAddress __localIPAddress;                   // local IP Address
static IPAddress __uniIPAddress;                   // local IP Address
static uint8_t __mode = DEFAULT_MODE;           // how to connect ?
static int __lastTimeActivity = 0;              // last time when there was activity
static bool __in_ap_mode = false;               // in AP connection? different than __mode, since
                                                // this is not a "mode" but how the connection was established


static byte packetBuffer[512];             //buffer to hold incoming and outgoing packets

static WiFiUDP __udp;                           // server for joysticks commands
static ESP8266WebServer __settingsServer(80);   // server for settings


void setup()
{
    // Open serial communications and wait for port to open:
    Serial.begin(115200);
    Serial.setDebugOutput(true);

    EEPROM.begin(256);

    delay(500);

    __mode = getMode();
    __in_ap_mode = false;

    Serial.printf("\n*** Commodore Home Alarm " COMMODORE_HOME_ALARM_VERSION " ***\n");
    char ip_address[512];
    readIPAddress(ip_address);
    __uniIPAddress.fromString(ip_address);
    Serial.printf("\nMode: %d. UniJoystiCle IP Address: %s\n", __mode, ip_address);

    // setting up Station AP
    setupWiFi();
    delay(500);
    printWifiStatus();

    delay(2000);

    if (MDNS.begin("commodore_home_alarm"))
        Serial.println("MDNS responder started");
    else fatalError(ERROR_MDNS_FAIL);

    createWebServer();
    __settingsServer.begin();
    Serial.println("HTTP server started");

    MDNS.addService("http", "tcp", 80);
    delay(100);

    pinMode(A0, INPUT);
}

void loop()
{
    loopSensor();
    __settingsServer.handleClient();
}

static void loopSensor()
{
    char buf[100];
    int d = analogRead(A0);

    static bool triggered = false;

    delay(50);

    // threshold 100 looks Ok
    if (d < 100)
    {
        if (!triggered) {
            // Protocol v2
            // packetBuffer[0] = version
            // packetBuffer[1] = ports enabled
            // packetBuffer[2] = joy1
            // packetBuffer[3] = joy2

            packetBuffer[0] = 2;
            packetBuffer[1] = 3;
            packetBuffer[2] = 0;
            packetBuffer[3] = 22;                           // 22 = Trigger alarm
            __udp.beginPacket(__uniIPAddress, UNI_PORT);    // unijoysticle port
            __udp.write(packetBuffer, 4);
            __udp.write(packetBuffer, 4);                   // send it twice
            __udp.endPacket();

            triggered = true;
            Serial.println("Door open");
        }
    } else if (d > 700) {
        // door closed, but was previously triggered ?
        if (triggered) {
            triggered = false;

            packetBuffer[0] = 2;
            packetBuffer[1] = 3;
            packetBuffer[2] = 0;
            packetBuffer[3] = 0;           // 0 = Do nothing. but clean, the ports
            __udp.beginPacket(__uniIPAddress, UNI_PORT); // unijoysticle port
            __udp.write(packetBuffer, 4);
            __udp.write(packetBuffer, 4);
            __udp.endPacket();
            Serial.println("Door closed");
        }
    }
}

static void fatalError(int times)
{
    Serial.println("Fatal error. Reboot please");
    pinMode(INTERNAL_LED, OUTPUT);
    while(1) {
        // report error
        for (int i=0; i<times; i++) {
            delay(400);
            digitalWrite(INTERNAL_LED, LOW);
            delay(400);
            digitalWrite(INTERNAL_LED, HIGH);
        }
        delay(500);
    }
}

static void setupWiFi()
{
    bool ok = false;

    if (__mode == MODE_STA || __mode == MODE_WPS)
        ok = setupSTA();

    if (!ok && __mode == MODE_WPS)
        ok = setupWPS();

    // always default to AP if couldn't connect with previous modes
    if (!ok)
        ok = setupAP();
}

static bool setupAP()
{
    delay(100);
    WiFi.mode(WIFI_AP);
    delay(100);

    uint8_t mac[WL_MAC_ADDR_LENGTH];
    WiFi.softAPmacAddress(mac);
    char buf[50];
    memset(buf, 0, sizeof(buf)-1);
    snprintf(buf, sizeof(buf)-1, "%s-%x%x%x",
             __ssid_ap,
             mac[WL_MAC_ADDR_LENGTH-3],
             mac[WL_MAC_ADDR_LENGTH-2],
             mac[WL_MAC_ADDR_LENGTH-1]);

    Serial.printf("Creating AP with SSID='%s'...",buf);
    bool success = false;
    while(!success) {
        if ((success=WiFi.softAP(buf))) {
            Serial.println("OK");
        } else {
            Serial.println("Error");
            delay(1000);
        }
    }

    __in_ap_mode = true;
    return true;
}

static bool setupSTA()
{
    char ssid[128];
    char pass[128];
    readCredentials(ssid, pass);

    Serial.printf("Trying to connect to %s...\n", ssid);
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, pass);
    return (WiFi.waitForConnectResult() == WL_CONNECTED);
}

static bool setupWPS()
{
    // Mode must be WIFI_STA, but it is already in that mode
    Serial.println("Trying to connect using WPS...");
    bool wpsSuccess = WiFi.beginWPSConfig();
    if(wpsSuccess) {
        // in case of a timeout we might have an empty ssid
        String newSSID = WiFi.SSID();
        if(newSSID.length() > 0) {
            Serial.printf("Connected to SSID '%s'\n", newSSID.c_str());
            Serial.printf("Password: %s\n", WiFi.psk().c_str());
            saveCredentials(WiFi.SSID(), WiFi.psk());
            delay(500);
        } else {
            Serial.println("WPS failed");
            wpsSuccess = false;
        }
    }

    if (!wpsSuccess) {
        // Issue #1845: https://github.com/esp8266/Arduino/issues/1845
        delay(500);
        wifi_wps_disable();
    }
    return wpsSuccess;
}

static void printWifiStatus()
{
    if (__in_ap_mode) {
        Serial.print("AP Station #: ");
        Serial.println(WiFi.softAPgetStationNum());
        // print your WiFi shield's IP address:
        __localIPAddress = WiFi.softAPIP();
        Serial.print("Local IP Address: ");
        Serial.println(__localIPAddress);
    }
    else
    {
        // print the SSID of the network you're attached to:
        Serial.printf("SSID: %s\n", WiFi.SSID().c_str());
        // print your WiFi shield's IP address:
        __localIPAddress = WiFi.localIP();
        Serial.print("Local IP Address: ");
        Serial.println(__localIPAddress);
    }
}

//
// EEPROM struct
//  0-2: "uni"
//    3: mode: 0 = AP, creates the unijoysticle wifi network
//             1 = STA, tries to connect to SSID. If it fails, then AP
//             2 = WPS, tries to connect to SSID. If it fails, then WPS, if it fails AP.
//    4: inactivity seconds
//             0 = don't check innactivity
//             any other value = how many seconds should pass before reseting the lines
//  5-7: reserved
//  asciiz: SSID
//  asciiz: password
//  128: asciiz: UniJoystiCle ip address
//
static void readCredentials(char* ssid, char* pass)
{
    if (!isValidEEPROM()) {
        Serial.printf("EEPROM signature failed: not 'uni'\n");
        ssid[0] = 0;
        pass[0] = 0;
        setDefaultValues();
        return;
    }

    int idx=8;
    for(int i=0;;i++) {
        ssid[i] = EEPROM.read(idx++);
        if (ssid[i] == 0)
            break;
    }

    for(int i=0;;i++) {
        pass[i] = EEPROM.read(idx++);
        if (pass[i] == 0)
            break;
    }
    Serial.printf("EEPROM credentials: ssid: %s, pass: %s\n", ssid, pass);
}

static void readIPAddress(char* ipAddress)
{
    if (!isValidEEPROM()) {
        Serial.printf("EEPROM signature failed: not 'uni'\n");
        setDefaultValues();
    }

    int idx=128;
    for(int i=0;;i++) {
        ipAddress[i] = EEPROM.read(idx++);
        if (ipAddress[i] == 0)
            break;
    }

    Serial.printf("Ip Address: %s\n", ipAddress);
}

static void setIPAddress(const String& ipaddress)
{
    int idx=128;
    for(int i=0;ipaddress.length(); i++) {
        EEPROM.write(idx++, ipaddress[i]);
    }
    EEPROM.write(idx, 0);
}

static void saveCredentials(const String& ssid, const String& pass)
{
    int idx = 8;

    for (int i=0; i<ssid.length(); ++i) {
        EEPROM.write(idx, ssid[i]);
        idx++;
    }

    EEPROM.write(idx, 0);
    idx++;

    for (int i=0; i<pass.length(); ++i) {
        EEPROM.write(idx, pass[i]);
        idx++;
    }
    EEPROM.write(idx, 0);
    EEPROM.commit();
}

static bool isValidEEPROM()
{
    bool failed = false;
    for (int i=0; i<3; ++i) {
        char c = EEPROM.read(i);
        failed |= (c != __signature[i]);
    }
    return !failed;
}

static void setDefaultValues()
{
    for (int i=0; i<3; i++) {
        EEPROM.write(i, __signature[i]);
    }
    // Mode
    EEPROM.write(3, DEFAULT_MODE);

    // unused
    EEPROM.write(4, 0);
    EEPROM.write(5, 0);
    EEPROM.write(6, 0);
    EEPROM.write(7, 0);

    // SSID name (asciiz)
    EEPROM.write(8, 0);
    // SSDI passwrod (asciiz)
    EEPROM.write(9, 0);
    // UniJoystiCle IP Address
    EEPROM.write(128, 0);
    EEPROM.commit();

    setDefaultIPAddress(String(__default_uni_ip_address));
}

static void setDefaultIPAddress(const String& ipaddress)
{
    int idx=128;
    for (int i=0;;i++) {
        EEPROM.write(idx++, ipaddress[i]);
        if (ipaddress[i] == 0)
            break;
    }
    EEPROM.commit();
}

static uint8_t getMode()
{
    if (!isValidEEPROM()) {
        setDefaultValues();
        return MODE_AP;
    }
    uint8_t mode = EEPROM.read(3);
    return mode;
}

static void setMode(uint8_t mode)
{
    if (!isValidEEPROM()) {
        setDefaultValues();
    }
    EEPROM.write(3, mode);
    EEPROM.commit();
}


//
// Settings
//
void createWebServer()
{
    static const char *htmlraw = R"html(<html>
<head><title>Commodore Home Alarm WiFi setup</title></head>
<body>
<h1>Commodore Home Alarm WiFi setup</h1>
<h2>Stats</h2>
<ul>
 <li>Firmware: %s</li>
 <li>IP Address: %d.%d.%d.%d</li>
 <li>SSID: %s</li>
 <li>Chip ID: %d</li>
 <li>Last reset reason: %s</li>
</ul>
<h2>Settings</h2>
<h4>Set WiFi mode:</h4>
<form method='get' action='mode'>
 <input type='radio' name='mode' value='0' %s> Access Point mode<br>
 <input type='radio' name='mode' value='1' %s> Station mode<br>
 <input type='radio' name='mode' value='2' %s> Station + WPS mode<br>
 <input type='submit' value='Submit'>
</form>
<small>Reboot to apply changes</small>

<br>
<p>Mode description:</p>
<ul>
 <li>Access Point mode: creates its own WiFi network. The SSID will start with <i>unijoysticle-</i></li>
 <li>Station mode: Tries to connect to a WiFi network using the specified SSID/password. If it fails, it will go into AP mode</li>
 <li>Station mode with WPS: Tries to connect to a WiFi network by using <a href='https://en.wikipedia.org/wiki/Wi-Fi_Protected_Setup'>WPS</a>. If it fails it will go into AP mode</li>
</ul>
<h4>Set SSID/Password (to be used when in STA mode):</h4>
<form method='get' action='setting'>
 <label>SSID: </label><input name='ssid' length=32/>
 <label>Password: </label><input name='pass' length=64/>
 <br/>
 <input type='submit' value='Submit'>
</form>
<small>Reboot to apply changes</small>

<h4>UniJoystiCle IP Address:</h4>
<form method='get' action='ipaddress'>
 <label>IP Address: </label><input name='ipaddress' length=64/>
 <br/>
 <input type='submit' value='Submit'>
</form>
<small>Reboot to apply changes</small>

<h4>Reboot device:</h4>
<form method='get' action='restart'>
 <input type='submit' value='Reboot'>
</form>
)html";

    static const char *htmlredirectok = R"html(<html>
<head>
 <meta http-equiv="refresh" content="1; url=/" />
</head>
<body>Success</body>
</html>
)html";

    static const char *htmlredirecterr = R"html(<html>
<head>
 <meta http-equiv="refresh" content="1; url=/" />
</head>
<body>Error</body>
</html>
)html";

    __settingsServer.on("/", []() {
        char buf[2816];
        const int mode = getMode();
        snprintf(buf, sizeof(buf)-1, htmlraw,
                 COMMODORE_HOME_ALARM_VERSION,
                 __localIPAddress[0], __localIPAddress[1], __localIPAddress[2], __localIPAddress[3],
                 WiFi.SSID().c_str(),
                 ESP.getChipId(),
                 ESP.getResetReason().c_str(),
                 (mode == 0) ? "checked" : "",
                 (mode == 1) ? "checked" : "",
                 (mode == 2) ? "checked" : ""
                 );
        buf[sizeof(buf)-1] = 0;

        delay(0);
        __settingsServer.send(200, "text/html", buf);
    });

    __settingsServer.on("/setting", []() {
        int statusCode = 404;
        String qsid = __settingsServer.arg("ssid");
        String qpass = __settingsServer.arg("pass");
        String content;
        if (qsid.length() > 0 && qpass.length() > 0) {
            saveCredentials(qsid, qpass);
            content = htmlredirectok;
            statusCode = 200;
        } else {
            content = htmlredirecterr;
            statusCode = 404;
        }
        __settingsServer.send(statusCode, "text/html", content);
    });

    __settingsServer.on("/mode", []() {
        String arg = __settingsServer.arg("mode");
        int mode = arg.toInt();
        setMode(mode);
        __settingsServer.send(200, "text/html", htmlredirectok);
    });

    __settingsServer.on("/ipaddress", []() {
        String arg = __settingsServer.arg("ipaddress");
        setIPAddress(arg);
        __settingsServer.send(200, "text/html", htmlredirectok);
    });

    __settingsServer.on("/restart", []() {
        __settingsServer.send(200, "text/html", htmlredirectok);
        delay(1000);
        ESP.restart();
    });
}

