#!/usr/bin/env python2

import serial, sys

def convert(d):
    return chr(int(d));

if len(sys.argv) < 2:
    sys.exit(1);

if len(sys.argv) == 3:
    f = open(sys.argv[2], 'r');
    data = f.readlines();
    print ":: read data from", sys.argv[2];
else:
    data = sys.stdin.readlines();
    print ":: read data from stdin"

if len(data) == 1: data = data[0].split(' ');

cxn = serial.Serial(sys.argv[1], 9600, parity=serial.PARITY_ODD);
#cxn = serial.Serial(sys.argv[1], 9600);
print ":: opened", cxn.portstr;

tx = "";
for d in data:
    tx += convert(d);

cxn.write(tx);

print "done"
sys.exit(0);
