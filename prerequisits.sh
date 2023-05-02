#!/bin/bash

## Make sure these is a place to put the binary files
if [ ! -d "bin" ]
then
  mkdir bin
fi
export GOBIN=`pwd`/bin

## A place for log files
if [ ! -d "logs" ]
then
  mkdir logs
fi

## A place for result output
if [ ! -d "results" ]
then
  mkdir results
fi

## go
if ! command -v go &> /dev/null
then
  echo "Please install the latest version of golang"
else
  echo "Golang installed correctly"
fi

## git
if ! command -v git &>/dev/null
then
  echo "Please install the latest version of git"
else
  echo "Git installed correctly"
fi

## sqlite
if ! command -v sqlite &>/dev/null
then
  echo "Please install the latest version of SQLite"
else
  echo "SQLite install correctly"
fi

## datamash
if ! command -v datamash &>/dev/null
then
  echo "Please install the latest version of datamash"
else
  echo "datamash install correctly"
fi

## consoleLoadTest
#rm -rf consoleLoadTest 
#git clone https://github.com/vegaprotocol/consoleLoadTest.git

## vegatools
if [ ! -d "vegatools" ]
then
  git clone https://github.com/vegaprotocol/vegatools.git
  cd vegatools
  go install ./...
  cd ..
fi

## vega
if [ ! -d "vega" ]
then
  git clone https://github.com/vegaprotocol/vega.git
  cd vega
  go install ./...
  cd ..
fi

## vega capsule
if [ ! -d "vegacapsule" ]
then
  git clone https://github.com/vegaprotocol/vegacapsule.git
  cd vegacapsule
  go install ./...
  cd ..
fi 
