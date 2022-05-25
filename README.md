# um_troubleshoot
Sample troubleshooting session with Ultra Messaging.

# Table of contents

<sup>(table of contents from https://luciopaiva.com/markdown-toc/)</sup>

# COPYRIGHT AND LICENSE

All of the documentation and software included in this and any
other Informatica Ultra Messaging GitHub repository
Copyright (C) Informatica. All rights reserved.

Permission is granted to licensees to use
or alter this software for any purpose, including commercial applications,
according to the terms laid out in the Software License Agreement.

This source code example is provided by Informatica for educational
and evaluation purposes only.

THE SOFTWARE IS PROVIDED "AS IS" AND INFORMATICA DISCLAIMS ALL WARRANTIES
EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION, ANY IMPLIED WARRANTIES OF
NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR
PURPOSE.  INFORMATICA DOES NOT WARRANT THAT USE OF THE SOFTWARE WILL BE
UNINTERRUPTED OR ERROR-FREE.  INFORMATICA SHALL NOT, UNDER ANY CIRCUMSTANCES,
BE LIABLE TO LICENSEE FOR LOST PROFITS, CONSEQUENTIAL, INCIDENTAL, SPECIAL OR
INDIRECT DAMAGES ARISING OUT OF OR RELATED TO THIS AGREEMENT OR THE
TRANSACTIONS CONTEMPLATED HEREUNDER, EVEN IF INFORMATICA HAS BEEN APPRISED OF
THE LIKELIHOOD OF SUCH DAMAGES.

# REPOSITORY

See https://github.com/UltraMessaging/um_troubleshoot for code and documentation.

# INTRODUCTION

This repository is intended to train Ultra Messaging users
to perform some simple troubleshooting using monitoring data
and a packet capture.

Informatica recommends that UM-based applications and daemons configure
automatic monitoring.

Informatica also recommends the use of an "always-on" packet capture
appliance,
like [Pico's Corvil](https://www.pico.net/corvil-analytics/corvil-classic/).

For a deeper explanation of enabling automatic monitoring,
see the repository [mon_demo](https://github.com/UltraMessaging/mon_demo).
This repository builds on the mon_demo, with some modifications.

## Test Setup

We ran the shell script "tst.sh", which executes a set of standard UM
example applications and captures monitoring data (in "lbmmon.log")
and packets (in "test.pcap").

You can also run "tst.sh", but will need to make changes for your environment
to the files "demo.cfg", "mon.cfg", and "lbmrd.xml".

An important part of the test is the line:
````
LBTRM_LOSS_RATE=10 lbmrcv -c demo.cfg -E 29west.example.multi.0 2>&1 >lbmrcv.log &
````
This runs a subscriber with an artificial randomized LBT-RM loss rate of 10%.
I.e., about 1 in 10 received messages will be dropped.

Here's an illustration of the test:
![Figure 1](figure1.png)
See [Interpreting the Data](https://github.com/UltraMessaging/mon_demo#interpreting-the-data)
for more explanation.

# PREPARATION

Make sure you have a recent version of
[Wireshark](https://www.wireshark.org).
It is not necessary to have Ultra Messaging installed to perform
these steps.

Download the contents of
[this repository](https://github.com/UltraMessaging/um_troubleshoot).
Click the green "Code" button near the top of that page,
and select "Download ZIP".
Expand it and "cd" to it.

# MONITORING DATA

To start, let's look for the most serious problem: unrecoverable loss.

````
$ egrep "Number of data message fragments unrecoverably lost: [^0]" lbmmon.log
$
````

Good, no unrecoverable loss by any application
that is being monitored.
Let's look for recovered loss.

````
$ egrep "Lost LBT-RM datagrams detected *: [^0]" lbmmon.log
    Lost LBT-RM datagrams detected                            : 374
    Lost LBT-RM datagrams detected                            : 381
    Lost LBT-RM datagrams detected                            : 514
    Lost LBT-RM datagrams detected                            : 487
$
````

Yes, there is loss.
The fact that there is loss, but no "unrecoverable loss", means that the
LBT-RM reliability algorithms did their job. I.e., even with 10% of received
packets dropped, UM got them all retransmitted.

Let's get some details.

````
$ vi lbmmon.log
````
Search for /Lost LBT-RM datagrams detected *: [^0]/ to find
the first two records reporting loss.
I will annotate the important lines with "*" in column 1
(not part of lbmmon.log).
````
...
Receiver statistics received from lbmrcv at 10.29.3.101, process ID=96ed, object ID=2344240, context instance=0d5f10a7eba3f94a, domain ID=0, sent Mon May 23 15:11:25 2022
Source: LBTRM:10.29.4.121:12091:a7f10561:239.101.3.10:14400
Transport: LBT-RM
*   LBT-RM datagrams received                                 : 3602
    LBT-RM datagram bytes received                            : 205314
    LBT-RM NAK packets sent                                   : 167
*   LBT-RM NAKs sent                                          : 371
*   Lost LBT-RM datagrams detected                            : 374
*   NCFs received (ignored)                                   : 32
...
    LBT-RM LBM messages received                              : 3602
*   LBT-RM LBM messages received with uninteresting topic     : 1806
...
Receiver statistics received from lbmrcv at 10.29.3.101, process ID=96ed, object ID=2344240, context instance=0d5f10a7eba3f94a, domain ID=0, sent Mon May 23 15:11:25 2022
Source: LBTRM:10.29.4.121:12090:f9d74f3e:239.101.3.10:14400
Transport: LBT-RM
*   LBT-RM datagrams received                                 : 3678
    LBT-RM datagram bytes received                            : 209646
    LBT-RM NAK packets sent                                   : 208
*   LBT-RM NAKs sent                                          : 347
*   Lost LBT-RM datagrams detected                            : 381
*   NCFs received (ignored)                                   : 28
...
    LBT-RM LBM messages received                              : 3678
*   LBT-RM LBM messages received with uninteresting topic     : 0
````
These two transport sessions are reported by the "lbmrcv" subscriber in
the same monitoring period (ending 15:11:25).
And these are the only two transport sessions joined by "lbmrcv".

Note that there are 3678 datagrams received and 381 lost datagrams detected.
We're losing about 10% of our datagrams.

Note that in both transport sessions, the number of NAKs sent
is less than the lost packets detected.
This is because UM does not send NAKs immediately upon gap detection.
The monitoring thread caught the receiver at a time that some NAKs were
still in their initial delay interval.

Also note that there were NCFs.
In fact, about 10% of the NAKs generated NCFs, a high number.
Something is definitely wrong (which will become clear later).

Finally, the first transport session has a large "uninteresting topic" count
(1806).
Fully half of the received messages are not subscribed by the application.
This represents a lot of wasted effort by UM
and suggests that the publisher should map its two topics to separate
transport sessions.

In the real world, correcting a large "uninteresting topic" count is sometimes
all that is needed to eliminate loss.
(In this example, the loss is artificially introduced and is not load-based.)

# PACKET CAPTURE ANALYSIS

Run the WireShark application and read the "test.pcap" file.

Set up protocols.
(These settings are temporary and will go away when WireShark is restarted.
For permanent changes, use "preferences".)

Right-click on the third packet -> "Decode As..."
* Double-click on "35101", replace with "12965", "Enter".
Double-click on "none" (under Current), select "LBMR", "Enter".
* Click the "duplicate" button (right of the "-" button), "Enter".
Double-click on "35101", replace with "12090", "Enter".
Double-click on "none" (under Current), select "LBT-RM", "Enter".
* Click the "duplicate" button (right of the "-" button), "Enter".
Double-click on "12090", replace with "12091", "Enter".
* Click the "duplicate" button (right of the "-" button), "Enter".
Double-click on "12091", replace with "14400", "Enter".

The "Wireshark Decode As..." should now look like this:
````
Field      Value   Type               Default   Current
UDP port   12965   Integer, base 10   (none)    LBMR
UDP port   12090   Integer, base 10   (none)    LBT-RM
UDP port   12091   Integer, base 10   (none)    LBT-RM
UDP port   14400   Integer, base 10   (none)    LBT-RM
````

* Click "OK".

## Find First NAK

In the "Apply a display filter..." box, enter "lbtrm.nak", "Enter".
The first displayed packet should be #111.

Select 111. The "Info" column should be, "NAK 2 naks Port 12090 ID 0xf9d74f3e".
This was sent by the subscriber to the publisher.
The "ID" is the session ID.
So this NAK corresponds to the monitoring data transport session:
````
Source: LBTRM:10.29.4.121:12090:f9d74f3e:239.101.3.10:14400
````
In the middle pane, expand "LBT-RM Protocol", "NAK Header", "NAK List".
There are two entries: "4" and "1d". (These are hexadecimal numbers.)
Also note the time: "1.281" seconds.

## Find the Corresponding Data Packets

In the "Apply a display filter..." box, enter "lbtrm.data.sqn==0x4", "Enter".
There should be three packets:
````
57      1.224170   ...   DATA sqn 0x4 Port 12090 ID 0xf9d74f3e DATA
112     1.281163   ...   DATA(RX) sqn 0x4 Port 12090 ID 0xf9d74f3e DATA
161     1.325048   ...   DATA sqn 0x4 Port 12091 ID 0xa7f10561 DATA
````
Packet 161 is from a different transport session (...561) and can be ignored.

Packet 57 was the original transmission of sqn 0x4.
The receiver did not get that packet.
But the receiver could not detect the gap until sqn 0x5,
Then the retransmission happened at packet 112, which was right after the NAK.

Let's find the original data packet by filtering on "lbtrm.data.sqn==0x5".
````
58 1.225 ... DATA sqn 0x5 Port 12090 ID 0xf9d74f3e DATA
163 ...
````

So packet 57 was lost, and the receiver detected this with packet 58,
at time 1.225.
The NAK was sent at time 1.281, 56 ms after the gap was detected.
This corresponds to the configuration option
[transport_lbtrm_nak_initial_backoff_interval (receiver)](https://ultramessaging.github.io/currdoc/doc/Config/html1/index.html#transportlbtrmnakinitialbackoffintervalreceiver),
which is not present in the "demo.cfg" config file, and defaults to 50 ms.
But remember that this value is randomized between 0.5x and 1.5x,
so the NAK delay could have been anywhere between 25 ms and 75 ms.

For completeness, let's find data packet 0x1d by filtering on
"lbtrm.data.sqn==0x1d".
````
82  1.250 ... DATA sqn 0x1d Port 12090 ID 0xf9d74f3e DATA
113 1.281 ... DATA(RX) sqn 0x1d Port 12090 ID 0xf9d74f3e DATA
216 1.351 ... DATA sqn 0x1d Port 12091 ID 0xa7f10561 DATA
````
As before,
packet 261 is from a different transport session (...561) and can be ignored.

The original was sent in packet 82, which was during the time of packet 57's
initial backoff interval.
So it was added to the list of packets that need to be NAKed.
I.e., it did not get its own initial backoff interval; the first loss defines
the start of the backoff interval. Subsequent losses before backoff expiration
are simply added to the NAK list.

It is rare to see one or two lost packets in a real-world loss situation.
There might be hundreds of lost packets detected within a very short time,
usually due to a burst of incoming traffic.

## Find First NCF

In the "Apply a display filter..." box, enter "lbtrm.nak", "Enter".
The first displayed packet should be:
````
816   1.633756   ...  NCF 1 ncf Port 12090 ID 0xf9d74f3e
...
````

Select 816. The "Info" column should be, "NCF 1 ncfs Port 12090 ID 0xf9d74f3e".
This was sent from the publisher to all subscribers.
Its purpose is to inform any subscriber that sent the corresponding NAK
that the publisher is refusing to send the retransmission.

In the middle pane, expand "LBT-RM Protocol", "NAK Confirmation Header".
The "Reason" is "NAK Ignored (0x1)", which means that the NAK arrived too
soon after the source had already sent the retransmission for the packet(s).
Expand the "NCF List".
There is one entry: 0xb89.

Since this is sent in response to NAK for sequence 0xb8,
let's look for that NAK.
Filter on "lbtrm.nak.list.nak==0xb8".
You should see:
````
 484   1.473572  ...  NAK 3 naks Port 12090 ID 0xf9d74f3e
 807   1.633581  ...  NAK 9 naks Port 12090 ID 0xf9d74f3e
3085   2.632711  ...  NAK 2 naks Port 12090 ID 0xf9d74f3e
````

Now let's find the transmissions of the data packet.
Filter on "lbtrm.
````
 356 1.416980   ...   DATA sqn 0xb8 Port 12090 ID 0xf9d74f3e
 487 1.473698   ...   DATA(RX) sqn 0xb8 Port 12090 ID 0xf9d74f3e
 574 1.517104   ...   DATA sqn 0xb8 Port 12091 ID 0xa7f10561 
3086 2.632898   ...   DATA(RX) sqn 0xb8 Port 12090 ID 0xf9d74f3e
````
Packet 574 is for a different transport session and can be ignored.

So we have a data packet at 1.414, which was lost.
The first NAK (#484) came at 1.473, 59 milliseconds later.
The retransmission came right away, within the same millisecond,
but that was also lost.

The second NAK (#807) came at 1.633, 160 milliseconds after the first.
This corresponds to the configuration option
[transport_lbtrm_nak_backoff_interval (receiver)](https://ultramessaging.github.io/currdoc/doc/Config/html1/index.html#transportlbtrmnakbackoffintervalreceiver),
which is not present in the "demo.cfg" config file, and defaults to 200 ms.
But remember that this value is randomized between 0.5x and 1.5x,
so the NAK delay could have been anywhere between 150 ms and 250 ms.
So the timing of the second NAK is correct.
And there were no other NAKs within the same timeframe.

The "NAK Ignored" NCF is controlled by the configuration option
[transport_lbtrm_ignore_interval (source)](https://ultramessaging.github.io/currdoc/doc/Config/html1/index.html#transportlbtrmignoreintervalsource),
which is not present in the "demo.cfg" config file, and defaults to 500 ms.

So here's what happened.
The receiver lost the original data packet with sqn 0xb8,
and it lost its retransmission.
After the proper NAK backoff of 150 to 250 ms, it sent another NAK.
But that NAK is still within the source's 500 ms ignore interval.
So instead of sending the retransmission, the source sent an NCF.

This NCF caused the receiver to wait a full second before sending a third NAK.
This corresponds to the configuration option
[ransport_lbtrm_nak_suppress_interval (receiver)](https://ultramessaging.github.io/currdoc/doc/Config/html1/index.html#transportlbtrmnaksuppressintervalreceiver),
which is not present in the "demo.cfg" config file, and defaults to 1000 ms.

Thus, the default intervals for NAK backoff and NAK ignore are not optimal.
If an original packet and its first retransmission are lost,
the second NAK is guaranteed to generate an NCF.

Informatica recommends shortening the source's ignore interval and
lengthening the NAK backoff interval:
````
source transport_lbtrm_ignore_interval 200
receiver transport_lbtrm_nak_backoff_interval 400
````
Now the NAK backoff interval will vary between 200 and 600,
and will never be below the ignore interval of 200.

Some might object to lengthening the NAK backoff since low latency is
an important goal.
However, in the real world,
if you've lost both the original packet and the initial retransmission,
then you probably had a severe traffic overload.
Sending retransmissions on top of the already overloading traffic just
makes the situation worse.
Better to wait extra time to let the burst subside.
