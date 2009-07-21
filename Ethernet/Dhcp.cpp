// DHCP Library v0.3 - April 25, 2009
// Author: Jordan Terrell - blog.jordanterrell.com
//   Modified to use the ASocket Library by Matt Robertson

extern "C" {
  #include "types.h"
  #include "w5100.h"
  #include "sockutil.h"
  #include "spi.h"
}
#include "WProgram.h"
#include <string.h>
#include <stdlib.h>
#include "Dhcp.h"
#include "wiring.h"
#include "ASocket.h"


int DhcpClass::beginWithDHCP(uint8_t *mac, u_long timeout, u_long responseTimeout)
{
    uint8_t dhcp_state = STATE_DHCP_START;
    u_char messageType = 0;
  
    // zero out _dhcpMacAddr, _dhcpSubnetMask, _dhcpGatewayIp, _dhcpLocalIp, _dhcpDhcpServerIp, _dhcpDnsServerIp
    memset(_dhcpMacAddr, 0, 26); 

    memcpy((void*)_dhcpMacAddr, (void*)mac, 6);
  
    iinchip_init();
    setSHAR(_dhcpMacAddr);
    setSIPR(_dhcpLocalIp);
    
    sysinit(0x55, 0x55);
    if(!_as.initUDP(DHCP_CLIENT_PORT))
    {
      return -1;
    }
    
//    presend_DHCP();
    
    
    
    int result = 0;
    
    u_long startTime = millis();
    
    while(dhcp_state != STATE_DHCP_LEASED)
    {
        if(dhcp_state == STATE_DHCP_START)
        {
            _dhcpTransactionId++;
            
            send_DHCP_MESSAGE(DHCP_DISCOVER, ((millis() - startTime) / 1000));
            dhcp_state = STATE_DHCP_DISCOVER;
        }
        else if(dhcp_state == STATE_DHCP_DISCOVER)
        {
            messageType = parseDHCPResponse(responseTimeout);
            if(messageType == DHCP_OFFER)
            {
                send_DHCP_MESSAGE(DHCP_REQUEST, ((millis() - startTime) / 1000));
                dhcp_state = STATE_DHCP_REQUEST;
            }
        }
        else if(dhcp_state == STATE_DHCP_REQUEST)
        {
            messageType = parseDHCPResponse(responseTimeout);
            if(messageType == DHCP_ACK)
            {
                dhcp_state = STATE_DHCP_LEASED;
                result = 1;
            }
            else if(messageType == DHCP_NAK)
                dhcp_state = STATE_DHCP_START;
        }
        
        if(messageType == 255)
        {
            messageType = 0;
            dhcp_state = STATE_DHCP_START;
        }
        
        if(result != 1 && ((millis() - startTime) > timeout))
            break;
    }
    
    _dhcpTransactionId++;
	_as.close();
    
    if(result == 1)
    {
        setSIPR(_dhcpLocalIp);
        setGAR(_dhcpGatewayIp);
        setSUBR(_dhcpSubnetMask);
    }
    
    return result;
}


void DhcpClass::send_DHCP_MESSAGE(uint8 messageType, uint16 secondsElapsed)
{
    uint8 dhcp_server[] = {255,255,255,255};
	
	_as.beginPacketUDP(dhcp_server,DHCP_SERVER_PORT);

    uint8 *buffer = (uint8*) malloc(32);
    memset(buffer, 0, 32);

    buffer[0] = DHCP_BOOTREQUEST;   // op
    buffer[1] = DHCP_HTYPE10MB;     // htype
    buffer[2] = DHCP_HLENETHERNET;  // hlen
    buffer[3] = DHCP_HOPS;          // hops

    // xid
    unsigned long xid = htonl(_dhcpTransactionId);
    memcpy(buffer + 4, &(xid), 4);

    // 8, 9 - seconds elapsed
    buffer[8] = ((secondsElapsed & 0xff00) >> 8);
    buffer[9] = (secondsElapsed & 0x00ff);

    // flags
    unsigned short flags = htons(DHCP_FLAGSBROADCAST);
    memcpy(buffer + 10, &(flags), 2);

    // ciaddr: already zeroed
    // yiaddr: already zeroed
    // siaddr: already zeroed
    // giaddr: already zeroed

    //put data in W5100 transmit buffer
    _as.write(buffer, 28);

    memcpy(buffer, _dhcpMacAddr, 6); // chaddr

    //put data in W5100 transmit buffer
    _as.write(buffer,16);

    memset(buffer, 0, 32); // clear local buffer

    // leave zeroed out for sname && file
    // put in W5100 transmit buffer x 6 (192 bytes)
  
    for(int i = 0; i < 6; i++) {
        _as.write(buffer, 32);
    }
  
    // OPT - Magic Cookie
    buffer[0] = (uint8)((MAGIC_COOKIE >> 24)& 0xFF);
    buffer[1] = (uint8)((MAGIC_COOKIE >> 16)& 0xFF);
    buffer[2] = (uint8)((MAGIC_COOKIE >> 8)& 0xFF);
    buffer[3] = (uint8)(MAGIC_COOKIE& 0xFF);

    // OPT - message type
    buffer[4] = dhcpMessageType;
    buffer[5] = 0x01;
    buffer[6] = messageType; //DHCP_REQUEST;

    // OPT - client identifier
    buffer[7] = dhcpClientIdentifier;
    buffer[8] = 0x07;
    buffer[9] = 0x01;
    memcpy(buffer + 10, _dhcpMacAddr, 6);

    // OPT - host name
    buffer[16] = hostName;
    buffer[17] = strlen(HOST_NAME) + 3; // length of hostname + last 3 bytes of mac address
    strcpy((char*)&(buffer[18]), HOST_NAME);

    buffer[24] = _dhcpMacAddr[3];
    buffer[25] = _dhcpMacAddr[4];
    buffer[26] = _dhcpMacAddr[5];

    //put data in W5100 transmit buffer
    _as.write(buffer, 27);

    if(messageType == DHCP_REQUEST)
    {
        buffer[0] = dhcpRequestedIPaddr;
        buffer[1] = 0x04;
        buffer[2] = _dhcpLocalIp[0];
        buffer[3] = _dhcpLocalIp[1];
        buffer[4] = _dhcpLocalIp[2];
        buffer[5] = _dhcpLocalIp[3];

        buffer[6] = dhcpServerIdentifier;
        buffer[7] = 0x04;
        buffer[8] = _dhcpDhcpServerIp[0];
        buffer[9] = _dhcpDhcpServerIp[1];
        buffer[10] = _dhcpDhcpServerIp[2];
        buffer[11] = _dhcpDhcpServerIp[3];

        //put data in W5100 transmit buffer
        _as.write(buffer, 12);
    }
    
    buffer[0] = dhcpParamRequest;
    buffer[1] = 0x06;
    buffer[2] = subnetMask;
    buffer[3] = routersOnSubnet;
    buffer[4] = dns;
    buffer[5] = domainName;
    buffer[6] = dhcpT1value;
    buffer[7] = dhcpT2value;
    buffer[8] = endOption;
    
    //put data in W5100 transmit buffer
    _as.write(buffer,9);

    if(buffer)
        free(buffer);

   _as.send();
   
   while(!_as.isSendCompleteUDP());
}

