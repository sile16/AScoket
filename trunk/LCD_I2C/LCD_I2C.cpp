#include "LCD_I2C.h"

#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <Wire.h>
#include "WProgram.h"

// When the display powers up, it is configured as follows:
//
// 1. Display clear
// 2. Function set: 
//    DL = 1; 8-bit interface data 
//    N = 0; 1-line display 
//    F = 0; 5x8 dot character font 
// 3. Display on/off control: 
//    D = 0; Display off 
//    C = 0; Cursor off 
//    B = 0; Blinking off 
// 4. Entry mode set: 
//    I/D = 1; Increment by 1 
//    S = 0; No shift 
//
// Note, however, that resetting the Arduino doesn't reset the LCD, so we
// can't assume that its in that state when a sketch starts (and the
// LiquidCrystal constructor is called).

LCD_I2C::LCD_I2C()
{
  _pos=0;
  _config= LCD_POWER | LCD_BKL_POWER;  //Turns on logic power and backlight.

}

void LCD_I2C::init(uint8_t enable, uint8_t contrast, uint8_t i2c_addr) 
{
  //Assign variable to local vars
  _contrast_pin = contrast;
  _enable_pin = enable;
  _i2c_addr = i2c_addr;

  //Setup arudino pins for output
  pinMode(_enable_pin, OUTPUT);
  pinMode(_contrast_pin, OUTPUT);
  digitalWrite(_enable_pin, LOW);
  analogWrite(_contrast_pin,LCD_CONTRAST);

/*

  //Turn off LCD
  Wire.beginTransmission(_i2c_addr); 
  Wire.send(0x00);
  Wire.endTransmission();
  delay(1000);

  //Turn on LCD
  Wire.beginTransmission(_i2c_addr); 
  Wire.send(_config);
  Wire.endTransmission();
  delay(1000);
*/

  //Start init sequence (Black magic begins...)
//  send_nibble(0x03);
//  delay(5);
//  send_nibble(0x03);
//  delayMicroseconds(100);
//  send_nibble(0x03);
//  delay(5);

  // needed by the LCDs controller
  //this being 2 sets up 4-bit mode.
//  send_nibble(0x02);
  send_nibble(0x02);
  
  
 
  command(0x28);  // function set: 4 bits, 1 line, 5x8 dots
  delayMicroseconds(60);
  command(0x0C);  // display control: turn display on, cursor off, no blinking
  delayMicroseconds(60);
  clear(); 
  delay(3);
  command(0x06);  // entry mode set: increment automatically, display shift, right shift
  delay(1);
  
  
}

void LCD_I2C::clear()
{
  command(0x01);  // clear display, set cursor position to zero
  _pos=0;
  delay(3);
}

void LCD_I2C::home()
{
  command(0x02);  // set cursor position to zero
  _pos=0;
  delay(3);
}

void LCD_I2C::setCursor(int col, int row)
{
#ifdef DEBUG
    Serial.println("");    
#else     
  int row_offsets[] = { 0x00, 0x40, 0x14, 0x54 };
 
  _pos = col;
  command(0x80 | (col + row_offsets[row]));
  delayMicroseconds(100);
#endif  
}

void LCD_I2C::command(uint8_t value) {
  send(value, RS_LOW);
}

void LCD_I2C::write(uint8_t value) {
  if( _pos == 16 ) {
	command(0xc0);  //move cursor to 0x0 address space
//	delayMicroseconds(2000);
  }
 
  send(value, RS_HIGH);
  _pos++;
 
}

void LCD_I2C::send(uint8_t value, uint8_t mode) {

#ifdef DEBUG
    Serial.print(value, BYTE); 
#else     
	send_nibble((value >> 4) | mode);
	send_nibble((value & 0x0f) | mode);
	

#endif
    


}

void LCD_I2C::send_nibble(uint8_t value) {
    
   
	Wire.beginTransmission(_i2c_addr); 
	Wire.send(value | _config);
	Wire.endTransmission();
	delayMicroseconds(10);

//	digitalWrite(_enable_pin, LOW);
//	delayMicroseconds(1);
	digitalWrite(_enable_pin, HIGH);
	delayMicroseconds(1);
	digitalWrite(_enable_pin, LOW);
	delayMicroseconds(1);

}

void LCD_I2C::setBacklight(uint8_t value) {

   if(value)
   {
   		_config= _config | LCD_BKL_POWER;
   }
   else
   {
       _config = _config & ~LCD_BKL_POWER;
   }
   Wire.beginTransmission(_i2c_addr); 
   Wire.send(_config);
   Wire.endTransmission();
}

LCD_I2C LCD = LCD_I2C();
