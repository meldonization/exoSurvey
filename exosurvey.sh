#!/bin/bash
# >>>
# __EXOSURVEY_SELF    =  'NJU exoplanet survey script'
# __EXOSURVEY_EMAIL   =  'exonju@hotmail.com'
# __EXOSURVEY_AUTHOR  =  'Meldonization'
# __EXOSURVEY_DATE    =  '2016-04-20' 
# __EXOSURVEY_VERSION =  '1.0'
# <<<


# script begins:

function display_help {
	# subroutine: display script help...
	echo '
#
# Usage: nohup bash path_to_exosurvey.sh &>> /dev/null &
#
# obj.txt includes all the fields of interests.
# obj.dat lists the field currently under observation.
# ***********************************************************
# Make sure this script and obj files are in the same folder!
# i.e. NJUPREFIX
# THERE IS NO NEED TO ADD BLANK LINES TO THESE FILES!!!!
# ***********************************************************
#
# ------ obj. FORMAT -------
# ra dec exptime(ms) nframes objname repointinterval(min)
# rpdt    30    # repointing time interval in min
# exptime 5000  # exposure time in ms
# nf      10    # number of frames for each field

#
# ------ script options -------
# -c or --continue  # continue from last saved obs. point
# -b or --backup    # archive & clear image after ccd exposure
# -h or --help      # display script man document
# -m 2m or -m 16h   # script maxmimum running time in minutes/hours
# -s or --skip      # skip the last saved obs. field
# -r or --recursive # wrap observing after finishing the last field 

# 
# Script Flow Description:
#  -> read in survey params;
#  -> backup all the files/data;
#  -> begin the main loop survey;
#  -> whilst catching errors;
'
}


# preparing output header
__EXO_SELF='#NJU EXOPLANET SURVEY SCRIPT'
__EXO_STATUS='###START A NEW SURVEY'
# defined var:
NJUPREFIX='/Volumes/MHD/Users/mengzy/Data/ast3/survey_test' #XXXXX
# /home/ast3/nju/obj.txt
if [ ${NJUPREFIX: -1} != '/' ]; then NJUPREFIX="$NJUPREFIX"/ ; fi
OUTINFO="$NJUPREFIX"exonjusurvey_`date "+%m%d"`.md

# read in params here...
while :
do
    case "$1" in
      -h | --help)
	  display_help  # Call help function
	  exit 0
	  ;;
      -c | --continue)
	  __EXO_STATUS='###CONTINUE PREV. SURVEY'
	  exostatus=1 # 1 - continue from existing
	  shift
	  ;;
      -b | --backup)
	  __EXO_STATUS="$__EXO_STATUS & ARCHIVE"
	  exobackup=1 # archive img after expose
	  shift
	  ;;
      -m)
	  if [[ $2 =~ ^[0-9]+[hm]$ ]] ; then 
		 __EXO_STATUS="$__EXO_STATUS & SCRIPT MAXTIME: $2"
   	 	 case "${2: -1}" in 
			h)
			maxtime=$(( ${2%?}*60 ))
			;;
			m)
			maxtime="${2%?}"
		 esac
		 shift 2
 	  else
		 echo -e "ERROR: Unknown parameter: $2 \n" | tee -a "$OUTINFO"
		 exit 1
	  fi
	  ;;
      -s | --skip)
	  __EXO_STATUS="$__EXO_STATUS & SKIP CURRENT FIELD"
	  exoskip=1 # skip saved field
	  skipstatus=0
	  shift
	  ;;
      -r | --recursive)
	  __EXO_STATUS="$__EXO_STATUS & RECURSIVE OBS."
	  exorecur=1 # non stop obs. even after the final field
	  recurstatus=0
	  shift
	  ;;
      --) # End of all options
	  shift
	  break;
	  ;;
      -*)
	  echo -e "WARNING: Unknown option: $1 \n" | tee -a "$OUTINFO"
	  exit 1
	  ;;
      *)  # No more options
	  break
	  ;;
    esac
done

# checking existing survey
if [ "`ps -A | grep survey | grep nohup`" ] ; then
	echo -e 'ERROR: Existing survey detected!!! \n' | tee -a "$OUTINFO"
	exit 1
fi
	
# checking key input files..
allField="$NJUPREFIX"obj.txt
if [ ! -e $allField ] ; then 
	echo -e "ERROR: cannot locate key file: obj.txt \n" | tee -a "$OUTINFO"
	exit 1
fi

nowField="$NJUPREFIX"obj.dat
if [ "$exostatus" -a "$exostatus" == '1' -a ! -e "$nowField" ] ; then 
	echo -e "ERROR: cannot locate key file: obj.dat \n" | tee -a "$OUTINFO"
	exit 1
fi

