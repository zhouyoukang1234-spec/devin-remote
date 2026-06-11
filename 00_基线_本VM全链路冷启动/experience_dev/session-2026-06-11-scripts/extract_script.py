import io, re
html = io.open(r"C:\Users\Administrator\dao\gen_middle.html", encoding="utf-8").read()
# grab all <script>...</script> blocks; the main one is the largest
blocks = re.findall(r"<script>(.*?)</script>", html, flags=re.S)
blocks.sort(key=len)
main = blocks[-1]
io.open(r"C:\Users\Administrator\dao\gen_script.js", "w", encoding="utf-8").write(main)
print("blocks:", [len(b) for b in blocks])
print("main script lines:", main.count("\n")+1, "chars:", len(main))
