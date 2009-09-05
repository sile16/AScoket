/*
*
@file		ASocket.h  v0.2
@brief	define function of ASocket API 
@Author	Matt Robertson
**
* most code pulled from wiznet & socket.c
* 
*/ 

#include "ASocket.h"

extern "C" {
  #include "types.h"
  #include "w5100.h"
}

#include "WProgram.h"


ASocket::ASocket()
{
	_sock=255;
	_write_ptr=0;
	_read_ptr=0;
	
}

void ASocket::init(SOCKET socket)
{
	_sock=socket;
}

uint8 ASocket::initTCP(uint16 srcPort ) 
{
	// if don't set the source port, set local_port number.
	return init(Sn_MR_TCP,srcPort,0);
}

uint8 ASocket::initUDP(uint16 srcPort ) 
{
	// if don't set the source port, set local_port number.
	return init(Sn_MR_UDP,srcPort,0);  //flag of 0
}

// allocates a socket(TCP or UDP or IP_RAW mode)
uint8 ASocket::init(uint8 protocol, uint16 srcPort, uint8 flag ) 
{ 
    //Find an available socket

	for(_sock = 0; _sock < MAX_SOCK_NUM ; _sock++){

		D_ASOCKET(Serial.print("Sock "));
		D_ASOCKET(Serial.print(_sock,DEC));
		D_ASOCKET(Serial.print(" Status: "));
		D_ASOCKET(Serial.println(getSn_SR(_sock),HEX));
		
		if( isClosed() ){  //isClosed uses _sock to determine status
			break;
		}
	}

	D_ASOCKET(Serial.print("selected: "));
	D_ASOCKET(Serial.println(_sock,DEC));


			
	if(_sock == MAX_SOCK_NUM) {//no avail sockets found, error
		D_ASOCKET(Serial.print("no sockets avail."));
		_sock=255;
		return 0;
	}
	
	//if srcPort=0 we need to assign a local port,  1024 + _sock sounds good
	if(srcPort == 0) {
		srcPort = 1024 + _sock;  //This should be unique 
	}
	
	
	D_ASOCKET(Serial.print("init port="));
	D_ASOCKET(Serial.print(srcPort,DEC));
		
	D_ASOCKET(Serial.print("_sock="));
	D_ASOCKET(Serial.println(_sock,DEC));
	
	//return socket(_sock, protocol, srcPort, 0);		
	if ((protocol == Sn_MR_TCP) || (protocol == Sn_MR_UDP) || (protocol == Sn_MR_IPRAW) || (protocol == Sn_MR_MACRAW) || (protocol == Sn_MR_PPPOE))
	{
		//Close socket again to make sure we are starting with a clean slate
		SOCKET temp_sock=_sock;
		close();
		_sock = temp_sock;
	
	    //set socket parameters
		IINCHIP_WRITE(Sn_MR(_sock),protocol | flag);
		IINCHIP_WRITE(Sn_PORT0(_sock),(uint8)((srcPort & 0xff00) >> 8));
		IINCHIP_WRITE((Sn_PORT0(_sock) + 1),(uint8)(srcPort & 0x00ff));

		//open socket
		sendCommand(Sn_CR_OPEN); // run sockinit Sn_CR
		return 1;
	}
	return 0;
}

void ASocket::sendCommand(uint8 command)
{
	if(_sock == 255)
		return;
	
	IINCHIP_WRITE(Sn_CR(_sock),command);
	
    while( IINCHIP_READ(Sn_CR(_sock)) ) 
		;
}
	
void ASocket::close() // Close socket, release back into pool
{
	if(_sock != 255)
	{
		sendCommand(Sn_CR_CLOSE);
		
		IINCHIP_WRITE(Sn_IR(_sock), 0xFF);  //clear interrupts
		_sock = 255;  //release our socket #
	}
}


void ASocket::send() // Send Packet
{
//	D_ASOCKET(Serial.print("send ptr="));
//	D_ASOCKET(Serial.println(_write_ptr,DEC));

	if(isClosed())
		return;
	
	
	//Write out pointer to W5100
	IINCHIP_WRITE(Sn_TX_WR0(_sock),(uint8)((_write_ptr & 0xff00) >> 8));
	IINCHIP_WRITE((Sn_TX_WR0(_sock) + 1),(uint8)(_write_ptr & 0x00ff));
 	
	//Send command
	sendCommand(Sn_CR_SEND);
	
}

