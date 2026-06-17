"""
validSTL.py — validate STL files for non-manifold geometry and open boundaries.

Usage:
    python validSTL.py <file.stl>          # single file
    python validSTL.py <directory>         # all STLs in directory tree
    python validSTL.py                     # defaults to current directory

Exit code: 0 if all pass, 1 if any file has non-manifold edges.

Requires: pip install pymeshlab
"""

import sys, os
import pymeshlab

# ── ANSI colours (stripped on non-TTY) ───────────────────────────────────────
def _c(code, text):
    return f"\033[{code}m{text}\033[0m" if sys.stdout.isatty() else text

def green(t):   return _c("32", t)
def yellow(t):  return _c("33", t)
def red(t):     return _c("31", t)
def cyan(t):    return _c("36", t)
def bold(t):    return _c("1",  t)


def find_stls(path):
    if os.path.isfile(path):
        return [path]
    found = []
    for root, _, files in os.walk(path):
        for f in sorted(files):
            if f.lower().endswith(".stl"):
                found.append(os.path.join(root, f))
    return sorted(found)


def analyze(path):
    """Return topology dict or raise on load failure."""
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(path)
    return ms.get_topological_measures()


def status_label(t):
    nm  = t["non_two_manifold_edges"]
    bnd = t["boundary_edges"]
    if nm > 0:
        return red("FAIL"), "non-manifold edges"
    if bnd > 0:
        return yellow("OPEN"), "open boundary (not watertight)"
    return green("OK"), ""


def report_file(path, t):
    nm    = t["non_two_manifold_edges"]
    bnd   = t["boundary_edges"]
    faces = t["faces_number"]
    verts = t["vertices_number"]
    holes = t["number_holes"]
    comps = t["connected_components_number"]
    label, note = status_label(t)

    detail = (f"faces={faces:>6}  verts={verts:>6}  "
              f"nm={nm:>4}  bnd={bnd:>4}  "
              f"holes={holes:>3}  shells={comps}")
    suffix = f"  [{note}]" if note else ""
    print(f"  {detail}  {label}{suffix}")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "."
    files  = find_stls(target)

    if not files:
        print(f"No STL files found in: {target}")
        sys.exit(0)

    print(bold(f"\nvalidSTL — {len(files)} file(s) in {os.path.abspath(target)}\n"))

    counts = {"ok": 0, "open": 0, "fail": 0, "err": 0}
    W = max(len(os.path.relpath(f, target)) for f in files)

    for path in files:
        rel = os.path.relpath(path, target)
        print(f"  {cyan(rel):<{W + 10}}", end="  ")
        sys.stdout.flush()
        try:
            t = analyze(path)
            report_file(path, t)
            nm  = t["non_two_manifold_edges"]
            bnd = t["boundary_edges"]
            if   nm  > 0: counts["fail"] += 1
            elif bnd > 0: counts["open"] += 1
            else:         counts["ok"]   += 1
        except Exception as e:
            print(red(f"ERROR: {e}"))
            counts["err"] += 1

    # ── Summary ───────────────────────────────────────────────────────────────
    total = len(files)
    print()
    print("=" * 72)
    parts = [
        green(f"{counts['ok']} OK"),
        yellow(f"{counts['open']} OPEN"),
        red(f"{counts['fail']} FAIL"),
    ]
    if counts["err"]:
        parts.append(red(f"{counts['err']} ERROR"))
    print(f"  {total} file(s):  " + "  |  ".join(parts))

    if counts["fail"] > 0:
        print(red("\n  Non-manifold edges detected — check before slicing."))
    elif counts["open"] > 0:
        print(yellow("\n  Open boundaries detected — slicer may auto-repair."))
    else:
        print(green("\n  All files are watertight manifolds."))

    sys.exit(1 if counts["fail"] > 0 else 0)


if __name__ == "__main__":
    main()
