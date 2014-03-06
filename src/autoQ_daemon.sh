#!/bin/bash

##
## Scan through each file in the autoQ master file
## list and determine which (if any) directories
## contain simulations which need a restart
##
##
##

# source functions and config
source /home/alex/bin/autoQ/autoQ_functions.sh

# create any log files oif they're mssing

# cronlog file
if [ ! -a "$AUTOQ_CRONLOG" ]
    then
    touch $AUTOQ_CRONLOG
fi

# statuslog file
if [ ! -a "$AUTOQ_STATUSLOG" ]
    then
    touch $AUTOQ_STATUSLOG
fi

# error log file
if [ ! -a "$AUTOQ_LOGFILE" ]
    then 
    touch $AUTOQ_LOGFILE
fi
 


# if there are lines in the master file...
if [ -s "$AUTOQ_REFFILE" ]
    then
    
    # for each line see if a restart is required
    # and if it is fire off the restart


    

    echo "-------------------------------------" >> $AUTOQ_CRONLOG
    echo "  New sweep of master file begining  " >> $AUTOQ_CRONLOG
    echo "-------------------------------------" >> $AUTOQ_CRONLOG

    while read -r line
      do      

      # is string null?
      if [ -z "$line" ]
	  then
	  echo `date` ": line is empty - skipping" >> $AUTOQ_CRONLOG	  
      elif [ ! -d "$line" ]
	  then
	  echo `date` ": $line is not a directory - skipping" >> $AUTOQ_CRONLOG	  	  
      else
      
	  cd $line
	  
	  echo `date` ": In ${line} checking for restart" >> $AUTOQ_CRONLOG
	  
	  launch_restart $GMX_LOGFILE $RESTART_SCRIPT >> $AUTOQ_CRONLOG
      fi
      
    done < $AUTOQ_REFFILE
fi

