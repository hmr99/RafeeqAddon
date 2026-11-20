#!/usr/bin/env python3
"""Bump Rafeeq's version everywhere and add a CHANGELOG section.

Usage: python3 scripts/bump.py 0.3.0 "Added X" "Fixed Y" ...
"""
import datetime, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv) < 3 or not re.fullmatch(r"\d+\.\d+\.\d+(-(alpha|beta)\d*)?", sys.argv[1]):
    sys.exit('usage: bump.py X.Y.Z[-beta1] "change 1" ["change 2" ...]')
ver, notes = sys.argv[1], sys.argv[2:]

toc = root / "Rafeeq" / "Rafeeq.toc"
toc.write_text(re.sub(r"## Version: .*", f"## Version: {ver}", toc.read_text(encoding="utf-8")), encoding="utf-8")

core = root / "Rafeeq" / "Core" / "Core.lua"
core.write_text(re.sub(r'ns\.version = "[^"]*"', f'ns.version = "{ver}"', core.read_text(encoding="utf-8")), encoding="utf-8")

cl = root / "CHANGELOG.md"
old = cl.read_text(encoding="utf-8") if cl.exists() else "# Changelog\n"
head, _, rest = old.partition("\n")
entry = f"\n## v{ver} - {datetime.date.today().isoformat()}\n" + "".join(f"- {n}\n" for n in notes)
cl.write_text(head + "\n" + entry + rest, encoding="utf-8")
print(f"Rafeeq -> v{ver}")
