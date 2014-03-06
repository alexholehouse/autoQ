#!/bin/bash
##
## autoQ : automatic restart of jobs for clusters
##
## version 0.1 - alpha testing
##
## Alex Holehouse, March 2014
##
## What is this file?
##   This file is the functions file used by the autoQ program. It probably shouldn't
##   be used in isolation as may of the functions here only make sense in their
##   full program context. An important caveat for all functions - autoQ operates from
##   a submission directory-centeric point of view. That is to say, all these functions
##   expect to be called *from* the directory in which submission has occured and
##   output has been generated.
##

#GOLBAL CONFIGS (move to .config file)

AUTOQ_V="v0.1"

source /home/alex/bin/autoQ/autoQ.config

########################################################################
#
submit_job() {
    # Function to submit a job within the autoQ
    # framework, which will genertae an autoq_idfile
    # which can be used to autoque to determine job
    # completion.
    #
    # Input
    # ARG1 : Should be the name of the PBS submission
    #        script to be used. NOTE this function
    #        assumes we are inside the in/out directory
    #        for the job
    
    if [ "$#" -ne 2 ]; then
	errorlog_header
	echo "ERROR: submit_job was passed an incorrect number of parameters" >> $AUTOQ_LOGFILE
	echo "ERROR"
	return
    fi

    SUBMISSION_SCRIPT=$1
    JOBTYPE=$2
    
    # this writes the job {$jobid}.mgt to the JID_FILE    
    # error is also piped into a directory-local log file
    echo `qsub ${SUBMISSION_SCRIPT} 2>qsub_log.e` > $JID_FILE

    # now lets run a quick check to make sure this went OK...
    check=`read_jobid`
    
    if [ -z "$check" ]
	then
	errorlog_header
	errorlog_current
	echo "ERROR: Problem submitting job using ${1} as submission script">> $AUTOQ_LOGFILE
	echo "ERROR"
	return
    fi
    
    # finally write to logfile and create a README in the directory
    echo `date` " -- Submitted ${JOBTYPE} job with ID [${check}] in" `pwd` >> $AUTOQ_STATUSLOG
    echo -e `date` "\nThis file is under AUTOQ control - please see your adminstrator for details\nAUTOQ reference file: ${AUTOQ_REFFILE}" > README_autoq

    
}

