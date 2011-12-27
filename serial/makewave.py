#!/usr/bin/env python

from math import *

def f(x):
    # 750hz notch
    #if x in range(12,40) or x in range(20,60): return 0;
    #else: return 255;

    # quadratic notch
    #return (1*(x-16))**2

    # high pass
    #return x**2

    # like am radio
    """
    if x in range(5,400):
        return -(1/60.*(x-115))**2+255
    else:
        return 0
    """

    # antialiasing
    if x < 32: return 0.5 * x**2;
    elif x < 256: return 80*log( - x + 256 );
    else: return 0

    #_ = 10
    #if x > _ : return 0; 
    #else: return 255*


##############

import string, sys

N = 1024;
y = [];

for x in xrange(N):
    # make a symmetric graph
    if x <= N/2:
        _ = f(x);
    else:
        _ = f(N-x);

    y.append(str( max( 0, min( 255, int(round(_)) ) ) ));

_ = string.join(y, "\n")

if len(sys.argv) < 2:
    print _;
else:
    f = open(sys.argv[1], 'w');
    f.write(_);
    f.close();