u_char DhcpClass::parseDHCPResponse(u_long responseTimeout)
{
     uint16 data_len = 0;
     uint16 port = 0;
     u_char type = 0;
     u_char svr_addr[4];
     u_char opt_len = 0;
	 uint8 junk;
     
    uint8* buffer = 0;

    u_long startTime = millis();

    while(_as.available() < 8)
    {
        if((millis() - startTime) > responseTimeout)
            return 255;
    }
//	Serial.print("Parsing DHCP message");
  
 
    // read UDP header
    data_len = _as.beginRecvUDP((uint8*)svr_addr, &port);
//	Serial.print("data=");
//	Serial.println(data_len,DEC);
   
    buffer = (uint8*) malloc(sizeof(RIP_MSG_FIXED));
    RIP_MSG_FIXED * pRMF = (RIP_MSG_FIXED*) buffer;

    _as.read((uint8*)buffer, sizeof(RIP_MSG_FIXED));
//	Serial.print("RIP_MSG Read");
  
    if(pRMF->op == DHCP_BOOTREPLY && port == DHCP_SERVER_PORT)
    {
        if(memcmp(pRMF->chaddr, _dhcpMacAddr, 6) != 0 || pRMF->xid != htonl(_dhcpTransactionId))
        {
            return 0;
        }
//		Serial.println("Trans ID OK");

        memcpy(_dhcpLocalIp, pRMF->yiaddr, 4);
        
		//dump 240 bytes of data to get to option - the sizeof(RIP_MSG_FXIED)
		_as.readSkip(240-sizeof(RIP_MSG_FIXED));
//		Serial.println("240 dump ok");
		free(buffer);

        uint16 optionLen = data_len - 240;
        buffer = (uint8*) malloc(optionLen);
		
        _as.read((uint8*)buffer, optionLen);
//		Serial.println("option len OK");

        uint8* p = buffer;
        uint8* e = p + optionLen;

        while ( p < e ) 
        {
            switch ( *p++ ) 
            {
                case endOption :
                    break;
                    
                case padOption :
                    break;
                    
                case dhcpMessageType :
                    opt_len = *p++;
                    type = *p;
					Serial.print("Found Type");
                    break;
                    
                case subnetMask :
                    opt_len =* p++;
                    memcpy(_dhcpSubnetMask, p ,4);
                    break;
                    
                case routersOnSubnet :
                    opt_len = *p++;
                    memcpy(_dhcpGatewayIp, p, 4);
                    break;
                    
                case dns :
                    opt_len = *p++;
                    memcpy(_dhcpDnsServerIp, p, 4);
                    break;
                    
                case dhcpIPaddrLeaseTime :
                    opt_len = *p++;
                    break;

                case dhcpServerIdentifier :
                    opt_len = *p++;
                    if( *((u_long*)_dhcpDhcpServerIp) == 0 || 
                        *((u_long*)_dhcpDhcpServerIp) == *((u_long*)svr_addr) )
                    {
                        memcpy(_dhcpDhcpServerIp, p ,4);
                    }
                    break;
                    
                default :
                    opt_len = *p++;
                    break;
            }
          
            p += opt_len;
        }
		

        free(buffer);
    }
    while(_as.available())
	{
		_as.read((uint8*)&junk,1);
	}	
    return type;
}

void DhcpClass::getMacAddress(uint8_t *dest)
{
    memcpy(dest, _dhcpMacAddr, 6);
}

void DhcpClass::getLocalIp(uint8_t *dest)
{
    memcpy(dest, _dhcpLocalIp, 4);
}

void DhcpClass::getSubnetMask(uint8_t *dest)
{
    memcpy(dest, _dhcpSubnetMask, 4);
}

void DhcpClass::getGatewayIp(uint8_t *dest)
{
    memcpy(dest, _dhcpGatewayIp, 4);
}

void DhcpClass::getDhcpServerIp(uint8_t *dest)
{
    memcpy(dest, _dhcpDhcpServerIp, 4);
}

void DhcpClass::getDnsServerIp(uint8_t *dest)
{
    memcpy(dest, _dhcpDnsServerIp, 4);
}

DhcpClass Dhcp;
