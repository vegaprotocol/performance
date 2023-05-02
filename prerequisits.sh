#!/bin/bash

## Check PERFHOME is set or we have to stop
if [ ! -v PERFHOME ]
then
  echo Please set the PERFHOME environment variable to the root of the performance repo
  exit
fi

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
  echo "$ wget https://go.dev/dl/go1.19.8.linux-amd64.tar.gz"
  echo "$ sudo rm -rf /usr/local/go"
  echo "$ sudo tar -C /usr/local -xzf go1.19.8.linux-amd64.tar.gz" 
  echo "Then add /usr/local/go/bin to your PATH variable"
  exit
else
  echo "Golang installed correctly"
fi
export CGO_ENABLED=0

## git
if ! command -v git &>/dev/null
then
  echo "Please install the latest version of git"
  echo "sudo apt install git -y"
  exit
else
  echo "Git installed correctly"
fi

## sqlite
if ! command -v sqlite &>/dev/null
then
  echo "Please install the latest version of SQLite"
  echo "sudo apt install sqlite -y"
  exit
else
  echo "SQLite install correctly"
fi

## datamash
if ! command -v datamash &>/dev/null
then
  echo "Please install the latest version of datamash"
  echo "sudo apt install datamash -y"
  exit
else
  echo "Datamash install correctly"
fi

## docker
if ! command -v docker &>/dev/null
then
  echo "Please install the latest version of docker"
  echo "sudo apt install docker.io -y"
  echo "sudo groupadd docker"
  echo "sudo usermod -aG docker \$USER"
  echo "newgrp docker"

  exit
else
  echo "Docker install correctly"
fi

## consoleLoadTest
#rm -rf consoleLoadTest 
#git clone https://github.com/vegaprotocol/consoleLoadTest.git

## vegatools
if [ ! -d "vegatools" ]
then
  git clone https://github.com/vegaprotocol/vegatools.git
fi

cd vegatools
git pull
go install ./...
cd ..

## vega
if [ ! -d "vega" ]
then
  git clone https://github.com/vegaprotocol/vega.git
fi

cd vega
git pull
go install ./...
cd ..

## vega capsule
if [ ! -d "vegacapsule" ]
then
  git clone https://github.com/vegaprotocol/vegacapsule.git
fi

cd vegacapsule
git pull
go install ./...
cd ..
 