uint8 ASocket::isSendCompleteUDP()
{
	if(isClosed())
		return 1;
	
	if( (IINCHIP_READ(Sn_IR(_sock)) & Sn_IR_SEND_OK) != Sn_IR_SEND_OK )  {
		if (IINCHIP_READ(Sn_IR(_sock)) & Sn_IR_TIMEOUT) {
			
			IINCHIP_WRITE(Sn_IR(_sock), (Sn_IR_SEND_OK | Sn_IR_TIMEOUT)); /* clear SEND_OK & TIMEOUT */
			return 1;
		}
		 
	    return 1;
	}
    //clear interrupt
	IINCHIP_WRITE(Sn_IR(_sock), Sn_IR_SEND_OK);
	return 1;
}

uint8 ASocket::isSendCompleteTCP()
{
	if(isClosed())
		return 1;
		
/* +2008.01 bj */	
	if ( (IINCHIP_READ(Sn_IR(_sock)) & Sn_IR_SEND_OK) != Sn_IR_SEND_OK ) 
	{
		/* m2008.01 [bj] : reduce code */
		if ( status() == SOCK_CLOSED )
		{
			close();
			return 1;  //send finsihed but bad
		}
		return 0;  //still sending
  	}
    //Clear Interrupt
	IINCHIP_WRITE(Sn_IR(_sock), Sn_IR_SEND_OK);

  	return 1;  //send complete

}

void ASocket::write_encode(uint8 * buf_in, uint16 len) // write data into send buffer
{
	uint8 buf_out[2];
	
	for(word i=0; i<len;i++)
	{
		buf_out[0] = ((buf_in[i] & 0xf0) >> 4) + '0';
		if(buf_out[0] > '9') buf_out[0]+=7;
    	buf_out[1] = (buf_in[i] & 0x0f) + '0';
		if(buf_out[1] > '9') buf_out[1]+=7;
		write((uint8*)&buf_out,2);
	}
}

// write data into send buffer
void ASocket::write(const uint8_t *buf, size_t len)
{
	if(isClosed())
		return;
		
	uint8 s=0;
	uint16 freesize=0;

	if (len > getIINCHIP_TxMAX(_sock)) {
		len = getIINCHIP_TxMAX(_sock); // check size not to exceed MAX size.
   	}

	// if freebuf is available, start.
	do 
	{
		freesize = getSn_TX_FSR(_sock);
		s = status();
		if ((s != SOCK_ESTABLISHED) && (s != SOCK_CLOSE_WAIT) && (s != SOCK_UDP))
		{
			return;
		}
	} while (freesize < len);  
//	D_ASOCKET(Serial.print("Write: ptr: "));
//	D_ASOCKET(Serial.print(_write_ptr,DEC));
//	D_ASOCKET(Serial.print(" len: "));
//	D_ASOCKET(Serial.println(len,DEC));
	write_data(_sock, (uint8 *) buf, (uint8 *)_write_ptr, len);
	_write_ptr +=len;
	
//	return len;
} 

void ASocket::write(const char * buf)
{
	return write((uint8*)buf,strlen(buf));
}

void ASocket::write(uint8_t buf)
{
	return write((uint8*)&buf,1);
}

// read data into read buffer
void ASocket::read(uint8 * buf, uint16 len)
{
	if ( len > 0 &&  !isClosed())
	{
		_read_ptr = IINCHIP_READ(Sn_RX_RD0(_sock));
    	_read_ptr = ((_read_ptr & 0x00ff) << 8) + IINCHIP_READ(Sn_RX_RD0(_sock) + 1);

		//make sure pointer doesn't == 0, this allows us to just skip data instead of actually reading it.
		//this is used by the readSkip function
		if(buf != 0)  
		{
			read_data(_sock,(uint8 *) _read_ptr,buf, len);
		}
		_read_ptr+=len;

/* //  DEBUG Data		
		for(uint16 i=0;i<len;i++)
		{
			Serial.print(buf[i],HEX);
			Serial.print(" ");
			if( i % 8 == 0)
				Serial.println(" ");
		}
*/		

		IINCHIP_WRITE(Sn_RX_RD0(_sock),(uint8)((_read_ptr & 0xff00) >> 8));
		IINCHIP_WRITE((Sn_RX_RD0(_sock) + 1),(uint8)(_read_ptr & 0x00ff));
		
		sendCommand(Sn_CR_RECV);
	}
}

void ASocket::readSkip(uint16 count)
{
	read(0,count);
}

uint16 ASocket::available() {
  
  if(isClosed()){
	  return 0;
  }
    
  return getSn_RX_RSR(_sock);

//DEBUG
/*  if(val > 0) {
	  Serial.print("Avail=");
	  Serial.print(val,DEC);
  } */
}

