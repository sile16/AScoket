




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

  
  if (!persist.useMetric){
    sprintf(myUnit,"US");
    sprintf(tempUnit,"%cF",(char)0xDF);
    sprintf(weightUnit,"lbs");
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
      else if ((prevState == 0) && (buttonPressed == 3))
        LCD.setContrast(++persist.contrast);
      
      displayTemp=currTemp;
      if (!persist.useMetric){
        displayTemp = ctof(currTemp);
      }
        
      buttonPressed = 255;
      //Generate strings for LCD output
      sprintf(buf,"%02d.%02d%s %c  %d%-3c",displayTemp.hi,displayTemp.lo,tempUnit,compIcon,kegPercent,(char)0x25);
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
      sprintf(buf,"Set: %2d%-8s",newKegTemp,tempUnit);
      
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

      if (prevState == 7){
        persist.useMetric = prevUseMetric;
          if (!persist.useMetric)
            sprintf(myUnit,"US");
          else
            sprintf(myUnit,"M");
      }
      else
        prevUseMetric = persist.useMetric; // Gives ability to revert (w/ left arrow from below state)

    
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
        persist.useMetric = !persist.useMetric;
          if (!persist.useMetric)
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
    
      if (prevState == 9)
        persist.contrast = prevContrast;
      else
        prevContrast = persist.contrast; // Gives ability to revert (w/ left arrow from below state)
    
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
        LCD.setContrast(--persist.contrast);
      else if (buttonPressed == 0)
        LCD.setContrast(++persist.contrast);
      
      buttonPressed = 255;  
      sprintf(buf,"Set: %-10d",(int)persist.contrast);
    
      LCD.setCursor(0,0);
      LCD.print(buf);
      LCD.setCursor(0,1);
      LCD.print("X=Back  Save=O");
      break;

    /************************
     * SET TEMP GAP         *
     ************************/
    case 10:
    
      if(prevState == 11)
        persist.kegTempGap = prevKegTempGap;
      else
        prevKegTempGap = persist.kegTempGap; // Gives ability to revert (w/ left arrow from below state)
    
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

      if ((buttonPressed == 2) && (persist.kegTempGap > 0))
        persist.kegTempGap = persist.kegTempGap--;
      else if ((buttonPressed == 0) && (persist.kegTempGap <10))
        persist.kegTempGap = persist.kegTempGap++;

      buttonPressed = 255;  
      sprintf(buf,"Temp Gap: %2d%s ",(int)persist.kegTempGap,tempUnit);
    
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
