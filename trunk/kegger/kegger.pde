#include <Client.h>

#include <LCD_I2C.h>
#include <stdio.h>
#include <Wire.h>
#include <EEPROM.h>

#include <avr/interrupt.h>
#include <avr/io.h>


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


/************************
 * BEGIN: Tyler Vars    *
 ************************/
// stateMenu is an array of finite state machine ID actions per button pressed
//   -Each row is the state, each col is a ptr to state based on button pressed
//    Ex: stateMenu[0] is the idle state
//          stateMenu[0][0] is state identifier (0)
//          stateMenu[0][1] is ptr to state when UP is pressed
//          stateMenu[0][2] is ptr to state when RIGHT is pressed
//          stateMenu[0][3] is ptr to state when DOWN is pressed
//    NOTE: stateMenu[0][4] is ptr to state when LEFT is pressed

static int stateMenu[][4] = {{3,0,1,0},  //Screen 0: Idle
                              {0,2,6,0},  //Screen 1: Set Temp
                              {2,4,2,1},  //Screen 2:   Set Temp 2
                              {6,5,0,0},  //Screen 3: About
                              {0,0,0,0},  //Screen 4: Saved
                              {5,5,5,3},  //Screen 5:   About 2
                              {1,7,3,0},  //Screen 6: Set Unit
                              {7,4,7,6},  //Screen 7:   Set Unit 2
                            };
static int currState = 0;
static int prevState = currState;
static boolean compPower = true;

static int temp_hi = 0;
static int temp_lo = 0;
static int newKegTemp = 43;
static int kegPercent = 69;
static int kegWt = 148;
static int kegPints = 201;
static int buttonPressed = 255;

static byte prevButtonTransientState = 0;
static byte currButtonState=0;    //Current button state plus bit 4 used to keep track of transient changes. BUTTONS_CHANGED_FLAG

// persistent variable to store between power outage
static struct{
   byte mac[6];
   byte ip[4];
   byte gateway[4];
  
   byte kegTemp;
   boolean useMetric;
   
   byte contrast;
} persist;




volatile static byte timer_status = 0;
volatile static byte timer_count = 0;
static byte tempByte;

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
  
  //network setup
  persist.mac[0] = 0xDE; 
  persist.mac[1] = 0xAD;
  persist.mac[2] = 0xBE;
  persist.mac[3] = 0xEF;
  persist.mac[4] = 0xFE;
  persist.mac[5] = 0xED;
 
  persist.ip[0] = 192;
  persist.ip[1] = 168;
  persist.ip[2] = 26;
  persist.ip[3] = 10;
 
  persist.gateway[0] = 192;
  persist.gateway[1] = 168;
  persist.gateway[2] = 26;
  persist.gateway[3] = 1;
 
  Serial.begin(115200);                    // connect to the serial port
  Serial.println("Kegger Begin");
  Wire.begin();

  // Temperature Sensor Init
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(ACCESS_CONFIG);
  Wire.send(TP_CONFIG);
  Wire.endTransmission();	
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(START_CONVERT);
  Wire.endTransmission();

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



void   loop()                     // run over and over again
{
  byte curr_temp_hi;
  byte curr_temp_lo;
  word scale_volts;

 
//**********************************************************************
//*******  Timer 1
//**********************************************************************

  if(timer_status & 0x01 ) //every 4 ms
  {
    timer_status &= ~0x01; 
    
    //  Read in current button values into tempByte
    tempByte =0;
    if( !digitalRead(UP_BUTTON_PIN)){
      tempByte = 1;
    }
    if( !digitalRead(DOWN_BUTTON_PIN)){
      tempByte += 2;
    }
    if( !digitalRead(LEFT_BUTTON_PIN)){
      tempByte += 4;
    }
    if( !digitalRead(RIGHT_BUTTON_PIN)){
      tempByte +=8;
    }
   
    //if the buttons have changed we need to set a flag so we know we aren't stable yet and update the previous transient value.
    if( tempByte != prevButtonTransientState) {
       currButtonState |= BUTTONS_CHANGED_FLAG;     //change the current button state to indicate we are not settled yet using the following bit  0x00010000 as a flag.
       prevButtonTransientState=tempByte;   //
    }
    
  } //if(timer_status & 0x01 )   5ms Timer
  
//**********************************************************************
//*******  Timer 2
//**********************************************************************

  if(timer_status & 0x02 ) //every 20 ms
  {
    timer_status &= ~0x02;
    
    if(! (currButtonState & BUTTONS_CHANGED_FLAG )) // This means the value was constant since last time we were here
    {
      if(currButtonState != prevButtonTransientState) { //This means that we do indeed have a new state and need to process this button press
        currButtonState = prevButtonTransientState;
        
        //Map physical button presses to state machine, if mutliple buttones are pressed to first one found gets executed.
        if( currButtonState & 1) {
          Serial.println("Up Button Press");
          buttonPressed = 0;
        }
        else if( currButtonState & 2) {
          Serial.println("Down Button Press");
          buttonPressed = 2;
        }
        else if( currButtonState & 4){
          Serial.println("Cancel Button Press");
          buttonPressed = 3;
        }
        else if( currButtonState & 8){
          Serial.println("Select Button Press");
          buttonPressed = 1;
        }
        
        if(currButtonState && buttonPressed < 4) {  //means there is at least one button pressed
          prevState = currState;
          currState = stateMenu[currState][buttonPressed];
          showMenu(currState);
          //Serial.print("Moved to state: ");
          //Serial.println(currState,DEC);
          
        }
        
      } //if(currButtonState != prevButtonTransientState)
    
    } //if(! (currButtonState & BUTTONS_CHANGED_FLAG ))
    
    //Clear the transient change flag
    currButtonState &= ~BUTTONS_CHANGED_FLAG;  //clears bit 4
    
  } //if(timer_status & 0x02)   20ms Timer
  
  
//**********************************************************************
//*******  Timer 3
//**********************************************************************

  if(timer_status & 0x04 ) //every 1 s
  {
    timer_status &= ~0x04;
    
 
    
    tempByte = ! digitalRead(LED_STATUS2_PIN);
    
    digitalWrite(LED_STATUS2_PIN, ! digitalRead(LED_STATUS2_PIN));
    digitalWrite(LED_PIN, ! digitalRead(LED_PIN));
 //   LCD.setBacklight(tempByte);
  
  //Read in current temperature
  tempByte = READ_TP;
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(tempByte);
  Wire.endTransmission();
  
  Wire.requestFrom(TP1_ADDR,2);
  curr_temp_hi = Wire.receive();
  curr_temp_lo = ((word)(Wire.receive() >> 4) * 625) / 100;

//  Serial.print("   Temp: ");
//  Serial.print(curr_temp_hi,DEC);
//  Serial.print(".");
//  Serial.print(curr_temp_lo,DEC);
  
  // Read scale voltage value from a2d
  Wire.requestFrom(A2D_ADDR,2);
  scale_volts = (word)Wire.receive() << 8;
  scale_volts += Wire.receive();
  
  // Setup for next read
  Wire.beginTransmission(A2D_ADDR);
  Wire.send(A2D_CONFIG);
  Wire.endTransmission();
  
// Serial.print("  Scale: ");
// Serial.println(scale_volts,DEC);
  //count1++;
  
 }//endif 1 sec timer

} //loop()




