#!/usr/bin/env python3

import time
from util import *

title = smart_input("Entry title",lambda s:"".join(c for c in s.lower().replace(" ","_") if c.isalpha() or c.isdigit() or c=="_"))

def check_v(s):
    s = s.upper()
    sel = [v for v in variants if v.startswith(s)]
    if len(sel)==1:
        return sel[0]
    return None

variant = smart_input("Type",check_v)

print("Enter description (Markdown). Leave first line empty for multi-line input.")
description = input()
if not(description):
    lines = []

    N=3
    while lines[-N:] != [""]*N:
        lines.append(input())

    description="\n".join(lines).rstrip()

timestamp = time.strftime("%Y-%M-%d_T%H:%M:%S")
fname = f"{timestamp}_{variant}_{title}"
print("Storing to",fname)
with open(fname,"w") as fp:
    fp.write(variant+"\n"+description)
