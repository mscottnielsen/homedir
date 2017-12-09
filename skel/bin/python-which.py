#!/usr/bin/env python3
from __future__ import print_function
import sys
import os
import importlib

##
## Run with python2/python3/virtualenv python to find module version and install path
##
## usage:  
## $ python3 python-which.py keras
##  Using TensorFlow backend.
##  module=keras version=2.0.4   path=/usr/local/lib/python3.5/dist-packages/keras
##
## $ python2 python-which.py keras
## Using TensorFlow backend.
##  module=keras version=2.0.2   path=/usr/local/lib/python2.7/dist-packages/keras
##

#python -c "import sys,${m}; print(sys.modules['${m}'])" 2>/dev/null || echo

args = sys.argv[1:]
if len(args) > 0:
    name = args[0]
    path, version = ("n/a", "n/a")
    try:
        m = importlib.import_module(args[0])
        path = os.path.dirname(m.__file__)
        try:
            version = m.__version__
        except Exception as e:
            print("** warning: {}".format(e))
    except Exception as e:
        print("** error: {}".format(e))

    print("  module={}\tversion={}\tpath={}".format(name, version, path))
else:
    print("** error: expecting python module")
    print("** usage: python {} {}".format(__file__,"{module}"))

