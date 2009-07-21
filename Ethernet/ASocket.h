/*
*
@file		ASocket.h  v0.2
@brief	define function of ASocket API 
*
*/

#ifndef	_ASocket_H_
#define	_ASocket_H_

#ifdef DEBUG
//#define DEBUG_ASOCKET
#endif

#ifdef DEBUG_ASOCKET
 #define D_ASOCKET(msg)  msg
#else
 #define D_ASOCKET(msg) 
#endif



extern "C" {
	#include "utility/types.h"
	#include "utility/w5100.h"
}

class ASocket{
	private:
		SOCKET _sock;
		uint16 _write_ptr;
		uint16 _read_ptr;
		void sendCommand(uint8 command);
		
	public:
		ASocket();
		
		//common API
		void init(SOCKET socket);
		uint8 init(uint8 protocol, uint16 srcPort, uint8 flag ) ;     //Allocates & initializes a socket
		void close(); // Close socket, release back into pool
		void send();  // Send Packet regardless of type
		uint8 status();   //0 - success, 1-timeout, 2 - still processing
		uint16 write(uint8 * buf, uint16 len); // write data into send buffer
		uint16 write(char * buf); // write data into send buffer
		void write_encode(uint8 * buf, uint16 len); // write data encoded into ASCII HEX to send buffer		
		void read(uint8 * buf, uint16 len);  // read data from read buffer
		void readSkip(uint16 len);  //skip over data in the read buffer
		uint8 isClosed();    //returns true if the state == SOCK_CLOSED
		uint16 available();  //returns # of bytes availabe in the receive buffer
		SOCKET getSocket();  //returns the socket #
		
		
		//TCP
		uint8 initTCP(uint16 srcPort ) ;
		void connectTCP(uint8 * addr, uint16 dstPort); // Establish TCP connection (Active connection)
		void disconnectTCP(); // disconnect the connection
		uint8 isConnectedTCP();  // find out if still connected.
		void beginPacketTCP(); // New TCP Packet
		uint8 listenTCP();	// Establish TCP listen connection (Passive connection)
		uint8 isSendCompleteTCP();  //Query if the sending of the last packet was completed.  (returns true even if send timed out)
		
				
		//UDP
		uint8 initUDP(uint16 srcPort ) ;
		uint16 beginRecvUDP(uint8 * addr, uint16  *dstPort);	// Receive a UDP Packet
		void beginPacketUDP(uint8 * addr, uint16 dstPort); // New TCP Packet
		uint8 isSendCompleteUDP();   //Query if the sending of the last packet was completed.  (returns true even if send timed out)

		//IGMP
		uint16 igmpsend(const uint8 * buf, uint16 len);
		
};
#endif
/* _ASocket_H_ */
