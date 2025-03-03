#!/bin/bash -x

# TUNABLES
GLIDEIN_MAX_RUNNING=1000
GLIDEIN_MAX_IDLE=10
GLIDEIN_PER_ROUND=10


USER_SCHEDDS="head01.af.uchicago.edu"
POOL="head01.af.uchicago.edu"

GLIDEIN_SUBMIT_FILE="/home/af_condor/af-glidein/submit/glidein.sub"

###############################################
# In pseudo-code:
#  if jobs_in_queue:
#    if glideins_running <= $GLIDEIN_MAX_RUNNING:
#      if glideins_queued <= $GLIDEIN_MAX_IDLE: 
#        submit * $GLIDEIN_PER_ROUND
#      elseif glideins_queued > $GLIDEIN_MAX_IDLE:
#        # safe to do nothing?
#    elseif glideins_running > $GLIDEIN_MAX_RUNNING:
#        # safe to do nothing?
#   else:
#     # do nothing
###############################################

jobs=0
for schedd in $USER_SCHEDDS; do
  jobs=$(($jobs + $(condor_q -name $schedd -pool $POOL -all -const 'ALLOW_MWT2==true' -totals -json | jq .[]."Idle")))
  if [[ $jobs -gt 0 ]]; then
    echo "Have jobs in queue ($jobs), continue" >&2
    # There are jobs in queue, let's start submitting.
    glideins_running=$(condor_q -const 'JobStatus == 2 && JobUniverse == 5' -json -totals | jq .[].MyRunning)
    glideins_idle=$(condor_q -const 'JobStatus == 1 && JobUniverse == 5' -json -totals | jq .[].MyIdle)
    if [[ $glideins_running -lt $GLIDEIN_MAX_RUNNING ]]; then 
    echo "Running glideins ($glideins_running) less than max running glideins ($GLIDEIN_MAX_RUNNING), continue" >&2
      # We can submit as long as we're under the max idle glidein limit
      if [[ $glideins_idle -lt $GLIDEIN_MAX_IDLE ]]; then
        echo "Idle glideins ($glideins_idle) less than max idle glideins ($GLIDEIN_MAX_IDLE), continue" >&2
        # There are fewer glideins running than our maximum, so continue
        if [[ $jobs -lt $GLIDEIN_PER_ROUND ]]; then
          echo "Number of jobs ($jobs) lower than the max glidein per round ($GLIDEIN_PER_ROUND), submit $jobs" >&2
          # if its only a few jobs, just submit a few glideins
          for i in $(seq -w 1 $jobs); do 
            condor_submit $GLIDEIN_SUBMIT_FILE
          done
        else
          echo "Submit up to max glidein per round ($GLIDEIN_PER_ROUND)" >&2
          # otherwise submit up to our maximum per round
          for i in $(seq -w 1 $GLIDEIN_PER_ROUND); do
            condor_submit $GLIDEIN_SUBMIT_FILE
          done
        fi
      else
        echo "Idle glideins ($glideins_idle) exceeds max idle glideins ($GLIDEIN_MAX_IDLE), stop" >&2
      fi
    fi
  fi
done
