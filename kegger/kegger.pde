#include <LCD_I2C.h>
#include <stdio.h>
#include <Wire.h>
#include <EEPROM.h>
#include <avr/interrupt.h>
#include <avr/io.h>
#include "kegger.h"

#include <Ethernet.h>
#include "Dhcp.h"


/**************************
 * BEGIN: Compile Options *
 **************************/
 
#define SIMULATE             //simulates temperature changes, use for testing w/o real temp sensor, otherwise comment out for real operation
//#define ETHERNET           //Adds ethernet capability
#define INITIALIZE_PERSIST   //Initializes persitant values

//END: Compile Options *

/************************
 * BEGIN: Constants    *
 ************************/

#define LCD_ENABLE_PIN             6
#define LCD_CONTRAST_PIN           5
#define COMPRESSOR_PIN           7
#define LCD_I2C_ADDR            0x20
#define TP1_ADDR		0x4f
#define A2D_ADDR		0x4a
#define A2D_CONFIG		0x9d
#define TP_CONFIG               0x0c
#define ACCESS_CONFIG           0xac
#define READ_TP  		0xaa
#define START_CONVERT           0x51
#define LED_PIN                 13
#define UP_BUTTON_PIN           15
#define DOWN_BUTTON_PIN         14
#define RIGHT_BUTTON_PIN        16
#define LEFT_BUTTON_PIN         17
#define LED_STATUS1_PIN         8
#define LED_STATUS2_PIN         9

#define BUTTONS_CHANGED_FLAG    0x10
#define INIT_TIMER_COUNT        6

//END: Constants 


/************************
 * BEGIN:    Globals    *
 ************************/





// stateMenu is an array of finite state machine ID actions per button pressed
//   -Each row is the state, each col is a ptr to state based on button pressed
//    Ex: stateMenu[0] is the idle state
//          stateMenu[0][0] is state identifier (0)
//          stateMenu[0][1] is ptr to state when UP is pressed
//          stateMenu[0][2] is ptr to state when RIGHT is pressed
//          stateMenu[0][3] is ptr to state when DOWN is pressed
//    NOTE: stateMenu[0][4] is ptr to state when LEFT is pressed
//    Current Menu Order: 0<->1<->6<->8<->3<->0
static int stateMenu[][4] = { {3,0,1,0},    //Screen 00: Idle
                              {0,2,6,0},    //Screen 01: Set Temp
                              {2,4,2,1},    //Screen 02:   Set Temp 2
                              {12,5,0,0},   //Screen 03: About
                              {0,0,0,0},    //Screen 04: Saved
                              {5,0,5,3},    //Screen 05:    About 2
                              {1,7,8,0},    //Screen 06: Set Unit
                              {7,4,7,6},    //Screen 07:    Set Unit 2
                              {6,9,10,0},   //Screen 08: Set Contrast
                              {9,4,9,8},    //Screen 09:    Set Contrast 2
                              {8,11,12,0},  //Screen 10: Set Temp Gap
                              {11,4,11,10}, //Screen 11:    Set Temp Gap 2
                              {10,13,3,0},  //Screen 12: Keg Reset/Tare
                              {13,4,13,12}, //Screen 13:    Keg Reset/Tare 2
                            };
static int currState = 0;
static int prevState = currState;
static boolean compPower = true;

temperature currTemp;
static byte newKegTemp;
static byte buttonPressed = 255;

static byte prevContrast;
static byte prevKegTempGap;
static byte prevKegTareFull;
static boolean prevUseMetric;

static byte prevButtonTransientState = 0;
static byte currButtonState=0;    //Current button state plus bit 4 used to keep track of transient changes. BUTTONS_CHANGED_FLAG

// persistent variable to store between power outage
// Add variable to the end of this struct to avoid breaking current values stored in memory
static struct{
   byte kegTemp;
   boolean useMetric;
   
   byte contrast;
   byte kegTempGap;

   word kegTareFull;
   word kegTareEmpty;
   
   //Adding network stuff towards end as this is the most unstable part.
   byte mac[6];            //MAC Address, should be unique to every keggorator
   byte server[50];        //Server hostname to send Updates to.
   byte server_path[10];   //Path on server to send updates
 
} persist;




volatile static byte timer_status = 0;
volatile static byte timer_count = 0;
static byte tempByte;
word scale_volts;

#ifdef ETHERNET
byte server[] = { 64, 233, 187, 99 }; // Google
Client client(server, 80);
boolean ipAcquired = false;
#endif
// END: Globals  


/************************************
 * ISR(TIMER2_OVF_vect)             
 *
 * Called every 4ms, Timer2 Overflow Interrupt
 * Increments counters for 3 status timers
 *
 ************************************/
