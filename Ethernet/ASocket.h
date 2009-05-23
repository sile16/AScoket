/*
*
@file		ASocket.h  v0.1
@brief	define function of ASocket API 
*
*/

#ifndef	_ASocket_H_
#define	_ASocket_H_

extern "C" {
	#include "utility/types.h"
	#include "utility/w5100.h"
}

class ASocket{
	private:
		SOCKET _sock;
		uint16 _write_ptr;
		uint16 _read_ptr;
		
		
	public:
		ASocket();
		
		//common API
		uint8 init(uint8 protocol, uint16 port ) ;                 //Allocates & initializes a socket
		uint8 init(uint8 protocol, uint16 port, uint8 flag ) ;     //Allocates & initializes a socket
		void close(); // Close socket, release back into pool
		void send();  // Send Packet
		uint8 sendStatus();   //0 - success, 1-timeout, 2 - still processing
		void endRecv();
		uint16 write(uint8 * buf, uint16 len); // write data into send buffer
		void read(uint8 * buf, uint16 len);  // read data into read buffer
		uint8 error();
		
		uint16 available();
		
		
		//TCP
		uint8 initTCP(uint16 port ) ;
		void connectTCP(uint8 * addr, uint16 port); // Establish TCP connection (Active connection)
		void disconnectTCP(); // disconnect the connection
		uint8 isConnected();  // find out if we are done connecting.
		void beginPacketTCP(); // New TCP Packet
		void beginRecvTCP();
		uint8 listen();	// Establish TCP connection (Passive connection)
				
		//UDP
		uint8 initUDP(uint16 port ) ;
		uint16 beginRecvUDP(uint8 * addr, uint16  *port);	// Receive a UDP Packet
		void beginPacketUDP(uint8 * addr, uint16 port); // New TCP Packet

		//IGMP
		uint16 igmpsend(const uint8 * buf, uint16 len);
		
};
#endif
/* _ASocket_H_ */
