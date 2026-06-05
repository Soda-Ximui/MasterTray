# MasterTray — Bug Registry
_Each entry: root cause, affected code, fix, and test to verify._

---

## B1 — Circular strut % uses diameter scaling instead of area scaling

**Status:** Fixed in `RenderMesh.scad` line 52  
**Severity:** Medium — solid border on jar floor/lid is larger than user-dialled value  
**Reported:** 2026-06-04 session (strut semantics review)

### Definition of strut %

Strut % is the **fraction of the surface that is solid border**.  
10% strut → 90% of the surface area is open mesh.

| Surface | Strut applies to |
|---------|-----------------|
| Flat rectangle | Each linear dimension independently: mesh rect = W×(1−s%) by L×(1−s%) |
| Flat circle | **Area**: mesh circle area = (1−s%) × total area |
| Cylindrical wall | Height only: mesh zone = (1−s%) of height, split equally top and bottom |

### The bug

`framed_mesh` with `is_cyl=true` (jar floor, jar lid) computed the mesh circle diameter as:

```scad
// BEFORE (wrong): linear diameter scaling
circle(d = get_mesh_dim(w, strut));   // = w * (1 - strut/100)
```

Area scales as diameter², so this gives mesh area = `(1−strut/100)²` of total — not `(1−strut/100)`.

**Error at common strut values:**

| Strut % | Expected mesh area | Actual mesh area (bug) | Error |
|---------|-------------------|----------------------|-------|
| 10% | 90% | 81% | −9 pp |
| 20% | 80% | 64% | −16 pp |
| 30% | 70% | 49% | −21 pp |
| 50% | 50% | 25% | −25 pp |

### Fix

Scale by √ so the area relationship is preserved:

```scad
// AFTER (correct): area-preserving scaling — see RenderMesh.scad line 52
circle(d = w * sqrt(max(0, 1 - strut / 100)));
```

Verification: at strut=10%, `d = w * sqrt(0.9) = w * 0.9487`.  
Area = π(0.9487d/2)² = 0.9 × πd²/4. ✓

### What is NOT a bug (for reference)

**Flat rectangle pad:** `framed_mesh` subtracts `pad = noz × 4.5` from the mesh rect
on each axis to prevent half-holes at the boundary. This makes the actual solid border
slightly wider than strut% alone specifies (by ~0.9mm each side at 0.4mm nozzle).
This is **intentional** — without it, holes at the mesh boundary are clipped to partial
shapes that print as blobs. Strut% sets the coarse border; pad adds a small fixed
print-quality margin on top.

**Threaded neck:** The mesh zone never reaches the threaded neck because the jar geometry
is split into separate pieces (`cyl_wall_h` for mesh wall, then taper + thread above).
Strut% only governs the mesh wall section; the neck is structurally isolated above it.

---

_Add new entries as B2, B3, … in order of discovery._
