#ifdef ETHERNET

inline void kegger_net()
{
  static u_long startTime;
 
  switch(networkState){
     case NET_DHCP:
         Serial.println("getting ip...");
  
         if(!Dhcp.initialize(persist.mac)) {
           //Failed init
           
           break;
         }
         
         startTime = millis();
         networkState = NET_DHCP_PROCESS;
     
     case NET_DHCP_PROCESS:
     
         ipAcquired = Dhcp.processState();
         
         if(!ipAcquired && ((millis() - startTime) < 30000)){   //30 second timeout for DHCP
           //DHCP  still processing
           break;
         }

         Dhcp.close(ipAcquired);
         
 
        if(ipAcquired == 1)
         {
            byte buffer[6];
//            Serial.println("ip acquired...");
  
            Dhcp.getLocalIp(buffer);
            Serial.print("ip address: ");
            printArray(&Serial, ".", buffer, 4, 10);
            
            Dhcp.getSubnetMask(buffer);
//            Serial.print("subnet mask: ");
//            printArray(&Serial, ".", buffer, 4, 10);
            
            Dhcp.getGatewayIp(buffer);
            Serial.print("gateway ip: ");
            printArray(&Serial, ".", buffer, 4, 10);
            
            Dhcp.getDnsServerIp(server_dns);
            Serial.print("DNS server ip: ");
            printArray(&Serial, ".", server_dns, 4, 10); 
            
            Dns.init(persist.server,server_dns);
            networkState = DNS_RESOLVE;
    
          }
          else{
            Serial.println("dhcp failed");
            networkState = NET_IDLE;   // we will retry
          }  //  if(result == 1) Ethernet connection
     break;
   
     case DNS_RESOLVE:
       //Serial.println("=====================================================");
       Serial.println("DNS Resolve");
       if(Dns.resolve()) {
         networkState=DNS_WORKING;
         Serial.println("DNS Connected");
       }
       else {
         networkState=NET_IDLE;
         Serial.println("DNS failed");
         netFailCount++;
         break;
       }      

    case DNS_WORKING:
       tempByte = Dns.finished();  //0 for still processing, 1 for success, > 1 for error
       if(tempByte == 1) {//success
         networkState = DNS_SUCCESS;
       }
       else if(tempByte > 1) { //Failure
         Serial.print("DNS Error: ");
         Serial.println(tempByte,DEC);
         networkState = NET_IDLE;
         netFailCount++;
       }
       break;
       
    case DNS_SUCCESS:
       Dns.getIP(server_ip);
       Serial.print("DNS IP: ");
       printArray(&Serial, ".", server_ip, 4, 10);
       delay(1);
       networkState = SERVER_CONNECT;
       break;
       
    case SERVER_CONNECT:
        
       if(!as.initTCP(0)) {
         networkState = NET_IDLE;
         Serial.println("TCP init failed");
         netFailCount++;
         break;
       }
       Serial.println("connecting...");
       delay(1);
       as.connectTCP(server_ip,80);

       networkState = SERVER_CONNECTING;
       startTime = millis();
       break; 
       
    case SERVER_CONNECTING:
  
       if(as.isConnectedTCP())
       {
         Serial.println("Connected");
         networkState = SERVER_SEND;
         as.beginPacketTCP();
       }
       else if (millis() - startTime > 5000)
       {
         Serial.println("Connect failed");
         netFailCount++;
         as.disconnectTCP();
         as.close();
         delay(1);
         networkState = NET_IDLE;
       } 
       break;
       
    case SERVER_SEND:
      netFailCount=0;
      //write network version
      as.write("GET /kegger/?A=");  
      tempByte = NETWORK_VERSION | kegStatus;
      as.write_encode((uint8*)&tempByte,1);  //write out network protocol version
      
      //write mac address
      as.write("&B=");
      as.write_encode((uint8*)&persist.mac,sizeof(persist.mac));
      
      //Write out Time & Temp & compressor State
      if(timer_status & 0x10 ){
        timer_status &= ~0x10;  //clear flag to upload time & temp
        
        as.write("&C=");
        as.write_encode((uint8*)&currTemp,2);     //write temperature
        as.write_encode((uint8*)&scale_volts,2);   //write weight 
        as.write_encode((uint8*)&compPower,1);     //Compressor Power
       }
      
      //Write drink information
      if(lastDrink) {
        lastDrink=0;
        as.write("&D=");
        as.write_encode((uint8*)&lastDrink,2);  //write value of last drink
        as.write_encode((uint8*)&persist.kegFlowCount,2);
      }
      
      //write configuration infomration
      if(kegStatus) { 
        kegStatus=0;
        as.write("&E=");
        as.write_encode((uint8*)&persist,sizeof(persist) - sizeof(persist.server) - sizeof(persist.mac));
      }
      
      as.write(" HTTP/1.0\nHOST: ");  //write header
      as.write((uint8*)persist.server,strlen(persist.server));  //write server hostname
      as.write("\n\n");
      as.send();
      
      networkState = SERVER_SEND_COMPLETE;
      break;
      
      case SERVER_SEND_COMPLETE:
        if(as.isSendCompleteTCP())
        {
          networkState = SERVER_RECEIVE;
          Serial.println("Upload Success!");
        }
      break;
      
      case SERVER_RECEIVE:
        if(as.isConnectedTCP())
        {
           if(as.available()){
             as.read(&tempByte,1);
             //Serial.print(tempByte,BYTE);
           }
        }
        else {
          as.disconnectTCP();
          as.close();
          networkState = NET_IDLE;
        }
       break;  
  
  };  //switch(networkState){ 
     
}

#endif
