line = open(r"C:\Users\Administrator\dao\gen_script.js", encoding="utf-8").read().split("\n")[90]
# JS string-state scan: line is concatenation using single-quote strings
in_str = False
esc = False
out = []
for i, ch in enumerate(line):
    if in_str:
        if esc:
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == "'":
            in_str = False
    else:
        if ch == "'":
            in_str = True
        elif ch == "&":
            out.append(i)
print("bare & positions (outside strings):", out)
for p in out:
    print("--- ctx around", p, "---")
    print(repr(line[max(0,p-80):p+80]))
