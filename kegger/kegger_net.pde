#ifdef ETHERNET

inline void kegger_net()
{
 switch(networkState){
     case DNS_RESOLVE:
       Serial.println("=====================================================");
       Serial.println("DNS Resolve");
       if(Dns.resolve()) {
         networkState=DNS_WORKING;
         Serial.println("DNS Connected");
       }
       else {
         networkState=NET_IDLE;
         Serial.println("DNS failed to connect");
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
       }
       break;
       
    case DNS_SUCCESS:
       Dns.getIP(server_ip);
       Serial.print("DNS IP: ");
       printArray(&Serial, ".", server_ip, 4, 10);
       if(as.initTCP(0)) {
         networkState = SERVER_CONNECT;
       }
       else{
         networkState = NET_IDLE;
         Serial.println("TCP init failed");
       }
       break;
       
    case SERVER_CONNECT:
       Serial.println("connecting...");
       as.connectTCP(server_ip,80);
       networkState = SERVER_CONNECTING;
       break; 
       
    case SERVER_CONNECTING:
       if(as.isConnectedTCP())
       {
         Serial.println("Connected");
         networkState = SERVER_SEND;
         as.beginPacketTCP();
       }
       else if (as.isClosed())
       {
         Serial.println("Connect failed");
    //     as.disconnectTCP();
         as.close();
         networkState = NET_IDLE;
       }
       break;
       
    case SERVER_SEND:
      
      as.write("GET /kegger/?D=");  //write header
      tempByte = NETWORK_VERSION;
      as.write_encode((uint8*)&tempByte,1);  //write out network protocol version
      as.write_encode((uint8*)&currTemp,2);     //write temperature
      as.write_encode((uint8*)&scale_volts,2);   //write weight 
      as.write_encode((uint8*)&persist,sizeof(persist) - sizeof(persist.server));
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
