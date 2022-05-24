#!/bin/sh
# labbox.sh - for Github.

export LABBOX_HOST="goat.29west.com"
CURDIR=`pwd`
SUBDIR=`basename $CURDIR`
labbox backup_exclude/labbox/$SUBDIR
