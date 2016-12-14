# exoSurvey

#
### Usage: nohup bash path_to_exosurvey.sh &>> /dev/null &
#
 obj.txt includes all the fields of interests.
 obj.dat lists the field currently under observation.
---
 Make sure this script and obj files are in the same folder!
 i.e. NJUPREFIX
 THERE IS NO NEED TO ADD BLANK LINES TO THESE FILES!!!!
---
```
 ------ obj. FORMAT -------
 ra dec exptime(ms) nframes objname repointinterval(min)
 rpdt    30    # repointing time interval in min
 exptime 5000  # exposure time in ms
 nf      10    # number of frames for each field
```
```
# ------ script options -------
# -c or --continue  # continue from last saved obs. point
# -b or --backup    # archive & clear image after ccd exposure
# -h or --help      # display script man document
# -m 2m or -m 16h   # script maxmimum running time in minutes/hours
# -s or --skip      # skip the last saved obs. field
# -r or --recursive # wrap observing after finishing the last field 
```
```
#
# Script Flow Description:
#  -> read in survey params;
#  -> backup all the files/data;
#  -> begin the main loop survey;
#  -> whilst catching errors;
```
