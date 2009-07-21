// DNS Library v0.2
// Author: Matt Robertson

#include <string.h>

#include "Dns.h"
#include "ASocket.h"
#include "WProgram.h"


DnsClass::DnsClass()
{
	
}
  
void DnsClass::init(char *domain, uint8_t *dns_server)
{
	_domain = domain;   
	memcpy(_dns_server,dns_server,4);
}

uint8_t DnsClass::resolve()
{
	uint8_t dns_header[] = { 0x69,0x69,   //ID
                    0x01,0x00,   //Request Recursion
					0x00,0x01,   // one question
					0x00,0x00,   // 0 answers
					0x00,0x00,   // 0 authority
					0x00,0x00};  // 0 additional 
					
	uint8_t question_footer[] = {	0x00,         //Question root zone
									0x00, 0x01,   //A Record
									0x00, 0x01};  //IN Record
									
					
	uint8_t domain_len=0; //keeps track of the '.' chars in the string.
	
//	Serial.print("Socket init");
	if( ! _as.initUDP(0))               //set for UDP, allocate socket, no flags
	{	
		Serial.print("Error1");
		return 0;
	}
		 
//	Serial.println("UDP Packet Begin");
	_as.beginPacketUDP(_dns_server,53);  //Start a new UDP Packet for destination port 53
//	Serial.println("DNS Header");
	_as.write(dns_header,sizeof(dns_header));  //write header into TX Buffer on W5100
//    Serial.println("Question");
	    
	//Question
	for(uint8_t x=1;x<=strlen(_domain);x++) { //replace each "." with a length field
		domain_len++;
		if(_domain[x] == '.' || _domain[x] == 0x00 ) {
			_as.write((uint8_t*)&domain_len,1);    //write label length into TX Buf
			_as.write((uint8_t*)&_domain[x-domain_len],domain_len);  //write label into TX buf
			domain_len=0;
			x++;
		}
	}
	//add the trailing null char of the name into the line below
//	Serial.println("footer");
	_as.write(question_footer, sizeof(question_footer)); //Write DNS footer
//	Serial.println("Send");
	_as.send();  //actually send the UDP packet
	
	while(!_as.isSendCompleteUDP());  //wait for udp packet to finish sending
	
	_startTime = millis();
	return 1; //  success	
	
}

/* Returns 0 if it's still processing
 * Returns 1 if it succesfully resolved
 * Returns > 1 if an error occured */
uint8_t DnsClass::finished()
{
	int8_t answer_count;
	uint8_t junk;
	uint8_t buf[12];
	uint16_t message_len;

	
	if( _as.available() > 19 )	{   //Have we received data yet?  20 is the UDP header plus the DNS header
		//Read in header
//		Serial.print("Read Header");
		message_len = _as.beginRecvUDP(incoming_ip,&incoming_port);
		
		_as.read(buf, 12);  //pull 12 bytes, size of the DNS header
		
		//check server return code
		junk = buf[3] & 0x0f;
		if(junk != 0 ) {   
			Serial.print("DNS error = 0x");
			Serial.println(buf[3],HEX);
			_as.close() ;
			return junk;
		}
		
		//Answer Count
		answer_count = buf[7];  //if there are more than 128 answers we are screwed becuase we are 8bit signed
			
		//Dump DNS Question, should only be only 1
		dumpName();
		_as.readSkip(4);  //dump
//	    Serial.print("Answers....");
		//Go through answers
		for(;answer_count>0;answer_count--) {
			dumpName();
			_as.read(buf, 10);
			
			if( buf[1] == 0x01) { // We found an A record!
				_ttl = *((long*)&buf[4]);
				_as.read(_answer, 4);
				_as.close();
				return 1;  //Success!
			}
			_as.readSkip(buf[9]);  //dump the RDATA
		}
		
		//No A Records founds error
		_as.close();
		return 2;  //FAILED
		
	} //if( getSn_RX_RSR(_sock) > 0 )
	else if(millis() - _startTime > DNS_TIMEOUT) {
		_as.close();
		return 3;  //Timeout
	}
	return 0; //We are not finished yet so return 0;
}
  
void DnsClass::getIP(uint8_t *ip)
{
  memcpy((void*)ip,(void*)_answer,4);
}

void DnsClass::dumpName()
{
     uint8_t junk;
	 
	 while(true) {
		_as.read(&junk, 1);
		if(junk == 0) { //reached end of label
			return;
		}
		if((junk & 0xc0) == 0xc0) {  //pointer found
			_as.readSkip(1);
			return;
		}
		_as.readSkip(junk);
	}
}
