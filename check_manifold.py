"""
check_manifold.py — scan STL/3mf files and report non-manifold edge counts.

Usage:
    python check_manifold.py [directory]          # default: STL/
    python check_manifold.py path/to/file.stl     # single file
"""
import sys, os, glob
from collections import defaultdict
import pymeshlab

def check_file(path):
    ms = pymeshlab.MeshSet()
    try:
        ms.load_new_mesh(path)
    except Exception as e:
        return None, str(e)

    faces = ms.current_mesh().face_matrix()
    edge_count = defaultdict(int)
    for f in faces:
        for a, b in ((f[0],f[1]), (f[1],f[2]), (f[0],f[2])):
            edge_count[(min(a,b), max(a,b))] += 1

    boundary = sum(1 for c in edge_count.values() if c == 1)
    nm_edges = sum(1 for c in edge_count.values() if c > 2)

    return {"nm_edges": nm_edges, "boundary": boundary}, None


def scan(target):
    if os.path.isfile(target):
        paths = [target]
        base  = os.path.dirname(target)
    else:
        exts = ("*.stl", "*.STL", "*.3mf")
        paths = []
        for ext in exts:
            paths += glob.glob(os.path.join(target, "**", ext), recursive=True)
        paths.sort()
        base = target

    if not paths:
        print(f"No STL/3mf files found in {target}")
        return

    # Deduplicate by resolved absolute path
    seen = set()
    unique = []
    for p in paths:
        ap = os.path.abspath(p)
        if ap not in seen:
            seen.add(ap)
            unique.append(p)
    paths = unique

    results = []
    for path in paths:
        result, err = check_file(path)
        rel = os.path.relpath(path, base)
        results.append((rel, result, err))

    W = max(len(r[0]) for r in results) + 2
    header = f"{'File':<{W}}  {'NM Edges':>9}  {'Boundary':>9}  Status"
    print(header)
    print("-" * len(header))

    any_bad = False
    for rel, result, err in results:
        if err:
            print(f"{rel:<{W}}  ERROR: {err}")
            continue
        nm  = result["nm_edges"]
        bnd = result["boundary"]
        ok  = (nm == 0 and bnd == 0)
        flag = "OK" if ok else "NON-MANIFOLD"
        if not ok:
            any_bad = True
        print(f"{rel:<{W}}  {nm:>9}  {bnd:>9}  {flag}")

    print()
    print("PASS" if not any_bad else "FAIL — see NON-MANIFOLD rows above")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "STL")
    scan(target)
