# Session Handoff — MasterTray
_Last updated: 2026-06-17 — mapping.yaml schema validation (Sonnet, item #4)_

---

## Branch
`refactor/code-clarity-and-safety`

---

## ✅ HARDENING PASS (this session — all verified by the build-matrix gate)

The critical review below drove a fix pass. Status of each item:

| # | Item | Status |
|---|------|--------|
| 1 | Untyped data model / silent fallback | **Mitigated** — `STRICT_KEYS` mode asserts typo'd KEY constants (MasterEngine.scad); gate runs with it on. Full struct redesign still open. |
| 2 | 583-line ternary, 6 copy-pasted box branches | **Done** — 5 collapsed into `box_lid_variant()` (MasterManifest.scad). |
| 3 | Silent dispatcher/intent misses | **Done** — both now `assert(false, …)`; bogus intent → exit 1. |
| 4 | mapping.yaml not true source of truth (two SCAD parsers) | **Done** — `mastertray.py dump-defaults` → `build/scad_defaults.json`; builder.astro consumes it; JS parser deleted. |
| 5 | `drop_redundant_overrides` regex can drop real overrides | **Open** — see review #5. Not yet addressed. |
| 6 | `--set` bypasses validation | **Done** — warns on unknown Customizer var (mastertray.py). |
| 7 | Layer-2 doing Layer-1 geometry (flip_hinge_y etc.) | **Open** — see review #7. Deliberately not moved (risky; flip lids frozen). |
| 8 | `EPS2` name pun | **Done** — renamed `LINE_W` across all SCAD. |
| 9 | No automated gate | **Done** — `build/scripts/build_matrix.py` (`just check-build`). |
| 10 | Hardcoded machine paths | **Done** — `python` from PATH / `$env:MASTERTRAY_PYTHON`; .ps1 self-guards on repo root. |

**Build-matrix gate** (`just check-build`): builds all 26 public-surface cases (every
intent + every Container/Container-Lid lid type) with `STRICT_KEYS=true`, asserts exit 0,
reports connected-component counts. `just check-build-strict` adds `--hardwarnings`.

Component-count observations from the gate (informational, NOT failures):
- `Container / Slide (Outer/Inner Wall)` = **4 components** — the known ball-snap boss
  disconnection (default catch is "Ball"). Tab snap → 2. Still the frozen workaround.
- `Grid` needs a layout that fits the footprint or it emits an empty object; the gate
  passes it `grid_layout="2x3"`.

Remaining open items: review #1 (full data-model redesign), #5 (override-diff regex),
#7 (layer violation). All deliberately deferred — each needs a design decision.
Review #4 (mapping.yaml schema) resolved this session — see "THIS SESSION" section above.

---

## ✅ MANIFOLD PASS (jar/slide fixes + manifold safeguards)

**The gap that started it:** test-print coupons were validated with `component_bboxes.py`
(component COUNT), which cannot see non-manifold edges. Non-manifold jar coupons shipped to
print. The correct tool (`validSTL.py`, pymeshlab) was in the repo, unused.

**Jar non-manifold — NOT a regression, now fixed.** Verified the pre-session commit (42ae96e)
produced a byte-identical non-manifold jar (nm=671), so recent changes didn't cause it — it had
been non-manifold per pymeshlab all along (OpenSCAD's own check passes it; slicers auto-repair
the seam edges → it looked stable). Cause: jar floor = ring + disc + wall meeting face-to-face
with zero overlap. Fix (EPS-overlap rule, commit `1d03992`): grow the inner disc by EPS·2
(not shrink the ring — that mis-meshed low-facet Quad/Spool jars); drop the wall EPS into the
floor. Result: **Jar 8012→0, Threaded Jar 8012→0, Grid Test 30452→0**, all jar variants nm=0.
The BOSL2 threads were clean all along.

**Slide groove-chamfer non-manifold — fixed** (commit `e3b9847`). The 45° ramp's base edge was
coplanar with the groove cutter top (coincident edge → nm=2 at 0.6/0.30). Dropped the base by
EPS to overlap. (Gate Slide-Outer still nm=10 = the separate ball-snap boss, documented.)

**⚠ Groove "prints on air" overhangs (print-quality, NOT manifold):** any inner-wall groove with
a trapping/retaining lip above it has the lip underside bridging the groove void — printed
bottom-up the ceiling prints on air. Caught on physical prints, not validSTL (it's a slicer
overhang, not a topology defect). Two instances:
- **Slide-Outer groove** — FIXED with a 45° self-supporting ceiling ramp ([GEOM-FIX: slide chamfer]).
- **Snap-Inner (Rabbet) groove** — FLAGGED, fix pending ([GEOM-WARN: snap-inner groove], RenderBox.scad).
  Confirmed on print + render; ~0.84mm (bead_h) overhang. The same 45° ramp treatment applies.

**Manifold safeguards added:**
- Gate reports `nm=` per case (pymeshlab-gated); `just check-build-manifold` / `--strict-manifold` fail on it.
- `mastertray.py --validate` / `--strict-validate`: post-build pymeshlab check; a reminder prints otherwise.
- Safeguard A: warning when a strut is 0% on a lidded container.
- All geometry fix-points tagged `// [GEOM-FIX: …]` (what was wrong + how fixed).

**Deferred for confirmation (design fork):** the **wall-thickness accommodation** (auto-bump
`m_safe_wall` so the groove fits with a sound lip at low loops) and **closing-zone lip-height
resizing** — both touch tested wall/margin geometry, and they hinge on whether `Wall_Loops`
should *drive* wall thickness (today `thick_wall` dominates; at 2 loops + 0.6mm the wall is still
2.4mm). Implemented only the safe, regression-free parts above; the invasive resizing awaits a nod.

---

## ✅ THIS SESSION (items #4, #1, #2, #3 + font portability)

_Items #4/#1/#2 done under Sonnet; #3 + font + performance pass under Opus._

**Goal:** surface a malformed `mapping.yaml` as a clear startup error instead of a cryptic
`KeyError` deep in `build_overrides()`.

### Item #4 — mapping.yaml schema validation

| File | Change |
|------|--------|
| `build/mastertray.py` | Added `validate_mapping()` + `_fail_mapping_validation()`. Called inside `load_mapping()` so every entry point is protected. |
| `build/mastertray.py` | Added `validate` subcommand. |
| `justfile` | Added `just validate`; wired into `just meta`. |
| `build/scripts/test_mapping_schema.py` | New. 7 unit tests: 1 golden path, 6 broken-fixture cases. |

8 structural/cross-reference rules — missing key, wrong type, unknown flag, bad alias, empty entry. Gate: 26/26. Tests: 7/7.

---

### Item #1 — `make_env()` named-arg constructor (Option B)

**Problem:** `ui_payload` was a 55-entry `[[KEY, value], ...]` literal. A typo in a value was silent; a typo in a key string was only caught by `STRICT_KEYS` if the constant was completely undefined. No single place documented the full key set.

**Fix:** Added `make_env()` to MasterEngine.scad with all 55 parameters as named OpenSCAD arguments, each with a default from the `*0` constants. MasterBuilder.scad now calls `ui_payload = make_env(width=raw_w, ...)` by name. A typo in a parameter name produces an OpenSCAD "unknown parameter" warning at parse time — before any geometry runs.

| File | Change |
|------|--------|
| `MasterEnum.scad` | Added `FILAMENT_TYPE` and `FIT_PROFILE` constants (previously raw strings in the payload). |
| `MasterEngine.scad` | Added `make_env()` with 55 named parameters and a design-rationale comment block. |
| `MasterBuilder.scad:164-220` | Replaced `ui_payload = [[...], ...]` with `ui_payload = make_env(...)` call. |

Call sites of `get_val()`, `concat()` overrides, and all Render* files are **unchanged**. Only the construction site changed.

**Adding a new key in the future:** add param to `make_env()` + constant to MasterEnum.scad + `[KEY, param]` to the return array + Customizer var passed in MasterBuilder.scad. Three files, co-located changes, no scattered edits.

Gate: 26/26.

---

### Item #2 — `drop_redundant_overrides` hardening

**Problem:** The function silently dropped overrides with no log output. Also, `values_equal()` had a Python `True == 1` bug — an int override of a bool default would be incorrectly dropped (OpenSCAD treats `true != 1`).

**Investigation:** The HANDOFF's concern about expression-defined/post-include defaults is inert in practice. ALL Customizer variables in MasterBuilder.scad's preamble are simple literals. Expression-derived vars (`raw_w`, etc.) are never passed as `-D` overrides and never appear in the overrides dict. The regex covers the full real-world set.

**Fixes:**

| File | Change |
|------|--------|
| `build/mastertray.py` | `drop_redundant_overrides()` now accepts `verbose=True` (or `MASTERTRAY_VERBOSE` env var) and prints each dropped key to stderr — auditable, not silent. |
| `build/mastertray.py` | `values_equal()`: booleans now require both sides to be `bool` before comparing — fixes silent drop of int `1` against bool `True` default. |
| `build/scripts/test_drop_redundant_overrides.py` | New. 11 unit tests covering: literal parsing, expression-var exclusion, post-include-var exclusion, drop/keep decisions, RawLiteral passthrough, bool/int distinction, float/int tolerance, verbose output. |

The bool/int fix was a real bug found by the tests. Tests: 11/11.

---

### Item #3 — layer violation cleared + flip lid closed out

**Problem:** `flip_hinge_y()` and `flip_half_lid_l()` were mm-level geometry math living in
MasterManifest.scad (Layer 2, the intent compiler) instead of the engine layer. OpenSCAD
functions are global (the whole program flattens through MasterBuilder's include graph), so
the violation was purely *where the code lived*, not a broken include.

**Fix:**

| File | Change |
|------|--------|
| `MasterManifest.scad` | Deleted `flip_hinge_y()` — it was **dead code** (defined, never called). |
| `MasterManifest.scad` | Removed `flip_half_lid_l()` definition; left a pointer comment + FROZEN banner. |
| `MasterTolerance.scad` | Added `flip_half_lid_l()` (Layer 1.8), next to its dependency `breathing_room(COMP_SPINE)`. Its 3 call sites in MasterManifest still resolve (global scope). |

Flip lids carry an explicit **FROZEN** banner in both files (failed print: sideways slide on
the C-clip, weak latch retention; Glide pillbox is the live path). The branches stay because
the build matrix still exercises Flip Single/Double — do NOT extend flip geometry without a
deliberate mechanical redesign.

### Font portability (Master Document Pillar 7.6)

| File | Change |
|------|--------|
| `MasterText.scad` | `render_embossed_text()` default font `"Arial Black"` → `"Liberation Sans:style=Bold"` (bundled with OpenSCAD on every platform). |

`"Arial Black"` is Windows-only; it silently fails on headless/Linux cloud render servers and
CI, producing a wrong/empty STL with no error. The module is currently **uncalled**, so this
is zero behavioral change today — purely removing a latent CI trap for when text is wired in.

---

**Gate result (all items):** 26/26 green, component counts identical to baseline (Slide=4,
Flip Double=3, etc. — the flip relayer moved no geometry). Tests: 7/7 (mapping schema) +
11/11 (drop-redundant) = 18/18 total.

**Remaining open items after this session:**
5. Ball-snap long-term fix (widening side-wall lip; `groove_w` reduction).

(See "Master Document triage" section below for the larger optimization backlog.)

---

## ⚠️ CRITICAL ARCHITECTURE REVIEW (the backlog that drove the pass above)

Real, cited liabilities. Items marked Done above are kept here for context. **Do NOT
"fix" the remaining ones blind — each needs a deliberate decision; several are load-bearing.**

### 1. Core data model = untyped dynamic-scope association list (BIGGEST RISK)
- `ui_payload` (MasterBuilder.scad:164) is ~55 `[KEY, value]` pairs threaded everywhere as `data`.
- Reads: `get_val(KEY, data, fallback)` — linear O(n), **first-match-wins**.
- Overrides: `concat([[KEY,val]], data)` — prepend, so the array **grows unbounded** through layers.
- **A typo in a key silently returns the fallback. No error.** The system fails open into
  "plausible but wrong." This is the root cause behind most of the subtle geometry bugs.
- Highest-leverage mitigation: a debug mode where `get_val` of an unknown key *errors*
  instead of returning the fallback. Cheap, catches a whole bug class.

### 2. `compile_manifest` is a 583-line single-function ternary chain (MasterManifest.scad:82+)
- Dispatch by `intent == "string"` cascade.
- Six near-identical box blocks (Snap Ext/Int, Glide Ext/Int, Flip Single/Double) differ
  only in `LID_TYPE`/`LID_STYLE`. Should be one table-driven branch
  (`style → {lid_type, lid_style}`).

### 3. Stringly-typed contracts in 3 unsynced places
- Intent names live in: `mapping.yaml intents:`, `compile_manifest` equality checks, and
  manifest type strings (`"BOX"`,`"LID"`) re-matched in `build_part` (MasterBuilder.scad:234).
- Dispatcher miss = `echo("WARNING")`, a **silent console warning, not an error** → typo
  yields a partial/empty STL.

### 4. `mapping.yaml` is NOT the single source of truth it claims to be
- Private intents (`Snap Box (External)`, pillbox internals, …) are **not in mapping.yaml** —
  the real vocabulary is in the SCAD ternary. Two vocabularies (public YAML vs actual SCAD).
- `parse_scad_defaults()` (mastertray.py:85) and `parseScadDefaults()` (builder.astro:19) are
  **two regex implementations of the same parser in two languages** → will drift.

### 5. "Diff from defaults" can silently drop real overrides
- `drop_redundant_overrides` (mastertray.py:108) strips overrides matching a regex that only
  sees top-level `Var = literal;` *before the first include*. Expression-defined or post-include
  defaults are invisible → may drop a genuine override → wrong model, **no error**. No test backs it.

### 6. `--set` escape hatch bypasses all validation (mastertray.py:271)
- Raw `VAR=value` → `-D` verbatim, no key/type check. The `yaml.RepresenterError` fixed this
  session (RawLiteral not registered on SafeDumper) proves this path shipped un-exercised.

### 7. Layer violation: Layer 2 doing Layer 1 geometry
- `flip_hinge_y` / `flip_half_lid_l` (MasterManifest.scad:69-80) are mm-level geometry math
  living in the *intent compiler*. This is why flip-lid latch bugs were painful.

### 8. `EPS2` name pun (MasterBuilder.scad:157)
- `EPS2 = Nozzle_Diameter`, but the name reads as "2×EPS" (architecture memory even records
  `EPS2 = EPS*2`). One name, two meanings across files. Rename one.

### 9. No automated verification gate
- `component_bboxes.py` is run by hand. No CI builds the intent matrix and asserts
  "2 components / manifold / NoError." Both known defects (flip lid, ball-snap) were caught by
  **physical prints**, not software. This is the most consequential *process* gap.

### 10. Hardcoded machine-specific paths
- `PYTHON = 'C:\Python314\python.exe'` (build_server.mjs:26) and
  `REPO_ROOT = 'C:\repos\3D\MasterTray'` in client JS (builder.astro:343). Web layer only
  works on this one machine.

### What's genuinely good (keep)
- `mastertray.py` core is clean; front-end-wraps-core layering is sound.
- SCAD file-level decomposition (Render/Engine/Tolerance/Enum) is reasonable — the rot is
  *inside* `compile_manifest` and the data model, not the file map.
- Friendly-name CLI/web abstraction is a real QA win.

### Fix priority (least churn, most risk reduction first)
1. Build-matrix test gate (CI: build all intents → assert 2 components/manifold/NoError).
2. `get_val` fail-loud debug mode for unknown keys.
3. Table-drive the box-variant branches in `compile_manifest`.
4. Unify the two SCAD-default parsers; reconcile mapping.yaml's source-of-truth claim.
5. De-hardcode paths in the web layer.

---

## 📋 MASTER DOCUMENT TRIAGE (the v4.26 "7-pillar optimization guide")

A large optimization document was supplied (7 pillars: Mechanical/FDM, Slicer, AST/State,
CSG Math, BOSL2, External Libs, "Dark Arts"). It was taken as **guidelines, not a worklist**.

**Governing principle:** the build gate proves *topology* (builds / manifold / component
count), NOT *physical correctness*. Both known defects (flip lid, ball-snap) passed software
and were caught on the print bed. So geometry changes from a document are exactly the
"plausible but wrong" risk this branch exists to remove — they are NOT shipped on a green
gate alone. Geometry-equivalent changes are verified twice: gate **+** `component_bboxes.py`
bbox/component diff before-vs-after.

| Pillar item | Verdict | Reason |
|---|---|---|
| 3.1 Lazy state / `make_env` | **Done** | This session's item #1 — `ui_payload = make_env(...)`. |
| 7.6 Cloud font fallback | **Done** | Safe (dormant module, OpenSCAD-bundled font). |
| 4.3 Purge `$fn=36`/`$fn=24` | **Reject** | Contradicts documented intentional overrides (30=threads, 36=hinge). Would coarsen → regression. |
| 4.2 Macro-Oversize (+50mm cutters) | **Reject** | Contradicts EPS discipline; +50mm cutters can slice adjacent platter parts. |
| 1.1–1.5 corner sweeps, snap relief, ACME threads, teardrop detents, spine gaps | **Defer (physical)** | All change tested mechanical fits. ROOM_SPINE was just tuned (B8, "reprint to confirm"). Need print validation. |
| 4.1 / 5.1 2D-first pipeline, VNF rewrite | **Defer (high risk)** | Rewrites the most fragile subsystem (mesh/boolean). Candidate IF profiling shows mesh is the bottleneck — see perf pass. |
| 3.3 `strip_ws` short-circuit, `_find_anchor_def` recursive early-exit | **Reject (measured)** | Micro-opts on cold paths. Benchmarked: 20,000 calls ≈ 1–2s → ~50–100µs/call; a real build makes ~2 dozen calls (single-digit ms vs a 15,000ms build = ~0.01%). `strip_ws` short-circuit can't avoid the O(n) scan anyway (must scan to detect whitespace). Recursion over ~5 anchors can be slower + reintroduces depth risk. Risk (silently-wrong grid parse) ≫ unmeasurable gain. |
| 6.1/6.2 NopSCADlib, dotSCAD | **Defer (design)** | New deps; additive features (heat-set inserts, magnet recesses, Voronoi floors) need a product decision on WHERE they apply. |
| 7.2/7.3 `quantize`, `flawless_wall` | **Defer** | `quantize` is not a built-in (none of quantize/offset3d/vnf_union/trapezoidal_threaded/projection exist in repo); `flawless_wall` bakes Bambu magic numbers into all wall math — needs calibration data. |
| 7.5 `projection(cut=true)` → DXF/SVG | **Done** | `Export_2D` flag in MasterBuilder + `mastertray.py --export-2d {svg,dxf}`. Verified: SVG outline produced, normal 3D builds unaffected. Additive — no tested geometry touched. |
| 2.2 modifier-STL export | **Done** | `Hints_Only` flag + `mastertray.py --export-modifiers`. build_part skips non-GRID components and the grid factory emits only the marker discs. Verified: Grid Test 31 comp → 6 comp (discs only) in modifier mode; gate 26/26 unaffected (default off). Turned out contained (2 SCAD spots + 1 CLI flag), not the invasive plumbing first feared. |

See "PERFORMANCE PASS" below for measured build times that gate the perf-oriented pillars.

---

## ⚡ PERFORMANCE PASS — the real bottleneck was none of the 7 pillars

**Method: measure before optimizing.** The document asserted "UI lag / render timeouts /
thousands of searches per frame." Rather than act on assertions, build times were measured
(OpenSCAD via `subprocess.run`, which blocks correctly — note `openscad.exe`/`.com` launched
from PowerShell `&` detach and return instantly, so `Measure-Command` reads ~0.2s; only Python
subprocess timing is trustworthy here).

**Finding — a ~22s FIXED cost on every build, independent of geometry:**

| case | output | baseline |
|------|--------|----------|
| plain box (125 KB) | trivial | 23.8s |
| threaded jar (8.7 MB) | complex | 23.9s |
| mesh box (125 KB) | trivial | 22.5s |

A trivial box and a complex jar took the **same** ~23s → geometry is NOT the cost. Bisection:
- Removing the `build_part()` render call → still **21.4s**. So the cost is at include/load, not render.
- BOSL2 `std + threading` in isolation → **0.3s**. Not BOSL2's intrinsic parse.
- Per-include bisect → cost distributed across the Render files (RenderBox 5.1s, RenderTray
  4.7s, RenderJar 4.7s each, single include + cube).
- Root cause: **OpenSCAD's `include` does not deduplicate.** 11 files redundantly
  `include <BOSL2/std.scad>` directly *and* via MasterEngine *and* via each other
  (RenderBox→RenderTray→RenderMesh/RenderGrid…). BOSL2 was textually re-parsed dozens of
  times through the diamond-shaped include graph. (`include <MasterEngine.scad>` ×11 = 3.2s
  vs ×1 = 0.5s confirmed non-dedup.)

**Fix (safe, verified):** removed the redundant direct `include <BOSL2/std.scad>` from all 11
files that obtain BOSL2 via MasterEngine. MasterEngine is now the single canonical owner (with
a comment block forbidding re-includes). Removing a redundant include of an already-included
library yields an identical symbol table → geometry is byte-identical (confirmed: output STL
sizes unchanged to the byte — lid_test_set 3146 KB, threaded_jar 8778 KB; grid_test still 31
components).

**Result (~33–38% faster, zero geometry change):**

| case | before | after |
|------|--------|-------|
| plain box | 23.8s | 14.8s |
| lid test set | 24.6s | 16.5s |
| threaded jar | 23.9s | 16.2s |

**Gate after dedup: 26/26 PASS, every component count identical to baseline** (Slide=4,
Flip Double=3, Pill=6, Tray=7, Threaded Jar=3, Grid Test=31, Lid Test=20). Correctness confirmed.

---

## 🆕 NEW FEATURE — 2D laser/CNC export (Master Document Pillar 7.5)

`projection(cut=true)` derivation for clear-acrylic lids / CNC stock. Additive: does NOT touch
any existing geometry path.

| File | Change |
|------|--------|
| `MasterBuilder.scad` | `Export_2D` flag (default false, outside the @CONFIG_SECTION blocks). Final exec wraps `build_part` in `projection(cut=true)` when set. |
| `build/mastertray.py` | `--export-2d {svg,dxf}` — sets `Export_2D=true` and the export format. |
| `build/scad_defaults.json` | regenerated (`Export_2D` now present). |

Usage: `python build/mastertray.py build --intent "Container Lid" --lid Plain --width 60
--length 60 --export-2d svg --out lid.svg --no-report`. Verified: produces a 58×60mm outline
SVG; normal 3D STL builds with `Export_2D=false` are byte-unaffected.

---

## 🆕 NEW FEATURE — modifier-volume STL export (Master Document Pillar 2.2)

Emit ONLY the grid modifier-hint discs as a standalone STL, to load as a slicer modifier
volume (no manual "split to objects"). Additive: default off, existing builds unaffected.

| File | Change |
|------|--------|
| `MasterBuilder.scad` | `Hints_Only` flag (default false). `build_part` skips non-GRID components when set. |
| `RenderGrid.scad` | `factory_render_grid`: when `Hints_Only`, emits only `_render_grid_mod_hints` (no grid body), guarded with `is_undef`. |
| `build/mastertray.py` | `--export-modifiers` → sets `Hints_Only=true`. |
| `build/scad_defaults.json` | regenerated (`Hints_Only` present). |

Usage: `mastertray.py build --intent "Grid Test" ... --export-modifiers --out mods.stl`.
Requires a grid layout with circular hubs (C/S/D/T) — else the modifier STL is empty.
Verified: Grid Test 31 comp → 6 comp (discs only); gate 26/26 unaffected.

---

## ⚠️ MANIFOLD-CHECK GAP — non-manifold coupons shipped, now fixed

**What happened:** test-print coupons were validated with `component_bboxes.py` (connected-
component COUNT) and "2 components = jar+cap" was treated as a pass. **Component count does NOT
detect non-manifold edges.** The threaded/circular jar coupons had thousands of non-manifold
edges and shipped to print anyway. The correct tool — `validSTL.py` (pymeshlab) — was in the
repo, unused. Even OpenSCAD `--hardwarnings` passes these (CGAL's manifold notion ≠ slicer's).

**Scope (gate now reports `nm=` per case):** circular **Jar / Threaded Jar = 8012**, **Grid
Test = 30452**, Slide-Outer = 10, Lid Test Set = 40 (at 80×120×30). Polygon **Square/Spool Jar
= 0** (clean). nm scales with facet count → it's the circular faceting + solid-body union seams
(floor ring↔disc, floor↔wall meet face-to-face with zero overlap — the EPS-overlap rule).

**Fixes (committed):**
| File | Change |
|------|--------|
| `build/scripts/build_matrix.py` | `manifold_nm()` (pymeshlab) + `nm=` column every run; `--strict-manifold` fails on it. |
| `validSTL.py` | committed (was untracked) — the canonical non-manifold/boundary checker. |
| `justfile` | `just validate-stl [dir]` and `just check-build-manifold`. |

**Rule:** ALWAYS run `just validate-stl "STL/Test Prints"` (or validSTL) before sending any STL
to print. Component count is necessary but NOT sufficient.

**Open (not yet fixed — geometry):** solid circular jars are non-manifold (body union seams; EPS-
overlap fix needed) and BOSL2 threads add more. NOTE: *meshed* jars (with a pattern + struts)
come out manifold — the mesh code path rebuilds the wall/floor and sidesteps the solid-union seams.

---

## 🖨️ TEST PRINTS — physical fit validation (`STL/Test Prints/`)

To start the print-validation loop the gate can't cover, four small mechanism coupons were
generated (all 2 components, verified). Tolerances are absolute-mm so small coupons validate
fit faithfully — minimal plastic.

| Coupon | Dims | Mechanism |
|--------|------|-----------|
| `snap-outer_40x40x15` | 40×40×15 | over-wall snap |
| `snap-inner_40x40x15` | 40×40×15 | rabbet/inner snap |
| `slide-outer-tab_55x55x22` | 55×55×22 | slide + Tab detent (slide needs ≥55mm footprint; <55 builds empty) |
| `threaded-jar_d35h30` | Ø35×30 | screw threads (jar + cap = 2 parts) |

`STL/Test Prints/README.md` lists what fit feedback to collect per coupon. That feedback drives
the deferred Pillar 1 mechanical changes — which are made AFTER a coupon print, never on a green
gate alone. (`STL/` is gitignored — coupons are local artifacts, regenerable from SCAD.)

---

## 🔧 FIRST PILLAR-1 MECHANICAL CHANGE — slide groove 45° self-supporting ramp

The slide-outer coupon review caught a real overhang: the side-wall retaining lip above the
glide groove bridges the channel void (prints on air). Fix in RenderBox.scad External-glide
branch — the groove cutter now adds a **45° ramp that raises the channel ceiling toward the
interior**:

```
roof = h - (groove_z + groove_h);
if (lip <= roof - layer)     // only when a full 45° ramp fits under the rim (else flat, no regression)
    for (sx = [-1,1]) <triangular prism raising ceiling from groove_h at gx to groove_h+lip at gx-lip>
```

Key safety property: full channel height is preserved at the lid edge (~groove_w/2); the ramp
only adds void *inward*, away from the lid — so lid fit is unchanged, the ramp just removes the
overhang. Verified: gate 26/26 (Slide still 4 comp Ball / 2 comp Tab), render confirms the ramp
direction, RenderLid untouched. **Still needs a print** to confirm slide+retain — the gate can't
prove the fit. The inner-wall (Rabbet) slide has no external lip and avoids this entirely.

**Files:** `MasterEngine.scad` (canonical-owner comment), and BOSL2 direct-include removed from
`GridLayout`, `MasterMeshPatterns`, `RenderBox/Grid/Jar/Lid/Mesh/Peg/Plaque/Tray`, `RenderRib`.

**Stage 2 — MasterEngine dedup (user-approved the openability tradeoff):** the BOSL2 dedup
above still left BOSL2 re-parsed via each of the 11 `include <MasterEngine.scad>`. MasterEngine
is now included exactly ONCE (by MasterBuilder.scad, as its first include); all 15 sub-files had
their `include <MasterEngine.scad>` stripped. BOSL2 is now parsed a single time.

**Final result — ~15× faster, geometry byte-identical, gate 26/26 with identical counts:**

| case | baseline | BOSL2 dedup | + MasterEngine dedup |
|------|----------|-------------|----------------------|
| plain box | 23.8s | 14.8s | **1.6s** |

**TRADEOFF (accepted by user):** individual sub-files (RenderBox.scad, etc.) no longer open
standalone in the OpenSCAD GUI — they lack BOSL2/MasterEngine symbols and are only valid when
built through MasterBuilder.scad. To preview/debug a part, open MasterBuilder.scad and set
`Part_To_Build`. This is documented in the comment block at MasterBuilder's `include <MasterEngine.scad>`.

**Lesson:** none of the document's 7 pillars targeted this — it took measurement, not the guide,
to find the real cost (OpenSCAD's non-deduplicating `include` re-parsing BOSL2 ~dozens of times).

---

## What's committed and verified

### Pillbox refactor (`e5db572`)
- `7-Day Pill Box`, `7-Day AM/PM Box`, `1-Day AM/PM Box` intents. All 14 variants
  (7 days × 2 Glide intents) → **2 components, manifold, NoError**.
- Glide-External `groove_z` fix: `groove_z = h - sl - lh·ceil(1/lh) - groove_h` (boss was
  floating above the box for all heights).

### Build tooling
- `build/mastertray.py` — core builder (mapping → `-D` overrides → OpenSCAD → report.yaml/html).
- `build/mapping.yaml` — friendly names ↔ Customizer vars (see review #4 for caveats).
- `build/build.py`, `build/scripts/build_server.mjs`, `astro/src/pages/builder.astro` — wrappers.

### This session (Opus)
- **Fixed `yaml.RepresenterError`** on `--set` builds: `RawLiteral` now registered on BOTH
  `yaml.add_representer` and `yaml.SafeDumper.add_representer` (mastertray.py:43-44).
  `safe_dump` uses SafeDumper's separate registry — registering on the default Dumper alone
  was insufficient.
- **build_server.mjs**: added `GET /api/report?name=<stl>` → returns `<name>.report.yaml`.
- **builder.astro**: server health indicator (pings `/health` on load + tab focus, colored
  online/offline/error) and a collapsible build-report `<details>` block fetched after build.
  Verified rendering via preview (page loads clean, indicator resolves to offline when server down).
- **RECAP.md** (repo root) — architecture overview + recommendations.
- **learning.md** (repo root) — cross-session lessons (yaml SafeDumper, groove_z, ball-snap,
  flip lid, EPS overlap, C-clip hinge).

---

## Known frozen / won't-fix
- **Flip lids** — frozen after failed print (sideways slide, weak retention). See `flip_lid_frozen.md`.
- **Ball-snap boss mesh disconnection** — `Slide + Ball` = 4 components (box + lid + 2 floating
  ball bosses). **Tab snap is the workaround/standard** (no boss on box side → clean 2 components).
  **Lip-widening DISPROVEN (2026-06-18):** tried `groove_w` `w-sw+0.6`→`w-sw-0.6` (lip 0.9→1.5mm)
  with lockstep lid_w — gate STILL 4. The ball dimple (r≈1.18mm) is centered at the groove edge
  and cuts inward, so material left behind = `lip − ~1.08mm`; CGAL-bondable ~1.5mm would need
  lip >2.6mm > wall (2.4mm) — impossible. Reverted. A real fix needs a SMALLER/shallower ball
  detent or relocating it off the thin wall (mechanism redesign, print-validated), not a lip tweak.

---

## Non-obvious technical facts
- **`Part_To_Build`, not `Intent`** is the Customizer var. CLI: `-D "Part_To_Build=\"7-Day Pill Box\""`.
- **`component_bboxes.py`** — `python build/sandbox/component_bboxes.py <stl>` counts connected
  components. Target: exactly 2 per box+lid. Manifold check does NOT catch inter-component disconnect.
- **EPS overlap rule** — all `union()` geometry must overlap parent by `EPS=0.1mm`; face-to-face
  zero-overlap = disconnected shells in the slicer.

---

## Guidance for the next session (Sonnet)

**Current state:** the hardening pass is committed (`44fa802`). The build-matrix gate
(`just check-build`) is green at 26/26. The codebase is safe to refactor *because* that
gate exists — run it after any SCAD or build-tooling change and treat a red as a stop.

**Workflow rules that held this session (keep them):**
- After any `.scad`, `mastertray.py`, `mapping.yaml`, or `builder.astro` change, run
  `python build/scripts/build_matrix.py` (or `just check-build`). Don't claim a change
  works without it.
- Verify SCAD edits by actually building (OpenSCAD is at
  `C:\Program Files\OpenSCAD\openscad.exe`); run with `--set STRICT_KEYS=true` so typo'd
  KEY constants fail loud.
- Edit STILL-fragile areas only with a deliberate plan — they're load-bearing. Confirm
  intent with the user before starting #1/#5/#7 below.
- After regenerating `build/scad_defaults.json` (when MasterBuilder.scad defaults change),
  run `just defaults` — `builder.astro` reads that file, not the SCAD.

**Remaining open items (from the review; each needs a design decision, NOT a mechanical edit):**
1. ~~**Data-model redesign.**~~ **Done this session.** `make_env()` in MasterEngine.scad;
   `ui_payload = make_env(...)` in MasterBuilder.scad. Named params catch typos at parse time.
   `FILAMENT_TYPE` + `FIT_PROFILE` constants added to MasterEnum.scad.
2. ~~**`drop_redundant_overrides` regex.**~~ **Done this session.** Verbose mode added;
   bool/int equality bug fixed; 11 pinning tests in `test_drop_redundant_overrides.py`.
3. **Layer violation.** `flip_hinge_y` / `flip_half_lid_l` (mm geometry) live in
   MasterManifest (the intent compiler); they belong in MasterEngine. Deferred because flip
   lids are frozen and touching their geometry is risky — only do this alongside a flip redesign.
4. ~~**`mapping.yaml` has no schema.**~~ **Done this session.** `validate_mapping()` runs at
   every `load_mapping()` call; `just validate` / `just meta` expose it standalone.
   `build/scripts/test_mapping_schema.py` has 7 pinning tests.
5. **Ball-snap fix — lip-widening DISPROVEN (2026-06-18).** Attempted `groove_w` `w-sw+0.6`→
   `w-sw-0.6` (lip 0.9→1.5mm) + lockstep `lid_w`; gate STILL 4 components. The ball dimple
   (r≈1.18mm) centered at the groove edge cuts inward, leaving `lip − ~1.08mm` behind it; a
   CGAL-bondable ~1.5mm would need lip >2.6mm > wall (2.4mm) — impossible. Reverted. A real fix
   = smaller/shallower detent or relocating it off the thin wall (mechanism redesign, needs a
   print). **Tab detent is the standard.** Don't retry lip-widening — it's geometrically ruled out.

**Paste-to-next-session prompt:**
```
Continue MasterTray on branch refactor/code-clarity-and-safety.
Read docs/HANDOFF.md fully — start with the HARDENING PASS table, then
"THIS SESSION", then "Guidance for the next session".

State: architecture-hardening pass committed (44fa802); items #4, #1, #2 done
this session (uncommitted). Build-matrix gate `just check-build` is green at
26/26. ALWAYS run it after any .scad / mastertray.py / mapping.yaml /
builder.astro change, and treat a red as a stop. Build SCAD edits with
`--set STRICT_KEYS=true` so typo'd KEY constants fail loud.

Remaining open items (#3 layer violation — frozen with flip lids; #5 ball-snap)
each need a design decision — do NOT start them as mechanical edits. Tell me
which one you want to tackle and propose a plan first; I'll confirm before you
change load-bearing code.
```