uint8 ASocket::status() {
 
  if(_sock != 255)
  {
  	return getSn_SR(_sock);
  }
  return SOCK_CLOSED;

}

//TCP
// Establish TCP connection (Active connection)
void ASocket::connectTCP(uint8 * addr, uint16 dstPort)
{
	if(isClosed())
		return;
		
	// set destination IP
	IINCHIP_WRITE(Sn_DIPR0(_sock),addr[0]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 1),addr[1]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 2),addr[2]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 3),addr[3]);
	IINCHIP_WRITE(Sn_DPORT0(_sock),(uint8)((dstPort & 0xff00) >> 8));
	IINCHIP_WRITE((Sn_DPORT0(_sock) + 1),(uint8)(dstPort & 0x00ff));
    
	sendCommand(Sn_CR_CONNECT);
}

uint8 ASocket::isConnectedTCP()
{
  uint8_t s = status();
//  D_ASOCKET(Serial.print("Status: "));
//  D_ASOCKET(Serial.println(s,DEC));
//  return !(s == SOCK_LISTEN || s == SOCK_FIN_WAIT || s == SOCK_CLOSED || (s == SOCK_CLOSE_WAIT && !available()));
    return (s == SOCK_ESTABLISHED || (s == SOCK_CLOSE_WAIT && available()));
}

uint8 ASocket::isClosingTCP()
{
  uint8_t s = status();
  return (s == SOCK_FIN_WAIT || (s == SOCK_CLOSE_WAIT && !available()));
}

uint8 ASocket::isClosed()
{
	return status() == SOCK_CLOSED;
}

// disconnect the connection
void ASocket::disconnectTCP()
{
	if(!isClosed())
	{
		sendCommand(Sn_CR_DISCON);
	}
}

 // New TCP Packet
void ASocket::beginPacketTCP()
{
	if(isClosed())
		return;
		
	//Initialize the write pointer
	_write_ptr = IINCHIP_READ(Sn_TX_WR0(_sock));
    _write_ptr = ((_write_ptr & 0x00ff) << 8) + IINCHIP_READ(Sn_TX_WR0(_sock) + 1);
	
//	Serial.print("Begin TCP ptr=");
//	Serial.println(_write_ptr,DEC);

}



// Establish TCP connection (Passive connection)
uint8 ASocket::listenTCP()
{
	if ( status() == SOCK_INIT)
	{
		sendCommand(Sn_CR_LISTEN);
		return 1;
	}
	
	return 0;
}
	
	
//UDP
// Receive a UDP Packet
uint16 ASocket::beginRecvUDP(uint8 * addr, uint16  *port)
{
	if(isClosed())
		return 0;
		
	uint8 head[8];
	uint16 data_len=0;
	
	while(available() < 0x08);
	
	read(head, 0x08);  //read in UDP header
	
	// read peer's IP address, port number.
	addr[0] = head[0];
	addr[1] = head[1];
	addr[2] = head[2];
	addr[3] = head[3];
	
	*port = head[4] ;
	*port = (*port << 8) + head[5];
	
	data_len = head[6];
	data_len = (data_len << 8) + head[7];
	
	return data_len;
}

// New UDP Packet
void ASocket::beginPacketUDP(uint8 * addr, uint16 port)
{
	if(isClosed())
		return;
		
	IINCHIP_WRITE(Sn_DIPR0(_sock),addr[0]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 1),addr[1]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 2),addr[2]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 3),addr[3]);
	IINCHIP_WRITE(Sn_DPORT0(_sock),(uint8)((port & 0xff00) >> 8));
	IINCHIP_WRITE((Sn_DPORT0(_sock) + 1),(uint8)(port & 0x00ff));

/*
	D_ASOCKET(Serial.print("begin udp addr: "));
	D_ASOCKET(Serial.print(addr[0],DEC));
	D_ASOCKET(Serial.print("."));
	D_ASOCKET(Serial.print(addr[1],DEC));
	D_ASOCKET(Serial.print("."));
	D_ASOCKET(Serial.print(addr[2],DEC));
	D_ASOCKET(Serial.print("."));
	D_ASOCKET(Serial.print(addr[3],DEC));
	D_ASOCKET(Serial.print(".  port= "));
	D_ASOCKET(Serial.println(port,DEC));  */
	
	beginPacketTCP();  //everything else from here is the same as TCP
}

SOCKET ASocket::getSocket()
{
	return _sock;
}
