/*

 NtpClass NTP Client
 
 Get the time from a Network Time Protocol (NTP) time server
 Demonstrates use of UDP sendPacket and ReceivePacket 
 For more on NTP time servers and the messages needed to communicate with them, 
 see http://en.wikipedia.org/wiki/Network_Time_Protocol
 
 created 17 Nov 2010
 by Barney Parker
 based on Udp NTP Client
 
 created 4 Sep 2010 
 by Michael Margolis
 
 modified 17 Sep 2010
 by Tom Igoe
 
 see http://arduino.cc/en/Tutorial/UdpNtpClient for original code
 
 This code is in the public domain.

 */
#include <Wprogram.h>
#include "Ntp.h"
#include "ASocket.h"

#include <wiring.h>
#include <string.h>

NtpClass::NtpClass() {
}

void NtpClass::init(uint8_t *ntp_server) {
	memcpy(_ntp_server,ntp_server,4);
}

uint8_t NtpClass::request() {
	if( ! _as.initUDP(0))               //set for UDP, allocate socket, no flags
	{	
		return COMPLETE_FAIL;
	}
	
	memset(_ntpBuffer, 0, NTP_PACKET_SIZE); 	// set all bytes in the buffer to 0
	
	// Initialize values needed to form NTP request
	_ntpBuffer[0] = 0b11100011;   	// LI, Version, Mode
	_ntpBuffer[1] = 0;     			// Stratum, or type of clock
	_ntpBuffer[2] = 6;     			// Polling Interval
	_ntpBuffer[3] = 0xEC;  			// Peer Clock Precision
	// 8 bytes of zero for Root Delay & Root Dispersion
	_ntpBuffer[12]  = 49; 
	_ntpBuffer[13]  = 0x4E;
	_ntpBuffer[14]  = 49;
	_ntpBuffer[15]  = 52;

	//send the request
	_as.beginPacketUDP(_ntp_server,123);  //Start a new UDP Packet for destination port 53
	_as.write(_ntpBuffer, NTP_PACKET_SIZE);	//write the data to the udp packet buffer
	_as.send();  //actually send the UDP packet
	
	while(!_as.isSendCompleteUDP());  //wait for udp packet to finish sending
	
	_startTime = millis();
	return COMPLETE_OK; //  success	
}

/* Returns 0 if it's still processing
 * Returns 1 if it succesfully resolved
 * Returns > 1 if an error occured */
uint8_t NtpClass::finished() {
	uint8_t incoming_ip[4];
	uint16_t incoming_port;
	uint8_t message_len;

	if( _as.available() >= NTP_PACKET_SIZE )	{   //Have we received data yet?  
		//Read in the Ntp respose
		message_len = _as.beginRecvUDP(incoming_ip,&incoming_port);
		
		_as.read(_ntpBuffer, NTP_PACKET_SIZE);
		_as.close();
		
		//parse the response in to the format we require
		
		// combine the four bytes (two words) into a long integer
		// this is NTP time (seconds since Jan 1 1900):
                unsigned long u = (unsigned long)_ntpBuffer[35];
                unsigned long v = (unsigned long)_ntpBuffer[34];
                unsigned long w = (unsigned long)_ntpBuffer[33];
                unsigned long x = (unsigned long)_ntpBuffer[32];
                unsigned long z = u | v<<8 | w<<16 | x<<24;
		_time = z - SEVENTY_YEARS;

		//return our result
		return COMPLETE_OK;		
	}
	else if(millis() - _startTime > NTP_TIMEOUT) {
		_as.close();
		return TIMEOUT_EXPIRED;  //Failed Timeout
	}
	return NOT_FINISHED; //We are not finished yet so return 0;
}

void NtpClass::getTimestamp(unsigned long *time) {
        *time = _time;
}

void NtpClass::date(unsigned long *year, unsigned long *month, unsigned long *day, unsigned long *hour, unsigned long *minute, unsigned long *second) {
        //calculate the complete date and time from the currently held timestamp
        *year = _time / 31557600;
        unsigned long leapDays = *year/4;
        unsigned long daysSinceEpoch = (_time / 86400) - leapDays;
        *year += 1970;
        *month = 0;
        *day = (daysSinceEpoch+1) % 365;
        
        unsigned int daysPerMonth[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        
        //account for this year being a leap year
        if(*year % 4 == 0)
                daysPerMonth[1] = 29;
        
        //TODO check if this is a leap year and make feb 29 if necessary
        while(*day > daysPerMonth[*month]) {
                *day -= daysPerMonth[*month];
                *month = *month + 1;
        }
       
        *month++;//make it 1 based
         
        *hour = (_time % 86400) / 3600;
        *minute = (_time % 3600) / 60;
        *second = _time % 60;
}
