// DNS Library v0.1
// Author: Matt Robertson

#ifndef Dns_h
#define Dns_h

#include "ASocket.h"

#ifdef DEBUG
//#define DEBUG_DNS
#endif

#ifdef DEBUG_DNS
 #define D_DNS(msg)  
#else
 #define D_DNS(msg)  msg
#endif

#define DNS_IDLE         0
#define DNS_HEADER       1
#define DNS_QUESTION     2
#define DNS_RR_TEXT      3
#define DNS_RR_HEADER    4
#define DNS_RR_ANSWER    5
#define DNS_RR_SKIP      6
#define DNS_SIZE		 7

//5 second time out value
#define DNS_TIMEOUT      5000



class DnsClass {
private:
  uint8_t _dns_server[4];
  ASocket _as;
  
  uint8_t incoming_ip[4];
  uint16_t incoming_port;
    
  char* _domain;
  uint8_t _answer[4];
  uint16_t _ttl;
  uint16_t _age;
  u_long _startTime;
  void dump(uint8_t count);
  void dumpName();

public:
  DnsClass();
  
  void init(char *domain, uint8_t *dns_server);
  uint8_t resolve();
  uint8_t finished();
  void getIP(uint8_t *ip);
  
};

#endif
