#include <Ethernet.h>
#include "Dhcp.h"
#include "Dns.h"

#include <string.h>

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
boolean ipAcquired = false;

DnsClass googleDns;

void setup()
{
  Serial.begin(9600);
  
  Serial.println("getting ip...");
  int result = Dhcp.beginWithDHCP(mac);
  
  if(result == 1)
  {
    ipAcquired = true;
    
    byte buffer[6];
    Serial.println("ip acquired...");
    
    Dhcp.getMacAddress(buffer);
    Serial.print("mac address: ");
    printArray(&Serial, ":", buffer, 6, 16);
    
    Dhcp.getLocalIp(buffer);
    Serial.print("ip address: ");
    printArray(&Serial, ".", buffer, 4, 10);
    
    Dhcp.getSubnetMask(buffer);
    Serial.print("subnet mask: ");
    printArray(&Serial, ".", buffer, 4, 10);
    
    Dhcp.getGatewayIp(buffer);
    Serial.print("gateway ip: ");
    printArray(&Serial, ".", buffer, 4, 10);
    
    Dhcp.getDhcpServerIp(buffer);
    Serial.print("dhcp server ip: ");
    printArray(&Serial, ".", buffer, 4, 10);
    
    Dhcp.getDnsServerIp(buffer);
    Serial.print("dns server ip: ");
    printArray(&Serial, ".", buffer, 4, 10);
    
    
    //// Do DNS Lookup
    
    googleDns.init("google.com", buffer);  //Buffer contains the IP address of the DNS server
    googleDns.resolve();
   
    int results;
       
    while(!(results=googleDns.finished())) ;  //wait for DNS to resolve the name
    
    if(results != 1)
    {
      Serial.print("DNS Error code: ");
      Serial.print(results,DEC);
    }
    
    
    googleDns.getIP(buffer);  //buffer now contains the IP address for google.com
    Serial.print("Google IP address: ");
    printArray(&Serial, ".", buffer, 4, 10);
    
    Client client(buffer, 80);
    
    Serial.println("connecting...");

    if (client.connect()) {
      Serial.println("connected");
      client.println("GET /search?q=arduino HTTP/1.0");
      client.println();
    
      while(true){  
        if (client.available()) {
          char c = client.read();
          Serial.print(c);
        }

        if (!client.connected()) {
           Serial.println();
           Serial.println("disconnecting.");
           client.stop();
           spinForever();
        }
      }  // while(true)
      
    
    
    } //if(client.connect())   
    else {
      Serial.println("connection failed");
    } 
  }
  else
    Serial.println("unable to acquire ip address...");
}

void printArray(Print *output, char* delimeter, byte* data, int len, int base)
{
  char buf[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  
  for(int i = 0; i < len; i++)
  {
    if(i != 0)
      output->print(delimeter);
      
    output->print(itoa(data[i], buf, base));
  }
  
  output->println();
}

void loop()
{
    spinForever();
}

void spinForever()
{
  for(;;)
      ;
}
