#!/usr/bin/env python3
"""
mastertray.py - Friendly build wrapper for MasterTray OpenSCAD models.

QA usage (no OpenSCAD/Customizer variable names needed):

    python mastertray.py list intents
    python mastertray.py list lids --intent Container
    python mastertray.py init-config
    python mastertray.py build --intent Container --lid "Flip (Double)" \\
        --width 50 --length 100 --height 30 --config build/configs/printer.yaml \\
        --out box.stl

See build/docs/README.md for the full QA guide.
Developers: the friendly <-> Customizer-variable translation lives entirely
in build/mapping.yaml. Rename Customizer variables freely; update mapping.yaml
to match and this script needs no code changes.
"""
import argparse
import datetime
import html
import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = Path(__file__).resolve().parent
SCAD_FILE = REPO_ROOT / "MasterBuilder.scad"
MAPPING_FILE = BUILD_DIR / "mapping.yaml"
EXAMPLE_CONFIG_DIR = BUILD_DIR / "configs"
SANDBOX_DIR = BUILD_DIR / "sandbox"
DEFAULT_OPENSCAD = r"C:\Program Files\OpenSCAD\openscad.exe"


class RawLiteral(str):
    """Marker: pass through to OpenSCAD -D verbatim (developer escape hatch)."""


yaml.add_representer(RawLiteral, lambda dumper, data: dumper.represent_str(str(data)))
yaml.SafeDumper.add_representer(RawLiteral, lambda dumper, data: dumper.represent_str(str(data)))


def load_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def load_mapping():
    if not MAPPING_FILE.exists():
        sys.exit(f"ERROR: mapping file not found: {MAPPING_FILE}")
    return load_yaml(MAPPING_FILE)


