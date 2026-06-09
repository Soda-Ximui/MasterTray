"""
nm_hunt.py — export every relevant lid/box combination from MasterBuilder.scad
             via OpenSCAD CLI, check for non-manifold edges via pymeshlab.

Run from the MasterTray directory:
    python nm_hunt.py
"""
import subprocess, os, sys, tempfile
from collections import defaultdict, Counter
import pymeshlab

OPENSCAD  = r"C:\Program Files\OpenSCAD\openscad.exe"
SCAD_FILE = "MasterBuilder.scad"
OUT_DIR   = os.path.join(tempfile.gettempdir(), "nm_hunt_stl")

# ---------------------------------------------------------------------------
# Base overrides applied to every export — small/fast geometry, no mesh holes.
# ---------------------------------------------------------------------------
BASE = {
    "Nozzle_Diameter":  "0.4",
    "Wall_Loops":       "2",
    "Layer_Height":     "0.28",
    "part_width":       "40",
    "part_length":      "80",
    "part_height":      "30",
    "chamfer_size":     "0.4",
    "bool_overlap_eps": "0.1",
    "mesh_hole_size":   "0",    # no mesh — faster export
    "Flip_Single":      "false",
    "Flip_Double":      "false",
    "Snap_External":    "false",
    "Snap_Internal":    "false",
    "Glide_External":   "false",
    "Glide_Internal":   "false",
}

def D(key, val):
    """Build a single -D define pair. String values get OpenSCAD quotes."""
    if isinstance(val, str) and not val.replace(".", "").replace("-", "").lstrip("-").isnumeric():
        # Looks like a string literal — wrap in OpenSCAD double-quotes
        return ["-D", f'{key}="{val}"']
    return ["-D", f"{key}={val}"]

# ---------------------------------------------------------------------------
# Test matrix: (label, Part_To_Build, {extra overrides})
# ---------------------------------------------------------------------------
CASES = [
    # --- boxes (each box type in isolation) ---
    ("Snap_Ext_Box",    "Snap Box (External)",  {"Snap_External": "true"}),
    ("Snap_Rab_Box",    "Snap Box (Internal)",  {"Snap_Internal": "true"}),
    ("Glide_Ext_Box",   "Glide Box (External)", {"Glide_External": "true", "Glide_Direction": "H", "Glide_Snap": "Ball"}),
    ("Glide_Rab_Box",   "Glide Box (Internal)", {"Glide_Internal": "true", "Glide_Direction": "H", "Glide_Snap": "Ball"}),
    ("Flip_Single_Box", "Flip Box (Single)",    {"Flip_Single": "true"}),
    ("Flip_Double_Box", "Flip Box (Double)",    {"Flip_Double": "true"}),

    # --- standalone lids (one at a time) ---
    ("Slip_Lid",        "Lid", {"Standalone_Lid_Type": "Slip"}),
    ("Snap_Ext_Lid",    "Lid", {"Standalone_Lid_Type": "Snap",        "Lid_Style": "External"}),
    ("Snap_Rab_Lid",    "Lid", {"Standalone_Lid_Type": "Snap",        "Lid_Style": "Rabbet"}),
    ("Glide_Ext_Lid",   "Lid", {"Standalone_Lid_Type": "Glide",       "Lid_Style": "External", "Glide_Direction": "H", "Glide_Snap": "Ball"}),
    ("Glide_Rab_Lid",   "Lid", {"Standalone_Lid_Type": "Glide",       "Lid_Style": "Rabbet",   "Glide_Direction": "H", "Glide_Snap": "Ball"}),
    ("Flip_Single_Lid", "Lid", {"Standalone_Lid_Type": "Flip_Single"}),
    ("Screw_Lid",       "Lid", {"Standalone_Lid_Type": "Screw"}),
]

# ---------------------------------------------------------------------------

def export_stl(label, part, extra):
    out_path = os.path.join(OUT_DIR, f"{label}.stl")
    defines = dict(BASE)
    defines.update(extra)
    defines["Part_To_Build"] = part

    d_args = []
    for k, v in defines.items():
        d_args += D(k, v)

    cmd = [OPENSCAD, "-o", out_path, "--export-format", "binstl"] + d_args + [SCAD_FILE]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    return out_path, result.returncode, result.stderr


