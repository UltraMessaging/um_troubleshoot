#!/bin/sh
# lbm.sh - source this script.

LBM_LICENSE_INFO="Product=LBM,UME,UMQ,UMDRO:Organization=xxxx:Expiration-Date=never:License-Key=xxxx xxxx xxxx xxxx"; export LBM_LICENSE_INFO

LBM=$HOME/UMP_6.7.1/Linux-glibc-2.17-x86_64; export LBM

LD_LIBRARY_PATH=$LBM/lib; export LD_LIBRARY_PATH

PATH="$LBM/bin:$PATH"; export PATH
