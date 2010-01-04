/************************************
 * void loop()              
 *
 * Called repeatedly, main program loop
 *
 ************************************/
void   loop()                     // run over and over again
{

 
#ifdef ETHERNET
kegger_net();
#endif   
 
//**********************************************************************
//*******  Timer 1
//**********************************************************************

  if(timer_status & 0x01 ) //every 4 ms
  {
    timer_status &= ~0x01; 
    

    
    //  Read in current button values into tempByte
    tempByte =0;
    if( digitalRead(UP_BUTTON_PIN)){
      tempByte = 1;
    }
    if( digitalRead(DOWN_BUTTON_PIN)){
      tempByte += 2;
    }
    if( digitalRead(LEFT_BUTTON_PIN)){
      tempByte += 4;
    }
    if( digitalRead(RIGHT_BUTTON_PIN)){
      tempByte +=8;
    }
   
    //if the buttons have changed we need to set a flag so we know we aren't stable yet and update the previous transient value.
    if( tempByte != prevButtonTransientState) {
       currButtonState |= BUTTONS_CHANGED_FLAG;     //change the current button state to indicate we are not settled yet using the following bit  0x00010000 as a flag.
       prevButtonTransientState=tempByte;   //
    }
    
  } //if(timer_status & 0x01 ) //every 4 ms
    
  
  
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

          if(currButtonState == 12) //both left & right buttons reset the LCD
            LCD.init(LCD_ENABLE_PIN,LCD_CONTRAST_PIN,LCD_I2C_ADDR,persist.contrast); 
          
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


   /***************************
   * Flash Status Lights
   ***************************/
    tempByte = ! digitalRead(LED_STATUS2_PIN);
    
    digitalWrite(LED_STATUS2_PIN, ! digitalRead(LED_STATUS2_PIN));
    digitalWrite(LED_PIN, ! digitalRead(LED_PIN));
 //   LCD.setBacklight(tempByte);


   /***************************
   * Read weight & temp
   ***************************/
  #ifdef  SIMULATE
  if(compPower) {   //simulate temp increasing by .1 degrees Celcius ever 1 second,  10 seconds for 1 degree
    currTemp.lo -= 10;
    if(currTemp.lo > 99) {
      currTemp.lo = 90;
      currTemp.hi--;
    }
  }
  else {
    currTemp.lo += 10;
    if(currTemp.lo > 99) {
      currTemp.lo=0;
      currTemp.hi++;
    }
    
  } //end if(compPower)
  
  if(scale_volts <=  persist.kegTareEmpty) {
    scale_volts = persist.kegTareFull; //10,000 is about 80lbs
  }
  else {
    scale_volts = scale_volts - 100;
  }
  
#else  // not simulating, read actual temp from sensor board
  //Read in current temperature
  tempByte = READ_TP;
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(tempByte);
  Wire.endTransmission();
  
  Wire.requestFrom(TP1_ADDR,2);
  currTemp.hi = Wire.receive();  //sent as a signed byte
  
  //add this unsigned value to your hi value to get real temp.
  //only top 4 bits are used
  //i.e.  .0625 degrees = 0001 0000,  .5 degress = 1000 0000
  //To use, first we shift right 4 bits, then each bit represents .0625 degrees so, normally we would just multiply by .0625
  // we want to display .lo as the number to the right of the decimal with 2 digits, so .0625 degress would be displayed 62
  //  so instead of multiplying by 0.0625 we just need to multipy by 6.25, 
  //but we can't use floating point.  So we cast as a word and multiply by 625 and then divide by 100 since 625/100 = 6.25
  currTemp.lo = ((word)(Wire.receive() >> 4) * 625) / 100;
   
  
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

#endif
  
   /***************************
   * FlowMeter Tracking
   ***************************/
   if(isDrinking) {
     flowMeterDrink+=flowMeterCount;
     if(flowMeterCount < 1) {
       isDrinking = false;
       persist.kegFlowCount += flowMeterDrink/10;  //have to divide by 10 to fit a whole keg into a word variable
       savePersist();
       lastDrink = flowMeterDrink;
       
       Serial.print("I just poured a drink! : ");
       Serial.println(flowMeterDrink);
      
     }
   }
   else if (flowMeterCount  > 0) {
       flowMeterDrink = flowMeterCount;
       isDrinking = true;
   }
   flowMeterCount=0;
   
   /***************************
   * Compressor On/Off Logic , Check compressor once a minute to enforce a minimum of a 1 minute on/off time.
   ***************************/
if(timer_status & 0x08 ) { //1 minute timer
  if(!compPower){
    // If the compressor is off, kick it on when currTemp is over the gap. Its kegTempGap-1 to accomodate for decimals
    // Else if the compressor is on, leave it on until we're ** 2 degrees ** under the desired temp (kegTemp)
    if(currTemp.hi > (persist.kegTemp + persist.kegTempGap-1))
    {
      compPower = true; 
      timer_status &= ~0x08;  //reset timer so we don't check compressor for 1 minute
    }
  }
  else if(compPower){
    if(currTemp.hi < persist.kegTemp-persist.kegTempGap) {
      compPower = false;
      timer_status &= ~0x08; //reset timer so we don't check compressor for 1 minute
    }
  }
  digitalWrite(COMPRESSOR_PIN,!compPower);
}
   
   
   
   /***************************
   * Ethernet
   ***************************/

#ifdef ETHERNET      
   if(networkState == SERVER_CONNECTING || networkState == SERVER_RECEIVE)
   {
     Serial.print("Sock Status: ");
     Serial.print(as.status(),DEC);
   }
    
  if(networkState == NET_IDLE)
  {
    if(!ipAcquired) {    //we don't have an IP lets retry DHCP
      networkState = NET_DHCP;
    }
    else if(lastDrink) {  //we have a drink to upload
      networkState = SERVER_CONNECT;
    }
    else if(netFailCount || timer_status & 0x10)  //we want to retry after 1 second on a failure or if it time update temp & voltage.
    {
      networkState = DNS_RESOLVE;
    }
  
    if(netFailCount > 15) {  //15 consecutive network failures.  Lets go back to DHCP
      networkState = NET_DHCP;
      netFailCount = 0;
    }
  }
#endif
  
   /***************************
   * LCD Menu Display
   ***************************/
  //update display every second.
  showMenu(currState);
  
  //If we are in the saved state move into main menu after a 1 second delay.
  if(currState == 4) {
    currState = 0;
  }
  
  
 }//endif 1 sec timer
 
 //**********************************************************************
//*******  Timer 4
//**********************************************************************

//  if(timer_status & 0x08 ) //every Minute
//  {
//    timer_status &= ~0x08;
    

    

    
    
//  } // if(timer_status & 0x08 ) //every Minute
  
//**********************************************************************
//*******  Timer 5
//**********************************************************************

 // if(timer_status & 0x10 ) //every 4 Minutes
///  {
 //   timer_status &= ~0x10;
    // This timer is handled inside of the 1 second timer
    

    
    
 // } //if(timer_status & 0x10 ) //every 4 Minutes

} //loop()
