#!/bin/bash

# TUNABLES
GLIDEIN_MAX_RUNNING=100
GLIDEIN_MAX_IDLE=100
GLIDEIN_PER_ROUND=10

USER_SCHEDDS="amundsen.grid.uchicago.edu scott.grid.uchicago.edu"
POOL="condor.grid.uchicago.edu"
#USER_SCHEDDS="login.usatlas.org"
#POOL="login.usatlas.org"

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
  jobs=$(($jobs + $(condor_q -all -name $schedd -pool $POOL -const 'JobStatus == 1 && JobUniverse == 5'  -totals | tail -n1 | awk '{print $7}')))
  if [[ $jobs -gt 0 ]]; then
    # There are jobs in queue, let's start submitting.
    glideins_running=$(condor_q -const 'JobStatus == 2 && JobUniverse == 5' -totals | tail -n1 | awk '{print $9}') 
    if [[ $glideins_running -lt $GLIDEIN_MAX_RUNNING ]]; then 
      # We aren't over our limit, so let's continue...
      if [[ $jobs -lt $GLIDEIN_MAX_RUNNING ]]; then
        # if its only a few jobs, just submit a few glideins
        for i in $(seq -w 1 $jobs); do 
          condor_submit glidein.sub 
        done
      else
        # otherwise submit up to our maximum per round
        for i in $(seq -w 1 $GLIDEIN_PER_ROUND); do
          condor_submit glidein.sub
        done
      fi
    fi
  fi
done
