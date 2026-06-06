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

## B2 — Screw lid cap height inherits jar neck height instead of minimum thread engagement

**Status:** Fixed in `RenderLid.scad` line 141  
**Severity:** High — lid prints ~70% taller than necessary; wastes filament and print time  
**Reported:** 2026-06-04 (user: "jar lid too tall")

### Root cause

The Screw lid cap height was derived by copying the jar neck geometry:

```scad
// BEFORE (wrong): RenderLid.scad line 141
lip_h = JAR_LIP_HEIGHT;              // 8.0mm — the jar's threaded neck height
cap_h = max(0.1, lip_h + sw * 1.5); // 8.0 + 2.4×1.5 = 11.6mm
```

`lip_h + sw*1.5` is the sum of the jar neck's thread section (`lip_h`) and its taper
cone (`sw*1.5`). The taper is a feature on the **jar body** — it transitions the jar
wall diameter down to the neck diameter. The lid cap slides over the neck; it has no
taper and does not need taper clearance.

**Total lid height at defaults:** `sl + cap_h` = `2.0 + 11.6` = **13.6mm**

### Fix

Cap height = minimum thread engagement: 3 full turns at the configured pitch,
floored at `sw*2` (ensures at least 2 full wall passes on the cap cylinder).

```scad
// AFTER: RenderLid.scad line 141
cap_h = max(m_thread_pitch(data) * 3, sw * 2);
```

**Total lid height at defaults** (`pitch=2.0, sw=2.4`):  
`max(6.0, 4.8) = 6.0mm cap` → `sl + cap_h = 2.0 + 6.0` = **8.0mm** (−5.6mm, −41%)

### Height comparison at common settings

| pitch | sw | Before cap_h | After cap_h | Saving |
|-------|----|-------------|-------------|--------|
| 2.0mm | 2.4mm | 11.6mm | 6.0mm | −5.6mm |
| 2.0mm | 3.2mm | 12.8mm | 6.4mm | −6.4mm |
| 3.0mm | 2.4mm | 11.6mm | 9.0mm | −2.6mm |

### All other lid types — confirmed correct

| Lid type | Height | Verdict |
|----------|--------|---------|
| Snap | `sl` only | ✅ |
| Glide | `sl` only | ✅ |
| Flip_Single | `sl` + C-clip hinge above (mechanically required) | ✅ |
| Slip | `sl` only | ✅ |
| **Screw** | **Was `sl + lip_h + sw*1.5`; now `sl + max(pitch×3, sw×2)`** | **Fixed** |

---

_Add new entries as B3, B4, … in order of discovery._
