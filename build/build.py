#!/usr/bin/env python3
"""
build.py - Terse shorthand interpreter on top of mastertray.py.

A human-friendly front-end: a short intent name plus a handful of
comma-separated option groups, instead of mastertray.py's long --flag list.
mastertray.py (and build/mapping.yaml) remain the source of truth -- this
script just translates shorthand into a mastertray `build` call.

Examples:
    python build/build.py
        # MasterBuilder.scad's own Part_To_Build default, all other defaults,
        # output named after that default (e.g. box.stl)

    python build/build.py box
        # intent "box" (-> Container), output box.stl, all other defaults

    python build/build.py box -o "My Box.stl"

    python build/build.py box -dim "100x50x30"      # total (outer) dims, mm
    python build/build.py box -use "100x50x30"      # usable (interior) dims, mm

    python build/build.py box -mesh "Slotted, 1.8, 1.2"
        # pattern, hole size, hole spacing

    python build/build.py box -strut "40, 50, 30"
        # lid %, floor %, wall % solid

    python build/build.py box -lid "Flip (Single), Flip (Double)"
        # batch: one build per lid, e.g. box-flip-single.stl, box-flip-double.stl

See build/docs/README.md for the full QA guide and build/mapping.yaml's
cli_aliases for the full list of intent shorthands. mastertray.py's own
flags (--config, --set, --dry-run, --hardwarnings, etc.) all pass through.
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mastertray as mt


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def resolve_intent(mapping, alias):
    """Map a short CLI alias (e.g. "box") to its friendly intent key
    (e.g. "Container"). Full friendly names (e.g. "Container Lid") also
    work, case-insensitively."""
    aliases = {k.lower(): v for k, v in mapping["cli_aliases"].items()}
    if alias.lower() in aliases:
        return aliases[alias.lower()]
    for name in mapping["intents"]:
        if name.lower() == alias.lower():
            return name
    sys.exit(f"ERROR: unknown intent '{alias}'.\n"
             f"Known aliases: {', '.join(sorted(aliases))}")


def default_intent(mapping):
    """The intent corresponding to MasterBuilder.scad's own Part_To_Build
    Customizer default (used when no intent is given on the command line)."""
    text = mt.SCAD_FILE.read_text(encoding="utf-8")
    m = re.search(r'Part_To_Build\s*=\s*"([^"]+)"', text)
    default_value = m.group(1) if m else None
    for friendly, value in mapping["intents"].items():
        if value == default_value:
            return friendly
    return next(iter(mapping["intents"]))


def parse_dims(spec):
    """"LxWxH" -> (length, width, height) floats."""
    parts = re.split(r"[xX]", spec)
    if len(parts) != 3:
        sys.exit(f'ERROR: dimensions must be "LxWxH", got "{spec}"')
    try:
        return [float(p.strip()) for p in parts]
    except ValueError:
        sys.exit(f'ERROR: dimensions must be numeric "LxWxH", got "{spec}"')


def parse_csv(spec):
    return [p.strip() for p in spec.split(",")]


def to_number(value):
    try:
        return int(value)
    except ValueError:
        try:
            return float(value)
        except ValueError:
            sys.exit(f"ERROR: expected a number, got '{value}'")


def mesh_overrides(mapping, spec):
    """"-mesh "pattern, hole_size, hole_spacing"" -> {Customizer var: value}"""
    parts = parse_csv(spec)
    keys = ["pattern", "hole_size", "hole_spacing"]
    if len(parts) != len(keys):
        sys.exit(f'ERROR: -mesh must be "pattern, hole_size, hole_spacing", got "{spec}"')
    group = mapping["config"]["mesh"]
    return {
        group[key]: (raw_value if key == "pattern" else to_number(raw_value))
        for key, raw_value in zip(keys, parts)
    }


def strut_overrides(mapping, spec):
    """"-strut "lid%, floor%, wall%"" -> {Customizer var: value}"""
    parts = parse_csv(spec)
    keys = ["lid_solid_percent", "floor_solid_percent", "wall_solid_percent"]
    if len(parts) != len(keys):
        sys.exit(f'ERROR: -strut must be "lid%, floor%, wall%", got "{spec}"')
    group = mapping["config"]["mesh"]
    return {group[key]: to_number(value) for key, value in zip(keys, parts)}


def make_build_args(common, intent, lid, out):
    """A mastertray `build` argparse.Namespace for one build."""
    return argparse.Namespace(
        intent=intent,
        lid=lid,
        width=common.width,
        length=common.length,
        height=common.height,
        mode=common.mode,
        slide_direction=common.slide_direction,
        slide_catch=common.slide_catch,
        config=common.config,
        out=out,
        export_format=common.export_format,
        hardwarnings=common.hardwarnings,
        openscad=common.openscad,
        dry_run=common.dry_run,
        set=common.set,
        no_report=common.no_report,
    )


def main():
    mapping = mt.load_mapping()

    parser = argparse.ArgumentParser(
        description="MasterTray terse build interpreter (front-end for mastertray.py build)")
    parser.add_argument("intent", nargs="?",
                         help='e.g. "box", "tray", "jar" (see build/mapping.yaml '
                              'cli_aliases), or a full --intent name. Defaults to '
                              "MasterBuilder.scad's own Part_To_Build default.")
    parser.add_argument("-o", dest="out",
                         help="Output file (.stl, .3mf, .png). Default: <intent>.stl. "
                              "Ignored (each lid gets its own name) when -lid lists "
                              "more than one lid.")
    parser.add_argument("-mesh", metavar='"pattern, hole_size, hole_spacing"')
    parser.add_argument("-strut", metavar='"lid%%, floor%%, wall%%"')
    parser.add_argument("-lid", metavar='"lid name[, lid name, ...]"',
                         help="One build per lid name; each output filename gets "
                              "the lid name appended.")
    parser.add_argument("-dim", metavar='"LxWxH"', help="Total (outer) dimensions, mm")
    parser.add_argument("-use", metavar='"LxWxH"', help="Usable (interior) dimensions, mm")
    parser.add_argument("--slide-direction", choices=list(mapping["slide_direction"]))
    parser.add_argument("--slide-catch", choices=list(mapping["slide_catch"]))
    parser.add_argument("--config", action="append", metavar="FILE")
    parser.add_argument("--export-format")
    parser.add_argument("--hardwarnings", action="store_true")
    parser.add_argument("--openscad")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--set", action="append", metavar="VAR=value")
    parser.add_argument("--no-report", action="store_true")
    args = parser.parse_args()

    # --- Intent ---
    if args.intent:
        friendly_intent = resolve_intent(mapping, args.intent)
        out_stem = slugify(args.intent)
    else:
        friendly_intent = default_intent(mapping)
        out_stem = slugify(mapping["intents"][friendly_intent])

    # --- Dimensions ---
    args.width = args.length = args.height = None
    args.mode = None
    if args.dim and args.use:
        sys.exit("ERROR: use only one of -dim or -use")
    if args.dim:
        args.length, args.width, args.height = parse_dims(args.dim)
        args.mode = "Total"
    elif args.use:
        args.length, args.width, args.height = parse_dims(args.use)
        args.mode = "Usable"

    # --- Mesh / strut: extra Customizer overrides on top of build_overrides() ---
    extra_overrides = {}
    if args.mesh:
        extra_overrides.update(mesh_overrides(mapping, args.mesh))
    if args.strut:
        extra_overrides.update(strut_overrides(mapping, args.strut))

    args.set = list(args.set or [])

    # --- Output filename ---
    out = args.out or f"{out_stem}.stl"
    if not Path(out).suffix:
        out += ".stl"

    # --- Lid(s): batch build, one per lid name ---
    lids = parse_csv(args.lid) if args.lid else [None]

    for lid in lids:
        if len(lids) > 1:
            base = Path(out)
            lid_out = str(base.with_name(f"{base.stem}-{slugify(lid)}{base.suffix}"))
        else:
            lid_out = out

        build_args = make_build_args(args, friendly_intent, lid, lid_out)
        overrides = mt.build_overrides(build_args, mapping)
        overrides.update(extra_overrides)
        overrides = mt.drop_redundant_overrides(overrides)
        mt.run_build(build_args, mapping, overrides)


if __name__ == "__main__":
    main()
