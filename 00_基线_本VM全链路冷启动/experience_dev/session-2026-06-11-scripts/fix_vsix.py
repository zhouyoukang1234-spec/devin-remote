path = r"C:\Users\Administrator\plugins\dao-vsix\src\extension.ts"
text = open(path, encoding="utf-8").read()
lines = text.split("\n")
l = lines[1817]  # source line 1818
marker = "(\\'openDevinPage"  # literal: ( \ ' openDevinPage  -- unique to the garbage
idx = l.find(marker)
assert idx != -1, "marker not found"
garbage = l[idx:]
print("GARBAGE (%d chars): %r" % (len(garbage), garbage))
# the char right before garbage must be ';'
print("char before garbage:", repr(l[idx-1]))
new_l = l[:idx]
print("new line tail:", repr(new_l[-40:]))
lines[1817] = new_l
# ensure marker no longer present anywhere
new_text = "\n".join(lines)
assert marker not in new_text, "marker still present!"
open(path, "w", encoding="utf-8", newline="").write(new_text)
print("WROTE FIX. removed", len(garbage), "chars from line 1818")
