
variants = "ADDED CHANGED DEPRICATED REMOVED FIXED".split()

def smart_input(s,f):
    while True:
        ans = f(input(s+": "))
        if ans is None:
            print("Invalid input")
            continue
        if input(ans+" - Confirm? [y/N]:") == "N":
            continue
        return ans
