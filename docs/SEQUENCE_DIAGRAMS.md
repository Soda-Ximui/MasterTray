# MasterTray — Sequence Diagrams
_Generated: 2026-06-04_

---

## 1. Top-Level Build Pipeline

The complete path from Customizer input to rendered geometry.

```mermaid
sequenceDiagram
    actor User
    participant Builder  as MasterBuilder.scad
    participant Manifest as MasterManifest.scad
    participant Engine   as MasterEngine.scad
    participant Factory  as factory_render_*

    User->>Builder: Set Part_To_Build + dimensions + mesh + tolerances
    Builder->>Builder: Auto-math: Usable→Total (raw_w/l/h)
    Builder->>Builder: Assemble ui_payload [[KEY, val], ...]
    Builder->>Manifest: compile_manifest(intent, ui_payload)
    Manifest->>Engine: get_physics_profile(data)
    Engine-->>Manifest: phys [SAFE_WALL, SAFE_FLOOR, CLEARANCE, NOZZLE]
    Manifest->>Manifest: Resolve intent → [[type, data, opts, phys], ...]
    Manifest-->>Builder: manifest array
    loop For each manifest item
        Builder->>Engine: get_xy(manifest, i) → [x, y] platter position
        Builder->>Factory: translate([x,y,0]) factory_render_*(data, opts, phys)
        Factory-->>User: Geometry rendered on build plate
    end
```

---

## 2. Manifest Compilation — Intent Resolution

How `compile_manifest` maps an intent string to typed component tuples.
Shows the data-override (prepend) pattern that enables dual-spawn and inline config.

```mermaid
sequenceDiagram
    participant Manifest as compile_manifest
    participant Engine   as MasterEngine
    participant Data     as data (ui_payload)

    Manifest->>Data: get_val(WIDTH, data)
    Manifest->>Data: get_val(LENGTH, data)
    Manifest->>Engine: get_physics_profile(data) → phys

    alt intent == "Jar with Lid" AND w == l
        Manifest-->>Manifest: [ JAR(data, IS_THREADED=true), LID(data, Screw) ]
    else intent == "Jar with Lid" AND w ≠ l  [dual-spawn]
        Manifest-->>Manifest: [ JAR(concat([[WIDTH,w]],data)), LID(concat([[WIDTH,w]],data)),\n  JAR(concat([[WIDTH,l]],data)), LID(concat([[WIDTH,l]],data)) ]
    else intent == "7-Day Pill Box"
        Manifest->>Manifest: box_d = concat([[GRID_LAYOUT,"7x1"],[HAS_BUILTIN_GRID,true]], data)
        Manifest-->>Manifest: [ BOX(box_d, Flip_Single), \n  LID×7(concat([[WIDTH,cw],[PLAQUE_TEXT,day]],data)) ]
    else intent == "14-Day AM/PM Box"
        Manifest-->>Manifest: [ BOX(7x2 grid, Flip_Double), \n  LID×7 AM, LID×7 PM ]
    else intent == "Pillbox Full Set"  [delegating intent]
        Manifest->>Manifest: compile_manifest("14-Day AM/PM Box", data)
        Manifest->>Manifest: compile_manifest("7-Day Pill Box", data)
        Manifest->>Manifest: compile_manifest("1-Day AM/PM Box", data)
        Manifest-->>Manifest: concat of all three manifests
    else intent == "S4 Jar"  [desiccant override]
        Manifest->>Manifest: prepend DESICCANT_MESH_CYL to data
        Manifest->>Manifest: delegate to "Jar with Lid"
    else unknown intent
        Manifest-->>Manifest: [ TRAY(data, []) ] + echo WARNING
    end
```

---

## 3. Physics Profile Computation

How `get_physics_profile` derives FDM-safe geometry from raw user inputs.

