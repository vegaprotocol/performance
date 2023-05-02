#!/bin/bash

## Clear up previous runs
rm -f $PERFHOME/logs/*
rm -f $PERFHOME/results/*

## Start up the nomad controller
vegacapsule nomad start > $PERFHOME/logs/nomad.log 2>&1 &
sleep 20

## Start up the network
vegacapsule network stop > $PERFHOME/logs/capsule.log 2>&1 
vegacapsule network destroy >> $PERFHOME/logs/capsule.log 2>&1 
vegacapsule network generate --config-path=./configs/config.hcl >> $PERFHOME/logs/capsule.log 2>&1 
./scripts/createwallets.sh
vegacapsule network start >> $PERFHOME/logs/capsule.log 2>&1 
sleep 10

exit

## Set the variables for this run
LPUSERS=3
NORMALUSERS=97
MARKETS=1
VOTERS=3
LPOPS=1
PEGGED=25
USELP=false
FILLPL=false
RUNTIME=600
OPS=10

## Initialise the markets
vegatools perftest -a=localhost:3027 -w=localhost:1789 -f=localhost:1790 -u=$LPUSERS -n=$NORMALUSERS -g=localhost:8545 -m=$MARKETS -v=$VOTERS -l=$LPOPS -p=$PEGGED -U=$USELP -F=$FILLPL -t=$PERFHOME/tokens.txt -i

## Kick off the actual test
vegatools perftest -a=localhost:3027 -w=localhost:1789 -f=localhost:1790 -c=$OPS -r=$RUNTIME -u=$LPUSERS -n=$NORMALUSERS -g=localhost:8545 -m=$MARKETS -v=$VOTERS -l=$LPOPS -U=$USELP -t=$PERFHOME/tokens.txt &

## Wait for things to get moving
sleep 30

## Start collecting the CPU numbers
rm cpu.log
top -c -b -n100 | egrep "datanode|node0" > $PERFHOME/logs/cpu.log &

## Now collect the event and backlog values
rm bande.log
for i in {0..100}
do
  curl -s localhost:3003/statistics | egrep "backlog|eventsPer" >> $PERFHOME/logs/bande.log
  sleep 1
done

## Parse the log files to generate the performance numbers we need
## Extract the eps value
cat $PERFHOME/logs/bande.log | grep "eventsPerSecond" | cut -d"\"" -f4 > $PERFHOME/results/eps.csv
EPS=$(cat $PERFHOME/results/eps.csv | datamash mean 1)

## Extract the backlog value
cat $PERFHOME/logs/bande.log | grep "backlog" | cut -d"\"" -f4 > $PERFHOME/results/bl.csv
BACKLOG=$(cat $PERFHOME/results/bl.csv | datamash mean 1)

## Extract the core cpu value
CORECPU=$(cat $PERFHOME/logs/cpu.log | grep "vega node" | mawk '{print $9}' | datamash mean 1)

## Extract the datanode cpu value
DNCPU=$(cat $PERFHOME/logs/cpu.log | grep "vega datanode" | mawk '{print $9}' | datamash mean 1)

## Push the results out to a file
echo EPS=$EPS,BACKLOG=$BACKLOG,CORECPU=$CORECPU,DNCPU=$DNCPU

## Shutdown the perftest app
pkill -9 vegatools

## Stop the network
vegacapsule network stop >> $PERFHOME/logs/capsule.log 2>&1

## Close down nomad
pkill -9 nomad