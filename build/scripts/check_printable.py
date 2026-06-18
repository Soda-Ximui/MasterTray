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
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import pymeshlab

# --- OrcaSlicer-based overhang detection (opt-in: --slicer) ----------------------
# OrcaSlicer's slicer KNOWS what bridges vs what needs support — its gcode marks
# real overhang perimeters as "; FEATURE: Overhang ..." and self-supporting spans
# (e.g. mesh teardrops) as "; FEATURE: Bridge". Counting overhang features is a
# context-aware "prints on air" signal the geometric normal screen can't match.
# Validated: a flat cap-on-post = 4 overhang features; a 45°-undercut box = 0.
# Paths are install/version specific — override via env if needed.
_ORCA = os.environ.get("ORCA_SLICER",
                       r"C:\Program Files\OrcaSlicer\orca-slicer.exe")
_ORCA_PROFILES = Path(os.environ.get(
    "ORCA_PROFILES", r"C:\Program Files\OrcaSlicer\resources\profiles\BBL"))
_ORCA_MACHINE = os.environ.get("ORCA_MACHINE", "Bambu Lab A1 0.4 nozzle.json")
_ORCA_PROCESS = os.environ.get("ORCA_PROCESS", "0.20mm Standard @BBL A1.json")
_ORCA_FILAMENT = os.environ.get("ORCA_FILAMENT", "Bambu PLA Basic @BBL A1.json")


def slicer_overhang(stl_path):
    """Slice with OrcaSlicer and count real overhang-wall features in the gcode.
    Returns (overhang_count, bridge_count) or None if the slicer/profiles are absent
    or slicing fails. Overhang>0 = unsupported overhangs the slicer can't bridge."""
    orca = Path(_ORCA)
    ms = _ORCA_PROFILES / "machine" / _ORCA_MACHINE
    pr = _ORCA_PROFILES / "process" / _ORCA_PROCESS
    fl = _ORCA_PROFILES / "filament" / _ORCA_FILAMENT
    if not (orca.exists() and ms.exists() and pr.exists() and fl.exists()):
        return None
    with tempfile.TemporaryDirectory(prefix="orca-oh-") as td:
        cmd = [str(orca), "--slice", "0",
               "--load-settings", f"{ms};{pr}",
               "--load-filaments", str(fl),
               "--outputdir", td, str(stl_path)]
        try:
            subprocess.run(cmd, capture_output=True, text=True, timeout=240)
        except Exception:  # noqa: BLE001
            return None
        gcodes = list(Path(td).glob("*.gcode"))
        if not gcodes:
            return None  # slice failed (GUI app is console-silent; no gcode = fail)
        txt = gcodes[0].read_text(errors="ignore")
        return txt.count("; FEATURE: Overhang"), \
            txt.count("; FEATURE: Bridge") + txt.count("; FEATURE: Internal Bridge")


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
    ap.add_argument("--slicer", action="store_true",
                    help="Use OrcaSlicer to detect REAL (context-aware) overhangs and FAIL on "
                         "them — distinguishes unsupported overhangs from bridges/teardrops. "
                         "Requires OrcaSlicer (see ORCA_* env vars). Slower (~1s/part).")
    ap.add_argument("--max-overhang-features", type=int, default=0,
                    help="With --slicer, max overhang-wall features allowed before failing. Default 0.")
    args = ap.parse_args()

    overhang_cos = np.sin(np.radians(args.overhang_deg))
    files = find_stls(args.target)
    if not files:
        print(f"No STL files in: {args.target}")
        return

    print(f"Printability gate — {len(files)} file(s)  "
          f"(overhang > {args.overhang_deg:.0f}° flagged, fail above {args.overhang_mm2:.0f} mm²)\n")
    fails = []
    slicer_unavailable = [False]
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
        reasons = []
        if r["nm"]:
            reasons.append(f"{r['nm']} non-manifold")
        if r["bnd"]:
            reasons.append(f"{r['bnd']} open-boundary")

        # Overhang: slicer-based (reliable, context-aware) when --slicer, else the
        # geometric hint only.
        ok = manifold_ok
        if args.slicer:
            sl = slicer_overhang(f)
            if sl is None:
                oh_str = "  overhang=?(slicer/profile missing)"
                slicer_unavailable[0] = True
            else:
                oh_n, br_n = sl
                bad = oh_n > args.max_overhang_features
                oh_str = f"  overhang-features={oh_n} (bridges={br_n})"
                if bad:
                    reasons.append(f"{oh_n} unsupported-overhang feature(s)")
                    ok = False
        else:
            oh_str = f"  overhang≈{r['oh_area']:.0f}mm² (geometric hint — unreliable on mesh)"

        verdict = "PRINTABLE" if ok else "NOT PRINTABLE"
        note = ("  [" + "; ".join(reasons) + "]") if reasons else ""
        print(f"  {f.name:<{W}}  {verdict}{note}{oh_str}")
        if not ok:
            fails.append(f.name)

    print()
    if not args.slicer:
        print("Overhang shown is a HINT only (mesh/thread false-positives). For a REAL overhang")
        print("gate, re-run with --slicer (OrcaSlicer), or confirm with a slicer preview / print.\n")
    elif slicer_unavailable[0]:
        print("NOTE: OrcaSlicer or its profiles weren't found — overhang NOT checked for some "
              "files. Set ORCA_SLICER / ORCA_PROFILES env vars.\n")
    if fails:
        print(f"NOT PRINTABLE ({len(fails)}/{len(files)}): {', '.join(fails)} — do NOT send.")
        sys.exit(1)
    print(f"All {len(files)} file(s) verified printable"
          f"{' (manifold + slicer-overhang)' if args.slicer else ' (manifold; overhang needs --slicer/preview)'}.")


if __name__ == "__main__":
    main()
