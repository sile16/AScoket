




/************************************
 * void showMenu(int)              
 *
 * Pass (int) state and this function outputs
 * strings to the LCD controller based on that state
 *
 ************************************/
void showMenu(int state){
  
  char buf[32];  //Buffer for LCD string output
  char buf2[] = "X=Back   Set=O ";   //Hoping it cuts off a little on memory??
  char compIcon = ' ';               //Compressor Icon either on (*) or off ( )
  char tempUnit[8];
  char weightUnit[8];
  char myUnit[8];
  temperature displayTemp;
  word displayWt;
  byte displayWtPercent;
  byte displayWtPints;
  
  static word newValue;

  displayTemp=currTemp;  //displayTemp is Metric by default
  //Changes by Matt, don't use floating point numbers......  they use up a ton of code space.
  //displayWt=(((float)scale_volts*.009696)-14)*.45359237; //displayWt is converted to US then Metric here
  
  displayWtPercent=(100*((unsigned long)scale_volts - persist.kegTareEmpty))/(persist.kegTareFull-persist.kegTareEmpty);
  displayWtPints=((word)displayWtPercent*124)/100;
  displayWt=displayWtPercent/2+14;   //50kg of beer plus 14kg for the keg container
    
  if (!persist.useMetric){
    sprintf(myUnit,"US");
    sprintf(tempUnit,"%cF",(char)0xDF);
    sprintf(weightUnit,"lb");
    displayTemp = ctof(currTemp);
    displayWt = (displayWt*22)/10;
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
        
      if ((prevState == 0) && (buttonPressed == 1))
        LCD.setContrast(--persist.contrast);
      else if ((prevState == 0) && (buttonPressed == 3)) {
        LCD.setContrast(++persist.contrast);
      }
      
      buttonPressed = 255;
      //Generate strings for LCD output
      LCD.setCursor(0,0);
      
      
      if(displayTemp.hi < 0 && displayTemp.lo != 0) {
        //if we are negative we have to invert the lo side
        displayTemp.lo = 100 - displayTemp.lo;
        displayTemp.hi++; 
        if(displayTemp.hi == 0)
        LCD.print("-");  
      }
      
      sprintf(buf,"%02d.%02d%s %c %d%-3c ",displayTemp.hi,displayTemp.lo,tempUnit,compIcon,displayWtPercent,(char)0x25);
      LCD.print(buf);

      sprintf(buf,"%d%s %dpints ",displayWt,weightUnit,displayWtPints);
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
        (int)newValue++;
      else if ((prevState == 2) && (buttonPressed == 2))
        (int)newValue--;
      buttonPressed = 255;  
      sprintf(buf,"Set: %2d%-8s",(int)newValue,tempUnit);
      
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
      
      if (prevState == 2) persist.kegTemp = newValue;
      if (prevState == 15) persist.kegTareEmpty = scale_volts;
      if (prevState == 7)  persist.useMetric = newValue;
      if (prevState == 9)  persist.contrast = newValue;
      if (prevState == 11)  persist.kegTempGap = newValue;
      if (prevState == 17) persist.kegTareEmpty = newValue;
      if (prevState == 13) persist.kegTareFull = newValue;
      
      if (prevState == 14) {
        persist.kegTareFull = scale_volts;
        persist.kegFlowCount = 0;
        kegStatus |= 0x80;  //means there was a new keg.
      }
      
      kegStatus |= 0x40;  //means configuration was updated
      
      savePersist();

      break;
      
    /********************
     * ABOUT 2          *
     ********************/
    case 5:
      LCD.setCursor(0,0);
      LCD.print("Kegerator v1.1");
      LCD.setCursor(0,1);
      LCD.print("... Enjoy! ...");
      break;
      
    /********************
     * SET UNIT         *
     ********************/
    case 6:
    
    
      newValue = persist.useMetric;
      if (!persist.useMetric)
         sprintf(myUnit,"US");
      else
         sprintf(myUnit,"M");
    
      sprintf(buf,"SET UNIT [%2s]  ",myUnit);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /********************
     * SET UNIT 2       *
     ********************/
    case 7:
    
      if ((prevState == 7) && ((buttonPressed == 0) || (buttonPressed == 2))){
        newValue = !newValue;
          if (!newValue)
            sprintf(myUnit,"US");
          else
            sprintf(myUnit,"M");
      }
      
      buttonPressed = 255;
      
      if(!strcmp(myUnit,"M"))
        sprintf(myUnit,"Metric");
        
      sprintf(buf,"Set: %-10s",myUnit);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;

    /************************
     * SET CONTRAST         *
     ************************/
    case 8:
    
      newValue = persist.contrast; // Gives ability to revert (w/ left arrow from below state)
    
      sprintf(buf,"CONTRAST [%2d]  ",(int)persist.contrast);
      
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /************************
     * SET CONTRAST 2       *
     ************************/
    case 9:
    
      if (buttonPressed == 2)
        LCD.setContrast(--newValue);
      else if (buttonPressed == 0)
        LCD.setContrast(++newValue);
      
      buttonPressed = 255;  
      sprintf(buf,"Set: %-10d",(int)newValue);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;

    /************************
     * SET TEMP GAP         *
     ************************/
    case 10:
    
      newValue = persist.kegTempGap; // Gives ability to revert (w/ left arrow from below state)
    
      sprintf(buf,"TEMP GAP [%2d%s]",(int)persist.kegTempGap,tempUnit);
      
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /************************
     * SET TEMP GAP 2       *
     ************************/
    case 11:

      if ((buttonPressed == 2) && (newValue > 1))
        newValue--;
      else if ((buttonPressed == 0) && (newValue <10))
        newValue++;

      buttonPressed = 255;  
      sprintf(buf,"Temp Gap: %2d%s ",(int)newValue,tempUnit);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;

    /************************
     * KEG RESET            *
     ************************/
    case 12:
    
      newValue = persist.kegTareFull; // Gives ability to revert (w/ left arrow from below state)
    
      sprintf(buf,"KEG FULL      ");
      
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /************************
     * KEG RESET 2          *
     ************************/
    case 13:

      if ((buttonPressed == 2) )
        newValue -= 25;
      else if ((buttonPressed == 0))
        newValue += 25;

      buttonPressed = 255;  
      sprintf(buf,"Full:  %7d ",(int)newValue);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;
      
     /************************
     * New Keg?              *
     ************************/
    case 14:
         LCD.setCursor(0,0);
         LCD.print("New Keg?       ");
         LCD.setCursor(0,1);
         LCD.print("X=Back   Yes=O");
         break;
    
      
     /************************
     * Tare Scale            *
     ************************/
     case 15:
         LCD.setCursor(0,0);
         LCD.print("Tare Scale     ");
         LCD.setCursor(0,1);
         LCD.print("X=Back   Yes=O");
         break;
       
    /************************
     * SCALE Empty Adjust            *
     ************************/
    case 16:
    
      newValue = persist.kegTareEmpty; // Gives ability to revert (w/ left arrow from below state)
    
      sprintf(buf,"KEG Empty      ");
      
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print(buf2);
      break;

    /************************
     * Scale Empty 2          *
     ************************/
    case 17:

      if ((buttonPressed == 2) )
        newValue -= 25;
      else if ((buttonPressed == 0))
        newValue += 25;

      buttonPressed = 255;  
      sprintf(buf,"Empty:  %7d",(int)newValue);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;

  }  //switch

    // Right-side arrows  
    LCD.setCursor(15,0);
    LCD.print("^");
    LCD.setCursor(15,1);
    LCD.print("v");

  
}//showMenu()
