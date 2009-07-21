#ifndef Server_h
#define Server_h

#include "Print.h"
#include "ASocket.h"

class Client;

class Server : public Print {
private:
  uint16_t _port;
  void accept();
  ASocket _as;
public:
  Server(uint16_t);
  Client available();
  void begin();
  virtual void write(uint8_t);
};

#endif
