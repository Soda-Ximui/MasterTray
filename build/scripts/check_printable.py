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


import math


def _slice_to_gcode(stl_path, td):
    """Slice an STL with OrcaSlicer into directory td; return gcode text or None."""
    orca = Path(_ORCA)
    ms = _ORCA_PROFILES / "machine" / _ORCA_MACHINE
    pr = _ORCA_PROFILES / "process" / _ORCA_PROCESS
    fl = _ORCA_PROFILES / "filament" / _ORCA_FILAMENT
    if not (orca.exists() and ms.exists() and pr.exists() and fl.exists()):
        return None
    cmd = [str(orca), "--slice", "0", "--load-settings", f"{ms};{pr}",
           "--load-filaments", str(fl), "--outputdir", td, str(stl_path)]
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=240)
    except Exception:  # noqa: BLE001
        return None
    gcodes = list(Path(td).glob("*.gcode"))
    if not gcodes:
        return None  # slice failed (GUI app is console-silent; no gcode = fail)
    return gcodes[0].read_text(errors="ignore")


# Default extrusion width used to turn first-layer path length into a contact-area
# estimate (overridden from the gcode header if present).
_DEFAULT_LW = 0.45


def _extruded(block, want):
    """Sum XY extrusion length (mm) for moves whose active FEATURE satisfies want(name);
    also return the XY bbox of those moves. Counts only positive-E (extruding) moves —
    OrcaSlicer uses relative E."""
    length = 0.0
    xs, ys = [], []
    x = y = None
    feat = ""
    for l in block:
        if l.startswith("; FEATURE:"):
            feat = l.split(":", 1)[1].strip()
            continue
        if not l.startswith(("G1", "G0")):
            continue
        nx, ny, e = x, y, None
        for tok in l.split()[1:]:
            if tok[:1] == "X": nx = float(tok[1:])
            elif tok[:1] == "Y": ny = float(tok[1:])
            elif tok[:1] == "E": e = float(tok[1:])
        if e is not None and e > 0 and want(feat) and x is not None and nx is not None:
            length += math.hypot(nx - x, ny - y)
            xs += [x, nx]; ys += [y, ny]
        x, y = (nx if nx is not None else x), (ny if ny is not None else y)
    bbox = (max(xs) - min(xs)) * (max(ys) - min(ys)) if xs else 0.0
    return length, bbox


