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
#ifndef Ntp_h
#define Ntp_h

#include "ASocket.h"

 //size of NTP packet in Bytes
#define NTP_PACKET_SIZE		48

//5 second time out value
#define NTP_TIMEOUT      	5000

// Unix time starts on Jan 1 1970. In seconds, that's 2208988800 since Jan 1 1900 (provided by NTP)
#define SEVENTY_YEARS 		2208988800UL

//return values
#define NOT_FINISHED		0
#define COMPLETE_FAIL		0
#define COMPLETE_OK		1
#define NO_DATA			2
#define TIMEOUT_EXPIRED		3

class NtpClass {
	private:
		uint8_t _ntp_server[4];
		ASocket _as;
		u_long _startTime;
		uint8_t _ntpBuffer[NTP_PACKET_SIZE]; //buffer to hold incoming and outgoing packets 
		unsigned long _time;
		
	public:
		NtpClass();
		
		void init(uint8_t *ntp_server);
		uint8_t request();
		uint8_t finished();
		void getTimestamp(unsigned long *time);
                void date(unsigned long *year, unsigned long *month, unsigned long *day, unsigned long *hour, unsigned long *minute, unsigned long *second);
};

#endif


