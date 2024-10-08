#!/bin/bash
# set -x
# env

if [ -z "$PGPASSWORD" ]; then
  echo "PGPASSWORD env variable is missing. Set it before you execute the runtests.sh script";
  exit 1;
fi;

if [[ "$1" = "--pprof-collection" ]]; then
  pprof_collection_enabled="true"
else
  pprof_collection_enabled="false"
fi

## Clear up any config files left over from the past run
rm -rf ~/.vegacapsule/testnet

## If we don't have a database file, create one now
psql --host $POSTGRES_HOST --port $POSTGRES_PORT --user $POSTGRES_USER defaultdb < createtable.sql

## Find vega version we are going to use
VEGAVERSION=`vega version`
echo "We are using vega version $VEGAVERSION"

## Find the branch name for this build
cd vega
VEGABRANCH=`git rev-parse --abbrev-ref HEAD`
echo "We built the code from the branch $VEGABRANCH"
cd ..

## Start up the nomad controller
vegacapsule nomad start > $PERFHOME/nomad.log 2>&1 &
sleep 10

## Initialise the results file
echo TIMESTAMP,VEGAVERSION,VEGABRANCH,TESTNAME,LPUSERS,SLALEVELS,SLAUPDATE,NORMALUSERS,MARKETS,VOTERS,PEGGED,STOPORDERS,USELP,PRICELEVELS,FILLPL,RUNTIME,OPS,EPS,BACKLOG,CORECPU,DNCPU,PGCPU,USEBATCH,BATCHSIZE,SPOTMARKET,AMM > $PERFHOME/results/all.csv

