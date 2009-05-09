#ifndef LCD_I2C_h
#define LCD_I2C_h
//#define DEBUG

#define RS_LOW 0x00
#define RS_HIGH 0x10
#define LCD_POWER 0x80
#define LCD_BKL_POWER 0x40
#define LCD_RW 0x20
#define LCD_RS 0x10
#define LCD_CONTRAST  170


#include <inttypes.h>
#include "Print.h"

class LCD_I2C : public Print {
public:
  LCD_I2C();
  void init(uint8_t enable_pin, uint8_t contrast_pin, uint8_t i2c_addr, uint8_t contrast);
  void clear();
  void home();
  void setCursor(uint8_t, uint8_t); 
  virtual void write(uint8_t);
  void command(uint8_t);
  void setBacklight(uint8_t value);
  void setContrast(uint8_t value);
  uint8_t getBacklight();
  
private:
  void send(uint8_t, uint8_t);
  void send_nibble(uint8_t value);
 
  
  uint8_t _enable_pin; // activated by a HIGH pulse.
  uint8_t _contrast_pin;
  uint8_t _i2c_addr;
  uint8_t _pos;
  uint8_t _config;
};

extern LCD_I2C LCD;

#endif
