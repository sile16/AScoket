#include "Ethernet.h"
#include "Client.h"
#include "Server.h"

extern "C" {
	#include "utility/types.h"
	#include "utility/w5100.h"
}

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
    
  while (!_as.isConnectedTCP()) {
    if (_as.isClosed())
      return 0;
  }
  
  return 1;
}

void Client::write(uint8_t b) {
  _as.beginPacketTCP();
  _as.write(&b, 1);
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
  }
  
  _as.disconnectTCP();
  _as.close();
}

uint8_t Client::connected() {
  //uint8_t s = status();
  //return !(s == SOCK_LISTEN || s == SOCK_CLOSED || (s == SOCK_CLOSE_WAIT && !available()));
  return _as.isConnectedTCP();
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
