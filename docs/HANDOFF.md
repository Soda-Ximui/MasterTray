# Session Handoff — MasterTray
_Last updated: 2026-06-17 — Architecture review (Opus) + hardening pass: 8 fixes, committed `44fa802`_

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
- **Ball-snap boss mesh disconnection** — `groove_w` cuts too close to side wall (~0.7–0.9mm lip);
  CGAL can't bond the boss → 4 components. **Tab snap is the workaround** (no boss on box side).
  Long-term fix: widen lip by reducing `groove_w`, update lid width formula + Rabbet branch in tandem.

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
1. **Data-model redesign (biggest risk).** `ui_payload` is an untyped O(n) assoc-list that
   grows unbounded via prepend-to-override. `STRICT_KEYS` only catches typo'd key *constants*.
   The real fix is a typed struct / single environment object. Large; design first.
2. **`drop_redundant_overrides` regex (mastertray.py).** Only sees top-level `Var = literal;`
   before the first `include`; can silently drop a genuine override. Add a test + handle
   expression/post-include defaults, or warn when a key isn't in the parsed defaults.
3. **Layer violation.** `flip_hinge_y` / `flip_half_lid_l` (mm geometry) live in
   MasterManifest (the intent compiler); they belong in MasterEngine. Deferred because flip
   lids are frozen and touching their geometry is risky — only do this alongside a flip redesign.
4. **`mapping.yaml` has no schema.** A malformed intent fails as a Python `KeyError`. Add a
   validation step (mastertray.py startup or `just meta`) for a clear error.
5. **Ball-snap long-term fix.** The gate confirms `Slide + Ball` = 4 components (CGAL can't
   bond the boss). Widen the side-wall lip by reducing `groove_w`; update the lid width
   formula AND the Rabbet branch in lockstep. Contained but multi-file. Tab snap is today's
   workaround.

**Paste-to-Sonnet prompt:**
```
Continue MasterTray on branch refactor/code-clarity-and-safety.
Read docs/HANDOFF.md fully — start with the HARDENING PASS table, then the
"Guidance for the next session" section.

State: the architecture-hardening pass is committed (44fa802). The build-matrix
gate `just check-build` is green at 26/26. ALWAYS run it (or
`python build/scripts/build_matrix.py`) after any .scad / mastertray.py /
mapping.yaml / builder.astro change, and treat a red result as a stop.
Build SCAD edits with `--set STRICT_KEYS=true` so typo'd KEY constants fail loud.

The remaining open items (#1 data-model redesign, #2 override-diff regex,
#3 layer violation, #4 mapping schema, #5 ball-snap) each need a design decision —
do NOT start them as mechanical edits. Tell me which one you want to tackle and
propose a plan first; I'll confirm before you change load-bearing code.
```