/************************************
 * void showMenu(int)              
 *
 * Pass (int) state and this function outputs
 * strings to the LCD controller based on that state
 *
 ************************************/
void showMenu(int state){
  
  char buf[32];  //Buffer for LCD string output
  char buf2[] = "X=Back   Set=O";  //Hoping it cuts off a little on memory??
  char compIcon = ' ';               //Compressor Icon either on (*) or off ( )
  char tempUnit[8];
  char weightUnit[8];
  char myUnit[8];

  
  if (!persist.useMetric){
    sprintf(myUnit,"US");
    sprintf(tempUnit,"%cF",(char)0xDF);
    sprintf(weightUnit,"kg");
  }
  else {
    sprintf(myUnit,"M");
    sprintf(tempUnit,"%cC",(char)0xDF);
    sprintf(weightUnit,"kg");
  }


  switch(state) {

    
    /********************
     * IDLE SCREEN      *
     ********************/
    case 0:
      if (compPower)
        compIcon = '*';
      else
        compIcon = ' ';
        
      if (buttonPressed == 1)
        LCD.setContrast(--persist.contrast);
      else if (buttonPressed == 3)
        LCD.setContrast(++persist.contrast);
      
      //Generate strings for LCD output
      sprintf(buf,"%3d%s  %c  %d%-3c",persist.kegTemp,tempUnit,compIcon,kegPercent,(char)0x25);
      LCD.setCursor(0,0);
      LCD.print(buf);

      sprintf(buf,"%3d%s %4dcups",kegWt,weightUnit,kegPints);
      LCD.setCursor(0,1);
      LCD.print(buf);
      
      //delay(500);
      break;

    /********************
     * SET TEMP         *
     ********************/
    case 1:
      sprintf(buf,"SET TEMP [%2d%s]",persist.kegTemp,tempUnit);
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /********************
     * SET TEMP 2       *
     ********************/
    case 2:
      // If up pressed, raise new temp var
      // Else if down button then lower temp var
      if ((prevState == 2) && (buttonPressed == 0))
        newKegTemp++;
      else if ((prevState == 2) && (buttonPressed == 2))
        newKegTemp--;
      buttonPressed = 255;  
      sprintf(buf,"Set: %2d%8s",newKegTemp,tempUnit);
      
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;
      
    /********************
     * ABOUT SCREEN     *
     ********************/
    case 3:
      LCD.setCursor(0,0);
      LCD.print("About           ");
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;
      
    /********************
     * SAVED SCREEN     *
     ********************/
    case 4:
      LCD.setCursor(0,0);
      LCD.print("Saved           ");
      LCD.setCursor(0,1);
      LCD.print("                ");
      
      if (prevState == 2) persist.kegTemp = newKegTemp;
      
      savePersist();
      
      delay(3000);
      currState = 0;
      prevState = 0;
      showMenu(currState);
      
      break;
      
    /********************
     * ABOUT 2          *
     ********************/
    case 5:
      LCD.setCursor(0,0);
      LCD.print("Kegerator v1.0");
      LCD.setCursor(0,1);
      LCD.print("... Enjoy! ...");
      break;
      
    /********************
     * SET UNIT         *
     ********************/
    case 6:
    
      sprintf(buf,"SET UNIT [%2s] ",myUnit);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /********************
     * SET UNIT 2       *
     ********************/
    case 7:
    
      if ((prevState == 7) && ((buttonPressed == 0) || (buttonPressed == 2)))
        persist.useMetric = !persist.useMetric;
      

      buttonPressed = 255;  
      sprintf(buf,"Set: %-15s",myUnit);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

  }  //switch

    // Right-side arrows  
    LCD.setCursor(15,0);
    LCD.print("^");
    LCD.setCursor(15,1);
    LCD.print("v");

  
}//showMenu()


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

void ctof(byte hi, byte lo)
{
    temp_hi = (word)hi * 18;     
     
    temp_lo = (word)lo * 18 + (temp_hi % 10) * 100;
    temp_hi = temp_hi/10 + 32 + temp_lo / 1000;
    temp_lo = (temp_lo % 1000) / 10; 
}
 

