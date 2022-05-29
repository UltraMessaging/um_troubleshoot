#!/bin/sh
# lbmsrc.sh

cd $1

source ~/lbm.sh

lbmsrc -c demo.cfg -M 5000 -P 1 29west.example.multi.0
