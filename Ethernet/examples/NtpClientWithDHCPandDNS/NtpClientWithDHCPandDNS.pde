#define DEBUG

#include <AEthernet.h>
#include "Dhcp.h"
#include "Dns.h"
#include "Ntp.h"

#include <string.h>

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
boolean ipAcquired = false;

DnsClass Dns;
NtpClass Ntp;

byte ntpServer[6];

void setup()
{
	Serial.begin(9600);
	Serial.println("getting ip...");
	int result = Dhcp.beginWithDHCP(mac);

	if(result == 1)
	{
		ipAcquired = true;

		byte buffer[6];
		Serial.println("ip acquired...");

		Dhcp.getMacAddress(buffer);
		Serial.print("mac address: ");
		printArray(&Serial, ":", buffer, 6, 16);

		Dhcp.getLocalIp(buffer);
		Serial.print("ip address: ");
		printArray(&Serial, ".", buffer, 4, 10);

		Dhcp.getSubnetMask(buffer);
		Serial.print("subnet mask: ");
		printArray(&Serial, ".", buffer, 4, 10);

		Dhcp.getGatewayIp(buffer);
		Serial.print("gateway ip: ");
		printArray(&Serial, ".", buffer, 4, 10);

		Dhcp.getDhcpServerIp(buffer);
		Serial.print("dhcp server ip: ");
		printArray(&Serial, ".", buffer, 4, 10);

		Dhcp.getDnsServerIp(buffer);
		Serial.print("dns server ip: ");
		printArray(&Serial, ".", buffer, 4, 10);
    
    
		// Do DNS Lookup for the NTP server    
		Dns.init("pool.ntp.org", buffer);  //Buffer contains the IP address of the DNS server
		Dns.resolve();   
       
		while(!(result=Dns.finished())) ;  //wait for DNS to resolve the name
		
		if(result != 1)
		{
		  Serial.print("DNS Error code: ");
		  Serial.print(result,DEC);
		}    
    
		Dns.getIP(ntpServer);  //buffer now contains the IP address for google.com
		Serial.print("NTP Server IP address: ");
		printArray(&Serial, ".", ntpServer, 4, 10);
		
		
	}
	else
		Serial.println("unable to acquire ip address...");
}

void printArray(Print *output, char* delimeter, byte* data, int len, int base)
{
	char buf[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

	for(int i = 0; i < len; i++)
	{
		if(i != 0)
			output->print(delimeter);

		output->print(itoa(data[i], buf, base));
	}

	output->println();
}

void loop()
{
  int result;
        // Do NTP enquiry
		Ntp.init(ntpServer);
		Ntp.request();
		
		while(!(result=Ntp.finished())); //wait for NTP to complete
		
		if(result == COMPLETE_OK)
                {
			//get the time data
			unsigned long epoch;
			Ntp.getTimestamp(&epoch);
			
			//print the number of seconds since Jan 1 1970 (Unix Epoch)
			Serial.println();
                	Serial.print("Seconds since Jan 1 1970: ");
			Serial.println(epoch);

			//print the hour, minute and second:
			Serial.print("The UTC time is ");       // UTC is the time at Greenwich Meridian (GMT)
			Serial.print((epoch  % 86400L) / 3600); // print the hour (86400 equals secs per day)
			Serial.print(':');  
			Serial.print((epoch  % 3600) / 60); // print the minute (3600 equals secs per minute)
			Serial.print(':'); 
			Serial.println(epoch %60); // print the second

                        unsigned long year, month, day, hour, minute, second;
                        Ntp.date(&year, &month, &day, &hour, &minute, &second);
                        Serial.print("Unix Time = ");
                        Serial.print(day);
                        Serial.print("/");
                        Serial.print(month);
                        Serial.print("/");
                        Serial.print(year);
                        Serial.print(" ");
                        Serial.print(hour);
                        Serial.print(":");
                        Serial.print(minute);
                        Serial.print(":");
                        Serial.println(second);
		}
                else 
		{
                    switch(result) {
                      case TIMEOUT_EXPIRED:
                        Serial.println("Timeout");
                        break;
                      case NO_DATA:
                        Serial.println("No Data");
                        break;
                      case COMPLETE_FAIL:
                        Serial.println("Failed");
                        break;
                    }
		}
		
}
