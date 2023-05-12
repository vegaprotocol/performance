#!/bin/bash

## Start up the nomad controller
vegacapsule nomad start > $PERFHOME/logs/nomad.log 2>&1 &
sleep 10

## Loop through the list of scenarios we want to test
while IFS=, read -r TESTNAME LPUSERS NORMALUSERS MARKETS VOTERS LPOPS PEGGED USELP FILLPL RUNTIME OPS || [ -n "$TESTNAME" ]
do
 echo Starting test $TESTNAME
#  echo LP Users = $LPUSERS
#  echo NormalUsers = $NORMALUSERS
#  echo Markets = $MARKETS
#  echo Voters = $VOTERS
#  echo LP Orders Per Side = $LPOPS
#  echo Pegged = $PEGGED
#  echo Use LP = $USELP
#  echo Fill Price Level = $FILLPL
#  echo Runtime = $RUNTIME
#  echo Operations Per Second = $OPS

  if [ "$TESTNAME" ==  "TESTNAME" ]
  then
    continue
  fi

  ## Clear up previous runs
  rm -f $PERFHOME/logs/*

  ## Start up the network
  vegacapsule network stop > $PERFHOME/logs/capsule.log 2>&1 
  vegacapsule network destroy >> $PERFHOME/logs/capsule.log 2>&1 
  vegacapsule network generate --config-path=./configs/config.hcl >> $PERFHOME/logs/capsule.log 2>&1 
  ./scripts/createwallets.sh
  vegacapsule network start >> $PERFHOME/logs/capsule.log 2>&1 
  sleep 10

  ## Initialise the markets
  vegatools perftest -a=localhost:3027 -w=localhost:1789 -f=localhost:1790 -u$LPUSERS -n$NORMALUSERS -g=localhost:8545 -m$MARKETS -v$VOTERS -l$LPOPS -p$PEGGED -U$USELP -F$FILLPL -t=$PERFHOME/tokens.txt -i > $PERFHOME/logs/perftest.log 2>&1

  ## Kick off the actual test
  vegatools perftest -a=localhost:3027 -w=localhost:1789 -f=localhost:1790 -c$OPS -r$RUNTIME -u$LPUSERS -n$NORMALUSERS -g=localhost:8545 -m$MARKETS -v$VOTERS -l$LPOPS -U$USELP -t=$PERFHOME/tokens.txt >> $PERFHOME/logs/perftest.log 2>&1 &

  ## Wait for things to get moving
  sleep 30

  ## Start collecting the CPU numbers
  top -c -b -n50 | egrep "datanode|node0" > $PERFHOME/logs/cpu.log &

  ## Now collect the event and backlog values
  for i in {0..100}
  do
    curl -s localhost:3003/statistics | egrep "backlog|eventsPer" >> $PERFHOME/logs/bande.log
    sleep 1
  done
  sleep 30

  ## Parse the log files to generate the performance numbers we need
  ## Extract the eps value
  cat $PERFHOME/logs/bande.log | grep "eventsPerSecond" | cut -d"\"" -f4 > $PERFHOME/logs/eps.csv
  EPS=$(cat $PERFHOME/logs/eps.csv | datamash -R 1 mean 1)

  ## Extract the backlog value
  cat $PERFHOME/logs/bande.log | grep "backlog" | cut -d"\"" -f4 > $PERFHOME/logs/bl.csv
  BACKLOG=$(cat $PERFHOME/logs/bl.csv | datamash -R 1 mean 1)

  ## Extract the core cpu value
  CORECPU=$(cat $PERFHOME/logs/cpu.log | grep "vega node" | mawk '{print $9}' | datamash -R 2 mean 1)

  ## Extract the datanode cpu value
  DNCPU=$(cat $PERFHOME/logs/cpu.log | grep "vega datanode" | mawk '{print $9}' | datamash -R 2 mean 1)

  ## Push the results out to a file
  echo
  echo TESTNAME=$TESTNAME,EPS=$EPS,BACKLOG=$BACKLOG,CORECPU=$CORECPU,DNCPU=$DNCPU
  echo TESTNAME=$TESTNAME,EPS=$EPS,BACKLOG=$BACKLOG,CORECPU=$CORECPU,DNCPU=$DNCPU > $PERFHOME/results/$TESTNAME.log

  ## Shutdown the perftest app
  pkill vegatools > /dev/null 2>&1

  ## Stop the network
  vegacapsule network stop >> $PERFHOME/logs/capsule.log 2>&1
  sleep 3
done < input.csv

## Close down nomad
pkill -9 nomad > /dev/null 2>&1