```mermaid
sequenceDiagram
    participant Caller
    participant Engine  as MasterEngine.scad
    participant Consts  as MasterConstants.scad

    Caller->>Engine: get_physics_profile(data)
    Engine->>Engine: noz = get_val(NOZZLE_DIAMETER, data)
    Engine->>Engine: lh  = get_val(LAYER_HEIGHT, data)
    Engine->>Engine: wl  = get_val(WALL_LOOPS, data)
    Engine->>Engine: fil = get_val(FILAMENT_TYPE, data)

    Note over Engine: SAFE_WALL: snap raw wall to nozzle multiples,\nmin = noz × wall_loops,\ncap = 45% of smallest XY dim

    Engine->>Engine: safe_wall = round(raw_wall/noz)*noz
    Engine->>Engine: safe_wall = max(safe_wall, noz*wl)

    Note over Engine: SAFE_FLOOR: snap to layer-height multiples,\ncap = 35% of total height

    Engine->>Engine: safe_floor = round(raw_floor/lh)*lh

    Note over Engine: CLEARANCE: filament-aware fit gap

    Engine->>Consts: breathing_room(component, filament, fit_profile)
    Consts-->>Engine: clearance (e.g. 0.2mm PETG Standard)

    Engine-->>Caller: [ [SAFE_WALL, w], [SAFE_FLOOR, f], [CLEARANCE, c], [NOZZLE, noz] ]
```

---

## 4. Mesh Rendering — Flat Surface (Box/Tray Floor & Lid)

How `framed_mesh` decides whether to render mesh, and which pattern to use.

```mermaid
sequenceDiagram
    participant Factory as factory_render_tray / box
    participant Mesh    as RenderMesh.scad
    participant Engine  as MasterEngine (get_mesh_cfg)
    participant Pattern as MasterMeshPatterns.scad

    Factory->>Engine: get_mesh_cfg(data, surface="FLOOR")
    Note over Engine: Checks HOLE_FLOOR > 0\nand STRUT_FLOOR < 100\nand PATTERN ≠ "None"
    alt mesh disabled (any check fails)
        Engine-->>Factory: undef
        Factory->>Factory: render solid slab — no mesh call
    else mesh enabled
        Engine-->>Factory: [hole, strut_pct]
        Factory->>Mesh: framed_mesh(data, w, l, h, cfg, is_cyl=false)
        Mesh->>Mesh: effective_w = w × (1 - strut_pct/100)
        Mesh->>Mesh: step = get_grid_step(hole, min_sp, noz)
        Mesh->>Mesh: nx = floor(effective_w / step)
        Mesh->>Mesh: ny = floor(effective_l / step)
        Mesh->>Pattern: render_rectangular_pattern(pat, hole, step, nx, ny)
        Pattern-->>Mesh: 2D pattern shapes (circles, teardrops, slots…)
        Mesh->>Mesh: linear_extrude(h) through slab
        Mesh->>Mesh: difference() slab − pattern
        Mesh-->>Factory: meshed slab geometry
    end
```

---

## 5. Mesh Rendering — Cylindrical Wall (Jar)

```mermaid
sequenceDiagram
    participant Factory as factory_render_jar
    participant Mesh    as cylindrical_mesh_wall
    participant Engine  as MasterEngine
    participant Pattern as MasterMeshPatterns.scad

    Factory->>Engine: get_mesh_cfg(data, surface="WALL")
    alt mesh disabled
        Engine-->>Factory: undef → solid cylinder shell
    else mesh enabled
        Engine-->>Factory: [hole, strut_pct]
        Factory->>Mesh: cylindrical_mesh_wall(data, d, h, wall_t, cfg)
        Mesh->>Mesh: rim_chamf = nozzle_d × 4  [1.6mm @ 0.4mm nozzle]
        Mesh->>Mesh: outer cyl(d, h, chamfer=rim_chamf)
        Mesh->>Mesh: inner cyl(d - wall_t×2, h+2) subtracted
        Mesh->>Mesh: n_cols = circumference / step  [holes around]
        Mesh->>Mesh: n_rows = effective_h / step    [holes up]
        loop for each [row, col]
            Mesh->>Pattern: render_cylindrical_pattern(pat, hole, wall_t)
            Pattern-->>Mesh: 3D hole cutter (extruded/rotated primitive)
            Mesh->>Mesh: rotate([0,90,col_angle]) translate([r,0,row_z]) hole_cutter
        end
        Mesh->>Mesh: difference() shell − all hole cutters
        Mesh-->>Factory: meshed jar wall
    end
```

