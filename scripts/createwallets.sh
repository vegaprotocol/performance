#!/bin/bash
## Create the password file
echo p3rfb0t > password.txt

WALLETDIR=~/.vegacapsule/testnet/wallet
WALLETPWD=$PERFHOME/password.txt
TOKENPWD=$PERFHOME/password.txt
TOKENFILE=$PERFHOME/tokens.txt

## Remove existing token file
rm -f $TOKENFILE

## Remove any wallets left over from previous calls
rm -f $WALLETDIR/data/wallets/*

## Create a set of new user wallets
for i in {00000..01000}
do
  USERNAME="User$i"
  DESCRIPTION="Token for wallet $USERNAME"
  echo -n $USERNAME >> $TOKENFILE
  # Create the wallet
  vegawallet --home $WALLETDIR create -p=password.txt -w=$USERNAME >> $PERFHOME/logs/wallet.log 2>&1
  # Create the API token for this wallet
  vegawallet --home $WALLETDIR api-token generate --wallet-name $USERNAME --description \"$DESCRIPTION\" --wallet-passphrase-file $WALLETPWD --tokens-passphrase-file $TOKENPWD | grep API | cut -d':' -f2 >> $TOKENFILE 
done
