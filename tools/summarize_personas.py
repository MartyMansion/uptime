#!/usr/bin/env python3
"""Summarize persona_*.txt files into a markdown table (stdout)."""
import sys, glob, json, re, os
d = sys.argv[1]
rows = []
for f in sorted(glob.glob(os.path.join(d, "persona_*.txt"))):
    t = open(f).read()
    def g(pat, default=""):
        m = re.search(pat, t, re.M); return m.group(1) if m else default
    p = g(r"^PERSONA (\S+)")
    runs = int(g(r"RUNS (\d+)", 0)); probs = int(g(r"PROBLEMS (\d+)", 0))
    end = json.loads(g(r"^ENDINGS (.*)$", "{}"))
    end = {k: v for k, v in end.items() if ":" not in k}
    inc = re.search(r"^INCIDENTS (\d+) \(after-hours (\d+), breached (\d+)\)", t, re.M)
    ps = json.loads(g(r"^PSTATS (.*)$", "{}"))
    byhand = ps.get("inc_by_hand", 0)
    farm = g(r"^FARM (.*)$")
    bal = g(r"^BALANCE \S+ \| (.*)$")
    top = ", ".join(f"{k} {100*v//max(1,runs)}%" for k, v in sorted(end.items(), key=lambda x: -x[1]))
    br = f"{int(inc.group(3))}/{byhand}" if inc else "-"
    rows.append((p, runs, probs, top, br, farm, bal))
print("| Persona | Weeks | Problems | Endings | Breached / hand-solved incidents | Farm | Avg end state |")
print("|---|---|---|---|---|---|---|")
for r in rows: print("| " + " | ".join(str(x) for x in r) + " |")
