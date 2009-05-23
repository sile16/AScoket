/*
*
@file		ASocket.h  v0.1
@brief	define function of ASocket API 
**
* most code pulled from wiznet socket.c
* 
*/ 

#include "ASocket.h"

extern "C" {
  #include "types.h"
  #include "w5100.h"
  #include "socket.h"
  #include "spi.h"
}

#include "WProgram.h"

ASocket::ASocket()
{
	_sock=255;
	_write_ptr=0;
	_read_ptr=0;
	
}

uint8 ASocket::initTCP(uint16 port ) 
{
	// if don't set the source port, set local_port number.
	return init(Sn_MR_UDP,port,0);
}

uint8 ASocket::initUDP(uint16 port ) 
{
	// if don't set the source port, set local_port number.
	return init(Sn_MR_TCP,port,0);
}
		
//Allocate local port automatically
uint8 ASocket::init(uint8 protocol, uint16 port ) 
{
	// if don't set the source port, set local_port number.
	return init(protocol,port,0);  //flag of 0
}

// allocates a socket(TCP or UDP or IP_RAW mode)
uint8 ASocket::init(uint8 protocol, uint16 port, uint8 flag ) 
{ 
	//we need to assign a local port,  1024 + _sock sounds good
	
	//Find an available socket
	_sock = 255;
	
	for(uint8 i = 0; i < MAX_SOCK_NUM ; i++){

		Serial.print("Sock ");
		Serial.print(i,DEC);
		Serial.print(" Status: ");
		Serial.println(getSn_SR(i),HEX);
		
		if( getSn_SR(i) == SOCK_CLOSED ){
			_sock=i;
		}
	}
			
	if(_sock == MAX_SOCK_NUM) {//no avail sockets found, error
		Serial.print("no sockets avail.");
		_sock=255;
		return 0;
	}
	
	if(port == 0) {
		port = 1024 + _sock;  //This should be unique 
	}
	
	Serial.print("init port=");
	Serial.print(port,DEC);
		
	Serial.print("_sock=");
	Serial.println(_sock,DEC);
	
	return socket(_sock, Sn_MR_UDP, 53, 0);		
}
	
void ASocket::close() // Close socket, release back into pool
{
	::close(_sock);

}


void ASocket::send() // Send Packet
{
	Serial.print("send ptr=");
	Serial.println(_write_ptr,DEC);
	
	
	//Write out pointer to W5100
	IINCHIP_WRITE(Sn_TX_WR0(_sock),(uint8)((_write_ptr & 0xff00) >> 8));
	IINCHIP_WRITE((Sn_TX_WR0(_sock) + 1),(uint8)(_write_ptr & 0x00ff));
 	
	//Send command
	IINCHIP_WRITE(Sn_CR(_sock),Sn_CR_SEND);
	
	
	while( IINCHIP_READ(Sn_CR(_sock)) )
		;	
		
	while ( (IINCHIP_READ(Sn_IR(_sock)) & Sn_IR_SEND_OK) != Sn_IR_SEND_OK )
	{
		if(sendStatus() != 2)
		{
			return;
		}
	}
	
}

uint8 ASocket::sendStatus()   //0 - success, 1-timeout, 2 - still processing
{
	if((IINCHIP_READ(Sn_IR(_sock)) & Sn_IR_SEND_OK) != Sn_IR_SEND_OK ) 
	{
	      if(IINCHIP_READ(Sn_IR(_sock)) & Sn_IR_TIMEOUT)
		  {
				return 1;  //timeout
		  }
		  return 2;
	}
	return 0;  //success
}


// write data into send buffer
uint16 ASocket::write(uint8 * buf, uint16 len)
{
	//uint8 status=0;
	//uint16 ret=0;
	//uint16 freesize=0;
/*
	if (len > getIINCHIP_TxMAX(_sock)) {
		len = getIINCHIP_TxMAX(_sock); // check size not to exceed MAX size.
   	}

	// if freebuf is available, start.
	do 
	{
		freesize = getSn_TX_FSR(_sock);
		status = IINCHIP_READ(Sn_SR(_sock));
		if ((status != SOCK_ESTABLISHED) && (status != SOCK_CLOSE_WAIT) && (status != SOCK_UDP))
		{
			ret = 0; 
			break;
		}
	} while (freesize < ret);  */
	Serial.print("Write: ptr: ");
	Serial.print(_write_ptr,DEC);
	Serial.print(" len: ");
	Serial.println(len,DEC);
	write_data(_sock, (uint8 *) buf, (uint8 *)_write_ptr, len);
	_write_ptr +=len;
	
	return len;
} 

