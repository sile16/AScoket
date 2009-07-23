#include "Ethernet.h"
#include "Client.h"
#include "Server.h"
#include "string.h"


extern "C" {
	#include "utility/types.h"
	#include "utility/w5100.h"
}

Server::Server(uint16_t port)
{
  _port = port;
}

void Server::begin()
{
/*  for (int sock = 0; sock < MAX_SOCK_NUM; sock++) {
    Client client(sock);
    if (client.status() == SOCK_CLOSED) {
      socket(sock, Sn_MR_TCP, _port, 0);
      listen(sock);
      EthernetClass::_server_port[sock] = _port;
      break;
    }
  } */
  
  if(_as.initTCP(_port))
  {
  	_as.listenTCP();
	EthernetClass::_server_port[_as.getSocket()] = _port;
  }
}

void Server::accept()
{
  uint8 listening = 0;
  
  for (SOCKET sock = 0; sock < MAX_SOCK_NUM; sock++) {
    _as.init(sock);
    
    if (EthernetClass::_server_port[sock] == _port) {
      if (_as.status() == SOCK_LISTEN) {
        listening = 1;
      } else if (_as.isClosingTCP()) {
	//	_as.disconnectTCP();
        _as.close();
		EthernetClass::_server_port[sock] = 0;
      }
    } 
  }
  
  if (!listening) {
    begin();
  }
}

Client Server::available()
{
  accept();
  
  for (int sock = 0; sock < MAX_SOCK_NUM; sock++) {
    Client client(sock);
    if (EthernetClass::_server_port[sock] == _port && client) { //  client.status() == SOCK_ESTABLISHED) {
      if (client.available()) {
        // XXX: don't always pick the lowest numbered socket.
        return client;
      }
    }
  }
  
  return Client(255);
}

void Server::write(uint8_t b) 
{
  write(&b, 1);
}

void Server::write(const char *str) 
{
  write((const uint8_t *)str, strlen(str));
}

void Server::write(const uint8_t *buffer, size_t size) 
{
  accept();
  
  for (int sock = 0; sock < MAX_SOCK_NUM; sock++) {
    Client client(sock);
    
    if (EthernetClass::_server_port[sock] == _port &&
        client.status() == SOCK_ESTABLISHED) {
      client.write(buffer, size);
    }
  }
}