---

## 6. apply_master_bounds — Edge Safety (All Rectangular Primitives)

Two-pass intersection that applies corner rounding + top/bottom chamfer.
Every box, tray, lid, and grid passes through this module.

```mermaid
sequenceDiagram
    participant Caller  as factory_render_* child geometry
    participant Bounds  as apply_master_bounds(w, l, h, r, c)
    participant BOSL2   as BOSL2 cuboid

    Caller->>Bounds: children() [raw geometry]

    Note over Bounds: Pass 1 — Vertical corner rounding\nc_r = max(0.1, min(r, w/2-0.1, l/2-0.1))

    Bounds->>BOSL2: cuboid([w, l, h×3], rounding=c_r, edges="Z", anchor=BOTTOM)
    Note over Bounds: h×3 oversize: avoids BOSL2 clipping\ntall children at exact height

    Bounds->>Bounds: intersection(children, pass1_cuboid)

    Note over Bounds: Pass 2 — Horizontal edge chamfer\nedges=TOP+BOTTOM\n→ top rim: safe to handle off printer\n→ bottom: 45° lead-in = elephant foot relief

    Bounds->>BOSL2: cuboid([w+EPS, l+EPS, h], chamfer=c, edges=TOP+BOTTOM, anchor=BOTTOM)
    Bounds->>Bounds: intersection(pass1_result, pass2_cuboid)

    Bounds-->>Caller: geometry with rounded vertical corners + chamfered top/bottom rims
```

---

## 7. Tolerance & Fit — Clearance Lookup

How fit clearance is derived per joint type, filament, and user fit profile.

```mermaid
sequenceDiagram
    participant Factory as factory_render_lid / box
    participant Tol     as MasterTolerance.scad
    participant Consts  as MasterConstants.scad

    Factory->>Tol: breathing_room(component, data)
    Tol->>Tol: fil = get_val(FILAMENT_TYPE, data)   [PLA/PETG/TPU/ABS]
    Tol->>Tol: fit = get_val(FIT_PROFILE, data)     [Tighter…Looser]

    Note over Tol: Base clearance per component:\nCOMP_SPINE  → hinge pin in boss\nCOMP_CCLIP  → C-clip spring retention\nCOMP_CLASP  → front snap latch\nCOMP_GLIDE  → sliding lid rail

    Tol->>Consts: ROOM_CCLIP_PETG / ROOM_CCLIP_PLA / ROOM_CCLIP_TPU
    Consts-->>Tol: base clearance (mm)

    Note over Tol: Fit profile adjustment:\nTighter  −0.10mm  −0.40mm engagement\nTight    −0.05mm  −0.20mm\nStandard  0       0\nLoose    +0.05mm  +0.20mm\nLooser   +0.10mm  +0.40mm

    Tol-->>Factory: adjusted clearance (mm)
    Factory->>Factory: Apply to socket diameter / groove width / boss engagement
```

---

## 8. Dual-Spawn Pattern — Data-Conditional Manifest

When W ≠ L on a jar intent, the manifest spawns two independent jars each with
their own WIDTH override prepended to data, exploiting `get_val`'s first-match.