########################################################################
#
read_jobid() {
    raw=`cat ${JID_FILE}`

    if [ -z "$raw" ]
	then
	
	errorlog_header
	echo "ERROR: unable to read ${JID_FILE}" >> $AUTOQ_LOGFILE
	errorlog_current
		
	echo "ERROR"
	return
    fi

    raw_len=${#raw}
    id_len=`expr ${raw_len} - 4`
    
    echo ${raw:0:${id_len}}        
    
}


########################################################################
#
GMX_jobfinishedgracefully(){
    # Function to ensure a job terminated in a gracefull manner
    # will print "GRACEFUL" if the job

    if [ "$#" -ne 1 ]; then
	errorlog_header
	echo "ERROR: GMX_jobcompleted was passed an incorrect number of parameters" >> $AUTOQ_LOGFILE
	echo "ERROR"
	return
    fi
    
    JOBID=$1

    # searches the PBS logfile for signs of crashes...

    # get PBD logfile name

    PBS_LOGFILE=`ls *.e${JOBID} 2>/dev/null`

    # check we actually got a log file (sort of crucial
    # if we're emplying negative testing...)

    if [ -z "$PBS_LOGFILE" ]
    then
	errorlog_headerq
	echo "ERROR: GMX_jobfinishedgracefully was unable to find a logfile" >> $AUTOQ_LOGFILE
	echo "" >> $AUTOQ_LOGFILE
	errorlog_current
	echo "JOB ID: $JOBID">> $AUTOQ_LOGFILE
	
	echo "ERROR"
	return
    fi

    
    # segmentation fault search (system exploding!)
    segfault=`grep "Segmentation fault" $PBS_LOGFILE`

    if [ -z "$segfault" ]
    then
	echo "GRACEFUL"
    fi
}


########################################################################
#
GMX_jobcompleted() {
    # Function which will only echo "COMPLETED" if it can determine a job has run
    # to completion based on the gromacs .log file
    #
    # input arguments
    # arg

    
    # check the number of input arguments
    if [ "$#" -ne 1 ]; then
	echo "ERROR: GMX_jobcompleted was passed an incorrect number of parameters"
	return
    fi


    # set some script parameters
    GMX_LOGFILE=$1
    
    tot_numsteps=`grep nsteps $GMX_LOGFILE | awk {' print $3 '}`
    avstat=`expr $tot_numsteps + 1`
    statistics_word=`grep "Statistics over ${avstat}" $GMX_LOGFILE | awk {' print $1 '}`
    
    if [ "Statistics" == "${statistics_word}" ]
    then # job has completed
	echo "COMPLETE"
    else
	echo "NOT COMPLETED"
    fi

    # if not then no echo
}


########################################################################
#
GMX_jobrunning() {
    # Function to check if a job is running based on the qstat output
    # and a job id fed in
    #

    # check the number of input arguments
    if [ "$#" -ne 1 ]; then
	echo "ERROR: GMX_jobrunning was passed an incorrect number of parameters"
	return
    fi

    JOBID=$1
    target_strlen=${#JOBID}

    found=`qstat | grep $JOBID | awk {' print $1 '}`

    if [ -n "$found" ]
    then
	found_strlen=${#found}  
	found_strlen=`expr $found_strlen - 4`

	if [ "$found_strlen" == "$target_strlen" ]
	then
            echo "RUNNING"
	else
	    echo "NOT RUNNING"
	fi
    else
	echo "NOT RUNNING"	
    fi

    # if job not running then no echo
}

########################################################################
#
GMX_restart_needed() {

    # check the number of input arguments
    if [ "$#" -ne 1 ]; then
	echo "ERROR: GMX_jobrunning was passed an incorrect number of parameters"
	return
    fi

    GMX_LOG=$1

    # is job running
    jobid=`read_jobid`   

    echo " ------> JobID read      : [$jobid]" >> $AUTOQ_CRONLOG
    
    # exception handling - oldschool style!
    if [ "$jobid" == "ERROR" ] 
	then
	echo "ERROR"
	return
    fi

    #first check if job is running
    running=`GMX_jobrunning ${jobid}`

    echo " ------> Is job running  : [$running]" >> $AUTOQ_CRONLOG

    if [ "$running" == "ERROR" ]
	then
	echo "ERROR"
	return
    fi

    # echo NO if the job is currently
    # running
    if [ "$running" == "RUNNING" ]
	then
	echo "NO"
	return
    fi
   

    # next check if the job has completed
    # (i.e. is it totally done)
    completed=`GMX_jobcompleted $GMX_LOG`

    echo " ------> Is job complete : [$completed]" >> $AUTOQ_CRONLOG

    # ERROR?
    if [ "$completed" == "ERROR" ]
	then
	echo "ERROR"
	return
    fi
    
    # did the job complete?
    # note that by complete we mean
    # come to the number of steps 
    # defined in the logfile
    if [ "$completed" == "COMPLETE" ]
	then
	
	echo " ---------> job is complete, removing from master file" >> $AUTOQ_CRONLOG
	remove_from_referencefile

	echo "NO"
	return
    fi        

    # finally check if there were any segfaults
    # (in fact, the complete check should only
    # come back true if the job has completed
    # succesfully, but by having a seperate
    # function to check if there were errors
    # we can potentially trouble shoot later
    # should more sinister errors be identified

    graceful=`GMX_jobfinishedgracefully ${jobid}`


    if [ -z "$graceful" ] || [ "$graceful" == "ERROR" ]
	then
	echo "ERROR"
	return
    fi
    
    if [ "$graceful" == "GRACEFUL" ]
	then
	echo "YES"
	else
	echo "NO"
    fi

}


########################################################################
#
launch_restart() {
    # Function which will restart a job if appropriate using the 
    # provided r

    # ARG1 is the gromacs logfile convention
    # being used
    GMX_LOGFILE=$1

    # ARG2 is the restart script file
    RESTART_SCRIPT=$2
    
    restart_needed=`GMX_restart_needed $GMX_LOGFILE`

    if [ "$restart_needed" == "YES" ]
	then

	echo " ------>Launching restart [${restart_needed}]"
	echo ""

	submit_job $RESTART_SCRIPT "RESTART"
    else 
	echo " ------> No restart [${restart_needed}]"
	echo ""
    fi
}


########################################################################
#
launch_job() {
    # Function which launches a job via qsub using the submission
    # script provided in a way which facilitates autoQ restarts 
    # as well as generating the appropriate logging information
    #
    # PRECONDITIONS: We are in the directory from which submission
    # is going to take place
    #
    # ARG1 : initial submission pbs script (NOT the restart script)
   
    # check the number of input arguments
    if [ "$#" -ne 1 ]; then
	echo "ERROR: GMX_jobrunning was passed an incorrect number of parameters"
	return
    fi

    SUBMISSION_SCRIPT=$1
    
    # submit
    submit_job $SUBMISSION_SCRIPT "NEW"

    # update the master reference file for the autoq cron daemon
    update_reference_file
}

########################################################################
#
remove_from_referencefile() {
    # Function to remove the current directory from the AUTOQ_REFFILE
    # so this directory/job is no longer under autoQ control.
    # Should only be called if the job has completed!
    
    # weirdly this ended up being more robus than sed or awk...
    
    C_DIR=`pwd`

    while read -r line
      do      

      if [ "$line" != "$C_DIR" ]
	  then
	  echo $line	  
      fi
    done < $AUTOQ_REFFILE > ${AUTOQ_REFFILE}.tmp
    mv ${AUTOQ_REFFILE}.tmp ${AUTOQ_REFFILE}
}

########################################################################
#
update_reference_file() {
    C_DIR=`pwd`
    BAD="false"        
    
    # scan through file if there are any lines in it
    if [ -s "$AUTOQ_REFFILE" ]
	then
	
	while read -r line
	  do
	  
      # if we find the current directory in this file
      # already
	  if [ "$line" == "$C_DIR" ]
	      then
	      BAD="true"	      
	  fi
	done < $AUTOQ_REFFILE
	
	
    # if we discover the current directory is already in master file
	if [ "$BAD" == "true" ]
	    then 
	    
	    echo "ERROR"
	    errorlog_header
	    echo "ERROR: Trying to add a directory to the master file which is already in the file" >> $AUTOQ_LOGFILE
	    echo "This is bad bad bad bad bad bad...." >> $AUTOQ_LOGFILE
	    echo "To avoid ruining everything we're going to put a pause on all autoQ daemon activity by moving the masterfile to a backup and creating an empty master file..." >> $AUTOQ_LOGFILE
	    echo "moving ${AUTOQ_REFFILE} to ${AUTOQ_REFFILE}_backup" >> $AUTOQ_LOGFILE
	    mv $AUTOQ_REFFILE ${AUTOQ_REFFILE}_backup
	    return
	fi
    fi

    # if the master file doesn't actually exist create a blank file
    if [ ! -f "$AUTOQ_REFFILE" ]
	then
	touch $AUTOQ_REFFILE
    fi
    	
    # add the current directory to the autoq_reference file
    echo ${C_DIR} >> $AUTOQ_REFFILE
}
	 

########################################################################
##                                                                    ##
##                   ERROR HANDELING FUNCTIONS                        ##
##                                                                    ##
########################################################################

errorlog_header() {
    # Function to write header info to the log
    # file to help contextualize when and what
    # went wrong
    
    echo "-------------" >> $AUTOQ_LOGFILE
    echo "ERROR        " >> $AUTOQ_LOGFILE
    date >> $AUTOQ_LOGFILE
}

errorlog_current(){
    echo "Current directory:">> $AUTOQ_LOGFILE
    pwd >> $AUTOQ_LOGFILE
    echo "" >>  $AUTOQ_LOGFILE
    echo "Directory contents:">> $AUTOQ_LOGFILE
    ls >> $AUTOQ_LOGFILE
    echo "" >> $AUTOQ_LOGFILE
}


    