//header file
#include <avr/io.h>
#include <stdio.h>
#include "WProgram.h"

struct temperature {
  int8_t hi;    //signed
  uint8_t lo;   //unsigned
  //add the two together to get real value
  //so -0.06 is stored as hi = -1, & low = 94
};