## Loop through the list of scenarios we want to test
while read -r TESTNAME LPUSERS SLALEVELS SLAUPDATE NORMALUSERS MARKETS VOTERS PEGGED STOPORDERS USELP PRICELEVELS FILLPL RUNTIME OPS USEBATCH BATCHSIZE SPOTMARKET AMM || [ -n "$TESTNAME" ]
do
  if [ "$TESTNAME" ==  "TESTNAME" ]
  then
    continue
  fi

  if [[ "$TESTNAME" =~ ^"#" ]]
  then
    continue
  fi

  echo Starting test "$TESTNAME"

  ## Clear up previous runs
  rm -f $PERFHOME/logs/*

  ## Start up the network
  vegacapsule network generate --config-path=./configs/config.hcl >> $PERFHOME/logs/capsule.log 2>&1
  ./scripts/createwallets.sh
  sleep 10
  vegacapsule network start >> $PERFHOME/logs/capsule.log 2>&1
  ## Wait for the wallet to import all the users as it can take a while
  sleep 60

  ## Initialise the markets
  vegatools perftest -a=localhost:3027 -w=localhost:1789 -f=localhost:1790 -u$LPUSERS -l$SLALEVELS -n$NORMALUSERS -g=localhost:8545 -m$MARKETS -v$VOTERS -p$PEGGED -U=$USELP -P=$SPOTMARKET -F=$FILLPL -L$PRICELEVELS -t=$PERFHOME/tokens.txt -d=$STOPORDERS -i >> $PERFHOME/logs/perftest.log 2>&1

  ## Kick off the actual test
  vegatools perftest -a=localhost:3027 -w=localhost:1789 -f=localhost:1790 -c$OPS -r$RUNTIME -u$LPUSERS -l$SLALEVELS -S$SLAUPDATE -n$NORMALUSERS -g=localhost:8545 -m$MARKETS -v$VOTERS -U=$USELP -P=$SPOTMARKET -A=$AMM -L$PRICELEVELS -d=0 -B=$USEBATCH -b$BATCHSIZE -t=$PERFHOME/tokens.txt -I >> $PERFHOME/logs/perftest.log 2>&1 &

  ## Wait for things to get moving 
  sleep 30

  ## Start collecting the CPU numbers
  top -c -b -n50 -w512 | egrep "datanode|node0|postgres:" > $PERFHOME/logs/cpu.log &

  ## Start collecting event counts for a report to see which events are the most common
  vegatools eventrate -a=localhost:3027 -e99 -f100 > $PERFHOME/logs/eventrate.log &


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

  ## Extract the postgres cpu value
  ## Because the postgres app is made up of several sub processes (thankfully all called postgres), we add up their total
  ## cpu time over the 50 collection times and then divide the result by 50 to get the average CPU time per second
  PGCPU=$(cat $PERFHOME/logs/cpu.log | grep "postgres" | mawk '{print $9}' | datamash -R 1 sum 1 | datamash round 1)
  PGCPU=$(bc -l <<< "scale=2; $PGCPU/50")

  ## Backup the eventrate report for access later
  cp $PERFHOME/logs/eventrate.log $PERFHOME/results/$TESTNAME-eventrate.log

  ## Generate a timestamp for this run
  TIMESTAMP=`date --rfc-3339=seconds --utc`

  ## Push the results out to a file
  echo TESTNAME=$TESTNAME,EPS=$EPS,BACKLOG=$BACKLOG,CORECPU=$CORECPU,DNCPU=$DNCPU,PGCPU=$PGCPU
  echo TESTNAME=$TESTNAME,EPS=$EPS,BACKLOG=$BACKLOG,CORECPU=$CORECPU,DNCPU=$DNCPU,PGCPU=$PGCPU > $PERFHOME/results/$TESTNAME.log
  echo $TIMESTAMP,$VEGAVERSION,$VEGABRANCH,$TESTNAME,$LPUSERS,$SLALEVELS,$SLAUPDATE,$NORMALUSERS,$MARKETS,$VOTERS,$PEGGED,$STOPORDERS,$USELP,$PRICELEVELS,$FILLPL,$RUNTIME,$OPS,$USEBATCH,$BATCHSIZE,$SPOTMARKET,$AMM,$EPS,$BACKLOG,$CORECPU,$DNCPU,$PGCPU >> $PERFHOME/results/all.csv
  echo

  ## Send the results into the sql database
  SQL="insert into perf_results (TS,VEGAVERSION,VEGABRANCH,TESTNAME,LPUSERS,SLALEVELS,SLAUPDATE,NORMALUSERS,MARKETS,VOTERS, \
    PEGGED,STOPORDERS,USELP,PRICELEVELS,FILLPL,RUNTIME,OPS,USEBATCH,BATCHSIZE,SPOTMARKET,AMM,EPS,BACKLOG,CORECPU,DNCPU,PGCPU) \
    values ('$TIMESTAMP','$VEGAVERSION','$VEGABRANCH','$TESTNAME',$LPUSERS,$SLALEVELS,$SLAUPDATE,$NORMALUSERS,$MARKETS,$VOTERS, \
    $PEGGED,$STOPORDERS,$USELP,$PRICELEVELS,$FILLPL,$RUNTIME,$OPS,$USEBATCH,$BATCHSIZE,$SPOTMARKET,$AMM,$EPS,$BACKLOG,$CORECPU,$DNCPU,$PGCPU)"

  psql --host $POSTGRES_HOST --port $POSTGRES_PORT --user $POSTGRES_USER defaultdb -c "$SQL"

  ## Shutdown the perftest app
  pkill vegatools > /dev/null 2>&1

  ## Stop the network
  vegacapsule network stop >> $PERFHOME/logs/capsule.log 2>&1

  if [[ "$pprof_collection_enabled" = "true" ]]; then
    pprof_base="${PERFHOME}/pprofs/${TESTNAME}"
    mkdir -p "${pprof_base}"
    while read -r pprof; do
      new_location=$(echo $pprof | sed "s|$HOME/.vegacapsule/testnet|$pprof_base|g")
      mkdir -p $(dirname $new_location)
      mv $pprof $new_location
    done< <(find ~/.vegacapsule/testnet -name "*.pprof")
  fi

  vegacapsule network destroy >> $PERFHOME/logs/capsule.log 2>&1
  sleep 3
done < input.csv

## Close down nomad
pkill -9 nomad > /dev/null 2>&1
