extern "C" {
  #include "types.h"
  #include "w5100.h"
  #include "string.h"
}

#include "WProgram.h"

#include "Ethernet.h"
#include "Client.h"
#include "Server.h"


Client::Client(uint8_t sock) {
  _as.init(sock);
}

Client::Client(uint8_t *ip, uint16_t port) {
  _ip = ip;
  _port = port;
}

uint8_t Client::connect() {
  
  if(!_as.initTCP(0)) {    //0 means select source port automatically
  		return 0;
  }
  
  _as.connectTCP(_ip,_port);
    
  while (status() != SOCK_ESTABLISHED) {
    delay(1);
    if (status() == SOCK_CLOSED) {
  		_as.close();
      return 0;
    }
  }
  
  return 1;
}

void Client::write(uint8_t b) {
    write((uint8_t *) &b, 1);
}

void Client::write(const char *str) {
  write((uint8_t *)str,strlen(str));
}

void Client::write(const uint8_t *buf, size_t size) {
  _as.beginPacketTCP();
  _as.write((uint8_t *)buf, size);
  _as.send();
}

int Client::available() {
  return _as.available();
}

int Client::read() {
  uint8_t b;
  if (!available())
    return -1;  
  _as.read(&b, 1);
  return b;
}

void Client::flush() {
  _as.readSkip(_as.available());
    
}

void Client::stop() {

  SOCKET temp_socket = _as.getSocket();
  
  if( temp_socket < MAX_SOCK_NUM)
  { 
	    EthernetClass::_server_port[temp_socket] = 0;
  
		// attempt to close the connection gracefully (send a FIN to other side)
		_as.disconnectTCP();
		unsigned long start = millis();

		// wait a second for the connection to close
		while (status() != SOCK_CLOSED && millis() - start < 1000)
		  delay(1);

		// if it hasn't closed, close it forcefully
		if (status() != SOCK_CLOSED)
		  _as.close();
	}
}

uint8_t Client::connected() {
	
    uint8_t s = status();
   
    return !(s == SOCK_LISTEN || s == SOCK_CLOSED || s == SOCK_FIN_WAIT ||
      (s == SOCK_CLOSE_WAIT && !available()));
}


uint8_t Client::status() {
  return _as.status();
}

// the next three functions are a hack so we can compare the client returned
// by Server::available() to null, or use it as the condition in an
// if-statement.  this lets us stay compatible with the Processing network
// library.

uint8_t Client::operator==(int p) {
  return _as.isClosed();
}

uint8_t Client::operator!=(int p) {
  return !_as.isClosed();
}

Client::operator bool() {
  return !_as.isClosed();
}
