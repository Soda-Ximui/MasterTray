# MasterTray — Architecture Recap

_Last updated: 2026-06-17_

---

## OpenSCAD Layer (the "compiler")

```
MasterBuilder.scad          ← Layer 4: UI entry point, dispatches by Part_To_Build
  MasterManifest.scad       ← Layer 2: intent compiler (name → geometry plan)
  MasterProcessor.scad      ← Layer 2: execution
  Render*.scad              ← Layer 3: dumb geometry renderers (one per shape type)
  MasterEngine.scad         ← Layer 1: physics/geometry math
  MasterEnum/Tolerance/...  ← Layer 1: constants, clearance tables, validation
```

Data flows as three arrays threaded through every call:
- **`data`** — full `ui_payload`, key-value pairs; prepend to override
- **`opts`** — per-component flags (`LID_TYPE`, `IS_THREADED`, etc.)
- **`phys`** — resolved print physics (`SAFE_WALL`, `NOZZLE`, `CLEARANCE`, etc.)

### Manifest Intent Architecture

- **Private intents** (e.g. "Snap Box (External)", "Glide Box (Internal)"): self-contained — emit box + lid + builtin-grid variant.
- **Public aggregators** (e.g. "Box", "Jar"): read checkbox flags, call `compile_manifest("Private Intent", data)` for each enabled flag, then `grid_variants()` once.
- Prepend to override data: `concat([[KEY, val]], data)`.

---

## Build Tooling Layer (the "front-end")

```
build/mapping.yaml               ← single source of truth: friendly names ↔ Customizer vars
build/mastertray.py              ← core builder: owns the build domain end-to-end
  build/build.py                 ← terse CLI shorthand, wraps mastertray.py
  build/scripts/build_server.mjs ← local HTTP API, shells out to mastertray.py
  astro/src/pages/builder.astro  ← web UI, calls build_server.mjs
```

**Layering rule:** new interfaces wrap `mastertray.py`; they never bypass or duplicate it. `mastertray.py` should never need to change to support a new front-end.

---

## Known Issues / Frozen Areas

| Area | Status | Notes |
|---|---|---|
| Flip lids | Frozen | Failed print test (sideways slide, weak retention) |
| Ball-snap boss | Workaround in place | Groove cuts too close to wall; CGAL can't bond boss. Tab snap is the fix. |

---

## Recommendations

### Done (hardening pass, 2026-06-17)
- ✅ **`--set` validation** — warns on unknown Customizer var names (mastertray.py).
- ✅ **`builder.astro` consumes generated artefact** — reads `build/scad_defaults.json`
  (from `mastertray.py dump-defaults`, via `just meta`); duplicate JS parser deleted.
- ✅ **Fail-loud** — `STRICT_KEYS` mode for `get_val`; `assert` on unknown intent/component.
- ✅ **Table-driven box variants**, **`EPS2`→`LINE_W`**, **de-hardcoded paths**.
- ✅ **Build-matrix gate** — `just check-build` (26 cases, all green).

### Still open (each needs a design decision)
1. **Data-model redesign** — the untyped, O(n), unbounded-growth `data` assoc-list is the
   biggest structural liability. `STRICT_KEYS` only catches typo'd key *constants*, not the
   deeper issues. A typed struct / single environment object is the real fix.
2. **`drop_redundant_overrides` regex** — only sees top-level `Var = literal;` before the
   first include; can silently drop a genuine override. No test backs it.
3. **Layer violation** — `flip_hinge_y` / `flip_half_lid_l` (geometry math) live in the
   intent compiler. Move to MasterEngine. Deferred (flip lids frozen, risky).
4. **`mapping.yaml` formal schema** — malformed intent → Python `KeyError`. Add validation.
5. **Ball-snap long-term fix** — widen side-wall lip by reducing `groove_w`; update lid width
   formula + Rabbet branch in lockstep. (Gate confirms Slide+Ball = 4 components today.)
