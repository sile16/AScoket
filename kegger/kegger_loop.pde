/************************************
 * void loop()              
 *
 * Called repeatedly, main program loop
 *
 ************************************/
void   loop()                     // run over and over again
{
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

#ifdef  SIMULATE_TEMPERATURE
  if(compPower) {   //simulate temp increasing by .1 degrees Celcius ever 1 second,  10 seconds for 1 degree
    currTemp.lo -= 0x10;
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
    
  }
#else  // not simulating, read actual temp from sensor board
  //Read in current temperature
  tempByte = READ_TP;
  Wire.beginTransmission(TP1_ADDR);
  Wire.send(tempByte);
  Wire.endTransmission();
  
  Wire.requestFrom(TP1_ADDR,2);
  currTemp.hi = Wire.receive();
  currTemp.lo = ((word)(Wire.receive() >> 4) * 625) / 100;

#endif
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
  
  
  
  /***************************
   * Compressor On/Off Logic
   ***************************/
  if(!compPower){
    // If the compressor is off, kick it on when currTemp is over the gap. Its kegTempGap-1 to accomodate for decimals
    // Else if the compressor is on, leave it on until we're ** 2 degrees ** under the desired temp (kegTemp)
    if(currTemp.hi > (persist.kegTemp + persist.kegTempGap-1))
      compPower = true; 
  }
  else if(compPower){
    if(currTemp.hi <= persist.kegTemp-3)
      compPower = false;
  }

  
    
  showMenu(currState);
  
 }//endif 1 sec timer

} //loop()
