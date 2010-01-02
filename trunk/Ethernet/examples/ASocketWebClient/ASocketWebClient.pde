#include <AEthernet.h>

#define SERVER_CONNECT    0
#define SERVER_CONNECTING 1
#define SERVER_RECEIVE    2
#define NET_IDLE          3
#define NET_TIMER         4


byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 26, 177 };
byte server[] = { 64, 233, 187, 99 }; // Google

ASocket as;
uint16 start_time;
uint8  networkState = SERVER_CONNECT;


void setup()
{
  Ethernet.begin(mac, ip);
  Serial.begin(9600);
  
  delay(1000);
}

void loop()
{
  switch(networkState){
    case SERVER_CONNECT:
       Serial.println("connecting...");
       if(as.initTCP(0))  // 0 means to select the source port automatically
       {
         as.connectTCP(server,80);
         networkState = SERVER_CONNECTING;
       }
       else
       {  
         Serial.println("failed to initialize socket");
         networkState = NET_IDLE;
       }
       break; 
       
    case SERVER_CONNECTING:
       if(as.isConnectedTCP())
       {
         Serial.println("Connected");
         as.beginPacketTCP();
         as.write("GET /search?q=arduino HTTP/1.0\n\n");  //write header
         as.send();
      
         networkState = SERVER_RECEIVE;
       
       }
       else if (as.isClosed())
       {
         Serial.println("Connect failed");
         as.close();
         networkState = NET_IDLE;
       }
       break;
 
      
      case SERVER_RECEIVE:
        if(as.isConnectedTCP())
        {
           if(as.available()){
             uint8 c;
             as.read(&c,1);
               Serial.print(c);
           }
        }
        else {
          as.disconnectTCP();
          as.close();
          networkState = NET_IDLE;
        }
       break;
     
     case NET_IDLE:
        start_time = millis();
        networkState = NET_TIMER;
        break;
     
     case NET_TIMER:
        if((millis() - start_time) > 5000 ) {// Wait 5 seconds between retries
          networkState = SERVER_CONNECT;
        }
        break;
        
  };  //switch(networkState){ 
 
 
}