void ASocket::endRecv()
{
	IINCHIP_WRITE(Sn_RX_RD0(_sock),(uint8)((_read_ptr & 0xff00) >> 8));
    IINCHIP_WRITE((Sn_RX_RD0(_sock) + 1),(uint8)(_read_ptr & 0x00ff));
	
	IINCHIP_WRITE(Sn_CR(_sock),Sn_CR_RECV);

	/* +20071122[chungs]:wait to process the command... */
	while( IINCHIP_READ(Sn_CR(_sock)) ) 
		;
	/* ------- */
}

// read data into read buffer
void ASocket::read(uint8 * buf, uint16 len)
{
	if ( len > 0 )
	{
		read_data(_sock,(uint8 *) _read_ptr,buf, len);
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
		

	}
}

uint16 ASocket::available() {
  uint16 val = IINCHIP_READ(Sn_RX_RSR0(_sock));
  val = (val << 8) + IINCHIP_READ(Sn_RX_RSR0(_sock) + 1);

//DEBUG
  if(val > 0) {
	  Serial.print("Avail=");
	  Serial.print(val,DEC);
  }
  
  return val;
}

uint8 ASocket::status() {
  return getSn_SR(_sock);
}

//TCP
// Establish TCP connection (Active connection)
void ASocket::connectTCP(uint8 * addr, uint16 port)
{
	// set destination IP
	IINCHIP_WRITE(Sn_DIPR0(_sock),addr[0]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 1),addr[1]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 2),addr[2]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 3),addr[3]);
	IINCHIP_WRITE(Sn_DPORT0(_sock),(uint8)((port & 0xff00) >> 8));
	IINCHIP_WRITE((Sn_DPORT0(_sock) + 1),(uint8)(port & 0x00ff));
	IINCHIP_WRITE(Sn_CR(_sock),Sn_CR_CONNECT);
    
	  /* m2008.01 [bj] :  wait for completion */

		while ( IINCHIP_READ(Sn_CR(_sock)) ) ;
}

// disconnect the connection
void ASocket::disconnectTCP()
{
	IINCHIP_WRITE(Sn_CR(_sock),Sn_CR_DISCON);

	/* +20071122[chungs]:wait to process the command... */
	while( IINCHIP_READ(Sn_CR(_sock)) ) 
		;
	/* ------- */
}

 // New TCP Packet
void ASocket::beginPacketTCP()
{
	Serial.print("Begin TCP ptr=");
	Serial.println(_write_ptr,DEC);
	
	//Initialize the write pointer
	_write_ptr = IINCHIP_READ(Sn_TX_WR0(_sock));
    _write_ptr = ((_write_ptr & 0x00ff) << 8) + IINCHIP_READ(Sn_TX_WR0(_sock) + 1);

}

void ASocket::beginRecvTCP()
{
	_read_ptr = IINCHIP_READ(Sn_RX_RD0(_sock));
    _read_ptr = ((_read_ptr & 0x00ff) << 8) + IINCHIP_READ(Sn_RX_RD0(_sock) + 1);
	
}

// Establish TCP connection (Passive connection)
uint8 ASocket::listen()
{
	if ( status() == SOCK_INIT)
	{
		IINCHIP_WRITE(Sn_CR(_sock),Sn_CR_LISTEN);
		/* +20071122[chungs]:wait to process the command... */
		while( IINCHIP_READ(Sn_CR(_sock)) ) 
			;
		/* ------- */
		return 1;
	}
	
	return 0;
}
	
	
//UDP
// Receive a UDP Packet
uint16 ASocket::beginRecvUDP(uint8 * addr, uint16  *port)
{
	uint8 head[8];
	uint16 data_len=0;
	
	while(available() < 0x08);
	
	beginRecvTCP();  //Read in _read_ptr
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
	IINCHIP_WRITE(Sn_DIPR0(_sock),addr[0]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 1),addr[1]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 2),addr[2]);
	IINCHIP_WRITE((Sn_DIPR0(_sock) + 3),addr[3]);
	IINCHIP_WRITE(Sn_DPORT0(_sock),(uint8)((port & 0xff00) >> 8));
	IINCHIP_WRITE((Sn_DPORT0(_sock) + 1),(uint8)(port & 0x00ff));
	
	Serial.print("begin udp addr: ");
	Serial.print(addr[0],DEC);
	Serial.print(".");
	Serial.print(addr[1],DEC);
	Serial.print(".");
	Serial.print(addr[2],DEC);
	Serial.print(".");
	Serial.print(addr[3],DEC);
	Serial.print(".  port= ");
	Serial.println(port,DEC);
	
	beginPacketTCP();  //everything else from here is the same as TCP
}

