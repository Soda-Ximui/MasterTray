# MasterTray — Lessons Learned

_Updated as things are discovered. Newest entries at the top._

---

## 2026-06-17 (architecture review + hardening pass)

### The review (10 cited liabilities, worst-first)
A harsh read of the actual code (not docs) produced this backlog. Full detail lives in
`docs/HANDOFF.md`; the short version:
1. **Untyped dynamic-scope `data` array** — `ui_payload` (~55 `[KEY,value]` pairs) threaded
   everywhere; `get_val` is O(n) first-match-wins; overrides prepend so it grows unbounded.
   A typo'd key silently returns the fallback → fails open into "plausible but wrong". *Biggest risk.*
2. **583-line `compile_manifest` ternary** with 6 near-identical box branches.
3. **Stringly-typed intent vocabulary** in 3 unsynced places; dispatcher miss = silent `echo`.
4. **`mapping.yaml` not the real source of truth** — private intents live only in SCAD; the
   SCAD-default parser was reimplemented in both Python and JS (drift risk).
5. **`drop_redundant_overrides` regex** only sees top-level `Var = literal;` before the first
   include → can silently drop a genuine override. No test backs it.
6. **`--set` bypasses all validation** (the yaml SafeDumper crash was the proof it shipped un-run).
7. **Layer violation** — `flip_hinge_y`/`flip_half_lid_l` (mm geometry) live in the intent compiler.
8. **`EPS2` name pun** — read as `2×EPS`, actually `= Nozzle_Diameter`.
9. **No automated gate** — both known defects were caught by *physical prints*, not software.
10. **Hardcoded machine paths** in the web layer.

### What got fixed (7 fully, 1 mitigated)
Done: #2 (table-drive), #3 (fail-loud asserts), #4 (single-owner parser), #6 (`--set` warn),
#8 (`EPS2`→`LINE_W`), #9 (build-matrix gate), #10 (de-hardcode paths). Mitigated: #1
(`STRICT_KEYS` catches typo'd key *constants*, not the full data-model problem).
**Left open by design:** #1 full struct redesign, #5 override-diff regex, #7 layer move
(flip lids frozen → risky). Each needs a deliberate decision, not a mechanical edit.

### Build-matrix gate findings (informational, not failures)
26/26 public-surface cases build green under `STRICT_KEYS=true`. Component counts revealed:
- `Slide (Outer/Inner Wall)` = **4 components** — the known ball-snap boss disconnection
  (default catch "Ball"). Tab snap → 2. Confirms the frozen issue is still live.
- Pure `Grid` emits an *empty object* unless the layout fits the footprint; the gate hands it
  `grid_layout="2x3"`. (`Grid Test` is unaffected — it builds containers regardless.)
- The gate proves build-success + key-typo safety; exact component counts are intent-specific
  and deliberately NOT asserted (would red-flag the frozen ball-snap case).

### Fail-loud over silent-fallback
- `get_val` now has an opt-in `STRICT_KEYS` mode (MasterEngine.scad). It can't error on
  every absent key — fallbacks are a designed feature — but a *typo'd KEY constant* evaluates
  to `undef` in OpenSCAD, so `assert(!STRICT_KEYS || !is_undef(key))` catches exactly that.
  The build-matrix gate runs with `-D STRICT_KEYS=true`.
- `build_part` unknown component type and `compile_manifest` unknown intent are now
  `assert(false, ...)` instead of `echo("WARNING")`. A typo used to render a silent wrong
  model; now it hard-errors with the offending name. Verified: bogus intent → exit 1.

### OpenSCAD `assert` in a function
- Valid as a prefix to the return expression: `function f(x) = assert(cond, msg) <expr>;`.
  In a ternary value branch: `... ? assert(false, msg) [[...]] : ...` works too.

### Table-driving the manifest
- The 5 single-mechanism box intents (Snap/Glide × Ext/Rabbet + Flip Single) collapsed into
  one `box_lid_variant(lid_type, style, data)` helper. Flip Double stays separate (two
  half-lids + ROTATE_180). Byte-for-byte behavior preserved — verified via "Lid Test Set".

### Single-owner SCAD-default parsing
- Python's `parse_scad_defaults()` is now the only parser. `mastertray.py dump-defaults`
  writes `build/scad_defaults.json`; `builder.astro` reads that instead of re-implementing
  the regex in JS. `just defaults` (folded into `just meta`) regenerates it.

### EPS2 was a misleading name
- `EPS2` read as "2×EPS" but was actually overridden to `Nozzle_Diameter` (one extrusion
  line width, used as double-sided cutter overlap). Renamed to `LINE_W` across all SCAD files.

---

## 2026-06-17

### yaml.SafeDumper vs yaml.Dumper for str subclasses
`yaml.add_representer(MyStrSubclass, ...)` registers on the default `Dumper`.
`yaml.safe_dump()` uses `SafeDumper`, which has a separate registry.
If you have a `str` subclass that needs to serialize cleanly with `safe_dump`, register on **both**:
```python
yaml.add_representer(RawLiteral, lambda d, v: d.represent_str(str(v)))
yaml.SafeDumper.add_representer(RawLiteral, lambda d, v: d.represent_str(str(v)))
```
Symptom if missed: `yaml.representer.RepresenterError: ('cannot represent an object', '5')` — even though `'5'` looks like a plain string, the subclass tag makes YAML treat it as unknown.

### build_server.mjs `/api/report` endpoint
After a build, the `.report.yaml` is written alongside the STL in `build/sandbox/output/`.
The server now exposes `GET /api/report?name=<stl-name>` to return it as `text/yaml`.
The builder page fetches this after a successful build and shows it in a collapsible `<details>` block.

### builder.astro health check pattern
Ping `GET /health` on page load and on `visibilitychange` (tab focus) with a 1.5 s `AbortSignal.timeout`.
Color the status dot: green = online, grey = offline, red = server error.
This lets the user know before they click Build whether the server is up.

---

## 2026-06-10 (prior sessions)

### Glide-External groove_z off-by-one
The groove bottom was calculated without subtracting `groove_h`, so the boss floated above the box for all heights.
Fix: `groove_z = h - sl - lh·ceil(1/lh) - groove_h`.

### Ball-snap boss mesh disconnection (pre-existing, not fixed)
`groove_w = w - sw + 0.6` leaves only ~0.7–0.9 mm of side-wall lip.
The boss cylinder overlaps this lip but CGAL cannot bond at near-degenerate contact.
The `difference()` for the ball-dimple then severs the tenuous connection → 4 mesh components.
**Workaround: use Tab snap** (no boss/dimple on box side → clean 2-component mesh).

### Flip lid print failure
Sideways slide and weak retention on physical print.
All flip-lid work is frozen until a redesign is planned.

### EPS overlap rule
All geometry joined via `union()` must overlap the parent body by at least `EPS = 0.1 mm`.
Face-to-face zero-overlap = disconnected shells in the slicer.

### C-Clip hinge orientation
Printed face-down. Slot at `-clip_outer_d/2` (bottom of arc) → arms point down toward lid body.
The bug was `clip_outer_d/2` (top) which created a floating cantilever at the top of the print.
