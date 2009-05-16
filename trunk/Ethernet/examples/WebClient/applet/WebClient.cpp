#include <Ethernet.h>

#include "WProgram.h"
void setup();
void loop();
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 25, 23 };
byte server[] = { 64, 191, 203, 30 }; // Google
byte gateway[] = { 192, 168, 25, 1 };
byte subnet[] = { 255, 255, 255, 0 };



Client client(server, 80);

void setup()
{
  Ethernet.begin(mac, ip, gateway, subnet);
  Serial.begin(115200);
  
  delay(1000);
  
  Serial.println("connecting...");
  
  if (client.connect()) {
    Serial.println("connected");
    client.println("GET / HTTP/1.0");
    client.println();
  } else {
    Serial.println("connection failed");
  }
}

void loop()
{
  if (client.available()) {
    char c = client.read();
    Serial.print(c);
  }
  
  if (!client.connected()) {
    Serial.println();
    Serial.println("disconnecting.");
    client.stop();
    for(;;)
      ;
  }
}

int main(void)
{
	init();

	setup();
    
	for (;;)
		loop();
        
	return 0;
}