def fmt_value(value):
    """Format a Python value as an OpenSCAD -D literal."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return f'"{value}"'


def parse_scad_value(raw):
    """Parse a single OpenSCAD literal (`true`/`false`/"string"/number) into
    the equivalent Python value."""
    if raw == "true":
        return True
    if raw == "false":
        return False
    m = re.match(r'^"(.*)"$', raw)
    if m:
        return m.group(1)
    if re.match(r'^-?\d+$', raw):
        return int(raw)
    try:
        return float(raw)
    except ValueError:
        return raw


def parse_scad_defaults():
    """{Customizer var name: Python value} for every top-level `Var = value;`
    Customizer assignment in MasterBuilder.scad (everything before the first
    `include <...>`). Used to drop -D overrides that match the Customizer's
    own defaults -- only real overrides should be passed to OpenSCAD."""
    text = SCAD_FILE.read_text(encoding="utf-8")
    head = text.split("\ninclude <", 1)[0]
    return {
        m.group(1): parse_scad_value(m.group(2).strip())
        for m in re.finditer(r'^(\w+)\s*=\s*(.+?);', head, re.MULTILINE)
    }


def values_equal(value, default):
    """Compare an override value to a parsed Customizer default, tolerant of
    int/float mismatches (e.g. -D part_width=50.0 vs Customizer's 50)."""
    if isinstance(value, bool) or isinstance(default, bool):
        return value == default
    if isinstance(value, (int, float)) and isinstance(default, (int, float)):
        return float(value) == float(default)
    return value == default


def drop_redundant_overrides(overrides):
    """Remove overrides whose value matches MasterBuilder.scad's own
    Customizer default for that variable. RawLiteral (--set) values are a
    developer escape hatch and always pass through unchanged."""
    defaults = parse_scad_defaults()
    return {
        key: value for key, value in overrides.items()
        if isinstance(value, RawLiteral) or not values_equal(value, defaults.get(key, object()))
    }


def friendly_config_keys(mapping):
    """Flatten all config groups (printer/mesh/advanced) into one
    {friendly_key: customizer_var} map. --config files don't carry a group
    label, so any friendly key from any group is accepted."""
    merged = {}
    for group_map in mapping["config"].values():
        merged.update(group_map)
    return merged


def config_overrides(mapping, config_path):
    """Load a friendly config file and translate to {customizer_var: value}.
    Config files are plain overrides on top of MasterBuilder.scad's own
    Customizer defaults -- there's nothing to fall back to here, so a missing
    file or unknown key is always an error."""
    key_map = friendly_config_keys(mapping)
    if not config_path.exists():
        sys.exit(f"ERROR: config file not found: {config_path}")
    friendly = load_yaml(config_path)
    out = {}
    for key, value in friendly.items():
        if key not in key_map:
            sys.exit(f"ERROR: unknown key '{key}' in {config_path}\n"
                     f"Valid keys: {', '.join(key_map)}")
        out[key_map[key]] = value
    return out


def load_config_defaults():
    """build/configs/{printer,mesh,advanced}.yaml as {group: {friendly_key: value}}.
    These mirror MasterBuilder.scad's @CONFIG_SECTION defaults (see
    check_config_sync.pl) and serve as the baseline build reports diff against."""
    return {
        group: load_yaml(EXAMPLE_CONFIG_DIR / f"{group}.yaml")
        for group in ("printer", "mesh", "advanced")
    }


def friendly_key_groups(mapping):
    """{friendly_key: group} reverse index across all config groups."""
    return {
        key: group
        for group, group_map in mapping["config"].items()
        for key in group_map
    }


def config_changes(args, mapping, defaults):
    """Friendly-key values from --config files that differ from build/configs/*.yaml
    defaults, in the form [{key, group, default, value, source}, ...]."""
    key_groups = friendly_key_groups(mapping)
    changes = []
    for path_arg in args.config or []:
        friendly = load_yaml(Path(path_arg))
        for key, value in friendly.items():
            group = key_groups.get(key)
            default_val = defaults.get(group, {}).get(key) if group else None
            if value != default_val:
                changes.append({
                    "key": key,
                    "group": group,
                    "default": default_val,
                    "value": value,
                    "source": path_arg,
                })
    return changes


def cmd_list_intents(args, mapping):
    print("Available intents (--intent):")
    for name in mapping["intents"]:
        print(f"  {name}")


def cmd_list_lids(args, mapping):
    if args.intent == "Container":
        table = mapping["container_lid_types"]
    elif args.intent == "Container Lid":
        table = mapping["standalone_lid_types"]
    else:
        sys.exit('--intent must be "Container" or "Container Lid" for lid listing')
    print(f'Available lid types for --intent "{args.intent}":')
    for name in table:
        print(f"  {name}")


def cmd_init_config(args, mapping):
    """Copy the example override files from build/configs/ as a starting
    point for --config. These are templates, not defaults -- MasterBuilder.scad
    already has its own Customizer defaults for everything they contain."""
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in ("printer.yaml", "mesh.yaml", "advanced.yaml"):
        src = EXAMPLE_CONFIG_DIR / name
        dst = out_dir / name
        if dst.exists() and not args.force:
            print(f"  skip (exists): {dst}")
            continue
        shutil.copy(src, dst)
        print(f"  wrote: {dst}")


def build_overrides(args, mapping):
    overrides = {}

    # --- Config files: plain override files, applied in order given ---
    for path_arg in args.config or []:
        overrides.update(config_overrides(mapping, Path(path_arg)))

    # --- Intent ---
    if args.intent not in mapping["intents"]:
        sys.exit(f"ERROR: unknown --intent '{args.intent}'. "
                 f"Run: python mastertray.py list intents")
    overrides["Part_To_Build"] = mapping["intents"][args.intent]

    # --- Dimensions ---
    if args.width is not None:
        overrides["part_width"] = args.width
    if args.length is not None:
        overrides["part_length"] = args.length
    if args.height is not None:
        overrides["part_height"] = args.height
    if args.mode:
        overrides["dimension_mode"] = mapping["dimension_mode"][args.mode]

    # --- Lid type ---
    if args.lid:
        if args.intent == "Container":
            table = mapping["container_lid_types"]
            if args.lid not in table:
                sys.exit(f"ERROR: unknown --lid '{args.lid}' for --intent Container. "
                         f'Run: python mastertray.py list lids --intent Container')
            # Force all mechanism flags false, then set the selected one(s) true.
            for flag in mapping["container_lid_flags"]:
                overrides[flag] = False
            overrides.update(table[args.lid])
        elif args.intent == "Container Lid":
            table = mapping["standalone_lid_types"]
            if args.lid not in table:
                sys.exit(f"ERROR: unknown --lid '{args.lid}' for --intent \"Container Lid\". "
                         f'Run: python mastertray.py list lids --intent "Container Lid"')
            overrides.update(table[args.lid])
        else:
            sys.exit('--lid only applies to --intent "Container" or "Container Lid"')

    # --- Slide (Glide) sub-options ---
    if args.slide_direction:
        overrides["Glide_Direction"] = mapping["slide_direction"][args.slide_direction]
    if args.slide_catch:
        overrides["Glide_Snap"] = mapping["slide_catch"][args.slide_catch]

    # --- Raw escape hatch (developers only) ---
    for raw in args.set or []:
        if "=" not in raw:
            sys.exit(f"ERROR: --set must be VAR=value, got '{raw}'")
        key, value = raw.split("=", 1)
        overrides[key] = RawLiteral(value)

    return overrides


def render_report_html(report):
    """Render a build report dict as a self-contained styled HTML page."""
    b = report["build"]

    def esc(value):
        return html.escape(str(value)) if value is not None else ""

    def kv_rows(d):
        return "\n".join(
            f"      <tr><th>{esc(k)}</th><td>{esc(v)}</td></tr>"
            for k, v in d.items()
        )

    build_rows = kv_rows({
        "Timestamp": b["timestamp"],
        "Intent": b["intent"],
        "Lid": b["lid"],
        "Width": b["width"],
        "Length": b["length"],
        "Height": b["height"],
        "Mode": b["mode"],
        "Slide direction": b["slide_direction"],
        "Slide catch": b["slide_catch"],
        "Out": b["out"],
        "Config files": ", ".join(b["config_files"]) or "(none)",
        "Command": b["command"],
    })

    printer_rows = kv_rows(report["printer"])

    if report["changes"]:
        changes_rows = "\n".join(
            "      <tr>"
            f"<td>{esc(c['key'])}</td>"
            f"<td>{esc(c['group'])}</td>"
            f"<td>{esc(c['default'])}</td>"
            f"<td>{esc(c['value'])}</td>"
            f"<td>{esc(c['source'])}</td>"
            "</tr>"
            for c in report["changes"]
        )
        changes_table = f"""    <table>
      <tr><th>Key</th><th>Group</th><th>Default</th><th>Value</th><th>Source</th></tr>
{changes_rows}
    </table>"""
    else:
        changes_table = "    <p><em>No changes from build/configs/*.yaml defaults.</em></p>"

    overrides_rows = kv_rows(report["overrides"])

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Build report: {esc(b['out'])}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; color: #222; }}
    h1 {{ font-size: 1.4rem; }}
    h2 {{ font-size: 1.1rem; margin-top: 2rem; border-bottom: 1px solid #ccc; padding-bottom: 0.25rem; }}
    table {{ border-collapse: collapse; width: 100%; margin-top: 0.5rem; }}
    th, td {{ text-align: left; padding: 0.35rem 0.6rem; border: 1px solid #ddd; font-size: 0.9rem; }}
    tr > th:first-child {{ width: 220px; background: #f7f7f7; font-weight: 600; }}
    table tr:first-child th {{ background: #f0f0f0; }}
    code {{ font-size: 0.85rem; }}
  </style>
</head>
<body>
  <h1>MasterTray build report: {esc(b['out'])}</h1>

  <h2>Build</h2>
  <table>
{build_rows}
  </table>

  <h2>Printer / Slicer</h2>
  <table>
{printer_rows}
  </table>

  <h2>Changes vs build/configs/*.yaml defaults</h2>
{changes_table}

  <h2>Customizer Overrides (-D)</h2>
  <table>
{overrides_rows}
  </table>
</body>
</html>
"""


def write_build_report(args, mapping, overrides, cmd):
    """Write <out>.report.yaml and <out>.report.html: build parameters,
    printer/slicer settings, and a diff of --config changes vs
    build/configs/*.yaml defaults. Used by the reporting/diff workflow to
    compare builds."""
    defaults = load_config_defaults()
    changes = config_changes(args, mapping, defaults)

    printer_settings = dict(defaults["printer"])
    for change in changes:
        if change["group"] == "printer":
            printer_settings[change["key"]] = change["value"]

    report = {
        "build": {
            "timestamp": datetime.datetime.now().isoformat(timespec="seconds"),
            "intent": args.intent,
            "lid": args.lid,
            "width": args.width,
            "length": args.length,
            "height": args.height,
            "mode": args.mode,
            "slide_direction": args.slide_direction,
            "slide_catch": args.slide_catch,
            "out": args.out,
            "config_files": args.config or [],
            "command": " ".join(f'"{c}"' if " " in c else c for c in cmd),
        },
        "printer": printer_settings,
        "changes": changes,
        "overrides": dict(overrides),
    }

    report_path = Path(args.out).with_suffix(".report.yaml")
    with open(report_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(report, f, sort_keys=False, default_flow_style=False)
    print(f"  report: {report_path}")

    html_path = Path(args.out).with_suffix(".report.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(render_report_html(report))
    print(f"  report: {html_path}")


def compute_overrides(args, mapping):
    """Final, deduplicated -D overrides for a build: friendly params translated
    to Customizer vars, with anything matching MasterBuilder.scad's own
    Customizer defaults dropped (see drop_redundant_overrides)."""
    return drop_redundant_overrides(build_overrides(args, mapping))


def run_build(args, mapping, overrides):
    """Run OpenSCAD with the given (already-computed) -D overrides, and write
    build reports unless --no-report."""
    # OpenSCAD runs with cwd=REPO_ROOT (so MasterBuilder.scad's own relative
    # includes resolve correctly) -- resolve --out against the *caller's* cwd
    # first, so a relative --out lands where the user is, not in REPO_ROOT.
    args.out = str(Path(args.out).resolve())

    openscad = args.openscad or DEFAULT_OPENSCAD
    cmd = [openscad, "-o", args.out]
    if args.export_format:
        cmd += ["--export-format", args.export_format]
    if args.hardwarnings:
        cmd.append("--hardwarnings")

    for key, value in overrides.items():
        if isinstance(value, RawLiteral):
            cmd += ["-D", f"{key}={value}"]
        else:
            cmd += ["-D", f"{key}={fmt_value(value)}"]
    cmd.append(str(SCAD_FILE))

    print("Running:")
    print("  " + " ".join(f'"{c}"' if " " in c else c for c in cmd))

    if args.dry_run:
        return

    result = subprocess.run(cmd, cwd=REPO_ROOT)
    if result.returncode != 0:
        sys.exit(result.returncode)

    if not args.no_report:
        write_build_report(args, mapping, overrides, cmd)


def cmd_build(args, mapping):
    overrides = compute_overrides(args, mapping)
    run_build(args, mapping, overrides)


def main():
    mapping = load_mapping()

    parser = argparse.ArgumentParser(description="MasterTray friendly build wrapper")
    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="List available intents or lid types")
    list_sub = p_list.add_subparsers(dest="what", required=True)
    list_sub.add_parser("intents", help="List build intents")
    p_list_lids = list_sub.add_parser("lids", help="List lid types for an intent")
    p_list_lids.add_argument("--intent", required=True)

    p_init = sub.add_parser("init-config", help="Copy example --config override files")
    p_init.add_argument("--out", default=str(SANDBOX_DIR),
                         help=f"Directory to write example configs into (default: {SANDBOX_DIR})")
    p_init.add_argument("--force", action="store_true", help="Overwrite existing files")

    p_build = sub.add_parser("build", help="Build and export a part")
    p_build.add_argument("--intent", required=True,
                          help='e.g. "Container", "Container Lid", "Tray", "Jar"')
    p_build.add_argument("--lid", help='e.g. "Flip (Double)", "Snap (Outer Wall)"')
    p_build.add_argument("--width", type=float, help="mm")
    p_build.add_argument("--length", type=float, help="mm")
    p_build.add_argument("--height", type=float, help="mm")
    p_build.add_argument("--mode", choices=list(mapping["dimension_mode"]),
                          help="Total = outer dimensions, Usable = interior dimensions")
    p_build.add_argument("--slide-direction", choices=list(mapping["slide_direction"]))
    p_build.add_argument("--slide-catch", choices=list(mapping["slide_catch"]))
    p_build.add_argument("--config", action="append", metavar="FILE",
                          help="Friendly-key override file (see build/configs/ for "
                               "examples); repeatable, applied in order given. "
                               "Unset values fall back to MasterBuilder.scad's own "
                               "Customizer defaults.")
    p_build.add_argument("--out", required=True, help="Output file (.stl, .3mf, .png)")
    p_build.add_argument("--export-format", help='e.g. "binstl", "3mf"')
    p_build.add_argument("--hardwarnings", action="store_true",
                          help="Promote OpenSCAD warnings to errors (exit 1 on geometry issues)")
    p_build.add_argument("--openscad", help=f"Path to openscad executable (default: {DEFAULT_OPENSCAD})")
    p_build.add_argument("--dry-run", action="store_true", help="Print the command without running it")
    p_build.add_argument("--set", action="append", metavar="VAR=value",
                          help="(Developer escape hatch) raw Customizer override, "
                               "passed through verbatim, e.g. --set chamfer_size=0.6")
    p_build.add_argument("--no-report", action="store_true",
                          help="Don't write <out>.report.yaml after a successful build")

    args = parser.parse_args()

    if args.command == "list":
        if args.what == "intents":
            cmd_list_intents(args, mapping)
        elif args.what == "lids":
            cmd_list_lids(args, mapping)
    elif args.command == "init-config":
        cmd_init_config(args, mapping)
    elif args.command == "build":
        cmd_build(args, mapping)


if __name__ == "__main__":
    main()