```mermaid
sequenceDiagram
    participant User
    participant Builder  as MasterBuilder
    participant Manifest as compile_manifest
    participant GetVal   as get_val(KEY, data)

    User->>Builder: WIDTH=30, LENGTH=46 ("Jar with Lid")
    Builder->>Manifest: compile_manifest("Jar with Lid", data)
    Manifest->>Manifest: w=30, l=46 → w ≠ l

    Note over Manifest: Prepend-to-override idiom:\nconcat([[WIDTH, 30]], data)\nconcat([[WIDTH, 46]], data)\nNo mutation — original data unchanged

    Manifest->>GetVal: get_val(WIDTH, concat([[WIDTH,30]], data))
    GetVal-->>Manifest: 30  [first match wins]

    Manifest->>GetVal: get_val(WIDTH, concat([[WIDTH,46]], data))
    GetVal-->>Manifest: 46  [first match wins]

    Manifest-->>Builder: [\n  JAR(d30), LID(d30),\n  JAR(d46), LID(d46)\n]

    Builder->>Builder: get_xy(manifest, 0) → [0, 0]
    Builder->>Builder: get_xy(manifest, 1) → [0, 0]   (lid beside jar)
    Builder->>Builder: get_xy(manifest, 2) → [x2, 0]  (second pair offset)
    Builder->>Builder: get_xy(manifest, 3) → [x2, 0]
```

---

## 9. Desiccant (S4) Intent — Override Chain

Shows how S4 intents lock mesh settings by prepending constants,
then delegate to a general intent.

```mermaid
sequenceDiagram
    participant User
    participant Manifest as compile_manifest
    participant Consts   as DESICCANT_MESH_CYL / RECT
    participant General  as compile_manifest("Jar with Lid")

    User->>Manifest: intent = "S4 Jar"
    Manifest->>Consts: DESICCANT_MESH_CYL
    Note over Consts: [[PATTERN, TEARDROP],\n [HOLE_WALL, 1.8], [HOLE_FLOOR, 1.8],\n [HOLE_SPACING, 1.2],\n [STRUT_WALL, 15], ...]

    Manifest->>Manifest: locked_data = concat(DESICCANT_MESH_CYL, data)
    Note over Manifest: Customizer mesh settings now\nburied behind desiccant overrides.\nget_val always finds the locked\nvalues first — user knobs silenced.

    Manifest->>General: compile_manifest("Jar with Lid", locked_data)
    General-->>Manifest: [ JAR(locked_data, IS_THREADED), LID(locked_data, Screw) ]
    Manifest-->>User: desiccant jar + lid with teardrop 1.8mm mesh locked in
```

---

## 10. Grid Layout — Parse to Geometry

How a layout string like `"7x5 S2/2/2/3/150% R6 C15%"` becomes divider geometry.

```mermaid
sequenceDiagram
    participant Factory as factory_render_grid
    participant Parser  as GridLayout.scad
    participant Render  as RenderGrid.scad
    participant Bounds  as apply_master_bounds / cyl intersection

    Factory->>Parser: parse_grid_layout(layout_string)
    Parser->>Parser: tokenize by spaces
    Parser->>Parser: "7x5"      → rows=7, cols=5
    Parser->>Parser: "S2/2/2/3/150%" → span: row2,col2, 2wide,3tall, 150% wall_h
    Parser->>Parser: "R6"       → radial spokes=6
    Parser->>Parser: "C15%"     → hub = 15% of container diameter

    Parser-->>Factory: grid_config [rows, cols, spans[], radial, hub]

    alt Cartesian grid (rows/cols present)
        Factory->>Render: render_cartesian_grid(config, data, opts, phys)
        Render->>Render: x_dividers: place at col boundaries
        Render->>Render: y_dividers: place at row boundaries
        loop spans
            Render->>Render: override wall_h for cells in span range
        end
    else Radial grid (R token present)
        Factory->>Render: render_radial_grid(config, data, opts, phys)
        Render->>Render: hub cylinder (if C large enough)
        Render->>Render: spokes: n×rotated cuboids at 360/n° intervals
    end

    alt Built-in mode (GRID_MODE = "Built-in")
        Render->>Factory: union grid into container — no gap
    else Drop-in mode (GRID_MODE = "Drop-in")
        Render->>Render: subtract GRID_DROP_IN_TOLERANCE (0.4mm) from outer dims
        Render->>Factory: standalone printable object
    end

    alt Rectangular container
        Factory->>Bounds: apply_master_bounds(w, l, h, r, c) clip
    else Jar container (IS_JAR_GRID)
        Factory->>Bounds: intersection() with cyl(d=inner_d, h) clip
    end
```
