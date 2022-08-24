#!/bin/sh
# tst.sh

D=`pwd`

# Define "LD_LIBRARY_PATH" and "PATH" and "LBM_LICENSE_INFO".
source ~/lbm.sh

rm -f *.log

tcpdump -i p4p1 -w test.pcap &
TCPDUMP_PID=$!

lbmrd lbmrd.xml >lbmrd.log 2>&1 &
LBMRD_PID="$!"
sleep 0.1

lbmmon --transport-opts="config=mon.cfg" >lbmmon.log 2>&1 &
LBMMON_PID="$!"
sleep 0.1

# Give lbmrcv a little loss.
LBTRM_LOSS_RATE=10 lbmrcv -c demo.cfg -E 29west.example.multi.0 2>&1 >lbmrcv.log &
LBMRCV_PID="$!"

# lbmwrc will subscribe to all topics, which will be 29west.example.multi.0 and 29west.example.multi.1
lbmwrcv -c demo.cfg -E -v "^29west\.example\.multi\.[01]$" >lbmwrcv.log 2>&1 &
LBMWRCV_PID="$!"

ssh hal $D/lbmsrc.sh $D >lbmsrc.log 2>&1 &
LBMSRC_PID="$!"

# lbmmsrc will publish 2 topics: 29west.example.multi.0 and 29west.example.multi.1
ssh hal $D/lbmmsrc.sh $D >lbmmsrc.log 2>&1 &
LBMMSRC_PID="$!"

echo "Waiting..."
wait $LBMRCV_PID $LBMWRCV_PID

kill $LBMMON_PID $LBMRD_PID $TCPDUMP_PID
