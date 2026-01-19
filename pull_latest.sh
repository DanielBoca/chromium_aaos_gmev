#!/bin/bash
cd $CHROMIUMBUILD/chromium/src
git fetch
git reset --hard
git pull
gclient sync
cp $CHROMIUMBUILD/chromium_aaos_gmev/automotive.patch .
git apply automotive.patch
rm automotive.patch
# Shouldn't have to run "gn args out/Release" 
gclient runhooks