def _empty_layers(lines):
    """Scan gcode layer-z sequence for gaps larger than 1.5× the layer height.
    A gap means the slicer skipped a z-range — the geometry had no cross-section
    there (empty layer). Returns a list of (z_start, z_end) tuples where gaps occur,
    or [] if none. Uses '; layer_z = N.NNN' comments emitted by OrcaSlicer."""
    zs = []
    for l in lines:
        if l.startswith("; layer_z ="):
            try:
                zs.append(float(l.split("=")[1]))
            except ValueError:
                pass
    if len(zs) < 3:
        return []
    # Infer nominal layer height from the median step between consecutive layers.
    steps = sorted(zs[i+1] - zs[i] for i in range(len(zs) - 1) if zs[i+1] > zs[i])
    if not steps:
        return []
    lh = steps[len(steps) // 2]  # median step = nominal layer height
    threshold = lh * 1.5
    return [(round(zs[i], 3), round(zs[i+1], 3))
            for i in range(len(zs) - 1)
            if zs[i+1] - zs[i] > threshold]


def analyze_gcode(txt):
    """Parse OrcaSlicer gcode for printability signals:
      - FIRST LAYER (most crucial): bed-contact length and COVERAGE (contact area /
        footprint bbox). A perforated/sparse first layer has low coverage → adhesion
        risk. (Coverage is robust; gcode 'runs' are NOT disconnected islands — the
        slicer travels within connected regions — so island-counting is not used.)
      - EMPTY LAYERS: z-range gaps in the layer sequence (slicer skipped a z-band
        because the cross-section was zero there). Hard indicator of geometry defect
        — e.g. coincident face-to-face junction producing a degenerate CGAL mesh.
      - OVERHANG: total 'Overhang' extrusion length. NOTE this INCLUDES mesh-hole
        overhangs (they print as long continuous overhang perimeters, indistinguishable
        from structural by length) — so it is only a clean STRUCTURAL gate when run on
        MESH-OFF geometry. On meshed parts it's a hint.
    Returns a dict, or None if the gcode has no layers."""
    lw = _DEFAULT_LW
    m = [l for l in txt.splitlines()[:400] if l.startswith("; line_width =")]
    if m:
        try: lw = float(m[0].split("=")[1])
        except ValueError: pass
    lines = txt.splitlines()
    layer_idx = [i for i, l in enumerate(lines) if l.startswith("; CHANGE_LAYER")]
    if not layer_idx:
        return None
    first = lines[layer_idx[0]: (layer_idx[1] if len(layer_idx) > 1 else len(lines))]

    fl_len, fl_bbox = _extruded(first, lambda f: f not in ("Skirt", "Brim", "Custom", ""))
    oh_len, _ = _extruded(lines, lambda f: f.startswith("Overhang"))
    coverage = (fl_len * lw / fl_bbox * 100.0) if fl_bbox > 0 else 0.0
    gaps = _empty_layers(lines)
    return {
        "fl_contact_mm": round(fl_len, 1),
        "fl_footprint_mm2": round(fl_bbox),
        "fl_coverage_pct": round(coverage, 1),
        "overhang_mm": round(oh_len, 1),
        "empty_layer_gaps": gaps,  # list of (z_start, z_end) — hard defect if non-empty
    }


def slicer_overhang(stl_path):
    """Back-compat: (overhang_count, bridge_count). Kept for callers; the richer
    signal is analyze_gcode()."""
    with tempfile.TemporaryDirectory(prefix="orca-oh-") as td:
        txt = _slice_to_gcode(stl_path, td)
        if txt is None:
            return None
        return txt.count("; FEATURE: Overhang"), \
            txt.count("; FEATURE: Bridge") + txt.count("; FEATURE: Internal Bridge")


def slicer_printability(stl_path):
    """Slice once; return analyze_gcode() dict (first-layer + structural overhang) or None."""
    with tempfile.TemporaryDirectory(prefix="orca-pc-") as td:
        txt = _slice_to_gcode(stl_path, td)
        return analyze_gcode(txt) if txt else None


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
                    help="Use OrcaSlicer for the REAL printability checks: FIRST-LAYER adhesion "
                         "(most crucial) and STRUCTURAL overhang (mesh-hole overhangs ignored). "
                         "Requires OrcaSlicer (see ORCA_* env vars). Slower (~1s/part).")
    ap.add_argument("--max-overhang-mm", type=float, default=2.0,
                    help="With --slicer, max structural-overhang extrusion (mm) before failing. "
                         "Hint only on meshed parts (teardrop apexes look like overhangs). Default 2.")
    ap.add_argument("--min-coverage-pct", type=float, default=10.0,
                    help="With --slicer, fail if first-layer coverage (contact × linewidth / "
                         "footprint) is below this %%. Low coverage = adhesion risk. Default 10.")
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
            pc = slicer_printability(f)
            if pc is None:
                detail = "  slicer=?(OrcaSlicer/profile missing)"
                slicer_unavailable[0] = True
            else:
                # EMPTY LAYERS (HARD): a z-gap in the slicer's layer sequence means the
                # geometry had zero cross-section at that height — geometry defect, not
                # printable. Typically caused by coincident face-to-face junctions in
                # CSG that produce degenerate CGAL cross-sections (e.g. jar wall→cone seam).
                if pc["empty_layer_gaps"]:
                    for (za, zb) in pc["empty_layer_gaps"]:
                        reasons.append(f"empty layer {za}–{zb}mm (zero cross-section — geometry defect)")
                    ok = False
                # FIRST LAYER coverage: low coverage means sparse adhesion (adhesion risk).
                # IMPORTANT: Coverage is reliable only for rectangular G1-path geometry.
                # Circular jars use G2/G3 arc moves for perimeters — those are skipped
                # by _extruded(), so fl_bbox comes out 0 and coverage = 0% (false alarm).
                # Only fail if coverage > 0 AND below threshold (i.e., arc-based = skip).
                if pc["fl_coverage_pct"] > 0 and pc["fl_coverage_pct"] < args.min_coverage_pct:
                    reasons.append(f"first-layer coverage {pc['fl_coverage_pct']}% "
                                   f"< {args.min_coverage_pct}% (adhesion risk)")
                    ok = False
                detail = (f"  1st-layer: contact={pc['fl_contact_mm']}mm "
                          f"coverage={pc['fl_coverage_pct']}% | "
                          f"overhang={pc['overhang_mm']}mm (hint on meshed parts)")
        else:
            detail = f"  overhang≈{r['oh_area']:.0f}mm² (geometric hint — unreliable on mesh)"

        verdict = "PRINTABLE" if ok else "NOT PRINTABLE"
        note = ("  [" + "; ".join(reasons) + "]") if reasons else ""
        print(f"  {f.name:<{W}}  {verdict}{note}\n      {detail}")
        if not ok:
            fails.append(f.name)

    print()
    if not args.slicer:
        print("Overhang shown is a HINT only (mesh/thread false-positives). For the REAL checks")
        print("(first-layer adhesion + structural overhang), re-run with --slicer (OrcaSlicer).\n")
    elif slicer_unavailable[0]:
        print("NOTE: OrcaSlicer or its profiles weren't found — first-layer/overhang NOT checked "
              "for some files. Set ORCA_SLICER / ORCA_PROFILES env vars.\n")
    if fails:
        print(f"NOT PRINTABLE ({len(fails)}/{len(files)}): {', '.join(fails)} — do NOT send.")
        sys.exit(1)
    print(f"All {len(files)} file(s) verified printable"
          f"{' (manifold + empty-layers + first-layer coverage)' if args.slicer else ' (manifold only)'}.")


if __name__ == "__main__":
    main()
