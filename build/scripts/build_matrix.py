#!/usr/bin/env python3
"""
build_matrix.py - Build-the-matrix regression gate for MasterTray.

Builds every public intent (and every Container / Container Lid lid type) through
mastertray.py with STRICT_KEYS=true, asserting each build succeeds. STRICT_KEYS
makes get_val() fail loud on a typo'd KEY constant (see MasterEngine.scad); the
SCAD asserts added for unknown intent / unknown component type turn manifest bugs
into nonzero exits. With --hardwarnings, OpenSCAD geometry warnings (non-manifold,
degenerate faces) also fail the build.

Exit 0 only if every build in the matrix succeeds. Component counts are reported
per build (informational) so regressions in inter-component bonding are visible.

Usage:
    python build/scripts/build_matrix.py [--hardwarnings] [--keep] [--only SUBSTR]
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

BUILD_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = BUILD_DIR.parent
MASTERTRAY = BUILD_DIR / "mastertray.py"
BBOXES = BUILD_DIR / "sandbox" / "component_bboxes.py"

import yaml  # noqa: E402

DIMS = ["--width", "80", "--length", "120", "--height", "30"]


def load_mapping():
    with open(BUILD_DIR / "mapping.yaml", "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def matrix(mapping):
    """[(label, [extra mastertray args]), ...] covering the public surface."""
    cases = []
    for intent in mapping["intents"]:
        if intent == "Container":
            for lid in mapping["container_lid_types"]:
                cases.append((f"Container / {lid}", ["--intent", "Container", "--lid", lid]))
        elif intent == "Container Lid":
            for lid in mapping["standalone_lid_types"]:
                cases.append((f"Container Lid / {lid}", ["--intent", "Container Lid", "--lid", lid]))
        elif intent == "Grid":
            # The pure Grid intent emits nothing if the layout doesn't fit the
            # footprint (the Customizer default grid is sized for a larger tray).
            # Give it a simple cartesian grid that fits the matrix test dims.
            cases.append((intent, ["--intent", intent, "--set", 'grid_layout="2x3"']))
        else:
            cases.append((intent, ["--intent", intent]))
    return cases


def component_count(stl_path):
    """Connected-component count via component_bboxes.py (needs ASCII STL)."""
    try:
        out = subprocess.run([sys.executable, str(BBOXES), str(stl_path)],
                             capture_output=True, text=True, cwd=REPO_ROOT)
        for line in out.stdout.splitlines():
            if "connected components" in line:
                return line.split(":")[-1].strip()
    except Exception as e:  # noqa: BLE001
        return f"(count failed: {e})"
    return "(unknown)"


def run_case(label, extra_args, out_dir, hardwarnings):
    stl = out_dir / (label.replace("/", "_").replace(" ", "") + ".stl")
    cmd = [sys.executable, str(MASTERTRAY), "build", *extra_args, *DIMS,
           "--set", "STRICT_KEYS=true",
           "--export-format", "asciistl",
           "--out", str(stl), "--no-report"]
    if hardwarnings:
        cmd.append("--hardwarnings")
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO_ROOT)
    ok = proc.returncode == 0 and stl.exists()
    count = component_count(stl) if ok else "-"
    return ok, count, proc.stderr.strip()


def main():
    ap = argparse.ArgumentParser(description="MasterTray build-matrix regression gate")
    ap.add_argument("--hardwarnings", action="store_true",
                    help="Promote OpenSCAD geometry warnings to build failures")
    ap.add_argument("--keep", action="store_true", help="Keep the generated STLs")
    ap.add_argument("--only", metavar="SUBSTR",
                    help="Only run cases whose label contains SUBSTR")
    args = ap.parse_args()

    mapping = load_mapping()
    cases = matrix(mapping)
    if args.only:
        cases = [c for c in cases if args.only.lower() in c[0].lower()]
        if not cases:
            sys.exit(f"No cases match --only '{args.only}'")

    tmp = tempfile.mkdtemp(prefix="mastertray-matrix-")
    out_dir = Path(tmp)
    print(f"Build matrix: {len(cases)} cases "
          f"({'hardwarnings ON' if args.hardwarnings else 'hardwarnings off'})")
    print(f"Output: {out_dir}\n")

    failures = []
    for label, extra in cases:
        ok, count, stderr = run_case(label, extra, out_dir, args.hardwarnings)
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {label:<38} components={count}")
        if not ok:
            failures.append((label, stderr))

    print()
    if failures:
        print(f"{len(failures)}/{len(cases)} FAILED:")
        for label, stderr in failures:
            tail = "\n      ".join(stderr.splitlines()[-4:]) if stderr else "(no stderr)"
            print(f"  - {label}\n      {tail}")
        if not args.keep:
            print(f"\n(STLs left in {out_dir} for inspection)")
        sys.exit(1)

    print(f"All {len(cases)} builds passed.")
    if not args.keep:
        import shutil
        shutil.rmtree(out_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
