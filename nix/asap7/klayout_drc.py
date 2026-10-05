"""asap7.lydrc (ORFS flow/platforms/asap7/drc, BSD-2, laurentc2) -> asap7.drc: the plain
DSL for `klayout -b -r asap7.drc -rd in_gds=<abs gds> -rd report_file=<abs lyrdb>`,
with the fixes below.   usage: klayout_drc.py asap7.lydrc asap7.drc"""
import html, re, sys
x = open(sys.argv[1]).read()
s = html.unescape(re.search(r"<text>(.*)</text>", x, re.S).group(1))

FIXES = [
    # S.1 (both edges > 36 nm: 18 nm) dropped every violation polygon touching a <=36 nm
    # edge -- including the 18 nm line ends of every min-width wire, so two parallel
    # 18 nm wires at ANY spacing passed. Check the long edges against each other instead.
    *[(f'{l}.space(18.nm).polygons.not_interacting({l}.edges.with_length(0..36.nm))',
       f'{l}.edges.with_length(36.nm + 1.dbu, 100.mm).space(18.nm, projection)')
      for l in ("lisd", "lig", "m1", "m2", "m3")],
    # rule names / layer typos
    ('.output("  ", "M1.S.2', '.output("M1.S.2", "M1.S.2'),
    ('.output("LISD.S.2", "LIG.S.2', '.output("LIG.S.2", "LIG.S.2'),
    ('lig.space(31.nm, euclidian).polygons.not_interacting(lisd.edges',
     'lig.space(31.nm, euclidian).polygons.not_interacting(lig.edges'),
    # GUI fallback for the report path needs an open view; batch runs must pass report_file
    ('report("ASAP7 DRC runset", File.join(File.dirname(RBA::CellView::active.filename), "6_drc_count.rpt"))',
     'raise "pass -rd report_file=<absolute path>"'),
]
for old, new in FIXES:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
hdr = ("# ASAP7 KLayout DRC. Source: OpenROAD-flow-scripts flow/platforms/asap7/drc/asap7.lydrc\n"
       "# (BSD-2, laurentc2/ASAP7_for_KLayout), converted by EDA-Packaged\n"
       "# nix/asap7/klayout_drc.py with the fixes listed there.\n"
       "# Run: klayout -b -r asap7.drc -rd in_gds=<abs gds> -rd report_file=<abs .lyrdb>\n")
open(sys.argv[2], "w").write(hdr + s)
