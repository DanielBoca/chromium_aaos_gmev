#!/bin/bash
TAG="146.0.7643.0"
cd $CHROMIUMBUILD/chromium/src
git fetch origin tag $TAG
git checkout -b aaos-$TAG tags/$TAG
git reset --hard HEAD
gclient sync
cp $CHROMIUMBUILD/chromium_aaos_gmev/automotive.patch .
git apply automotive.patch
rm automotive.patch
# Shouldn't have to run "gn args out/Release" 
gclient runhooks
