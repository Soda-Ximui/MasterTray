#!/usr/bin/env python3
"""
test_mapping_schema.py — Unit tests for validate_mapping() in mastertray.py.

Tests two categories:
  1. The real mapping.yaml passes cleanly (the "it works" baseline).
  2. Intentionally-broken snippets each trigger a specific error (the "it
     catches problems" coverage).

Run:
    python build/scripts/test_mapping_schema.py
Exit 0 = all passed.  Exit 1 = failures listed.

Design note (item #4 from the architecture review, 2026-06-17):
    validate_mapping() was added so a malformed intent surfaces as a clear
    startup error instead of a cryptic KeyError deep in build_overrides().
    These tests pin that contract so future edits can't silently regress it.
"""
import copy
import sys
from pathlib import Path

# Resolve mastertray.py relative to this file regardless of CWD.
BUILD_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BUILD_DIR))

import yaml  # noqa: E402
from mastertray import load_yaml, validate_mapping  # noqa: E402

MAPPING_FILE = BUILD_DIR / "mapping.yaml"


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _load_real():
    return load_yaml(MAPPING_FILE)


def _expect_ok(mapping, label):
    """Assert validate_mapping() does NOT raise SystemExit."""
    try:
        validate_mapping(mapping)
        return True
    except SystemExit as e:
        print(f"  FAIL [{label}]: expected OK but got:\n    {e}")
        return False


def _expect_error(mapping, fragment, label):
    """Assert validate_mapping() raises SystemExit whose message contains
    *fragment* (case-sensitive substring match)."""
    try:
        validate_mapping(mapping)
        print(f"  FAIL [{label}]: expected error containing {fragment!r} but got OK")
        return False
    except SystemExit as e:
        msg = str(e)
        if fragment in msg:
            return True
        print(f"  FAIL [{label}]: error did not contain {fragment!r}.\n    Got: {msg}")
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Test cases
# ─────────────────────────────────────────────────────────────────────────────

def test_real_mapping_is_valid():
    """The real build/mapping.yaml must pass without errors."""
    return _expect_ok(_load_real(), "real mapping.yaml is valid")


def test_missing_top_level_key():
    """Omitting a required top-level key is caught."""
    m = copy.deepcopy(_load_real())
    del m["cli_aliases"]
    return _expect_error(m, "missing top-level key: 'cli_aliases'",
                         "missing top-level key")


def test_unknown_flag_in_container_lid_types():
    """A flag name that isn't in container_lid_flags is caught."""
    m = copy.deepcopy(_load_real())
    first_lid = next(iter(m["container_lid_types"]))
    m["container_lid_types"][first_lid]["Nonexistent_Flag"] = True
    return _expect_error(m, "not in container_lid_flags",
                         "unknown flag in container_lid_types")


def test_cli_alias_references_nonexistent_intent():
    """An alias pointing at a missing intent is caught."""
    m = copy.deepcopy(_load_real())
    m["cli_aliases"]["bad-alias"] = "Does Not Exist"
    return _expect_error(m, "references unknown intent",
                         "cli_alias → bad intent")


def test_standalone_lid_type_empty_overrides():
    """A standalone_lid_types entry with an empty override dict is caught."""
    m = copy.deepcopy(_load_real())
    m["standalone_lid_types"]["Empty Lid"] = {}
    return _expect_error(m, "must have at least one override key",
                         "empty standalone_lid_types entry")


def test_intent_value_not_string():
    """An intent whose value is not a string is caught."""
    m = copy.deepcopy(_load_real())
    m["intents"]["Bad Intent"] = 42
    return _expect_error(m, "value must be a string",
                         "intent value not a string")


def test_config_group_value_not_string():
    """A config group entry whose value is not a string is caught."""
    m = copy.deepcopy(_load_real())
    m["config"]["printer"]["nozzle"] = 0.4   # should be a string var name
    return _expect_error(m, "value must be a string",
                         "config group value not a string")


# ─────────────────────────────────────────────────────────────────────────────
# Runner
# ─────────────────────────────────────────────────────────────────────────────

TESTS = [
    test_real_mapping_is_valid,
    test_missing_top_level_key,
    test_unknown_flag_in_container_lid_types,
    test_cli_alias_references_nonexistent_intent,
    test_standalone_lid_type_empty_overrides,
    test_intent_value_not_string,
    test_config_group_value_not_string,
]


def main():
    print(f"Running {len(TESTS)} mapping-schema tests ...\n")
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
