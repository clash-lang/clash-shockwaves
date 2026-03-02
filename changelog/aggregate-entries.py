#!/usr/bin/env python3

import os, time
from collections import defaultdict as ddict
from util import *

entries = [f for f in os.listdir() if not "." in f and not f.startswith("_") and not f.startswith(".")]

print("Entries:")
for e in entries:
    print("-",e)

changes = ddict(list)

for e in entries:
    with open(e,"r") as fp:
        txt = fp.read()
    try:
        variant,descr = txt.split("\n",1)
    except:
        raise Exception("Error reading "+e)
    changes[variant].append(descr)

blocks = sorted(changes.items(),key=lambda i: variants.index(i[0]) if i[0] in variants else -1)

version = smart_input("Version (i.e. 2.0.1hsd)",str)
timestamp = time.strftime("%d %b %Y")

print()
print("CHANGELOG MARKDOWN")
print()

print(f"# v{version} *{timestamp}*")
print()

for v,ds in blocks:
    print(v.capitalize()+":")
    for d in ds:
        print("- "+d.replace("\n","\n  "))
    print()