echo -e "\n" | tee -a "$OUTINFO"
echo "------ SURVEY BEGIN AT `date "+%F %T"` ------" | tee -a "$OUTINFO"
echo "$__EXO_SELF" | tee -a "$OUTINFO"
echo "$0" | tee -a "$OUTINFO"
echo "$__EXO_STATUS" | tee -a "$OUTINFO"
echo "Script starts at local time `date "+%F %T"`" | tee -a "$OUTINFO"

nField=$(wc -l < "$allField")
#declare -a arrayField
#arrayField=( `cat "$allField"`) 
#echo ${arrayField[0]}

trap 'echo "WARNING Ctrl_C detected! Exiting..." && break' 2 | tee -a "$OUTINFO" 
trap 'echo "WARNING Ctrl_C detected! Exiting..." && exit 2' INIT | tee -a "$OUTINFO" 
# 3K2 YZY/LES
start=`date +%s`
cnt=0
cntfield=0

echo -e "> re-pointing telescope before obs.  \n" | tee -a "$OUTINFO"
echo -e "\`/ast3/bin/telpoint.sh $ra $dec $objname\`  \n" | tee -a "$OUTINFO" #XXXXX
echo -e "> end of re-pointing telescope.  \n" | tee -a "$OUTINFO"

until [ "$recurstatus" == '1' ] ; do 

	# if not recurring then stop after this round
	[ $cntfield == $nField -a ! -n "$exorecur" ] && recurstatus=1 
	while read nowTarget || [ -n "$nowTarget" ];
	do
		
		targra=`echo $nowTarget | awk '{print $1}'`
		targdec=`echo $nowTarget | awk '{print $2}'`
		exptime=`echo $nowTarget | awk '{print $3}'`
		nframes=`echo $nowTarget | awk '{print $4}'`
		objname=`echo $nowTarget | awk '{print $5}'`
		rpdt=`echo $nowTarget | awk '{print $6}'`
		
		if [ "$exostatus" == '1' ]; then # continue from existing survey
			[[ "`awk '{print $1}' $nowField`" == "$targra" &&  \
			   "`awk '{print $2}' $nowField`" == "$targdec" && \
			   "`awk '{print $3}' $nowField`" == "$exptime" && \
			   "`awk '{print $4}' $nowField`" == "$nframes" && \
			   "`awk '{print $5}' $nowField`" == "$objname" && \
			   "`awk '{print $6}' $nowField`" == "$rpdt" ]] && \
			   exostatus=0 
			[[ "$exostatus" == '0'  && "$exoskip" != '1' ]] && skipstatus=1
			[[ "$skipstatus" != '1' ]] && continue
		fi
		
		echo "$targra $targdec $exptime $nframes $objname $rpdt" > $nowField
		echo NO. $cntfield | FIELD: ra: "$targra" dec: "$targdec" exp: "$exptime"ms \
			$nframes $objname "$rpdt"min | tee -a "$OUTINFO"
		
		echo -e "> loop obs. begins at `date "+%F %T"`  \n" | tee -a "$OUTINFO"
	    echo -e "\`/ast3/bin/ccd expose $exptime 1 $nf\`  \n" | tee -a "$OUTINFO" #XXXXX 
		
		# SAVE IMAGES NAMES AND OBSERVING TIME TO LOG FILE
		sleep 1 #XXXXX
		
		if [ "$exobackup" == '1' ]; then # whether to backup
			echo -e "\`/ast3/bin/copyimg.sh ; /ast3/bin/cleanimg.sh\`  \n" \
				| tee -a "$OUTINFO" #XXXXX
		fi
		
		echo -e "> CCD exposure finished.  \n" | tee -a "$OUTINFO"
		cntfield=$((cntfield+1))
		tnow=`date +%s`
		dtime=$(( $tnow-$start ))
		
	    if [ -n "$maxtime" ] && (( $dtime/60 >= "$maxtime" )) ; then 
				echo -e '__!!max. time reached!!__  \n' | tee -a "$OUTINFO"
				recurstatus=1
				break
	    fi
		
	    if (( $dtime/$rpdt >= $cnt + 1 )); then
	        echo -e "> re-pointing telescope.  \n" | tee -a "$OUTINFO"
			echo -e "\`/ast3/bin/telpoint.sh $ra $dec $objname\`  \n" \
				| tee -a "$OUTINFO" #XXXXX
	        cnt=$((cnt+1))
			echo -e "> end of re-pointing telescope.  \n" | tee -a "$OUTINFO"
	    fi
		
	done < "$allField" 	
done

[[ "$dtime" == '' ]] && dtime=1
echo "`basename $0` EXEC takes: $(($dtime/60)) min $(($dtime%60)) sec." \
	    | tee -a "$OUTINFO"
echo "------ SURVEY END AT `date "+%F %T"` ------" | tee -a "$OUTINFO"
echo -e "\n" | tee -a "$OUTINFO"