def nm_check(stl_path):
    ms = pymeshlab.MeshSet()
    try:
        ms.load_new_mesh(stl_path)
    except Exception as e:
        return None, str(e)

    faces = ms.current_mesh().face_matrix()
    verts = ms.current_mesh().vertex_matrix()

    edge_faces = defaultdict(list)
    for i, f in enumerate(faces):
        for a, b in ((f[0],f[1]), (f[1],f[2]), (f[0],f[2])):
            edge_faces[(min(a,b), max(a,b))].append(i)

    nm_edges  = [(k, v) for k, v in edge_faces.items() if len(v) > 2]
    bnd_edges = [(k, v) for k, v in edge_faces.items() if len(v) == 1]

    z_dist = Counter(
        round((verts[a][2] + verts[b][2]) / 2, 2)
        for (a, b), _ in nm_edges
    )
    face_counts = Counter(len(v) for _, v in nm_edges)

    return {
        "nm":          len(nm_edges),
        "bnd":         len(bnd_edges),
        "faces":       len(faces),
        "z_dist":      z_dist,
        "face_counts": face_counts,   # {4: N} = platter coplanar, {3: N} = butterfly
    }, None


def is_platter_artifact(info):
    """True when ALL NM edges are 4-face-sharing (coplanar pair) AND all above Z=0."""
    if info["nm"] == 0:
        return False
    fc = info["face_counts"]
    if set(fc.keys()) != {4}:
        return False   # 3-face edges = butterfly intersection = real bug
    return all(z > 0.05 for z in info["z_dist"])


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Exporting to: {OUT_DIR}\n")

    W = max(len(label) for label, *_ in CASES) + 2
    results = []

    for label, part, extra in CASES:
        sys.stdout.write(f"  {label:<{W}}")
        sys.stdout.flush()

        stl_path, rc, stderr = export_stl(label, part, extra)
        if rc != 0 or not os.path.exists(stl_path) or os.path.getsize(stl_path) == 0:
            print("EXPORT FAILED")
            errs = [l for l in stderr.splitlines() if "ERROR" in l or "WARNING" in l]
            for e in errs[-3:]:
                print(f"    {e}")
            results.append((label, None, "export failed"))
            continue

        info, err = nm_check(stl_path)
        if err:
            print(f"CHECK FAILED: {err}")
            results.append((label, None, err))
            continue

        if info["nm"] == 0:
            print(f"nm=   0  faces={info['faces']:6d}  OK")
        elif is_platter_artifact(info):
            zs = sorted(info["z_dist"].items())
            print(f"nm={info['nm']:4d}  faces={info['faces']:6d}  PLATTER-ARTIFACT  z={zs}")
        else:
            print(f"nm={info['nm']:4d}  faces={info['faces']:6d}  *** REAL BUG ***")
            zs = sorted(info["z_dist"].items())
            print(f"    z_dist={zs}  face_sharing={dict(info['face_counts'])}")

        results.append((label, info, None))

    # Summary
    print()
    print("=" * 70)
    real_bugs = [(l, i) for l, i, e in results if i is not None and i["nm"] > 0 and not is_platter_artifact(i)]
    artifacts = [(l, i) for l, i, e in results if i is not None and is_platter_artifact(i)]
    failed    = [(l, e) for l, i, e in results if e is not None]

    if real_bugs:
        print(f"FAIL — {len(real_bugs)} part(s) have real non-manifold geometry:")
        for label, info in real_bugs:
            print(f"  {label}: {info['nm']} NM edges  z={sorted(info['z_dist'].items())}")
    else:
        print("PASS — no real non-manifold geometry found")

    if artifacts:
        print(f"\n{len(artifacts)} platter artifact(s) (benign, all above Z=0):")
        for label, info in artifacts:
            print(f"  {label}: {info['nm']} NM edges at Z={sorted(info['z_dist'].keys())}")
    if failed:
        print(f"\n{len(failed)} export/check failure(s):")
        for label, err in failed:
            print(f"  {label}: {err}")


if __name__ == "__main__":
    main()
