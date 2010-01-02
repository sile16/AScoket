/*
 * ASocket Web Server
 *
 * A simple web server that shows the value of the analog input pins.
 */

#include <AEthernet.h>
#include <ASocket.h>

//Different Network States
#define CLOSED             1
#define LISTENING          2
#define READING            3
#define READING_FOUND_LF   4
#define WRITING            5
#define CLOSING            6

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 10, 0, 0, 177 };

uint8   state[4];                 //We need to keep track of what state we are in for each socket
ASocket asocket[sizeof(state)];   //Allocate same number of sockets as we have states
                                  //This could be adjusted lower, maybe reserve a socket for outgoing connections.

uint8   readBuffer[100];           //Read buffer for processing the incoming data
                                  //This can be adjusted lower or higher

bool   listening;                 //variable to store if we are activley listening for connections

uint8 stateMachine(ASocket &mysocket, uint8 mystate);

void setup()
{
  Ethernet.begin(mac, ip);
  listening = false;
  
  //Initilize all my states to CLOSED state
  for(int x=0;x<sizeof(state);x++)
      state[x] = CLOSED;
}

void loop()
{
 
  for(int i=0; i < sizeof(state) ; i++) {  //iterate through all of our sockets
    state[i] = stateMachine(asocket[i], state[i]);  //process each socket through our state machine and store the new state
  }
  
  //Do other time sensetive work such as check buttons or update a display.  Check for incoming serial data etc.
  
}

uint8 stateMachine(ASocket &mysocket, uint8 mystate)
{
  int len;
  int x;
  
  switch(mystate){
    case CLOSED:
       if(listening) 
         return CLOSED;           //If we already have a socket listening we don't need to open another one.
       
       mysocket.initTCP(80);      //We don't have any sockets listening so lets start a new one
       mysocket.listenTCP();
       listening=true;
   
    case LISTENING:
    
        if(!mysocket.available()) {   //check to see if any data is available to read
          return LISTENING;
        }
        listening=false;      //Since this was the lisetining socket but it now has a connection we don't have any listening sockets.

    case READING:  //looking for the end of the headers is the most complicated part of this server.
       len = mysocket.available();               //See how much data is available
       if(len > sizeof(readBuffer))              //check to see if the amount of data is larger than our read buffer
         len = sizeof(readBuffer);               //if so we can only read up to the size of our read buffer
         
       mysocket.read(readBuffer,len);            //read data from socket
       for(x=0;x<len;x++) {
          if(readBuffer[x] == '\n') {           //line feed found
             if((x+1) < len) {                  
                if(readBuffer[x+1] == '\r') {   //see if /r is next char
                  return WRITING;               //yes it is we are done reading we can write
                }
             } //if((x+1) < len)
             else {                              
               return READING_FOUND_LF;         //we don't have the next characater
             }
          }  //if(readBuffer[x] == '\n') {  
       } //for
       return READING;                                      //nothing found just keep on reading 
       
   case READING_FOUND_LF:
       if(mysocket.available())                            //okay, we found one already, we just need to check to see if there is one more
       {
         mysocket.read(readBuffer,1);                      //read in one more byte and check to see if it is \r
         if(readBuffer[0] != '\r') {
             return READING;
         }
         return WRITING;
       }
       return READING_FOUND_LF;   
   
   case WRITING:
      mysocket.beginPacketTCP();                            //start a packet
      mysocket.println("HTTP/1.1 200 OK");                  //write headers
      mysocket.println("Content-Type: text/html");   
      mysocket.println();
          
      // output the value of each analog input pin
      for (int i = 0; i < 6; i++) {                        //write our data into the packet      
         mysocket.print("analog input ");
         mysocket.print(i);
         mysocket.print(" is ");
         mysocket.print(analogRead(i));
         mysocket.print("<br />\n");         
       }
      mysocket.send();                                     //send our packet
      mysocket.readSkip(mysocket.available());             //flush recieve buffers
      mysocket.disconnectTCP();                            //disconnect
    
   case CLOSING:
      if(mysocket.isClosed()) {                           //wait for disconnect to complete before releaseing back into pool for new connections
         return CLOSED; 
      }
      return CLOSING;
  }
}
