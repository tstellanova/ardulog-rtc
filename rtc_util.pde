/*
** Hobbytronics rtc_util
** DS1307/ DS1338 RTC utility functions to Read date/time as string
** and to set date/time from a string
*/

#define RTC_ADDRESS 0x68

byte bcdToDec(byte val)  {
// Convert binary coded decimal to normal decimal numbers
  return ( (val/16*10) + (val%16) );
}

byte decToBcd(byte val){
// Convert normal decimal numbers to binary coded decimal
  return ( (val/10*16) + (val%10) );
}

void readDate(char datetime[]){
  // Read the Date and Time from RTC and set the char array passed in
  
  // Reset the register pointer
  Wire.beginTransmission(RTC_ADDRESS);

  byte zero = 0x00;
  Wire.write(zero);
  Wire.endTransmission();

  Wire.requestFrom(RTC_ADDRESS, 7);

  int second = bcdToDec(Wire.read());
  int minute = bcdToDec(Wire.read());
  int hour = bcdToDec(Wire.read() & 0b111111); //24 hour time
  int weekDay = bcdToDec(Wire.read()); //0-6 -> sunday - Saturday
  int monthDay = bcdToDec(Wire.read());
  int month = bcdToDec(Wire.read());
  int year = 2000 + bcdToDec(Wire.read());

  //print the date EG  DD/MM/YY HH:MM:SS 
  sprintf(datetime,"%4.2d%2.2d%2.2d %2.2d:%2.2d:%2.2d", year, month, monthDay, hour, minute, second);

}

void setDateTime(char datetime[]){
  
  // Takes a char string of the format
  // DD/MM/YY HH:MM:SS
  // and uses this to set the date/time of the RTC

  byte second;
  byte minute;
  byte hour;
  byte weekDay;
  byte monthDay;
  byte month;
  byte year;

  monthDay = datetime[0]-48;
  monthDay = monthDay*10 + datetime[1]-48;   
     
  month = datetime[3]-48;
  month = month*10 + datetime[4]-48; 
     
  year = datetime[6]-48;
  year = year*10 + datetime[7]-48;     
      
  hour = datetime[9]-48;
  hour = hour*10 + datetime[10]-48;   
    
  minute = datetime[12]-48;
  minute = minute*10 + datetime[13]-48; 
    
  second = datetime[15]-48;
  second = second*10 + datetime[16]-48;     
  
  Wire.beginTransmission(RTC_ADDRESS);
  Wire.write(0x00); //stop Oscillator

  Wire.write(decToBcd(second));
  Wire.write(decToBcd(minute));
  Wire.write(decToBcd(hour));
  Wire.write(decToBcd(weekDay));
  Wire.write(decToBcd(monthDay));
  Wire.write(decToBcd(month));
  Wire.write(decToBcd(year));

  Wire.write(0x00); //start 

  Wire.endTransmission();  

}
