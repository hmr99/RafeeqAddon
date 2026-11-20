#!/usr/bin/env python3
"""Run the Rafeeq emulator session under Lua 5.1 (via lupa).

Usage:  python3 tests/run.py [--qdb PATH_TO_QUESTIEDB] [--addon PATH]
Exit code 0 = all scenarios passed, 1 = failures.
"""
import argparse, os, sys

try:
    import lupa.lua51 as lua51
except ImportError:
    sys.exit("pip install lupa  (needs the lua51 runtime bundled with lupa)")

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser()
ap.add_argument("--qdb", default=os.environ.get("QDB_PATH", ""))
ap.add_argument("--addon", default=os.path.join(root, "Rafeeq"))
args = ap.parse_args()

os.chdir(root)
os.environ["QDB_PATH"] = os.path.abspath(args.qdb) if args.qdb else ""
os.environ["ADDON_PATH"] = os.path.abspath(args.addon)

rt = lua51.LuaRuntime(unpack_returned_tuples=True)
# lupa does not expose os.getenv values set after start on every platform; pass them explicitly
rt.execute('local e = ... ; local g = os.getenv ; os.getenv = function(k) return e[k] or g(k) end',
           rt.table_from({"QDB_PATH": os.environ["QDB_PATH"], "ADDON_PATH": os.environ["ADDON_PATH"]}))
if os.environ["QDB_PATH"]:
    os.chdir(os.environ["QDB_PATH"])
    try:
        rt.execute('''
            local config = dofile("src/config.lua")
            local emulator = dofile("emulator/metadata.lua")
            local client = dofile("emulator/client.lua")
            client.reset()
            client.install({ expansion = "Forever", faction = "Alliance", classFile = "WARRIOR",
                raceName = "Human", raceId = 1, level = 5 })
            emulator.loadAddon(config.addonName .. ".toc", config.addonName)
            QDB_PRELOADED = true
        ''')
    except Exception as e:
        print("QuestieDB load failed:", e)
    os.chdir(root)
rt.execute('dofile("tests/run.lua")')
failed = rt.eval("RESULT_FAILED") or 0
sys.exit(1 if failed else 0)
