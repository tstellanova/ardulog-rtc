/*
  ArduLog RTC 
  Requires Arduino V1.0 and above
  
  Requires RTCLib library available from https://github.com/adafruit/RTClib 

  Written by Hobbytronics Ltd (www.hobbytronics.co.uk)
  This example code is in the public domain.
  
  Simple Data Logging program for the Hobbytronics ArduLog RTC board. Please feel free to amend and adapt.
  
  CONFIGURATION
  -------------
  Configuration is determined by config.txt file on microSD card which should have the following entries
  
  BAUD xxx
  FILE filename_prefix
  SECONDS seconds between data read/write to file
  
  E.g
  
  BAUD 9600
  FILE log
  SECONDS 30
  
  LEDS
  ----
  Green LED lights up to indicate logging has started, extinguishes when logging stopped
  Orange LED indicates data activity
  
  DATE/TIME
  ---------
  Date and time can be set on the RTC using serial connection by sending the following command
  
  date dd/mm/yy hh:mm:ss
  
  History
  -------
  1.00  14 APR 2014   Initial Release

*/


#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include <RTClib.h>

#define SENSOR_COUNT     4 // number of analog pins to log
#define CARD_DETECT_PIN   6 // the card detect pin

RTC_DS1307 RTC;  // define the Real Time Clock object

const int statusLED = 5;       // Green Status LED on pin 5


uint16_t _raw_sensor_data[SENSOR_COUNT] = {};
File logFile;

// Struct to hold config info from config.txt file
struct {
  unsigned long baud;    // baud rate
  char fileprefix[20];   // filename prefix  
  char filename[20];     // filename to log data
  unsigned long seconds; // Force data write to file after x seconds 
} config;

unsigned long currentTime;
unsigned long cloopTime;
char command_string[60];       // string to store command
unsigned char command_index;
char rtc_datetime[17];             // string to store date/time from RTC
unsigned char first_time=1;    // First time through main loop - log data, don't wait for SECONDS

void setup()
{
  int i;
  command_index=0;
  command_string[0]=0x00;
  pinMode(CARD_DETECT_PIN, INPUT);  // Card Detect
  pinMode(statusLED, OUTPUT);  // Status LED
  
  // Default config settings - override with config file "config.txt" if required
  config.baud = 9600;
  config.seconds = 10;  
  strcpy(config.fileprefix, "DATA-");  
  strcpy(config.filename, "DATA-001.CSV");
    
  // Note that even if it's not used as the CS pin, the hardware SS pin 
  // (10 on most Arduino boards, 53 on the Mega) must be left as an output 
  // or the SD library functions will not work. 
  pinMode(10, OUTPUT); 
  
  // set date time callback function so file is opened with correct timestamp
  SdFile::dateTimeCallback(dateTime);
  
  Wire.begin();

  if(!digitalRead(CARD_DETECT_PIN)) {
    // CARD_DETECT_PIN LOW - a card is inserted 
    if (!SD.begin(10)) {
      return;
    }    
    read_config_file();

    if(config.baud > 0)  {
        Serial.begin(config.baud);
    }
    else {
        // Use default baud
        Serial.begin(9600);      
    }
    Serial.println("---- ArduLog OK ----");    
     
    if (openLogFile()) {
      digitalWrite(statusLED, HIGH);  // Logging started 
    }
    
    // write header
    logFile.print("time");

    for (uint8_t i = 0; i < SENSOR_COUNT; i++) {
      logFile.print(",sens");
      logFile.print(i, DEC);    
    }
    
    logFile.println("");
  
  }
  else  {
    // Use default baud
    Serial.begin(9600);    
    Serial.println("No card detected");     
  }
  
  if (!RTC.begin()) {
    Serial.println("RTC failed");
    while(1);
  };  
  
  currentTime = millis();
  cloopTime = currentTime;
}

void handleSerialData()
{
  char inByte = Serial.read();
    command_string[command_index] = inByte;
    command_index++;      
    if(inByte==13)   {      
       if(command_string[0]=='d' && command_string[1]=='a' && command_string[2]=='t' && command_string[3]=='e' && command_index>21)  {
          command_index=0;
          Serial.println(command_string);
          //remove "date " from beginning of string
          for(char i=0;i<17;i++) command_string[i]=command_string[i+5];
          setDateTime(command_string);
          Serial.println("setDateTime");
       }   
    }
    if(command_index>=59) {
      command_index=0;
    }
}

// Main Loop
void loop()
{
  // We can set the date/time by sending
  // date DD/MM/YY HH:MM:SS from a serial connection
  //
  // If you want to log serial data you could use if(digitalRead(CARD_DETECT_PIN)) { .. } here
  // so that setting the date is only possible without a card fitted. With a card fitted
  // then you could log all serial data. 
  if (Serial.available() > 0){
    handleSerialData();
  }

  currentTime = millis();

  // This is the main loop which should read sensors and save data to file every config.seconds
  if ((currentTime >= (cloopTime + (config.seconds*1000))) || (first_time==1))  {
    first_time=0;
    cloopTime = currentTime;  // Updates cloopTime

    // Read current date/time
    readDate(rtc_datetime);

    // read sensor data 
    uint32_t sumData = 0;
    for (uint8_t ia = 0; ia < SENSOR_COUNT; ia++) {
      _raw_sensor_data[ia] = analogRead(ia);
      sumData += _raw_sensor_data[ia];
    }
    
    if (0 == sumData) {
      //don't log all-zeroes sensor data to logFile
      Serial.println("...");
      return;
    }
    
    Serial.print(rtc_datetime);
    Serial.println("");
   
    if(!digitalRead(CARD_DETECT_PIN))  {
      // Print date/time to file
      logFile.print(rtc_datetime);
      for (uint8_t ia = 0; ia < SENSOR_COUNT; ia++) {
        logFile.print(',');   
        logFile.print(_raw_sensor_data[ia]);
      }
      logFile.println("");

      // Flush to logFile
      logFile.flush();
    }  

   }  
}

bool openLogFile()
{
    // Search for next log filename
    getNewLogfile();    
    Serial.print("Opening log file: ");
    Serial.println(config.filename);
    
    logFile = SD.open(config.filename, FILE_WRITE);

    // if the file opened okay, output the name
    if (logFile) {
      return true;
    }  
    else {
      // if the file didn't open, print an error:
      Serial.print("Error opening log file: ");
      Serial.println(config.filename); 
      return false;     
    }  
}  

// call back for file timestamps
void dateTime(uint16_t* date, uint16_t* time) {
  DateTime now = RTC.now();

  // return date using FAT_DATE macro to format fields
  *date = FAT_DATE(now.year(), now.month(), now.day());

  // return time using FAT_TIME macro to format fields
  *time = FAT_TIME(now.hour(), now.minute(), now.second());
}

