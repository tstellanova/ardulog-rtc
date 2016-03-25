/*
  Ardulog config sketch
  
  Read config.txt file
  Store values in config struct (see ardulog)
*/  

// Convert String to int 
long strtoi (char *a){
  unsigned char i=0; 
  char neg=1;
  char w;
  long intval=0, inttemp;
  i=0;
  if(a[0]=='-') {
    neg=-1;
    i++;
  }  
  do{ 
    w=a[i];
    inttemp=(long) w;
    inttemp=inttemp-48;
    if((inttemp >=0) && (inttemp <=9)){
      intval*=10;
      intval+=inttemp;
    }
    i++;
  } while(a[i]);
  intval*=neg;
  return intval;
}

void GetParam( char *instr, char *buffer )
{
  char oneChar;
  // Find first whitespace (space or tab)
  while ((*instr != '\0') && (*instr != ' ') && (*instr != 0x09) && (*instr >=31))
  {
    instr++;
  }
  // Skip any more whitespace
  while ((*instr == ' ') || (*instr == 0x09))
  {
    instr++;
  }  
  // Extract Parameter
  while ((*instr != '\0') && (*instr != ' ') && (*instr != 0x09) && (*instr >=31))
  {
    oneChar=*instr++;
    *buffer++ = oneChar;
  }
  *buffer = '\0';
}

void read_config_file(void)
{
  char i=0;
  char inVal;
  char configData[81];
  char param[30];
  File CFile;
  #define LINE_LEN 80
  
  if (SD.exists("config.txt")) 
  {
    CFile = SD.open("config.txt");
  
    if (CFile) 
    {   
      // read from the file until there's nothing else in it:
      while (CFile.available()) 
      {
    	inVal = CFile.read();
        if((inVal=='\r') || (inVal=='\n') || (i>LINE_LEN))
        {
          // end of line
          configData[i] = '\0';
          if(i>0)
          { 
            if (!strncmp( configData, "BAUD", 4 ))
            {  
              GetParam(configData, param);
              config.baud = (unsigned long) strtoi(param);
            }            
            if (!strncmp( configData, "FILE", 4 ))
            {  
              GetParam(configData, param);
              strcpy(config.fileprefix, param);
              strcat(config.fileprefix,".");
            }     
            if (!strncmp( configData, "SECONDS", 7 ))
            {  
              GetParam(configData, param);
              config.seconds = (unsigned long) strtoi(param);
            }             
          }
          i=0;          
        }  
        else
        {
          configData[i]=inVal;
          i++;
        }  
      }
    } 
    else 
    {
      // file doesn't exist or cant open it
    }
    // close the file:
    CFile.close();    
  }  
}

void get_new_logfile(void)
{
    // Search for highest value logfile
    unsigned int i,j;
    unsigned int file_ext;
    char filename[20];
    File root;
    file_ext = 0;

    root = SD.open("/");
    root.rewindDirectory(); // Needed because we have already opened config.txt 
  
    while(true) {

        File entry =  root.openNextFile();
        if (!entry) {
           // no more files
           break;
        }

        if (!(entry.isDirectory())) 
        {
           // files have sizes, directories do not
           strcpy(filename, entry.name());
           
           if (!(strncmp(filename, config.fileprefix, strlen(config.fileprefix)))) 
           {
               // It's one of our log files
               // Extract the file extension
               
               for(i=0;i<strlen(filename);i++)
               {
                  if(filename[i]=='.') j=i;
               }
               for(i=0;i<strlen(filename)-j;i++)
               {
                  filename[i]=filename[j+i+1];
                  filename[i+1]='\0';
               } 
               // convert file ext to a number and keep highest. 

               i = strtoi(filename);
               if(i>file_ext) file_ext=i;
           }  

        }
        entry.close();
    }
    root.close();
    
    // Set filename to file_ext+1
    sprintf(config.filename,"%s%03d",config.fileprefix,++file_ext);   

}
