"""Print a one-screen report for every book in data/raw.  make py F=show_report.py"""
from report import report_dir

for name, r in report_dir("data/raw").items():
    le = r["line_endings"]
    print("%-12s %8d B  %-7s bom=%-5s crlf=%-6d lf=%-6d chars=%-3d lines=%-6d blank=%.0f%% maxline=%d ctrl=%d"
          % (name, r["bytes"], r["encoding"], r["has_bom"], le["crlf"], le["lf"], r["distinct_chars"],
             r["lines"], 100 * r["blank_line_frac"], r["max_line_len"], r["control_chars"]))
    print("             non-ascii:", " ".join("%s:%d" % (c, n) for c, n in r["non_ascii"]))
