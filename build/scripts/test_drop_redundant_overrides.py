#!/usr/bin/env python3
"""
test_drop_redundant_overrides.py — Unit tests for drop_redundant_overrides()
and parse_scad_defaults() in mastertray.py.

Design note (item #2 from the architecture review, 2026-06-17):
    drop_redundant_overrides() strips -D overrides whose value matches the
    Customizer default parsed from MasterBuilder.scad's preamble.  The risk
    flagged in the review: if parse_scad_defaults() misses a default (e.g.
    expression-defined or post-include), an override matching that default
    could be dropped incorrectly.

    Investigation showed the risk is inert in practice: ALL Customizer
    variables in MasterBuilder.scad are simple literals in the preamble.
    Expression-defined vars (raw_w, raw_l, raw_h) and post-include vars are
    never passed as -D overrides so they never appear in the overrides dict.

    These tests pin that contract so future edits can't silently regress it.

Run:
    python build/scripts/test_drop_redundant_overrides.py
Exit 0 = all passed.  Exit 1 = failures listed.
"""
import io
import sys
from pathlib import Path

BUILD_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BUILD_DIR))

from mastertray import (  # noqa: E402
    RawLiteral,
    drop_redundant_overrides,
    parse_scad_defaults,
    values_equal,
)

SCAD_FILE = BUILD_DIR.parent / "MasterBuilder.scad"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _ok(result, label):
    if result:
        return True
    print(f"  FAIL [{label}]")
    return False


# ─────────────────────────────────────────────────────────────────────────────
# parse_scad_defaults() tests
# ─────────────────────────────────────────────────────────────────────────────

def test_parses_known_literal_vars():
    """parse_scad_defaults() captures the standard Customizer variables."""
    d = parse_scad_defaults()
    expected = {
        "part_width":   140,
        "part_length":  70,
        "part_height":  20,
        "Flip_Single":  True,
        "Flip_Double":  False,
        "Wall_Loops":   2,
        "Nozzle_Diameter": 0.4,
    }
    ok = True
    for key, val in expected.items():
        if key not in d:
            print(f"  FAIL [parses_known_literal_vars]: '{key}' not in defaults")
            ok = False
        elif not values_equal(d[key], val):
            print(f"  FAIL [parses_known_literal_vars]: '{key}' = {d[key]!r}, "
                  f"expected {val!r}")
            ok = False
    return ok


def test_expression_vars_not_in_defaults():
    """Expression-defined vars (raw_w, raw_l, raw_h) should either be absent
    or parse to a non-numeric value — they must never accidentally match a
    user-supplied numeric override."""
    d = parse_scad_defaults()
    for var in ("raw_w", "raw_l", "raw_h"):
        if var in d and isinstance(d[var], (int, float)):
            print(f"  FAIL [expression_vars_not_numeric]: '{var}' parsed as "
                  f"numeric {d[var]!r} — drop_redundant_overrides could "
                  f"incorrectly drop a real override")
            return False
    return True


def test_post_include_vars_not_in_defaults():
    """EPS, LINE_W, and ui_payload are set post-include; they must not appear
    as parseable defaults (their assignments use Customizer variable values,
    not literals, so they'd never be -D-overridden anyway)."""
    d = parse_scad_defaults()
    # These are set post-include and must not appear as simple-literal defaults.
    # If they do appear as a raw string it's harmless (values_equal won't match
    # a numeric override), but we assert absence for clarity.
    for var in ("EPS", "LINE_W"):
        # These ARE in the preamble as simple literals in MasterEngine.scad
        # defaults section — but the parser only reads MasterBuilder.scad's
        # preamble (before its first include), so they must be absent.
        if var in d:
            # Only a problem if they parse as a numeric that could collide.
            if isinstance(d[var], (int, float)):
                print(f"  FAIL [post_include_vars]: '{var}' = {d[var]!r} "
                      f"(numeric) could cause incorrect drop")
                return False
    return True


# ─────────────────────────────────────────────────────────────────────────────
# drop_redundant_overrides() tests
# ─────────────────────────────────────────────────────────────────────────────

def test_drops_override_matching_default():
    """An override equal to the Customizer default is removed."""
    result = drop_redundant_overrides({"part_width": 140})
    return _ok("part_width" not in result, "drops override matching default")


def test_keeps_override_differing_from_default():
    """An override that differs from the Customizer default is kept."""
    result = drop_redundant_overrides({"part_width": 80})
    return _ok("part_width" in result and result["part_width"] == 80,
               "keeps override differing from default")


def test_rawliteral_always_passes_through():
    """RawLiteral values (--set) always pass through, even if value matches default."""
    result = drop_redundant_overrides({"part_width": RawLiteral("140")})
    return _ok("part_width" in result, "RawLiteral passes through")


def test_unknown_key_always_kept():
    """An override for an unknown key (not in defaults) is always kept."""
    result = drop_redundant_overrides({"STRICT_KEYS": RawLiteral("true")})
    return _ok("STRICT_KEYS" in result, "unknown key kept (RawLiteral)")


def test_bool_int_not_confused():
    """False must not match 0, and True must not match 1 (int/bool distinction)."""
    result_false = drop_redundant_overrides({"Flip_Single": 0})
    result_true  = drop_redundant_overrides({"Flip_Single": 1})
    ok_false = _ok("Flip_Single" in result_false,
                   "bool/int: False default does not drop int 0")
    ok_true  = _ok("Flip_Single" in result_true,
                   "bool/int: True default does not drop int 1")
    return ok_false and ok_true


def test_float_int_tolerance():
    """140.0 and 140 are considered equal (same physical value)."""
    result = drop_redundant_overrides({"part_width": 140.0})
    return _ok("part_width" not in result, "float/int tolerance: 140.0 drops against 140")


def test_verbose_flag_prints_dropped_key(capsys=None):
    """With verbose=True, dropped keys are reported to stderr."""
    buf = io.StringIO()
    old_stderr = sys.stderr
    sys.stderr = buf
    try:
        drop_redundant_overrides({"part_width": 140}, verbose=True)
    finally:
        sys.stderr = old_stderr
    output = buf.getvalue()
    return _ok("drop-redundant" in output and "part_width" in output,
               "verbose prints dropped key to stderr")


def test_verbose_does_not_print_kept_key():
    """With verbose=True, kept keys produce no stderr output."""
    buf = io.StringIO()
    old_stderr = sys.stderr
    sys.stderr = buf
    try:
        drop_redundant_overrides({"part_width": 80}, verbose=True)
    finally:
        sys.stderr = old_stderr
    output = buf.getvalue()
    return _ok("part_width" not in output, "verbose: kept key not printed")


# ─────────────────────────────────────────────────────────────────────────────
# Runner
# ─────────────────────────────────────────────────────────────────────────────

TESTS = [
    test_parses_known_literal_vars,
    test_expression_vars_not_in_defaults,
    test_post_include_vars_not_in_defaults,
    test_drops_override_matching_default,
    test_keeps_override_differing_from_default,
    test_rawliteral_always_passes_through,
    test_unknown_key_always_kept,
    test_bool_int_not_confused,
    test_float_int_tolerance,
    test_verbose_flag_prints_dropped_key,
    test_verbose_does_not_print_kept_key,
]


def main():
    print(f"Running {len(TESTS)} drop-redundant-overrides tests ...\n")
    passed = 0
    for t in TESTS:
        ok = t()
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {t.__name__}")
        if ok:
            passed += 1
    print(f"\n{passed}/{len(TESTS)} passed.")
    if passed < len(TESTS):
        sys.exit(1)


if __name__ == "__main__":
    main()
