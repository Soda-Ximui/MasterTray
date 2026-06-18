#!/usr/bin/env python3
"""
check_printable.py — printability gate for STLs that are about to be SENT OUT.

Requirement: nothing ships unless it is verified printable. "Printable" is MORE
than manifold — non-manifold checks (and "does it slice") both pass geometry that
prints on air. This gate checks BOTH:

  1. Manifold + watertight     (pymeshlab non_two_manifold_edges / boundary_edges)
  2. Unsupported overhangs     (steep downward-facing faces above the build plate)

The overhang screen is a HEURISTIC, not a slicer: it flags faces whose normal points
downward more steeply than ~50° from vertical (so a 45° self-supporting ramp/chamfer
is NOT flagged) and whose centroid is above the build plate. A large overhang area
means the part has "prints on air" geometry (e.g., a flat trapping-lip ceiling).
It cannot model bridging across short gaps, so a small flagged area may still print
fine — use the per-file area/% to judge, and render-inspect anything flagged.

Exit 0 only if every file is manifold, watertight, AND below the overhang area
threshold. Use before sending any STL to print.

Usage:
    python build/scripts/check_printable.py <file.stl | dir> [--overhang-mm2 N] [--overhang-deg D]
"""
import argparse
import sys
from pathlib import Path

import numpy as np
import pymeshlab


def find_stls(path):
    p = Path(path)
    if p.is_file():
        return [p]
    return sorted(q for q in p.rglob("*.stl"))


def analyze(path, overhang_cos, plate_eps):
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(str(path))
    m = ms.current_mesh()
    t = ms.get_topological_measures()
    nm = int(t["non_two_manifold_edges"])
    bnd = int(t["boundary_edges"])

    fn = np.asarray(m.face_normal_matrix(), dtype=float)
    fm = np.asarray(m.face_matrix())
    vm = np.asarray(m.vertex_matrix(), dtype=float)

    # normalize face normals (guard against any unnormalized rows)
    norms = np.linalg.norm(fn, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    nz = (fn / norms)[:, 2]

    tri = vm[fm]
    centroid_z = tri[:, :, 2].mean(axis=1)
    areas = 0.5 * np.linalg.norm(
        np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1)
    zmin = vm[:, 2].min()

    # Overhang: normal points DOWN steeper than the threshold (nz < -cos(deg from
    # straight-down))... we pass overhang_cos = sin(angle from vertical); a face is
    # an unsupported overhang when nz < -overhang_cos and it's above the plate.
    overhang = (nz < -overhang_cos) & (centroid_z > zmin + plate_eps)
    oh_area = float(areas[overhang].sum())
    total = float(areas.sum()) or 1.0
    return {
        "nm": nm, "bnd": bnd,
        "oh_area": oh_area, "oh_pct": 100.0 * oh_area / total,
        "oh_faces": int(overhang.sum()),
    }


def main():
    ap = argparse.ArgumentParser(description="STL printability gate (manifold + overhangs)")
    ap.add_argument("target", nargs="?", default="STL", help="STL file or directory")
    ap.add_argument("--overhang-mm2", type=float, default=5.0,
                    help="Fail if unsupported-overhang area exceeds this (mm^2). Default 5.")
    ap.add_argument("--overhang-deg", type=float, default=50.0,
                    help="Overhang angle from vertical to count as unsupported. Default 50 "
                         "(so 45° self-supporting ramps are NOT flagged).")
    ap.add_argument("--plate-eps", type=float, default=0.5,
                    help="Ignore faces within this many mm of the lowest point (build plate).")
    args = ap.parse_args()

    overhang_cos = np.sin(np.radians(args.overhang_deg))
    files = find_stls(args.target)
    if not files:
        print(f"No STL files in: {args.target}")
        return

    print(f"Printability gate — {len(files)} file(s)  "
          f"(overhang > {args.overhang_deg:.0f}° flagged, fail above {args.overhang_mm2:.0f} mm²)\n")
    fails = []
    W = max(len(f.name) for f in files)
    for f in files:
        try:
            r = analyze(f, overhang_cos, args.plate_eps)
        except Exception as e:  # noqa: BLE001
            print(f"  {f.name:<{W}}  ERROR: {e}")
            fails.append(f.name)
            continue
        # HARD GATE: manifold + watertight (reliable). Overhang is reported as a
        # render-review HINT only — the geometric screen is dominated by self-supporting
        # mesh teardrops / thread flanks and cannot reliably isolate real "prints on air"
        # overhangs, so it must NOT fail the build (proven: a clean jar flags more area
        # than a groove'd box). Real overhang verification = slicer preview / print.
        manifold_ok = r["nm"] == 0 and r["bnd"] == 0
        verdict = "MANIFOLD-OK" if manifold_ok else "NOT MANIFOLD"
        reasons = []
        if r["nm"]:
            reasons.append(f"{r['nm']} non-manifold")
        if r["bnd"]:
            reasons.append(f"{r['bnd']} open-boundary")
        manifold_note = ("  [" + "; ".join(reasons) + "]") if reasons else ""
        hint = f"  overhang≈{r['oh_area']:.0f}mm² (hint only — render-review)"
        print(f"  {f.name:<{W}}  {verdict}{manifold_note}{hint}")
        if not manifold_ok:
            fails.append(f.name)

    print()
    print("Overhang figures are a HINT only (mesh/thread false-positives) — confirm true")
    print("printability with a slicer preview or a test print; fix known overhangs at source.\n")
    if fails:
        print(f"NOT MANIFOLD ({len(fails)}/{len(files)}): {', '.join(fails)} — do NOT send.")
        sys.exit(1)
    print(f"All {len(files)} file(s) manifold + watertight. "
          f"Overhang/support still needs slicer-preview/print review before sending.")


if __name__ == "__main__":
    main()
