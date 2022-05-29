#!/bin/sh
# lbmmsrc.sh

cd $1

source ~/lbm.sh

lbmmsrc -c demo.cfg -M 5000 -P 1 -S 2 -T 1