ISR(TIMER2_OVF_vect) {  //Every 4 ms
  TCNT2 = INIT_TIMER_COUNT;   //sets the starting value of the timer to 6 so we get 250 counts before overflow of our 8 bit counter
  
  timer_count++;
  timer_status |= 1;   //Turn on flag for Timer1 4ms
  
  if(((timer_count+3) % 5) == 0) {  //20ms
   timer_status |= 2;  //Turn on flag for Timer2 20ms
  }
  
  if((timer_count % 250) == 0) {  //1s
    timer_status |= 4;  //Turn on flag for Timer3 1s
    timer_count=0;
    //Do it directly so no function calls from ISR
    PORTB ^= ( 0x01 << 0);  //Flash LED on Arduino pin 8 on Atmega328
  }
  
}  //ISR(TIME2_OVF_vect)


/************************************
 * void setup()              
 *
 * Called once, does one time setup
 *
 ************************************/
void setup()                    // run once, when the sketch starts
{

  pinMode(LED_PIN, OUTPUT);              // sets the digital pin as output
  pinMode(LED_STATUS1_PIN, OUTPUT);      // sets the digital pin as output
  pinMode(LED_STATUS2_PIN, OUTPUT);      // sets the digital pin as output
  pinMode(UP_BUTTON_PIN, INPUT);
  pinMode(DOWN_BUTTON_PIN, INPUT);
  pinMode(LEFT_BUTTON_PIN, INPUT);
  pinMode(RIGHT_BUTTON_PIN, INPUT);
  pinMode(COMPRESSOR_PIN, OUTPUT);
 
  //Load persistent variable from EEPROM into persist struct.
  loadPersist();
  
  
  Serial.begin(115200);                    // connect to the serial port
  Serial.println("Kegger Begin");
  Wire.begin();


#ifdef INITIALIZE_PERSIST
  persist.kegTareFull = 10500;
  persist.kegTareEmpty = 500;
  //Initialize kegTempGap
  if ((int)persist.kegTempGap >10)
    persist.kegTempGap = 2;
        
  persist.mac[0] = 0xDE; 
  persist.mac[1] = 0xAD;
  persist.mac[2] = 0xBE;
  persist.mac[3] = 0xEF;
  persist.mac[4] = 0xFE;
  persist.mac[5] = 0xED;
  
  savePersist();

#endif //#ifdef INITIALIZE_PERSIST
 
#ifdef ETHERNET
  //network setup
  
  
  Serial.println("getting ip...");
  
  int result = Dhcp.beginWithDHCP(persist.mac);
 
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
    

    
    Serial.println("connecting...");

    if (client.connect()) {
      Serial.println("connected");
      client.println("GET /search?q=arduino HTTP/1.0");
      client.println();
    } else {
      Serial.println("connection failed");
    }
    
  }
  else{
    Serial.println("unable to acquire ip address...");
  }  //  if(result == 1) Ethernet connection
#endif    
 

  // Temperature Sensor Init
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(ACCESS_CONFIG);
  Wire.send(TP_CONFIG);
  Wire.endTransmission();	
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(START_CONVERT);
  Wire.endTransmission();
  
  //Initialize the temp variables
  currTemp.hi = newKegTemp = persist.kegTemp;
  currTemp.lo=0;


  // Scale sensor init
  Wire.beginTransmission(A2D_ADDR);
  Wire.send(A2D_CONFIG);
  Wire.endTransmission();  
  
  //init LCD
  LCD.init(LCD_ENABLE_PIN,LCD_CONTRAST_PIN,LCD_I2C_ADDR,persist.contrast); 
  showMenu(currState); 
  
  //Timer2 Settings: Timer Prescaler /256,    16000000  / 256 = 625000 HZ =  62500 HZ / 250 =  250 HZ or every 4ms for the overflow timer
  TCCR2B |= (1<<CS22) | (1<<CS21);    // turn on CS22 and CS21 bits, sets prescaler to 256
  TCCR2B &= ~(1<<CS20);    // make sure CS20 bit is off
  // Use normal mode
  TCCR2A &= ~((1<<WGM21) | (1<<WGM20));   // turn off WGM21 and WGM20 bits
  // Use internal clock - external clock not used in Arduino
  ASSR |= (0<<AS2);
  TIMSK2 |= (1<<TOIE2) | (0<<OCIE2A);	  //Timer2 Overflow Interrupt Enable
  TCNT2 = INIT_TIMER_COUNT;   //sets the starting value of the timer
  sei();  //Global interrupt enable
}   //setup()




//Load persistent variable
void loadPersist()
{
     for(tempByte=0; tempByte < sizeof(persist) ; tempByte++) {
        ((byte*)&persist)[tempByte] = EEPROM.read(tempByte);
     }
}

//Save persistent variables
void savePersist()
{
     for(tempByte=0; tempByte < sizeof(persist) ; tempByte++) {
       EEPROM.write(tempByte, ((byte*)&persist)[tempByte]);
     }
}


temperature ctof(temperature input)
{
    temperature converted;
    word hi,lo;
  
    hi = ((word)input.hi) * 18;     
    lo = ((word)input.lo) * 18 + (hi % 10) * 100;
    converted.hi = hi/10 + 32 + lo / 1000;
    converted.lo = (lo % 1000) / 10;
    return converted;
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
